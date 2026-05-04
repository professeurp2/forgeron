import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../domain/models/jog_command.dart';
import '../../core/widgets/split_view.dart';

class ProbingScreen extends ConsumerStatefulWidget {
  const ProbingScreen({super.key});
  @override
  ConsumerState<ProbingScreen> createState() => _ProbingScreenState();
}

class _ProbingScreenState extends ConsumerState<ProbingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedWCS = 0;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  static const _wcsData = [
    ('G54', [120.500, -45.200, 0.000, 0.000, 90.000]),
    ('G55', [0.000, 0.000, 0.000, 0.000, 0.000]),
    ('G56', [250.000, 100.000, 0.000, 45.000, 180.000]),
  ];
  static const _axisLabels = ['X', 'Y', 'Z', 'A', 'C'];
  static const _axisColors = [
    AppColors.axisX, AppColors.axisY, AppColors.axisZ,
    AppColors.axisA, AppColors.axisC
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineStateProvider);
    final wPos = state.valueOrNull?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return ResizableSplitView(
      initialRatio: 0.28,
      left: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('WORK COORDINATE SYSTEMS',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          for (int i = 0; i < _wcsData.length; i++) _wcsCard(i),
          const SizedBox(height: 24),
          const Text('LIVE DRO',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          for (int i = 0; i < 5; i++)
            _liveDroRow(_axisLabels[i], wPos[i], _axisColors[i],
                i >= 3 ? '°' : 'mm'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 40,
            child: OutlinedButton(
              onPressed: () => ref.read(machineRepositoryProvider).sendGCode('G0 X0 Y0 Z0 A0 C0'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.textDisabled)),
              child: const Text('GOTO ZERO', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 40,
            child: OutlinedButton(
              onPressed: () => ref.read(jogProvider.notifier).homeAll(),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.axisZ)),
              child: const Text('HOME ALL', style: TextStyle(color: AppColors.axisZ, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
      right: ResizableSplitView(
        initialRatio: 0.6,
        left: Column(children: [
          Container(
            decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textDisabled,
              tabs: const [
                Tab(icon: Icon(Icons.center_focus_strong, size: 16), text: 'JOG 5-AXES'),
                Tab(icon: Icon(Icons.vertical_align_bottom, size: 16), text: 'Z-PROBE'),
                Tab(icon: Icon(Icons.rotate_right, size: 16), text: 'ALIGNEMENT A/C'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_JogPanel5Axes(), _ZProbeTab(), _AlignementTab()],
            ),
          ),
        ]),
        right: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _HomingSequencePanel(),
          ]),
        ),
      ),
    );
  }

  Widget _wcsCard(int i) {
    final sel = i == _selectedWCS;
    final d = _wcsData[i];
    return InkWell(
      onTap: () => setState(() => _selectedWCS = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: sel ? AppColors.primary : AppColors.surfaceBorder, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceBright,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(d.$1,
                style: TextStyle(color: sel ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'JetBrains Mono')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (int j = 0; j < 5; j++)
                Text('${_axisLabels[j]}:${d.$2[j].toStringAsFixed(2)}',
                    style: TextStyle(color: _axisColors[j], fontSize: 9, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _liveDroRow(String axis, double val, Color color, String unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Text(axis, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
        const SizedBox(width: 6),
        Text(unit, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9)),
        const Spacer(),
        Text(val.toStringAsFixed(axis == 'A' || axis == 'C' ? 2 : 3),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
      ]),
    );
  }
}

// ── Jog Panel 5-axes Trunnion ─────────────────────────────────────────────────
class _JogPanel5Axes extends ConsumerStatefulWidget {
  @override
  ConsumerState<_JogPanel5Axes> createState() => _JogPanel5AxesState();
}

class _JogPanel5AxesState extends ConsumerState<_JogPanel5Axes> {
  @override
  Widget build(BuildContext context) {
    final jog = ref.watch(jogProvider);
    final jogN = ref.read(jogProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Sélecteur de pas ──────────────────────────────────────────────
        _sectionTitle('PAS LINÉAIRE (mm)'),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final s in LinearJogStep.steps)
            _stepChip(s.toString(), s == jog.linearStep, AppColors.axisX,
                () => jogN.setLinearStep(s)),
        ]),
        const SizedBox(height: 12),
        _sectionTitle('PAS ROTATIF (°)'),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final s in RotaryJogStep.steps)
            _stepChip('$s°', s == jog.rotaryStep, AppColors.axisA,
                () => jogN.setRotaryStep(s)),
        ]),
        const SizedBox(height: 20),
        // ── Axes linéaires X/Y/Z ─────────────────────────────────────────
        _sectionTitle('AXES LINÉAIRES'),
        const SizedBox(height: 8),
        // Jog XY en grille
        Row(children: [
          Expanded(child: _linearGroup()),
          const SizedBox(width: 16),
          // Z vertical
          Column(children: [
            _jogBtn('Z+', AppColors.axisZ, () => jogN.jogLinear('Z', 1)),
            const SizedBox(height: 8),
            _jogBtn('Z-', AppColors.axisZ, () => jogN.jogLinear('Z', -1)),
          ]),
        ]),
        const SizedBox(height: 20),
        // ── Axes rotatifs A/C ────────────────────────────────────────────
        _sectionTitle('AXES ROTATIFS — TRUNNION'),
        const SizedBox(height: 8),
        Row(children: [
          // Axe A (tilt broche)
          Expanded(
            child: GlassPanel(
              title: 'A — TILT BROCHE',
              child: Column(children: [
                const Icon(Icons.rotate_90_degrees_ccw, color: AppColors.axisA, size: 28),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _jogBtn('A-', AppColors.axisA, () => jogN.jogRotary('A', -1)),
                  _jogBtn('A+', AppColors.axisA, () => jogN.jogRotary('A', 1)),
                ]),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          // Axe C (rotation plateau)
          Expanded(
            child: GlassPanel(
              title: 'C — ROTATION PLATEAU',
              child: Column(children: [
                const Icon(Icons.sync, color: AppColors.axisC, size: 28),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _jogBtn('C-', AppColors.axisC, () => jogN.jogRotary('C', -1)),
                  _jogBtn('C+', AppColors.axisC, () => jogN.jogRotary('C', 1)),
                ]),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // ── JOG STOP ─────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.stop, size: 20),
            label: const Text('JOG STOP  (0x85)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => jogN.stopJog(),
          ),
        ),
      ]),
    );
  }

  Widget _linearGroup() {
    final jogN = ref.read(jogProvider.notifier);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _jogBtn('Y+', AppColors.axisY, () => jogN.jogLinear('Y', 1)),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _jogBtn('X-', AppColors.axisX, () => jogN.jogLinear('X', -1)),
        const SizedBox(width: 8),
        Container(width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceBright, border: Border.all(color: AppColors.surfaceBorder)),
            child: const Center(child: Icon(Icons.add, size: 12, color: AppColors.textDisabled))),
        const SizedBox(width: 8),
        _jogBtn('X+', AppColors.axisX, () => jogN.jogLinear('X', 1)),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _jogBtn('Y-', AppColors.axisY, () => jogN.jogLinear('Y', -1)),
      ]),
    ]);
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5));

  Widget _stepChip(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: selected ? color : AppColors.surfaceBorder, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : AppColors.textDisabled,
                fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
      ),
    );
  }

  Widget _jogBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
        ),
      ),
    );
  }
}

// ── Homing séquencé Trunnion ─────────────────────────────────────────────────
class _HomingSequencePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jogN = ref.read(jogProvider.notifier);
    return GlassPanel(
      title: 'HOMING TRUNNION',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Séquence recommandée : Z → X → Y → A → C',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 9, height: 1.5)),
        const SizedBox(height: 16),
        for (final e in [
          ('HOME Z', 'Dégager broche', AppColors.axisZ, () => jogN.homeAxis('Z')),
          ('HOME X', 'Axe horizontal', AppColors.axisX, () => jogN.homeAxis('X')),
          ('HOME Y', 'Axe frontal', AppColors.axisY, () => jogN.homeAxis('Y')),
          ('HOME A', 'Basculement', AppColors.axisA, () => jogN.homeAxis('A')),
          ('HOME C', 'Rotation plateau', AppColors.axisC, () => jogN.homeAxis('C')),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity, height: 38,
              child: OutlinedButton(
                onPressed: e.$4,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: e.$3.withValues(alpha: 0.5)),
                  foregroundColor: e.$3,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(children: [
                  Text(e.$1, style: TextStyle(color: e.$3, fontWeight: FontWeight.w900, fontSize: 11, fontFamily: 'JetBrains Mono')),
                  const SizedBox(width: 12),
                  Text(e.$2, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9)),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity, height: 44,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.home, size: 16),
            label: const Text('HOME ALL (\$H)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.axisZ, foregroundColor: Colors.white),
            onPressed: () => jogN.homeAll(),
          ),
        ),
      ]),
    );
  }
}

// ── Z-Probe Tab ───────────────────────────────────────────────────────────────
class _ZProbeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        title: 'Z-Probe Configuration',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in [
            ('PROBE FEED', '50 mm/min'),
            ('MAX DEPTH', '-50.000 mm'),
            ('RETRACT', '2.000 mm'),
            ('TOOL OFFSET', 'G43 H3'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Text(e.$1, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
              ]),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: () => ref.read(machineRepositoryProvider).sendGCode('G38.2 Z-50 F50'),
              icon: const Icon(Icons.sensors),
              label: const Text('LANCER Z-PROBE', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Alignement A/C Tab ────────────────────────────────────────────────────────
class _AlignementTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final aPos = state?.wPos[3] ?? 0.0;
    final cPos = state?.wPos[4] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        title: 'Alignement Axes Rotatifs',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in [
            ('AXE A (Tilt broche)', '${aPos.toStringAsFixed(3)}°', AppColors.axisA),
            ('AXE C (Rotation plateau)', '${cPos.toStringAsFixed(3)}°', AppColors.axisC),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Text(e.$1, style: TextStyle(color: e.$3, fontSize: 11, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900)),
              ]),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.rotate_right),
              label: const Text('CALIBRER A/C', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}
