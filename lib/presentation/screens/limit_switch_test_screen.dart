import 'package:flutter/material.dart';
import '../../core/widgets/readable_width.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import '../../core/i18n/app_localizations.dart';

/// Mode « Test des fins de course » : l'opérateur presse chaque switch à la
/// main et voit en direct quel axe change d'état. Valide le câblage, le bon
/// axe et l'orientation (NO/NC) AVANT d'activer les hard limits.
class LimitSwitchTestScreen extends ConsumerStatefulWidget {
  const LimitSwitchTestScreen({super.key});

  @override
  ConsumerState<LimitSwitchTestScreen> createState() =>
      _LimitSwitchTestScreenState();
}

class _LimitSwitchTestScreenState
    extends ConsumerState<LimitSwitchTestScreen> {
  final Set<int> _seen = {};
  static const _axes = ['X', 'Y', 'Z', 'A', 'C'];

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final state = ref.watch(machineStateProvider).valueOrNull;
    final online = state != null && state.status != MachineStatus.offline;
    final lim = state?.limitSwitches ?? const [false, false, false, false, false];
    final colors = [fc.axisX, fc.axisY, fc.axisZ, fc.axisA, fc.axisC];

    // Mémorise chaque axe vu « actif » au moins une fois (validation câblage).
    ref.listen(machineStateProvider, (prev, next) {
      final l = next.valueOrNull?.limitSwitches;
      if (l == null) return;
      for (int i = 0; i < 5 && i < l.length; i++) {
        if (l[i] && !_seen.contains(i)) {
          setState(() => _seen.add(i));
          HapticFeedback.mediumImpact();
        }
      }
    });

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        title: Text(tr('TEST FINS DE COURSE'),
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _seen.clear()),
            icon: Icon(Icons.refresh_rounded, size: 16, color: fc.textSecondary),
            label: Text(tr('Réinit.'),
                style: TextStyle(color: fc.textSecondary, fontSize: 12)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!online)
              _banner(fc, fc.warning, Icons.cloud_off,
                  'Machine hors ligne — connecte l\'ESP32 pour tester.'),
            Text(
              tr('Presse manuellement chaque fin de course. L\'axe correspondant doit passer à ACTIF. Vérifie que c\'est le bon axe et le bon sens.'),
              style: TextStyle(color: fc.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < 5; i++)
              _axisRow(fc, _axes[i], colors[i], lim.length > i && lim[i],
                  _seen.contains(i)),
            const SizedBox(height: 16),
            _summary(fc),
            const SizedBox(height: 12),
            _banner(
              fc,
              fc.warning,
              Icons.warning_amber_rounded,
              'N\'active les hard limits (Paramètres → Machine → config) qu\'une '
              'fois TOUS tes switches validés ici — un câblage inversé provoquerait '
              'des alarmes intempestives.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _axisRow(ForgeronColorPalette fc, String axis, Color color,
      bool active, bool seen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color : fc.surfaceBorder,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: active ? 0.3 : 0.12),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Text(axis,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            active ? 'ACTIF' : 'relâché',
            style: TextStyle(
              color: active ? color : fc.textDisabled,
              fontSize: 16,
              fontWeight: active ? FontWeight.w900 : FontWeight.w500,
              letterSpacing: active ? 1 : 0,
            ),
          ),
        ),
        // Pastille « vu au moins une fois » (validation câblage).
        if (seen)
          Row(children: [
            Icon(Icons.check_circle_rounded, color: fc.success, size: 18),
            const SizedBox(width: 4),
            Text(tr('détecté'),
                style: TextStyle(color: fc.success, fontSize: 11)),
          ])
        else
          Text(tr('jamais vu'),
              style: TextStyle(color: fc.textDisabled, fontSize: 11)),
      ]),
    );
  }

  Widget _summary(ForgeronColorPalette fc) {
    final n = _seen.length;
    final color = n == 0 ? fc.textDisabled : (n >= 3 ? fc.success : fc.primary);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.fact_check_outlined, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tr('{} fin(s) de course détectée(s) : {}', [
              n,
              _seen.isEmpty ? '—' : _seen.map((i) => _axes[i]).join(', '),
            ]),
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _banner(
      ForgeronColorPalette fc, Color color, IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(color: color, fontSize: 11, height: 1.4)),
        ),
      ]),
    );
  }
}
