import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/services/audio_service.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/gauge_widgets.dart';
import '../widgets/dashboard/workshop_layout.dart';
import '../widgets/dashboard/cnc_panel_widgets.dart';
import '../widgets/trunnion_visualizer.dart';
import 'cnc_panel_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SCREEN — Layout premium 3 zones (Forgeron Design v2)
//
//  ┌─────────────────────┬──────────────────────────┬──────────────────────┐
//  │  ZONE CENTRALE      │                          │  PANEL DROIT         │
//  │  Visualiseur 3D     │  (sidebar gérée par      │  • DRO 5 axes        │
//  │  + barre programme  │   MainScaffold)           │  • JOG CONTROL       │
//  │                     │                          │  • Quick Actions     │
//  └─────────────────────┴──────────────────────────┴──────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWorkshopMode = ref.watch(isWorkshopModeProvider);
    final isFullScreen = ref.watch(isVisualizerFullScreenProvider);

    if (isWorkshopMode) {
      return const WorkshopLayout();
    }

    if (isFullScreen) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: FullScreenVisualizer(),
      );
    }

    return const _DashboardLayout();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DashboardLayout extends ConsumerWidget {
  const _DashboardLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.fc.background,
      body: Row(
        children: [
          // ── Zone centrale : Header machine + Visualisateur + Programme ──
          Expanded(
            flex: 5,
            child: _CenterZone(),
          ),

          // ── Séparateur ──
          Container(
            width: 1,
            color: context.fc.surfaceBorder,
          ),

          // ── Panel droit : DRO + JOG + Quick Actions ──
          SizedBox(
            width: 320,
            child: _RightPanel(),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ZONE CENTRALE
// ═════════════════════════════════════════════════════════════════════════════

class _CenterZone extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final gcodeState = ref.watch(gcodeProvider);
    final progress = state?.sdPercent ?? 0.0;
    final spindle = state?.spindleSpeed.toStringAsFixed(0) ?? '0';
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;

    return Column(
      children: [
        // ── Header machine compact ──────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.fc.surface,
            border: Border(bottom: BorderSide(color: context.fc.surfaceBorder)),
          ),
          child: Row(
            children: [
              Text('FORGERON',
                  style: TextStyle(
                      color: context.fc.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(width: 12),
              // Indicateur statut
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? context.fc.success : context.fc.textDisabled,
                  boxShadow: isOnline
                      ? [BoxShadow(color: context.fc.success, blurRadius: 8)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Barre d'avance
              Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: context.fc.surfaceBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ((state?.overrides.isNotEmpty == true ? state!.overrides[0] : 100) / 200).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.fc.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$spindle RPM',
                  style: TextStyle(
                      color: context.fc.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
              const SizedBox(width: 12),
              _StatusChip(state: state),
            ],
          ),
        ),

        // ── Visualisateur 3D ────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.fc.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.fc.surfaceBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  TrunnionVisualizer(mPos: mPos),
                  // Label
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.fc.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.fc.surfaceBorder),
                      ),
                      child: Text('CENTER',
                          style: TextStyle(
                              color: context.fc.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                  ),
                  // Bouton fullscreen
                  Positioned(
                    top: 8, right: 8,
                    child: Consumer(
                      builder: (ctx, r, _) => IconButton(
                        icon: Icon(Icons.fullscreen, color: context.fc.textDisabled, size: 20),
                        onPressed: () => r.read(isVisualizerFullScreenProvider.notifier).state = true,
                        tooltip: 'Plein écran',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Bas : 3 cartes (Programme / Historique / Avances) ────────────
        SizedBox(
          height: 160,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Carte PROGRAMME (G-Code)
                Expanded(
                  flex: 3,
                  child: _DashCard(
                    title: 'PROGRAMME',
                    child: gcodeState.allLines.isEmpty
                        ? Text('Aucun programme chargé',
                            style: TextStyle(color: context.fc.textDisabled, fontSize: 10))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: gcodeState.allLines
                                .take(5)
                                .toList()
                                .asMap()
                                .entries
                                .map((e) {
                              final isActive = e.key == (state?.activeLineIndex ?? 0);
                              return Text('${e.key + 1}  ${e.value}',
                                  style: TextStyle(
                                      color: isActive ? context.fc.primary : context.fc.textSecondary,
                                      fontSize: 9,
                                      fontFamily: 'JetBrains Mono',
                                      fontWeight: isActive ? FontWeight.w900 : FontWeight.normal),
                                  overflow: TextOverflow.ellipsis);
                            }).toList(),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Carte HISTORIQUE
                Expanded(
                  flex: 3,
                  child: _DashCard(
                    title: 'HISTORIQUE',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Execution timeline',
                            style: TextStyle(color: context.fc.textDisabled, fontSize: 10)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 10,
                            backgroundColor: context.fc.surfaceBorder,
                            color: context.fc.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${progress.toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: context.fc.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'JetBrains Mono')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Carte AVANCES
                Expanded(
                  flex: 2,
                  child: _DashCard(
                    title: 'AVANCES',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CompactFeedBar(
                          label: 'Feed override',
                          value: (state?.overrides.isNotEmpty == true ? state!.overrides[0] : 100).toDouble(),
                          max: 200, color: context.fc.primary),
                        const SizedBox(height: 8),
                        _CompactFeedBar(
                          label: 'Spindle override',
                          value: (state?.overrides.length == 3 ? state!.overrides[2] : 100).toDouble(),
                          max: 200, color: context.fc.secondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.fc.surfaceBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(title,
                style: TextStyle(
                    color: context.fc.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const Spacer(),
            Icon(Icons.more_horiz, color: context.fc.textDisabled, size: 14),
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CompactFeedBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  const _CompactFeedBar({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text(label, style: TextStyle(color: context.fc.textDisabled, fontSize: 9)),
          const Spacer(),
          Text('${value.toInt()}%',
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: context.fc.surfaceBorder,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MachineState? state;
  const _StatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final status = state?.status ?? MachineStatus.offline;
    final color = switch (status) {
      MachineStatus.idle  => context.fc.success,
      MachineStatus.run   => context.fc.primary,
      MachineStatus.hold  => context.fc.warning,
      MachineStatus.alarm => context.fc.error,
      _                   => context.fc.textDisabled,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.name.toUpperCase(),
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANEL DROIT : DRO + JOG CONTROL + QUICK ACTIONS
// ═════════════════════════════════════════════════════════════════════════════

class _RightPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return Container(
      color: context.fc.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── POSITION DRO ──────────────────────────────────────────
            _PanelSectionHeader(title: 'POSITION DRO', trailing: Text(
              'Work Pos.',
              style: TextStyle(color: context.fc.textDisabled, fontSize: 9),
            )),
            const SizedBox(height: 4),

            // X + Y sur une ligne
            Row(children: [
              Expanded(child: _DroBig(label: 'X', value: wPos[0], color: context.fc.axisX)),
              const SizedBox(width: 4),
              Expanded(child: _DroBig(label: 'Y', value: wPos[1], color: context.fc.axisY)),
            ]),
            // Z sur toute la largeur
            _DroBig(label: 'Z', value: wPos[2], color: context.fc.axisZ),
            // A + C sur une ligne
            Row(children: [
              Expanded(child: _DroBig(label: 'A', value: wPos[3], color: context.fc.axisA, isRotary: true)),
              const SizedBox(width: 4),
              Expanded(child: _DroBig(label: 'C', value: wPos[4], color: context.fc.axisC, isRotary: true)),
            ]),

            const SizedBox(height: 8),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 8),

            // ── JOG CONTROL ──────────────────────────────────────────
            const _PanelSectionHeader(title: 'JOG CONTROL'),
            const SizedBox(height: 6),

            // Section PAS (x1 / x10 / x100)
            Text('PAS (INCRÉMENT)',
                style: TextStyle(color: context.fc.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Consumer(builder: (ctx, r, _) {
              final multiplier = r.watch(cncJogMultiplierProvider);
              return Row(
                children: [
                  for (final mult in [1, 10, 100])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: () {
                            r.read(cncJogMultiplierProvider.notifier).state = mult;
                            r.read(audioServiceProvider).play(SoundEffect.click);
                            HapticFeedback.selectionClick();
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: multiplier == mult
                                  ? context.fc.primary.withValues(alpha: 0.15)
                                  : context.fc.surfaceBright,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: multiplier == mult
                                    ? context.fc.primary
                                    : context.fc.surfaceBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text('×$mult',
                                  style: TextStyle(
                                      color: multiplier == mult
                                          ? context.fc.primary
                                          : context.fc.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'JetBrains Mono')),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),

            const SizedBox(height: 8),

            // Section AXES LINÉAIRES (X / Y / Z)
            Text('AXES LINÉAIRES',
                style: TextStyle(color: context.fc.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Dpad XY
                Consumer(builder: (ctx, r, _) {
                  final jogN = r.read(secureJogProvider.notifier);
                  return DpadCross(
                    size: 120,
                    onXPlus:  () => jogN.jogLinear('X', 1),
                    onXMinus: () => jogN.jogLinear('X', -1),
                    onYPlus:  () => jogN.jogLinear('Y', 1),
                    onYMinus: () => jogN.jogLinear('Y', -1),
                    onStop:   () => jogN.stopJog(),
                  );
                }),
                // Axe Z
                Consumer(builder: (ctx, r, _) {
                  final jogN = r.read(secureJogProvider.notifier);
                  return Column(
                    children: [
                      ZAxisButton(isPlus: true, onTap: () => jogN.jogLinear('Z', 1)),
                      const SizedBox(height: 6),
                      ZAxisButton(isPlus: false, onTap: () => jogN.jogLinear('Z', -1)),
                    ],
                  );
                }),
              ],
            ),

            const SizedBox(height: 8),

            // Section AXES ROTATIFS (A / C) — Molettes CncJogDial
            Text('AXES ROTATIFS',
                style: TextStyle(color: context.fc.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Axe A (molette CncJogDial)
                Consumer(builder: (ctx, r, _) {
                  final multiplier = r.watch(cncJogMultiplierProvider);
                  return CncJogDial(
                    axis: 'A',
                    label: 'TILT',
                    color: context.fc.axisA,
                    currentValue: wPos[3],
                    multiplier: multiplier,
                    minValue: -90,
                    maxValue: 90,
                    isContinuous: false,
                    onJog: (step) {
                      r.read(machineRepositoryProvider).jog('A', step, 3600);
                    },
                    size: 100,
                  );
                }),
                // Axe C (molette CncJogDial)
                Consumer(builder: (ctx, r, _) {
                  final multiplier = r.watch(cncJogMultiplierProvider);
                  return CncJogDial(
                    axis: 'C',
                    label: 'PLATEAU',
                    color: context.fc.axisC,
                    currentValue: wPos[4],
                    multiplier: multiplier,
                    isContinuous: true,
                    minValue: 0,
                    maxValue: 360,
                    onJog: (step) {
                      r.read(machineRepositoryProvider).jog('C', step, 3600);
                    },
                    size: 100,
                  );
                }),
              ],
            ),

            const SizedBox(height: 8),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 8),

            // ── QUICK ACTIONS ─────────────────────────────────────────
            const _PanelSectionHeader(title: 'QUICK ACTIONS'),
            const SizedBox(height: 8),

            Consumer(builder: (ctx, r, _) {
              final repo = r.read(machineRepositoryProvider);
              final audio = r.read(audioServiceProvider);
              return Row(
                children: [
                  _QAction(label: 'CYCLE\nSTART', color: context.fc.success, icon: Icons.play_arrow_rounded,
                    onTap: () { repo.resume(); audio.play(SoundEffect.click); HapticFeedback.mediumImpact(); }),
                  const SizedBox(width: 6),
                  _QAction(label: 'FEED\nHOLD', color: context.fc.warning, icon: Icons.pause_rounded,
                    onTap: () { repo.pause(); audio.play(SoundEffect.click); HapticFeedback.mediumImpact(); }),
                  const SizedBox(width: 6),
                  _QAction(label: 'E-STOP', color: context.fc.danger, icon: Icons.bolt_rounded,
                    onTap: () { repo.emergencyStop(); audio.play(SoundEffect.alarm); HapticFeedback.vibrate(); }),
                  const SizedBox(width: 6),
                  _QAction(label: 'JOG\nSTOP', color: context.fc.primary, icon: Icons.stop_rounded,
                    onTap: () { r.read(secureJogProvider.notifier).stopJog(); audio.play(SoundEffect.alert); HapticFeedback.heavyImpact(); }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}


// ─── Widgets utilitaires ───────────────────────────────────────────────────

class _PanelSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _PanelSectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title,
          style: TextStyle(
              color: context.fc.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      const Spacer(),
      if (trailing case final t?) t,
      Icon(Icons.more_horiz, color: context.fc.textDisabled, size: 14),
    ]);
  }
}

/// Affichage DRO compact — style écran LCD 7 segments
class _DroBig extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isRotary;
  const _DroBig({
    required this.label,
    required this.value,
    required this.color,
    this.isRotary = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = isRotary
        ? '${value.toStringAsFixed(1)}°'
        : value.toStringAsFixed(3);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.fc.background,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
          const SizedBox(width: 4),
          Expanded(
            child: Text(display,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono',
                    shadows: [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8)])),
          ),
        ],
      ),
    );
  }
}

class _QAction extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _QAction({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vues plein écran (réutilisées) ──────────────────────────────────────

class FullScreenVisualizer extends ConsumerWidget {
  const FullScreenVisualizer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    return Stack(
      children: [
        TrunnionVisualizer(mPos: mPos),
        Positioned(
          top: 16, right: 16,
          child: IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white70),
            onPressed: () => ref.read(isVisualizerFullScreenProvider.notifier).state = false,
          ),
        ),
      ],
    );
  }
}
