import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_state.dart';
import '../../core/net/cellular_http_client.dart';
import '../services/ai_agent_service.dart';
import '../services/notification_service.dart';
import 'machine_provider.dart';
import 'ai_agent_settings_provider.dart';
import 'ai_model_provider.dart';
import 'ai_usage_provider.dart';
import 'ai_inbox_provider.dart';
import 'activity_log_provider.dart';

/// Veilleur d'évènements CRITIQUES (rares) : alarme machine, arrêt d'urgence,
/// surchauffe. Sur front montant, envoie une notification factuelle immédiate
/// PUIS un appel IA ponctuel pour la cause probable + l'action à faire.
///
/// Justification quota : ces évènements sont rares → un appel Ian par évènement
/// est acceptable (contrairement au flux d'actions courantes, qui reste passif).
class CriticalEventWatcher {
  final Ref _ref;

  MachineStatus? _lastStatus;
  bool _lastEstop = false;
  bool _tempAlerted = false;
  List<bool> _lastLimits = const [false, false, false, false, false];
  final List<DateTime?> _lastLimitNotify = List<DateTime?>.filled(5, null);
  DateTime? _lastAiCall;
  final Map<String, DateTime> _lastNotifyByType = {};

  static const _axisNames = ['X', 'Y', 'Z', 'A', 'C'];

  static const double _tempThreshold = 70.0; // °C
  static const Duration _aiCooldown = Duration(seconds: 45);
  // Anti-répétition par axe : un capteur qui rebondit ou réapparaît dans les
  // rapports de statut ne doit pas re-notifier en rafale.
  static const Duration _limitNotifyCooldown = Duration(seconds: 10);
  // Anti-rafale par type d'évènement. Assez court pour ne pas masquer une
  // seconde alarme réellement distincte, assez long pour tuer une boucle.
  static const Duration _sameTypeCooldown = Duration(seconds: 20);

  CriticalEventWatcher(this._ref) {
    _ref.listen<AsyncValue<MachineState>>(machineStateProvider, (prev, next) {
      final s = next.valueOrNull;
      if (s != null) _check(s);
    });
  }

  void _check(MachineState s) {
    // Alarme machine (front montant).
    if (s.status == MachineStatus.alarm &&
        _lastStatus != MachineStatus.alarm) {
      _trigger(
        'ALARME MACHINE',
        'La machine est passée en ALARME'
            '${s.alarmCode != null ? ' (code ${s.alarmCode})' : ''}.',
        s,
      );
    }

    // Arrêt d'urgence (front montant).
    if (s.emergencyTriggered && !_lastEstop) {
      _trigger('ARRÊT D\'URGENCE', 'Un arrêt d\'urgence a été déclenché.', s);
    }

    // Surchauffe (avec hystérésis pour ré-armer).
    if (s.coreTemp >= _tempThreshold && !_tempAlerted) {
      _tempAlerted = true;
      _trigger(
        'SURCHAUFFE',
        'Température cœur élevée : ${s.coreTemp.toStringAsFixed(0)} °C '
            '(seuil ${_tempThreshold.toInt()} °C).',
        s,
      );
    } else if (s.coreTemp < _tempThreshold - 5) {
      _tempAlerted = false;
    }

    // Fins de course (front montant par axe).
    for (int i = 0; i < 5 && i < s.limitSwitches.length; i++) {
      final active = s.limitSwitches[i];
      final was = i < _lastLimits.length && _lastLimits[i];
      if (active && !was) {
        final axis = _axisNames[i];
        // Journal d'activité (l'IA le voit en contexte) — toujours.
        _ref
            .read(activityLogProvider.notifier)
            .log('Fin de course $axis déclenchée (statut ${s.status.name})');

        // Pendant le HOMING, toucher les capteurs est NORMAL et répété
        // (approche → pull-off → ré-approche) : aucune notification, sinon un
        // cycle d'origine spamme l'opérateur.
        if (s.status == MachineStatus.home) continue;

        // Anti-répétition par axe (rebond du switch / réapparition dans les
        // rapports de statut).
        final now = DateTime.now();
        final last = _lastLimitNotify[i];
        if (last != null && now.difference(last) < _limitNotifyCooldown) {
          continue;
        }
        _lastLimitNotify[i] = now;

        if (s.status == MachineStatus.run) {
          // Déclenchement PENDANT un usinage = hard limit → alerte + IA.
          _trigger(
            'FIN DE COURSE $axis',
            'Fin de course $axis déclenchée PENDANT un mouvement (hard limit) — '
                'la machine doit être stoppée immédiatement.',
            s,
          );
        } else {
          // Autre état (ex. alarme déjà signalée par ailleurs) : simple info.
          _notify('Fin de course $axis', 'Fin de course $axis active.',
              problem: false);
        }
      }
    }
    _lastLimits = List<bool>.from(s.limitSwitches);

    // `offline` veut dire « liaison perdue », PAS « la machine a changé
    // d'état ». Une alarme ne disparaît pas parce que le WiFi a coupé.
    //
    // Le dépôt force pourtant le statut à `offline` à chaque coupure, si bien
    // que le moindre cycle de reconnexion produisait la séquence
    // alarme → offline → alarme, donc un nouveau front montant, donc une
    // notification — en boucle tant que le lien restait instable, ce qui est
    // exactement le cas au démarrage de l'application.
    //
    // En ne mémorisant pas `offline`, le front d'alarme reste consommé et la
    // reconnexion ne renotifie plus.
    if (s.status != MachineStatus.offline) {
      _lastStatus = s.status;
      _lastEstop = s.emergencyTriggered;
    }
  }

  Future<void> _trigger(String type, String factual, MachineState s) async {
    // Filet de sécurité : quoi qu'il arrive en amont, un même type d'évènement
    // ne peut pas notifier en rafale. Ce n'est PAS le correctif de la boucle
    // de démarrage — celui-ci est dans `_check`, sur le statut `offline` — mais
    // une seconde barrière, parce qu'un opérateur noyé sous les notifications
    // finit par toutes les ignorer, y compris la vraie.
    final now = DateTime.now();
    final lastSame = _lastNotifyByType[type];
    if (lastSame != null && now.difference(lastSame) < _sameTypeCooldown) {
      return;
    }
    _lastNotifyByType[type] = now;

    // 1) Notification factuelle IMMÉDIATE (sans attendre l'IA).
    _notify(type, factual, problem: true);

    // 2) Appel IA ponctuel (avec cooldown pour éviter toute rafale d'appels).
    if (_lastAiCall != null && now.difference(_lastAiCall!) < _aiCooldown) {
      return;
    }
    _lastAiCall = now;

    final advice = await _askAi(type, factual, s);
    if (advice != null && advice.trim().isNotEmpty) {
      _notify('$type — Assistant IA', advice.trim(), problem: true);
    }
  }

  void _notify(String title, String body, {bool problem = false}) {
    NotificationService.instance.show(title, body, problem: problem);
    _ref
        .read(aiInboxProvider.notifier)
        .pushAlert('$title : $body', problem: problem);
  }

  Future<String?> _askAi(String type, String factual, MachineState s) async {
    try {
      final settings = _ref.read(aiAgentSettingsProvider);
      if (!settings.enabled) return null;
      final key = await _ref.read(aiAgentSettingsProvider.notifier).readApiKey();
      if (key == null || key.isEmpty) return null;

      final model = _ref.read(aiModelProvider).active.id;
      final service = AiAgentService(
          apiKey: key, model: model, client: CellularHttpClient());
      final activity = formatRecentActivity(_ref.read(activityLogProvider), n: 8);

      final prompt = 'ÉVÈNEMENT CRITIQUE sur une CNC 5 axes (trunnion, FluidNC). '
          'Type : $type. $factual\n'
          'État machine : statut=${s.status.name}, alarme=${s.alarmCode}, '
          'temp=${s.coreTemp.toStringAsFixed(0)}°C, '
          'wPos=${s.wPos.map((v) => v.toStringAsFixed(1)).toList()}, '
          'ForceGuard=${s.forceGuardActive}.\n'
          'Dernières actions:\n$activity\n\n'
          'En 2 phrases MAXIMUM : cause probable, puis ce que l\'opérateur doit '
          'faire MAINTENANT. Ton urgent et concret. Pas de markdown, pas de '
          'salutation.';

      final resp = await service.sendMessages(
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        functionDeclarations: const [],
      );
      service.dispose();
      _ref
          .read(aiUsageProvider.notifier)
          .recordRequest(model, tokens: resp.totalTokens);
      return resp.text;
    } catch (_) {
      // IA indisponible (clé/quota/réseau) → on garde la notif factuelle.
      return null;
    }
  }
}

final criticalEventWatcherProvider =
    Provider<CriticalEventWatcher>((ref) => CriticalEventWatcher(ref));
