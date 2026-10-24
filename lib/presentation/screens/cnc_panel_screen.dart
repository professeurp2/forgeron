import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/jog_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../application/services/audio_service.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/cnc_panel_widgets.dart';
import '../widgets/trunnion_visualizer.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import '../../core/i18n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CNC PANEL SCREEN — Pupitre CNC 5 Axes style FANUC 0i-M
//
// Remplace le WorkshopLayout. Layout desktop/tablette uniquement (min 800px).
// Architecture :
//   ┌──────────────────────── HEADER ──────────────────────────────────────┐
//   │  LCD DISPLAY (DRO + état)      │  PANNEAU DE TOUCHES                │
//   │  • DRO 5 axes                  │  • Sélecteur de mode               │
//   │  • Statut modal                │  • Cycle (Start / Hold / Reset)    │
//   │  • Outil & WCS                 │  • Overrides F% S%                 │
//   │  • F / S courants              │  • Jog XYZ + A/C                  │
//   │                                │  • Sélect. pas                     │
//   └──────────────────────── FOOTER ──────────────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider du mode machine sélectionné sur le pupitre (AUTO/MDI/MEM/JOG/HANDLE).
final cncPanelModeProvider = StateProvider<CncOperatingMode>((ref) => CncOperatingMode.auto);


enum CncOperatingMode { auto, mdi, mem, jog, handle }

extension CncOperatingModeExt on CncOperatingMode {
  String get label {
    switch (this) {
      case CncOperatingMode.auto: return 'AUTO';
      case CncOperatingMode.mdi: return 'MDI';
      case CncOperatingMode.mem: return 'MEM';
      case CncOperatingMode.jog: return 'JOG';
      case CncOperatingMode.handle: return 'HANDLE';
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────────

class CncPanelScreen extends ConsumerWidget {
  const CncPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineState = ref.watch(machineStateProvider);
    final state = machineState.valueOrNull;
    final repo = ref.read(machineRepositoryProvider);

    return Container(
      // Gradient linéaire simulant une plaque de métal brossé d'un pupitre industriel
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.fc.panelBody,
            Color(0xFF14192F),
            context.fc.panelBody,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _PanelHeader(state: state),

            // ── Corps principal ────────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  // ── Colonne gauche : LCD Display ─────────────────────────
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _LcdDisplayColumn(state: state),
                    ),
                  ),

                  // ── Rainure verticale embossée double-ligne ──
                  Container(
                    width: 6,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.black.withValues(alpha: 0.65), width: 2),
                        right: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 2),
                      ),
                    ),
                  ),

                  // ── Colonne centrale : Visualisateur ──────────────────
                  Expanded(
                    flex: 4,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        border: Border.all(color: context.fc.surfaceBorder, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TrunnionVisualizer(
                          mPos: ref.watch(renderMPosProvider),
                        ),
                      ),
                    ),
                  ),

                  // ── Rainure verticale embossée double-ligne ──
                  Container(
                    width: 6,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.black.withValues(alpha: 0.65), width: 2),
                        right: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 2),
                      ),
                    ),
                  ),

                  // ── Colonne droite : Panneau de touches ──────────────────
                  Expanded(
                    flex: 3,
                    child: _TouchPanel(state: state, repo: repo),
                  ),
                ],
              ),
            ),

            // ── Footer statut ──────────────────────────────────────────────
            _PanelFooter(state: state),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER DU PUPITRE
// ═══════════════════════════════════════════════════════════════════════════════

class _PanelHeader extends ConsumerWidget {
  final MachineState? state;
  const _PanelHeader({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;
    final statusColor = _statusColor(context, state?.status ?? MachineStatus.offline);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.fc.panelSection,
        border: Border(
          bottom: BorderSide(color: context.fc.keyBorder, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Logo + titre
          CncLedIndicator(
            color: isOnline ? context.fc.success : context.fc.danger,
            isActive: isOnline,
            size: 12,
          ),
          SizedBox(width: 10),
          Image.asset('assets/logo.png', height: 28),
          SizedBox(width: 10),
          Text(
            tr('FORGERON'),
            style: TextStyle(
              color: context.fc.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(width: 6),
          Text(
            tr('CNC-5X'),
            style: TextStyle(
              color: context.fc.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
            ),
          ),

          SizedBox(width: 20),

          // Badges status
          _statusBadge(isOnline ? 'EN LIGNE' : 'HORS LIGNE',
              isOnline ? context.fc.success : context.fc.danger),
          SizedBox(width: 8),
          _statusBadge(
              state?.status.name.toUpperCase() ?? 'OFFLINE', statusColor),

          const Spacer(),

          // RTCP Badge
          if (state?.isRtcpActive == true)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.fc.axisZ.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: context.fc.axisZ.withValues(alpha: 0.5)),
              ),
              child: Text(tr('RTCP G43.4'),
                  style: TextStyle(
                      color: context.fc.axisZ,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
            ),

          // Bouton quitter pupitre
          IconButton(
            icon: Icon(Icons.close_fullscreen,
                color: context.fc.textDisabled, size: 20),
            tooltip: tr('Quitter le pupitre'),
            onPressed: () =>
                ref.read(isWorkshopModeProvider.notifier).state = false,
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 6)],
          ),
        ),
        SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8)),
      ]),
    );
  }

  Color _statusColor(BuildContext context, MachineStatus s) {
    switch (s) {
      case MachineStatus.idle: return context.fc.success;
      case MachineStatus.run: return context.fc.primary;
      case MachineStatus.hold: return context.fc.warning;
      case MachineStatus.alarm: return context.fc.danger;
      case MachineStatus.home: return context.fc.axisZ;
      default: return context.fc.textDisabled;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LCD DISPLAY COLUMN — Colonne gauche avec écrans LCD
// ═══════════════════════════════════════════════════════════════════════════════

class _LcdDisplayColumn extends StatelessWidget {
  final MachineState? state;
  const _LcdDisplayColumn({required this.state});

  @override
  Widget build(BuildContext context) {
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return Column(
      children: [
        // ── LCD principal : DRO position pièce ──────────────────────────
        const CncSectionLabel('POSITION PIÈCE (W)  —  AXES 5'),
        Expanded(
          flex: 5,
          child: CncLcdScreen(
            title: tr('COORDONNÉES DE TRAVAIL'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CncLcdAxisRow(axis: 'X', value: wPos[0], axisColor: context.fc.axisX, fontSize: 36),
                  CncLcdAxisRow(axis: 'Y', value: wPos[1], axisColor: context.fc.axisY, fontSize: 36),
                  CncLcdAxisRow(axis: 'Z', value: wPos[2], axisColor: context.fc.axisZ, fontSize: 36),
                  Divider(color: context.fc.lcdBorder, indent: 12, endIndent: 12, height: 8),
                  CncLcdAxisRow(axis: 'A', value: wPos[3], axisColor: context.fc.axisA, isRotary: true, fontSize: 26),
                  CncLcdAxisRow(axis: 'C', value: wPos[4], axisColor: context.fc.axisC, isRotary: true, fontSize: 26),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: 8),

        // ── Ligne basse : 3 mini-LCD ─────────────────────────────────────
        Expanded(
          flex: 3,
          child: Row(
            children: [
              // LCD position machine
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CncSectionLabel('POSITION MACHINE (M)'),
                    Expanded(
                      child: CncLcdScreen(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _mPosRow(context, 'X', mPos[0], context.fc.axisX),
                              _mPosRow(context, 'Y', mPos[1], context.fc.axisY),
                              _mPosRow(context, 'Z', mPos[2], context.fc.axisZ),
                              _mPosRow(context, 'A', mPos[3], context.fc.axisA, isRotary: true),
                              _mPosRow(context, 'C', mPos[4], context.fc.axisC, isRotary: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              // LCD état modal
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CncSectionLabel('ÉTAT MODAL'),
                    Expanded(
                      child: CncLcdScreen(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _modalRow(context, 'WCS', state?.activeWCS ?? 'G54'),
                              _modalRow(context, 'OUTIL', 'T${state?.activeToolNum ?? 0}'),
                              _modalRow(context, 'F réel',
                                  '${state?.feedrate.toInt() ?? 0}', unit: 'mm/min'),
                              _modalRow(context, 'S réel',
                                  '${state?.spindleSpeed.toInt() ?? 0}', unit: 'RPM'),
                              Divider(color: context.fc.lcdBorder, height: 6),
                              _overrideRow(context, 'F%', state?.overrides != null ? state!.overrides[0] : 100, context.fc.primary),
                              _overrideRow(context, 'S%', state?.overrides != null ? state!.overrides[2] : 100, context.fc.secondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mPosRow(BuildContext context, String axis, double val, Color color, {bool isRotary = false}) {
    return Row(children: [
      Text(axis,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'JetBrains Mono')),
      const Spacer(),
      Text(
        isRotary ? '${val.toStringAsFixed(2)}°' : val.toStringAsFixed(3),
        style: TextStyle(
          color: context.fc.lcdTextDim,
          fontSize: 11,
          fontFamily: 'JetBrains Mono',
        ),
      ),
    ]);
  }

  Widget _modalRow(BuildContext context, String label, String value, {String? unit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: context.fc.lcdTextDim,
                fontSize: 9,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.bold)),
        const Spacer(),
        const SizedBox(width: 8),
        // Flexible + ellipse : « F reel » suivi de « 0 mm/min » ne tenait pas
        // dans la colonne etroite du pupitre, et la ligne debordait (bandes
        // jaunes et noires par-dessus l'etat modal).
        Flexible(
          child: Text(
            unit != null ? '$value $unit' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.fc.lcdText,
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _overrideRow(BuildContext context, String label, int value, Color color) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              color: context.fc.lcdTextDim,
              fontSize: 9,
              fontFamily: 'JetBrains Mono')),
      SizedBox(width: 6),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 2.0),
            minHeight: 4,
            backgroundColor: context.fc.lcdBorder,
            color: color,
          ),
        ),
      ),
      SizedBox(width: 6),
      Text('$value%',
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w900)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOUCH PANEL — Colonne droite avec les touches du pupitre
// ═══════════════════════════════════════════════════════════════════════════════

class _TouchPanel extends ConsumerWidget {
  final MachineState? state;
  final dynamic repo;
  const _TouchPanel({required this.state, required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Sélecteur de mode opératoire ──────────────────────────────
          _ModeSelector(),
          SizedBox(height: 12),

          // ── 2. Panneau de cycle ───────────────────────────────────────────
          _CyclePanel(repo: repo),
          SizedBox(height: 12),

          // ── 3. Overrides F% et S% ─────────────────────────────────────────
          _OverridePanel(repo: repo, state: state),
          SizedBox(height: 12),

          // ── 4. Panneau de jog 5 axes ──────────────────────────────────────
          _JogPanel5Axis(),
        ],
      ),
    );
  }
}

// ─── Sélecteur de Mode ────────────────────────────────────────────────────────

class _ModeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(cncPanelModeProvider);

    return CncPanelSectionContainer(
      title: tr('MODE OPÉRATOIRE'),
      child: Row(
        children: CncOperatingMode.values.map((m) {
          final sel = m == mode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: CncKeyButton(
                height: 44,
                color: context.fc.primary,
                isActive: sel,
                onTap: () {
                  ref.read(cncPanelModeProvider.notifier).state = m;
                  HapticFeedback.selectionClick();
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CncLedIndicator(
                      color: context.fc.success,
                      isActive: sel,
                      size: 7,
                    ),
                    SizedBox(height: 3),
                    Text(
                      m.label,
                      style: TextStyle(
                        color: sel
                            ? context.fc.primary
                            : context.fc.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Panneau Cycle ────────────────────────────────────────────────────────────

class _CyclePanel extends ConsumerWidget {
  final dynamic repo;
  const _CyclePanel({required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CncPanelSectionContainer(
      title: tr('CONTRÔLE CYCLE'),
      child: Column(
        children: [
          // Cycle Start — grande touche verte
          CncKeyButton(
            height: 64,
            color: context.fc.success,
            onTap: () {
              ref.read(audioServiceProvider).play(SoundEffect.click);
              final status = ref.read(machineStateProvider).valueOrNull?.status;
              if (status == MachineStatus.hold) {
                repo.resume();
              } else if (status == MachineStatus.idle) {
                ref.read(streamingProvider.notifier).startStream();
              }
              HapticFeedback.mediumImpact();
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CncLedIndicator(color: context.fc.success, isActive: true, size: 10),
              SizedBox(width: 10),
              Icon(Icons.play_arrow_rounded, color: context.fc.success, size: 22),
              SizedBox(width: 6),
              Text(tr('CYCLE START'),
                  style: TextStyle(
                      color: context.fc.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0)),
            ]),
          ),
          SizedBox(height: 8),
          Row(children: [
            // Feed Hold
            Expanded(
              child: CncKeyButton(
                height: 52,
                color: context.fc.warning,
                onTap: () {
                  repo.pause();
                  HapticFeedback.lightImpact();
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.pause_rounded, color: context.fc.warning, size: 18),
                  SizedBox(height: 2),
                  Text(tr('FEED HOLD'),
                      style: TextStyle(
                          color: context.fc.warning,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
            SizedBox(width: 8),
            // Reset
            Expanded(
              child: CncKeyButton(
                height: 52,
                color: context.fc.danger,
                isDanger: true,
                onTap: () {
                  repo.sendRaw('\x18');
                  Future.delayed(
                      const Duration(milliseconds: 500),
                      () => repo.sendRaw('\$X\n'));
                  HapticFeedback.heavyImpact();
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.refresh_rounded, color: context.fc.danger, size: 18),
                  SizedBox(height: 2),
                  Text(tr('RESET'),
                      style: TextStyle(
                          color: context.fc.danger,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
            SizedBox(width: 8),
            // E-STOP
            Expanded(
              child: CncKeyButton(
                height: 52,
                color: context.fc.danger,
                isDanger: true,
                onTap: () {
                  // Contrôleur, pas repository : purge du flux + alerte si
                  // l'arrêt n'est pas parti (voir StreamingController).
                  ref.read(streamingProvider.notifier).stopStream();
                  HapticFeedback.heavyImpact();
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.warning_amber_rounded, color: context.fc.danger, size: 18),
                  SizedBox(height: 2),
                  Text(tr('E-STOP'),
                      style: TextStyle(
                          color: context.fc.danger,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Panneau Overrides ────────────────────────────────────────────────────────

class _OverridePanel extends ConsumerStatefulWidget {
  final dynamic repo;
  final MachineState? state;
  const _OverridePanel({required this.repo, required this.state});

  @override
  ConsumerState<_OverridePanel> createState() => _OverridePanelState();
}

class _OverridePanelState extends ConsumerState<_OverridePanel> {
  // Overrides locaux (0–200% affiché en UI, envoyés en commandes GRBL)
  double _feedOverride = 100;
  double _spindleOverride = 100;

  void _adjustFeed(int delta) {
    setState(() => _feedOverride = (_feedOverride + delta).clamp(10, 200));
    // GRBL : 0x91 = +10%, 0x92 = -10%, 0x93 = +1%, 0x94 = -1%
    if (delta == 10) widget.repo.sendRaw('\x91');
    if (delta == -10) widget.repo.sendRaw('\x92');
    if (delta == 1) widget.repo.sendRaw('\x93');
    if (delta == -1) widget.repo.sendRaw('\x94');
  }

  void _adjustSpindle(int delta) {
    setState(() => _spindleOverride = (_spindleOverride + delta).clamp(10, 200));
    if (delta == 10) widget.repo.sendRaw('\x9A');
    if (delta == -10) widget.repo.sendRaw('\x9B');
    if (delta == 1) widget.repo.sendRaw('\x9C');
    if (delta == -1) widget.repo.sendRaw('\x9D');
  }

  @override
  Widget build(BuildContext context) {
    return CncPanelSectionContainer(
      title: tr('CORRECTIONS (OVERRIDES)'),
      child: Column(
        children: [
          _overrideRow('AVANCE  F%', _feedOverride, context.fc.primary,
              () => _adjustFeed(10), () => _adjustFeed(-10), () => _adjustFeed(1), () => _adjustFeed(-1)),
          SizedBox(height: 6),
          _overrideRow('BROCHE  S%', _spindleOverride, context.fc.secondary,
              () => _adjustSpindle(10), () => _adjustSpindle(-10), () => _adjustSpindle(1), () => _adjustSpindle(-1)),
        ],
      ),
    );
  }

  Widget _overrideRow(String label, double val, Color color,
      VoidCallback onPlusLg, VoidCallback onMinusLg,
      VoidCallback onPlusSm, VoidCallback onMinusSm) {
    return Row(children: [
      // Étiquette
      SizedBox(
        width: 70,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.fc.textDisabled,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0)),
            SizedBox(height: 2),
            Text('${val.toInt()}%',
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono')),
          ],
        ),
      ),

      // Barre de progression
      Expanded(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (val / 200).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: context.fc.keyBezel,
                color: color,
              ),
            ),
          ],
        ),
      ),

      SizedBox(width: 8),

      // Boutons +/- 10%
      CncKeyButton(
        width: 32, height: 30,
        color: color,
        onTap: onMinusLg,
        child: Center(
          child: Text('-10', style: TextStyle(color: context.fc.textSecondary, fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      ),
      SizedBox(width: 3),
      CncKeyButton(
        width: 32, height: 30,
        color: color,
        onTap: onMinusSm,
        child: Center(
          child: Text('-1', style: TextStyle(color: context.fc.textSecondary, fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      ),
      SizedBox(width: 3),
      CncKeyButton(
        width: 32, height: 30,
        color: color,
        onTap: onPlusSm,
        child: Center(
          child: Text('+1', style: TextStyle(color: context.fc.textSecondary, fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      ),
      SizedBox(width: 3),
      CncKeyButton(
        width: 32, height: 30,
        color: color,
        onTap: onPlusLg,
        child: Center(
          child: Text('+10', style: TextStyle(color: context.fc.textSecondary, fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      ),
    ]);
  }
}

// ─── Panneau JOG 5 Axes ───────────────────────────────────────────────────────

class _JogPanel5Axis extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jogN = ref.read(secureJogProvider.notifier);
    final mode = ref.watch(cncPanelModeProvider);
    final isJogEnabled = mode == CncOperatingMode.jog || mode == CncOperatingMode.handle;

    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final wPos = machineState?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];

    return Opacity(
      opacity: isJogEnabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !isJogEnabled,
        child: CncPanelSectionContainer(
          title: tr('JOG MANUEL 5 AXES'),
          trailing: !isJogEnabled
              ? Text(
                  tr('MODE JOG REQUIS'),
                  style: TextStyle(
                    color: context.fc.warning,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Design unifié avec le panneau JOG CONTROL du Dashboard.
              JogControlPanel(wPos: wPos, showHeader: false),
              SizedBox(height: 16),
              // JOG STOP global
              CncKeyButton(
                height: 44,
                color: context.fc.danger,
                isDanger: true,
                onTap: () { jogN.stopJog(); HapticFeedback.heavyImpact(); },
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.stop_rounded, color: context.fc.danger, size: 18),
                  SizedBox(width: 8),
                  Text(tr('JOG STOP  [0x85]'),
                      style: TextStyle(
                          color: context.fc.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════════
// FOOTER DU PUPITRE
// ═══════════════════════════════════════════════════════════════════════════════

class _PanelFooter extends StatelessWidget {
  final MachineState? state;
  const _PanelFooter({required this.state});

  @override
  Widget build(BuildContext context) {
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final feed = state?.feedrate.toInt() ?? 0;
    final spindle = state?.spindleSpeed.toInt() ?? 0;
    final tool = state?.activeToolNum ?? 0;
    final wcs = state?.activeWCS ?? 'G54';
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.fc.panelSection,
        border: Border(top: BorderSide(color: context.fc.keyBorder, width: 1)),
      ),
      child: Row(
        children: [
          Text(tr('FORGERON CNC-5X  v1.0'),
              style: TextStyle(
                  color: context.fc.textDisabled,
                  fontSize: 9,
                  fontFamily: 'JetBrains Mono')),
          SizedBox(width: 20),
          Text(
            'M: X${mPos[0].toStringAsFixed(2)}  Y${mPos[1].toStringAsFixed(2)}  Z${mPos[2].toStringAsFixed(2)}  A${mPos[3].toStringAsFixed(1)}°  C${mPos[4].toStringAsFixed(1)}°',
            style: TextStyle(
                color: context.fc.primary,
                fontSize: 9,
                fontFamily: 'JetBrains Mono'),
          ),
          const Spacer(),
          _footerChip('F: $feed mm/min', context.fc.primary),
          SizedBox(width: 8),
          _footerChip('S: $spindle RPM', context.fc.secondary),
          SizedBox(width: 8),
          _footerChip('T$tool', context.fc.warning),
          SizedBox(width: 8),
          _footerChip(wcs, context.fc.axisZ),
          SizedBox(width: 8),
          CncLedIndicator(
            color: isOnline ? context.fc.success : context.fc.danger,
            isActive: isOnline,
            size: 8,
          ),
          SizedBox(width: 4),
          Text(isOnline ? 'ESP32' : 'OFFLINE',
              style: TextStyle(
                  color: isOnline ? context.fc.success : context.fc.danger,
                  fontSize: 9,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _footerChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w900)),
    );
  }
}

