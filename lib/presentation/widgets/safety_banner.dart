import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/streaming_provider.dart';

/// Bannière d'alerte de sécurité, affichée en haut de l'application.
///
/// Deux cas, tous deux invisibles auparavant :
///  - **E-STOP non transmis** : la liaison était coupée, la commande d'arrêt
///    n'est jamais partie. L'opérateur croyait la machine arrêtée.
///  - **Flux bloqué** : l'ESP32 n'acquitte plus. Le programme est suspendu.
///
/// Rien ne se ferme tout seul : l'opérateur doit acquitter explicitement.
class SafetyBanner extends ConsumerWidget {
  const SafetyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estopFailed = ref.watch(estopFailedProvider);
    final stallReason = ref.watch(streamStallProvider);

    if (estopFailed) {
      return _Bar(
        color: context.fc.danger,
        icon: Icons.gpp_bad_rounded,
        title: 'ARRÊT D\'URGENCE NON TRANSMIS',
        detail:
            'La liaison est coupée : la commande n\'est jamais partie. '
            'La machine n\'est PAS arrêtée — coupez l\'alimentation physiquement.',
        onDismiss: () =>
            ref.read(estopFailedProvider.notifier).state = false,
      );
    }

    if (stallReason != null) {
      return _Bar(
        color: context.fc.warning,
        icon: Icons.pause_circle_filled_rounded,
        title: 'FLUX SUSPENDU',
        detail: '$stallReason — le programme est interrompu.',
        onDismiss: () =>
            ref.read(streamStallProvider.notifier).state = null,
      );
    }

    return const SizedBox.shrink();
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onDismiss;

  const _Bar({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color, width: 2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: context.fc.textPrimary,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: color, size: 18),
              tooltip: 'Acquitter',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
