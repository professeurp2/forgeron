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
import '../../application/providers/streaming_provider.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/gauge_widgets.dart';
import '../widgets/dashboard/workshop_layout.dart';
import '../widgets/trunnion_visualizer.dart';
import 'cnc_panel_screen.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_highlighter.dart';

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
                Consumer(builder: (ctx, ref, _) {
                  final scrollController = ref.watch(gcodeScrollControllerProvider);
                  final currentIndex = state?.activeLineIndex ?? 0;

                  ref.listen(machineStateProvider, (previous, next) {
                    final oldIndex = previous?.valueOrNull?.activeLineIndex ?? 0;
                    final newIndex = next.valueOrNull?.activeLineIndex ?? 0;
                    if (newIndex != oldIndex && scrollController.hasClients) {
                      final targetOffset = (newIndex * 22.0) - 40;
                      scrollController.animateTo(
                        targetOffset > 0 ? targetOffset : 0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return Expanded(
                    child: _DashCard(
                      title: 'PROGRAMME',
                      action: IconButton(
                        icon: Icon(Icons.file_open_rounded, color: context.fc.primary, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final content = await FilePickerService.pickGCodeContent();
                          if (content != null) {
                            await ref.read(gcodeProvider.notifier).loadFile(content);
                          }
                        },
                        tooltip: 'Charger un fichier G-Code (.nc, .gcode)',
                      ),
                      child: gcodeState.allLines.isEmpty
                          ? Text('Aucun programme chargé',
                              style: TextStyle(color: context.fc.textDisabled, fontSize: 10))
                          : SizedBox(
                              height: 98,
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: gcodeState.allLines.length,
                                itemExtent: 22,
                                itemBuilder: (ctx, i) {
                                  final isCurrent = i == currentIndex;
                                  return Container(
                                    decoration: isCurrent
                                        ? BoxDecoration(
                                            color: context.fc.primary.withValues(alpha: 0.08),
                                            border: Border(
                                              left: BorderSide(color: context.fc.primary, width: 3),
                                            ),
                                          )
                                        : null,
                                    padding: EdgeInsets.only(
                                      left: isCurrent ? 5.0 : 8.0,
                                      right: 8.0,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              color: isCurrent ? context.fc.primary : context.fc.textDisabled,
                                              fontSize: 9,
                                              fontFamily: 'JetBrains Mono',
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: RichText(
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'JetBrains Mono',
                                              ),
                                              children: GCodeHighlighter.buildSpans(gcodeState.allLines[i], isCurrent),
                                            ),
                                          ),
                                        ),
                                        if (isCurrent)
                                          Icon(
                                            Icons.chevron_left,
                                            color: context.fc.primary,
                                            size: 12,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  );
                }),
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
  final Widget? action;
  const _DashCard({required this.title, required this.child, this.action});

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
            if (action != null)
              action!
            else
              Icon(Icons.more_horiz, color: context.fc.textDisabled, size: 14),
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
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
    final progress = state?.sdPercent ?? 0.0;
    final feedOverride = state?.overrides.isNotEmpty == true ? state!.overrides[0] : 100;
    final spindleOverride = (state?.overrides.length ?? 0) > 2 ? state!.overrides[2] : 100;

    return Container(
      color: context.fc.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── POSITION DRO ──────────────────────────────────────────
            _PanelSectionHeader(title: 'POSITION DRO', trailing: Text(
              'W-value − Target',
              style: TextStyle(color: context.fc.textDisabled, fontSize: 9),
            )),
            const SizedBox(height: 8),
            _DroBig(label: 'X', value: wPos[0], color: context.fc.axisX),
            _DroBig(label: 'Y', value: wPos[1], color: context.fc.axisY),
            _DroBig(label: 'Z', value: wPos[2], color: context.fc.axisZ),
            _DroBig(label: 'A', value: wPos[3], color: context.fc.axisA, isRotary: true),
            _DroBig(label: 'C', value: wPos[4], color: context.fc.axisC, isRotary: true),

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
            const SizedBox(height: 8),
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

            const SizedBox(height: 16),

            // Section AXES ROTATIFS (A / C)
            Text('AXES ROTATIFS',
                style: TextStyle(color: context.fc.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Axe A
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ArcGauge(
                      value: wPos[3],
                      minValue: -90,
                      maxValue: 90,
                      color: context.fc.axisA,
                      axisLabel: 'A',
                      size: 110,
                    ),
                    const SizedBox(height: 6),
                    Consumer(builder: (ctx, r, _) {
                      final multiplier = r.watch(cncJogMultiplierProvider);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotaryJogButton(
                            isPlus: false,
                            axisLabel: 'A',
                            color: context.fc.axisA,
                            onTap: () => r.read(machineRepositoryProvider).jog('A', -multiplier.toDouble(), 3600),
                          ),
                          const SizedBox(width: 4),
                          RotaryJogButton(
                            isPlus: true,
                            axisLabel: 'A',
                            color: context.fc.axisA,
                            onTap: () => r.read(machineRepositoryProvider).jog('A', multiplier.toDouble(), 3600),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                // Axe C
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RingGauge(
                      value: wPos[4] % 360,
                      color: context.fc.axisC,
                      axisLabel: 'C',
                      size: 90,
                    ),
                    const SizedBox(height: 6),
                    Consumer(builder: (ctx, r, _) {
                      final multiplier = r.watch(cncJogMultiplierProvider);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotaryJogButton(
                            isPlus: false,
                            axisLabel: 'C',
                            color: context.fc.axisC,
                            onTap: () => r.read(machineRepositoryProvider).jog('C', -multiplier.toDouble(), 3600),
                          ),
                          const SizedBox(width: 4),
                          RotaryJogButton(
                            isPlus: true,
                            axisLabel: 'C',
                            color: context.fc.axisC,
                            onTap: () => r.read(machineRepositoryProvider).jog('C', multiplier.toDouble(), 3600),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 8),

            // Section PROGRESSION & AVANCES
            const _PanelSectionHeader(title: 'PROGRESSION & AVANCES'),
            const SizedBox(height: 8),
            
            // Progression (Historique)
            Row(
              children: [
                Text('HISTORIQUE',
                    style: TextStyle(color: context.fc.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${progress.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: context.fc.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: context.fc.surfaceBorder,
                color: context.fc.primary,
              ),
            ),
            const SizedBox(height: 8),

            // Avances (Feed & Spindle Override)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('F-OVERRIDE', style: TextStyle(color: context.fc.textDisabled, fontSize: 8, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('$feedOverride%', style: TextStyle(color: context.fc.primary, fontSize: 8, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (feedOverride / 200.0).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: context.fc.surfaceBorder,
                          color: context.fc.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('S-OVERRIDE', style: TextStyle(color: context.fc.textDisabled, fontSize: 8, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('$spindleOverride%', style: TextStyle(color: context.fc.secondary, fontSize: 8, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (spindleOverride / 200.0).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: context.fc.surfaceBorder,
                          color: context.fc.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  _QAction(
                    label: 'CYCLE\nSTART',
                    color: context.fc.success,
                    icon: Icons.play_arrow_rounded,
                    onTap: () async {
                      final latestState = r.read(machineStateProvider).valueOrNull;
                      if (latestState?.status == MachineStatus.hold) {
                        repo.resume();
                      } else {
                        final messenger = ScaffoldMessenger.of(ctx);
                        final errorColor = context.fc.error;
                        final result = await r.read(streamingProvider.notifier).startStream();
                        if (!result.isValid) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Erreur Lookahead : ${result.errorMessage} (ligne ${result.errorLine})'),
                              backgroundColor: errorColor,
                            ),
                          );
                        }
                      }
                      audio.play(SoundEffect.click);
                      HapticFeedback.mediumImpact();
                    },
                  ),
                  const SizedBox(width: 6),
                  _QAction(
                    label: 'FEED\nHOLD',
                    color: context.fc.warning,
                    icon: Icons.pause_rounded,
                    onTap: () {
                      repo.pause();
                      audio.play(SoundEffect.click);
                      HapticFeedback.mediumImpact();
                    },
                  ),
                  const SizedBox(width: 6),
                  _QAction(
                    label: 'E-STOP',
                    color: context.fc.danger,
                    icon: Icons.bolt_rounded,
                    onTap: () {
                      r.read(streamingProvider.notifier).stopStream();
                      audio.play(SoundEffect.alarm);
                      HapticFeedback.vibrate();
                    },
                  ),
                  const SizedBox(width: 6),
                  _QAction(
                    label: 'JOG\nSTOP',
                    color: context.fc.primary,
                    icon: Icons.stop_rounded,
                    onTap: () {
                      r.read(secureJogProvider.notifier).stopJog();
                      audio.play(SoundEffect.alert);
                      HapticFeedback.heavyImpact();
                    },
                  ),
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
        color: context.fc.background,
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
