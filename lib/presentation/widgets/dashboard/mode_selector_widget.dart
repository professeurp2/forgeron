import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/machining_mode_provider.dart';
import '../../../domain/models/machining_mode.dart';

/// Sélecteur de mode d'usinage avec indicateur des limites actives.
///
/// Affiche un toggle 3AX / 5AX avec les paramètres de coupe autorisés
/// pour le mode sélectionné. Le changement de mode demande une
/// confirmation pour éviter les basculements accidentels.
class ModeSelectorWidget extends ConsumerWidget {
  const ModeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(machiningModeProvider);
    final is5Ax = mode == MachiningMode.fiveAxis;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: is5Ax
              ? const Color(0xFFFF9800) // Orange pour 5AX (attention)
              : const Color(0xFF4CAF50), // Vert pour 3AX (sûr)
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête : Mode + Toggle ──
          Row(
            children: [
              Icon(
                is5Ax ? Icons.rotate_90_degrees_ccw : Icons.lock_outline,
                color: is5Ax
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF4CAF50),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                mode.shortLabel,
                style: TextStyle(
                  color: is5Ax
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const Spacer(),
              // Toggle switch
              _ModeToggle(
                is5Ax: is5Ax,
                onChanged: (value) =>
                    _handleModeChange(context, ref, value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Label complet ──
          Text(
            mode.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          // ── Limites actives ──
          _LimitRow(
            label: 'R_max',
            value: '${mode.maxResultantForce} N',
            icon: Icons.speed,
          ),
          _LimitRow(
            label: 'F_max',
            value: '${mode.maxFeedrate.toInt()} mm/min',
            icon: Icons.fast_forward,
          ),
          _LimitRow(
            label: 'ap_max',
            value: '${mode.maxDepthOfCut} mm',
            icon: Icons.height,
          ),
          _LimitRow(
            label: 'ae_max',
            value: '${mode.maxWidthOfCut} mm',
            icon: Icons.width_normal,
          ),
          if (is5Ax) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.shield, size: 12, color: Colors.amber.shade300),
                const SizedBox(width: 4),
                Text(
                  'ForceGuard actif',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleModeChange(
      BuildContext context, WidgetRef ref, bool to5Ax) {
    final newMode =
        to5Ax ? MachiningMode.fiveAxis : MachiningMode.threeAxis;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Changer en ${newMode.shortLabel} ?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          to5Ax
              ? 'Mode 5 axes simultanés.\n'
                  'Le ForceGuard limitera l\'avance à '
                  '${newMode.maxFeedrate.toInt()} mm/min '
                  '(R_max = ${newMode.maxResultantForce} N).\n\n'
                  'Les axes A et C seront déverrouillés.'
              : 'Mode 3 axes (X, Y, Z uniquement).\n'
                  'Les axes A et C seront verrouillés en position actuelle.\n'
                  'Force nominale : ${newMode.nominalForce.toInt()} N.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: to5Ax
                  ? const Color(0xFFFF9800)
                  : const Color(0xFF4CAF50),
            ),
            onPressed: () {
              ref.read(machiningModeProvider.notifier).state = newMode;
              Navigator.pop(ctx);
            },
            child: Text('Passer en ${newMode.shortLabel}'),
          ),
        ],
      ),
    );
  }
}

/// Toggle switch stylisé pour le mode d'usinage.
class _ModeToggle extends StatelessWidget {
  final bool is5Ax;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.is5Ax, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!is5Ax),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: is5Ax
              ? const Color(0xFFFF9800).withOpacity(0.3)
              : const Color(0xFF4CAF50).withOpacity(0.3),
          border: Border.all(
            color: is5Ax
                ? const Color(0xFFFF9800)
                : const Color(0xFF4CAF50),
          ),
        ),
        child: Stack(
          children: [
            // Labels
            Positioned(
              left: 6,
              top: 6,
              child: Text(
                '3',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: !is5Ax ? Colors.white : Colors.white38,
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Text(
                '5',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: is5Ax ? Colors.white : Colors.white38,
                ),
              ),
            ),
            // Thumb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: is5Ax ? 30 : 2,
              top: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: is5Ax
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF4CAF50),
                  boxShadow: [
                    BoxShadow(
                      color: (is5Ax
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF4CAF50))
                          .withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'affichage d'une limite de coupe.
class _LimitRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _LimitRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }
}
