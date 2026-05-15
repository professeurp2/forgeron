import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import '../../core/widgets/split_view.dart';
import '../widgets/trunnion_visualizer.dart';
import '../../domain/models/macro.dart';
import '../../application/providers/gcode_provider.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_parser.dart';
import '../../data/mock/mock_machine_repository.dart';
import '../tutorial/tutorial_keys.dart';

final isWorkshopModeProvider = StateProvider<bool>((ref) => false);
final isVisualizerFullScreenProvider = StateProvider<bool>((ref) => false);
final simulationSpeedProvider = StateProvider<double>((ref) => 1.0);

class ToolpathNotifier extends StateNotifier<List<List<double>>> {
  ToolpathNotifier() : super([]);
  void addPoint(List<double> pos) {
    if (state.isEmpty || (state.last[0] - pos[0]).abs() > 0.5 || (state.last[1] - pos[1]).abs() > 0.5) {
      state = [...state, pos];
    }
  }
  void clear() => state = [];
}

final toolpathProvider = StateNotifierProvider<ToolpathNotifier, List<List<double>>>((ref) => ToolpathNotifier());

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWorkshop = ref.watch(isWorkshopModeProvider);
    final isFullScreen = ref.watch(isVisualizerFullScreenProvider);

    if (isFullScreen) return _FullScreenVisualizer();
    if (isWorkshop) return _WorkshopLayout();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ResizableSplitView(
        initialRatio: 0.22,
        left: Column(children: [
          _ConnectionHUD(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                _ActionGrid(),
                const SizedBox(height: 16),
                _MacrosPanel(),
                const SizedBox(height: 16),
                _TelemetryPanel(),
              ]),
            ),
          ),
        ]),
        right: ResizableSplitView(
          initialRatio: 0.7,
          left: Column(children: [
            Expanded(flex: 3, child: _VisualizerPanel()),
            const SizedBox(height: 16),
            SizedBox(height: 250, child: _GCodeConsolePanel()),
          ]),
          right: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: [
              _DROPanel(),
              const SizedBox(height: 16),
              _OverridesPanel(),
              const SizedBox(height: 16),
              _DynamicsPanel(),
              const SizedBox(height: 16),
              _ModalStatePanel(),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FullScreenVisualizer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final gcodeState = ref.watch(gcodeProvider);
    final showVectors = ref.watch(showVectorsProvider);

    return Stack(
      children: [
        TrunnionVisualizer(
          mPos: mPos,
          targetPos: state?.targetPos,
          toolpath: gcodeState.toolpath,
          activeIndex: state?.activeLineIndex ?? 0,
          showVectors: showVectors,
        ),
        Positioned(
          top: 24,
          right: 24,
          child: IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 40),
            onPressed: () => ref.read(isVisualizerFullScreenProvider.notifier).state = false,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 24,
          child: _StatusBadge(
            label: state?.status.name.toUpperCase() ?? 'DÉCONNECTÉ',
            color: _getStatusColor(state?.status ?? MachineStatus.offline),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(MachineStatus s) {
    switch (s) {
      case MachineStatus.idle: return AppColors.success;
      case MachineStatus.run: return AppColors.primary;
      case MachineStatus.hold: return AppColors.warning;
      case MachineStatus.alarm: return AppColors.error;
      default: return AppColors.textDisabled;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)])),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
      ]),
    );
  }
}

class _ConnectionHUD extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;
    final ip = ref.watch(espIpProvider);
    final isWorkshop = ref.watch(isWorkshopModeProvider);
    return GlassPanel(
      key: TutorialKeys.statusCockpit,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('LIEN SYSTÈME', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const Spacer(),
          IconButton(
            icon: Icon(isWorkshop ? Icons.fullscreen_exit : Icons.touch_app, size: 16, color: AppColors.primary), 
            onPressed: () => ref.read(isWorkshopModeProvider.notifier).state = !isWorkshop,
            tooltip: 'Mode Atelier / Cockpit',
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? AppColors.success : AppColors.error, boxShadow: [BoxShadow(color: isOnline ? AppColors.success : AppColors.error, blurRadius: 8)])),
          const SizedBox(width: 8),
          Text(isOnline ? 'ESP32 EN LIGNE' : 'HORS LIGNE', style: TextStyle(color: isOnline ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
        ]),
        const SizedBox(height: 8),
        Text(ip, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono')),
      ]),
    );
  }
}

class _ActionGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(machineRepositoryProvider);
    final speed = ref.watch(simulationSpeedProvider);
    final isSim = ref.watch(isSimulationModeProvider);

    return Column(
      key: TutorialKeys.actionButtons,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ACTIONS MACHINE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
          children: [
            _actionBtn(Icons.play_arrow, 'REPRENDRE', AppColors.success, () => repo.resume()),
            _actionBtn(Icons.pause, 'PAUSE', AppColors.warning, () => repo.pause()),
            _actionBtn(Icons.stop, 'ARRÊT', AppColors.danger, () => repo.emergencyStop()),
            _actionBtn(Icons.refresh, 'RESET', AppColors.textDisabled, () {
              repo.sendRaw('\x18'); // Soft reset
              Future.delayed(const Duration(milliseconds: 500), () => repo.sendRaw('\$X\n')); // Unlock alarm
            }),
            _actionBtn(Icons.home, 'ORIGINE TOUS', AppColors.axisZ, () {
              repo.sendRaw('\$X\n'); // Unlock alarm d'abord
              Future.delayed(const Duration(milliseconds: 300), () => repo.home([]));
            }),
            _actionBtn(Icons.gps_fixed, 'ALLER ZÉRO', AppColors.secondary, () => repo.sendGCode('G90 G0 X0 Y0 Z0')),
          ],
        ),
        if (isSim) ...[
          const SizedBox(height: 16),
          const Text('VITESSE SIMULATION / OVERRIDES', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          Container(
            key: TutorialKeys.overridesPanel,
            child: Row(children: [
            Expanded(
              child: Slider(
                value: speed,
                min: 0.1,
                max: 20.0,
                onChanged: (v) {
                  ref.read(simulationSpeedProvider.notifier).state = v;
                  if (repo is MockMachineRepository) {
                    repo.setSimulationSpeed(v);
                  }
                },
                activeColor: AppColors.primary,
              ),
            ),
            Text('${speed.toStringAsFixed(1)}x', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
          ]),
          ),
        ],
      ],
    );
  }
  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))), child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0))])))));
  }
}

class _ModalStatePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    return GlassPanel(title: 'ÉTAT MODAL', child: Column(children: [_modalRow('WCS ACTIF', state?.activeWCS ?? 'G54', AppColors.primary), const SizedBox(height: 8), _modalRow('OUTIL ACTIF', 'T${state?.activeToolNum ?? 0}', AppColors.secondary), const Divider(color: AppColors.surfaceBorder, height: 20), Row(children: [Expanded(child: _bufferIndicator('PLAN', state?.plannerBuffer ?? 15, 15)), const SizedBox(width: 8), Expanded(child: _bufferIndicator('RX', state?.rxBuffer ?? 128, 128))])]));
  }
  Widget _modalRow(String label, String value, Color color) => Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withOpacity(0.4))), child: Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')))]);
  Widget _bufferIndicator(String label, int value, int max) {
    final ratio = (value / max).clamp(0.0, 1.0);
    final color = ratio > 0.5 ? AppColors.success : (ratio > 0.2 ? AppColors.warning : AppColors.error);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)), const Spacer(), Text('$value/$max', style: TextStyle(color: color, fontSize: 9, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold))]), const SizedBox(height: 4), LinearProgressIndicator(value: ratio, minHeight: 3, backgroundColor: AppColors.surfaceBorder, color: color, borderRadius: BorderRadius.circular(2))]);
  }
}

class _TelemetryPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    return GlassPanel(title: 'TÉLÉMÉTRIE', titleTrailing: const Icon(Icons.waves, color: AppColors.primary, size: 14), child: Column(children: [_telemetryRow('STATUT MACHINE', state?.status.name.toUpperCase() ?? 'HORS LIGNE', '', AppColors.textPrimary), _telemetryRow('TEMP CORE', state?.coreTemp.toStringAsFixed(1) ?? '--', '°C', AppColors.textPrimary), _telemetryRow('RTCP (G43.4)', (state?.isRtcpActive ?? false) ? 'ACTIF' : 'INACTIF', '', AppColors.success)]));
  }
  Widget _telemetryRow(String label, String value, String unit, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(unit, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

final showVectorsProvider = StateProvider<bool>((ref) => false);

class _VisualizerPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final gcodeState = ref.watch(gcodeProvider);
    final showVectors = ref.watch(showVectorsProvider);
    final activeIndex = state?.activeLineIndex ?? 0;
    final progress = state?.sdPercent ?? 0.0;

    return Column(
      key: TutorialKeys.trunnionViz,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('VISUALISEUR 3D WEBGL', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)), 
          const Spacer(),
          if (progress > 0 && progress < 100) ...[
            Text('${progress.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: LinearProgressIndicator(value: progress / 100, minHeight: 2, backgroundColor: AppColors.surfaceBorder, color: AppColors.primary)),
            const SizedBox(width: 16),
          ],
          IconButton(
            icon: const Icon(Icons.fullscreen, color: AppColors.textSecondary, size: 18),
            onPressed: () => ref.read(isVisualizerFullScreenProvider.notifier).state = true,
            tooltip: 'Plein Écran',
          ),
          const SizedBox(width: 8),
          const Text('VECTEURS', style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
          Switch(
            value: showVectors, 
            onChanged: (v) => ref.read(showVectorsProvider.notifier).state = v,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(child: GlassPanel(expand: true, padding: EdgeInsets.zero, child: Stack(children: [
          TrunnionVisualizer(
            mPos: mPos, 
            targetPos: state?.targetPos, 
            toolpath: gcodeState.toolpath,
            activeIndex: activeIndex,
            showVectors: showVectors,
          ), 
          if ((state?.singularityRisk ?? 0.0) > 0.5) 
            Positioned(top: 12, left: 12, right: 12, child: _SingularityAlert(risk: state!.singularityRisk))
        ]))),
      ],
    );
  }
}

class _SingularityAlert extends StatelessWidget {
  final double risk;
  const _SingularityAlert({required this.risk});
  @override
  Widget build(BuildContext context) {
    final color = risk > 0.8 ? AppColors.error : AppColors.warning;
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))), child: Row(children: [Icon(Icons.warning, color: color, size: 14), const SizedBox(width: 8), Text('SINGULARITÉ PROCHE', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)), const Spacer(), Text('${(risk * 100).toInt()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))]));
  }
}

class _DROPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    return Column(
      key: TutorialKeys.droPanel,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LECTURE DIGITALE (DRO)', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (int i = 0; i < 3; i++) _coordCard(['X', 'Y', 'Z'][i], wPos[i], [AppColors.axisX, AppColors.axisY, AppColors.axisZ][i]),
        Row(children: [
          Expanded(child: _coordCard('A', wPos[3], AppColors.axisA, small: true)),
          const SizedBox(width: 8),
          Expanded(child: _coordCard('C', wPos[4], AppColors.axisC, small: true))
        ])
      ],
    );
  }
  Widget _coordCard(String a, double v, Color c, {bool small = false}) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(small ? 8 : 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: c, width: 3)),
        ),
        child: Row(
          children: [
            Text(a, style: TextStyle(color: c, fontSize: small ? 12 : 16, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  v.toStringAsFixed(3),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: small ? 18 : 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _OverridesPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final ov = state?.overrides ?? [100, 100, 100];
    return GlassPanel(title: 'CORRECTIONS (OVERRIDES)', child: Column(children: [_ovRow('AVANCE (F)', ov[0], AppColors.primary), _ovRow('RAPIDE', ov[1], AppColors.axisZ), _ovRow('BROCHE (S)', ov[2], AppColors.secondary)]));
  }
  Widget _ovRow(String l, int v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(l, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            FittedBox(
              child: Text('$v%', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
            ),
          ],
        ),
      );
}

class _DynamicsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    return GlassPanel(
      title: 'DYNAMIQUE',
      child: Column(
        children: [
          _dynRow('AVANCE RÉELLE', 'F${state?.feedrate.toInt() ?? 0}', AppColors.textPrimary),
          _dynRow('VITESSE BROCHE', '${state?.spindleSpeed.toInt() ?? 0} RPM', AppColors.secondary),
        ],
      ),
    );
  }

  Widget _dynRow(String l, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(l, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
              ),
            ),
          ],
        ),
      );
}

class _WorkshopLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final gcodeState = ref.watch(gcodeProvider);
    final repo = ref.read(machineRepositoryProvider);
    final showVectors = ref.watch(showVectorsProvider);
    final progress = state?.sdPercent ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // TOP BAR COCKPIT
            _CockpitHeader(state: state, ref: ref),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT COLUMN: GIANT DRO & OVERRIDES
                  SizedBox(
                    width: 400,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _GiantIndustrialDRO(wPos: wPos),
                        ),
                        const SizedBox(height: 12),
                        _WorkshopGauges(state: state),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // CENTER: 3D VISUALIZER (FULL SCREEN FEEL)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceBorder, width: 2),
                      ),
                      child: Stack(
                        children: [
                          TrunnionVisualizer(
                            mPos: mPos,
                            targetPos: state?.targetPos,
                            toolpath: gcodeState.toolpath,
                            activeIndex: state?.activeLineIndex ?? 0,
                            showVectors: showVectors,
                          ),
                          if (progress > 0 && progress < 100)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                minHeight: 4,
                                backgroundColor: Colors.transparent,
                                color: AppColors.primary,
                              ),
                            ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: _WorkshopQuickActions(repo: repo),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (progress > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                    child: Text('${progress.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 24),
                                  onPressed: () => ref.read(isVisualizerFullScreenProvider.notifier).state = true,
                                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                          if ((state?.singularityRisk ?? 0.0) > 0.6)
                            Positioned(
                              top: 60,
                              left: 20,
                              right: 20,
                              child: _SingularityAlert(risk: state!.singularityRisk),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // RIGHT COLUMN: LARGE BUTTONS
                  SizedBox(
                    width: 220,
                    child: _IndustrialControlPanel(repo: repo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CockpitHeader extends StatelessWidget {
  final MachineState? state;
  final WidgetRef ref;
  const _CockpitHeader({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(state?.status ?? MachineStatus.offline);
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_input_component, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COCKPIT FORGERON',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              Text('SYSTÈME PRÊT // V1.0.0',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono')),
            ],
          ),
          const Spacer(),
          _CockpitStatusBadge(
              label: state?.status.name.toUpperCase() ?? 'DÉCONNECTÉ',
              color: statusColor),
          const SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
            onPressed: () => ref.read(isWorkshopModeProvider.notifier).state = false,
            tooltip: 'Quitter le mode cockpit',
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(MachineStatus s) {
    switch (s) {
      case MachineStatus.idle: return AppColors.success;
      case MachineStatus.run: return AppColors.primary;
      case MachineStatus.hold: return AppColors.warning;
      case MachineStatus.alarm: return AppColors.error;
      default: return AppColors.textDisabled;
    }
  }
}

class _GiantIndustrialDRO extends StatelessWidget {
  final List<double> wPos;
  const _GiantIndustrialDRO({required this.wPos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          _giantAxis('X', wPos[0], AppColors.axisX),
          const Divider(color: AppColors.surfaceBorder, height: 32),
          _giantAxis('Y', wPos[1], AppColors.axisY),
          const Divider(color: AppColors.surfaceBorder, height: 32),
          _giantAxis('Z', wPos[2], AppColors.axisZ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _miniAxis('A', wPos[3], AppColors.axisA)),
              const SizedBox(width: 12),
              Expanded(child: _miniAxis('C', wPos[4], AppColors.axisC)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _giantAxis(String name, double val, Color color) {
    return Row(
      children: [
        Text(name, style: TextStyle(color: color, fontSize: 42, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(
          val.toStringAsFixed(3),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              fontFamily: 'JetBrains Mono'),
        ),
      ],
    );
  }

  Widget _miniAxis(String name, double val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(val.toStringAsFixed(2),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}

class _WorkshopGauges extends StatelessWidget {
  final MachineState? state;
  const _WorkshopGauges({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          _gaugeRow('AVANCE (F)', state?.feedrate ?? 0, 5000, AppColors.primary, 'mm/min'),
          const SizedBox(height: 12),
          _gaugeRow('BROCHE (S)', state?.spindleSpeed ?? 0, 24000, AppColors.secondary, 'RPM'),
        ],
      ),
    );
  }

  Widget _gaugeRow(String label, double val, double max, Color color, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11, fontWeight: FontWeight.bold)),
            Text('${val.toInt()} $unit', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (val / max).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.black,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _IndustrialControlPanel extends ConsumerWidget {
  final dynamic repo;
  const _IndustrialControlPanel({required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcodeState = ref.watch(gcodeProvider);
    final isSimulation = ref.watch(isSimulationModeProvider);
    final speed = ref.watch(simulationSpeedProvider);

    return Column(
      children: [
        _hmiButton(
          Icons.play_arrow,
          'DÉPART CYCLE',
          AppColors.success,
          () {
            if (isSimulation && gcodeState.allLines.isNotEmpty) {
              repo.sendGCodeBatch(gcodeState.allLines);
              repo.resume();
            } else {
              repo.resume();
            }
          },
          isLarge: true,
        ),
        const SizedBox(height: 12),
        _hmiButton(Icons.pause, 'ARRÊT AVANCE', AppColors.warning, () => repo.pause(), isLarge: true),
        const SizedBox(height: 12),
        _hmiButton(Icons.stop, 'ABANDON / RESET', AppColors.danger, () => repo.reset(), isLarge: true),
        if (isSimulation) ...[
          const SizedBox(height: 24),
          const Text('VITESSE SIM', style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.bold)),
          Slider(
            value: speed,
            min: 0.1,
            max: 20.0,
            onChanged: (v) {
              ref.read(simulationSpeedProvider.notifier).state = v;
              if (repo is MockMachineRepository) {
                repo.setSimulationSpeed(v);
              }
            },
            activeColor: AppColors.primary,
          ),
          Text('${speed.toStringAsFixed(1)}x', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
        ],
        const Spacer(),
        _hmiButton(Icons.home, 'ORIGINES', AppColors.axisZ, () => repo.home([]), isLarge: false),
        const SizedBox(height: 12),
        _hmiButton(Icons.gps_fixed, 'GOTO ZÉRO', AppColors.secondary, () => repo.sendGCode('G0 X0 Y0 Z0'), isLarge: false),
      ],
    );
  }

  Widget _hmiButton(IconData icon, String label, Color color, VoidCallback onTap, {required bool isLarge}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: isLarge ? 110 : 70,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: isLarge ? 42 : 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: isLarge ? 13 : 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkshopQuickActions extends StatelessWidget {
  final dynamic repo;
  const _WorkshopQuickActions({required this.repo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _miniFloatingBtn(Icons.refresh, () => repo.reset(), 'Réinitialiser'),
        const SizedBox(width: 8),
        _miniFloatingBtn(Icons.center_focus_strong, () => {}, 'Palpage'),
      ],
    );
  }

  Widget _miniFloatingBtn(IconData icon, VoidCallback onTap, String tooltip) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }
}

class _CockpitStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CockpitStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color, blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}


class _MacrosPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      key: TutorialKeys.macrosPanel,
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
      const Text('MACROS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      for (final m in defaultMacros)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              final repo = ref.read(machineRepositoryProvider);
              if (m.gcode == 'MOCK_DEMO') {
                // Demo spécial: envoie une séquence de test
                repo.sendGCode('G90 G0 X10 Y10 Z-5');
                return;
              }
              // Envoyer les lignes une par une avec délai
              final lines = m.gcode.split('\n').where((l) => l.trim().isNotEmpty).toList();
              for (int i = 0; i < lines.length; i++) {
                Future.delayed(Duration(milliseconds: i * 200), () {
                  repo.sendGCode(lines[i].trim());
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: m.color.withOpacity(0.1),
                border: Border.all(color: m.color.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Icon(m.icon, color: m.color, size: 16),
                const SizedBox(width: 12),
                Text(m.name, style: TextStyle(color: m.color, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _GCodeConsolePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcodeState = ref.watch(gcodeProvider);
    final scrollController = ref.watch(gcodeScrollControllerProvider);
    
    return GlassPanel(
      key: TutorialKeys.gcodeConsole,
      title: 'FLUX G-CODE INDUSTRIEL',
      expand: true,
      titleTrailing: IconButton(
        icon: const Icon(Icons.file_open, color: AppColors.primary, size: 14),
        onPressed: () => _pickFile(ref),
        tooltip: 'Charger un fichier G-Code',
      ),
      child: ListView.builder(
        controller: scrollController,
        itemCount: gcodeState.allLines.length,
        itemExtent: 24, // Virtualisation haute performance
        itemBuilder: (ctx, i) {
          final isCurrent = i == gcodeState.currentLineIndex;
          return Container(
            color: isCurrent ? AppColors.primary.withOpacity(0.1) : null,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              SizedBox(width: 40, child: Text('${i + 1}', style: TextStyle(color: isCurrent ? AppColors.primary : AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono'))),
              const SizedBox(width: 8),
              Expanded(child: Text(gcodeState.allLines[i], style: TextStyle(color: isCurrent ? Colors.white : AppColors.textDisabled, fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontFamily: 'JetBrains Mono'))),
              if (isCurrent) const Icon(Icons.chevron_left, color: AppColors.primary, size: 14),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _pickFile(WidgetRef ref) async {
    final content = await FilePickerService.pickGCodeContent();
    if (content != null) {
      // Chargement optimisé via Isolate
      await ref.read(gcodeProvider.notifier).loadFile(content);
    }
  }
}
