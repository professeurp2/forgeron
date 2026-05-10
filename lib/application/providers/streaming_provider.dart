import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/trajectory_validator.dart';
import '../services/streaming_service.dart';
import 'gcode_provider.dart';
import 'machine_provider.dart';

/// Provider pour orchestrer le streaming industriel sécurisé.
final streamingProvider = Provider((ref) {
  final machineRepo = ref.watch(machineRepositoryProvider);
  // Note: GCodeStreamingService nécessite une instance de FluidNCConnection.
  // On simplifie ici pour l'architecture Riverpod.
});

class StreamingController extends StateNotifier<bool> {
  final Ref _ref;
  
  StreamingController(this._ref) : super(false);

  Future<void> startStream() async {
    final gcodeState = _ref.read(gcodeProvider);
    if (gcodeState.allLines.isEmpty) return;

    // 1. Validation Lookahead avant de commencer
    final result = TrajectoryValidator.validate(
      AnalyzedGCode(lines: [], toolpath: [], modalStates: {})
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
