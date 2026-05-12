import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';

/// Type d'entrée de log
enum LogType { tx, rx, system, alarm }

/// Modèle pour une entrée de journal diagnostic
class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String message;

  LogEntry(this.type, this.message) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
    't': timestamp.toIso8601String(),
    'type': type.name,
    'msg': message,
  };
}

/// Service de Logging Industriel (Buffer Circulaire).
/// Intercepte tout le trafic pour analyse post-mortem.
class LoggerService extends StateNotifier<List<LogEntry>> {
  final Ref _ref;
  static const int _maxEntries = 5000;
  final ListQueue<LogEntry> _buffer = ListQueue<LogEntry>(_maxEntries);

  LoggerService(this._ref) : super([]) {
    // Écoute automatique de tout le trafic (TX/RX) via le repository
    _ref.read(machineRepositoryProvider).trafficStream.listen((data) {
      if (data.startsWith('TX:')) {
        log(LogType.tx, data.substring(3).trim());
      } else if (data.startsWith('RX:')) {
        final msg = data.substring(3).trim();
        if (msg.startsWith('ALARM:')) {
          log(LogType.alarm, msg);
        } else {
          log(LogType.rx, msg);
        }
      }
    });
  }

  void log(LogType type, String message) {
    // Ignorer les requêtes de statut répétitives pour ne pas polluer le buffer
    if (message == '?' || message.startsWith('<')) return;

    final entry = LogEntry(type, message);
    if (_buffer.length >= _maxEntries) {
      _buffer.removeFirst();
    }
    _buffer.add(entry);
    
    // On met à jour le state pour l'UI (ex: les 100 derniers)
    state = _buffer.toList().reversed.take(100).toList().reversed.toList();
  }

  /// Génère un dump complet du système pour diagnostic technique.
  String generateDiagnosticDump() {
    final machine = _ref.read(machineRepositoryProvider).currentState;
    
    final dump = {
      'system': {
        'app': 'Forgeron CNC',
        'version': '1.0.0-industrial',
        'platform': defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'machine_state': {
        'status': machine.status.name,
        'mPos': machine.mPos,
        'wco': machine.wco,
        'modal': machine.activeWCS,
        'temp': machine.coreTemp,
      },
      'logs': _buffer.map((e) => e.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(dump);
  }

  void clear() {
    _buffer.clear();
    state = [];
  }
}

final loggerServiceProvider = StateNotifierProvider<LoggerService, List<LogEntry>>((ref) {
  return LoggerService(ref);
});
