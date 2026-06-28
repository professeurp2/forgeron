import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/fluidnc/fluidnc_connection.dart';
import 'force_guard_service.dart';

/// Service de Streaming Industriel avec Algorithme de Character-Counting (GRBL/FluidNC).
/// Garantit que le buffer de l'ESP32 est saturé sans jamais déborder.
class GCodeStreamingService {
  final FluidNCConnection _connection;

  /// Service ForceGuard — bride les efforts selon le mode d'usinage actif.
  ForceGuardService? _forceGuard;

  /// Injecte le ForceGuard (appelé lors du changement de mode d'usinage)
  void setForceGuard(ForceGuardService? guard) => _forceGuard = guard;

  // Configuration du buffer GRBL (FluidNC)
  static const int _maxRxBufferSize = 127;

  final Queue<int> _sentByteCounts = Queue<int>();
  final Queue<String> _pendingLines = Queue<String>();
  int _bytesInFlight = 0;
  bool _isPaused = false;

  /// Callback appelé quand toutes les lignes ont été acquittées par l'ESP32.
  void Function()? _onComplete;

  // Watchdog pour la résilience réseau
  Timer? _watchdogTimer;
  static const Duration _watchdogTimeout = Duration(seconds: 2);

  GCodeStreamingService(this._connection);

  /// Ajoute des lignes de G-Code au flux de streaming.
  /// [onComplete] est appelé quand la dernière ligne reçoit son 'ok' de l'ESP32.
  void streamLines(List<String> lines, {void Function()? onComplete}) {
    // ── Réinitialisation complète de l'état précédent ──────────────────────
    // BUG FIX: sans ça, _isPaused / _bytesInFlight / _sentByteCounts
    // gardaient les valeurs du run précédent et bloquaient silencieusement.
    _isPaused = false;
    _pendingLines.clear();
    _sentByteCounts.clear();
    _bytesInFlight = 0;
    _watchdogTimer?.cancel();
    _onComplete = onComplete;
    // ───────────────────────────────────────────────────────────────────────

    for (var line in lines) {
      final clean = line.split(';')[0].trim();
      if (clean.isNotEmpty) {
        _pendingLines.add('$clean\n');
      }
    }
    debugPrint('[Streaming] 🚀 Démarrage : ${_pendingLines.length} lignes à envoyer.');
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

    // ── Détection de fin de streaming ──────────────────────────────────────
    // Toutes les lignes ont été envoyées ET acquittées par l'ESP32.
    if (_pendingLines.isEmpty && _bytesInFlight == 0 && _sentByteCounts.isEmpty) {
      debugPrint('[Streaming] ✅ Toutes les lignes acquittées — streaming terminé.');
      final cb = _onComplete;
      _onComplete = null;
      cb?.call();
    }
  }

  void _attemptSend() {
    if (_isPaused) return;

    while (_pendingLines.isNotEmpty) {
      var line = _pendingLines.first;

      // ── ForceGuard : bridage automatique avant envoi ──
      if (_forceGuard != null) {
        line = _forceGuard!.processLine(line);
      }

      final lineSize = line.length;

      // Algorithme Character-Counting : on ne dépasse jamais 128 octets
      if (_bytesInFlight + lineSize <= _maxRxBufferSize) {
        _pendingLines.removeFirst();
        _bytesInFlight += lineSize;
        _sentByteCounts.add(lineSize);
        _connection.sendRaw(line);
        _startWatchdog();
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
    _connection.sendRaw('?');
    _isPaused = true;
    debugPrint('[Streaming] ⏸ Suspendu — vérification liaison ESP32...');
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
    _isPaused = false;
    _watchdogTimer?.cancel();
    // Notifier l'UI que le streaming est terminé (arrêt manuel)
    final cb = _onComplete;
    _onComplete = null;
    cb?.call();
  }

  void dispose() {
    _watchdogTimer?.cancel();
  }
}
