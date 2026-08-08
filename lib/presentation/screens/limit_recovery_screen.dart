import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/jog_control_panel.dart';

/// Récupération guidée après une alarme (dont fin de course / hard limit) :
/// déverrouiller ($X) → dégager l'axe de la butée → re-homing.
class LimitRecoveryScreen extends ConsumerWidget {
  const LimitRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final state = ref.watch(machineStateProvider).valueOrNull;
    final status = state?.status ?? MachineStatus.offline;
    final inAlarm = status == MachineStatus.alarm;
    final wPos = state?.wPos ?? const [0.0, 0.0, 0.0, 0.0, 0.0];

    const axes = ['X', 'Y', 'Z', 'A', 'C'];
    final active = <String>[];
    for (int i = 0; i < 5 && state != null && i < state.limitSwitches.length; i++) {
      if (state.limitSwitches[i]) active.add(axes[i]);
    }

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        title: const Text('RÉCUPÉRATION',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // État live
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (inAlarm ? fc.danger : fc.success).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (inAlarm ? fc.danger : fc.success)
                      .withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(inAlarm ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: inAlarm ? fc.danger : fc.success, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statut : ${status.name.toUpperCase()}',
                        style: TextStyle(
                            color: inAlarm ? fc.danger : fc.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                    if (active.isNotEmpty)
                      Text('Fins de course actives : ${active.join(', ')}',
                          style:
                              TextStyle(color: fc.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Étape 1 : Déverrouiller ─────────────────────────────────────
          _stepLabel(fc, 1, 'Déverrouiller'),
          const SizedBox(height: 6),
          Text(
            'La machine est verrouillée en alarme. Déverrouille-la pour '
            'autoriser un mouvement de dégagement.',
            style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          _bigButton(fc, fc.warning, Icons.lock_open_rounded,
              'DÉVERROUILLER (\$X)', inAlarm, () {
            ref.read(machineRepositoryProvider).sendRaw('\$X\n');
            HapticFeedback.mediumImpact();
          }),
          const SizedBox(height: 24),

          // ── Étape 2 : Dégager ───────────────────────────────────────────
          _stepLabel(fc, 2, 'Dégager l\'axe de la butée'),
          const SizedBox(height: 6),
          Text(
            'Éloigne l\'axe touché de la butée par PETITS pas (choisis ×1), '
            'dans le sens OPPOSÉ à la fin de course. Le jog est autorisé même '
            'butée active pour permettre le dégagement.',
            style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: JogControlPanel(wPos: wPos),
          ),
          const SizedBox(height: 24),

          // ── Étape 3 : Re-homing ─────────────────────────────────────────
          _stepLabel(fc, 3, 'Re-homing'),
          const SizedBox(height: 6),
          Text(
            'Une fois l\'axe dégagé et toutes les butées relâchées, relance le '
            'homing pour rétablir le zéro machine.',
            style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          _bigButton(fc, fc.axisZ, Icons.home_rounded, 'RELANCER LE HOMING (\$H)',
              active.isEmpty && !inAlarm, () {
            ref.read(machineRepositoryProvider).home();
            HapticFeedback.mediumImpact();
          }),
          const SizedBox(height: 16),
          if (active.isNotEmpty)
            Text(
              '⚠️ Des fins de course sont encore actives — dégage-les avant le homing.',
              style: TextStyle(color: fc.warning, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _stepLabel(ForgeronColorPalette fc, int n, String text) {
    return Row(children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fc.primary.withValues(alpha: 0.15),
          border: Border.all(color: fc.primary.withValues(alpha: 0.5)),
        ),
        child: Text('$n',
            style: TextStyle(
                color: fc.primary, fontWeight: FontWeight.w900, fontSize: 12)),
      ),
      const SizedBox(width: 10),
      Text(text,
          style: TextStyle(
              color: fc.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _bigButton(ForgeronColorPalette fc, Color color, IconData icon,
      String label, bool enabled, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: enabled ? color.withValues(alpha: 0.1) : fc.surfaceBright,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: enabled
                      ? color.withValues(alpha: 0.5)
                      : fc.surfaceBorder,
                  width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: enabled ? color : fc.textDisabled, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: enabled ? color : fc.textDisabled,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5)),
            ]),
          ),
        ),
      ),
    );
  }
}
