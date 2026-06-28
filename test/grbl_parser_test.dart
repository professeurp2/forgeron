import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/data/fluidnc/grbl_parser.dart';

void main() {
  group('GrblParser Tests', () {
    const initialState = MachineState();

    test('Parses FluidNC 5-Axis Status Report', () {
      final msg = '<Idle|MPos:10.0,20.0,30.0,40.0,0.0,50.0|WCO:0.0,0.0,0.0,0.0,0.0,0.0|FS:1200,10000|Pn:P>';
      final state = GrblParser.parse(msg, initialState);
      
      expect(state, isNotNull);
      expect(state!.status, MachineStatus.idle);
      // X=10, Y=20, Z=30, A=40, C=50 (index 5)
      expect(state.mPos, [10.0, 20.0, 30.0, 40.0, 50.0]);
      expect(state.feedrate, 1200.0);
      expect(state.spindleSpeed, 10000.0);
      expect(state.probeTriggered, true);
    });

    test('Parses MSG format', () {
      final msg = '[MSG:Reset to continue]';
      final state = GrblParser.parse(msg, initialState);
      
      expect(state, isNotNull);
      expect(state!.lastMessage, 'Reset to continue');
    });

    test('Parses ALARM format', () {
      final msg = 'ALARM:1';
      final state = GrblParser.parse(msg, initialState);
      
      expect(state, isNotNull);
      expect(state!.status, MachineStatus.alarm);
      expect(state.alarmCode, 1);
    });
  });
}
