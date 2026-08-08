import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/providers/jog_provider.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/spindle_provider.dart';
import '../../../application/providers/motor_provider.dart';
import '../../../application/services/audio_service.dart';
import '../../../domain/models/machine_state.dart';
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
class JogControlPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Alerte de garde jog (hors-course / fin de course) → snackbar.
    ref.listen(jogGuardMessageProvider, (prev, next) {
      if (next == null) return;
      final fc = context.fc;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next.message),
        backgroundColor: next.blocked ? fc.danger : fc.warning,
        duration: const Duration(seconds: 2),
      ));
      // Réinitialise pour permettre une nouvelle alerte identique.
      Future.microtask(
          () => ref.read(jogGuardMessageProvider.notifier).state = null);
    });
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
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotaryJogButton(
                                  isPlus: false,
                                  axisLabel: 'A',
                                  color: context.fc.axisA,
                                  onTap: () => r
                                      .read(secureJogProvider.notifier)
                                      .jogRotary('A', -1),
                                ),
                                const SizedBox(width: 4),
                                RotaryJogButton(
                                  isPlus: true,
                                  axisLabel: 'A',
                                  color: context.fc.axisA,
                                  onTap: () => r
                                      .read(secureJogProvider.notifier)
                                      .jogRotary('A', 1),
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
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotaryJogButton(
                                  isPlus: false,
                                  axisLabel: 'C',
                                  color: context.fc.axisC,
                                  onTap: () => r
                                      .read(secureJogProvider.notifier)
                                      .jogRotary('C', -1),
                                ),
                                const SizedBox(width: 4),
                                RotaryJogButton(
                                  isPlus: true,
                                  axisLabel: 'C',
                                  color: context.fc.axisC,
                                  onTap: () => r
                                      .read(secureJogProvider.notifier)
                                      .jogRotary('C', 1),
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

            const SizedBox(height: 16),

            // ── BROCHE (Marche / Arrêt — relais tout-ou-rien) ──────────
            _JogSectionLabel('BROCHE'),
            const SizedBox(height: 6),
            _SpindleControl(scale: scale),

            const SizedBox(height: 12),

            // ── MOTEURS (désactivation via le pin ENA commun) ──────────
            _JogSectionLabel('MOTEURS'),
            const SizedBox(height: 6),
            _MotorDisableButton(scale: scale),
          ],
        );
      },
    );
  }
}

/// Bouton Marche/Arrêt de la broche à relais.
///
/// Envoie `M3` (marche) / `M5` (arrêt) via [spindleControllerProvider]. L'état
/// affiché suit [MachineState.spindleOn] (champ accessoire `A:` du rapport
/// GRBL), donc il reflète l'état réel de la machine, pas une supposition.
/// Désactivé hors ligne.
class _SpindleControl extends ConsumerWidget {
  final double scale;
  const _SpindleControl({required this.scale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final state = ref.watch(machineStateProvider).valueOrNull;
    final online = state != null && state.status != MachineStatus.offline;
    final on = state?.spindleOn ?? false;
    final color = on ? fc.danger : fc.success;

    return GestureDetector(
      onTap: online
          ? () async {
              final res = await ref.read(spindleControllerProvider).toggle();
              ref.read(audioServiceProvider).play(SoundEffect.click);
              HapticFeedback.mediumImpact();
              if (!res.ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res.message ?? 'Commande broche refusée'),
                  backgroundColor: fc.danger,
                  duration: const Duration(seconds: 2),
                ));
              }
            }
          : null,
      child: Container(
        height: 52 * scale.clamp(0.9, 1.1),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: online ? color.withValues(alpha: 0.12) : fc.surfaceBright,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: online ? color : fc.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              on
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: online ? color : fc.textDisabled,
              size: 26,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  on ? 'ARRÊT BROCHE' : 'MARCHE BROCHE',
                  style: TextStyle(
                    color: online ? color : fc.textDisabled,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  !online
                      ? 'hors ligne'
                      : (on ? 'active (M3)' : 'arrêtée (M5)'),
                  style: TextStyle(color: fc.textSecondary, fontSize: 10),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? fc.danger : fc.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Couper les moteurs » : désactive les 5 drivers via le pin ENA
/// commun (`$MD`). Confirmation obligatoire car relâcher le couple peut faire
/// **tomber l'axe Z** sous son poids. Désactivé hors ligne.
class _MotorDisableButton extends ConsumerWidget {
  final double scale;
  const _MotorDisableButton({required this.scale});

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final fc = context.fc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text('Couper les moteurs ?',
            style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: fc.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les 5 axes vont relâcher leur couple et tourner librement. '
              'ATTENTION : l\'axe Z n\'est plus retenu et peut TOMBER. '
              'Assure-toi que Z est en position basse ou sécurisée. '
              'Les moteurs se réactivent au prochain déplacement.',
              style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: fc.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: fc.danger, foregroundColor: Colors.white),
            child: const Text('Couper'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final res = await ref.read(motorControllerProvider).disableAll();
    ref.read(audioServiceProvider).play(SoundEffect.click);
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.ok ? 'Moteurs coupés — axes libres.' : (res.message ?? 'Commande refusée')),
        backgroundColor: res.ok ? fc.warning : fc.danger,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final state = ref.watch(machineStateProvider).valueOrNull;
    final online = state != null && state.status != MachineStatus.offline;
    final color = fc.warning;

    return GestureDetector(
      onTap: online ? () => _run(context, ref) : null,
      child: Container(
        height: 52 * scale.clamp(0.9, 1.1),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: online ? color.withValues(alpha: 0.12) : fc.surfaceBright,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: online ? color : fc.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.power_settings_new_rounded,
                color: online ? color : fc.textDisabled, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'COUPER MOTEURS',
                  style: TextStyle(
                    color: online ? color : fc.textDisabled,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  online ? 'libère les axes ⚠️ chute Z' : 'hors ligne',
                  style: TextStyle(color: fc.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
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
