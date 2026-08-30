import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../application/providers/probing_provider.dart';
import '../../application/providers/config_provider.dart';
import '../../application/providers/machine_params_provider.dart';
import '../../application/providers/firmware_provider.dart';
import '../../application/providers/network_stats_provider.dart';
import '../widgets/mobile/mobile_tab_bar.dart';
import '../widgets/wcs_offset_dialog.dart';
import '../widgets/tool_photo.dart';
import '../../application/services/logger_service.dart';
import '../tutorial/tutorial_keys.dart';
import '../widgets/dashboard/mode_selector_widget.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/program_tools_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../core/utils/gcode_tool_extractor.dart';
import '../../core/i18n/app_localizations.dart';

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

  static const _wcsLabels = ['G54', 'G55', 'G56', 'G57', 'G58', 'G59'];
  static const _emptyOffset = [0.0, 0.0, 0.0, 0.0, 0.0];
  static List<String> get _axisLabels => ['X', 'Y', 'Z', 'A', 'C'];
  static List<Color> _axisColors(ForgeronColorPalette c) => [
    c.axisX, c.axisY, c.axisZ,
    c.axisA, c.axisC,
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
    final wcsOffsets = state.valueOrNull?.wcsOffsets ?? const {};
    final wcsData = [
      for (final label in _wcsLabels) (label, wcsOffsets[label] ?? _emptyOffset)
    ];

    return Column(
      children: [
        // ── Tab bar compacte (48 px au lieu de 72) ─────────────────────
        MobileTabBar(
          controller: _tab,
          tabs: const [
            MobileTab(Icons.grid_on, 'WCS'),
            MobileTab(Icons.center_focus_strong, 'JOG'),
            MobileTab(Icons.vertical_align_bottom, 'PALPAGE'),
            MobileTab(Icons.home, 'HOMING'),
          ],
        ),

        // ── Content ────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _WCSTab(
                  wcsData: wcsData,
                  wPos: wPos,
                  activeWCS: activeWCS,
                  axisLabels: _axisLabels,
                  axisColors: _axisColors(context.fc)),
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
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ModeSelectorWidget(),
        SizedBox(height: 20),

        const _MLabel('SYSTÈMES DE COORDONNÉES (WCS)'),
        SizedBox(height: 8),
        ...wcsData.map((d) {
          final sel = d.$1 == activeWCS;
          return GestureDetector(
            onTap: () {
              ref.read(machineRepositoryProvider).sendGCode(d.$1);
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr('WCS actif: {}', [d.$1])),
                backgroundColor: context.fc.primary,
                duration: const Duration(seconds: 1),
              ));
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.fc.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sel ? context.fc.primary : context.fc.surfaceBorder,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? context.fc.primary.withValues(alpha: 0.15)
                        : context.fc.surfaceBright,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(d.$1,
                      style: TextStyle(
                          color: sel ? context.fc.primary : context.fc.textSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          fontFamily: 'JetBrains Mono')),
                ),
                SizedBox(width: 12),
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
                  Icon(Icons.check_circle,
                      color: context.fc.primary, size: 16),
                // Saisie du décalage au clavier, pour ce WCS précis. Éditer
                // depuis sa propre ligne lève toute ambiguïté sur la cible.
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: context.fc.textDisabled, size: 17),
                  tooltip: tr('Saisir le décalage de {}', [d.$1]),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(left: 8),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => WcsOffsetDialog(
                      wcs: d.$1,
                      current: d.$2,
                      axisLabels: axisLabels,
                      axisColors: axisColors,
                    ),
                  ),
                ),
              ]),
            ),
          );
        }),

        SizedBox(height: 20),
        const _MLabel('DRO EN DIRECT'),
        SizedBox(height: 8),
        ...List.generate(5, (i) {
          final isRotary = i >= 3;
          return Container(
            margin: EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.fc.surface,
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
              SizedBox(width: 4),
              Text(isRotary ? '°' : 'mm',
                  style: TextStyle(
                      color: context.fc.textDisabled, fontSize: 9)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  wPos[i].toStringAsFixed(isRotary ? 2 : 3),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: context.fc.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono'),
                ),
              ),
            ]),
          );
        }),

        SizedBox(height: 20),
        const _MLabel('DÉFINIR L\'ORIGINE PIÈCE (position actuelle = 0)'),
        SizedBox(height: 8),
        Row(children: [
          for (int i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(machineRepositoryProvider)
                      .sendGCode('G10 L20 P0 ${axisLabels[i]}0');
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        tr('{} = 0 à la position actuelle ({})', [axisLabels[i], activeWCS])),
                    backgroundColor: axisColors[i],
                    duration: const Duration(seconds: 1),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: axisColors[i].withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: axisColors[i].withValues(alpha: 0.5)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(axisLabels[i],
                        style: TextStyle(
                            color: axisColors[i],
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            fontFamily: 'JetBrains Mono')),
                    Text('= 0',
                        style: TextStyle(
                            color: axisColors[i].withValues(alpha: 0.8),
                            fontSize: 9)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        SizedBox(height: 8),
        _MActionButton(
          'TOUT METTRE À ZÉRO (ICI)',
          context.fc.primary,
          Icons.adjust_rounded,
          () {
            ref
                .read(machineRepositoryProvider)
                .sendGCode('G10 L20 P0 X0 Y0 Z0 A0 C0');
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('Origine pièce définie ici ({})', [activeWCS])),
              backgroundColor: context.fc.primary,
              duration: const Duration(seconds: 1),
            ));
          },
        ),

        SizedBox(height: 16),
        _MActionButton(
          'ALLER AU ZÉRO',
          context.fc.textSecondary,
          Icons.gps_fixed,
          () => ref.read(machineRepositoryProvider).sendGCode('G0 X0 Y0 Z0 A0 C0'),
        ),
        SizedBox(height: 8),
        _MActionButton(
          'ORIGINES (TOUS)',
          context.fc.axisZ,
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
    final jogN = ref.read(secureJogProvider.notifier);
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final wPos = machineState?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    // DRO en haut, commandes de jog au milieu, JOG STOP épinglé en bas.
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _JogDroStrip(wPos: wPos),
      ),
      // Commandes de jog — défilent seules si nécessaire.
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.fc.surfaceBright, context.fc.surface],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.fc.surfaceBorder),
            ),
            child: JogControlPanel(wPos: wPos),
          ),
        ),
      ),
      // JOG STOP épinglé en bas, toujours atteignable au pouce.
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: _JogStopButton(onStop: () {
          jogN.stopJog();
          HapticFeedback.heavyImpact();
        }),
      ),
    ]);
  }
}

// ── Bandeau DRO live + bouton STOP (onglet Jog) ─────────────────────────────
/// Bandeau compact des 5 axes (X/Y/Z/A/C) avec valeurs en direct, pour garder
/// la position sous les yeux pendant le jog.
class _JogDroStrip extends ConsumerWidget {
  final List<double> wPos;
  const _JogDroStrip({required this.wPos});

  /// En deca de cette distance relative a une extremite, la jauge alerte.
  static const _edge = 0.05;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final axes = [
      ('X', fc.axisX, false),
      ('Y', fc.axisY, false),
      ('Z', fc.axisZ, false),
      ('A', fc.axisA, true),
      ('C', fc.axisC, true),
    ];

    // Position MACHINE et courses : pendant un jog, on conduit l\'axe a la main
    // vers ses butees. Savoir ce qu\'il reste avant la fin de course est
    // exactement l\'information qui manque, et la coordonnee piece affichee ne
    // peut pas la donner puisqu\'elle depend de l\'origine posee.
    final mPos =
        ref.watch(machineStateProvider).valueOrNull?.mPos ?? const [0.0, 0.0, 0.0, 0.0, 0.0];
    final kin = ref.watch(axisKinematicsProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 5; i++)
            Expanded(
              child: _axis(
                context,
                axes[i].$1,
                axes[i].$2,
                axes[i].$3,
                i < wPos.length ? wPos[i] : 0.0,
                (kin != null && i < kin.length)
                    ? kin[i].travelFraction(i < mPos.length ? mPos[i] : 0.0)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _axis(BuildContext context, String label, Color color, bool rotary,
      double value, double? fraction) {
    final fc = context.fc;
    final nearEdge =
        fraction != null && (fraction <= _edge || fraction >= 1 - _edge);

    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 12)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            rotary ? '${value.toStringAsFixed(2)}°' : value.toStringAsFixed(3),
            style: TextStyle(
                color: nearEdge ? fc.warning : fc.textPrimary,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w900,
                fontSize: 13),
          ),
        ),
        // Course inconnue = pas de barre, plutot qu\'une proportion inventee.
        if (fraction != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: Stack(children: [
                  Positioned.fill(
                    child: ColoredBox(
                        color: fc.surfaceBorderDim.withValues(alpha: 0.6)),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      color: nearEdge ? fc.warning : color,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bouton JOG STOP premium — dégradé rouge + halo, hauteur généreuse.
class _JogStopButton extends StatelessWidget {
  final VoidCallback onStop;
  const _JogStopButton({required this.onStop});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStop,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [fc.danger, fc.danger.withValues(alpha: 0.72)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: fc.danger.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: -2),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text(tr('JOG STOP'),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ),
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
      padding: EdgeInsets.all(16),
      child: Column(children: [
        // Statut
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: probing.step == ProbingStep.error
                ? context.fc.danger.withValues(alpha: 0.1)
                : context.fc.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: probing.step == ProbingStep.error
                  ? context.fc.danger
                  : context.fc.primary,
              width: 0.5,
            ),
          ),
          child: Row(children: [
            Icon(
              probing.step == ProbingStep.error ? Icons.error : Icons.info,
              color: probing.step == ProbingStep.error
                  ? context.fc.danger
                  : context.fc.primary,
              size: 16,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                probing.statusMessage,
                style: TextStyle(
                  color: probing.step == ProbingStep.error
                      ? context.fc.danger
                      : context.fc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),
        if (probing.step != ProbingStep.idle && probing.step != ProbingStep.finished)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
                color: context.fc.primary,
                backgroundColor: context.fc.surfaceBright),
          ),

        SizedBox(height: 16),

        // Routines 2×2
        Row(children: [
          Expanded(child: _ProbingCard('HAUTEUR Z', 'G38.2 sur axe Z',
              Icons.vertical_align_bottom,
              probing.step == ProbingStep.idle ? () => probingN.startToolZRoutine() : null)),
          SizedBox(width: 10),
          Expanded(child: _ProbingCard('CENTRE TROU', '4 points → centre',
              Icons.adjust,
              probing.step == ProbingStep.idle
                  ? () => probingN.startHoleCenterRoutine(20.0, -5.0) : null)),
        ]),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ProbingCard('ANGLE X', 'Inclinaison pièce X',
              Icons.architecture,
              probing.step == ProbingStep.idle
                  ? () => probingN.startAngleRoutine('X', 50.0) : null)),
          SizedBox(width: 10),
          Expanded(child: _ProbingCard('ANGLE Y', 'Inclinaison pièce Y',
              Icons.architecture,
              probing.step == ProbingStep.idle
                  ? () => probingN.startAngleRoutine('Y', 50.0) : null)),
        ]),

        if (probing.step != ProbingStep.idle) ...[
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.fc.danger,
                  foregroundColor: Colors.white),
              onPressed: () { probingN.cancel(); HapticFeedback.heavyImpact(); },
              child: Text(tr('ANNULER LE PALPAGE'),
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
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.fc.primary.withValues(alpha: 0.10),
                context.fc.surface,
              ],
              stops: const [0.0, 0.65],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.fc.primary.withValues(alpha: 0.3)),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                        color: context.fc.primary.withValues(alpha: 0.12),
                        blurRadius: 16,
                        spreadRadius: -4),
                  ],
          ),
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.fc.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.fc.primary, size: 26),
            ),
            SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.fc.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
            SizedBox(height: 4),
            Text(desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.fc.textDisabled, fontSize: 9, height: 1.4)),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  context.fc.primary,
                  context.fc.primary.withValues(alpha: 0.75),
                ]),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                      color: context.fc.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: -2),
                ],
              ),
              child: Text(tr('LANCER'),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0)),
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
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.fc.axisZ.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.fc.axisZ.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: context.fc.axisZ, size: 14),
            SizedBox(width: 8),
            Expanded(
              child: Text(tr('Séquence recommandée : Z → X → Y → A → C'),
                  style: TextStyle(color: context.fc.textSecondary, fontSize: 10, height: 1.5)),
            ),
          ]),
        ),
        SizedBox(height: 16),
        for (final e in [
          ('HOME Z', 'Dégager broche', context.fc.axisZ, () => jogN.homeAxis('Z')),
          ('HOME X', 'Axe horizontal', context.fc.axisX, () => jogN.homeAxis('X')),
          ('HOME Y', 'Axe frontal', context.fc.axisY, () => jogN.homeAxis('Y')),
          ('HOME A', 'Basculement trunnion', context.fc.axisA, () => jogN.homeAxis('A')),
          ('HOME C', 'Rotation plateau', context.fc.axisC, () => jogN.homeAxis('C')),
        ])
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _MActionButton(e.$1, e.$3, Icons.home,
                () { e.$4(); HapticFeedback.mediumImpact(); },
                subtitle: e.$2),
          ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            icon: Icon(Icons.home_rounded, size: 20),
            label: Text(tr('HOME ALL (\$H)'),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.fc.axisZ, foregroundColor: Colors.white),
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

/// Magasin d'outils — **lu dans le programme chargé**, jamais saisi.
///
/// Il n'existe pas de table d'outils dans l'application : afficher un catalogue
/// d'outils qui ne sont pas ceux du programme induirait l'opérateur en erreur
/// au pire moment, celui du changement. Tout vient donc de
/// [programToolsProvider], c'est-à-dire du G-code lui-même.
class MobileToolTableScreen extends ConsumerStatefulWidget {
  const MobileToolTableScreen({super.key});
  @override
  ConsumerState<MobileToolTableScreen> createState() =>
      _MobileToolTableScreenState();
}

class _MobileToolTableScreenState
    extends ConsumerState<MobileToolTableScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showDetail(ProgramTool tool, int activeToolNum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, ctrl) => _ToolDetailSheet(
          tool: tool,
          scrollController: ctrl,
          activeToolNum: activeToolNum,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final tools = ref.watch(programToolsProvider);
    final activeToolNum = ref.watch(activeToolNumberProvider);

    final filtered = tools.where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return 'T${t.number}'.toLowerCase().contains(q) ||
          (t.description ?? '').toLowerCase().contains(q) ||
          (t.operation ?? '').toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        _header(fc, tools.length, activeToolNum),
        if (tools.isNotEmpty) _searchField(fc),
        Expanded(
          child: tools.isEmpty
              ? _emptyState(fc)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final t = filtered[i];
                    return _ToolCard(
                      tool: t,
                      isActive: t.number == activeToolNum && activeToolNum > 0,
                      onTap: () => _showDetail(t, activeToolNum),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _header(ForgeronColorPalette fc, int count, int activeToolNum) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('OUTILS DU PROGRAMME'),
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(tr('lus dans le G-code chargé'),
                  style: TextStyle(color: fc.textDisabled, fontSize: 10)),
            ],
          ),
          const Spacer(),
          if (activeToolNum > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: fc.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: fc.primary.withValues(alpha: 0.5)),
              ),
              child: Text(tr('ACTIF : T{}', [activeToolNum]),
                  style: TextStyle(
                      color: fc.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            )
          else
            Text(tr(count > 1 ? '{} outils' : '{} outil', [count]),
                style: TextStyle(color: fc.textDisabled, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _searchField(ForgeronColorPalette fc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(color: fc.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search, color: fc.textSecondary, size: 18),
          hintText: tr('Filtrer'),
          hintStyle: TextStyle(color: fc.textDisabled, fontSize: 13),
          filled: true,
          fillColor: fc.background.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: fc.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: fc.surfaceBorder),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ForgeronColorPalette fc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handyman_outlined, color: fc.textDisabled, size: 48),
            const SizedBox(height: 14),
            Text(tr('AUCUN PROGRAMME CHARGÉ'),
                style: TextStyle(
                    color: fc.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              tr('Les outils sont lus dans le G-code. Charge un programme depuis l\'onglet PROGRAMME pour voir ceux qu\'il utilise.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: fc.textDisabled, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un outil dans la liste.
class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.isActive,
    required this.onTap,
  });

  final ProgramTool tool;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? fc.primary.withValues(alpha: 0.10) : fc.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive ? fc.primary : fc.surfaceBorder,
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          children: [
            ToolPhoto(shape: tool.shape, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('T${tool.number}',
                        style: TextStyle(
                            color: isActive ? fc.primary : fc.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono')),
                    const SizedBox(width: 8),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: fc.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(tr('MONTÉ'),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    tool.description ?? 'Descriptif absent du programme',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tool.description == null
                          ? fc.textDisabled
                          : fc.textSecondary,
                      fontSize: 11,
                      fontStyle: tool.description == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  if (!tool.isBare) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (tool.diameterMm != null)
                        _Chip('Ø${_trim(tool.diameterMm!)}', fc.primary),
                      if (tool.flutes != null)
                        _Chip('${tool.flutes} tailles', fc.info),
                      if (tool.material != null)
                        _Chip(tool.material!, fc.textSecondary),
                    ]),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: fc.textDisabled, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Fiche détaillée d'un outil.
class _ToolDetailSheet extends ConsumerWidget {
  const _ToolDetailSheet({
    required this.tool,
    required this.scrollController,
    required this.activeToolNum,
  });

  final ProgramTool tool;
  final ScrollController scrollController;
  final int activeToolNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final isActive = tool.number == activeToolNum && activeToolNum > 0;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: fc.textDisabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(children: [
          ToolPhoto(shape: tool.shape, size: 88),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('T${tool.number}',
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
                Text(tool.shape.label,
                    style: TextStyle(color: fc.primary, fontSize: 12)),
                if (isActive) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: fc.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tr('ACTUELLEMENT MONTÉ'),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          ),
        ]),

        const SizedBox(height: 18),

        // ── Ce que dit le programme ────────────────────────────────────────
        _sectionTitle(fc, 'CE QUE DIT LE PROGRAMME'),
        const SizedBox(height: 8),
        if (tool.description != null)
          _rawLine(fc, tool.description!)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fc.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: fc.warning.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: fc.warning, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Le programme ne décrit pas cet outil : il n\'indique que son numéro. Aucune caractéristique n\'est affichée plutôt que d\'en inventer.'),
                  style: TextStyle(
                      color: fc.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),

        if (tool.operation != null) ...[
          const SizedBox(height: 8),
          _row(fc, 'Opération', tool.operation!),
        ],

        if (!tool.isBare) ...[
          const SizedBox(height: 18),
          _sectionTitle(fc, 'CARACTÉRISTIQUES'),
          const SizedBox(height: 8),
          if (tool.diameterMm != null)
            _row(fc, 'Diamètre', '${_trim(tool.diameterMm!)} mm'),
          if (tool.flutes != null) _row(fc, 'Tailles', '${tool.flutes}'),
          if (tool.cuttingLengthMm != null)
            _row(fc, 'Longueur de coupe',
                '${_trim(tool.cuttingLengthMm!)} mm'),
          if (tool.material != null) _row(fc, 'Matière', tool.material!),
        ],

        const SizedBox(height: 18),
        _sectionTitle(fc, 'DANS LE PROGRAMME'),
        const SizedBox(height: 8),
        _row(fc, 'Appelé', '${tool.changeLines.length} fois'),
        // Numérotation du FICHIER SOURCE, pas du programme affiché dans
        // l'onglet PROGRAMME : celui-ci est la version adaptée, dont les lignes
        // ont été renumérotées. Le préciser évite un renvoi faux.
        _row(fc, 'Ligne (fichier d\'origine)', '${tool.firstChangeLine + 1}'),

        if (tool.spindleSpeed != null) ...[
          const SizedBox(height: 8),
          // Sans cette mise en garde, l'opérateur croirait que la broche tourne
          // à la vitesse annoncée. Sur une broche pilotée en tout-ou-rien, le
          // mot S est reçu puis ignoré par le contrôleur.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fc.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: fc.info.withValues(alpha: 0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.speed, color: fc.info, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Le programme demande S{}. Cette valeur n\'est appliquée que si la broche est pilotée en vitesse ; en tout-ou-rien elle est ignorée.', [tool.spindleSpeed]),
                  style: TextStyle(
                      color: fc.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.build_circle_outlined, size: 18),
            label: Text(tr('APPELER T{}  (M6)', [tool.number])),
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.surfaceBright,
              foregroundColor: fc.primary,
              padding: const EdgeInsets.all(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: fc.primary.withValues(alpha: 0.3)),
              ),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
            ),
            onPressed: () => _confirmCall(context, ref),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.straighten, size: 18),
            label: Text(tr('G43 H{}  (décalage longueur)', [tool.number])),
            style: OutlinedButton.styleFrom(
              foregroundColor: fc.textSecondary,
              padding: const EdgeInsets.all(15),
              side: BorderSide(color: fc.surfaceBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            onPressed: () {
              ref
                  .read(machineRepositoryProvider)
                  .sendGCode('G43 H${tool.number}');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr('✓ G43 H{} appliqué', [tool.number])),
              ));
            },
          ),
        ),
      ]),
    );
  }

  void _confirmCall(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: context.fc.surface,
        title: Text(tr('Appel outil T{}', [tool.number]),
            style: TextStyle(color: context.fc.textPrimary, fontSize: 16)),
        content: Text(
          tr('Envoyer T{} M6 ?\n\nLa broche s\'arrête et le programme se met en pause pour le changement.', [tool.number]),
          style: TextStyle(color: context.fc.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(tr('Annuler')),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(machineRepositoryProvider)
                  .sendGCode('T${tool.number} M6');
              Navigator.pop(dctx);
              Navigator.pop(context);
            },
            child: Text(tr('Envoyer')),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ForgeronColorPalette fc, String label) => Text(
        label,
        style: TextStyle(
            color: fc.textDisabled,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5),
      );

  Widget _rawLine(ForgeronColorPalette fc, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: fc.terminalBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fc.surfaceBorder),
        ),
        child: Text(text,
            style: TextStyle(
                color: fc.textPrimary,
                fontSize: 12,
                fontFamily: 'JetBrains Mono')),
      );

  Widget _row(ForgeronColorPalette fc, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label, style: TextStyle(color: fc.textDisabled, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
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

  // Log EN DIRECT du trafic machine (TX/RX réels via trafficStream).
  final List<(String time, String type, String content)> _log = [];
  // Historique des commandes réellement envoyées.
  final List<(String cmd, String time)> _history = [];
  StreamSubscription<String>? _trafficSub;
  final ScrollController _logScroll = ScrollController();

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  /// Reçoit chaque trame TX/RX de la connexion et l'ajoute au log.
  void _handleTraffic(String msg) {
    if (!mounted) return;
    String type = 'MSG';
    String content = msg;
    if (msg.startsWith('TX: ')) {
      type = '>>>';
      content = msg.substring(4).trim();
    } else if (msg.startsWith('RX: ')) {
      content = msg.substring(4).trim();
      if (content.startsWith('ok')) {
        type = 'ok';
      } else if (content.startsWith('error') || content.startsWith('ALARM')) {
        type = 'ERR';
      } else if (content.startsWith('<')) {
        return; // trames de statut filtrées (sinon ça défile en boucle)
      } else {
        type = 'MSG';
      }
    }
    if (content.isEmpty) return;
    setState(() {
      _log.add((_fmtTime(DateTime.now()), type, content));
      if (_log.length > 200) _log.removeAt(0);
    });
    Future.delayed(const Duration(milliseconds: 40), () {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(_logScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  /// Couleur d'une ligne selon son type (theme-aware, résolue au rendu).
  Color _typeColor(ForgeronColorPalette fc, String type) => switch (type) {
        '>>>' => fc.primary,
        'ok' => fc.success,
        'ERR' => fc.error,
        'MSG' => fc.warning,
        _ => fc.secondary,
      };

  static List<(IconData, String, String, Color)> _macros(
          ForgeronColorPalette c) =>
      [
    (Icons.home, 'ORIGINES', '\$H', c.primary),
    // Nom rectifié : la macro DÉPLACE les axes vers l'origine pièce, elle ne
    // la définit pas. Sous l'étiquette « ZÉRO PIÈCE », l'opérateur croyait
    // poser son origine et lançait un rapide 5 axes vers Z0 — dans la pièce.
    // Pour définir l'origine : onglet PALPAGE → DÉFINIR L'ORIGINE (G10 L20).
    (Icons.gps_fixed, 'ALLER AU ZÉRO', 'G0 X0 Y0 Z0 A0 C0', c.primary),
    (Icons.sensors, 'PALPAGE Z', 'G38.2 Z-50 F100', c.secondary),
    // S1000 = 100 % de la speed_map FluidNC (broche relais tout-ou-rien sur
    // gpio.21). S12000 annonçait un régime que cette broche ne connaît pas.
    (Icons.rotate_right, 'BROCHE H', 'M3 S1000', c.success),
    (Icons.stop_circle, 'ARRÊT B.', 'M5', c.error),
    (Icons.water_drop, 'ARROSAGE', 'M8', c.primary),
    (Icons.water_drop_outlined, 'ARROS. OFF', 'M9', c.textDisabled),
    (Icons.air, 'SOUFFLAGE', 'M7', c.secondary),
    (Icons.vertical_align_top, 'Z SÉCU', 'G0 Z50', c.primary),
    // G28 (position prédéfinie de la carte), comme sur desktop. L'ancien
    // « G0 X0 Y200 Z50 » demandait Y200 alors que la course Y est de 150 mm,
    // soft_limits activées : la macro finissait systématiquement en alarme.
    (Icons.local_parking, 'PARKING', 'G28', c.textSecondary),
    (Icons.play_arrow, 'REPRENDRE', '~', c.success),
    (Icons.pause, 'PAUSE', '!', c.warning),
    // Manquaient au mobile : de quoi couper un programme en cours et sortir
    // d'alarme sans passer par la saisie clavier.
    (Icons.cancel_rounded, 'ANNULER', '', c.error),
    (Icons.lock_open_rounded, 'DÉBLOQUER', '\$X', c.warning),
  ];


  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _log.add((_fmtTime(DateTime.now()), 'INFO', 'Terminal prêt — en attente de trafic…'));
    Future.microtask(() {
      _trafficSub =
          ref.read(machineRepositoryProvider).trafficStream.listen(_handleTraffic);
    });
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _logScroll.dispose();
    _tab.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _send(String cmd) {
    final c = cmd.trim();
    if (c.isEmpty) return;
    ref.read(machineRepositoryProvider).sendGCode(c);
    setState(() {
      _history.insert(0, (c, _fmtTime(DateTime.now())));
      if (_history.length > 30) _history.removeLast();
    });
    _ctrl.clear();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final rxBuf = ref.watch(machineStateProvider).valueOrNull?.rxBuffer ?? 128;
    return Column(
      children: [
        MobileTabBar(
          controller: _tab,
          tabs: const [
            MobileTab(Icons.terminal, 'TERMINAL'),
            MobileTab(Icons.grid_view_rounded, 'MACROS'),
          ],
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
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  color: context.fc.surfaceBright,
                  child: Row(children: [
                    Icon(Icons.terminal,
                        color: context.fc.textDisabled, size: 14),
                    SizedBox(width: 8),
                    Text(tr('LOG MACHINE'),
                        style: TextStyle(
                            color: context.fc.textDisabled,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text(tr('BUFFER: {}/128', [rxBuf]),
                        style: TextStyle(
                            color: context.fc.textDisabled,
                            fontSize: 9,
                            fontFamily: 'JetBrains Mono')),
                  ]),
                ),
                // Log
                Expanded(
                  key: TutorialKeys.mdiHistory,
                  child: Container(
                    color: context.fc.terminalBg,
                    child: ListView.builder(
                      controller: _logScroll,
                      padding: EdgeInsets.all(12),
                      itemCount: _log.length,
                      itemBuilder: (ctx, i) {
                        final l = _log[i];
                        final color = _typeColor(context.fc, l.$2);
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.$1,
                                  style: TextStyle(
                                      color: context.fc.textDisabled,
                                      fontSize: 10,
                                      fontFamily: 'JetBrains Mono')),
                              SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                child: Text(l.$2,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'JetBrains Mono')),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(l.$3,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontFamily: 'JetBrains Mono')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Input
                Container(
                  key: TutorialKeys.mdiInput,
                  padding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: context.fc.surface,
                      border: Border(
                          top: BorderSide(color: context.fc.surfaceBorder))),
                  child: Row(children: [
                    Text('❯',
                        style: TextStyle(
                            color: context.fc.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: TextStyle(
                            color: context.fc.textPrimary,
                            fontSize: 14,
                            fontFamily: 'JetBrains Mono'),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: tr('Saisir commande G-code...'),
                          hintStyle: TextStyle(
                              color: context.fc.textDisabled),
                        ),
                        onSubmitted: _send,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _send(_ctrl.text),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 44)),
                      child: Icon(Icons.send_rounded, size: 18),
                    ),
                  ]),
                ),
              ]),

              // ── Tab 2 : Macros ────────────────────────────────────
              SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _MLabel('MACROS RAPIDES'),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: _macros(context.fc).map((m) => InkWell(
                      onTap: () {
                        if (m.$2 == 'ORIGINES') {
                          ref.read(machineRepositoryProvider).home([]);
                        } else if (m.$2 == 'PAUSE') {
                          ref.read(machineRepositoryProvider).pause();
                        } else if (m.$2 == 'REPRENDRE') {
                          ref.read(machineRepositoryProvider).resume();
                        } else if (m.$2 == 'ANNULER') {
                          ref.read(streamingProvider.notifier).stopStream();
                        } else if (m.$2 == 'DÉBLOQUER') {
                          ref.read(machineRepositoryProvider).sendRaw('\$X\n');
                        } else {
                          ref.read(machineRepositoryProvider).sendGCode(m.$3);
                        }
                        HapticFeedback.selectionClick();
                      },
                      borderRadius: BorderRadius.circular(10),
                      splashColor: m.$4.withValues(alpha: 0.2),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              m.$4.withValues(alpha: 0.14),
                              m.$4.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: m.$4.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                                color: m.$4.withValues(alpha: 0.1),
                                blurRadius: 10,
                                spreadRadius: -3),
                          ],
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: m.$4.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(m.$1, color: m.$4, size: 20),
                          ),
                          SizedBox(height: 7),
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
                  SizedBox(height: 24),
                  const _MLabel('HISTORIQUE'),
                  SizedBox(height: 8),
                  for (final h in _history)
                    GestureDetector(
                      onTap: () {
                        _ctrl.text = h.$1;
                        _tab.animateTo(0);
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                            color: context.fc.surfaceBright,
                            borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          Icon(Icons.history,
                              color: context.fc.textDisabled, size: 14),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(h.$1,
                                style: TextStyle(
                                    color: context.fc.textPrimary,
                                    fontSize: 12,
                                    fontFamily: 'JetBrains Mono')),
                          ),
                          Text(h.$2,
                              style: TextStyle(
                                  color: context.fc.textDisabled,
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

  static List<(String, String, bool, Color)> _endstops(
          ForgeronColorPalette c) =>
      [
    ('X', 'GPIO 34', false, c.axisX),
    ('Y', 'GPIO 35', false, c.axisY),
    ('Z', 'GPIO 32', true, c.axisZ),
    ('A', 'GPIO 33', false, c.axisA),
    ('C', 'GPIO 25', false, c.axisC),
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
    final fw = ref.watch(firmwareInfoProvider);
    final net = ref.watch(networkStatsProvider);
    final latColor = !net.connected
        ? context.fc.textDisabled
        : (net.latencyMs < 30
            ? context.fc.success
            : (net.latencyMs < 100 ? context.fc.warning : context.fc.error));


    return Column(children: [
      MobileTabBar(
        controller: _tab,
        tabs: const [
          MobileTab(Icons.developer_board, 'GPIO'),
          MobileTab(Icons.code, 'CONFIG'),
          MobileTab(Icons.settings_applications, 'PARAMS'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            // ── GPIO & Santé système ──────────────────────────────
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _MLabel('FINS DE COURSE (LIVE)'),
                SizedBox(height: 8),
                for (final e in _endstops(context.fc).asMap().entries)
                  _EndstopRow(e.value.$1, e.value.$2,
                      limSw[e.key], e.value.$4),
                Row(children: [
                  Expanded(child: _SensorMini('PALPEUR', 'GPIO 36',
                      machineState?.probeTriggered ?? false, context.fc.secondary)),
                  SizedBox(width: 8),
                  Expanded(child: _SensorMini('E-STOP', 'GPIO 27',
                      machineState?.emergencyTriggered ?? false, context.fc.danger)),
                ]),

                SizedBox(height: 20),
                const _MLabel('SANTÉ SYSTÈME'),
                SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: [
                    _HealthCard('TEMP CPU', '${temp.toStringAsFixed(0)}°C',
                        Icons.thermostat, context.fc.warning),
                    // RAM / Uptime / RSSI : non rapportés par FluidNC standard →
                    // resteront statiques tant que le firmware n'envoie pas de
                    // [MSG:] custom. Marqués « — » pour ne pas faire croire à du live.
                    _HealthCard('USAGE RAM', '—', Icons.memory, context.fc.textDisabled),
                    _HealthCard('UPTIME', '—', Icons.schedule, context.fc.textDisabled),
                    _HealthCard('WiFi RSSI', '—', Icons.wifi, context.fc.textDisabled),
                  ],
                ),

                SizedBox(height: 20),
                const _MLabel('TÉLÉMÉTRIE RÉSEAU'),
                SizedBox(height: 8),
                GlassPanel(
                  key: TutorialKeys.networkMonitor,
                  child: Column(children: [
                    Center(
                      child: Column(children: [
                        Text(tr('LATENCE'),
                            style: TextStyle(
                                color: context.fc.textDisabled,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text(net.connected ? '${net.latencyMs}' : '—',
                            style: TextStyle(
                                color: latColor,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'JetBrains Mono')),
                        Text('ms',
                            style: TextStyle(color: context.fc.textDisabled)),
                      ]),
                    ),
                    SizedBox(height: 12),
                    Row(children: [
                      Text(tr('QUALITÉ'),
                          style: TextStyle(
                              color: context.fc.textDisabled, fontSize: 9)),
                      SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: net.qualityPct / 100,
                            backgroundColor: context.fc.surfaceBright,
                            color: latColor,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('${net.qualityPct}%',
                          style: TextStyle(
                              color: latColor,
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w900)),
                    ]),
                    SizedBox(height: 12),
                    for (final e in [
                      ('PAQUETS TX', '${net.txCount}'),
                      ('PAQUETS RX', '${net.rxCount}'),
                      ('UPTIME CONN.', formatUptime(net.uptime)),
                    ])
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Text(e.$1,
                              style: TextStyle(
                                  color: context.fc.textDisabled,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text(e.$2,
                              style: TextStyle(
                                  color: context.fc.textPrimary,
                                  fontSize: 11,
                                  fontFamily: 'JetBrains Mono')),
                        ]),
                      ),
                  ]),
                ),

                SizedBox(height: 20),
                const _MLabel('AMDEC — RISQUES'),
                SizedBox(height: 8),
                GlassPanel(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final r in [
                        ('Gimbal Lock (A≈0°)', singularityRisk, 'Critique'),
                        ('Surchauffe ESP32', (temp - 30) / 40, 'Moyen'),
                        ('Latence UDP', (net.latencyMs / 200).clamp(0.0, 1.0), 'Faible'),
                        ('Perte de Pas', 0.05, 'Faible'),
                      ])
                        Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(r.$1,
                                    style: TextStyle(
                                        color: context.fc.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                Text(tr('Gravité : {}', [r.$3]),
                                    style: TextStyle(
                                        color: context.fc.textDisabled,
                                        fontSize: 8)),
                              ]),
                            ),
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: r.$2.clamp(0.0, 1.0),
                                  backgroundColor: context.fc.surfaceBright,
                                  color: r.$2 > 0.8
                                      ? context.fc.error
                                      : (r.$2 > 0.5
                                          ? context.fc.warning
                                          : context.fc.success),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: 16),
                const _MLabel('MAINTENANCE PRÉVENTIVE'),
                SizedBox(height: 8),
                _MaintCard(),
              ]),
            ),

            // ── Config YAML ────────────────────────────────────────
            Column(children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: context.fc.surfaceBright,
                child: Row(children: [
                  Icon(Icons.code, color: context.fc.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('CONFIG.YAML — FluidNC'),
                        style: TextStyle(
                            color: context.fc.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              Expanded(
                child: Container(
                  color: context.fc.terminalBg,
                  child: configAsync.when(
                    data: (yamlStr) {
                      final lines = yamlStr.split('\n');
                      return ListView.builder(
                        padding: EdgeInsets.all(12),
                        itemCount: lines.length,
                        itemBuilder: (ctx, i) {
                          final l = lines[i];
                          final isComment = l.trimLeft().startsWith('#');
                          final parts = l.split(':');
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 1),
                            child: Row(children: [
                              SizedBox(
                                width: 28,
                                child: Text('${i + 1}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: context.fc.textDisabled,
                                        fontSize: 9,
                                        fontFamily: 'JetBrains Mono')),
                              ),
                              Container(
                                  width: 1,
                                  height: 14,
                                  color: context.fc.surfaceBorder,
                                  margin: EdgeInsets.symmetric(horizontal: 8)),
                              Expanded(
                                child: isComment
                                    ? Text(l,
                                        style: TextStyle(
                                            color: context.fc.textDisabled,
                                            fontSize: 11,
                                            fontFamily: 'JetBrains Mono'))
                                    : (parts.length > 1
                                        ? RichText(
                                            text: TextSpan(children: [
                                              TextSpan(
                                                  text: '${parts[0]}:',
                                                  style: TextStyle(
                                                      color: context.fc.primary,
                                                      fontSize: 11,
                                                      fontFamily: 'JetBrains Mono',
                                                      fontWeight: FontWeight.bold)),
                                              TextSpan(
                                                  text: parts.sublist(1).join(':'),
                                                  style: TextStyle(
                                                      color: parts.sublist(1).join(':').contains('"')
                                                          ? context.fc.success
                                                          : context.fc.warning,
                                                      fontSize: 11,
                                                      fontFamily: 'JetBrains Mono')),
                                            ]))
                                        : Text(l,
                                            style: TextStyle(
                                                color: context.fc.textPrimary,
                                                fontSize: 11,
                                                fontFamily: 'JetBrains Mono'))),
                              ),
                            ]),
                          );
                        },
                      );
                    },
                    loading: () => Center(
                        child: CircularProgressIndicator(
                            color: context.fc.primary)),
                    error: (e, _) => Center(
                        child: Text(tr('Erreur: {}', [e]),
                            style: TextStyle(color: context.fc.error))),
                  ),
                ),
              ),
            ]),

            // ── Paramètres axes ────────────────────────────────────
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const _MLabel('IDENTITÉ FIRMWARE'),
                SizedBox(height: 8),
                GlassPanel(
                  titleTrailing: fw.isKnown
                      ? null
                      : InkWell(
                          onTap: () => ref
                              .read(firmwareInfoProvider.notifier)
                              .requestInfo(),
                          child: Icon(Icons.refresh_rounded,
                              size: 14, color: context.fc.textSecondary),
                        ),
                  child: Column(children: [
                    for (final e in [
                      ('Version', fw.version ?? (fw.isKnown ? '—' : 'en attente (\$I)…')),
                      ('GRBL', fw.grblVersion ?? '—'),
                      ('Carte', fw.board ?? '—'),
                      ('Options', fw.options ?? '—'),
                    ])
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Text(e.$1,
                              style: TextStyle(
                                  color: context.fc.textDisabled, fontSize: 10)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(e.$2,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.fc.textPrimary,
                                    fontSize: 11,
                                    fontFamily: 'JetBrains Mono',
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ),
                  ]),
                ),

                SizedBox(height: 20),
                const _MLabel('ACTIONS SYSTÈME'),
                SizedBox(height: 8),
                for (final b in <(String, IconData, Color, VoidCallback)>[
                  (
                    'COPIER CONFIG.YAML',
                    Icons.copy_all_rounded,
                    context.fc.primary,
                    () {
                      final cfg = ref.read(configResultProvider).valueOrNull;
                      final m = ScaffoldMessenger.of(context);
                      if (cfg == null) {
                        m.showSnackBar(SnackBar(
                            content: Text(tr('Config non chargée.'))));
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: cfg.yaml));
                      HapticFeedback.mediumImpact();
                      m.showSnackBar(SnackBar(
                          content: Text(
                              tr('config.yaml copié dans le presse-papiers'))));
                    }
                  ),
                  (
                    'REDÉMARRER ESP32',
                    Icons.power_settings_new,
                    context.fc.error,
                    () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.fc.surface,
                          title: Text(tr('Redémarrer l\'ESP32 ?'),
                              style: TextStyle(
                                  color: context.fc.textPrimary, fontSize: 16)),
                          content: Row(children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 18, color: context.fc.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr('La liaison va être coupée : l\'app se déconnectera quelques secondes, le temps du reboot. La reconnexion est automatique.'),
                                style: TextStyle(
                                    color: context.fc.textSecondary,
                                    fontSize: 12,
                                    height: 1.4),
                              ),
                            ),
                          ]),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(tr('Annuler'),
                                    style: TextStyle(
                                        color: context.fc.textSecondary))),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: context.fc.error,
                                  foregroundColor: Colors.white),
                              child: Text(tr('Redémarrer')),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        ref
                            .read(machineRepositoryProvider)
                            .sendRaw('\$Bye\n');
                        HapticFeedback.heavyImpact();
                      }
                    }
                  ),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: b.$4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 52,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: b.$3.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: b.$3.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(b.$2, color: b.$3, size: 18),
                          SizedBox(width: 12),
                          Text(b.$1,
                              style: TextStyle(
                                  color: b.$3,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              color: context.fc.textDisabled, size: 16),
                        ]),
                      ),
                    ),
                  ),

                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.analytics),
                    label: Text(tr('DUMP DIAGNOSTIC (JSON)'),
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: context.fc.primary,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      final dump = ref.read(loggerServiceProvider.notifier)
                          .generateDiagnosticDump();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr('Dump généré en console'))));
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
        style: TextStyle(
          color: context.fc.textDisabled,
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
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withValues(alpha: 0.18),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 14,
                  spreadRadius: -4),
            ],
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            SizedBox(width: 12),
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
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(
                            color: context.fc.textDisabled, fontSize: 9)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: color.withValues(alpha: 0.6), size: 18),
          ]),
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
    final stateColor = triggered ? context.fc.error : context.fc.success;
    return Container(
      height: 48,
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.fc.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.fc.surfaceBorder),
      ),
      child: Row(children: [
        Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
                color: axisColor, borderRadius: BorderRadius.circular(2))),
        SizedBox(width: 10),
        Text(axis,
            style: TextStyle(
                color: axisColor,
                fontSize: 14,
                fontWeight: FontWeight.w900)),
        SizedBox(width: 8),
        Text(gpio,
            style: TextStyle(
                color: context.fc.textDisabled,
                fontSize: 10,
                fontFamily: 'JetBrains Mono')),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            SizedBox(width: 6),
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
    final s = triggered ? context.fc.error : context.fc.success;
    return Container(
      height: 48,
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.fc.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.fc.surfaceBorder),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(triggered ? 'DÉCL.' : 'OUVERT',
            style: TextStyle(color: s, fontSize: 8, fontWeight: FontWeight.w900)),
        SizedBox(width: 6),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.fc.surfaceBright, context.fc.surface],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fc.surfaceBorder),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 12,
              spreadRadius: -4),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: context.fc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono')),
        Text(label,
            style: TextStyle(
                color: context.fc.textDisabled,
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.fc.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.engineering, color: context.fc.primary, size: 14),
          SizedBox(width: 8),
          Text(tr('MAINTENANCE PRÉVENTIVE'),
              style: TextStyle(
                  color: context.fc.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ]),
        SizedBox(height: 10),
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
        ? context.fc.error
        : (health < 60 ? context.fc.warning : context.fc.success);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: context.fc.textDisabled, fontSize: 9))),
        Text(timeLeft,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        SizedBox(width: 8),
        SizedBox(
            width: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                  value: health / 100,
                  backgroundColor: context.fc.surfaceBright,
                  color: color,
                  minHeight: 3),
            )),
      ]),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// CINÉMATIQUE ÉDITABLE — lit les vraies valeurs du config.yaml (live ou cache
// offline) et envoie les modifications à FluidNC via `$/axes/<x>/<param>=<v>`.
// ─────────────────────────────────────────────────────────────────────────────
class KinematicsTable extends ConsumerStatefulWidget {
  const KinematicsTable({super.key});
  @override
  ConsumerState<KinematicsTable> createState() => KinematicsTableState();
}

class KinematicsTableState extends ConsumerState<KinematicsTable> {
  final Map<String, double> _overrides = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Synchro depuis la carte à l'ouverture : l'affichage doit refléter la
    // mémoire réelle (config.yaml), pas un cache éventuellement périmé. En cas
    // d'échec réseau, configResultProvider retombe proprement sur le cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(configResultProvider);
    });
  }

  /// Relit les paramètres depuis la carte et abandonne les édits locaux non
  /// enregistrés — pour lever toute ambiguïté « affiché vs mémoire de la carte ».
  void _syncFromBoard() {
    ref.invalidate(configResultProvider);
    setState(() => _overrides.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Lecture des paramètres depuis la carte…'))));
  }

  Color _axisColor(BuildContext c, String axis) => switch (axis) {
        'X' => c.fc.axisX,
        'Y' => c.fc.axisY,
        'Z' => c.fc.axisZ,
        'A' => c.fc.axisA,
        _ => c.fc.axisC,
      };

  double? _value(AxisKinematics k, KinematicField f) {
    final o = _overrides['${k.axis}.${f.name}'];
    if (o != null) return o;
    return switch (f) {
      KinematicField.steps => k.stepsPerMm,
      KinematicField.maxRate => k.maxRate,
      KinematicField.accel => k.accel,
      KinematicField.maxTravel => k.maxTravel,
    };
  }

  Future<void> _edit(AxisKinematics k, KinematicField f) async {
    final fc = context.fc;
    final current = _value(k, f);
    final ctrl = TextEditingController(text: current?.toStringAsFixed(3) ?? '');

    final newVal = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final preview =
              fluidNcSetCommand(k.axis, f, double.tryParse(ctrl.text) ?? 0);
          return AlertDialog(
            backgroundColor: fc.surface,
            title: Text('${k.axis} · ${f.label}',
                style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    onChanged: (_) => setLocal(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    style: TextStyle(
                        color: fc.primary,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 18),
                    decoration: InputDecoration(
                      suffixText: f.unit,
                      suffixStyle: TextStyle(color: fc.textDisabled),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: fc.surfaceBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(tr('COMMANDE FLUIDNC'),
                      style: TextStyle(
                          color: fc.textDisabled,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: fc.terminalBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: fc.surfaceBorder),
                    ),
                    child: Text(preview,
                        style: TextStyle(
                            color: fc.primary,
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 13, color: fc.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          tr('Effet immédiat mais volatil. Sauvez le YAML (onglet CONFIG) pour le rendre permanent.'),
                          style: TextStyle(color: fc.warning, fontSize: 9)),
                    ),
                  ]),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      Text(tr('ANNULER'), style: TextStyle(color: fc.textDisabled))),
              ElevatedButton(
                onPressed: () {
                  final v = double.tryParse(ctrl.text.trim());
                  if (v != null) Navigator.pop(ctx, v);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: fc.primary, foregroundColor: Colors.white),
                child: Text(tr('ENVOYER')),
              ),
            ],
          );
        },
      ),
    );

    if (newVal == null || !mounted) return;
    final cmd = fluidNcSetCommand(k.axis, f, newVal);
    final messenger = ScaffoldMessenger.of(context);
    final okColor = context.fc.success;
    await ref.read(machineRepositoryProvider).sendGCode(cmd);
    if (!mounted) return;
    setState(() => _overrides['${k.axis}.${f.name}'] = newVal);
    messenger.showSnackBar(SnackBar(
        content: Text(tr('Appliqué à chaud (volatil, perdu au reboot). « Enregistrer dans la config » pour la mémoire de la carte.')),
        backgroundColor: okColor,
        duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final async = ref.watch(axisKinematicsProvider);
    final cfg = ref.watch(configResultProvider).valueOrNull;

    Widget headerRow() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: fc.surfaceBright,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(5))),
          child: Row(children: [
            SizedBox(
                width: 30,
                child: Text(tr('AXE'),
                    style: TextStyle(
                        color: fc.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w900))),
            for (final f in KinematicField.values)
              Expanded(
                  child: Text(f.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: fc.textDisabled,
                          fontSize: 9,
                          fontWeight: FontWeight.w900))),
          ]),
        );

    Widget cell(AxisKinematics k, KinematicField f) {
      final v = _value(k, f);
      return Expanded(
        child: InkWell(
          onTap: () => _edit(k, f),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              v == null
                  ? '—'
                  : (v == v.roundToDouble()
                      ? v.toStringAsFixed(0)
                      : v.toStringAsFixed(1)),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: v == null ? fc.textDisabled : fc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono'),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(cfg?.fromCache == true ? Icons.cloud_off : Icons.cloud_done,
              size: 12,
              color: cfg?.fromCache == true ? fc.warning : fc.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              cfg == null
                  ? 'Lecture depuis la carte…'
                  : cfg.fromCache
                      ? 'Hors ligne — valeurs en CACHE (non synchronisées)'
                      : 'Synchronisé avec la carte (config.yaml)',
              style: TextStyle(
                  color: cfg?.fromCache == true ? fc.warning : fc.textDisabled,
                  fontSize: 9),
            ),
          ),
          InkWell(
            onTap: _saving ? null : _syncFromBoard,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sync, size: 13, color: fc.primary),
                const SizedBox(width: 3),
                Text(tr('SYNCHRONISER'),
                    style: TextStyle(
                        color: fc.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: fc.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fc.surfaceBorder),
        ),
        child: async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr('Config indisponible : {}', [e]),
                  style: TextStyle(color: fc.textDisabled, fontSize: 11))),
          data: (axes) {
            final hasAny = axes.any((k) =>
                k.stepsPerMm != null ||
                k.maxRate != null ||
                k.accel != null ||
                k.maxTravel != null);
            return Column(children: [
              headerRow(),
              if (!hasAny)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      tr('Aucune cinématique lue depuis config.yaml (connecte-toi à l\'ESP32 une fois pour la mettre en cache).'),
                      style: TextStyle(color: fc.textDisabled, fontSize: 11)),
                )
              else
                for (final k in axes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: fc.surfaceBorder))),
                    child: Row(children: [
                      SizedBox(
                        width: 30,
                        child: Text(k.axis,
                            style: TextStyle(
                                color: _axisColor(context, k.axis),
                                fontSize: 15,
                                fontWeight: FontWeight.w900)),
                      ),
                      for (final f in KinematicField.values) cell(k, f),
                    ]),
                  ),
            ]);
          },
        ),
      ),
      const SizedBox(height: 6),
      Text(tr('Touchez une valeur : appliquée à chaud (volatile). « Enregistrer » l\'écrit dans la mémoire de la carte.'),
          style: TextStyle(color: fc.textDisabled, fontSize: 9)),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _saveToConfig,
          style: ElevatedButton.styleFrom(
            backgroundColor: fc.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(
              _saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              size: 18),
          label: Text(
              _saving ? 'ENREGISTREMENT…' : 'ENREGISTRER DANS LA CONFIG FLUIDNC',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 4),
      Text(
          tr('Écrit les valeurs actuelles dans config.yaml (permanent) puis redémarre FluidNC pour les appliquer.'),
          style: TextStyle(color: fc.textDisabled, fontSize: 9)),
    ]);
  }

  Future<void> _saveToConfig() async {
    final fc = context.fc;
    final kin = ref.read(axisKinematicsProvider).valueOrNull;
    if (kin == null || kin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Cinématique indisponible (config non chargée).'))));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text(tr('Enregistrer dans FluidNC ?'),
            style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Les valeurs de cinématique actuelles seront écrites dans config.yaml (permanent), puis FluidNC redémarrera pour les appliquer.'),
              style:
                  TextStyle(color: fc.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fc.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fc.warning.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: fc.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Le redémarrage va couper la liaison : l\'app sera déconnectée quelques secondes, le temps que l\'ESP32 reboote. La reconnexion est automatique.'),
                    style: TextStyle(
                        color: fc.warning, fontSize: 11, height: 1.35),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text(tr('Annuler'), style: TextStyle(color: fc.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: fc.primary, foregroundColor: Colors.white),
            child: Text(tr('Enregistrer & redémarrer')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final okColor = context.fc.success;
    final errColor = context.fc.error;
    try {
      // On repart du YAML déjà chargé (évite un GET fragile sur l'AP ESP32).
      final yaml = ref.read(configResultProvider).valueOrNull?.yaml;
      if (yaml == null || !yaml.contains('axes:')) {
        throw Exception('config.yaml non chargé ou sans section axes '
            '(machine hors ligne ?)');
      }
      // Construit {axe: {clé_yaml: valeur}} depuis l'affichage (overrides inclus).
      final byAxis = <String, Map<String, double>>{};
      for (final k in kin) {
        final m = <String, double>{};
        for (final f in KinematicField.values) {
          final v = _value(k, f);
          if (v != null) m[f.yamlKey] = v;
        }
        if (m.isNotEmpty) byAxis[k.axis.toLowerCase()] = m;
      }
      final patched = patchAxisKinematicsYaml(yaml, byAxis);

      try {
        await ref.read(configRepositoryProvider).saveConfig(patched);
        // Les édits locaux sont maintenant dans config.yaml → on abandonne les
        // overrides pour que l'affichage relise la carte (source de vérité).
        if (mounted) setState(() => _overrides.clear());
        ref.invalidate(configResultProvider);
        ref.read(machineRepositoryProvider).sendRaw('\$Bye\n');
        messenger.showSnackBar(SnackBar(
            content: Text(tr('Config enregistrée — redémarrage de FluidNC…')),
            backgroundColor: okColor));
      } catch (_) {
        // Écriture auto impossible (endpoint non supporté) → repli fiable :
        // on copie la config patchée pour la coller dans la WebUI FluidNC.
        await Clipboard.setData(ClipboardData(text: patched));
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(
              tr('Écriture auto impossible. Config copiée : colle-la dans la WebUI FluidNC (192.168.0.1 → Files → config.yaml), puis reboot.')),
          backgroundColor: errColor,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Échec : {}', [e])),
          backgroundColor: errColor,
          duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
