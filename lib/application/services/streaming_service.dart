import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/fluidnc/fluidnc_connection.dart';

/// Service de Streaming Industriel avec Algorithme de Character-Counting (GRBL/FluidNC).
/// Garantit que le buffer de l'ESP32 est saturé sans jamais déborder.
class GCodeStreamingService {
  final FluidNCConnection _connection;
  
  // Configuration du buffer GRBL (FluidNC)
  static const int _maxRxBufferSize = 127;
  
  final Queue<int> _sentByteCounts = Queue<int>();
  final Queue<String> _pendingLines = Queue<String>();
  int _bytesInFlight = 0;
  bool _isPaused = false;
  
  // Watchdog pour la résilience réseau
  Timer? _watchdogTimer;
  static const Duration _watchdogTimeout = Duration(seconds: 2);

  GCodeStreamingService(this._connection);

  /// Ajoute des lignes de G-Code au flux de streaming
  void streamLines(List<String> lines) {
    for (var line in lines) {
      final clean = line.split(';')[0].trim();
      if (clean.isNotEmpty) {
        _pendingLines.add('$clean\n');
      }
    }
    _attemptSend();
  }

  /// Appelé par le repository lors de la réception d'un 'ok' ou 'error:'
  void handleAck() {
    _resetWatchdog();
    
    if (_sentByteCounts.isNotEmpty) {
      final lastSentSize = _sentByteCounts.removeFirst();
      _bytesInFlight -= lastSentSize;
      _attemptSend();
    }
  }

  void _attemptSend() {
    if (_isPaused) return;

    while (_pendingLines.isNotEmpty) {
      final line = _pendingLines.first;
      final lineSize = line.length;

      // Algorithme Character-Counting : on ne dépasse jamais 128 octets
      if (_bytesInFlight + lineSize <= _maxRxBufferSize) {
        _pendingLines.removeFirst();
        _bytesInFlight += lineSize;
        _sentByteCounts.add(lineSize);
        
        _connection.sendRaw(line);
        _startWatchdog(); // Armer le watchdog après envoi
      } else {
        // Buffer FluidNC plein, on attend le prochain 'ok'
        break;
      }
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(_watchdogTimeout, () {
      debugPrint('⚠️ STREAMING WATCHDOG: Aucun acquittement depuis 2s.');
      _handleStall();
    });
  }

  void _resetWatchdog() {
    _watchdogTimer?.cancel();
  }

  /// Gère une perte de synchronisation ou de réseau
  void _handleStall() {
    // 1. Demander l'état immédiat de la machine via '?'
    _connection.sendRaw('?');
    
    // 2. Mettre le streaming en pause pour sécurité
    _isPaused = true;
    
    // 3. Envoyer une alerte (peut être interceptée par l'UI)
    debugPrint('Streaming suspendu : Vérification de la liaison ESP32...');
  }

  void resume() {
    _isPaused = false;
    _attemptSend();
  }

  void pause() {
    _isPaused = true;
  }

  void stop() {
    _pendingLines.clear();
    _sentByteCounts.clear();
    _bytesInFlight = 0;
    _watchdogTimer?.cancel();
  }
}
