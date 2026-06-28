import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/machine_status_color.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../domain/models/machine_state.dart';
import '../../../application/providers/di_providers.dart';
import '../../screens/cnc_panel_screen.dart';


class WorkshopLayout extends ConsumerWidget {
  const WorkshopLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le mode atelier pointe désormais vers le Pupitre CNC industriel 5 axes.
    // CncPanelScreen gère son propre bouton "Quitter" qui remet isWorkshopModeProvider à false.
    return const CncPanelScreen();
  }
}


class CockpitHeader extends ConsumerWidget {
  final MachineState? state;
  const CockpitHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.precision_manufacturing, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          const Text('FORGERON', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const Text(' HMI', style: TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w300)),
          const Spacer(),
          WorkshopQuickActions(repo: ref.read(machineRepositoryProvider)),
          const SizedBox(width: 24),
          CockpitStatusBadge(
            label: state?.status.name.toUpperCase() ?? 'OFFLINE',
            color: getMachineStatusColor(state?.status ?? MachineStatus.offline),
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textDisabled, size: 28),
            onPressed: () => ref.read(isWorkshopModeProvider.notifier).state = false,
          ),
        ],
      ),
    );
  }
}

class GiantIndustrialDRO extends StatelessWidget {
  final MachineState? state;
  const GiantIndustrialDRO({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    return Column(
      children: [
        _axis('X', wPos[0], AppColors.axisX),
        const SizedBox(height: 16),
        _axis('Y', wPos[1], AppColors.axisY),
        const SizedBox(height: 16),
        _axis('Z', wPos[2], AppColors.axisZ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _miniAxis('A', wPos[3], AppColors.axisA)),
            const SizedBox(width: 16),
            Expanded(child: _miniAxis('C', wPos[4], AppColors.axisC)),
          ],
        ),
      ],
    );
  }

  Widget _axis(String name, double val, Color color) {
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

class WorkshopGauges extends StatelessWidget {
  final MachineState? state;
  const WorkshopGauges({super.key, required this.state});

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

class IndustrialControlPanel extends ConsumerWidget {
  final dynamic repo;
  const IndustrialControlPanel({super.key, required this.repo});

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
              repo.setSimulationSpeed(v);
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

class WorkshopQuickActions extends StatelessWidget {
  final dynamic repo;
  const WorkshopQuickActions({super.key, required this.repo});

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

class CockpitStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const CockpitStatusBadge({super.key, required this.label, required this.color});

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
