import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import 'fluidnc_connection.dart';
import 'grbl_parser.dart';

/// Repository FluidNC complet pour machine CNC 5-axes Trunnion
///
/// Gère :
///  - Polling status 5 Hz (? toutes les 200ms)
///  - Queue de commandes avec contrôle de flux ok/error
///  - Jog typé avec cancel automatique (0x85)
///  - Homing séquencé par axe
///  - Overrides temps réel via chars ASCII
class FluidNCMachineRepository implements MachineRepository {
  final FluidNCConnection _connection;
  final _stateController = StreamController<MachineState>.broadcast();
  MachineState _currentState = const MachineState(status: MachineStatus.offline);

  // ── Polling & timer ──────────────────────────────────────────────────────
  Timer? _pollingTimer;

  // ── Queue de commandes (contrôle de flux GRBL) ───────────────────────────
  // GRBL accepte jusqu'à 128 octets dans son buffer RX.
  // On attend un 'ok' ou 'error' avant d'envoyer la suivante.
  final _cmdQueue = Queue<String>();
  final _sentCommands = Queue<int>(); // Stocke la longueur des commandes en attente d'ok
  int _bufferCount = 0; // Octets actuellement dans le buffer FluidNC
  static const int _maxBufferSize = 127; // Limite GRBL/FluidNC

  bool _isJogging = false;
  bool _waitingForOk = false; // Utilisé pour compatibilité et logique simple

  FluidNCMachineRepository(this._connection) {
    _connection.connect();

    _connection.messages.listen(_handleMessage);
    _connection.status.listen((isConnected) {
      if (!isConnected) {
        _currentState = _currentState.copyWith(status: MachineStatus.offline);
        _stateController.add(_currentState);
        _bufferCount = 0;
        _cmdQueue.clear();
        _sentCommands.clear();
      } else {
        // Séquence d'initialisation "Ingénieuse"
        Future.delayed(const Duration(milliseconds: 500), () {
          _connection.send('\$G\n');   // État modal
          _connection.send('\$#\n');   // Offsets de travail (G54-G59)
          _connection.send('[ESP110]\n'); // WiFi info
        });
      }
    });

    // Polling status à 5 Hz (200ms)
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_connection.isConnected) {
        _connection.send('?'); // Commande temps réel, pas de \n requis
      }
    });
  }

  // ── Handler de messages entrants ─────────────────────────────────────────
  void _handleMessage(String message) {
    final trimmed = message.trim();

    // Contrôle de flux : déverrouiller le buffer sur ok/error
    if (trimmed == 'ok' || trimmed.startsWith('error:')) {
      if (_sentCommands.isNotEmpty) {
        final len = _sentCommands.removeFirst();
        _bufferCount -= len;
      }
      _processQueue();
      return;
    }

    // Parser GRBL unifié
    final newState = GrblParser.parse(trimmed, _currentState);
    if (newState != null) {
      _currentState = newState;
      _stateController.add(_currentState);
    }
  }

  // ── Queue de commandes ───────────────────────────────────────────────────
  void _enqueue(String cmd) {
    _cmdQueue.add(cmd);
    _processQueue();
  }

  void _processQueue() {
    while (_cmdQueue.isNotEmpty) {
      final cmd = _cmdQueue.first;
      final len = cmd.length;

      if (_bufferCount + len <= _maxBufferSize) {
        _cmdQueue.removeFirst();
        _sentCommands.add(len);
        _bufferCount += len;
        _connection.send(cmd);
      } else {
        break; // Buffer plein, on attend un 'ok'
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MachineRepository interface
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Stream<MachineState> get stateStream => _stateController.stream;

  @override
  MachineState get currentState => _currentState;

  @override
  Future<void> sendGCode(String gcode) async {
    // ⚠️ Correction bug : plus de préfixe $N — envoi direct du G-code
    final cmd = gcode.endsWith('\n') ? gcode : '$gcode\n';
    _enqueue(cmd);
  }

  @override
  Future<void> sendGCodeBatch(List<String> lines) async {
    for (var line in lines) {
      // Optimisation textuelle agressive pour le streaming
      String optimized = line.split(';')[0].trim(); // Retrait commentaires
      optimized = optimized.replaceAll(' ', '');   // Retrait espaces
      if (optimized.isNotEmpty) {
        _enqueue('$optimized\n');
      }
    }
  }

  @override
  Future<void> jog(String axis, double distance, double feedrate) async {
    // Annuler le jog précédent si actif
    if (_isJogging) {
      _connection.send('\x85'); // Jog Cancel — temps réel, pas de \n
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isJogging = true;
    // Jog relatif métrique — $J=G91 G21 A45.0 F200
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feedrate.toStringAsFixed(0)}\n';
    _connection.send(cmd); // Jog bypass la queue (temps réel)
  }

  /// Jog multi-axes simultané (ex: A et C ensemble)
  Future<void> jogMultiAxis(Map<String, double> axes, double feedrate) async {
    if (_isJogging) {
      _connection.send('\x85');
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isJogging = true;
    final axesStr = axes.entries
        .map((e) => '${e.key}${e.value.toStringAsFixed(3)}')
        .join(' ');
    _connection.send('\$J=G91 G21 $axesStr F${feedrate.toStringAsFixed(0)}\n');
  }

  /// Arrêt immédiat du jog (char 0x85 — temps réel)
  Future<void> jogCancel() async {
    _connection.send('\x85');
    _isJogging = false;
  }

  @override
  Future<void> emergencyStop() async {
    _connection.send('\x18'); // Soft Reset — char temps réel
    _isJogging = false;
    _waitingForOk = false;
    _cmdQueue.clear();
  }

  @override
  Future<void> home([List<String> axes = const []]) async {
    if (axes.isEmpty) {
      _enqueue('\$H\n'); // Homing complet
    } else {
      // Homing séquencé : $HZ, $HX, $HY, $HA, $HC
      for (final axis in axes) {
        _enqueue('\$H${axis.toUpperCase()}\n');
      }
    }
  }

  /// Homing séquencé recommandé pour trunnion :
  /// Z → X → Y → A → C
  Future<void> homeTrunnionSequence() async {
    await home(['Z']); // Dégager Z en premier
    await Future.delayed(const Duration(milliseconds: 200));
    await home(['X', 'Y']);
    await Future.delayed(const Duration(milliseconds: 200));
    await home(['A']);
    await Future.delayed(const Duration(milliseconds: 200));
    await home(['C']);
  }

  @override
  Future<void> resume() async {
    _connection.send('~'); // Cycle Start / Resume — temps réel
  }

  @override
  Future<void> pause() async {
    _connection.send('!'); // Feed Hold — temps réel
  }

  @override
  Future<void> reset() async {
    _connection.send('\x18'); // Soft Reset
    _waitingForOk = false;
    _cmdQueue.clear();
    _isJogging = false;
  }

  // ── Overrides temps réel ─────────────────────────────────────────────────
  // Chars définis dans le protocole GRBL/FluidNC

  /// Feed override : percent = 10..200
  Future<void> setFeedOverride(int percent) async {
    final current = _currentState.overrides[0];
    final diff = percent - current;
    if (diff == 0) return;
    if (diff % 10 == 0) {
      final steps = (diff / 10).round().abs();
      final char = diff > 0 ? '\x91' : '\x92'; // +10% / -10%
      for (int i = 0; i < steps; i++) { _connection.send(char); }
    } else {
      final char = diff > 0 ? '\x93' : '\x94'; // +1% / -1%
      for (int i = 0; i < diff.abs(); i++) { _connection.send(char); }
    }
    // Reset à 100%
    if (percent == 100) _connection.send('\x90');
  }

  /// Rapid override : 100%, 50%, 25%
  Future<void> setRapidOverride(int percent) async {
    switch (percent) {
      case 100: _connection.send('\x95'); break;
      case 50:  _connection.send('\x96'); break;
      case 25:  _connection.send('\x97'); break;
      default:  debugPrint('Rapid override: valeurs valides = 100, 50, 25');
    }
  }

  /// Spindle override : percent = 10..200
  Future<void> setSpindleOverride(int percent) async {
    final current = _currentState.overrides[2];
    final diff = percent - current;
    if (diff == 0) return;
    if (diff % 10 == 0) {
      final steps = (diff / 10).round().abs();
      final char = diff > 0 ? '\x9A' : '\x9B'; // +10% / -10%
      for (int i = 0; i < steps; i++) { _connection.send(char); }
    } else {
      final char = diff > 0 ? '\x9C' : '\x9D'; // +1% / -1%
      for (int i = 0; i < diff.abs(); i++) { _connection.send(char); }
    }
    if (percent == 100) _connection.send('\x99');
  }

  // ── Changement d'outil ───────────────────────────────────────────────────
  Future<void> selectTool(int toolNum) async {
    _enqueue('T$toolNum M6\n');
  }

  /// Activer compensation longueur outil
  Future<void> applyToolLengthCompensation(int toolNum) async {
    _enqueue('G43 H$toolNum\n');
  }

  // ── Changement de WCS ────────────────────────────────────────────────────
  Future<void> setActiveWCS(String wcs) async {
    _enqueue('$wcs\n');
    _enqueue('\$G\n'); // Refresh état modal
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────
  void dispose() {
    _pollingTimer?.cancel();
    _stateController.close();
    _connection.disconnect();
  }
}
