import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import '../../core/widgets/split_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth =
          constraints.maxWidth < 900 ? 900.0 : constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: contentWidth,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ResizableSplitView(
              initialRatio: 0.25,
              left: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SingleChildScrollView(
                  child: Column(children: [
                    _ConnectionHUD(),
                    const SizedBox(height: 24),
                    _ActionGrid(),
                    const SizedBox(height: 24),
                    _ModalStatePanel(),
                    const SizedBox(height: 24),
                    _TelemetryPanel(),
                  ]),
                ),
              ),
              right: ResizableSplitView(
                initialRatio: 0.55,
                left: Padding(
                  padding: const EdgeInsets.only(right: 8, left: 8),
                  child: _VisualizerPanel(),
                ),
                right: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SingleChildScrollView(
                    child: Column(children: [
                      _DROPanel(),
                      const SizedBox(height: 24),
                      _OverridesPanel(),
                      const SizedBox(height: 24),
                      _DynamicsPanel(),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Connexion HUD ─────────────────────────────────────────────────────────────
class _ConnectionHUD extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(machineStateProvider);
    final state = stateAsync.valueOrNull;
    final isOnline = state?.status != null &&
        state?.status != MachineStatus.offline;
    final ip = ref.watch(espIpProvider);

    return GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SYSTEM LINK',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.success : AppColors.error,
              boxShadow: [
                BoxShadow(
                    color: isOnline ? AppColors.success : AppColors.error,
                    blurRadius: 8)
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isOnline ? 'ESP32 ONLINE' : 'OFFLINE',
              style: TextStyle(
                  color: isOnline ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(ip,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 9,
                fontFamily: 'JetBrains Mono')),
        const SizedBox(height: 12),
        for (final t in [
          'WEBSOCKET ws://...:81',
          'GRBL/FluidNC PROTOCOL',
          'AXES: X Y Z A C',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(t,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'JetBrains Mono')),
          ),
      ]),
    );
  }
}

// ── Actions Machine ───────────────────────────────────────────────────────────
class _ActionGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(machineRepositoryProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MACHINE ACTIONS',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          _actionBtn(Icons.play_arrow, 'REPRENDRE', AppColors.success,
              () => repo.resume()),
          _actionBtn(
              Icons.pause, 'PAUSE', AppColors.warning, () => repo.pause()),
          _actionBtn(Icons.stop, 'ARRÊT', AppColors.danger,
              () => repo.emergencyStop()),
          _actionBtn(Icons.refresh, 'RESET', AppColors.textDisabled,
              () => repo.reset()),
          _actionBtn(Icons.home, 'HOME ALL', AppColors.axisZ,
              () => repo.home([])),
          _actionBtn(Icons.gps_fixed, 'GOTO ZERO', AppColors.secondary,
              () => repo.sendGCode('G0 X0 Y0 Z0')),
        ],
      ),
    ]);
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── État Modal (WCS actif, Outil actif) ───────────────────────────────────────
class _ModalStatePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final wcs = state?.activeWCS ?? 'G54';
    final tool = state?.activeToolNum ?? 0;
    final planBuf = state?.plannerBuffer ?? 15;
    final rxBuf = state?.rxBuffer ?? 128;

    return GlassPanel(
      title: 'ÉTAT MODAL',
      child: Column(children: [
        // WCS actif
        _modalRow('WCS ACTIF', wcs, AppColors.primary),
        const SizedBox(height: 8),
        // Outil actif
        _modalRow('OUTIL ACTIF', 'T$tool', AppColors.secondary),
        const Divider(color: AppColors.surfaceBorder, height: 20),
        // Buffers FluidNC
        Row(children: [
          Expanded(child: _bufferIndicator('PLAN', planBuf, 15)),
          const SizedBox(width: 8),
          Expanded(child: _bufferIndicator('RX', rxBuf, 128)),
        ]),
      ]),
    );
  }

  Widget _modalRow(String label, String value, Color color) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
              fontWeight: FontWeight.w900)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono')),
      ),
    ]);
  }

  Widget _bufferIndicator(String label, int value, int max) {
    final ratio = (value / max).clamp(0.0, 1.0);
    final color = ratio > 0.5
        ? AppColors.success
        : (ratio > 0.2 ? AppColors.warning : AppColors.error);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
        const Spacer(),
        Text('$value/$max',
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      LinearProgressIndicator(
        value: ratio,
        minHeight: 3,
        backgroundColor: AppColors.surfaceBorder,
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    ]);
  }
}

// ── Télémétrie ────────────────────────────────────────────────────────────────
class _TelemetryPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(machineStateProvider);
    final status =
        stateAsync.valueOrNull?.status.name.toUpperCase() ?? 'OFFLINE';
    final alarm = stateAsync.valueOrNull?.alarmCode;

    return GlassPanel(
      title: 'Telemetry',
      titleTrailing: const Icon(Icons.waves, color: AppColors.primary, size: 14),
      child: Column(children: [
        for (final e in [
          ('MACHINE STATUS', status, ''),
          ('TEMP CORE', '42.5', '°C'),
          ('VOLTAGE', '24.1', 'V'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Text(e.$1,
                  style: const TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(e.$2,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
              const SizedBox(width: 4),
              Text(e.$3,
                  style: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 9)),
            ]),
          ),
        if (alarm != null) ...[
          const Divider(color: AppColors.error, height: 16),
          Row(children: [
            const Icon(Icons.warning_amber, color: AppColors.error, size: 14),
            const SizedBox(width: 8),
            Text('ALARM: $alarm',
                style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono')),
          ]),
        ],
      ]),
    );
  }
}

// ── Visualiseur 3D (placeholder) ──────────────────────────────────────────────
class _VisualizerPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('PATH VISUALIZATION — TRUNNION 5X',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0)),
      const SizedBox(height: 12),
      Expanded(
        child: GlassPanel(
          expand: true,
          padding: EdgeInsets.zero,
          child: Stack(children: [
            // Visualiseur trunnion schématique
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.architecture,
                      color: AppColors.surfaceBright, size: 80),
                  const SizedBox(height: 8),
                  const Text('TRUNNION VIEW',
                      style: TextStyle(
                          color: AppColors.surfaceBright,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    'A: ${mPos[3].toStringAsFixed(1)}°  C: ${mPos[4].toStringAsFixed(1)}°',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PERSPECTIVE VIEW',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                Text('MODEL: TRUNNION_5X_ENI',
                    style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 9)),
              ]),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Text('CYCLE PROGRESS',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text('67%',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono')),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.67,
                    minHeight: 4,
                    backgroundColor: Colors.black,
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ── DRO 5-axes — Linéaires (mm) + Rotatifs (°) ───────────────────────────────
class _DROPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(machineStateProvider);
    final state = stateAsync.valueOrNull;
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final isMoving = state?.status == MachineStatus.run;
    final wcs = state?.activeWCS ?? 'G54';
    final limSw = state?.limitSwitches ?? [false, false, false, false, false];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('DIGITAL READOUT',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Text(wcs,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
        ),
      ]),
      const SizedBox(height: 8),
      // Séparateur axes linéaires
      const Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: Text('LINÉAIRES — mm',
            style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ),
      _coordCard('X', wPos[0], mPos[0], AppColors.axisX, true, isMoving,
          limSw[0], 'mm'),
      const SizedBox(height: 6),
      _coordCard('Y', wPos[1], mPos[1], AppColors.axisY, true, isMoving,
          limSw[1], 'mm'),
      const SizedBox(height: 6),
      _coordCard('Z', wPos[2], mPos[2], AppColors.axisZ, true, isMoving,
          limSw[2], 'mm'),
      const SizedBox(height: 12),
      // Séparateur axes rotatifs
      const Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: Text('ROTATIFS — degrés',
            style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ),
      // A et C côte à côte pour gagner de la place
      Row(children: [
        Expanded(
          child: _coordCard('A', wPos[3], mPos[3], AppColors.axisA, false,
              isMoving, limSw[3], '°'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _coordCard('C', wPos[4], mPos[4], AppColors.axisC, false,
              isMoving, limSw[4], '°'),
        ),
      ]),
    ]);
  }

  Widget _coordCard(String axis, double wValue, double mValue, Color color,
      bool isLarge, bool isMoving, bool limActive, String unit) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: isLarge ? 14 : 10),
      decoration: BoxDecoration(
        color: limActive
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
              color: limActive ? AppColors.error : color, width: 3),
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          right: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
        ),
        boxShadow: isMoving
            ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20)]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(axis,
              style: TextStyle(
                  color: limActive ? AppColors.error : color,
                  fontSize: isLarge ? 16 : 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                  shadows: isMoving
                      ? [Shadow(color: color, blurRadius: 10)]
                      : null)),
          const SizedBox(width: 6),
          Text(unit,
              style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 9)),
          if (limActive) ...[
            const SizedBox(width: 6),
            const Icon(Icons.warning_amber,
                color: AppColors.error, size: 12),
          ],
          const Spacer(),
          // MPos en petit
          Text('M:${mValue.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 8,
                  fontFamily: 'JetBrains Mono')),
        ]),
        const SizedBox(height: 2),
        // WPos en grand
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            wValue.toStringAsFixed(isLarge ? 3 : 2),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isLarge ? 32 : 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono',
                letterSpacing: -1.0),
          ),
        ),
      ]),
    );
  }
}

// ── Overrides temps réel ──────────────────────────────────────────────────────
class _OverridesPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final ov = state?.overrides ?? [100, 100, 100];
    final repo = ref.read(machineRepositoryProvider);

    return GlassPanel(
      title: 'OVERRIDES TEMPS RÉEL',
      child: Column(children: [
        _overrideRow('FEED', ov[0], AppColors.primary, (v) {
          try { (repo as dynamic).setFeedOverride(v); } catch (_) {}
        }),
        const SizedBox(height: 12),
        _overrideRow('RAPID', ov[1], AppColors.axisZ, (v) {
          try { (repo as dynamic).setRapidOverride(v); } catch (_) {}
        }),
        const SizedBox(height: 12),
        _overrideRow('SPINDLE', ov[2], AppColors.secondary, (v) {
          try { (repo as dynamic).setSpindleOverride(v); } catch (_) {}
        }),
      ]),
    );
  }

  Widget _overrideRow(
      String label, int value, Color color, ValueChanged<int> onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const Spacer(),
        Text('$value%',
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono')),
      ]),
      const SizedBox(height: 6),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: color,
          inactiveTrackColor: AppColors.surfaceBorder,
          thumbColor: color,
          overlayColor: color.withValues(alpha: 0.15),
        ),
        child: Slider(
          min: 10,
          max: 200,
          divisions: 19,
          value: value.clamp(10, 200).toDouble(),
          onChanged: (v) => onChange(v.round()),
        ),
      ),
    ]);
  }
}

// ── Dynamique d'usinage ───────────────────────────────────────────────────────
class _DynamicsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final feed = state?.feedrate.toStringAsFixed(0) ?? '0';
    final spindle = state?.spindleSpeed.toStringAsFixed(0) ?? '0';

    return GlassPanel(
      title: 'Dynamique d\'usinage',
      child: Column(children: [
        for (final e in [
          ('FEEDRATE', 'F$feed', 'mm/min'),
          ('SPINDLE', '$spindle RPM', 'S'),
          ('LOAD', '2.4', 'kW'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Text(e.$1,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(e.$2,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
              const SizedBox(width: 8),
              Text(e.$3,
                  style: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 8)),
            ]),
          ),
        const Divider(color: AppColors.surfaceBorder, height: 24),
        const Row(children: [
          Text('ESTIMATED',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          Spacer(),
          Text('01:47:22',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
          SizedBox(width: 8),
          Text('TIME',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 8)),
        ]),
      ]),
    );
  }
}
