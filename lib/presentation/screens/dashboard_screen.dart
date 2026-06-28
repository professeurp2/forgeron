import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/services/audio_service.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/gauge_widgets.dart';
import '../widgets/dashboard/workshop_layout.dart';
import '../widgets/trunnion_visualizer.dart';

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
      backgroundColor: AppColors.background,
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
            color: AppColors.surfaceBorder,
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
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Row(
            children: [
              Text('FORGERON',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(width: 12),
              // Indicateur statut
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppColors.success : AppColors.textDisabled,
                  boxShadow: isOnline
                      ? [BoxShadow(color: AppColors.success, blurRadius: 8)]
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
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ((state?.overrides.isNotEmpty == true ? state!.overrides[0] : 100) / 200).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$spindle RPM',
                  style: TextStyle(
                      color: AppColors.textPrimary,
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
              color: const Color(0xFF0A0C10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder),
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
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: const Text('CENTER',
                          style: TextStyle(
                              color: AppColors.textSecondary,
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
                        icon: const Icon(Icons.fullscreen, color: AppColors.textDisabled, size: 20),
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
                            style: TextStyle(color: AppColors.textDisabled, fontSize: 10))
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
                                      color: isActive ? AppColors.primary : AppColors.textSecondary,
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
                        const Text('Execution timeline',
                            style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 10,
                            backgroundColor: AppColors.surfaceBorder,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${progress.toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: AppColors.primary,
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
                          max: 200, color: AppColors.primary),
                        const SizedBox(height: 8),
                        _CompactFeedBar(
                          label: 'Spindle override',
                          value: (state?.overrides.length == 3 ? state!.overrides[2] : 100).toDouble(),
                          max: 200, color: AppColors.secondary),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const Spacer(),
            const Icon(Icons.more_horiz, color: AppColors.textDisabled, size: 14),
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
          Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9)),
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
            backgroundColor: AppColors.surfaceBorder,
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
      MachineStatus.idle  => AppColors.success,
      MachineStatus.run   => AppColors.primary,
      MachineStatus.hold  => AppColors.warning,
      MachineStatus.alarm => AppColors.error,
      _                   => AppColors.textDisabled,
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
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── POSITION DRO ──────────────────────────────────────────
            _PanelSectionHeader(title: 'POSITION DRO', trailing: Text(
              'W-value − Target',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 9),
            )),
            const SizedBox(height: 8),
            _DroBig(label: 'X', value: wPos[0], color: AppColors.axisX),
            _DroBig(label: 'Y', value: wPos[1], color: AppColors.axisY),
            _DroBig(label: 'Z', value: wPos[2], color: AppColors.axisZ),
            _DroBig(label: 'A', value: wPos[3], color: AppColors.axisA, isRotary: true),
            _DroBig(label: 'C', value: wPos[4], color: AppColors.axisC, isRotary: true),

            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.surfaceBorder),
            const SizedBox(height: 16),

            // ── JOG CONTROL ──────────────────────────────────────────
            const _PanelSectionHeader(title: 'JOG CONTROL'),
            const SizedBox(height: 12),

            // Croix X + Jauge A en row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Croix XY centrale
                Expanded(
                  child: Consumer(builder: (ctx, r, _) {
                    final jogN = r.read(secureJogProvider.notifier);
                    return DpadCross(
                      size: 130,
                      onXPlus:  () => jogN.jogLinear('X', 1),
                      onXMinus: () => jogN.jogLinear('X', -1),
                      onYPlus:  () => jogN.jogLinear('Y', 1),
                      onYMinus: () => jogN.jogLinear('Y', -1),
                      onStop:   () => jogN.stopJog(),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                // Jauge axe A
                ArcGauge(
                  value: wPos[3],
                  minValue: -90,
                  maxValue: 90,
                  color: AppColors.axisA,
                  axisLabel: 'A',
                  size: 110,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Jauge axe C (pleine largeur)
            Center(
              child: RingGauge(
                value: wPos[4] % 360,
                color: AppColors.axisC,
                axisLabel: 'C',
                size: 120,
              ),
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.surfaceBorder),
            const SizedBox(height: 16),

            // ── QUICK ACTIONS ─────────────────────────────────────────
            const _PanelSectionHeader(title: 'QUICK ACTIONS'),
            const SizedBox(height: 8),

            Consumer(builder: (ctx, r, _) {
              final repo = r.read(machineRepositoryProvider);
              final audio = r.read(audioServiceProvider);
              return Row(
                children: [
                  _QAction(label: 'CYCLE\nSTART', color: AppColors.success, icon: Icons.play_arrow_rounded,
                    onTap: () { repo.resume(); audio.play(SoundEffect.click); HapticFeedback.mediumImpact(); }),
                  const SizedBox(width: 6),
                  _QAction(label: 'FEED\nHOLD', color: AppColors.warning, icon: Icons.pause_rounded,
                    onTap: () { repo.pause(); audio.play(SoundEffect.click); HapticFeedback.mediumImpact(); }),
                  const SizedBox(width: 6),
                  _QAction(label: 'E-STOP', color: AppColors.danger, icon: Icons.bolt_rounded,
                    onTap: () { repo.emergencyStop(); audio.play(SoundEffect.alarm); HapticFeedback.vibrate(); }),
                  const SizedBox(width: 6),
                  _QAction(label: 'JOG\nSTOP', color: AppColors.primary, icon: Icons.stop_rounded,
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
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      const Spacer(),
      if (trailing case final t?) t,
      const Icon(Icons.more_horiz, color: AppColors.textDisabled, size: 14),
    ]);
  }
}

/// Affichage DRO grand format — style écran LCD 7 segments
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
        ? '${value.toStringAsFixed(2)}°'
        : value.toStringAsFixed(3);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
          const SizedBox(width: 8),
          Expanded(
            child: Text(display,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono',
                    shadows: [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 12)])),
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
