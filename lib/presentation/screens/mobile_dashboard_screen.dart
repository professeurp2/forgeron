import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/machine_params_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/jog_provider.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import '../../domain/models/machine_state.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../application/providers/stream_progress_provider.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_highlighter.dart';
import '../widgets/mobile/mobile_visualizer_panel.dart';
import '../widgets/mobile/mobile_tab_bar.dart';
import '../widgets/mobile/tool_change_banner.dart';
import '../widgets/mobile/override_panel.dart';
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

    // Avertissements de l'adaptateur G-code au chargement d'un programme (codes
    // CAM traduits, ou blocage si incompatible → à corriger dans le post).
    ref.listen(gcodeProvider, (prev, next) {
      if (next.isLoading || next.adaptWarnings.isEmpty) return;
      if (identical(prev?.adaptWarnings, next.adaptWarnings)) return;
      final fc = context.fc;
      final blocked = next.adaptBlocking;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${blocked ? '⛔ ' : '✓ '}G-code adapté — '
          '${next.adaptWarnings.length} point(s). ${next.adaptWarnings.first}'
          '${blocked ? ' Corrige le post CAM avant d\'exécuter.' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: blocked ? fc.danger : fc.surfaceBright,
        duration: Duration(seconds: blocked ? 7 : 4),
      ));
    });

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
    // Position MACHINE : elle seule situe l'axe dans sa course.
    final mPos = state?.mPos ?? List.filled(5, 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

          const SizedBox(height: 12),
          // ── DRO : une seule carte, cinq lignes alignées ──
          _DroCard(wPos: wPos, mPos: mPos),

          const SizedBox(height: 14),
          // ── CORRECTIONS ──
          // Juste au-dessus des actions de cycle : c'est le levier qu'on
          // cherche quand la passe est déjà lancée et qu'elle va trop vite.
          const OverridePanel(),

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

    // Trois zones plutot qu'une seule vue defilante.
    //
    // Le DRO et l'arret restent a l'ecran en permanence ; seuls les organes de
    // commande defilent. Auparavant tout defilait ensemble : pour arreter un
    // mouvement il fallait d'abord faire remonter le bouton, ce qui est
    // exactement ce qu'on ne veut pas d'une commande d'arret.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _CompactDroStrip(wPos: wPos),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: JogControlPanel(wPos: wPos),
          ),
        ),
        // Epingle, et separe visuellement de ce qui defile au-dessus.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: context.fc.background,
            border: Border(
                top: BorderSide(color: context.fc.surfaceBorderDim)),
          ),
          child: SafeArea(
            top: false,
            child: _MasterActionButton(
              label: 'STOP JOG',
              icon: Icons.pan_tool_rounded,
              color: context.fc.danger,
              onTap: () {
                ref.read(secureJogProvider.notifier).stopJog();
                HapticFeedback.heavyImpact();
              },
            ),
          ),
        ),
      ],
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
    final progress = ref.watch(streamProgressProvider);

    return Column(
      children: [
        // Quel outil monter, pendant une pause de changement. Placé avant la
        // progression : à cet instant c'est la seule information qui compte.
        const ToolChangeBanner(),
        // Panneau de progression, visible pendant l'exécution.
        if (progress.active) _ExecutionProgressPanel(fc: fc, p: progress),
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
              : _GCodeListView(
                  lines: lines, current: currentIndex, running: progress.active),
          ),
        ),

        // Console et Chargement
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              const Expanded(child: _MobileGCodeInput()),
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

}

/// Panneau esthétique de progression pendant l'exécution d'un programme :
/// anneau de %, ligne courante, temps écoulé / restant, barre de progression.
class _ExecutionProgressPanel extends StatelessWidget {
  final ForgeronColorPalette fc;
  final StreamProgress p;
  const _ExecutionProgressPanel({required this.fc, required this.p});

  @override
  Widget build(BuildContext context) {
    final eta = p.eta;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fc.primary.withValues(alpha: 0.12), fc.surface],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: p.fraction,
                        strokeWidth: 5,
                        backgroundColor: fc.surfaceBorder,
                        color: fc.primary,
                      ),
                    ),
                    Text('${p.percent}%',
                        style: TextStyle(
                            color: fc.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.play_arrow_rounded, size: 14, color: fc.primary),
                      const SizedBox(width: 6),
                      Text('EXÉCUTION EN COURS',
                          style: TextStyle(
                              color: fc.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _stat(Icons.tag, 'LIGNE', '${p.currentLine}/${p.totalLines}'),
                      _stat(Icons.timer_outlined, 'ÉCOULÉ',
                          formatDuration(p.elapsed)),
                      _stat(Icons.hourglass_bottom_rounded, 'RESTANT',
                          eta != null ? formatDuration(eta) : '—'),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 6,
              backgroundColor: fc.surfaceBorder,
              color: fc.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: fc.textDisabled),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(color: fc.textDisabled, fontSize: 9)),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}

/// Liste G-code qui surligne la ligne courante et défile automatiquement vers
/// elle pendant l'exécution (fini l'usinage « à l'aveugle »).
class _GCodeListView extends StatefulWidget {
  final List<String> lines;
  final int current;
  final bool running;
  const _GCodeListView(
      {required this.lines, required this.current, required this.running});

  @override
  State<_GCodeListView> createState() => _GCodeListViewState();
}

class _GCodeListViewState extends State<_GCodeListView> {
  final _ctrl = ScrollController();
  static const double _extent = 32.0;

  @override
  void initState() {
    super.initState();
    // À l'ouverture de l'écran, se placer d'emblée sur la ligne en cours.
    //
    // Sans ça la liste s'ouvrait en tête : sur un programme de plusieurs
    // milliers de lignes, l'opérateur devait chercher lui-même où en était la
    // machine. Et le suivi de `didUpdateWidget` ne le sauvait pas — il ne se
    // déclenche qu'au CHANGEMENT de ligne, donc jamais pendant une pause de
    // changement d'outil, précisément le moment où l'on vient regarder.
    //
    // Après le premier frame : le ScrollController n'a pas encore de client
    // tant que la liste n'est pas montée.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrent(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _GCodeListView old) {
    super.didUpdateWidget(old);
    if (widget.running && widget.current != old.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  /// [animate] à `false` pour le positionnement d'ouverture : dérouler quatre
  /// mille lignes sous les yeux de l'opérateur n'apporte rien et retarde
  /// l'affichage de ce qu'il est venu voir.
  void _scrollToCurrent({bool animate = true}) {
    if (!_ctrl.hasClients) return;
    final vp = _ctrl.position.viewportDimension;
    final target = (widget.current * _extent) - vp / 2 + _extent / 2;
    final clamped = target.clamp(0.0, _ctrl.position.maxScrollExtent);

    if (!animate) {
      _ctrl.jumpTo(clamped);
      return;
    }
    _ctrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return ListView.builder(
      controller: _ctrl,
      itemCount: widget.lines.length,
      itemExtent: _extent,
      itemBuilder: (ctx, i) {
        final isCurrent = i == widget.current;
        return Container(
          decoration: BoxDecoration(
            color: isCurrent ? fc.primary.withValues(alpha: 0.18) : null,
            border: isCurrent
                ? Border(left: BorderSide(color: fc.primary, width: 3))
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            SizedBox(
              width: 14,
              child: isCurrent
                  ? Icon(Icons.play_arrow_rounded, size: 14, color: fc.primary)
                  : null,
            ),
            Text('${i + 1}'.padLeft(4),
                style: TextStyle(
                    color: isCurrent ? fc.primary : fc.textDisabled,
                    fontSize: 11,
                    fontFamily: 'JetBrains Mono')),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14, fontFamily: 'JetBrains Mono'),
                  children: GCodeHighlighter.buildSpans(widget.lines[i], isCurrent),
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
/// Visualisation de position (DRO) : une carte, cinq lignes alignees.
///
/// Remplace cinq pave independants qui occupaient deux rangees pour cinq
/// nombres. Outre l'espace perdu, les largeurs etaient incoherentes — X/Y/Z au
/// tiers de la largeur, A/C a la moitie — et les valeurs ne s'alignaient donc
/// pas d'une ligne a l'autre.
///
/// Une colonne monospace alignee a droite se lit d'un coup d'oeil : c'est ce
/// qu'on demande a un DRO, bien plus que de la decoration.
/// Visualisation de position (DRO) : une carte, cinq lignes alignees, chacune
/// doublee d'une jauge de course.
///
/// Le NOMBRE affiche est la position PIECE — c'est elle qui compte pour usiner.
/// Le REMPLISSAGE, lui, situe l'axe dans sa course MACHINE : il repond a une
/// autre question, « combien me reste-t-il avant la butee ? », que la
/// coordonnee piece ne peut pas donner puisqu'elle depend de l'origine posee.
///
/// La barre vire a l'orange dans les 5 % de chaque extremite : approcher une
/// fin de course pendant un usinage vaut d'etre vu avant de l'entendre.
///
/// Limite connue : FluidNC ne rapporte pas si la machine a ete referencee.
/// Avant un homing, la position machine ne veut rien dire et la jauge non plus.
class _DroCard extends ConsumerWidget {
  const _DroCard({required this.wPos, required this.mPos});

  final List<double> wPos;
  final List<double> mPos;

  static const _axes = [
    ('X', 'mm'),
    ('Y', 'mm'),
    ('Z', 'mm'),
    ('A', '°'),
    ('C', '°'),
  ];

  /// En deca de cette distance relative a une extremite, la jauge alerte.
  static const _edge = 0.05;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final colors = [fc.axisX, fc.axisY, fc.axisZ, fc.axisA, fc.axisC];
    final kin = ref.watch(axisKinematicsProvider).valueOrNull;

    return Container(
      clipBehavior: Clip.antiAlias,
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
        children: [
          for (var i = 0; i < _axes.length; i++) ...[
            if (i > 0) Divider(color: fc.surfaceBorderDim, height: 1),
            _row(context, i, colors[i],
                kin != null && i < kin.length ? kin[i] : null),
          ],
        ],
      ),
    );
  }

  Widget _row(
      BuildContext context, int i, Color color, AxisKinematics? kinematics) {
    final fc = context.fc;
    final machine = i < mPos.length ? mPos[i] : 0.0;
    final fraction = kinematics?.travelFraction(machine);
    final nearEdge =
        fraction != null && (fraction <= _edge || fraction >= 1 - _edge);
    final barColor = nearEdge ? fc.warning : color;

    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          // Jauge de fond. Sans course connue, aucune barre : mieux vaut ne
          // rien montrer qu'une proportion inventee.
          if (fraction != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    color: barColor.withValues(alpha: nearEdge ? 0.26 : 0.16),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(_axes[i].$1,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              if (fraction != null) ...[
                const SizedBox(width: 7),
                Text('${(fraction * 100).round()}%',
                    style: TextStyle(
                        color: nearEdge ? fc.warning : fc.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ],
              const Spacer(),
              Text(
                (i < wPos.length ? wPos[i] : 0.0).toStringAsFixed(3),
                style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'JetBrains Mono',
                    letterSpacing: -0.5),
              ),
              SizedBox(
                width: 26,
                child: Text(_axes[i].$2,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: fc.textDisabled,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
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

/// Rappel de position pendant le jog, epingle en haut de l'onglet.
///
/// Deux decimales et non une : le selecteur de pas descend a 0,01 mm, et un
/// affichage au dixieme rendait ces deplacements simplement invisibles.
class _CompactDroStrip extends StatelessWidget {
  final List<double> wPos;
  const _CompactDroStrip({required this.wPos});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final axes = [
      ('X', fc.axisX),
      ('Y', fc.axisY),
      ('Z', fc.axisZ),
      ('A', fc.axisA),
      ('C', fc.axisC),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 5; i++)
            Expanded(
              child: Column(children: [
                Text(axes[i].$1,
                    style: TextStyle(
                        color: axes[i].$2,
                        fontWeight: FontWeight.w900,
                        fontSize: 10)),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    wPos[i].toStringAsFixed(2),
                    // La valeur reprend la couleur de l'axe : sur cinq nombres
                    // serres, c'est ce qui permet de trouver le bon du regard
                    // sans lire les etiquettes.
                    style: TextStyle(
                        color: axes[i].$2,
                        fontSize: 13,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),
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

class _MobileGCodeInput extends ConsumerStatefulWidget {
  const _MobileGCodeInput();
  @override
  ConsumerState<_MobileGCodeInput> createState() => _MobileGCodeInputState();
}

class _MobileGCodeInputState extends ConsumerState<_MobileGCodeInput> {
  final _ctrl = TextEditingController();
  void _send() {
    final cmd = _ctrl.text.trim();
    if (cmd.isEmpty) return;
    // Retour clair si la machine est hors ligne (sinon l'utilisateur croit que
    // « rien ne s'envoie » alors qu'elle est simplement déconnectée).
    final offline = ref.read(machineStateProvider).valueOrNull?.status ==
        MachineStatus.offline;
    if (offline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Machine hors ligne — commande non envoyée'),
      ));
      return;
    }
    // Lire le repo FRAIS à l'envoi (pas le `widget.repo` capturé au build, qui
    // pouvait rester le mock de simulation après une connexion réelle).
    ref.read(machineRepositoryProvider).sendGCode(cmd);
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
