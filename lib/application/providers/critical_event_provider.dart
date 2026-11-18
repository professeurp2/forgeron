import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/esp32_reboot_event.dart';
import '../../domain/models/machine_state.dart';
import '../../core/i18n/app_language.dart';
import '../../core/utils/grbl_alarm_catalog.dart';
import '../../core/net/cellular_http_client.dart';
import '../services/ai_agent_service.dart';
import '../services/local_ai_agent_service.dart';
import '../services/notification_service.dart';
import 'machine_provider.dart';
import 'ai_agent_settings_provider.dart';
import 'ai_model_provider.dart';
import 'ai_usage_provider.dart';
import 'ai_inbox_provider.dart';
import 'activity_log_provider.dart';
import 'controller_memory_provider.dart';
import 'di_providers.dart';
import 'backoffice_provider.dart';

/// Veilleur d'évènements CRITIQUES temps réel : alarme machine (`ALARM:1..18`),
/// redémarrage intempestif de la carte ESP32 (Brownout broche 775, Watchdog,
/// coupure alim ATX), arrêt d'urgence (`GPIO 15`), et surchauffe.
///
/// Sur front montant :
/// 1. Envoie une notification factuelle et matérielle immédiate (< 50 ms).
/// 2. Sollicite l'Agent IA (en mode **Local Ollama** ou **Cloud Gemini**) avec
///    la mémoire complète du contrôleur et dans la langue de l'opérateur.
class CriticalEventWatcher {
  final Ref _ref;

  MachineStatus? _lastStatus;
  bool _lastEstop = false;
  bool _tempAlerted = false;
  int _lastRebootCount = 0;
  List<bool> _lastLimits = const [false, false, false, false, false];
  final List<DateTime?> _lastLimitNotify = List<DateTime?>.filled(5, null);
  DateTime? _lastAiCall;
  final Map<String, DateTime> _lastNotifyByType = {};

  static const _axisNames = ['X', 'Y', 'Z', 'A', 'C'];

  static const double _tempThreshold = 70.0; // °C
  static const Duration _aiCooldown = Duration(seconds: 45);
  static const Duration _limitNotifyCooldown = Duration(seconds: 10);
  static const Duration _sameTypeCooldown = Duration(seconds: 20);

  CriticalEventWatcher(this._ref) {
    _ref.listen<AsyncValue<MachineState>>(machineStateProvider, (prev, next) {
      final s = next.valueOrNull;
      if (s != null) _check(s);
    });

    // Surveillance temps réel des redémarrages de la carte ESP32 depuis toute fenêtre
    _ref.listen<ControllerMemoryState>(controllerMemoryProvider, (prev, next) {
      if (next.esp32RebootCount > _lastRebootCount &&
          next.lastRebootEvent != null) {
        _lastRebootCount = next.esp32RebootCount;
        _onEsp32Reboot(next.lastRebootEvent!);
      }
    });
  }

  void _onEsp32Reboot(Esp32RebootEvent event) {
    MachineState currentState;
    try {
      currentState = _ref.read(machineRepositoryProvider).currentState;
    } catch (_) {
      currentState = const MachineState(status: MachineStatus.alarm);
    }
    _trigger(
      event.title,
      '${event.factualSummary} ${event.recommendedAction}',
      currentState,
    );
  }

  void _check(MachineState s) {
    // Alarme machine (front montant).
    if (s.status == MachineStatus.alarm &&
        _lastStatus != MachineStatus.alarm) {
      final info = GrblAlarmCatalog.lookup(s.alarmCode);
      _trigger(
        info == null ? 'ALARME MACHINE' : 'ALARME ${info.code} — ${info.title}',
        info == null
            ? 'La machine est passée en ALARME.'
            : '${info.cause} ${info.action}'
                '${info.positionLost ? ' Position machine perdue : prise d\'origine obligatoire.' : ''}',
        s,
      );
    }

    // Arrêt d'urgence (front montant).
    if (s.emergencyTriggered && !_lastEstop) {
      _trigger(
        'ARRÊT D\'URGENCE',
        'Un arrêt d\'urgence a été déclenché (boucle NF GPIO 15 ouverte).',
        s,
      );
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
        _ref
            .read(activityLogProvider.notifier)
            .log('Fin de course $axis déclenchée (statut ${s.status.name})');

        if (s.status == MachineStatus.home) continue;

        final now = DateTime.now();
        final last = _lastLimitNotify[i];
        if (last != null && now.difference(last) < _limitNotifyCooldown) {
          continue;
        }
        _lastLimitNotify[i] = now;

        if (s.status == MachineStatus.run) {
          _trigger(
            'FIN DE COURSE $axis',
            'Fin de course $axis déclenchée PENDANT un mouvement (hard limit) — '
                'la machine doit être stoppée immédiatement.',
            s,
          );
        } else {
          _notify('Fin de course $axis', 'Fin de course $axis active.',
              problem: false);
        }
      }
    }
    _lastLimits = List<bool>.from(s.limitSwitches);

    if (s.status != MachineStatus.offline) {
      _lastStatus = s.status;
      _lastEstop = s.emergencyTriggered;
    }
  }

  Future<void> _trigger(String type, String factual, MachineState s) async {
    final now = DateTime.now();
    final lastSame = _lastNotifyByType[type];
    if (lastSame != null && now.difference(lastSame) < _sameTypeCooldown) {
      return;
    }
    _lastNotifyByType[type] = now;

    // 1) Notification factuelle IMMÉDIATE (sans attendre l'IA).
    _notify(type, factual, problem: true);
    _audit('veilleur.alerte', '$type : $factual',
        severity: BackofficeSeverity.critical,
        details: {
          'type': type,
          'statut': s.status.name,
          'alarme': ?s.alarmCode,
          'temperature': s.coreTemp,
        });

    // 2) Appel IA ponctuel (compatible Local Ollama & Cloud Gemini).
    if (_lastAiCall != null && now.difference(_lastAiCall!) < _aiCooldown) {
      _audit('veilleur.ia_differe', 'Diagnostic IA non demandé (appel récent, délai de garde)',
          severity: BackofficeSeverity.notice, details: {'type': type});
      return;
    }
    _lastAiCall = now;

    final clock = Stopwatch()..start();
    final advice = await _askAi(type, factual, s);
    final text = advice?.trim();
    _audit(
      'veilleur.ia',
      text == null || text.isEmpty
          ? 'Diagnostic IA sur « $type » : aucune réponse (IA désactivée, sans clé ou injoignable)'
          : 'Diagnostic IA sur « $type » en ${clock.elapsedMilliseconds} ms : ${text.length > 140 ? '${text.substring(0, 139)}…' : text}',
      severity: BackofficeSeverity.notice,
      details: {
        'type': type,
        'latence_ms': clock.elapsedMilliseconds,
        'reponse': ?text == null || text.isEmpty ? null : text,
        'modele': ?_lastModel,
      },
    );
    if (text != null && text.isNotEmpty) {
      _notify('$type — Assistant IA', text, problem: true);
    }
  }

  String? _lastModel;

  void _audit(String kind, String summary,
      {BackofficeSeverity severity = BackofficeSeverity.info,
      Map<String, dynamic> details = const {}}) {
    try {
      _ref.read(backofficeBusProvider.notifier).emit(
            source: BackofficeSource.veilleur,
            kind: kind,
            summary: summary,
            severity: severity,
            details: details,
            origin: BackofficeOrigin.veilleur,
          );
    } catch (_) {/* le backoffice n'arrête jamais le veilleur */}
  }

  void _notify(String title, String body, {bool problem = false}) {
    NotificationService.instance.show(title, body, problem: problem);
    _ref
        .read(aiInboxProvider.notifier)
        .pushAlert('$title : $body', problem: problem);
  }

  Future<String?> _askAi(String type, String factual, MachineState s) async {
    AiBackend? service;
    String modelId = '';
    try {
      final settings = _ref.read(aiAgentSettingsProvider);
      if (!settings.enabled) return null;

      // Support prioritaire du serveur IA local (Ollama / forgeron-qwen)
      if (settings.localBaseUrl.trim().isNotEmpty) {
        modelId = settings.localModel;
        _lastModel = modelId;
        service = LocalAiAgentService(
          baseUrl: LocalAiAgentService.normalizeBaseUrl(settings.localBaseUrl),
          model: modelId,
          timeout: const Duration(seconds: 25),
        );
      } else {
        final key =
            await _ref.read(aiAgentSettingsProvider.notifier).readApiKey();
        if (key == null || key.isEmpty) return null;
        modelId = _ref.read(aiModelProvider).active.id;
        _lastModel = modelId;
        service = AiAgentService(
          apiKey: key,
          model: modelId,
          client: CellularHttpClient(),
        );
      }
      final activity = formatRecentActivity(_ref.read(activityLogProvider), n: 8);
      final memoryBlock = _ref.read(controllerMemoryProvider).toSystemPromptBlock();
      final aiLang = _ref.read(effectiveAiLanguageProvider);

      final prompt = 'ÉVÈNEMENT CRITIQUE sur la CNC 5 axes Forgeron (Trunnion, FluidNC).\n'
          'Type : $type. $factual\n'
          'État machine : statut=${s.status.name}, alarme=${s.alarmCode}, '
          'temp=${s.coreTemp.toStringAsFixed(0)}°C, '
          'wPos=${s.wPos.map((v) => v.toStringAsFixed(1)).toList()}, '
          'ForceGuard=${s.forceGuardActive}.\n'
          '$memoryBlock\n'
          'Dernières actions:\n$activity\n\n'
          'En 2 phrases MAXIMUM : indique la cause matérielle probable (broche GPIO/alimentation/axe) '
          'et ce que l\'opérateur doit faire MAINTENANT depuis sa fenêtre active. '
          'Ton urgent et concret. Pas de markdown.\n'
          '${aiLang.trailingPromptAnchor(detectedLanguageCode: aiLang.isAuto ? "fr" : aiLang.id)}';

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
        systemPrompt: aiLang.promptDirective,
      );
      service.dispose();
      _ref
          .read(aiUsageProvider.notifier)
          .recordRequest(modelId, tokens: resp.totalTokens);
      return resp.text;
    } catch (_) {
      service?.dispose();
      return null;
    }
  }
}

final criticalEventWatcherProvider =
    Provider<CriticalEventWatcher>((ref) => CriticalEventWatcher(ref));
