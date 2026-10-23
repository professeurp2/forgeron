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
  bool _active = false;

  /// Vrai tant qu'un programme est en cours de streaming (entre [streamLines] et
  /// [stop] ou la fin). Le repository s'en sert pour n'attribuer les 'ok'/'error'
  /// AU STREAMING que quand il est actif : sinon un 'ok' hors-bande (typiquement
  /// la réponse au `$X` de déverrouillage après une alarme) serait compté comme
  /// l'acquittement d'une ligne — ce qui désynchronise le comptage d'octets ET
  /// relance l'envoi de la ligne suivante (retour dans la butée → re-alarme).
  bool get isStreaming => _active;

  /// Callback appelé quand toutes les lignes ont été acquittées par l'ESP32.
  void Function()? _onComplete;

  /// Callback appelé à chaque ligne acquittée par l'ESP32, pour l'UI.
  void Function(int index)? _onProgress;

  /// Callback appelé quand le flux se bloque (aucun acquittement).
  /// SÉCURITÉ : sans lui, l'UI resterait indéfiniment en « RUN ».
  void Function(String reason)? _onStall;

  // Watchdog pour la résilience réseau.
  // Réarmé par [notifyActivity] dès que la machine donne signe de vie
  // (mouvement en cours), donc un mouvement long — pendant lequel aucune
  // nouvelle ligne n'est acquittée — ne déclenche PAS de faux blocage.
  //
  // 5 s et non 3 : le heartbeat réclame un statut toutes les 2 s, ce qui ne
  // laissait qu'UNE seconde de marge. Sur l'AP de l'ESP32 un rapport en retard
  // suffisait alors à déclarer un faux blocage, surtout juste après la
  // connexion quand la liaison n'est pas encore régulière. Le rôle de sécurité
  // est le même à 5 s : si la carte meurt, plus aucun statut n'arrive.
  Timer? _watchdogTimer;
  static const Duration _watchdogTimeout = Duration(seconds: 5);

  /// Temporisations (`G4 P…`) des lignes envoyées et pas encore acquittées.
  ///
  /// Une temporisation est un silence LÉGITIME : la carte n'acquitte rien
  /// pendant toute sa durée et, le planner étant vide, elle peut se déclarer
  /// `Idle` — donc [notifyActivity] ne réarme rien. Un `G4 P3` durait
  /// exactement le timeout du watchdog : le démarrage échouait une fois sur
  /// deux, au hasard de l'arrivée du rapport d'état. Le watchdog doit donc
  /// savoir ce qu'il vient d'envoyer et s'accorder ce délai en plus.
  ///
  /// Le cas n'a rien d'exotique : l'adaptateur injecte lui-même un `G4` de
  /// montée en régime après chaque changement d'outil.
  final Queue<int> _sentDwellMs = Queue<int>();
  int _dwellMsInFlight = 0;

  /// `G4 P<secondes>` (GRBL/FluidNC). `G4` est exigé devant : sans lui, le
  /// `S1000` d'un `M3 S1000` passerait pour une temporisation de 1000 s.
  static final RegExp _dwellRegex =
      RegExp(r'G0?4(?:\s|\b)[^;(]*?\bP\s*([0-9]*\.?[0-9]+)', caseSensitive: false);

  /// Durée de la temporisation portée par [line], en millisecondes (0 si aucune).
  @visibleForTesting
  static int dwellMsOf(String line) {
    final m = _dwellRegex.firstMatch(line);
    if (m == null) return 0;
    final seconds = double.tryParse(m.group(1)!) ?? 0;
    // Garde-fou : une valeur aberrante ne doit pas désarmer le watchdog pour
    // de bon. Au-delà d'une minute, on plafonne.
    return (seconds.clamp(0, 60) * 1000).round();
  }

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
    _active = true;
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
    _active = false;
    _pendingLines.clear();
    _pendingLineIndices.clear();
    _sentLineIndices.clear();
    _sentByteCounts.clear();
    _bytesInFlight = 0;
    _sentDwellMs.clear();
    _dwellMsInFlight = 0;
    _watchdogTimer?.cancel();
  }

  /// Appelé par le repository lors de la réception d'un 'ok' ou 'error:'
  void handleAck() {
    if (_sentByteCounts.isNotEmpty) {
      final lastSentSize = _sentByteCounts.removeFirst();
      _bytesInFlight -= lastSentSize;
      if (_sentDwellMs.isNotEmpty) _dwellMsInFlight -= _sentDwellMs.removeFirst();
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
      _active = false;
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
        final dwellMs = dwellMsOf(line);
        _sentDwellMs.add(dwellMs);
        _dwellMsInFlight += dwellMs;
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
    // Le silence d'une temporisation en cours est légitime : on lui accorde sa
    // durée EN PLUS du timeout, sinon un `G4` plus long que celui-ci passe
    // pour un blocage.
    final budget = Duration(
      milliseconds: _watchdogTimeout.inMilliseconds + _dwellMsInFlight,
    );
    _watchdogTimer = Timer(budget, _handleStall);
  }

  /// Signal « la machine est vivante et bouge » (rapport de statut Run/Jog/Home
  /// reçu). Réarme le watchdog pendant un mouvement long : la carte n'acquitte
  /// pas de nouvelle ligne tant que son buffer de planification est plein, mais
  /// elle avance — ce n'est donc PAS un blocage. Sans ça, tout mouvement plus
  /// long que le timeout suspendait le programme à tort.
  void notifyActivity() {
    if (_isPaused) return;
    if (_bytesInFlight > 0) _startWatchdog();
  }

  /// Gère une perte de synchronisation ou de réseau (aucun acquittement NI
  /// mouvement pendant le timeout → machine réellement muette/bloquée).
  void _handleStall() {
    _isPaused = true;
    _connection.sendRaw('?');
    const reason =
        'Aucun acquittement ni mouvement de l\'ESP32 — le programme est interrompu';
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
