import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/camera_provider.dart';
import '../../core/theme/forgeron_colors.dart';

/// Sélecteur compact CAM / 3D. Il tient lieu de titre au panneau visualiseur.
///
/// Partagé par le panneau mobile et le tableau de bord desktop : la caméra doit
/// se prendre de la même façon des deux côtés.
///
/// À n'afficher que si une caméra est configurée ([cameraEnabledProvider]) —
/// sans elle, [effectiveVisualizerModeProvider] force le simulateur et le
/// sélecteur n'aurait qu'un seul choix utile.
class VisualizerModeToggle extends ConsumerWidget {
  const VisualizerModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final mode = ref.watch(effectiveVisualizerModeProvider);

    Widget segment(VisualizerMode value, IconData icon, String label) {
      final selected = mode == value;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(visualizerModeProvider.notifier).state = value;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? fc.primary.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: selected ? fc.primary : fc.textDisabled),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected ? fc.primary : fc.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fc.surfaceBorderDim),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        segment(VisualizerMode.camera, Icons.videocam, 'CAM'),
        segment(VisualizerMode.simulation3d, Icons.view_in_ar, '3D'),
      ]),
    );
  }
}
