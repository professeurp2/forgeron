import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/trajectory_validator.dart';
import '../../core/utils/gcode_parser.dart';
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

class StreamingController extends StateNotifier<bool> {
  final Ref _ref;

  StreamingController(this._ref) : super(false);

  Future<ValidationResult> startStream() async {
    debugPrint('[StreamingController] 🟢 startStream() appelé ! state = $state');
    // ── Guard : ne pas lancer si déjà en cours ────────────────────────────
    if (state) {
      debugPrint('[StreamingController] ⚠️ Ignoré car streaming déjà en cours (state=true).');
      return ValidationResult.success();
    }

    final gcodeState = _ref.read(gcodeProvider);
    if (gcodeState.allLines.isEmpty) {
      debugPrint('[StreamingController] ❌ Aucun programme G-Code chargé !');
      return ValidationResult.error('Aucun programme G-Code chargé', 0);
    }

    // ── Guard : G-code adapté mais BLOQUÉ ─────────────────────────────────
    // L'adaptateur (au chargement) a détecté des codes CAM que FluidNC ne peut
    // pas exécuter et qu'on ne peut pas traduire ici (RTCP, compensation de
    // rayon MACHINE G41/G42, cycle non géré) → à corriger dans le post CAM.
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
    // 1. Validation Lookahead avant de commencer
    final result = TrajectoryValidator.validate(
      AnalyzedGCode(
        lines: gcodeState.allLines,
        toolpath: gcodeState.toolpath,
        modalStates: {},
        toolpathLineIndices: gcodeState.toolpathLineIndices,
      ),
      config: _ref.read(trunnionConfigProvider),
    );

    if (!result.isValid) {
      debugPrint('[StreamingController] ❌ Validation échouée : ${result.errorMessage}');
      return result;
    }

    // 2. ── ForceGuard : bridage des efforts selon le mode d'usinage ────────
    // Appliqué ICI, en amont : le character-counting du service de streaming
    // doit compter exactement les octets qui partent sur le fil.
    // (Auparavant le ForceGuard était injectable mais n'était JAMAIS branché :
    //  le bridage ne s'appliquait donc jamais, malgré ce qu'affichait l'UI.)
    final guard = ForceGuardService(
      mode: _ref.read(machiningModeProvider),
      config: _ref.read(trunnionConfigProvider),
    );
    final lines = gcodeState.allLines.map(guard.processLine).toList();
    if (guard.clampedCount > 0 || guard.blockedCount > 0) {
      debugPrint(
        '[ForceGuard] ⚡ ${guard.clampedCount} ligne(s) bridée(s), '
        '${guard.blockedCount} ligne(s) A/C bloquée(s).',
      );
    }

    // 3. Démarrer le streaming — l'état revient à false via onComplete/onStall
    debugPrint('[StreamingController] ✅ Validation réussie. Lancement de sendGCodeBatch...');
    _ref.read(streamStallProvider.notifier).state = null;
    state = true;
    await _ref.read(machineRepositoryProvider).sendGCodeBatch(
      lines,
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
