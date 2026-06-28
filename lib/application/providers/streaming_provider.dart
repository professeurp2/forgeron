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

  Future<void> startStream() async {
    // ── Guard : ne pas lancer si déjà en cours ────────────────────────────
    // BUG FIX: sans ce guard, chaque clic relançait un stream même si l'état
    // UI affichait déjà "en cours" (state == true mais streaming réel arrêté).
    if (state) return;

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
      // Alerte UI à gérer si besoin
      return;
    }

    // 2. Démarrer le streaming — l'état revient à false via onComplete
    state = true;
    await _ref.read(machineRepositoryProvider).sendGCodeBatch(
      gcodeState.allLines,
      onComplete: () {
        // ── BUG FIX : remettre l'état à false quand l'ESP32 a acquitté
        // la dernière ligne. Sans ça, l'UI restait bloquée sur "en cours".
        if (mounted) state = false;
      },
    );
  }

  void stopStream() {
    // emergencyStop() → stop() dans le service → onComplete appelé → state = false
    _ref.read(machineRepositoryProvider).emergencyStop();
    state = false;
  }
}
