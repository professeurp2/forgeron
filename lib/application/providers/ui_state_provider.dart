import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/ui_state_provider.dart';

final isWorkshopModeProvider = StateProvider<bool>((ref) => false);
final isVisualizerFullScreenProvider = StateProvider<bool>((ref) => false);
final simulationSpeedProvider = StateProvider<double>((ref) => 1.0);
final show3DOnMobileProvider = StateProvider<bool>((ref) => false);
final showVectorsProvider = StateProvider<bool>((ref) => false);

/// Vrai pendant qu'une transition de page (cube 3D) est en cours.
/// Le simulateur (WebView) ne pouvant pas pivoter en 3D, on le masque derrière
/// un panneau figé Flutter pendant la rotation pour éviter la déchirure.
final pageTransitioningProvider = StateProvider<bool>((ref) => false);
