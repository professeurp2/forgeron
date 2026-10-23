import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'di_providers.dart';
import 'streaming_provider.dart';

/// Une action machine horodatée (manuelle opérateur OU initiée par l'IA).
class ActivityEntry {
  final DateTime time;
  final String text;
  const ActivityEntry(this.time, this.text);
}

class ActivityLog {
  final List<ActivityEntry> entries;
  const ActivityLog(this.entries);
}

/// Journal d'activité de la machine : écoute le trafic (TX), interprète les
/// commandes en actions lisibles, et garde un tampon roulant. Alimente le
/// contexte de l'agent IA (sécurité/optimisation) sans appel API supplémentaire.
class ActivityLogNotifier extends StateNotifier<ActivityLog> {
  final Ref _ref;
  StreamSubscription<String>? _sub;
  static const _max = 60;

  ActivityLogNotifier(this._ref) : super(const ActivityLog([])) {
    final repo = _ref.read(machineRepositoryProvider);
    _sub = repo.trafficStream.listen(_onTraffic);
    // Bornes de programme (au lieu de logger chaque ligne streamée).
    _ref.listen<bool>(streamingProvider, (prev, next) {
      if (next && prev != true) {
        _add('▶ Programme lancé (exécution)');
      } else if (!next && prev == true) {
        _add('■ Programme terminé / arrêté');
      }
    });
  }

  void _onTraffic(String msg) {
    if (!msg.startsWith('TX:')) return;
    // Pendant le streaming, on ne journalise pas chaque ligne (flood).
    if (_ref.read(streamingProvider)) return;
    final action = _interpret(msg.substring(3).trim());
    if (action != null) _add(action);
  }

  /// Ajout d'un évènement sémantique (ex. depuis l'UI).
  void log(String text) => _add(text);

  void _add(String text) {
    final list = [...state.entries, ActivityEntry(DateTime.now(), text)];
    if (list.length > _max) list.removeRange(0, list.length - _max);
    state = ActivityLog(list);
  }

  /// Interprète une commande TX en action lisible, ou `null` si à ignorer.
  String? _interpret(String d) {
    if (d.isEmpty) return null;
    if (d == '?' || d == '\x85') return null; // heartbeat / annulation jog
    final first = d.codeUnitAt(0);
    if (first >= 0x90 && first <= 0x9B) return 'Override modifié';
    if (d == '~') return 'Cycle start (reprise)';
    if (d == '!') return 'Pause (feed hold)';
    if (d.contains('')) return 'Soft reset (arrêt)';

    final u = d.toUpperCase();
    if (u.startsWith('\$J=')) {
      final j = d.substring(3).replaceAll(RegExp(r'G9[01]|G21'), '').trim();
      return 'Jog manuel : $j';
    }
    if (u.startsWith('\$H')) return 'Homing des axes (\$H)';
    if (u.startsWith('\$BYE')) return 'Redémarrage ESP32';
    if (u == '\$X') return 'Déverrouillage alarme (\$X)';
    if (u.startsWith('\$/')) return 'Réglage FluidNC : $d';
    if (u.startsWith('\$') || u.startsWith('[ESP')) return null; // requêtes
    if (RegExp(r'^G5[4-9]').hasMatch(u)) return 'Changement WCS → ${u.substring(0, 3)}';
    if (u.contains('G10 L20')) return 'Origine pièce posée (G10 L20) : $d';
    if (u.startsWith('M3') || u.startsWith('M4')) return 'Broche ON ($d)';
    if (u.startsWith('M5')) return 'Broche OFF';
    if (u.startsWith('M7') || u.startsWith('M8')) return 'Arrosage ON';
    if (u.startsWith('M9')) return 'Arrosage OFF';
    if (RegExp(r'^(G9[01]\s+)?G[0-3]\b').hasMatch(u)) return 'Déplacement : $d';
    return 'Commande : $d';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final activityLogProvider =
    StateNotifierProvider<ActivityLogNotifier, ActivityLog>(
        (ref) => ActivityLogNotifier(ref));

/// Formate les [n] dernières actions pour injection dans le contexte IA.
String formatRecentActivity(ActivityLog log, {int n = 15}) {
  if (log.entries.isEmpty) return 'Aucune action récente enregistrée.';
  final recent =
      log.entries.length > n ? log.entries.sublist(log.entries.length - n) : log.entries;
  String two(int v) => v.toString().padLeft(2, '0');
  return recent
      .map((e) =>
          '${two(e.time.hour)}:${two(e.time.minute)}:${two(e.time.second)} — ${e.text}')
      .join('\n');
}
