import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../application/providers/machine_provider.dart';

class OverridesPanel extends ConsumerWidget {
  const OverridesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final ov = state?.overrides ?? [100, 100, 100];
    return GlassPanel(
      title: 'CORRECTIONS (OVERRIDES)', 
      child: Column(children: [
        _ovRow('AVANCE (F)', ov[0], AppColors.primary), 
        _ovRow('RAPIDE', ov[1], AppColors.axisZ), 
        _ovRow('BROCHE (S)', ov[2], AppColors.secondary)
      ])
    );
  }
  
  Widget _ovRow(String l, int v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(l, style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8),
            FittedBox(
              child: Text('$v%', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
            ),
          ],
        ),
      );
}

class DynamicsPanel extends ConsumerWidget {
  const DynamicsPanel({super.key});

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
            Expanded(child: Text(l, style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8),
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

class ModalStatePanel extends ConsumerWidget {
  const ModalStatePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    return GlassPanel(
      title: 'ÉTAT MODAL', 
      child: Column(children: [
        _modalRow('WCS ACTIF', state?.activeWCS ?? 'G54', AppColors.primary), 
        SizedBox(height: 8), 
        _modalRow('OUTIL ACTIF', 'T${state?.activeToolNum ?? 0}', AppColors.secondary), 
        Divider(color: AppColors.surfaceBorder, height: 20), 
        Row(children: [
          Expanded(child: _bufferIndicator('PLAN', state?.plannerBuffer ?? 15, 15)), 
          SizedBox(width: 8), 
          Expanded(child: _bufferIndicator('RX', state?.rxBuffer ?? 128, 128))
        ])
      ])
    );
  }
  
  Widget _modalRow(String label, String value, Color color) => Row(children: [Expanded(child: Text(label, style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)), SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.4))), child: Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')))]);
  
  Widget _bufferIndicator(String label, int value, int max) {
    final ratio = (value / max).clamp(0.0, 1.0);
    final color = ratio > 0.5 ? AppColors.success : (ratio > 0.2 ? AppColors.warning : AppColors.error);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(label, style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)), const Spacer(), Text('$value/$max', style: TextStyle(color: color, fontSize: 9, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold))]), SizedBox(height: 4), LinearProgressIndicator(value: ratio, minHeight: 3, backgroundColor: AppColors.surfaceBorder, color: color, borderRadius: BorderRadius.circular(2))]);
  }
}

class TelemetryPanel extends ConsumerWidget {
  const TelemetryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    return GlassPanel(
      title: 'TÉLÉMÉTRIE', 
      titleTrailing: Icon(Icons.waves, color: AppColors.primary, size: 14), 
      child: Column(children: [
        _telemetryRow('STATUT MACHINE', state?.status.name.toUpperCase() ?? 'HORS LIGNE', '', AppColors.textPrimary), 
        _telemetryRow('TEMP CORE', state?.coreTemp.toStringAsFixed(1) ?? '--', '°C', AppColors.textPrimary), 
        _telemetryRow('RTCP (G43.4)', (state?.isRtcpActive ?? false) ? 'ACTIF' : 'INACTIF', '', AppColors.success)
      ])
    );
  }
  
  Widget _telemetryRow(String label, String value, String unit, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
                    if (unit.isNotEmpty) ...[
                      SizedBox(width: 4),
                      Text(unit, style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
