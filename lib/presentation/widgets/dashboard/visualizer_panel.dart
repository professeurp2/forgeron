import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/machine_status_color.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../domain/models/machine_state.dart';
import '../../widgets/trunnion_visualizer.dart';
import '../../tutorial/tutorial_keys.dart';

class VisualizerPanel extends ConsumerWidget {
  const VisualizerPanel({super.key});

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
          Text('VISUALISEUR 3D WEBGL', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)), 
          const Spacer(),
          if (progress > 0 && progress < 100) ...[
            Text('${progress.toStringAsFixed(1)}%', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
            SizedBox(width: 8),
            SizedBox(width: 60, child: LinearProgressIndicator(value: progress / 100, minHeight: 2, backgroundColor: AppColors.surfaceBorder, color: AppColors.primary)),
            SizedBox(width: 16),
          ],
          IconButton(
            icon: Icon(Icons.fullscreen, color: AppColors.textSecondary, size: 18),
            onPressed: () => ref.read(isVisualizerFullScreenProvider.notifier).state = true,
            tooltip: 'Plein Écran',
          ),
          SizedBox(width: 8),
          Text('VECTEURS', style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
          Switch(
            value: showVectors, 
            onChanged: (v) => ref.read(showVectorsProvider.notifier).state = v,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ]),
        SizedBox(height: 12),
        Expanded(child: GlassPanel(expand: true, padding: EdgeInsets.zero, child: Stack(children: [
          TrunnionVisualizer(
            mPos: mPos, 
            targetPos: state?.targetPos, 
            toolpath: gcodeState.toolpath,
            activeIndex: activeIndex,
            showVectors: showVectors,
          ), 
          if ((state?.singularityRisk ?? 0.0) > 0.5) 
            Positioned(top: 12, left: 12, right: 12, child: SingularityAlert(risk: state!.singularityRisk))
        ]))),
      ],
    );
  }
}

class FullScreenVisualizer extends ConsumerWidget {
  const FullScreenVisualizer({super.key});

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
            icon: Icon(Icons.fullscreen_exit, color: Colors.white, size: 40),
            onPressed: () => ref.read(isVisualizerFullScreenProvider.notifier).state = false,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 24,
          child: StatusBadge(
            label: state?.status.name.toUpperCase() ?? 'DÉCONNECTÉ',
            color: getMachineStatusColor(state?.status ?? MachineStatus.offline),
          ),
        ),
      ],
    );
  }
}

class SingularityAlert extends StatelessWidget {
  final double risk;
  const SingularityAlert({super.key, required this.risk});
  @override
  Widget build(BuildContext context) {
    final color = risk > 0.8 ? AppColors.error : AppColors.warning;
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.5))), child: Row(children: [Icon(Icons.warning, color: color, size: 14), SizedBox(width: 8), Text('SINGULARITÉ PROCHE', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)), const Spacer(), Text('${(risk * 100).toInt()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))]));
  }
}
