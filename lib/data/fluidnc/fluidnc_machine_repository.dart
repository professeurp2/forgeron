import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import 'fluidnc_connection.dart';
import 'grbl_parser.dart';

/// Repository FluidNC Industriel pour machine CNC 5-axes Trunnion.
/// 
/// Exploite la classe FluidNCConnection pour une communication robuste :
///  - Gestion automatique du buffer (Backpressure).
///  - Reconnexion avec Exponential Backoff.
///  - Heartbeat pour la surveillance du lien WiFi.
class FluidNCMachineRepository implements MachineRepository {
  final FluidNCConnection _connection;
  final _stateController = StreamController<MachineState>.broadcast();
  MachineState _currentState = const MachineState(status: MachineStatus.offline);

  FluidNCMachineRepository(this._connection) {
    _connection.connect();

    _connection.messages.listen(_handleMessage);
    _connection.status.listen((isConnected) {
      if (!isConnected) {
        _currentState = _currentState.copyWith(status: MachineStatus.offline);
        _stateController.add(_currentState);
      } else {
        // Séquence d'initialisation industrielle
        Future.delayed(const Duration(milliseconds: 500), () {
          _connection.sendRaw('\$G\n');   // État modal
          _connection.sendRaw('\$#\n');   // Offsets de travail
          _connection.sendRaw('[ESP110]\n'); // WiFi info
        });
      }
    });
  }

  void _handleMessage(String message) {
    final newState = GrblParser.parse(message, _currentState);
    if (newState != null) {
      _currentState = newState;
      _stateController.add(_currentState);
    }
  }

  @override
  Stream<MachineState> get stateStream => _stateController.stream;

  @override
  Stream<String> get messageStream => _connection.messages;

  /// Stream of raw network traffic (TX/RX) for diagnostics.
  Stream<String> get trafficStream => _connection.traffic;

  @override
  MachineState get currentState => _currentState;

  @override
  Future<void> sendGCode(String gcode) async {
    _connection.sendGCode(gcode);
  }

  @override
  Future<void> sendGCodeBatch(List<String> lines) async {
    for (var line in lines) {
      String optimized = line.split(';')[0].trim();
      if (optimized.isNotEmpty) {
        _connection.sendGCode(optimized);
      }
    }
  }

  @override
  Future<void> jog(String axis, double distance, double feedrate) async {
    // Annuler jog précédent (commande temps réel 0x85)
    _connection.sendRaw('\x85');
    // Le jog industriel utilise $J=G91...
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feedrate.toStringAsFixed(0)}\n';
    _connection.sendRaw(cmd);
  }

  @override
  Future<void> emergencyStop() async {
    _connection.sendRaw('\x18'); // Soft Reset (Ctrl-X)
  }

  @override
  Future<void> home([List<String> axes = const []]) async {
    if (axes.isEmpty) {
      _connection.sendGCode('\$H');
    } else {
      for (final axis in axes) {
        _connection.sendGCode('\$H${axis.toUpperCase()}');
      }
    }
  }

  @override
  Future<void> resume() async {
    _connection.sendRaw('~'); // Cycle Start
  }

  @override
  Future<void> pause() async {
    _connection.sendRaw('!'); // Feed Hold
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

  void dispose() {
    _stateController.close();
    _connection.dispose();
  }
}
