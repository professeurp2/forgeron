import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/trajectory_validator.dart';
import '../../core/utils/gcode_parser.dart';
import '../../domain/models/machining_mode.dart';
import '../../domain/models/trunnion_config.dart';
import '../services/force_guard_service.dart';
import 'gcode_provider.dart';
import 'machining_mode_provider.dart';
import '../../application/providers/di_providers.dart';

/// Provider pour orchestrer le streaming industriel sécurisé.
final streamingProvider = StateNotifierProvider<StreamingController, bool>((ref) {
  return StreamingController(ref);
});

/// Raison du dernier blocage du flux (`null` = aucun).
/// SÉCURITÉ : sans ça, un flux mort laissait l'UI indéfiniment en « RUN ».
final streamStallProvider = StateProvider<String?>((ref) => null);

/// Vrai si le dernier arrêt d'urgence n'a **pas pu être transmis**.
/// SÉCURITÉ : l'UI doit alerter — la machine n'est PAS arrêtée.
final estopFailedProvider = StateProvider<bool>((ref) => false);

class _StreamPrepInput {
  final List<String> allLines;
  final List<List<double>> toolpath;
  final List<int> toolpathLineIndices;
  final TrunnionConfig config;
  final MachiningMode mode;

  const _StreamPrepInput({
    required this.allLines,
    required this.toolpath,
    required this.toolpathLineIndices,
    required this.config,
    required this.mode,
  });
}

class _StreamPrepOutput {
  final ValidationResult validation;
  final List<String> guardedLines;
  final int clampedCount;
  final int blockedCount;

  const _StreamPrepOutput({
    required this.validation,
    required this.guardedLines,
    required this.clampedCount,
    required this.blockedCount,
  });
}

_StreamPrepOutput _prepareStreamSync(_StreamPrepInput input) {
  final result = TrajectoryValidator.validate(
    AnalyzedGCode(
      lines: input.allLines,
      toolpath: input.toolpath,
      modalStates: const {},
      toolpathLineIndices: input.toolpathLineIndices,
    ),
    config: input.config,
  );
  if (!result.isValid) {
    return _StreamPrepOutput(
      validation: result,
      guardedLines: const [],
      clampedCount: 0,
      blockedCount: 0,
    );
  }
  final guard = ForceGuardService(
    mode: input.mode,
    config: input.config,
  );
  final lines = input.allLines.map(guard.processLine).toList();
  return _StreamPrepOutput(
    validation: result,
    guardedLines: lines,
    clampedCount: guard.clampedCount,
    blockedCount: guard.blockedCount,
  );
}

class StreamingController extends StateNotifier<bool> {
  final Ref _ref;

  StreamingController(this._ref) : super(false);

  Future<ValidationResult> startStream() async {
    debugPrint('[StreamingController] 🟢 startStream() appelé ! state = $state');
    if (state) {
      debugPrint('[StreamingController] ⚠️ Ignoré car streaming déjà en cours (state=true).');
      return ValidationResult.success();
    }

    final gcodeState = _ref.read(gcodeProvider);
    if (gcodeState.allLines.isEmpty) {
      debugPrint('[StreamingController] ❌ Aucun programme G-Code chargé !');
      return ValidationResult.error('Aucun programme G-Code chargé', 0);
    }

    if (gcodeState.adaptBlocking) {
      final why = gcodeState.adaptWarnings
          .where((w) => w.contains('⚠️'))
          .join(' ');
      debugPrint('[StreamingController] ❌ G-code bloqué par l\'adaptateur : $why');
      return ValidationResult.error(
        'G-code incompatible FluidNC — à corriger dans le post CAM. '
        '${why.isEmpty ? '' : why}',
        0,
      );
    }

    debugPrint('[StreamingController] 🔍 Validation Lookahead de ${gcodeState.allLines.length} lignes...');
    final prepInput = _StreamPrepInput(
      allLines: gcodeState.allLines,
      toolpath: gcodeState.toolpath,
      toolpathLineIndices: gcodeState.toolpathLineIndices,
      config: _ref.read(trunnionConfigProvider),
      mode: _ref.read(machiningModeProvider),
    );

    final prep = gcodeState.allLines.length > 500
        ? await compute(_prepareStreamSync, prepInput)
        : _prepareStreamSync(prepInput);

    if (!prep.validation.isValid) {
      debugPrint('[StreamingController] ❌ Validation échouée : ${prep.validation.errorMessage}');
      return prep.validation;
    }

    if (prep.clampedCount > 0 || prep.blockedCount > 0) {
      debugPrint(
        '[ForceGuard] ⚡ ${prep.clampedCount} ligne(s) bridée(s), '
        '${prep.blockedCount} ligne(s) A/C bloquée(s).',
      );
    }

    debugPrint('[StreamingController] ✅ Validation réussie. Lancement de sendGCodeBatch...');
    _ref.read(streamStallProvider.notifier).state = null;
    state = true;
    await _ref.read(machineRepositoryProvider).sendGCodeBatch(
      prep.guardedLines,
      onComplete: () {
        debugPrint('[StreamingController] 🏁 onComplete appelé ! Fin du flux.');
        if (mounted) state = false;
      },
      onStall: (reason) {
        debugPrint('[StreamingController] ⏸ Flux bloqué : $reason');
        if (mounted) state = false;
        _ref.read(streamStallProvider.notifier).state = reason;
      },
    );
    debugPrint('[StreamingController] 🚀 startStream() a fini de soumettre le batch au repository.');
    return ValidationResult.success();
  }

  /// Arrêt d'urgence. Retourne `false` si la commande n'a PAS pu être
  /// transmise — dans ce cas la machine n'est pas arrêtée et l'UI doit alerter.
  Future<bool> stopStream() async {
    debugPrint('[StreamingController] 🛑 stopStream() appelé !');
    final sent = await _ref.read(machineRepositoryProvider).emergencyStop();
    state = false;
    _ref.read(estopFailedProvider.notifier).state = !sent;
    if (!sent) {
      debugPrint('[StreamingController] 🚨 E-STOP NON TRANSMIS — liaison coupée !');
    }
    return sent;
  }
}
