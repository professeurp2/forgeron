import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/providers/jog_provider.dart';
import '../../../application/providers/di_providers.dart';
import '../../../domain/models/machine_state.dart';
import '../../../application/providers/streaming_provider.dart';
import '../dashboard/jog_control_panel.dart';

class MobileWorkshopScreen extends ConsumerWidget {
  const MobileWorkshopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final wPos = state?.wPos ?? List.filled(5, 0.0);
    final fc = context.fc;

    return Scaffold(
      backgroundColor: Colors.black, // Contraste maximum
      body: SafeArea(
        child: Column(
          children: [
            // ── Header d'Urgence / Sortie ──────────────────────────────────
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: fc.surfaceBorder.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.factory_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  const Text('MODE ATELIER', 
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white70),
                    onPressed: () => ref.read(isWorkshopModeProvider.notifier).state = false,
                  ),
                ],
              ),
            ),

            // ── DRO GÉANT (Occupant la majeure partie) ─────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _GiantAxisRow('X', wPos[0], fc.axisX),
                    _GiantAxisRow('Y', wPos[1], fc.axisY),
                    _GiantAxisRow('Z', wPos[2], fc.axisZ),
                    Row(
                      children: [
                        Expanded(child: _GiantAxisRow('A', wPos[3], fc.axisA, small: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _GiantAxisRow('C', wPos[4], fc.axisC, small: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── CONTRÔLES RAPIDES GÉANTS ────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _WorkshopBigButton(
                      label: 'JOG',
                      icon: Icons.open_with_rounded,
                      color: fc.primary,
                      onTap: () => _showJogModal(context, wPos),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WorkshopBigButton(
                      label: state?.status == MachineStatus.hold ? 'RUN' : 'CYCLE',
                      icon: Icons.play_arrow_rounded,
                      color: fc.success,
                      onTap: () => _handleCycle(ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WorkshopBigButton(
                      label: 'STOP',
                      icon: Icons.stop_rounded,
                      color: fc.danger,
                      onTap: () => ref.read(machineRepositoryProvider).reset(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCycle(WidgetRef ref) {
    final repo = ref.read(machineRepositoryProvider);
    final status = ref.read(machineStateProvider).valueOrNull?.status;
    if (status == MachineStatus.hold) {
      repo.resume();
    } else {
      ref.read(streamingProvider.notifier).startStream();
    }
    HapticFeedback.heavyImpact();
  }

  void _showJogModal(BuildContext context, List<double> wPos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: context.fc.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('CONTROLE JOG', style: TextStyle(color: context.fc.textPrimary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: JogControlPanel(wPos: wPos))),
          ],
        ),
      ),
    );
  }
}

class _GiantAxisRow extends StatelessWidget {
  final String axis;
  final double value;
  final Color color;
  final bool small;

  const _GiantAxisRow(this.axis, this.value, this.color, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: small ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Text(axis, style: TextStyle(color: color, fontSize: small ? 24 : 32, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(
            value.toStringAsFixed(small ? 2 : 3),
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 32 : 52,
              fontWeight: FontWeight.bold,
              fontFamily: 'JetBrains Mono',
              shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 15)],
            ),
          ),
          const SizedBox(width: 10),
          Text(small ? '°' : 'mm', style: const TextStyle(color: Colors.white24, fontSize: 14)),
        ],
      ),
    );
  }
}

class _WorkshopBigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WorkshopBigButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
