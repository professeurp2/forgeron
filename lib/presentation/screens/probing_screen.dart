import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../widgets/dashboard/cnc_panel_widgets.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../domain/models/jog_command.dart';
import '../../application/providers/probing_provider.dart';
import '../../core/widgets/split_view.dart';
import '../widgets/calibration_wizard.dart';
import '../widgets/trunnion_visualizer.dart';
import '../../application/providers/gcode_provider.dart';
import '../screens/dashboard_screen.dart' show showVectorsProvider;
import '../../core/widgets/responsive_layout.dart';
import '../tutorial/tutorial_keys.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/ui_state_provider.dart';
import '../widgets/dashboard/mode_selector_widget.dart';

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
    _tabCtrl = TabController(length: 4, vsync: this);
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
    final mPos = state.valueOrNull?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final gcodeState = ref.watch(gcodeProvider);
    final showVectors = ref.watch(showVectorsProvider);

    final leftColumn = SingleChildScrollView(
      key: TutorialKeys.wcsCards,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ModeSelectorWidget(),
        const SizedBox(height: 24),
        const Text('SYSTÈMES DE COORDONNÉES (WCS)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        for (int i = 0; i < _wcsData.length; i++) _wcsCard(i, state.valueOrNull?.activeWCS ?? 'G54'),
        const SizedBox(height: 24),
        const Text('DRO EN DIRECT',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        for (int i = 0; i < 5; i++)
          _liveDroRow(_axisLabels[i], wPos[i], _axisColors[i],
              i >= 3 ? '°' : 'mm'),
        const SizedBox(height: 16),
        Container(
          key: TutorialKeys.probingOffsets,
          child: Column(children: [
            SizedBox(
              width: double.infinity, height: 40,
              child: OutlinedButton(
                onPressed: () => ref.read(machineRepositoryProvider).sendGCode('G0 X0 Y0 Z0 A0 C0'),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.textDisabled)),
                child: const Text('ALLER AU ZÉRO', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 40,
              child: OutlinedButton(
                onPressed: () => ref.read(secureJogProvider.notifier).homeAll(),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.axisZ)),
                child: const Text('ORIGINES (TOUS)', style: TextStyle(color: AppColors.axisZ, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ]),
    );

    final visualizer = Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TrunnionVisualizer(
          mPos: mPos,
          targetPos: state.valueOrNull?.targetPos,
          toolpath: gcodeState.toolpath,
          activeIndex: state.valueOrNull?.activeLineIndex ?? 0,
          showVectors: showVectors,
        ),
      ),
    );

    final tabsAndControls = Column(children: [
      Container(
        margin: const EdgeInsets.only(top: 16, right: 16),
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
            Tab(icon: Icon(Icons.center_focus_strong, size: 16), text: 'JOG'),
            Tab(icon: Icon(Icons.vertical_align_bottom, size: 16), text: 'PALPAGE'),
            Tab(icon: Icon(Icons.rotate_right, size: 16), text: 'ALIGNER'),
            Tab(icon: Icon(Icons.home, size: 16), text: 'HOMING'),
          ],
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _JogPanel5Axes(), 
              _ProbingWizardTab(), 
              _AlignementTab(),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _HomingSequencePanel(),
              ),
            ],
          ),
        ),
      ),
    ]);

    return ResponsiveLayout(
      mobile: Column(
        children: [
          Expanded(flex: 1, child: leftColumn),
          Expanded(flex: 2, child: tabsAndControls),
        ],
      ),
      tablet: ResizableSplitView(
        initialRatio: 0.22,
        left: leftColumn,
        right: ResizableSplitView(
          initialRatio: 0.55,
          left: visualizer,
          right: tabsAndControls,
        ),
      ),
      desktop: ResizableSplitView(
        initialRatio: 0.22,
        left: leftColumn,
        right: ResizableSplitView(
          initialRatio: 0.55,
          left: visualizer,
          right: tabsAndControls,
        ),
      ),
    );
  }

  Widget _wcsCard(int i, String activeWcs) {
    final d = _wcsData[i];
    final sel = d.$1 == activeWcs;
    return InkWell(
      onTap: () {
        ref.read(machineRepositoryProvider).sendGCode(d.$1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('WCS actif défini sur ${d.$1}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ));
      },
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
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(val.toStringAsFixed(axis == 'A' || axis == 'C' ? 2 : 3),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
          ),
        ),
      ]),
    );
  }
}

class _JogPanel5Axes extends ConsumerStatefulWidget {
  @override
  ConsumerState<_JogPanel5Axes> createState() => _JogPanel5AxesState();
}

class _JogPanel5AxesState extends ConsumerState<_JogPanel5Axes> {
  @override
  Widget build(BuildContext context) {
    final jog = ref.watch(secureJogProvider);
    final jogN = ref.read(secureJogProvider.notifier);
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final wPos = machineState?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('PAS LINÉAIRE (mm)'),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final s in LinearJogStep.steps)
            _stepChip(s.toString(), s == jog.linearStep, AppColors.axisX, () => jogN.setLinearStep(s)),
        ]),
        const SizedBox(height: 12),
        _sectionTitle('PAS ROTATIF (°)'),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final s in RotaryJogStep.steps)
            _stepChip('$s°', s == jog.rotaryStep, AppColors.axisA, () => jogN.setRotaryStep(s)),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('AXES LINÉAIRES'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _linearGroup()),
          const SizedBox(width: 16),
          Column(children: [
            _jogBtn('Z+', AppColors.axisZ, () => jogN.jogLinear('Z', 1)),
            const SizedBox(height: 8),
            _jogBtn('Z-', AppColors.axisZ, () => jogN.jogLinear('Z', -1)),
          ]),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('AXES ROTATIFS — TRUNNION'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: CncJogDial(
              axis: 'A',
              label: 'TILT (BERCEAU)',
              color: AppColors.axisA,
              currentValue: wPos[3],
              multiplier: (jog.rotaryStep * 10).round(),
              onJog: (step) {
                ref.read(machineRepositoryProvider).jog('A', step, 3600);
              },
              size: 80,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CncJogDial(
              axis: 'C',
              label: 'PLATEAU ROTATIF',
              color: AppColors.axisC,
              currentValue: wPos[4],
              multiplier: (jog.rotaryStep * 10).round(),
              onJog: (step) {
                ref.read(machineRepositoryProvider).jog('C', step, 3600);
              },
              size: 80,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.stop, size: 20),
            label: const Text('JOG STOP  (0x85)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => jogN.stopJog(),
          ),
        ),
      ]),
    );
  }

  Widget _linearGroup() {
    final jogN = ref.read(secureJogProvider.notifier);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [_jogBtn('Y+', AppColors.axisY, () => jogN.jogLinear('Y', 1))]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _jogBtn('X-', AppColors.axisX, () => jogN.jogLinear('X', -1)),
        const SizedBox(width: 8),
        Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceBright, border: Border.all(color: AppColors.surfaceBorder)), child: const Center(child: Icon(Icons.add, size: 12, color: AppColors.textDisabled))),
        const SizedBox(width: 8),
        _jogBtn('X+', AppColors.axisX, () => jogN.jogLinear('X', 1)),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [_jogBtn('Y-', AppColors.axisY, () => jogN.jogLinear('Y', -1))]),
    ]);
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5));
  Widget _stepChip(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: selected ? color.withValues(alpha: 0.18) : AppColors.surface, borderRadius: BorderRadius.circular(3), border: Border.all(color: selected ? color : AppColors.surfaceBorder, width: selected ? 1.5 : 1)), child: Text(label, style: TextStyle(color: selected ? color : AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono'))));
  }
  Widget _jogBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(width: 56, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.4))), child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')))));
  }
}

class _HomingSequencePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jogN = ref.read(secureJogProvider.notifier);
    return GlassPanel(
      title: 'HOMING TRUNNION',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Séquence recommandée : Z → X → Y → A → C', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, height: 1.5)),
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
                style: OutlinedButton.styleFrom(side: BorderSide(color: e.$3.withValues(alpha: 0.5)), foregroundColor: e.$3, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: Row(children: [Text(e.$1, style: TextStyle(color: e.$3, fontWeight: FontWeight.w900, fontSize: 11, fontFamily: 'JetBrains Mono')), const SizedBox(width: 12), Text(e.$2, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9))]),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(icon: const Icon(Icons.home, size: 16), label: const Text('HOME ALL (\$H)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.axisZ, foregroundColor: Colors.white), onPressed: () => jogN.homeAll())),
      ]),
    );
  }
}

class _ProbingWizardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probing = ref.watch(probingProvider);
    final probingN = ref.read(probingProvider.notifier);

    return SingleChildScrollView(
      key: TutorialKeys.probingTools,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        GlassPanel(
          title: 'ASSISTANT PALPAGE INDUSTRIEL',
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: probing.step == ProbingStep.error ? AppColors.danger.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: probing.step == ProbingStep.error ? AppColors.danger : AppColors.primary, width: 0.5),
              ),
              child: Row(children: [
                Icon(probing.step == ProbingStep.error ? Icons.error : Icons.info, 
                     color: probing.step == ProbingStep.error ? AppColors.danger : AppColors.primary, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(probing.statusMessage, 
                  style: TextStyle(color: probing.step == ProbingStep.error ? AppColors.danger : AppColors.textPrimary, 
                  fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
            ),
            if (probing.step != ProbingStep.idle && probing.step != ProbingStep.finished)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.surfaceBright),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _routineCard(
              'HAUTEUR Z', 
              'Palpage simple G38.2 sur l\'axe Z.', 
              Icons.vertical_align_bottom,
              probing.step == ProbingStep.idle ? () => probingN.startToolZRoutine() : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _routineCard(
              'CENTRE TROU', 
              'Routine 4 points pour trouver le centre.', 
              Icons.adjust,
              probing.step == ProbingStep.idle ? () => probingN.startHoleCenterRoutine(20.0, -5.0) : null,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _routineCard(
              'ANGLE X', 
              'Détecte l\'inclinaison de la pièce en X.', 
              Icons.architecture,
              probing.step == ProbingStep.idle ? () => probingN.startAngleRoutine('X', 50.0) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _routineCard(
              'ANGLE Y', 
              'Détecte l\'inclinaison de la pièce en Y.', 
              Icons.architecture,
              probing.step == ProbingStep.idle ? () => probingN.startAngleRoutine('Y', 50.0) : null,
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (probing.step != ProbingStep.idle)
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () => probingN.cancel(),
              child: const Text('ANNULER LE PALPAGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
      ]),
    );
  }

  Widget _routineCard(String title, String desc, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: GlassPanel(
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Column(children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, height: 1.4)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
              child: const Text('LANCER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AlignementTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AlignementTab> createState() => _AlignementTabState();
}

class _AlignementTabState extends ConsumerState<_AlignementTab> {
  bool _showWizard = false;

  @override
  Widget build(BuildContext context) {
    if (_showWizard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          title: 'ASSISTANT DE CALIBRATION',
          titleTrailing: IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setState(() => _showWizard = false)),
          child: const CalibrationWizard(),
        ),
      );
    }

    final state = ref.watch(machineStateProvider).valueOrNull;
    final aPos = state?.wPos[3] ?? 0.0;
    final cPos = state?.wPos[4] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        title: 'Alignement des axes rotatifs',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in [('AXE A (Tilt broche)', '${aPos.toStringAsFixed(3)}°', AppColors.axisA), ('AXE C (Rotation plateau)', '${cPos.toStringAsFixed(3)}°', AppColors.axisC)])
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Text(e.$1, style: TextStyle(color: e.$3, fontSize: 11, fontWeight: FontWeight.w900)), const Spacer(), Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900))])),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: () => setState(() => _showWizard = true), icon: const Icon(Icons.rotate_right), label: const Text('LANCER L\'ASSISTANT DE CALIBRATION', style: TextStyle(fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
  }
}
