import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../domain/models/jog_command.dart';
import '../../application/providers/probing_provider.dart';
import '../../application/providers/config_provider.dart';
import '../../application/services/logger_service.dart';
import '../tutorial/tutorial_keys.dart';
import '../widgets/dashboard/mode_selector_widget.dart';
import '../../application/providers/di_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 2 — PALPAGE & ORIGINES  (Mobile)
// ═══════════════════════════════════════════════════════════════════════════════

class MobileProbingScreen extends ConsumerStatefulWidget {
  const MobileProbingScreen({super.key});
  @override
  ConsumerState<MobileProbingScreen> createState() =>
      _MobileProbingScreenState();
}

class _MobileProbingScreenState extends ConsumerState<MobileProbingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _wcsData = [
    ('G54', [120.500, -45.200, 0.000, 0.000, 90.000]),
    ('G55', [0.000, 0.000, 0.000, 0.000, 0.000]),
    ('G56', [250.000, 100.000, 0.000, 45.000, 180.000]),
  ];
  static const _axisLabels = ['X', 'Y', 'Z', 'A', 'C'];
  static const _axisColors = [
    AppColors.axisX, AppColors.axisY, AppColors.axisZ,
    AppColors.axisA, AppColors.axisC,
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineStateProvider);
    final wPos = state.valueOrNull?.wPos ?? List.filled(5, 0.0);
    final activeWCS = state.valueOrNull?.activeWCS ?? 'G54';

    return Column(
      children: [
        // ── Tab bar ────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tab,
            isScrollable: false,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textDisabled,
            labelStyle: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            tabs: const [
              Tab(icon: Icon(Icons.grid_on, size: 18), text: 'WCS'),
              Tab(icon: Icon(Icons.center_focus_strong, size: 18), text: 'JOG'),
              Tab(icon: Icon(Icons.vertical_align_bottom, size: 18), text: 'PALPAGE'),
              Tab(icon: Icon(Icons.home, size: 18), text: 'HOMING'),
            ],
          ),
        ),

        // ── Content ────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _WCSTab(
                  wcsData: _wcsData,
                  wPos: wPos,
                  activeWCS: activeWCS,
                  axisLabels: _axisLabels,
                  axisColors: _axisColors),
              const _MobileJogTab(),
              const _MobileProbingTab(),
              const _MobileHomingTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── WCS Tab ────────────────────────────────────────────────────────────────
class _WCSTab extends ConsumerWidget {
  final List<(String, List<double>)> wcsData;
  final List<double> wPos;
  final String activeWCS;
  final List<String> axisLabels;
  final List<Color> axisColors;

  const _WCSTab({
    required this.wcsData,
    required this.wPos,
    required this.activeWCS,
    required this.axisLabels,
    required this.axisColors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ModeSelectorWidget(),
        const SizedBox(height: 20),

        const _MLabel('SYSTÈMES DE COORDONNÉES (WCS)'),
        const SizedBox(height: 8),
        ...wcsData.map((d) {
          final sel = d.$1 == activeWCS;
          return GestureDetector(
            onTap: () {
              ref.read(machineRepositoryProvider).sendGCode(d.$1);
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('WCS actif: ${d.$1}'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 1),
              ));
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sel ? AppColors.primary : AppColors.surfaceBorder,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(d.$1,
                      style: TextStyle(
                          color: sel ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          fontFamily: 'JetBrains Mono')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (int j = 0; j < 5; j++)
                        Text(
                          '${axisLabels[j]}:${d.$2[j].toStringAsFixed(2)}',
                          style: TextStyle(
                              color: axisColors[j],
                              fontSize: 10,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                if (sel)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 16),
              ]),
            ),
          );
        }),

        const SizedBox(height: 20),
        const _MLabel('DRO EN DIRECT'),
        const SizedBox(height: 8),
        ...List.generate(5, (i) {
          final isRotary = i >= 3;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  left: BorderSide(color: axisColors[i], width: 3)),
            ),
            child: Row(children: [
              Text(axisLabels[i],
                  style: TextStyle(
                      color: axisColors[i],
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
              const SizedBox(width: 4),
              Text(isRotary ? '°' : 'mm',
                  style: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wPos[i].toStringAsFixed(isRotary ? 2 : 3),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono'),
                ),
              ),
            ]),
          );
        }),

        const SizedBox(height: 16),
        _MActionButton(
          'ALLER AU ZÉRO',
          AppColors.textSecondary,
          Icons.gps_fixed,
          () => ref.read(machineRepositoryProvider).sendGCode('G0 X0 Y0 Z0 A0 C0'),
        ),
        const SizedBox(height: 8),
        _MActionButton(
          'ORIGINES (TOUS)',
          AppColors.axisZ,
          Icons.home,
          () => ref.read(secureJogProvider.notifier).homeAll(),
        ),
      ]),
    );
  }
}

// ── Jog Tab ────────────────────────────────────────────────────────────────
class _MobileJogTab extends ConsumerStatefulWidget {
  const _MobileJogTab();
  @override
  ConsumerState<_MobileJogTab> createState() => _MobileJogTabState();
}

class _MobileJogTabState extends ConsumerState<_MobileJogTab> {
  @override
  Widget build(BuildContext context) {
    final jog = ref.watch(secureJogProvider);
    final jogN = ref.read(secureJogProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Pas linéaire ───────────────────────────────────────────
        const _MLabel('PAS LINÉAIRE (mm)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: LinearJogStep.steps
              .map((s) => _StepChip(
                  s.toString(), s == jog.linearStep, AppColors.axisX,
                  () => jogN.setLinearStep(s)))
              .toList(),
        ),
        const SizedBox(height: 16),

        // ── Pas rotatif ────────────────────────────────────────────
        const _MLabel('PAS ROTATIF (°)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: RotaryJogStep.steps
              .map((s) => _StepChip(
                  '$s°', s == jog.rotaryStep, AppColors.axisA,
                  () => jogN.setRotaryStep(s)))
              .toList(),
        ),
        const SizedBox(height: 20),

        // ── Croix directionnelle XY + Z ───────────────────────────
        const _MLabel('AXES LINÉAIRES X / Y / Z'),
        const SizedBox(height: 12),
        Row(
          children: [
            // Croix XY
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _JogBtn('Y+', AppColors.axisY,
                        () { jogN.jogLinear('Y', 1); HapticFeedback.lightImpact(); }),
                  ]),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _JogBtn('X-', AppColors.axisX,
                          () { jogN.jogLinear('X', -1); HapticFeedback.lightImpact(); }),
                      const SizedBox(width: 8),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceBright,
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: const Center(child: Icon(Icons.add, size: 14, color: AppColors.textDisabled)),
                      ),
                      const SizedBox(width: 8),
                      _JogBtn('X+', AppColors.axisX,
                          () { jogN.jogLinear('X', 1); HapticFeedback.lightImpact(); }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _JogBtn('Y-', AppColors.axisY,
                        () { jogN.jogLinear('Y', -1); HapticFeedback.lightImpact(); }),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Axe Z
            Column(
              children: [
                _JogBtn('Z+', AppColors.axisZ,
                    () { jogN.jogLinear('Z', 1); HapticFeedback.lightImpact(); }),
                const SizedBox(height: 10),
                const Text('Z', style: TextStyle(color: AppColors.axisZ, fontSize: 11, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _JogBtn('Z-', AppColors.axisZ,
                    () { jogN.jogLinear('Z', -1); HapticFeedback.lightImpact(); }),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),
        const _MLabel('AXES ROTATIFS — TRUNNION'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RotaryCard('A', 'TILT', AppColors.axisA, Icons.rotate_90_degrees_ccw,
                  () => jogN.jogRotary('A', -1), () => jogN.jogRotary('A', 1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RotaryCard('C', 'PLATEAU', AppColors.axisC, Icons.sync,
                  () => jogN.jogRotary('C', -1), () => jogN.jogRotary('C', 1)),
            ),
          ],
        ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.stop_rounded, size: 22),
            label: const Text('JOG STOP',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              jogN.stopJog();
              HapticFeedback.heavyImpact();
            },
          ),
        ),
      ]),
    );
  }
}

class _RotaryCard extends StatelessWidget {
  final String axis;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _RotaryCard(this.axis, this.label, this.color, this.icon,
      this.onMinus, this.onPlus);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text('$axis — $label',
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _JogBtn('$axis-', color, () { onMinus(); HapticFeedback.lightImpact(); }),
            _JogBtn('$axis+', color, () { onPlus(); HapticFeedback.lightImpact(); }),
          ],
        ),
      ]),
    );
  }
}

// ── Probing Tab ────────────────────────────────────────────────────────────
class _MobileProbingTab extends ConsumerWidget {
  const _MobileProbingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probing = ref.watch(probingProvider);
    final probingN = ref.read(probingProvider.notifier);

    return SingleChildScrollView(
      key: TutorialKeys.probingTools,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Statut
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: probing.step == ProbingStep.error
                ? AppColors.danger.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: probing.step == ProbingStep.error
                  ? AppColors.danger
                  : AppColors.primary,
              width: 0.5,
            ),
          ),
          child: Row(children: [
            Icon(
              probing.step == ProbingStep.error ? Icons.error : Icons.info,
              color: probing.step == ProbingStep.error
                  ? AppColors.danger
                  : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                probing.statusMessage,
                style: TextStyle(
                  color: probing.step == ProbingStep.error
                      ? AppColors.danger
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),
        if (probing.step != ProbingStep.idle && probing.step != ProbingStep.finished)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceBright),
          ),

        const SizedBox(height: 16),

        // Routines 2×2
        Row(children: [
          Expanded(child: _ProbingCard('HAUTEUR Z', 'G38.2 sur axe Z',
              Icons.vertical_align_bottom,
              probing.step == ProbingStep.idle ? () => probingN.startToolZRoutine() : null)),
          const SizedBox(width: 10),
          Expanded(child: _ProbingCard('CENTRE TROU', '4 points → centre',
              Icons.adjust,
              probing.step == ProbingStep.idle
                  ? () => probingN.startHoleCenterRoutine(20.0, -5.0) : null)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ProbingCard('ANGLE X', 'Inclinaison pièce X',
              Icons.architecture,
              probing.step == ProbingStep.idle
                  ? () => probingN.startAngleRoutine('X', 50.0) : null)),
          const SizedBox(width: 10),
          Expanded(child: _ProbingCard('ANGLE Y', 'Inclinaison pièce Y',
              Icons.architecture,
              probing.step == ProbingStep.idle
                  ? () => probingN.startAngleRoutine('Y', 50.0) : null)),
        ]),

        if (probing.step != ProbingStep.idle) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white),
              onPressed: () { probingN.cancel(); HapticFeedback.heavyImpact(); },
              child: const Text('ANNULER LE PALPAGE',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ProbingCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final VoidCallback? onTap;
  const _ProbingCard(this.title, this.desc, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null ? null : () {
        onTap!();
        HapticFeedback.mediumImpact();
      },
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
            const SizedBox(height: 4),
            Text(desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 9, height: 1.4)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('LANCER',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Homing Tab ─────────────────────────────────────────────────────────────
class _MobileHomingTab extends ConsumerWidget {
  const _MobileHomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jogN = ref.read(secureJogProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.axisZ.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.axisZ.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.axisZ, size: 14),
            SizedBox(width: 8),
            Expanded(
              child: Text('Séquence recommandée : Z → X → Y → A → C',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.5)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        for (final e in [
          ('HOME Z', 'Dégager broche', AppColors.axisZ, () => jogN.homeAxis('Z')),
          ('HOME X', 'Axe horizontal', AppColors.axisX, () => jogN.homeAxis('X')),
          ('HOME Y', 'Axe frontal', AppColors.axisY, () => jogN.homeAxis('Y')),
          ('HOME A', 'Basculement trunnion', AppColors.axisA, () => jogN.homeAxis('A')),
          ('HOME C', 'Rotation plateau', AppColors.axisC, () => jogN.homeAxis('C')),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MActionButton(e.$1, e.$3, Icons.home,
                () { e.$4(); HapticFeedback.mediumImpact(); },
                subtitle: e.$2),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.home_rounded, size: 20),
            label: const Text('HOME ALL (\$H)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.axisZ, foregroundColor: Colors.white),
            onPressed: () { jogN.homeAll(); HapticFeedback.heavyImpact(); },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 3 — MAGASIN D'OUTILS  (Mobile)
// ═══════════════════════════════════════════════════════════════════════════════

class MobileToolTableScreen extends ConsumerStatefulWidget {
  const MobileToolTableScreen({super.key});
  @override
  ConsumerState<MobileToolTableScreen> createState() =>
      _MobileToolTableScreenState();
}

class _MobileToolTableScreenState
    extends ConsumerState<MobileToolTableScreen> {
  int _selectedTool = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _tools = [
    ('T1', 'FORET CARBURE Ø12', 120.00, 12.00, AppColors.success, 'OK'),
    ('T2', 'FRAISE 2 TAILLES Ø20', 85.50, 20.00, AppColors.success, 'OK'),
    ('T3', 'FRAISE HÉMISP. Ø6', 65.02, 6.00, AppColors.success, 'OK'),
    ('T4', 'FORET CENTRE D3', 45.00, 3.00, AppColors.success, 'OK'),
    ('T5', 'TARAUDEUR M8', 70.00, 8.00, AppColors.warning, 'USURE: 85%'),
    ('T6', 'FRAISE EB Ø25', 90.00, 25.00, AppColors.success, 'OK'),
    ('T7', 'ALÉSOIR H7 Ø10', 110.00, 10.00, AppColors.success, 'OK'),
    ('T8', 'GRAVEUR V-BIT 60°', 30.00, 6.00, AppColors.success, 'OK'),
    ('T9', 'FRAISE EB Ø16', 75.00, 16.00, AppColors.error, 'BRIS DÉTECTÉ'),
    ('T10', 'FRAISE RAVAGEUSE Ø12', 80.00, 12.00, AppColors.success, 'OK'),
    ('T11', 'FRAISE TORIQUE R2 Ø8', 60.00, 8.00, AppColors.success, 'OK'),
    ('T12', 'PALPEUR 3D RENISHAW', 50.00, 4.00, AppColors.info, 'CALIBRÉ'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showDetail(int index, int activeToolNum, String activeWCS) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, ctrl) => _ToolDetailSheet(
          tool: _tools[index],
          scrollController: ctrl,
          activeToolNum: activeToolNum,
          ref: ref,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final activeToolNum = machineState?.activeToolNum ?? 0;
    final activeWCS = machineState?.activeWCS ?? 'G54';

    final filtered = _tools.asMap().entries.where((e) {
      if (_query.isEmpty) return true;
      return e.value.$1.toLowerCase().contains(_query.toLowerCase()) ||
          e.value.$2.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppColors.surface,
          child: Column(children: [
            Row(children: [
              const Text('MAGASIN',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0)),
              const Spacer(),
              if (activeToolNum > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.build, color: AppColors.success, size: 10),
                    const SizedBox(width: 4),
                    Text('ACTIF: T$activeToolNum',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono')),
                  ]),
                ),
              const SizedBox(width: 8),
              Text('${_tools.length}/24',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            // Barre de recherche
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher T# ou nom...',
                hintStyle: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 12),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textDisabled, size: 18),
                filled: true,
                fillColor: AppColors.surfaceBright,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ]),
        ),

        // Liste
        Expanded(
          key: TutorialKeys.toolTable,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final entry = filtered[i];
              final t = entry.value;
              final origIdx = entry.key;
              final toolNum =
                  int.tryParse(t.$1.replaceAll('T', '')) ?? -1;
              final isActive = toolNum == activeToolNum && activeToolNum > 0;

              return InkWell(
                onTap: () {
                  setState(() => _selectedTool = origIdx);
                  _showDetail(origIdx, activeToolNum, activeWCS);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withValues(alpha: 0.04)
                        : Colors.transparent,
                    border: Border(
                      bottom: const BorderSide(color: AppColors.surfaceBorder),
                      left: BorderSide(
                          color: isActive
                              ? AppColors.success
                              : Colors.transparent,
                          width: 3),
                    ),
                  ),
                  child: Row(children: [
                    // Badge T#
                    Container(
                      width: 44, height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.surfaceBright,
                        borderRadius: BorderRadius.circular(6),
                        border: isActive
                            ? Border.all(
                                color: AppColors.success, width: 1.5)
                            : null,
                      ),
                      child: Text(t.$1,
                          style: TextStyle(
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.$2,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                                'L:${t.$3.toStringAsFixed(2)}  D:${t.$4.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 9,
                                    fontFamily: 'JetBrains Mono')),
                          ]),
                    ),
                    // État
                    Column(children: [
                      Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.$5,
                              boxShadow: [BoxShadow(color: t.$5, blurRadius: 4)])),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textDisabled, size: 16),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToolDetailSheet extends ConsumerWidget {
  final (String, String, double, double, Color, String) tool;
  final ScrollController scrollController;
  final int activeToolNum;
  final WidgetRef ref;

  const _ToolDetailSheet({
    required this.tool,
    required this.scrollController,
    required this.activeToolNum,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final toolNum = int.tryParse(tool.$1.replaceAll('T', '')) ?? -1;
    final isActive = toolNum == activeToolNum && activeToolNum > 0;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Drag handle
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textDisabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Header outil
        Row(children: [
          Container(
            width: 56, height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: isActive ? Border.all(color: AppColors.success, width: 2) : null,
            ),
            child: Text(tool.$1,
                style: TextStyle(
                    color: isActive ? AppColors.success : AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    fontFamily: 'JetBrains Mono')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tool.$2,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tool.$5.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('● ${tool.$6}',
                      style: TextStyle(
                          color: tool.$5, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('▶ EN BROCHE',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
            ]),
          ),
        ]),

        const SizedBox(height: 20),

        // Actions
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.build, size: 14),
              label: Text('APPELER ${tool.$1}  (M6)'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                Navigator.pop(context);
                _callTool(context, toolNum);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.straighten, size: 14, color: AppColors.secondary),
              label: Text('G43 H$toolNum',
                  style: const TextStyle(color: AppColors.secondary)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.secondary),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                ref.read(machineRepositoryProvider).sendGCode('G43 H$toolNum');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✓ G43 H$toolNum appliqué'),
                  backgroundColor: AppColors.secondary,
                ));
              },
            ),
          ),
        ]),

        const SizedBox(height: 20),
        const _MLabel('PARAMÈTRES PHYSIQUES'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _MParamCard('LONGUEUR (L)', tool.$3.toStringAsFixed(3), 'mm')),
          const SizedBox(width: 10),
          Expanded(child: _MParamCard('DIAMÈTRE (D)', tool.$4.toStringAsFixed(3), 'mm')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _MParamCard('RAYON (R)', (tool.$4 / 2).toStringAsFixed(3), 'mm')),
          const SizedBox(width: 10),
          Expanded(child: _MParamCard('AVANCE (F)', '1200', 'mm/min')),
        ]),

        const SizedBox(height: 20),
        const _MLabel('DURÉE DE VIE'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBright,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            SizedBox(
              width: 80, height: 80,
              child: Stack(alignment: Alignment.center, children: [
                const CircularProgressIndicator(
                    value: 0.68,
                    strokeWidth: 6,
                    backgroundColor: AppColors.surface,
                    color: AppColors.success),
                const Text('68%',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final e in [
                  ('TEMPS TOTAL', '04h 22min'),
                  ('PIÈCES USINÉES', '47'),
                  ('VIE RESTANTE', '~02h 08min'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Text(e.$1,
                          style: const TextStyle(
                              color: AppColors.textDisabled,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text(e.$2,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  void _callTool(BuildContext context, int toolNum) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Appel outil T$toolNum',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.build, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text('Envoyer T$toolNum M6 ?',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('⚠ Changement d\'outil en cours.',
              style: TextStyle(color: AppColors.warning, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              ref.read(machineRepositoryProvider).sendGCode('T$toolNum M6');
              HapticFeedback.heavyImpact();
            },
            child: Text('APPELER T$toolNum',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _MParamCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MParamCard(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
        ),
        Text(unit,
            style: const TextStyle(
                color: AppColors.textDisabled, fontSize: 9)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 5 — TERMINAL MDI  (Mobile)
// ═══════════════════════════════════════════════════════════════════════════════

class MobileTerminalScreen extends ConsumerStatefulWidget {
  const MobileTerminalScreen({super.key});
  @override
  ConsumerState<MobileTerminalScreen> createState() =>
      _MobileTerminalScreenState();
}

class _MobileTerminalScreenState extends ConsumerState<MobileTerminalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _ctrl = TextEditingController();

  static const _logLines = [
    ('14:02:11', 'INFO', 'Système initialisé. Connecté à FluidNC v3.7.8', AppColors.secondary),
    ('14:02:12', '>>>', '\$H', AppColors.primary),
    ('14:02:15', 'ok', '', AppColors.success),
    ('14:03:01', '>>>', 'G90 G21', AppColors.primary),
    ('14:03:01', 'ok', '', AppColors.success),
    ('14:05:22', 'MSG', '[MSG: Vitesse broche atteinte]', AppColors.warning),
    ('14:06:10', '>>>', 'G0 X100 Y50 Z10', AppColors.primary),
    ('14:06:10', 'ok', '', AppColors.success),
    ('14:08:45', 'ERR', '[ERR: Limite logicielle Z min]', AppColors.error),
    ('14:09:00', '>>>', 'G0 Z50', AppColors.primary),
    ('14:09:00', 'ok', '', AppColors.success),
  ];

  static const _macros = [
    (Icons.home, 'ORIGINES', '\$H', AppColors.primary),
    (Icons.gps_fixed, 'ZÉRO PIÈCE', 'G0 X0 Y0 Z0', AppColors.primary),
    (Icons.sensors, 'PALPAGE Z', 'G38.2 Z-50 F100', AppColors.secondary),
    (Icons.rotate_right, 'BROCHE H', 'M3 S12000', AppColors.success),
    (Icons.stop_circle, 'ARRÊT B.', 'M5', AppColors.error),
    (Icons.water_drop, 'ARROSAGE', 'M8', AppColors.primary),
    (Icons.water_drop_outlined, 'ARROS. OFF', 'M9', AppColors.textDisabled),
    (Icons.air, 'SOUFFLAGE', 'M7', AppColors.secondary),
    (Icons.vertical_align_top, 'Z SÉCU', 'G0 Z50', AppColors.primary),
    (Icons.local_parking, 'PARKING', 'G0 X0 Y200 Z50', AppColors.textSecondary),
    (Icons.play_arrow, 'REPRENDRE', '~', AppColors.success),
    (Icons.pause, 'PAUSE', '!', AppColors.warning),
  ];

  static const _history = [
    ('G0 Z50', '14:09:00'),
    ('M5', '14:08:50'),
    ('G0 X100 Y50 Z10', '14:06:10'),
    ('M3 S12000', '14:05:20'),
    ('G90 G21', '14:03:01'),
    ('\$H', '14:02:12'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _send(String cmd) {
    if (cmd.trim().isEmpty) return;
    ref.read(machineRepositoryProvider).sendGCode(cmd.trim());
    _ctrl.clear();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tab,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textDisabled,
            labelStyle: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            tabs: const [
              Tab(icon: Icon(Icons.terminal, size: 18), text: 'TERMINAL'),
              Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'MACROS'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // ── Tab 1 : Terminal ──────────────────────────────────
              Column(children: [
                // Header terminal
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.surfaceBright,
                  child: Row(children: [
                    const Icon(Icons.terminal,
                        color: AppColors.textDisabled, size: 14),
                    const SizedBox(width: 8),
                    const Text('LOG MACHINE',
                        style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    const Text('BUFFER: 127/128',
                        style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 9,
                            fontFamily: 'JetBrains Mono')),
                  ]),
                ),
                // Log
                Expanded(
                  key: TutorialKeys.mdiHistory,
                  child: Container(
                    color: AppColors.terminalBg,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logLines.length,
                      itemBuilder: (ctx, i) {
                        final l = _logLines[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Text(l.$1,
                                style: const TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 10,
                                    fontFamily: 'JetBrains Mono')),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 32,
                              child: Text(l.$2,
                                  style: TextStyle(
                                      color: l.$4,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'JetBrains Mono')),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(l.$3,
                                  style: TextStyle(
                                      color: l.$2 == '>>>'
                                          ? AppColors.primary
                                          : l.$4,
                                      fontSize: 12,
                                      fontFamily: 'JetBrains Mono')),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                ),
                // Input
                Container(
                  key: TutorialKeys.mdiInput,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                          top: BorderSide(color: AppColors.surfaceBorder))),
                  child: Row(children: [
                    const Text('❯',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontFamily: 'JetBrains Mono'),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Saisir commande G-code...',
                          hintStyle: TextStyle(
                              color: AppColors.textDisabled),
                        ),
                        onSubmitted: _send,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _send(_ctrl.text),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 44)),
                      child: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ]),
                ),
              ]),

              // ── Tab 2 : Macros ────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _MLabel('MACROS RAPIDES'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: _macros.map((m) => InkWell(
                      onTap: () {
                        if (m.$2 == 'ORIGINES') {
                          ref.read(machineRepositoryProvider).home([]);
                        } else if (m.$2 == 'PAUSE') {
                          ref.read(machineRepositoryProvider).pause();
                        } else if (m.$2 == 'REPRENDRE') {
                          ref.read(machineRepositoryProvider).resume();
                        } else {
                          ref.read(machineRepositoryProvider).sendGCode(m.$3);
                        }
                        HapticFeedback.selectionClick();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: m.$4.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: m.$4.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Icon(m.$1, color: m.$4, size: 24),
                          const SizedBox(height: 6),
                          Text(m.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: m.$4,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  const _MLabel('HISTORIQUE'),
                  const SizedBox(height: 8),
                  for (final h in _history)
                    GestureDetector(
                      onTap: () {
                        _ctrl.text = h.$1;
                        _tab.animateTo(0);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceBright,
                            borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          const Icon(Icons.history,
                              color: AppColors.textDisabled, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(h.$1,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontFamily: 'JetBrains Mono')),
                          ),
                          Text(h.$2,
                              style: const TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 9,
                                  fontFamily: 'JetBrains Mono')),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 6 — DIAGNOSTICS  (Mobile)
// ═══════════════════════════════════════════════════════════════════════════════

class MobileDiagnosticsScreen extends ConsumerStatefulWidget {
  const MobileDiagnosticsScreen({super.key});
  @override
  ConsumerState<MobileDiagnosticsScreen> createState() =>
      _MobileDiagnosticsScreenState();
}

class _MobileDiagnosticsScreenState
    extends ConsumerState<MobileDiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _endstops = [
    ('X', 'GPIO 34', false, AppColors.axisX),
    ('Y', 'GPIO 35', false, AppColors.axisY),
    ('Z', 'GPIO 32', true, AppColors.axisZ),
    ('A', 'GPIO 33', false, AppColors.axisA),
    ('C', 'GPIO 25', false, AppColors.axisC),
  ];

  static const _axisParams = [
    ('X', AppColors.axisX, '160', '5000', '250', '600'),
    ('Y', AppColors.axisY, '160', '5000', '250', '800'),
    ('Z', AppColors.axisZ, '320', '2000', '150', '200'),
    ('A', AppColors.axisA, '88.8', '3600', '100', '120'),
    ('C', AppColors.axisC, '88.8', '7200', '150', '360'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limSw = ref.watch(machineStateProvider).valueOrNull?.limitSwitches ??
        [false, false, false, false, false];
    final configAsync = ref.watch(configProvider);
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final singularityRisk = machineState?.singularityRisk ?? 0.0;
    final temp = machineState?.coreTemp ?? 40.0;

    return Column(children: [
      Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textDisabled,
          labelStyle: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          tabs: const [
            Tab(icon: Icon(Icons.developer_board, size: 18), text: 'GPIO'),
            Tab(icon: Icon(Icons.code, size: 18), text: 'CONFIG'),
            Tab(icon: Icon(Icons.settings_applications, size: 18), text: 'PARAMS'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            // ── GPIO & Santé système ──────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _MLabel('FINS DE COURSE (LIVE)'),
                const SizedBox(height: 8),
                for (int i = 0; i < _endstops.length; i++)
                  _EndstopRow(_endstops[i].$1, _endstops[i].$2,
                      limSw[i], _endstops[i].$4),
                Row(children: [
                  Expanded(child: _SensorMini('PALPEUR', 'GPIO 36', false, AppColors.secondary)),
                  const SizedBox(width: 8),
                  Expanded(child: _SensorMini('E-STOP', 'GPIO 27', false, AppColors.danger)),
                ]),

                const SizedBox(height: 20),
                const _MLabel('SANTÉ SYSTÈME'),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: [
                    _HealthCard('TEMP CPU', '58°C', Icons.thermostat, AppColors.warning),
                    _HealthCard('USAGE RAM', '42%', Icons.memory, AppColors.success),
                    _HealthCard('UPTIME', '14h 22m', Icons.schedule, AppColors.primary),
                    _HealthCard('WiFi RSSI', '-64 dBm', Icons.wifi, AppColors.success),
                  ],
                ),

                const SizedBox(height: 20),
                const _MLabel('TÉLÉMÉTRIE RÉSEAU'),
                const SizedBox(height: 8),
                GlassPanel(
                  key: TutorialKeys.networkMonitor,
                  child: Column(children: [
                    const Center(
                      child: Column(children: [
                        Text('LATENCE',
                            style: TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('12',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'JetBrains Mono')),
                        Text('ms',
                            style: TextStyle(color: AppColors.textDisabled)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('QUALITÉ',
                          style: TextStyle(
                              color: AppColors.textDisabled, fontSize: 9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: const LinearProgressIndicator(
                            value: 0.92,
                            backgroundColor: AppColors.surfaceBright,
                            color: AppColors.success,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('92%',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 12),
                    for (final e in [
                      ('PAQUETS TX', '145,892'),
                      ('PAQUETS RX', '145,890'),
                      ('UPTIME CONN.', '14h 22min'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Text(e.$1,
                              style: const TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text(e.$2,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontFamily: 'JetBrains Mono')),
                        ]),
                      ),
                  ]),
                ),

                const SizedBox(height: 20),
                const _MLabel('AMDEC — RISQUES'),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final r in [
                        ('Gimbal Lock (A≈0°)', singularityRisk, 'Critique'),
                        ('Surchauffe ESP32', (temp - 30) / 40, 'Moyen'),
                        ('Latence UDP', 0.15, 'Faible'),
                        ('Perte de Pas', 0.05, 'Faible'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(r.$1,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                Text('Gravité : ${r.$3}',
                                    style: const TextStyle(
                                        color: AppColors.textDisabled,
                                        fontSize: 8)),
                              ]),
                            ),
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: r.$2.clamp(0.0, 1.0),
                                  backgroundColor: AppColors.surfaceBright,
                                  color: r.$2 > 0.8
                                      ? AppColors.error
                                      : (r.$2 > 0.5
                                          ? AppColors.warning
                                          : AppColors.success),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _MLabel('MAINTENANCE PRÉVENTIVE'),
                const SizedBox(height: 8),
                _MaintCard(),
              ]),
            ),

            // ── Config YAML ────────────────────────────────────────
            Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surfaceBright,
                child: Row(children: [
                  const Icon(Icons.code, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('CONFIG.YAML — FluidNC',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child: const Text('ÉDITER',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
              Expanded(
                child: Container(
                  color: AppColors.terminalBg,
                  child: configAsync.when(
                    data: (yamlStr) {
                      final lines = yamlStr.split('\n');
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: lines.length,
                        itemBuilder: (ctx, i) {
                          final l = lines[i];
                          final isComment = l.trimLeft().startsWith('#');
                          final parts = l.split(':');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(children: [
                              SizedBox(
                                width: 28,
                                child: Text('${i + 1}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        color: AppColors.textDisabled,
                                        fontSize: 9,
                                        fontFamily: 'JetBrains Mono')),
                              ),
                              Container(
                                  width: 1,
                                  height: 14,
                                  color: AppColors.surfaceBorder,
                                  margin: const EdgeInsets.symmetric(horizontal: 8)),
                              Expanded(
                                child: isComment
                                    ? Text(l,
                                        style: const TextStyle(
                                            color: AppColors.textDisabled,
                                            fontSize: 11,
                                            fontFamily: 'JetBrains Mono'))
                                    : (parts.length > 1
                                        ? RichText(
                                            text: TextSpan(children: [
                                              TextSpan(
                                                  text: '${parts[0]}:',
                                                  style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 11,
                                                      fontFamily: 'JetBrains Mono',
                                                      fontWeight: FontWeight.bold)),
                                              TextSpan(
                                                  text: parts.sublist(1).join(':'),
                                                  style: TextStyle(
                                                      color: parts.sublist(1).join(':').contains('"')
                                                          ? AppColors.success
                                                          : AppColors.warning,
                                                      fontSize: 11,
                                                      fontFamily: 'JetBrains Mono')),
                                            ]))
                                        : Text(l,
                                            style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 11,
                                                fontFamily: 'JetBrains Mono'))),
                              ),
                            ]),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                    error: (e, _) => Center(
                        child: Text('Erreur: $e',
                            style: const TextStyle(color: AppColors.error))),
                  ),
                ),
              ),
            ]),

            // ── Paramètres axes ────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const _MLabel('CINÉMATIQUE DES AXES'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                          color: AppColors.surfaceBright,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(5))),
                      child: const Row(children: [
                        SizedBox(width: 28, child: Text('AXE', style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))),
                        Expanded(child: Text('PAS', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))),
                        Expanded(child: Text('F-MAX', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))),
                        Expanded(child: Text('ACCEL', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))),
                        Expanded(child: Text('COURSE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))),
                      ]),
                    ),
                    for (final a in _axisParams)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: AppColors.surfaceBorder))),
                        child: Row(children: [
                          SizedBox(
                            width: 28,
                            child: Text(a.$1,
                                style: TextStyle(
                                    color: a.$2,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                          ),
                          for (final v in [a.$3, a.$4, a.$5, a.$6])
                            Expanded(
                              child: Text(v,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 10,
                                      fontFamily: 'JetBrains Mono')),
                            ),
                        ]),
                      ),
                  ]),
                ),

                const SizedBox(height: 20),
                const _MLabel('IDENTITÉ FIRMWARE'),
                const SizedBox(height: 8),
                GlassPanel(
                  child: Column(children: [
                    for (final e in [
                      ('Version', 'FluidNC v3.7.8'),
                      ('Carte', 'ESP32_WROOM_32D'),
                      ('Flash', '4MB (1.2MB Libre)'),
                      ('ESP-IDF', 'v4.4.4'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Text(e.$1,
                              style: const TextStyle(
                                  color: AppColors.textDisabled, fontSize: 10)),
                          const Spacer(),
                          Text(e.$2,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                  ]),
                ),

                const SizedBox(height: 20),
                const _MLabel('ACTIONS SYSTÈME'),
                const SizedBox(height: 8),
                for (final b in [
                  ('SAUVEGARDE CONFIG', Icons.download, AppColors.primary),
                  ('RESTAURER CONFIG', Icons.upload, AppColors.warning),
                  ('FLASH FIRMWARE', Icons.system_update, AppColors.danger),
                  ('REDÉMARRER ESP32', Icons.power_settings_new, AppColors.error),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => HapticFeedback.mediumImpact(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: b.$3.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: b.$3.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(b.$2, color: b.$3, size: 18),
                          const SizedBox(width: 12),
                          Text(b.$1,
                              style: TextStyle(
                                  color: b.$3,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              color: AppColors.textDisabled, size: 16),
                        ]),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text('DUMP DIAGNOSTIC (JSON)',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      final dump = ref.read(loggerServiceProvider.notifier)
                          .generateDiagnosticDump();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Dump généré en console')));
                      debugPrint(dump);
                    },
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSANTS COMMUNS
// ─────────────────────────────────────────────────────────────────────────────

/// Label de section uniforme mobile
class _MLabel extends StatelessWidget {
  final String text;
  const _MLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      );
}

/// Bouton d'action plein écran uniforme
class _MActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  const _MActionButton(this.label, this.color, this.icon, this.onTap,
      {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          fontFamily: 'JetBrains Mono')),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppColors.textDisabled, fontSize: 9)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Chip de pas de jog
class _StepChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StepChip(this.label, this.selected, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { onTap(); HapticFeedback.selectionClick(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? color : AppColors.surfaceBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : AppColors.textDisabled,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono')),
      ),
    );
  }
}

/// Bouton de jog directionnel
class _JogBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _JogBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono')),
        ),
      ),
    );
  }
}

class _EndstopRow extends StatelessWidget {
  final String axis;
  final String gpio;
  final bool triggered;
  final Color axisColor;
  const _EndstopRow(this.axis, this.gpio, this.triggered, this.axisColor);

  @override
  Widget build(BuildContext context) {
    final stateColor = triggered ? AppColors.error : AppColors.success;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(children: [
        Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
                color: axisColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(axis,
            style: TextStyle(
                color: axisColor,
                fontSize: 14,
                fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text(gpio,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
                fontFamily: 'JetBrains Mono')),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: stateColor.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stateColor,
                    boxShadow: [BoxShadow(color: stateColor, blurRadius: 4)])),
            const SizedBox(width: 6),
            Text(triggered ? 'DÉCL.' : 'OUVERT',
                style: TextStyle(
                    color: stateColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }
}

class _SensorMini extends StatelessWidget {
  final String label;
  final String gpio;
  final bool triggered;
  final Color color;
  const _SensorMini(this.label, this.gpio, this.triggered, this.color);

  @override
  Widget build(BuildContext context) {
    final s = triggered ? AppColors.error : AppColors.success;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(triggered ? 'DÉCL.' : 'OUVERT',
            style: TextStyle(color: s, fontSize: 8, fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: s)),
      ]),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _HealthCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono')),
        Text(label,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 8,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _MaintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.engineering, color: AppColors.primary, size: 14),
          SizedBox(width: 8),
          Text('MAINTENANCE PRÉVENTIVE',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        for (final e in [
          ('Graissage Vis à Billes', 85.0, '12j'),
          ('Tension Courroies', 42.0, '45j'),
          ('Calibration Trunnion', 95.0, '2j'),
        ])
          _MaintRow(e.$1, e.$2, e.$3),
      ]),
    );
  }
}

class _MaintRow extends StatelessWidget {
  final String label;
  final double health;
  final String timeLeft;
  const _MaintRow(this.label, this.health, this.timeLeft);

  @override
  Widget build(BuildContext context) {
    final color = health < 20
        ? AppColors.error
        : (health < 60 ? AppColors.warning : AppColors.success);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 9))),
        Text(timeLeft,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        SizedBox(
            width: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                  value: health / 100,
                  backgroundColor: AppColors.surfaceBright,
                  color: color,
                  minHeight: 3),
            )),
      ]),
    );
  }
}
