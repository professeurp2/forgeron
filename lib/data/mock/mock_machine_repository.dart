import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';

class MockMachineRepository implements MachineRepository {
  final _stateController = StreamController<MachineState>.broadcast();
  MachineState _currentState = const MachineState(status: MachineStatus.idle);
  // ignore: unused_field
  Timer? _simulationTimer;
  final _random = Random();

  MockMachineRepository() {
    _startSimulation();
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentState.status == MachineStatus.run) {
        final newX = _currentState.mPos[0] + (_random.nextDouble() * 0.1 - 0.05);
        final newY = _currentState.mPos[1] + (_random.nextDouble() * 0.1 - 0.05);
        final newZ = _currentState.mPos[2] + (_random.nextDouble() * 0.05 - 0.025);
        final newA = _currentState.mPos[3] + (_random.nextDouble() * 0.5 - 0.25);
        final newC = _currentState.mPos[4] + (_random.nextDouble() * 0.5 - 0.25);
        
        _updateState(_currentState.copyWith(
          mPos: [newX, newY, newZ, newA, newC],
          wPos: [newX, newY, newZ, newA, newC], // Simplified
          feedrate: 1200.0 + _random.nextDouble() * 50,
          spindleSpeed: 12000.0 + _random.nextDouble() * 100,
        ));
      } else {
        // Emit current state so new listeners get it
        _updateState(_currentState);
      }
    });
    
    // Initial state push
    _updateState(_currentState.copyWith(
      mPos: [125.340, -45.200, 12.050, 0.000, 90.000],
      wPos: [125.340, -45.200, 12.050, 0.000, 90.000],
    ));
  }

  void _updateState(MachineState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Stream<MachineState> get stateStream => _stateController.stream;

  @override
  MachineState get currentState => _currentState;

  @override
  Future<void> sendGCode(String gcode) async {
    debugPrint('Mock sending GCode: $gcode');
    if (gcode.startsWith('M3') || gcode.startsWith('G1') || gcode.startsWith('G0')) {
      _updateState(_currentState.copyWith(status: MachineStatus.run));
    }
  }

  @override
  Future<void> emergencyStop() async {
    debugPrint('Mock E-STOP');
    _updateState(_currentState.copyWith(status: MachineStatus.alarm));
  }

  @override
  Future<void> home([List<String> axes = const []]) async {
    debugPrint('Mock Home ${axes.isEmpty ? "All" : axes.join(", ")}');
    _updateState(_currentState.copyWith(status: MachineStatus.home));
    await Future.delayed(const Duration(seconds: 2));
    _updateState(_currentState.copyWith(
      status: MachineStatus.idle,
      mPos: [0.0, 0.0, 0.0, 0.0, 0.0],
      wPos: [0.0, 0.0, 0.0, 0.0, 0.0],
    ));
  }

  @override
  Future<void> jog(String axis, double distance, double feedrate) async {
    debugPrint('Mock Jog $axis $distance F$feedrate');
    _updateState(_currentState.copyWith(status: MachineStatus.run));
    await Future.delayed(const Duration(milliseconds: 500));
    _updateState(_currentState.copyWith(status: MachineStatus.idle));
  }

  @override
  Future<void> resume() async {
    debugPrint('Mock Resume');
    _updateState(_currentState.copyWith(status: MachineStatus.run));
  }

  @override
  Future<void> pause() async {
    debugPrint('Mock Pause');
    _updateState(_currentState.copyWith(status: MachineStatus.hold));
  }

  @override
  Future<void> reset() async {
    debugPrint('Mock Reset');
    _updateState(_currentState.copyWith(status: MachineStatus.idle));
  }
}
