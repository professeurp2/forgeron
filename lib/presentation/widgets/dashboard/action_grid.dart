import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/services/audio_service.dart';
import '../../tutorial/tutorial_keys.dart';
import '../../../application/providers/di_providers.dart';

class ActionGrid extends ConsumerWidget {
  const ActionGrid({super.key});

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
            _actionBtn(ref, Icons.play_arrow, 'REPRENDRE', AppColors.success, () {
              repo.resume();
              _showFeedback(context, 'Reprise (Cycle Start)');
            }),
            _actionBtn(ref, Icons.pause, 'PAUSE', AppColors.warning, () {
              repo.pause();
              _showFeedback(context, 'Pause (Feed Hold)');
            }),
            _actionBtn(ref, Icons.stop, 'ARRÊT', AppColors.danger, () {
              repo.emergencyStop();
              _showFeedback(context, 'Arrêt / Reset');
            }),
            _actionBtn(ref, Icons.refresh, 'RESET', AppColors.textDisabled, () {
              repo.sendRaw('\x18'); // Soft reset
              Future.delayed(const Duration(milliseconds: 500), () => repo.sendRaw('\$X\n')); // Unlock alarm
              _showFeedback(context, 'Soft Reset & Déverrouillage');
            }),
            _actionBtn(ref, Icons.home, 'ORIGINE TOUS', AppColors.axisZ, () {
              repo.sendRaw('\$X\n'); // Unlock alarm d'abord
              Future.delayed(const Duration(milliseconds: 300), () => repo.home([]));
              _showFeedback(context, 'Homing global initié (\$H)');
            }),
            _actionBtn(ref, Icons.gps_fixed, 'ALLER ZÉRO', AppColors.secondary, () {
              repo.sendGCode('G90 G0 X0 Y0 Z0 A0 C0');
              _showFeedback(context, 'Retour à l\'origine pièce (G0)');
            }),
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
                  repo.setSimulationSpeed(v);
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
  
  Widget _actionBtn(WidgetRef ref, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        ref.read(audioServiceProvider).play(SoundEffect.click);
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: AppColors.surfaceBright,
      duration: const Duration(seconds: 2),
    ));
  }
}
