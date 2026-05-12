import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/trajectory_validator.dart';
import '../../core/utils/gcode_parser.dart';
import 'gcode_provider.dart';
import 'machine_provider.dart';

/// Provider pour orchestrer le streaming industriel sécurisé.
final streamingProvider = StateNotifierProvider<StreamingController, bool>((ref) {
  return StreamingController(ref);
});

class StreamingController extends StateNotifier<bool> {
  final Ref _ref;
  
  StreamingController(this._ref) : super(false);

  Future<void> startStream() async {
    final gcodeState = _ref.read(gcodeProvider);
    if (gcodeState.allLines.isEmpty) return;

    // 1. Validation Lookahead avant de commencer
    final result = TrajectoryValidator.validate(
      AnalyzedGCode(
        lines: gcodeState.allLines, 
        toolpath: gcodeState.toolpath, 
        modalStates: {},
      ),
    );

    if (!result.isValid) {
      // Lever une alerte UI via un autre provider ou un SnackBar
      return;
    }

    // 2. Lancer le stream via le repository
    state = true;
    await _ref.read(machineRepositoryProvider).sendGCodeBatch(gcodeState.allLines);
  }

  void stopStream() {
    _ref.read(machineRepositoryProvider).emergencyStop();
    state = false;
  }
}
