import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import 'fluidnc_connection.dart';
import 'fluidnc_serial_connection.dart';
import 'grbl_parser.dart';
import '../../application/services/streaming_service.dart';

/// Repository FluidNC Industriel pour machine CNC 5-axes Trunnion.
///
/// Exploite la classe FluidNCConnection pour une communication robuste :
///  - Gestion automatique du buffer (Backpressure).
///  - Reconnexion avec Exponential Backoff.
///  - Heartbeat pour la surveillance du lien WiFi.
class FluidNCMachineRepository implements MachineRepository {
  final FluidNCConnection _connection;
  final bool _ownsConnection;
  final _stateController = StreamController<MachineState>.broadcast();
  MachineState _currentState = const MachineState(status: MachineStatus.offline);

  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;
  late final GCodeStreamingService _streamingService;
  int _lastProgressEmitMs = 0;

  FluidNCMachineRepository(this._connection, {bool ownsConnection = true})
      : _ownsConnection = ownsConnection {
    _streamingService = GCodeStreamingService(_connection);
    _msgSub = _connection.messages.listen(_handleMessage);
    _statusSub = _connection.status.listen((isConnected) {
      if (_stateController.isClosed) return;
      if (!isConnected) {
        _streamingService.stop();
        _currentState = _currentState.copyWith(status: MachineStatus.offline);
        _stateController.add(_currentState);
      } else {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!_connection.isConnected || _stateController.isClosed) return;
          if (_connection is FluidNCSerialConnection) {
            // En mode USB, couper le Wi-Fi de l'ESP32 pour éviter tout scan/reconnexion
            // radio pendant le homing ou l'usinage.
            _connection.sendRaw('\$WiFi/Mode=Off\n');
          }
          _disableNoisyHardLimits();
          _connection.sendRaw('?');      // Statut immédiat (<Idle|MPos:...>)
          _connection.sendRaw('\$G\n');  // État modal
          _connection.sendRaw('\$#\n');  // Offsets de travail
          _connection.sendRaw('\$I\n');  // Build info firmware (VER/OPT)
          if (_connection is! FluidNCSerialConnection) {
            _connection.sendRaw('[ESP110]\n'); // WiFi info
          }
        });
      }
    });
    // Différer l'ouverture du port série / WebSocket après le rendu du premier
    // frame Flutter afin que Win32Window::Show() s'exécute immédiatement.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!_stateController.isClosed) {
        _connection.connect();
      }
    });
  }

  /// Désactive `hard_limits` en RAM sur X, Y, Z, A pour immuniser l'usinage
  /// contre les parasites électromagnétiques (EMI) de la broche DC (`M3` sur
  /// relais GPIO21) qui déclenchaient de fausses « ALARM:1 Hard Limit » sur les
  /// entrées fins de course (pull-up interne ~45 kΩ) dès la mise en route de la
  /// broche.
  ///
  /// SÉCURITÉ CONSERVÉE :
  ///  - Le homing (`$H`) utilise toujours les capteurs physiques (`limit_all_pin`).
  ///  - Les limites logicielles (`soft_limits: true`) protègent toutes les courses.
  ///  - L'arrêt d'urgence matériel (`estop_pin: gpio.15`) reste actif.
  void _disableNoisyHardLimits() {
    for (final axis in const ['x', 'y', 'z', 'a']) {
      _connection.sendRaw('\$/axes/$axis/motor0/hard_limits=false\n');
    }
  }

  void _handleMessage(String message) {
    if (_stateController.isClosed) return;

    final trimmed = message.trim();
    if (trimmed == 'ok' || trimmed.startsWith('error:')) {
      if (_streamingService.isStreaming) _streamingService.handleAck();
    } else if (trimmed.startsWith('ALARM:')) {
      // Arrêter immédiatement le streaming dès la ligne `ALARM:N` sans attendre
      // le prochain rapport `<Alarm|...>`.
      if (_streamingService.isStreaming) _streamingService.stop();
    } else if (trimmed.startsWith('Grbl ') || trimmed.startsWith('FluidNC')) {
      // Après un soft-reset (Ctrl-X) ou redémarrage de l'ESP32, réappliquer
      // `hard_limits=false` en RAM.
      if (_streamingService.isStreaming) _streamingService.stop();
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (_connection.isConnected && !_stateController.isClosed) {
          _disableNoisyHardLimits();
        }
      });
    }

    final prevStatus = _currentState.status;
    final newState = GrblParser.parse(message, _currentState);
    if (newState != null) {
      _currentState = newState;
      _stateController.add(_currentState);

      // La machine bouge : on l'interroge quatre fois par seconde au lieu
      // d'une fois toutes les deux secondes, pour que ce qui est affiché (DRO,
      // jumeau 3D, enlèvement de matière) soit ce que la carte fait, pas ce
      // qu'elle faisait il y a deux secondes.
      if (newState.status != prevStatus) {
        _connection.setHeartbeatPeriod(pollIntervalFor(newState.status));
      }

      if (newState.status == MachineStatus.alarm &&
          prevStatus != MachineStatus.alarm) {
        _streamingService.stop();
      }
      _streamingService.setMachineHold(newState.status == MachineStatus.hold);
      if (newState.status == MachineStatus.run ||
          newState.status == MachineStatus.home ||
          newState.status == MachineStatus.hold) {
        _streamingService.notifyActivity();
      }
    }
  }

  @override
  Stream<MachineState> get stateStream => _stateController.stream;

  @override
  Stream<String> get messageStream => _connection.messages;

  /// Stream of raw network traffic (TX/RX) for diagnostics.
  Stream<String> get trafficStream => _connection.traffic;

  @override
  void sendRaw(String data) => _connection.sendRaw(data);

  @override
  MachineState get currentState => _currentState;

  @override
  Future<void> sendGCode(String gcode) async {
    _connection.sendGCode(gcode);
  }

  @override
  Future<void> sendGCodeBatch(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int index)? onProgress,
    void Function(String reason)? onStall,
  }) async {
    final total = lines.length;
    _streamingService.streamLines(
      lines,
      onComplete: onComplete,
      onStall: onStall,
      onProgress: (idx) {
        _currentState = _currentState.copyWith(activeLineIndex: idx);
        if (!_stateController.isClosed) {
          final now = DateTime.now().millisecondsSinceEpoch;
          // Cadencement des émissions UI à ~30 Hz (32 ms) tout en garantissant
          // l'émission immédiate sur les premières et dernières lignes.
          if (idx <= 1 || idx >= total - 1 || (now - _lastProgressEmitMs) >= 32) {
            _lastProgressEmitMs = now;
            _stateController.add(_currentState);
          }
        }
        onProgress?.call(idx);
      },
    );
  }

  @override
  Future<void> jog(String axis, double distance, double feedrate) async {
    _connection.sendRaw('\x85');
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feedrate.toStringAsFixed(0)}\n';
    _connection.sendRaw(cmd);
  }

  @override
  Future<bool> emergencyStop() async {
    _streamingService.stop();
    final sent = _connection.sendRaw('\x18');
    if (!sent) {
      debugPrint(
        '[FORGERON] 🚨 ARRÊT D\'URGENCE NON TRANSMIS — liaison coupée. '
        'La machine n\'est PAS arrêtée.',
      );
    }
    return sent;
  }

  @override
  Future<void> home([List<String> axes = const []]) async {
    if (axes.isEmpty) {
      _connection.sendGCode('\$H');
    } else {
      for (final axis in axes) {
        final a = axis.toUpperCase();
        if (a == 'C') {
          _connection.sendGCode('G92 ${a}0');
        } else {
          _connection.sendGCode('\$H$a');
        }
      }
    }
  }

  @override
  Future<void> resume() async {
    _connection.sendRaw('~'); // Cycle Start
    if (_streamingService.isStreaming) {
      _streamingService.resume();
    }
  }

  @override
  Future<void> pause() async {
    _connection.sendRaw('!'); // Feed Hold
    if (_streamingService.isStreaming) {
      _streamingService.pause();
    }
  }

  @override
  Future<void> reset() async {
    _connection.sendRaw('\x18');
  }

  // --- Overrides ---
  @override
  Future<void> setFeedOverride(int percent) async => _connection.sendRaw(percent == 100 ? '\x90' : (percent > 100 ? '\x91' : '\x92'));

  @override
  Future<void> setSpindleOverride(int percent) async => _connection.sendRaw(percent == 100 ? '\x99' : (percent > 100 ? '\x9A' : '\x9B'));

  @override
  void setSimulationSpeed(double speed) {} // Ignored for real hardware

  /// Cadence du `?` selon l'état : rapide dès que des axes peuvent bouger.
  static const Duration fastPoll = Duration(milliseconds: 250);
  static const Duration idlePoll = Duration(seconds: 2);

  static Duration pollIntervalFor(MachineStatus status) => switch (status) {
        MachineStatus.run ||
        MachineStatus.home ||
        MachineStatus.hold ||
        MachineStatus.check =>
          fastPoll,
        _ => idlePoll,
      };

  @override
  void setStatusPollInterval(Duration interval) =>
      _connection.setHeartbeatPeriod(interval);

  static const Map<String, int> _wcsToP = {
    'G54': 1, 'G55': 2, 'G56': 3, 'G57': 4, 'G58': 5, 'G59': 6,
  };

  @override
  Future<void> setWcsOffset(String wcs, List<double> offset) async {
    final p = _wcsToP[wcs.toUpperCase()];
    if (p == null) return;
    const axisLetters = ['X', 'Y', 'Z', 'A', 'C'];
    final cmd = StringBuffer('G10 L2 P$p');
    for (var i = 0; i < offset.length && i < axisLetters.length; i++) {
      cmd.write(' ${axisLetters[i]}${offset[i].toStringAsFixed(3)}');
    }
    _connection.sendGCode(cmd.toString());
    _connection.sendRaw('\$#\n');
  }

  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    _stateController.close();
    _streamingService.dispose();
    if (_ownsConnection) {
      _connection.dispose();
    }
  }
}
