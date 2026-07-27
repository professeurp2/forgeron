import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/jog_provider.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import '../../domain/models/machine_state.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_highlighter.dart';
import '../widgets/mobile/mobile_visualizer_panel.dart';
import '../widgets/mobile/mobile_tab_bar.dart';
import '../tutorial/tutorial_keys.dart';

/// Dashboard Mobile "Forge Pro" — Version Épurée
/// Focus sur la lisibilité maximale, suppression du désordre visuel.
class MobileDashboardScreen extends ConsumerStatefulWidget {
  const MobileDashboardScreen({super.key});
  @override
  ConsumerState<MobileDashboardScreen> createState() =>
      _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends ConsumerState<MobileDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showSimulator = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineStateProvider).valueOrNull;

    return Column(
      children: [
        // ── Barre d'onglets épurée (Seulement 3 sections claires) ──────────
        MobileTabBar(
          key: TutorialKeys.mobileTabs,
          controller: _tabController,
          tabs: const [
            MobileTab(Icons.analytics_outlined, 'MASTER'),
            MobileTab(Icons.open_with_rounded, 'JOG'),
            MobileTab(Icons.code_rounded, 'PROGRAMME'),
          ],
        ),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _MasterTab(state: state, showSim: _showSimulator, onToggleSim: () => setState(() => _showSimulator = !_showSimulator)),
              _JogTab(state: state),
              _ProgramTab(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 1 : MASTER (DRO + ACTIONS CRITIQUES)
// ─────────────────────────────────────────────────────────────────────────────
class _MasterTab extends ConsumerWidget {
  final MachineState? state;
  final bool showSim;
  final VoidCallback onToggleSim;

  const _MasterTab({required this.state, required this.showSim, required this.onToggleSim});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final wPos = state?.wPos ?? List.filled(5, 0.0);
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MobileStatusBanner(isOnline: isOnline, status: state?.status),
          const SizedBox(height: 16),

          // ── Simulateur 3D Compact ──
          GestureDetector(
            key: TutorialKeys.mobileSimulator,
            onTap: onToggleSim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: fc.surfaceBright,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fc.surfaceBorder),
              ),
              child: Row(children: [
                Icon(Icons.view_in_ar, size: 18, color: fc.primary),
                const SizedBox(width: 10),
                Text('SIMULATEUR 3D',
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
                const Spacer(),
                Icon(showSim ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: fc.textDisabled),
              ]),
            ),
          ),
          if (showSim) ...[
            const SizedBox(height: 8),
            const SizedBox(height: 240, child: MobileVisualizerPanel(expand: true)),
          ],

          const SizedBox(height: 16),
          // ── DRO en grille : axes linéaires (X Y Z) puis rotatifs (A C) ──
          Row(
            children: [
              Expanded(child: _AxisTile('X', wPos[0], fc.axisX, 'mm')),
              const SizedBox(width: 10),
              Expanded(child: _AxisTile('Y', wPos[1], fc.axisY, 'mm')),
              const SizedBox(width: 10),
              Expanded(child: _AxisTile('Z', wPos[2], fc.axisZ, 'mm')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AxisTile('A', wPos[3], fc.axisA, '°')),
              const SizedBox(width: 10),
              Expanded(child: _AxisTile('C', wPos[4], fc.axisC, '°')),
            ],
          ),

          const SizedBox(height: 24),
          // ── MODE ATELIER ──
          Material(
            key: TutorialKeys.mobileNav, // Détourné pour pointer le mode atelier dans le tuto
            color: fc.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => ref.read(isWorkshopModeProvider.notifier).state = true,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: fc.primary.withValues(alpha: 0.45), width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.factory_rounded, color: fc.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('ACTIVER MODE ATELIER',
                        style: TextStyle(
                            color: fc.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: fc.textDisabled, size: 14),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          // ── ACTIONS DE CYCLE (Accessibles immédiatement) ──
          _MasterActionButton(
            label: state?.status == MachineStatus.hold ? 'REPRENDRE' : 'DÉPART CYCLE',
            icon: Icons.play_arrow_rounded,
            color: fc.success,
            onTap: () => _handleStart(context, ref),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MasterActionButton(
                  label: 'PAUSE',
                  icon: Icons.pause_rounded,
                  color: fc.warning,
                  onTap: () => ref.read(machineRepositoryProvider).pause(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MasterActionButton(
                  label: 'STOP',
                  icon: Icons.stop_rounded,
                  color: fc.danger,
                  onTap: () => ref.read(machineRepositoryProvider).reset(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleStart(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(machineRepositoryProvider);
    final latest = ref.read(machineStateProvider).valueOrNull;
    if (latest?.status == MachineStatus.hold) {
      repo.resume();
    } else {
      // On capture messenger + couleur AVANT l'await (context ne doit pas être
      // réutilisé après un gap async).
      final messenger = ScaffoldMessenger.of(context);
      final errColor = context.fc.error;
      final result = await ref.read(streamingProvider.notifier).startStream();
      if (!result.isValid) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur: ${result.errorMessage}'),
          backgroundColor: errColor,
        ));
      }
    }
    HapticFeedback.mediumImpact();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 2 : JOG (MOUVEMENTS)
// ─────────────────────────────────────────────────────────────────────────────
class _JogTab extends ConsumerWidget {
  final MachineState? state;
  const _JogTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Rappel DRO compact pour le JOG
          _CompactDroStrip(wPos: wPos),
          const SizedBox(height: 20),
          JogControlPanel(wPos: wPos),
          const SizedBox(height: 20),
          _MasterActionButton(
            label: 'STOP JOG',
            icon: Icons.pan_tool_rounded,
            color: context.fc.danger,
            onTap: () {
              ref.read(secureJogProvider.notifier).stopJog();
              HapticFeedback.heavyImpact();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 3 : PROGRAMME (G-CODE)
// ─────────────────────────────────────────────────────────────────────────────
class _ProgramTab extends ConsumerWidget {
  final MachineState? state;
  const _ProgramTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final gcodeState = ref.watch(gcodeProvider);
    final currentIndex = state?.activeLineIndex ?? 0;
    final lines = gcodeState.allLines;

    return Column(
      children: [
        // Macros en haut pour accès rapide
        _QuickMacrosBar(repo: ref.read(machineRepositoryProvider)),
        
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: fc.terminalBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: lines.isEmpty 
              ? _buildEmptyState(fc)
              : _buildGCodeList(lines, currentIndex, fc),
          ),
        ),

        // Console et Chargement
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(child: _MobileGCodeInput(repo: ref.read(machineRepositoryProvider))),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.file_open_rounded,
                color: fc.primary,
                onTap: () async {
                  final content = await FilePickerService.pickGCodeContent();
                  if (content != null) {
                    await ref.read(gcodeProvider.notifier).loadFile(content);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ForgeronColorPalette fc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, color: fc.textDisabled, size: 48),
          const SizedBox(height: 12),
          Text('Aucun programme chargé', style: TextStyle(color: fc.textDisabled, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGCodeList(List<String> lines, int current, ForgeronColorPalette fc) {
    return ListView.builder(
      itemCount: lines.length,
      itemExtent: 32,
      itemBuilder: (ctx, i) {
        final isCurrent = i == current;
        return Container(
          color: isCurrent ? fc.primary.withValues(alpha: 0.15) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Text('${i + 1}'.padLeft(4), style: TextStyle(color: isCurrent ? fc.primary : fc.textDisabled, fontSize: 11, fontFamily: 'JetBrains Mono')),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14, fontFamily: 'JetBrains Mono'),
                  children: GCodeHighlighter.buildSpans(lines[i], isCurrent),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSANTS DE DESIGN ÉPURÉS
// ─────────────────────────────────────────────────────────────────────────────

/// Tuile DRO d'un axe : pastille + lettre + unité en tête, valeur en gros
/// dessous. Pensée pour une grille (3 linéaires / 2 rotatifs) : compacte,
/// alignée, et la valeur se réduit via [FittedBox] plutôt que de déborder.
class _AxisTile extends StatelessWidget {
  final String axis;
  final double value;
  final Color color;
  final String unit;

  const _AxisTile(this.axis, this.value, this.color, this.unit);

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc.surfaceBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(axis,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text(unit,
                  style: TextStyle(
                      color: fc.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value.toStringAsFixed(3),
              maxLines: 1,
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono',
                  letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MasterActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52, // hauteur unifiée avec les autres boutons du MASTER
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDroStrip extends StatelessWidget {
  final List<double> wPos;
  const _CompactDroStrip({required this.wPos});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final axes = [('X', fc.axisX), ('Y', fc.axisY), ('Z', fc.axisZ), ('A', fc.axisA), ('C', fc.axisC)];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fc.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < 5; i++)
            Column(children: [
              Text(axes[i].$1, style: TextStyle(color: axes[i].$2, fontWeight: FontWeight.bold, fontSize: 10)),
              Text(wPos[i].toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
            ]),
        ],
      ),
    );
  }
}

class _QuickMacrosBar extends StatelessWidget {
  final dynamic repo;
  const _QuickMacrosBar({required this.repo});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final macros = [('G28', 'G28'), ('G0 Z5', 'G0 Z5'), ('M3 S8000', 'M3 S8000'), ('M5', 'M5')];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: macros.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(macros[i].$1, style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
            backgroundColor: fc.surfaceBright,
            onPressed: () => repo.sendGCode(macros[i].$2),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
    );
  }
}

class _MobileStatusBanner extends StatelessWidget {
  final bool isOnline;
  final MachineStatus? status;
  const _MobileStatusBanner({required this.isOnline, this.status});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final color = isOnline ? _statusColor(context) : fc.textDisabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 12),
          const SizedBox(width: 12),
          Text(isOnline ? 'ESP32 CONNECTÉ' : 'HORS LIGNE', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
          const Spacer(),
          Text(status?.name.toUpperCase() ?? '-', style: TextStyle(color: color, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    switch (status) {
      case MachineStatus.idle: return context.fc.success;
      case MachineStatus.run: return context.fc.primary;
      case MachineStatus.hold: return context.fc.warning;
      case MachineStatus.alarm: return context.fc.error;
      default: return context.fc.textDisabled;
    }
  }
}

class _MobileGCodeInput extends ConsumerStatefulWidget {
  final dynamic repo;
  const _MobileGCodeInput({required this.repo});
  @override
  ConsumerState<_MobileGCodeInput> createState() => _MobileGCodeInputState();
}

class _MobileGCodeInputState extends ConsumerState<_MobileGCodeInput> {
  final _ctrl = TextEditingController();
  void _send() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.repo.sendGCode(_ctrl.text.trim());
    _ctrl.clear();
  }
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      style: TextStyle(color: context.fc.primary, fontFamily: 'JetBrains Mono'),
      decoration: InputDecoration(
        hintText: 'Envoyer G-Code...',
        filled: true,
        fillColor: context.fc.terminalBg,
        suffixIcon: IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onSubmitted: (_) => _send(),
    );
  }
}
