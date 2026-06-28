import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machining_mode.dart';
import '../../domain/models/trunnion_config.dart';

// ── Configuration Trunnion (constantes mécaniques PFE §3.4) ─────────────────

/// Configuration mécanique du Trunnion — singleton immuable.
/// Contient les paramètres GT2 (6:1), NEMA 17, courses, efforts.
final trunnionConfigProvider = Provider<TrunnionConfig>(
  (ref) => const TrunnionConfig(),
);

// ── Mode d'usinage ──────────────────────────────────────────────────────────

/// Mode d'usinage actif (3AX par défaut — le plus sûr).
final machiningModeProvider = StateProvider<MachiningMode>(
  (ref) => MachiningMode.threeAxis,
);

// ── Providers dérivés ───────────────────────────────────────────────────────

/// Force résultante maximale autorisée (N) selon le mode actif.
/// 5AX → 45,6 N (bridage ForceGuard) | 3AX → 180 N.
final activeMaxForceProvider = Provider<double>((ref) {
  final mode = ref.watch(machiningModeProvider);
  return mode.maxResultantForce;
});

/// Vitesse d'avance maximale autorisée (mm/min) selon le mode actif.
/// 5AX → 500 mm/min | 3AX → 2000 mm/min.
final activeMaxFeedrateProvider = Provider<double>((ref) {
  final mode = ref.watch(machiningModeProvider);
  return mode.maxFeedrate;
});

/// Les axes rotatifs sont-ils actifs dans le mode courant ?
final rotaryAxesActiveProvider = Provider<bool>((ref) {
  final mode = ref.watch(machiningModeProvider);
  return mode.rotaryAxesActive;
});

/// Profondeur de passe max recommandée (mm) selon le mode actif.
final activeMaxApProvider = Provider<double>((ref) {
  final mode = ref.watch(machiningModeProvider);
  return mode.maxDepthOfCut;
});

/// Largeur d'engagement max recommandée (mm) selon le mode actif.
final activeMaxAeProvider = Provider<double>((ref) {
  final mode = ref.watch(machiningModeProvider);
  return mode.maxWidthOfCut;
});
