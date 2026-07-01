import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/trajectory_validator.dart';
import '../../core/utils/gcode_parser.dart';
import 'gcode_provider.dart';
import '../../application/providers/di_providers.dart';

/// Provider pour orchestrer le streaming industriel sécurisé.
final streamingProvider = StateNotifierProvider<StreamingController, bool>((ref) {
  return StreamingController(ref);
});

class StreamingController extends StateNotifier<bool> {
  final Ref _ref;

  StreamingController(this._ref) : super(false);

  Future<ValidationResult> startStream() async {
    // ── Guard : ne pas lancer si déjà en cours ────────────────────────────
    if (state) return ValidationResult.success();

    final gcodeState = _ref.read(gcodeProvider);
    if (gcodeState.allLines.isEmpty) {
      return ValidationResult.error('Aucun programme G-Code chargé', 0);
    }

    // 1. Validation Lookahead avant de commencer
    final result = TrajectoryValidator.validate(
      AnalyzedGCode(
        lines: gcodeState.allLines,
        toolpath: gcodeState.toolpath,
        modalStates: {},
      ),
    );

    if (!result.isValid) {
      return result;
    }

    // 2. Démarrer le streaming — l'état revient à false via onComplete
    state = true;
    await _ref.read(machineRepositoryProvider).sendGCodeBatch(
      gcodeState.allLines,
      onComplete: () {
        if (mounted) state = false;
      },
    );
    return ValidationResult.success();
  }

  void stopStream() {
    // emergencyStop() → stop() dans le service → onComplete appelé → state = false
    _ref.read(machineRepositoryProvider).emergencyStop();
    state = false;
  }
}
