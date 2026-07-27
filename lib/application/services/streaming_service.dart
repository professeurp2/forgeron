import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/fluidnc/fluidnc_connection.dart';

/// Service de Streaming Industriel avec Algorithme de Character-Counting (GRBL/FluidNC).
/// Garantit que le buffer de l'ESP32 est saturé sans jamais déborder.
///
/// Le ForceGuard n'est PAS appliqué ici : les lignes sont déjà bridées en amont
/// par le [StreamingController], afin que le comptage d'octets porte exactement
/// sur ce qui part sur le fil.
class GCodeStreamingService {
  final FluidNCConnection _connection;

  // Configuration du buffer GRBL (FluidNC)
  static const int _maxRxBufferSize = 127;

  final Queue<int> _sentByteCounts = Queue<int>();
  final Queue<String> _pendingLines = Queue<String>();
  final Queue<int> _pendingLineIndices = Queue<int>();
  final Queue<int> _sentLineIndices = Queue<int>();
  int _bytesInFlight = 0;
  bool _isPaused = false;

  /// Callback appelé quand toutes les lignes ont été acquittées par l'ESP32.
  void Function()? _onComplete;

  /// Callback appelé à chaque ligne acquittée par l'ESP32, pour l'UI.
  void Function(int index)? _onProgress;

  /// Callback appelé quand le flux se bloque (aucun acquittement).
  /// SÉCURITÉ : sans lui, l'UI resterait indéfiniment en « RUN ».
  void Function(String reason)? _onStall;

  // Watchdog pour la résilience réseau
  Timer? _watchdogTimer;
  static const Duration _watchdogTimeout = Duration(seconds: 2);

  GCodeStreamingService(this._connection);

  /// Ajoute des lignes de G-Code au flux de streaming.
  /// [onComplete] est appelé quand la dernière ligne reçoit son 'ok' de l'ESP32.
  /// [onStall] est appelé si l'ESP32 cesse d'acquitter.
  void streamLines(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int)? onProgress,
    void Function(String reason)? onStall,
  }) {
    // ── Réinitialisation complète de l'état précédent ──────────────────────
    // BUG FIX: sans ça, _isPaused / _bytesInFlight / _sentByteCounts
    // gardaient les valeurs du run précédent et bloquaient silencieusement.
    _resetBuffers();
    _onComplete = onComplete;
    _onProgress = onProgress;
    _onStall = onStall;
    // ───────────────────────────────────────────────────────────────────────

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final clean = line.split(';')[0].trim();
      if (clean.isNotEmpty) {
        _pendingLines.add('$clean\n');
        _pendingLineIndices.add(i);
      }
    }
    debugPrint('[Streaming] 🚀 Démarrage : ${_pendingLines.length} lignes à envoyer.');
    _attemptSend();
  }

  /// Vide toutes les files et remet le compteur d'octets à zéro.
  void _resetBuffers() {
    _isPaused = false;
    _pendingLines.clear();
    _pendingLineIndices.clear();
    _sentLineIndices.clear();
    _sentByteCounts.clear();
    _bytesInFlight = 0;
    _watchdogTimer?.cancel();
  }

  /// Appelé par le repository lors de la réception d'un 'ok' ou 'error:'
  void handleAck() {
    if (_sentByteCounts.isNotEmpty) {
      final lastSentSize = _sentByteCounts.removeFirst();
      _bytesInFlight -= lastSentSize;
      if (_sentLineIndices.isNotEmpty) {
        final ackedIndex = _sentLineIndices.removeFirst();
        _onProgress?.call(ackedIndex);
      }
      _attemptSend();
    }

    // ── Détection de fin de streaming ──────────────────────────────────────
    // Toutes les lignes ont été envoyées ET acquittées par l'ESP32.
    if (_pendingLines.isEmpty && _bytesInFlight == 0 && _sentByteCounts.isEmpty) {
      _watchdogTimer?.cancel();
      debugPrint('[Streaming] ✅ Toutes les lignes acquittées — streaming terminé.');
      final cb = _onComplete;
      _onComplete = null;
      cb?.call();
      return;
    }

    // ── Le watchdog doit rester armé TANT QUE des octets sont en vol ───────
    // BUG FIX: auparavant l'acquittement se contentait d'annuler le timer, qui
    // n'était réarmé que si _attemptSend() envoyait effectivement une ligne.
    // En fin de programme (tout envoyé, derniers 'ok' en attente), plus rien
    // ne surveillait : un blocage machine passait totalement inaperçu.
    if (_bytesInFlight > 0) {
      _startWatchdog();
    } else {
      _watchdogTimer?.cancel();
    }
  }

  void _attemptSend() {
    if (_isPaused) return;

    while (_pendingLines.isNotEmpty) {
      final line = _pendingLines.first;
      final lineSize = line.length;

      // Algorithme Character-Counting : on ne dépasse jamais 127 octets
      if (_bytesInFlight + lineSize <= _maxRxBufferSize) {
        _pendingLines.removeFirst();
        final originalIndex = _pendingLineIndices.removeFirst();
        _sentLineIndices.add(originalIndex);

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
    _watchdogTimer = Timer(_watchdogTimeout, _handleStall);
  }

  /// Gère une perte de synchronisation ou de réseau.
  void _handleStall() {
    _isPaused = true;
    _connection.sendRaw('?');
    const reason = 'Aucun acquittement de l\'ESP32 depuis 2 s';
    debugPrint('[Streaming] ⏸ SUSPENDU — $reason');
    _onStall?.call(reason);
  }

  void resume() {
    _isPaused = false;
    _attemptSend();
  }

  void pause() {
    _isPaused = true;
  }

  /// Purge le flux (arrêt manuel, E-STOP, ou perte de liaison).
  ///
  /// CRITIQUE : doit être appelé à chaque déconnexion. Sans ça, _bytesInFlight
  /// et _sentByteCounts gardent les valeurs d'avant la coupure ; à la
  /// reconnexion, le character-counting est désynchronisé avec le buffer RX
  /// (vidé) de l'ESP32 → débordement → caractères perdus → G-code corrompu.
  void stop() {
    _resetBuffers();
    _onStall = null;
    // Notifier l'UI que le streaming est terminé (arrêt manuel / coupure)
    final cb = _onComplete;
    _onComplete = null;
    cb?.call();
  }

  void dispose() {
    _watchdogTimer?.cancel();
  }
}
