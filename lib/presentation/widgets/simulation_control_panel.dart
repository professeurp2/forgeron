import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/ai_artifacts_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/simulation_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../domain/models/machine_state.dart';
import 'camera_view.dart';
import 'trunnion_visualizer.dart';
import 'viewer_scene.dart';

/// Barre de pilotage de simulation 3D compacte (utilisable sous le visualiseur
/// 3D du Dashboard Desktop et du panneau 3D Mobile Android).
class CompactSimulationBar extends ConsumerWidget {
  const CompactSimulationBar({super.key, this.dense = false});

  final bool dense;

  static const List<double> _speeds = [1, 5, 10, 25, 50];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final sim = ref.watch(simulationProvider);
    final ctrl = ref.read(simulationProvider.notifier);
    final hasToolpath =
        ref.watch(gcodeProvider.select((s) => s.toolpath.isNotEmpty));

    final isPlaying = sim.status == SimulationStatus.playing;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(
          top: BorderSide(color: fc.surfaceBorder),
          bottom: BorderSide(color: fc.surfaceBorder),
        ),
      ),
      child: Row(
        children: [
          // Bouton Play / Pause simulation
          InkWell(
            onTap: hasToolpath ? ctrl.togglePlayPause : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPlaying
                    ? fc.warning.withValues(alpha: 0.16)
                    : fc.primary.withValues(alpha: hasToolpath ? 0.16 : 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isPlaying
                      ? fc.warning
                      : (hasToolpath ? fc.primary : fc.surfaceBorder),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 14,
                    color: isPlaying
                        ? fc.warning
                        : (hasToolpath ? fc.primary : fc.textDisabled),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPlaying ? tr('PAUSE') : tr('SIMULER'),
                    style: TextStyle(
                      color: isPlaying
                          ? fc.warning
                          : (hasToolpath ? fc.primary : fc.textDisabled),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Reset
          Tooltip(
            message: tr('Réinitialiser la simulation et le brut'),
            child: InkWell(
              onTap: hasToolpath ? ctrl.reset : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.replay_rounded,
                  size: 15,
                  color: hasToolpath ? fc.textSecondary : fc.textDisabled,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Scrubber temporel
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: fc.primary,
                inactiveTrackColor: fc.surfaceBright,
                thumbColor: fc.primary,
              ),
              child: Slider(
                value: sim.progressPct.clamp(0.0, 100.0),
                min: 0.0,
                max: 100.0,
                onChanged: hasToolpath ? ctrl.seekPercent : null,
              ),
            ),
          ),
          Text(
            '${sim.progressPct.toStringAsFixed(0)}%',
            style: TextStyle(
              color: fc.textSecondary,
              fontSize: 9.5,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          // Sélecteur de vitesse
          PopupMenuButton<double>(
            tooltip: tr('Vitesse de simulation'),
            onSelected: ctrl.setSpeed,
            itemBuilder: (_) => [
              for (final s in _speeds)
                PopupMenuItem<double>(
                  value: s,
                  child: Text('×${s.toStringAsFixed(0)}'),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: fc.surfaceBright,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: fc.surfaceBorder),
              ),
              child: Text(
                '×${sim.speedMultiplier.toStringAsFixed(0)}',
                style: TextStyle(
                  color: fc.primary,
                  fontSize: 9.5,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fiche de résumé des paramètres de tâche (Style Acteris "Summary") avec
/// édition directe.
class ActerisJobSummaryCard extends ConsumerWidget {
  const ActerisJobSummaryCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final sim = ref.watch(simulationProvider);
    final artifacts = ref.watch(aiArtifactsProvider);

    final jobTitle = artifacts.gcode?.fileName ??
        artifacts.step?.fileName ??
        sim.jobName;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined,
                  size: 15, color: fc.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr('Summary · Paramètres de la tâche'),
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryFieldTile(
            fc: fc,
            label: tr('Nom du Job'),
            value: jobTitle,
            onEdit: () => _editFieldDialog(
              context,
              ref,
              title: tr('Nom du Job'),
              initial: sim.jobName,
              onSave: (val) => ref
                  .read(simulationProvider.notifier)
                  .configureJob(jobName: val.trim()),
            ),
          ),
          const SizedBox(height: 6),
          _SummaryFieldTile(
            fc: fc,
            label: tr('Taille de série (Batch Size)'),
            value: '${sim.batchSize}',
            onEdit: () => _editFieldDialog(
              context,
              ref,
              title: tr('Taille de série'),
              initial: '${sim.batchSize}',
              onSave: (val) {
                final n = int.tryParse(val.trim());
                if (n != null && n > 0) {
                  ref
                      .read(simulationProvider.notifier)
                      .configureJob(batchSize: n);
                }
              },
            ),
          ),
          const SizedBox(height: 6),
          _SummaryFieldTile(
            fc: fc,
            label: tr('Forme du brut (Part Shape)'),
            value: '${sim.stockShape.wire} (${sim.dimensionsLabel})',
            onEdit: () => _editStockDialog(context, ref, sim),
          ),
        ],
      ),
    );
  }

  Future<void> _editFieldDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final fc = context.fc;
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text(title, style: TextStyle(color: fc.textPrimary, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: fc.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Annuler'), style: TextStyle(color: fc.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('Valider')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res != null && res.trim().isNotEmpty) {
      onSave(res);
    }
  }

  Future<void> _editStockDialog(
    BuildContext context,
    WidgetRef ref,
    SimulationState sim,
  ) async {
    final fc = context.fc;
    StockShape shape = sim.stockShape;
    final xCtrl = TextEditingController(text: sim.stockDimensions[0].toStringAsFixed(0));
    final yCtrl = TextEditingController(text: sim.stockDimensions[1].toStringAsFixed(0));
    final zCtrl = TextEditingController(text: sim.stockDimensions[2].toStringAsFixed(0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: fc.surface,
          title: Text(tr('Configurer le brut pré-usinage'),
              style: TextStyle(color: fc.textPrimary, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<StockShape>(
                initialValue: shape,
                dropdownColor: fc.surfaceBright,
                style: TextStyle(color: fc.textPrimary, fontSize: 12.5),
                items: [
                  for (final s in StockShape.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) {
                  if (v != null) setModalState(() => shape = v);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: xCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: fc.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: shape == StockShape.cylinder ? 'Ø (mm)' : 'X (mm)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (shape == StockShape.cuboid) ...[
                    Expanded(
                      child: TextField(
                        controller: yCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: fc.textPrimary, fontSize: 12),
                        decoration: const InputDecoration(labelText: 'Y (mm)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: zCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: fc.textPrimary, fontSize: 12),
                      decoration: const InputDecoration(labelText: 'H / Z (mm)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Annuler'), style: TextStyle(color: fc.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: fc.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('Appliquer')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final dx = (double.tryParse(xCtrl.text) ?? 40.0).clamp(5.0, 300.0);
      final dy = shape == StockShape.cylinder
          ? dx
          : (double.tryParse(yCtrl.text) ?? dx).clamp(5.0, 300.0);
      final dz = (double.tryParse(zCtrl.text) ?? 25.0).clamp(2.0, 200.0);
      ref.read(simulationProvider.notifier).configureJob(
            stockShape: shape,
            stockDimensions: [dx, dy, dz],
          );
    }
    xCtrl.dispose();
    yCtrl.dispose();
    zCtrl.dispose();
  }
}

class _SummaryFieldTile extends StatelessWidget {
  const _SummaryFieldTile({
    required this.fc,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final ForgeronColorPalette fc;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: fc.textDisabled, fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fc.surface,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: fc.surfaceBorder),
              ),
              child: Text(
                tr('Edit'),
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panneau droit unifié de style **Acteris** :
/// - En-tête avec sélecteur segmenté `[ Simulateur | Caméra ]` + contrôles de scène
/// - Vue Jumeau Numérique 3D (Machine 5 axes + Brut + Pièce STEP + Parcours + ViewCube ISOMETRIC)
///   ou Flux Caméra ESP32-CAM en direct
/// - Barre de simulation temporelle interactive + Bouton `▶ Start Production`
/// - Panneau `Execution State` en bas (IDLE / SIMULATION / PRODUCTION, Job ID, Collisions).
class ActerisSimulatorCameraPanel extends ConsumerStatefulWidget {
  const ActerisSimulatorCameraPanel({
    super.key,
    this.onClose,
    this.onDetach,
  });

  final VoidCallback? onClose;
  final VoidCallback? onDetach;

  @override
  ConsumerState<ActerisSimulatorCameraPanel> createState() =>
      _ActerisSimulatorCameraPanelState();
}

class _ActerisSimulatorCameraPanelState
    extends ConsumerState<ActerisSimulatorCameraPanel> {
  String? _loadedGcodePath;
  bool _showMachineTwin = true;
  final bool _showPartOverlay = true;
  bool _showWorkpiece = true;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final sim = ref.watch(simulationProvider);
    final simCtrl = ref.read(simulationProvider.notifier);
    final artifacts = ref.watch(aiArtifactsProvider);
    final toolpath = ref.watch(renderToolpathProvider);
    final machineStatus =
        ref.watch(machineStateProvider.select((s) => s.valueOrNull?.status)) ??
            MachineStatus.offline;
    final realMPos =
        ref.watch(machineStateProvider.select((s) => s.valueOrNull?.mPos)) ??
            const [0.0, 0.0, 0.0, 0.0, 0.0];
    final realActiveLine = ref.watch(
            machineStateProvider.select((s) => s.valueOrNull?.activeLineIndex)) ??
        0;

    // Si l'agent IA a produit un fichier G-code dans aiArtifactsProvider, on le
    // charge automatiquement dans gcodeProvider pour le simulateur.
    final gcodePath = artifacts.gcode?.path;
    if (gcodePath != null && gcodePath != _loadedGcodePath) {
      _loadedGcodePath = gcodePath;
      Future.microtask(() async {
        try {
          final file = File(gcodePath);
          if (file.existsSync()) {
            final content = await file.readAsString();
            await ref.read(gcodeProvider.notifier).loadFile(content);
            simCtrl.analyzeCurrentProgram();
          }
        } catch (_) {}
      });
    }

    final isSimTab = sim.activeTab == ConsoleRightTab.simulator;
    final activeIdx = sim.isSimulating
        ? sim.currentToolpathIndex
        : ref.read(gcodeProvider).resolveToolpathIndex(realActiveLine);

    final execStateLabel = machineStatus == MachineStatus.run
        ? 'PRODUCTION (RUNNING)'
        : (sim.status == SimulationStatus.playing
            ? 'SIMULATING (×${sim.speedMultiplier.toStringAsFixed(0)})'
            : (sim.status == SimulationStatus.paused
                ? 'SIMULATION PAUSED (${sim.progressPct.toStringAsFixed(0)}%)'
                : (sim.status == SimulationStatus.completed
                    ? 'SIMULATION COMPLETED'
                    : 'IDLE')));

    return Container(
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        border: Border(left: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Barre supérieure : [ Simulateur | Caméra ] (Style Acteris) ──
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: fc.surface,
              border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                if (widget.onDetach != null)
                  Tooltip(
                    message: tr('Ouvrir dans une fenêtre détachée'),
                    child: IconButton(
                      icon: Icon(Icons.open_in_full_rounded,
                          size: 15, color: fc.textSecondary),
                      onPressed: widget.onDetach,
                    ),
                  ),
                const Spacer(),
                // Sélecteur segmenté Simulator | Camera
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: fc.surfaceBright,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fc.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TabPill(
                        fc: fc,
                        label: tr('Simulateur'),
                        icon: Icons.precision_manufacturing_outlined,
                        selected: isSimTab,
                        onTap: () =>
                            simCtrl.setActiveTab(ConsoleRightTab.simulator),
                      ),
                      const SizedBox(width: 4),
                      _TabPill(
                        fc: fc,
                        label: tr('Caméra'),
                        icon: Icons.videocam_outlined,
                        selected: !isSimTab,
                        onTap: () =>
                            simCtrl.setActiveTab(ConsoleRightTab.camera),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isSimTab) ...[
                  Tooltip(
                    message: tr('Afficher/Masquer la cellule machine 5 axes'),
                    child: InkWell(
                      onTap: () =>
                          setState(() => _showMachineTwin = !_showMachineTwin),
                      borderRadius: BorderRadius.circular(5),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.domain_verification_outlined,
                          size: 16,
                          color: _showMachineTwin ? fc.primary : fc.textDisabled,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: tr('Afficher/Masquer le brut voxelisé'),
                    child: InkWell(
                      onTap: () =>
                          setState(() => _showWorkpiece = !_showWorkpiece),
                      borderRadius: BorderRadius.circular(5),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.view_in_ar_rounded,
                          size: 16,
                          color: _showWorkpiece ? fc.secondary : fc.textDisabled,
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.onClose != null)
                  Tooltip(
                    message: tr('Masquer le panneau'),
                    child: IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: fc.textDisabled),
                      onPressed: widget.onClose,
                    ),
                  ),
              ],
            ),
          ),

          // ── 2. Zone Principale : Simulateur 3D ou Caméra Live ──────────────
          Expanded(
            child: isSimTab
                ? TrunnionVisualizer(
                    mPos: sim.isSimulating ? sim.simulatedMPos : realMPos,
                    toolpath: toolpath,
                    activeIndex: activeIdx,
                    partMesh: _showPartOverlay
                        ? artifacts.step?.preview?.mesh
                        : null,
                    scene: ViewerScene(
                      machine: _showMachineTwin,
                      toolpath: true,
                      part: _showPartOverlay &&
                          artifacts.step?.preview?.mesh != null,
                      workpiece: _showWorkpiece,
                      controls: true,
                    ),
                  )
                : const CameraView(),
          ),

          // ── 3. Barre de Simulation & Bouton "Start Production" ────────────
          const CompactSimulationBar(),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: fc.surface,
              border: Border(top: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Bouton Simuler (Action rapide)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: toolpath.isNotEmpty
                              ? simCtrl.togglePlayPause
                              : null,
                          icon: Icon(
                            sim.status == SimulationStatus.playing
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 17,
                          ),
                          label: Text(
                            sim.status == SimulationStatus.playing
                                ? tr('Mettre en pause')
                                : tr('Simuler le parcours'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: fc.primary,
                            side: BorderSide(color: fc.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton Start Production (Style Acteris)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: toolpath.isNotEmpty
                              ? () {
                                  simCtrl.pause();
                                  ref
                                      .read(streamingProvider.notifier)
                                      .startStream();
                                }
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            tr('Start Production'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fc.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Bloc d'état d'exécution (Style Acteris : Execution State, Job ID, Commands)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fc.surfaceBright,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: fc.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TelemetryLine(
                        fc: fc,
                        label: 'Execution State',
                        value: execStateLabel,
                        valueColor: sim.collisionCount > 0
                            ? fc.danger
                            : (sim.isSimulating ? fc.primary : fc.success),
                      ),
                      const SizedBox(height: 3),
                      _TelemetryLine(
                        fc: fc,
                        label: 'Current Job ID',
                        value: artifacts.gcode?.fileName ??
                            artifacts.step?.fileName ??
                            sim.jobName,
                      ),
                      const SizedBox(height: 3),
                      _TelemetryLine(
                        fc: fc,
                        label: 'Estimated Cycle Time',
                        value:
                            '${SimulationController.formatDuration(sim.elapsedSeconds)} / '
                            '${SimulationController.formatDuration(sim.estimatedTotalSeconds)} '
                            '(Cut: ${sim.totalCuttingMm.toStringAsFixed(0)} mm)',
                      ),
                      const SizedBox(height: 3),
                      _TelemetryLine(
                        fc: fc,
                        label: 'Safety & Collisions',
                        value: sim.collisionCount == 0
                            ? '0 collision · Course 5 axes OK'
                            : '${sim.collisionCount} alerte(s) détectée(s) !',
                        valueColor:
                            sim.collisionCount == 0 ? fc.success : fc.danger,
                      ),
                    ],
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

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.fc,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ForgeronColorPalette fc;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? fc.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : fc.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : fc.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryLine extends StatelessWidget {
  const _TelemetryLine({
    required this.fc,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final ForgeronColorPalette fc;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: fc.textDisabled,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? fc.textPrimary,
              fontSize: 10.5,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
