import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import '../../application/providers/gcode_provider.dart';

class MockMachineRepository implements MachineRepository {
  final _stateController = StreamController<MachineState>.broadcast();
  MachineState _currentState = const MachineState(status: MachineStatus.idle);
  
  @override
  Stream<MachineState> get stateStream => _stateController.stream;

  @override
  MachineState get currentState => _currentState;

  // ignore: unused_field
  Timer? _simulationTimer;
  final _random = math.Random();

  bool _isDemoActive = false;
  double _demoProgress = 0.0;
  List<GCodeLine> _currentProgram = [];
  int _currentProgramIndex = 0;

  MockMachineRepository() {
    _startSimulation();
  }

  void _startSimulation() {
    double time = 0;
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentState.status == MachineStatus.run) {
        time += 0.05;

        if (_isDemoActive) {
          _demoProgress += 0.5; // Démo plus rapide pour le test
          if (_demoProgress >= 100) {
            _demoProgress = 100;
            _isDemoActive = false;
            _updateState(_currentState.copyWith(status: MachineStatus.idle, sdPercent: 100));
            return;
          }
          
          // Simulation mouvement démo (dôme)
          final x = 40 * math.cos(time * 0.8);
          final y = 40 * math.sin(time * 0.8);
          final z = 15 + 5 * math.sin(time * 3);
          final a = 30 - (_demoProgress * 0.4);
          final c = (time * 40) % 360;
          _updateWithPos([x, y, z, a, c], targetOffset: 0.5);
          return;
        }

        // --- SIMULATION PROGRAMME CHARGÉ ---
        if (_currentProgram.isNotEmpty && _currentProgramIndex < _currentProgram.length) {
          final line = _currentProgram[_currentProgramIndex].content.toUpperCase();
          
          // Extraction simplifiée des coordonnées (X, Y, Z, A, C)
          final newPos = List<double>.from(_currentState.mPos);
          final regX = RegExp(r'X([-+]?[0-9]*\.?[0-9]+)');
          final regY = RegExp(r'Y([-+]?[0-9]*\.?[0-9]+)');
          final regZ = RegExp(r'Z([-+]?[0-9]*\.?[0-9]+)');
          final regA = RegExp(r'A([-+]?[0-9]*\.?[0-9]+)');
          final regC = RegExp(r'C([-+]?[0-9]*\.?[0-9]+)');

          if (regX.hasMatch(line)) newPos[0] = double.parse(regX.firstMatch(line)!.group(1)!);
          if (regY.hasMatch(line)) newPos[1] = double.parse(regY.firstMatch(line)!.group(1)!);
          if (regZ.hasMatch(line)) newPos[2] = double.parse(regZ.firstMatch(line)!.group(1)!);
          if (regA.hasMatch(line)) newPos[3] = double.parse(regA.firstMatch(line)!.group(1)!);
          if (regC.hasMatch(line)) newPos[4] = double.parse(regC.firstMatch(line)!.group(1)!);

          _currentProgramIndex++;
          final progress = (_currentProgramIndex / _currentProgram.length) * 100;
          
          _updateWithPos(newPos, progress: progress, filename: 'SIMULATION_ACTIVE.NC', lineIndex: _currentProgramIndex);
          
          if (_currentProgramIndex >= _currentProgram.length) {
            _updateState(_currentState.copyWith(status: MachineStatus.idle));
          }
        }
      }
    });
  }

  void _updateState(MachineState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void _updateWithPos(List<double> pos, {double progress = 0.0, String? filename, double targetOffset = 1.0, int lineIndex = 0}) {
    // Calcul target (avance sur trajectoire simulée ou bruit)
    final targetPos = [for (var i = 0; i < 5; i++) pos[i] + (i == 0 ? 2.0 : 0.0)]; 
    
    final absA = pos[3].abs();
    final risk = (1.0 - (absA / 10.0)).clamp(0.0, 1.0);

    _updateState(_currentState.copyWith(
      mPos: pos,
      targetPos: targetPos,
      singularityRisk: risk,
      wPos: pos,
      sdPercent: progress,
      sdFilename: filename,
      activeLineIndex: lineIndex,
      feedrate: 2000.0,
      spindleSpeed: 15000.0,
      isRtcpActive: true,
    ));
  }

  @override
  Future<void> sendGCode(String gcode) async {
    debugPrint('Mock command: $gcode');
    if (gcode == 'MOCK_DEMO') {
      _isDemoActive = true;
      _demoProgress = 0.0;
      _updateState(_currentState.copyWith(status: MachineStatus.run));
      return;
    }
    // Simulation du programme chargé via batch ou ligne
    if (gcode.startsWith('M3') || gcode.startsWith('G')) {
      _updateState(_currentState.copyWith(status: MachineStatus.run));
    }
  }

  @override
  Future<void> sendGCodeBatch(List<String> lines) async {
    _currentProgram = lines.asMap().entries.map((e) => GCodeLine(number: e.key + 1, content: e.value)).toList();
    _currentProgramIndex = 0;
    _isDemoActive = false;
    _updateState(_currentState.copyWith(status: MachineStatus.idle, sdPercent: 0, activeLineIndex: 0));
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
