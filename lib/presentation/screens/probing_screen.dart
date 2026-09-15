import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../widgets/wcs_offset_dialog.dart';
import '../../application/providers/jog_provider.dart';
import '../../application/providers/probing_provider.dart';
import '../../core/widgets/split_view.dart';
import '../widgets/calibration_wizard.dart';
import '../widgets/trunnion_visualizer.dart';
import '../../application/providers/gcode_provider.dart';
import '../../core/widgets/responsive_layout.dart';
import '../tutorial/tutorial_keys.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/ui_state_provider.dart';
import '../widgets/dashboard/mode_selector_widget.dart';
import '../../core/i18n/app_localizations.dart';

class ProbingScreen extends ConsumerStatefulWidget {
  const ProbingScreen({super.key});
  @override
  ConsumerState<ProbingScreen> createState() => _ProbingScreenState();
}

class _ProbingScreenState extends ConsumerState<ProbingScreen>
    with SingleTickerProviderStateMixin {
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

  static const _wcsLabels = ['G54', 'G55', 'G56', 'G57', 'G58', 'G59'];
  static const _emptyOffset = [0.0, 0.0, 0.0, 0.0, 0.0];
  static const _axisLabels = ['X', 'Y', 'Z', 'A', 'C'];
  List<Color> get _axisColors => [
    context.fc.axisX, context.fc.axisY, context.fc.axisZ,
    context.fc.axisA, context.fc.axisC
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineStateProvider);
    final wPos = state.valueOrNull?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final mPos = ref.watch(renderMPosProvider);
    final gcodeState = ref.watch(gcodeProvider);
    final showVectors = ref.watch(showVectorsProvider);

    final leftColumn = SingleChildScrollView(
      key: TutorialKeys.wcsCards,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ModeSelectorWidget(),
        SizedBox(height: 24),
        Text(tr('SYSTÈMES DE COORDONNÉES (WCS)'),
            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        SizedBox(height: 12),
        for (final label in _wcsLabels)
          _wcsCard(
            label,
            state.valueOrNull?.wcsOffsets[label] ?? _emptyOffset,
            state.valueOrNull?.activeWCS ?? 'G54',
          ),
        SizedBox(height: 24),
        Text(tr('DRO EN DIRECT'),
            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        SizedBox(height: 12),
        for (int i = 0; i < 5; i++)
          _liveDroRow(_axisLabels[i], wPos[i], _axisColors[i],
              i >= 3 ? '°' : 'mm'),
        SizedBox(height: 16),
        Container(
          key: TutorialKeys.probingOffsets,
          child: Column(children: [
            SizedBox(
              width: double.infinity, height: 40,
              child: OutlinedButton(
                onPressed: () => ref.read(machineRepositoryProvider).sendGCode('G0 X0 Y0 Z0 A0 C0'),
                style: OutlinedButton.styleFrom(side: BorderSide(color: context.fc.textDisabled)),
                child: Text(tr('ALLER AU ZÉRO'), style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 40,
              child: OutlinedButton(
                onPressed: () => ref.read(secureJogProvider.notifier).homeAll(),
                style: OutlinedButton.styleFrom(side: BorderSide(color: context.fc.axisZ)),
                child: Text(tr('ORIGINES (TOUS)'), style: TextStyle(color: context.fc.axisZ, fontSize: 10, fontWeight: FontWeight.w900)),
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
        border: Border.all(color: context.fc.surfaceBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TrunnionVisualizer(
          mPos: mPos,
          targetPos: state.valueOrNull?.targetPos,
          toolpath: ref.watch(renderToolpathProvider),
          activeIndex: gcodeState
              .resolveToolpathIndex(state.valueOrNull?.activeLineIndex ?? 0),
          showVectors: showVectors,
        ),
      ),
    );

    final tabsAndControls = Column(children: [
      Container(
        margin: const EdgeInsets.only(top: 16, right: 16),
        decoration: BoxDecoration(
            color: context.fc.surface,
            border: Border(bottom: BorderSide(color: context.fc.surfaceBorder))),
        child: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: Colors.deepOrange,
          labelColor: Colors.deepOrange,
          unselectedLabelColor: context.fc.textDisabled,
          tabs: [
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

  Widget _wcsCard(String label, List<double> offset, String activeWcs) {
    final sel = label == activeWcs;
    return InkWell(
      onTap: () {
        ref.read(machineRepositoryProvider).sendGCode(label);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('WCS actif défini sur {}', [label])),
          backgroundColor: Colors.deepOrange,
          duration: const Duration(seconds: 2),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.fc.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: sel ? Colors.deepOrange : context.fc.surfaceBorder, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? Colors.deepOrange.withValues(alpha: 0.15) : context.fc.surfaceBright,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(color: sel ? Colors.deepOrange : Colors.grey, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'JetBrains Mono')),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (int j = 0; j < 5; j++)
                Text('${_axisLabels[j]}:${offset[j].toStringAsFixed(2)}',
                    style: TextStyle(color: _axisColors[j], fontSize: 9, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
            ]),
          ),
          // Saisie du décalage au clavier (G10 L2), en complément du « zéro
          // ici » (G10 L20) : quand la cote du montage est connue, l'écrire
          // vaut mieux que d'aller chercher le point au jog. Le bouton est sur
          // la ligne du WCS visé — aucune ambiguïté sur la cible.
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: context.fc.textDisabled, size: 16),
            tooltip: tr('Saisir le décalage de {}', [label]),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => WcsOffsetDialog(
                wcs: label,
                current: offset,
                axisLabels: _axisLabels,
                axisColors: _axisColors,
              ),
            ),
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
        color: context.fc.surface,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Text(axis, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
        SizedBox(width: 6),
        Text(unit, style: TextStyle(color: context.fc.textDisabled, fontSize: 9)),
        SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(val.toStringAsFixed(axis == 'A' || axis == 'C' ? 2 : 3),
                style: TextStyle(color: context.fc.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
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
    final jogN = ref.read(secureJogProvider.notifier);
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final wPos = machineState?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Design unifié avec le panneau JOG CONTROL du Dashboard.
        JogControlPanel(wPos: wPos),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            icon: Icon(Icons.stop, size: 20),
            label: Text(tr('JOG STOP  (0x85)'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: context.fc.danger, foregroundColor: Colors.white),
            onPressed: () => jogN.stopJog(),
          ),
        ),
      ]),
    );
  }
}

class _HomingSequencePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jogN = ref.read(secureJogProvider.notifier);
    return GlassPanel(
      title: tr('HOMING TRUNNION'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Séquence recommandée : Z → X → Y → A → C'), style: TextStyle(color: context.fc.textDisabled, fontSize: 9, height: 1.5)),
        SizedBox(height: 16),
        for (final e in [
          ('HOME Z', 'Dégager broche', context.fc.axisZ, () => jogN.homeAxis('Z')),
          ('HOME X', 'Axe horizontal', context.fc.axisX, () => jogN.homeAxis('X')),
          ('HOME Y', 'Axe frontal', context.fc.axisY, () => jogN.homeAxis('Y')),
          ('HOME A', 'Basculement', context.fc.axisA, () => jogN.homeAxis('A')),
          ('HOME C', 'Rotation plateau', context.fc.axisC, () => jogN.homeAxis('C')),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity, height: 38,
              child: OutlinedButton(
                onPressed: e.$4,
                style: OutlinedButton.styleFrom(side: BorderSide(color: e.$3.withValues(alpha: 0.5)), foregroundColor: e.$3, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: Row(children: [Text(e.$1, style: TextStyle(color: e.$3, fontWeight: FontWeight.w900, fontSize: 11, fontFamily: 'JetBrains Mono')), SizedBox(width: 12), Text(e.$2, style: TextStyle(color: context.fc.textDisabled, fontSize: 9))]),
              ),
            ),
          ),
        SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(icon: Icon(Icons.home, size: 16), label: Text(tr('HOME ALL (\$H)'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: context.fc.axisZ, foregroundColor: Colors.white), onPressed: () => jogN.homeAll())),
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
          title: tr('ASSISTANT PALPAGE INDUSTRIEL'),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: probing.step == ProbingStep.error ? context.fc.danger.withValues(alpha: 0.1) : Colors.deepOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: probing.step == ProbingStep.error ? context.fc.danger : Colors.deepOrange, width: 0.5),
              ),
              child: Row(children: [
                Icon(probing.step == ProbingStep.error ? Icons.error : Icons.info, 
                     color: probing.step == ProbingStep.error ? context.fc.danger : Colors.deepOrange, size: 16),
                SizedBox(width: 10),
                Expanded(child: Text(probing.statusMessage, 
                  style: TextStyle(color: probing.step == ProbingStep.error ? context.fc.danger : context.fc.textPrimary, 
                  fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
            ),
            if (probing.step != ProbingStep.idle && probing.step != ProbingStep.finished)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(color: Colors.deepOrange, backgroundColor: context.fc.surfaceBright),
              ),
          ]),
        ),
        SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _routineCard(
              context,
              'HAUTEUR Z', 
              'Palpage simple G38.2 sur l\'axe Z.', 
              Icons.vertical_align_bottom,
              probing.step == ProbingStep.idle ? () => probingN.startToolZRoutine() : null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _routineCard(
              context,
              'CENTRE TROU', 
              'Routine 4 points pour trouver le centre.', 
              Icons.adjust,
              probing.step == ProbingStep.idle ? () => probingN.startHoleCenterRoutine(20.0, -5.0) : null,
            ),
          ),
        ]),
        SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _routineCard(
              context,
              'ANGLE X', 
              'Détecte l\'inclinaison de la pièce en X.', 
              Icons.architecture,
              probing.step == ProbingStep.idle ? () => probingN.startAngleRoutine('X', 50.0) : null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _routineCard(
              context,
              'ANGLE Y', 
              'Détecte l\'inclinaison de la pièce en Y.', 
              Icons.architecture,
              probing.step == ProbingStep.idle ? () => probingN.startAngleRoutine('Y', 50.0) : null,
            ),
          ),
        ]),
        if (probing.hasPendingZero) ...[
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: () => _confirmZero(context, ref),
              icon: Icon(Icons.my_location),
              label: Text(tr('ZÉRER LE WCS ICI'), style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
        ],
        SizedBox(height: 20),
        if (probing.step != ProbingStep.idle)
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.fc.danger, foregroundColor: Colors.white),
              onPressed: () => probingN.cancel(),
              child: Text(tr('ANNULER LE PALPAGE'), style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
      ]),
    );
  }

  void _confirmZero(BuildContext context, WidgetRef ref) {
    final activeWcs = ref.read(machineStateProvider).valueOrNull?.activeWCS ?? 'G54';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        title: Text(tr('Zérer {} ici ?', [activeWcs]), style: TextStyle(color: Colors.white)),
        content: Text(
          tr('La machine va se déplacer au point calculé par le palpage, puis redéfinir l\'origine du système de coordonnées {} à cette position (G10 L20). Cette action modifie l\'origine pièce active.', [activeWcs]),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Annuler')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () {
              ref.read(probingProvider.notifier).confirmZeroWcs(activeWcs);
              Navigator.pop(ctx);
            },
            child: Text(tr('Confirmer le zérotage')),
          ),
        ],
      ),
    );
  }

  Widget _routineCard(BuildContext context, String title, String desc, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: GlassPanel(
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Column(children: [
            Icon(icon, color: Colors.deepOrange, size: 32),
            SizedBox(height: 12),
            Text(title, style: TextStyle(color: context.fc.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
            SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: TextStyle(color: context.fc.textDisabled, fontSize: 10, height: 1.4)),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(4)),
              child: Text(tr('LANCER'), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
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
          title: tr('ASSISTANT DE CALIBRATION'),
          titleTrailing: IconButton(icon: Icon(Icons.close, size: 14), onPressed: () => setState(() => _showWizard = false)),
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
        title: tr('Alignement des axes rotatifs'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in [('AXE A (Tilt broche)', '${aPos.toStringAsFixed(3)}°', context.fc.axisA), ('AXE C (Rotation plateau)', '${cPos.toStringAsFixed(3)}°', context.fc.axisC)])
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Text(e.$1, style: TextStyle(color: e.$3, fontSize: 11, fontWeight: FontWeight.w900)), const Spacer(), Text(e.$2, style: TextStyle(color: context.fc.textPrimary, fontSize: 18, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900))])),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: () => setState(() => _showWizard = true), icon: Icon(Icons.rotate_right), label: Text(tr('LANCER L\'ASSISTANT DE CALIBRATION'), style: TextStyle(fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
  }
}
