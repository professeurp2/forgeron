import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/forge_kinetic_fx.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/services/audio_service.dart';
import '../../application/providers/streaming_provider.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import '../widgets/travel_gauge.dart';
import '../widgets/override_panel.dart';
import '../widgets/camera_view.dart';
import '../widgets/tool_change_banner.dart';
import '../tutorial/tutorial_keys.dart';
import '../widgets/visualizer_mode_toggle.dart';
import '../../application/providers/camera_provider.dart';
import '../../application/providers/machine_params_provider.dart';
import '../widgets/trunnion_visualizer.dart';
import '../widgets/simulation_control_panel.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_highlighter.dart';
import '../widgets/gcode_editor_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../application/providers/ai_artifacts_provider.dart';

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
    // Le mode atelier est intercepte plus haut, par le scaffold : le pupitre
    // remplace toute l'application, barre laterale comprise.
    final isFullScreen = ref.watch(isVisualizerFullScreenProvider);

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
          Expanded(flex: 5, child: _CenterZone()),

          // ── Séparateur ──
          Container(width: 1, color: context.fc.surfaceBorder),

          // ── Panel droit : DRO + JOG + Quick Actions ──
          SizedBox(width: 320, child: _RightPanel()),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ZONE CENTRALE
// ═════════════════════════════════════════════════════════════════════════════

class _CenterZone extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CenterZone> createState() => _CenterZoneState();
}

class _CenterZoneState extends ConsumerState<_CenterZone> {
  DateTime? _lastScrollTime;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = ref.watch(renderMPosProvider);
    final gcodeState = ref.watch(gcodeProvider);
    final spindle = state?.spindleSpeed.toStringAsFixed(0) ?? '0';
    final isOnline =
        state?.status != null && state?.status != MachineStatus.offline;
    // L'ESP32-CAM n'existait que sur mobile : au poste, on ne pouvait pas
    // regarder la coupe autrement qu'en se penchant sur la machine. Sans
    // caméra configurée, le mode retombe de lui-même sur le simulateur.
    final cameraEnabled = ref.watch(cameraEnabledProvider);
    final isCamera =
        ref.watch(effectiveVisualizerModeProvider) == VisualizerMode.camera;

    return TacticalGridBackground(
      child: Column(
        children: [
          // ── Header machine compact ──────────────────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: context.fc.cardGradient,
              border: Border(
                bottom: BorderSide(color: context.fc.surfaceBorder),
              ),
            ),
            child: Row(
              children: [
                Text(
                  tr('FORGERON'),
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    color: context.fc.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
              const SizedBox(width: 12),
              // Indicateur statut
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? context.fc.success
                      : context.fc.textDisabled,
                  boxShadow: isOnline
                      ? [BoxShadow(color: context.fc.success, blurRadius: 8)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Barre d'avance
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LaserShimmerBar(
                    value:
                        ((state?.overrides.isNotEmpty == true
                                    ? state!.overrides[0]
                                    : 100) /
                                200)
                            .clamp(0.0, 1.0),
                    height: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sélecteur CAM / 3D. Dans la barre d'outils et non posé sur
              // l'image : la caméra affiche ses propres badges dans le coin
              // haut-gauche, les deux se seraient superposés.
              if (cameraEnabled) ...[
                const VisualizerModeToggle(),
                const SizedBox(width: 12),
              ],
              Text(
                tr('{} RPM', [spindle]),
                style: TextStyle(
                  color: context.fc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(state: state),
            ],
          ),
        ),

        // Quel outil monter, pendant une pause de changement. Le bandeau ne
        // s'affiche que pendant le maintien programme (M0) ; à cet instant
        // c'est la seule information qui compte.
        const ToolChangeBanner(dense: true),

        // ── Visualisateur 3D ────────────────────────────────────────────
        Expanded(
          child: Container(
            // Cible du tutoriel : la clé vivait sur un panneau qui n'était
            // plus affiché nulle part, l'étape « jumeau numérique » pointait
            // donc le vide.
            key: TutorialKeys.trunnionViz,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            decoration: BoxDecoration(
              color: context.fc.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.fc.rimHighlight),
              boxShadow: [
                BoxShadow(
                  color: context.fc.isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  if (isCamera)
                    const CameraView()
                  else
                    // Le desktop ne passait que mPos : `toolpath` restant nul,
                    // le visualiseur sortait de _sendToolpath() sans rien
                    // tracer et l'écran n'a jamais montré le parcours, alors
                    // que mobile / palpage / panneau CNC l'alimentent tous.
                    TrunnionVisualizer(
                      mPos: mPos,
                      targetPos: state?.targetPos,
                      toolpath: ref.watch(renderToolpathProvider),
                      activeIndex: gcodeState
                          .resolveToolpathIndex(state?.activeLineIndex ?? 0),
                      showVectors: ref.watch(showVectorsProvider),
                      machineLimits: ref.watch(machineTravelProvider),
                      partMesh: ref.watch(aiArtifactsProvider).step?.preview?.mesh,
                    ),
                  // Sélecteur CAM / 3D quand une caméra est configurée ;
                  // sinon le simple libellé de la vue.
                  // Nom de la vue. Masqué en caméra : l'image porte déjà ses
                  // propres badges au même endroit.
                  if (!isCamera)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.fc.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: context.fc.surfaceBorder),
                        ),
                        child: Text(
                          tr('SIMULATEUR 3D'),
                          style: TextStyle(
                            color: context.fc.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  // Bouton fullscreen
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Consumer(
                      builder: (ctx, r, _) => IconButton(
                        icon: Icon(
                          Icons.fullscreen,
                          color: context.fc.textDisabled,
                          size: 20,
                        ),
                        onPressed: () =>
                            r
                                    .read(
                                      isVisualizerFullScreenProvider.notifier,
                                    )
                                    .state =
                                true,
                        tooltip: tr('Plein écran'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Barre de simulation interactive (Lecture / Pause / Vitesse) ──
        if (!isCamera)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const CompactSimulationBar(dense: true),
            ),
          ),

        // ── Bas : 3 cartes (Programme / Historique / Avances) ────────────
        SizedBox(
          height: 245,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Carte PROGRAMME (G-Code)
                Consumer(
                  builder: (ctx, ref, _) {
                    final scrollController = ref.watch(
                      gcodeScrollControllerProvider,
                    );
                    final currentIndex = state?.activeLineIndex ?? 0;

                    ref.listen(machineStateProvider, (previous, next) {
                      final oldIndex =
                          previous?.valueOrNull?.activeLineIndex ?? 0;
                      final newIndex = next.valueOrNull?.activeLineIndex ?? 0;
                      if (newIndex != oldIndex && scrollController.hasClients) {
                        final targetOffset = ((newIndex * 22.0) - 40).clamp(
                          0.0,
                          scrollController.position.maxScrollExtent,
                        );
                        final now = DateTime.now();
                        if (_lastScrollTime != null &&
                            now.difference(_lastScrollTime!).inMilliseconds <
                                150) {
                          scrollController.jumpTo(targetOffset);
                        } else {
                          _lastScrollTime = now;
                          scrollController.animateTo(
                            targetOffset,
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                          );
                        }
                      }
                    });

                    return Expanded(
                      child: BentoCascadeEntry(
                        index: 1,
                        child: _DashCard(
                          title: tr('PROGRAMME'),
                          expandChild: true,
                        action: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (gcodeState.allLines.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.edit_rounded,
                                  color: context.fc.secondary,
                                  size: 14,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const GCodeEditorDialog(),
                                  );
                                },
                                tooltip: tr('Éditer le G-Code'),
                              ),
                            if (gcodeState.allLines.isNotEmpty)
                              const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.file_open_rounded,
                                color: context.fc.primary,
                                size: 14,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final content =
                                    await FilePickerService.pickGCodeContent();
                                if (content != null) {
                                  await ref
                                      .read(gcodeProvider.notifier)
                                      .loadFile(content);
                                }
                              },
                              tooltip:
                                  tr('Charger un fichier G-Code (.nc, .gcode)'),
                            ),
                          ],
                        ),
                        child: gcodeState.allLines.isEmpty
                            ? Text(
                                tr('Aucun programme chargé'),
                                style: TextStyle(
                                  color: context.fc.textDisabled,
                                  fontSize: 10,
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: gcodeState.allLines.length,
                                itemExtent: 22,
                                itemBuilder: (ctx, i) {
                                  final isCurrent = i == currentIndex;
                                  return LaserActiveLineWrapper(
                                    isCurrent: isCurrent,
                                    color: context.fc.primary,
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
                                              color: isCurrent
                                                  ? context.fc.primary
                                                  : context.fc.textDisabled,
                                              fontSize: 9,
                                              fontFamily: 'JetBrains Mono',
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'JetBrains Mono',
                                              ),
                                              children:
                                                  GCodeHighlighter.buildSpans(
                                                    gcodeState.allLines[i],
                                                    isCurrent,
                                                  ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                  },
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  final bool expandChild;
  const _DashCard({
    required this.title,
    required this.child,
    this.action,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      decoration: BoxDecoration(
        gradient: fc.cardGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fc.rimHighlight),
        boxShadow: [
          BoxShadow(
            color: fc.isDark
                ? Colors.black.withValues(alpha: 0.34)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      // La carte remplit la hauteur qu'on lui donne et son contenu prend le
      // reste : une liste ou un état vide à hauteur fixe débordait de 34 px
      // sur tous les postes (balayage).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 12,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: fc.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: fc.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              if (action != null)
                action!
              else
                Icon(
                  Icons.more_horiz,
                  color: fc.textDisabled,
                  size: 14,
                ),
            ],
          ),
          const SizedBox(height: 8),
          expandChild ? Expanded(child: child) : child,
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
      MachineStatus.idle => context.fc.success,
      MachineStatus.run => context.fc.primary,
      MachineStatus.hold => context.fc.warning,
      MachineStatus.alarm => context.fc.error,
      _ => context.fc.textDisabled,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
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
    // Position MACHINE + cinematique : de quoi situer chaque axe dans sa
    // course. Le DRO desktop n'affichait que la position piece, qui ne dit
    // rien de la distance restante avant la butee.
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final kin = ref.watch(axisKinematicsProvider).valueOrNull;
    double? travel(int i) => (kin != null && i < kin.length && i < mPos.length)
        ? kin[i].travelFraction(mPos[i])
        : null;
    final progress = state?.sdPercent ?? 0.0;
    return Container(
      color: context.fc.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── POSITION DRO ──────────────────────────────────────────
            BentoCascadeEntry(
              index: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelSectionHeader(
                    title: tr('POSITION DRO'),
                    trailing: Text(
                      tr('W-value − Target'),
                      style: TextStyle(color: context.fc.textDisabled, fontSize: 9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DroBig(
                      label: 'X',
                      value: wPos[0],
                      color: context.fc.axisX,
                      travelFraction: travel(0)),
                  _DroBig(
                      label: 'Y',
                      value: wPos[1],
                      color: context.fc.axisY,
                      travelFraction: travel(1)),
                  _DroBig(
                      label: 'Z',
                      value: wPos[2],
                      color: context.fc.axisZ,
                      travelFraction: travel(2)),
                  _DroBig(
                    label: 'A',
                    value: wPos[3],
                    color: context.fc.axisA,
                    isRotary: true,
                    travelFraction: travel(3),
                  ),
                  _DroBig(
                    label: 'C',
                    value: wPos[4],
                    color: context.fc.axisC,
                    isRotary: true,
                    travelFraction: travel(4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 6),
            // Section PROGRESSION & AVANCES
            BentoCascadeEntry(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelSectionHeader(title: tr('PROGRESSION & AVANCES')),
                  const SizedBox(height: 6),

                  // Progression (Historique)
                  Row(
                    children: [
                      Text(
                        tr('HISTORIQUE'),
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          color: context.fc.textDisabled,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${progress.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: context.fc.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LaserShimmerBar(
                    value: (progress / 100).clamp(0.0, 1.0),
                    height: 6,
                  ),
                  const SizedBox(height: 8),

                  // Corrections d'avance et de rapides — REGLABLES.
                  // Le panneau n'affichait que deux barres en lecture seule : on
                  // voyait la correction sans pouvoir la toucher, alors que c'est le
                  // seul moyen de ralentir une passe en cours sans arreter le
                  // programme. Densite desktop : plat, compact, sans carte — le rail
                  // porte deja sa surface et son en-tete de section.
                  const OverridePanel(dense: true),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 6),

            // ── QUICK ACTIONS ─────────────────────────────────────────
            BentoCascadeEntry(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelSectionHeader(title: tr('QUICK ACTIONS')),
                  const SizedBox(height: 6),

                  Consumer(
                    builder: (ctx, r, _) {
                      final repo = r.read(machineRepositoryProvider);
                      final audio = r.read(audioServiceProvider);
                      return Row(
                        children: [
                          _QAction(
                            label: tr('CYCLE\nSTART'),
                            color: context.fc.success,
                            icon: Icons.play_arrow_rounded,
                            onTap: () async {
                              final latestState = r
                                  .read(machineStateProvider)
                                  .valueOrNull;
                              if (latestState?.status == MachineStatus.hold) {
                                repo.resume();
                                audio.play(SoundEffect.click);
                                HapticFeedback.mediumImpact();
                              } else {
                                final messenger = ScaffoldMessenger.of(ctx);
                                final errorColor = context.fc.error;
                                final result = await r
                                    .read(streamingProvider.notifier)
                                    .startStream();
                                if (!result.isValid) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        tr('Erreur Lookahead : {} (ligne {})', [result.errorMessage, result.errorLine]),
                                      ),
                                      backgroundColor: errorColor,
                                    ),
                                  );
                                  audio.play(SoundEffect.alert);
                                  HapticFeedback.heavyImpact();
                                } else {
                                  audio.play(SoundEffect.click);
                                  HapticFeedback.mediumImpact();
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          _QAction(
                            label: tr('FEED\nHOLD'),
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
                            label: tr('E-STOP'),
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
                            label: tr('JOG\nSTOP'),
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
                    },
                  ),
                ],
              ),
            ),
            // Respiration entre les actions rapides et le jog : les quatre
            // boutons touchaient l'en-tête de la section suivante.
            const SizedBox(height: 10),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 10),
            // ── JOG CONTROL ──────────────────────────────────────────
            BentoCascadeEntry(
              index: 3,
              child: JogControlPanel(wPos: wPos),
            ),

            const SizedBox(height: 8),
            Container(height: 1, color: context.fc.surfaceBorder),
            const SizedBox(height: 8),
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
    final fc = context.fc;
    // Le titre cède la place avant tout : à largeur naturelle, il débordait
    // de 12 px dans la colonne de droite sur TOUS les postes (balayage).
    return Row(
      children: [
        Container(
          width: 2,
          height: 12,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: fc.primary,
            borderRadius: BorderRadius.circular(1),
            boxShadow: [
              BoxShadow(color: fc.ambientGlow, blurRadius: 4),
            ],
          ),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: fc.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        if (trailing case final t?) t,
        Icon(Icons.more_horiz, color: fc.textDisabled, size: 14),
      ],
    );
  }
}

/// Affichage DRO grand format — style écran LCD 7 segments
class _DroBig extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isRotary;

  /// Position de l'axe dans sa course machine, de 0 a 1. `null` quand la
  /// course n'est pas connue : aucune jauge n'est alors dessinee.
  final double? travelFraction;

  const _DroBig({
    required this.label,
    required this.value,
    required this.color,
    this.isRotary = false,
    this.travelFraction,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final nearEdge = TravelGaugeFill.isNearEdge(travelFraction);
    return KineticAxisMovementDetector(
      value: value,
      color: color,
      builder: (context, glow) {
        return Container(
          margin: const EdgeInsets.only(bottom: 3),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.lerp(
                  fc.background,
                  color,
                  fc.isDark ? (0.06 + 0.12 * glow) : (0.03 + 0.08 * glow),
                )!,
                fc.background,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.22 + 0.50 * glow),
              width: 1.0,
            ),
            boxShadow: glow > 0.02
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.24 * glow),
                      blurRadius: 12 * glow,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Liseré latéral gauche lumineux selon le mouvement d'axe
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: glow > 0.05
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.65 * glow),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Jauge de course, identique au DRO mobile.
              TravelGaugeFill(fraction: travelFraction, color: color),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        shadows: glow > 0.05
                            ? [
                                Shadow(
                                  color: color.withValues(alpha: 0.6 * glow),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    // Meme lecture que sur mobile : la position dans la course, en clair.
                    if (travelFraction != null) ...[
                      const SizedBox(width: 7),
                      Text('${(travelFraction! * 100).round()}%',
                          style: TextStyle(
                              color: nearEdge
                                  ? fc.warning
                                  : fc.textDisabled,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      // Glisse d'un rapport de la carte au suivant au lieu de
                      // sauter : la cote reste lisible pendant un mouvement.
                      child: AnimatedNumberText(
                        value,
                        decimals: isRotary ? 2 : 3,
                        suffix: isRotary ? '°' : '',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'JetBrains Mono',
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.4 + 0.28 * glow),
                              blurRadius: 12 + 6 * glow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QAction extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _QAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

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
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
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
    final mPos = ref.watch(renderMPosProvider);
    final state = ref.watch(machineStateProvider).valueOrNull;
    final gcodeState = ref.watch(gcodeProvider);
    final isCamera =
        ref.watch(effectiveVisualizerModeProvider) == VisualizerMode.camera;
    return Stack(
      children: [
        // Le plein écran suit le mode choisi dans le panneau : passer en
        // caméra puis agrandir ne doit pas ramener le simulateur.
        if (isCamera)
          const CameraView()
        else
          Column(
            children: [
              Expanded(
                child: TrunnionVisualizer(
                  mPos: mPos,
                  targetPos: state?.targetPos,
                  toolpath: ref.watch(renderToolpathProvider),
                  activeIndex:
                      gcodeState.resolveToolpathIndex(state?.activeLineIndex ?? 0),
                  showVectors: ref.watch(showVectorsProvider),
                  machineLimits: ref.watch(machineTravelProvider),
                  partMesh: ref.watch(aiArtifactsProvider).step?.preview?.mesh,
                ),
              ),
              const CompactSimulationBar(),
            ],
          ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white70),
            onPressed: () =>
                ref.read(isVisualizerFullScreenProvider.notifier).state = false,
          ),
        ),
      ],
    );
  }
}
