import 'package:flutter/material.dart';
import 'dart:convert';
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

final isWorkshopModeProvider = StateProvider<bool>((ref) => false);

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

class _ConnectionHUD extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;
    final ip = ref.watch(espIpProvider);
    final isWorkshop = ref.watch(isWorkshopModeProvider);
    return GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('SYSTEM LINK', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const Spacer(),
          IconButton(icon: Icon(isWorkshop ? Icons.fullscreen_exit : Icons.touch_app, size: 16, color: AppColors.primary), onPressed: () => ref.read(isWorkshopModeProvider.notifier).state = !isWorkshop),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? AppColors.success : AppColors.error, boxShadow: [BoxShadow(color: isOnline ? AppColors.success : AppColors.error, blurRadius: 8)])),
          const SizedBox(width: 8),
          Text(isOnline ? 'ESP32 ONLINE' : 'OFFLINE', style: TextStyle(color: isOnline ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MACHINE ACTIONS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
        children: [
          _actionBtn(Icons.play_arrow, 'REPRENDRE', AppColors.success, () => repo.resume()),
          _actionBtn(Icons.pause, 'PAUSE', AppColors.warning, () => repo.pause()),
          _actionBtn(Icons.stop, 'ARRÊT', AppColors.danger, () => repo.emergencyStop()),
          _actionBtn(Icons.refresh, 'RESET', AppColors.textDisabled, () => repo.reset()),
          _actionBtn(Icons.home, 'HOME ALL', AppColors.axisZ, () => repo.home([])),
          _actionBtn(Icons.gps_fixed, 'GOTO ZERO', AppColors.secondary, () => repo.sendGCode('G0 X0 Y0 Z0')),
        ],
      ),
    ]);
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
  Widget _modalRow(String label, String value, Color color) => Row(children: [Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withOpacity(0.4))), child: Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')))]);
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
    return GlassPanel(title: 'Telemetry', titleTrailing: const Icon(Icons.waves, color: AppColors.primary, size: 14), child: Column(children: [_telemetryRow('MACHINE STATUS', state?.status.name.toUpperCase() ?? 'OFFLINE', '', AppColors.textPrimary), _telemetryRow('TEMP CORE', state?.coreTemp.toStringAsFixed(1) ?? '--', '°C', AppColors.textPrimary), _telemetryRow('RTCP (G43.4)', (state?.isRtcpActive ?? false) ? 'ACTIVE' : 'INACTIVE', '', AppColors.success)]));
  }
  Widget _telemetryRow(String label, String value, String unit, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900)), const Spacer(), Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')), if (unit.isNotEmpty) ...[const SizedBox(width: 4), Text(unit, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9))]]));
}

class _VisualizerPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final toolpath = ref.watch(toolpathProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('PATH VISUALIZATION', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)), const Spacer(), IconButton(icon: const Icon(Icons.layers_clear, size: 14, color: AppColors.textDisabled), onPressed: () => ref.read(toolpathProvider.notifier).clear())]),
      const SizedBox(height: 12),
      Expanded(child: GlassPanel(expand: true, padding: EdgeInsets.zero, child: Stack(children: [TrunnionVisualizer(mPos: mPos, targetPos: state?.targetPos, toolpath: toolpath), if ((state?.singularityRisk ?? 0.0) > 0.5) Positioned(top: 12, left: 12, right: 12, child: _SingularityAlert(risk: state!.singularityRisk))]))),
    ]);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DIGITAL READOUT', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 12), for (int i = 0; i < 3; i++) _coordCard(['X', 'Y', 'Z'][i], wPos[i], [AppColors.axisX, AppColors.axisY, AppColors.axisZ][i]), Row(children: [Expanded(child: _coordCard('A', wPos[3], AppColors.axisA, small: true)), const SizedBox(width: 8), Expanded(child: _coordCard('C', wPos[4], AppColors.axisC, small: true))])]);
  }
  Widget _coordCard(String a, double v, Color c, {bool small = false}) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4), border: Border(left: BorderSide(color: c, width: 3))), child: Row(children: [Text(a, style: TextStyle(color: c, fontSize: small ? 14 : 18, fontWeight: FontWeight.w900)), const Spacer(), Text(v.toStringAsFixed(3), style: TextStyle(color: AppColors.textPrimary, fontSize: small ? 20 : 28, fontWeight: FontWeight.w900))]));
}

class _OverridesPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final ov = state?.overrides ?? [100, 100, 100];
    return GlassPanel(title: 'OVERRIDES', child: Column(children: [_ovRow('FEED', ov[0], AppColors.primary), _ovRow('RAPID', ov[1], AppColors.axisZ), _ovRow('SPINDLE', ov[2], AppColors.secondary)]));
  }
  Widget _ovRow(String l, int v, Color c) => Row(children: [Text(l, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9)), const Spacer(), Text('$v%', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold))]);
}

class _DynamicsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    return GlassPanel(title: 'DYNAMIQUE', child: Column(children: [_dynRow('FEEDRATE', 'F${state?.feedrate.toInt() ?? 0}', AppColors.textPrimary), _dynRow('SPINDLE', '${state?.spindleSpeed.toInt() ?? 0} RPM', AppColors.secondary)]));
  }
  Widget _dynRow(String l, String v, Color c) => Row(children: [Text(l, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10)), const Spacer(), Text(v, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold))]);
}

class _WorkshopLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('WORKSHOP MODE', style: TextStyle(color: Colors.white)));
  }
}

class _MacrosPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MACROS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 12), for (final m in defaultMacros) Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => ref.read(machineRepositoryProvider).sendGCode(m.gcode), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: m.color.withOpacity(0.1), border: Border.all(color: m.color.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)), child: Row(children: [Icon(m.icon, color: m.color, size: 16), const SizedBox(width: 12), Text(m.name, style: TextStyle(color: m.color, fontSize: 10, fontWeight: FontWeight.bold))]))))]);
  }
}

class _GCodeConsolePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(activeGCodeProvider);
    final state = ref.watch(machineStateProvider).valueOrNull;
    final currentIndex = (state?.activeLineIndex ?? 0) - 1; // 1-based to 0-based
    return GlassPanel(
      title: 'FLUX G-CODE TEMPS RÉEL',
      expand: true,
      titleTrailing: IconButton(
        icon: const Icon(Icons.file_open, color: AppColors.primary, size: 14),
        onPressed: () => _pickFile(ref),
        tooltip: 'Charger un fichier G-Code',
      ),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (ctx, i) {
          final isCurrent = i == currentIndex;
          return Container(
            color: isCurrent ? AppColors.primary.withOpacity(0.1) : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              SizedBox(width: 30, child: Text('${lines[i].number}', style: TextStyle(color: isCurrent ? AppColors.primary : AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono'))),
              const SizedBox(width: 8),
              Expanded(child: Text(lines[i].content, style: TextStyle(color: isCurrent ? AppColors.primary : AppColors.textPrimary, fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontFamily: 'JetBrains Mono'))),
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
      final rawLines = content.split('\n');
      final List<GCodeLine> newLines = [];
      final List<String> stringLines = [];
      
      for (int i = 0; i < rawLines.length; i++) {
        final line = rawLines[i].trim();
        if (line.isNotEmpty) {
          newLines.add(GCodeLine(number: i + 1, content: line));
          stringLines.add(line);
        }
      }
      
      ref.read(activeGCodeProvider.notifier).state = newLines;
      // Synchroniser avec le repository pour la simulation
      await ref.read(machineRepositoryProvider).sendGCodeBatch(stringLines);
    }
  }
}
