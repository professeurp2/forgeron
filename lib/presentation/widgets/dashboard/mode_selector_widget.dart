import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/providers/machining_mode_provider.dart';
import '../../../domain/models/machining_mode.dart';
import '../../../core/i18n/app_localizations.dart';

/// Panneau **ForceGuard / Mode d'usinage**.
///
/// Affiche de façon lisible le mode actif (3AX / 5AX), l'état du garde-fou
/// d'effort, et les 4 limites de coupe autorisées présentées en tuiles.
/// Le changement de mode demande une confirmation.
class ModeSelectorWidget extends ConsumerWidget {
  const ModeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final mode = ref.watch(machiningModeProvider);
    final is5Ax = mode == MachiningMode.fiveAxis;

    // 5AX = effort bridé (vigilance) → accent primaire ; 3AX = A/C verrouillés
    // (sûr) → succès.
    final accent = is5Ax ? fc.primary : fc.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.10), fc.surface],
          stops: const [0.0, 0.6],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.14),
              blurRadius: 16,
              spreadRadius: -4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête : badge mode + libellé + toggle ──
          Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                is5Ax ? Icons.rotate_90_degrees_ccw_rounded : Icons.lock_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            // Expanded + ellipse : le libellé prenait sa largeur naturelle,
            // donc dans la colonne étroite de l'écran Palpage la rangée
            // débordait — bandes jaunes et noires en bout de carte.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          fontFamily: 'JetBrains Mono',
                          height: 1.0)),
                  Text(tr(mode.label),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fc.textDisabled, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ModeToggle(
              is5Ax: is5Ax,
              accent: accent,
              onChanged: (v) => _handleModeChange(context, ref, v),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Bannière d'état ForceGuard ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(is5Ax ? Icons.shield_rounded : Icons.lock_outline_rounded,
                  size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 10.5, color: fc.textSecondary),
                    children: is5Ax
                        ? [
                            TextSpan(
                                text: 'FORCEGUARD ACTIF',
                                style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
                            TextSpan(
                                text:
                                    ' — avance bridée pour garder R ≤ ${mode.maxResultantForce} N'),
                          ]
                        : [
                            TextSpan(
                                text: 'AXES A/C VERROUILLÉS',
                                style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
                            const TextSpan(text: ' — usinage 3 axes, pas de bridage'),
                          ],
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Grille des 4 limites ──
          Row(children: [
            Expanded(
                child: _ForceStatTile(
                    icon: Icons.compress_rounded,
                    label: tr('R_max'),
                    value: '${mode.maxResultantForce}',
                    unit: 'N',
                    accent: accent)),
            const SizedBox(width: 8),
            Expanded(
                child: _ForceStatTile(
                    icon: Icons.fast_forward_rounded,
                    label: tr('F_max'),
                    value: '${mode.maxFeedrate.toInt()}',
                    unit: 'mm/min',
                    accent: accent)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _ForceStatTile(
                    icon: Icons.height_rounded,
                    label: tr('ap_max'),
                    value: '${mode.maxDepthOfCut}',
                    unit: 'mm',
                    accent: accent)),
            const SizedBox(width: 8),
            Expanded(
                child: _ForceStatTile(
                    icon: Icons.width_normal_rounded,
                    label: tr('ae_max'),
                    value: '${mode.maxWidthOfCut}',
                    unit: 'mm',
                    accent: accent)),
          ]),
        ],
      ),
    );
  }

  void _handleModeChange(BuildContext context, WidgetRef ref, bool to5Ax) {
    final fc = context.fc;
    final newMode = to5Ax ? MachiningMode.fiveAxis : MachiningMode.threeAxis;
    final accent = to5Ax ? fc.primary : fc.success;

    final description = to5Ax
        ? 'Mode 5 axes simultanés. Les axes A et C seront déverrouillés et '
            'le ForceGuard bornera l\'avance de sécurité.'
        : 'Mode 3 axes (X, Y, Z). Les axes A et C seront verrouillés en '
            'position actuelle.';

    final chips = to5Ax
        ? [
            _DialogStat('AVANCE MAX', '${newMode.maxFeedrate.toInt()}', 'mm/min'),
            _DialogStat('R_max', '${newMode.maxResultantForce}', 'N'),
          ]
        : [
            _DialogStat('FORCE NOM.', '${newMode.nominalForce.toInt()}', 'N'),
            _DialogStat('AXES A·C', 'LOCK', ''),
          ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: fc.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 34,
                spreadRadius: -6,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Bandeau héro : dégradé + badge icône ─────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.15),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(
                        to5Ax
                            ? Icons.view_in_ar_rounded
                            : Icons.grid_on_rounded,
                        color: accent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('Passer en {} ?', [newMode.shortLabel]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Corps : description + chips paramètres ───────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  children: [
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: fc.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        for (int i = 0; i < chips.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: _buildDialogChip(fc, accent, chips[i])),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // ── Actions ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: fc.surfaceBorder, width: 1.2),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('Annuler'),
                            style: TextStyle(
                                color: fc.textSecondary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ref.read(machiningModeProvider.notifier).state =
                              newMode;
                          Navigator.pop(ctx);
                        },
                        child: Text(tr('Confirmer'),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogChip(
      ForgeronColorPalette fc, Color accent, _DialogStat s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: fc.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.surfaceBorder.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Text(
            s.label,
            style: TextStyle(
              color: fc.textDisabled,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: s.value,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              children: [
                if (s.unit.isNotEmpty)
                  TextSpan(
                    text: ' ${s.unit}',
                    style: TextStyle(
                      color: fc.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Petite donnée affichée dans une puce du dialog de changement de mode.
class _DialogStat {
  final String label;
  final String value;
  final String unit;
  const _DialogStat(this.label, this.value, this.unit);
}

/// Toggle 3AX / 5AX theme-aware.
class _ModeToggle extends StatelessWidget {
  final bool is5Ax;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _ModeToggle(
      {required this.is5Ax, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return GestureDetector(
      onTap: () => onChanged(!is5Ax),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 58,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: accent.withValues(alpha: 0.18),
          border: Border.all(color: accent),
        ),
        child: Stack(children: [
          Positioned(
            left: 8,
            top: 7,
            child: Text('3',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: !is5Ax ? Colors.white : fc.textDisabled)),
          ),
          Positioned(
            right: 8,
            top: 7,
            child: Text('5',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: is5Ax ? Colors.white : fc.textDisabled)),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: is5Ax ? 30 : 2,
            top: 2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Tuile d'une limite de coupe (R_max, F_max, ap_max, ae_max).
class _ForceStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accent;

  const _ForceStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: fc.textDisabled,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono')),
          ]),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
              ),
              const SizedBox(width: 3),
              Text(unit,
                  style: TextStyle(color: fc.textDisabled, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}
