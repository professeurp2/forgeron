import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/providers/jog_provider.dart';
import '../../../application/providers/di_providers.dart';
import '../../../application/services/audio_service.dart';
import 'gauge_widgets.dart';

/// Panneau de contrôle Jog 5-axes unifié (X/Y/Z/A/C).
///
/// Design de référence : panneau JOG CONTROL du Dashboard. Ce widget est
/// partagé par le Dashboard, le CNC Panel, l'écran Palpage et les écrans
/// mobiles afin qu'une seule implémentation existe pour ce contrôle
/// (comportement ET apparence identiques partout).
///
/// Se redimensionne en fonction de la largeur disponible (dial/D-pad plus
/// petits sur un panneau étroit ou un téléphone) via [LayoutBuilder].
class JogControlPanel extends StatelessWidget {
  /// Position courante des 5 axes [X, Y, Z, A, C] (repère pièce).
  final List<double> wPos;

  /// Affiche l'en-tête de section "JOG CONTROL" (à désactiver si l'appelant
  /// fournit déjà son propre titre, ex: CncPanelSectionContainer).
  final bool showHeader;

  const JogControlPanel({
    super.key,
    required this.wPos,
    this.showHeader = true,
  });

  // Tailles de référence (panneau JOG CONTROL du Dashboard, ~380px de large).
  // D-pad agrandi + plafond d'échelle relevé : sur mobile la flèche de jog
  // (32 % de la D-pad) passe d'environ 33 px à ~44 px, bien plus utilisable au
  // pouce et avec des gants.
  static const double _refWidth = 360.0;
  static const double _refDpad = 150.0;
  static const double _refArc = 118.0;
  static const double _refRing = 96.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _refWidth;
        final scale = (width / _refWidth).clamp(0.78, 1.15);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              const _JogSectionHeader(title: 'JOG CONTROL'),
              const SizedBox(height: 6),
            ],

            // ── PAS (INCRÉMENT) ────────────────────────────────────────
            _JogSectionLabel('PAS (INCRÉMENT)'),
            const SizedBox(height: 6),
            const _StepMultiplierSelector(),

            const SizedBox(height: 8),

            // ── AXES LINÉAIRES (X / Y / Z) ─────────────────────────────
            _JogSectionLabel('AXES LINÉAIRES'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Consumer(
                  builder: (ctx, r, _) {
                    final jogN = r.read(secureJogProvider.notifier);
                    return DpadCross(
                      size: _refDpad * scale,
                      onXPlus: () => jogN.jogLinear('X', 1),
                      onXMinus: () => jogN.jogLinear('X', -1),
                      onYPlus: () => jogN.jogLinear('Y', 1),
                      onYMinus: () => jogN.jogLinear('Y', -1),
                      onStop: () => jogN.stopJog(),
                    );
                  },
                ),
                Consumer(
                  builder: (ctx, r, _) {
                    final jogN = r.read(secureJogProvider.notifier);
                    return Column(
                      children: [
                        ZAxisButton(
                          isPlus: true,
                          onTap: () => jogN.jogLinear('Z', 1),
                        ),
                        const SizedBox(height: 6),
                        ZAxisButton(
                          isPlus: false,
                          onTap: () => jogN.jogLinear('Z', -1),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── AXES ROTATIFS (A / C) ──────────────────────────────────
            _JogSectionLabel('AXES ROTATIFS'),
            const SizedBox(height: 6),
            Row(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ArcGauge(
                          value: wPos.length > 3 ? wPos[3] : 0.0,
                          minValue: -90,
                          maxValue: 90,
                          color: context.fc.axisA,
                          axisLabel: 'A',
                          size: _refArc * scale,
                        ),
                        const SizedBox(height: 6),
                        Consumer(
                          builder: (ctx, r, _) {
                            final multiplier =
                                r.watch(cncJogMultiplierProvider);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotaryJogButton(
                                  isPlus: false,
                                  axisLabel: 'A',
                                  color: context.fc.axisA,
                                  onTap: () => r
                                      .read(machineRepositoryProvider)
                                      .jog('A', -multiplier.toDouble(), 3600),
                                ),
                                const SizedBox(width: 4),
                                RotaryJogButton(
                                  isPlus: true,
                                  axisLabel: 'A',
                                  color: context.fc.axisA,
                                  onTap: () => r
                                      .read(machineRepositoryProvider)
                                      .jog('A', multiplier.toDouble(), 3600),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RingGauge(
                          value: (wPos.length > 4 ? wPos[4] : 0.0) % 360,
                          color: context.fc.axisC,
                          axisLabel: 'C',
                          size: _refRing * scale,
                        ),
                        const SizedBox(height: 6),
                        Consumer(
                          builder: (ctx, r, _) {
                            final multiplier =
                                r.watch(cncJogMultiplierProvider);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotaryJogButton(
                                  isPlus: false,
                                  axisLabel: 'C',
                                  color: context.fc.axisC,
                                  onTap: () => r
                                      .read(machineRepositoryProvider)
                                      .jog('C', -multiplier.toDouble(), 3600),
                                ),
                                const SizedBox(width: 4),
                                RotaryJogButton(
                                  isPlus: true,
                                  axisLabel: 'C',
                                  color: context.fc.axisC,
                                  onTap: () => r
                                      .read(machineRepositoryProvider)
                                      .jog('C', multiplier.toDouble(), 3600),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Sélecteur de multiplicateur de pas (×1 / ×10 / ×100) — partagé par tous
/// les panneaux de Jog. Pilote [cncJogMultiplierProvider].
class _StepMultiplierSelector extends ConsumerWidget {
  const _StepMultiplierSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiplier = ref.watch(cncJogMultiplierProvider);
    return Row(
      children: [
        for (final mult in [1, 10, 100])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () {
                  ref.read(cncJogMultiplierProvider.notifier).state = mult;
                  ref.read(audioServiceProvider).play(SoundEffect.click);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  height: 46, // cible tactile confortable (gants/atelier)
                  decoration: BoxDecoration(
                    color: multiplier == mult
                        ? context.fc.primary.withValues(alpha: 0.15)
                        : context.fc.surfaceBright,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: multiplier == mult
                          ? context.fc.primary
                          : context.fc.surfaceBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '×$mult',
                      style: TextStyle(
                        color: multiplier == mult
                            ? context.fc.primary
                            : context.fc.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _JogSectionLabel extends StatelessWidget {
  final String text;
  const _JogSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.fc.textDisabled,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _JogSectionHeader extends StatelessWidget {
  final String title;
  const _JogSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.fc.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Icon(Icons.more_horiz, color: context.fc.textDisabled, size: 14),
      ],
    );
  }
}
