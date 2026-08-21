import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/camera_provider.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../core/theme/forgeron_colors.dart';

/// Vue caméra temps réel (ESP32-CAM). Prend la place du simulateur 3D dans le
/// panneau du visualiseur.
///
/// La boucle de capture démarre à l'affichage et s'arrête à la destruction du
/// widget : quitter l'onglet coupe réellement le trafic vers la caméra, ce qui
/// est indispensable puisqu'elle partage l'AP avec le contrôleur.
class CameraView extends ConsumerStatefulWidget {
  const CameraView({super.key});

  @override
  ConsumerState<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<CameraView> {
  @override
  void initState() {
    super.initState();
    // Après le premier frame : lire un provider pendant initState est interdit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cameraFeedProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;

    if (ref.watch(isSimulationModeProvider)) {
      return _Placeholder(
        icon: Icons.videocam_off_outlined,
        title: 'MODE SIMULATION',
        detail: 'Aucune caméra à simuler.',
      );
    }

    final feed = ref.watch(cameraFeedProvider);
    final liveAllowed = ref.watch(cameraLiveAllowedProvider);

    // Caméra perdue et jamais rien reçu : plein écran d'erreur.
    if (feed.isLost && !feed.hasFrame) {
      return _Placeholder(
        icon: Icons.videocam_off_outlined,
        title: 'CAMÉRA INJOIGNABLE',
        detail: '${ref.watch(cameraIpProvider)} ne répond pas.',
        action: TextButton(
          onPressed: () => ref.read(cameraFeedProvider.notifier).start(),
          child: const Text('Réessayer'),
        ),
      );
    }

    if (!feed.hasFrame) {
      return Center(
        child: CircularProgressIndicator(color: fc.primary, strokeWidth: 2),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // gaplessPlayback : sans lui, l'écran clignote entre deux captures.
        Image.memory(
          feed.frame!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),

        // Bandeau d'explication quand la cadence est volontairement réduite.
        if (!liveAllowed)
          Positioned(
            left: 8,
            top: 8,
            child: _Badge(
              color: fc.warning,
              icon: Icons.speed,
              label: 'CADENCE RÉDUITE — USINAGE EN COURS',
            ),
          ),

        // La caméra a décroché mais on garde la dernière image à l'écran :
        // il faut dire clairement qu'elle n'est plus fraîche.
        if (feed.isLost)
          Positioned(
            left: 8,
            bottom: 8,
            child: _Badge(
              color: fc.error,
              icon: Icons.warning_amber_rounded,
              label: 'IMAGE FIGÉE — CAMÉRA PERDUE',
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ]),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: fc.textDisabled),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: fc.textDisabled,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail,
            style: TextStyle(color: fc.textDisabled, fontSize: 10),
            textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ]),
    );
  }
}
