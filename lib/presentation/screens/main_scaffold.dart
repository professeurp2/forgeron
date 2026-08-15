import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import '../../application/providers/discovery_provider.dart';
import '../tutorial/tutorial_overlay.dart';
import '../tutorial/tutorial_keys.dart';
import '../tutorial/tutorial_controller.dart';
import 'dashboard_screen.dart';
import 'probing_screen.dart';
import 'tool_table_screen.dart';
import 'file_manager_screen.dart';
import 'mdi_terminal_screen.dart';
import 'diagnostics_screen.dart';
import 'ai_assistant_screen.dart';
import 'ai_agent_settings_screen.dart';
import 'app_settings_screen.dart';
import '../../application/providers/ai_agent_provider.dart';
import 'connection_settings_screen.dart';
import 'mobile_dashboard_screen.dart';
import 'mobile_screens.dart';
import '../../core/widgets/responsive_layout.dart';
import '../widgets/forgeron_wordmark.dart';
import '../widgets/safety_banner.dart';
import '../widgets/nav/cube_page_view.dart';
import '../widgets/nav/forge_bottom_nav.dart';
import '../../application/providers/streaming_provider.dart';
import '../../application/providers/stream_progress_provider.dart';
import '../../application/providers/activity_log_provider.dart';
import '../../application/providers/critical_event_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/ai_inbox_provider.dart';

import '../../application/services/audio_service.dart';
import '../../application/providers/di_providers.dart';

final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});
  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  bool _isSidebarExpanded = true;

  /// Pilote la navigation en cube 3D sur mobile. Détenu ici pour synchroniser
  /// la barre du bas (tap) et le glissement horizontal.
  final PageController _pageController = PageController();
  bool _wasTransitioning = false;

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  /// Signale « transition en cours » dès que la page quitte un entier, pour que
  /// le simulateur (WebView) se masque le temps de la rotation du cube.
  void _onPageScroll() {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      return;
    }
    final page = _pageController.page ?? 0;
    final transitioning = (page - page.round()).abs() > 0.001;
    if (transitioning != _wasTransitioning) {
      _wasTransitioning = transitioning;
      ref.read(pageTransitioningProvider.notifier).state = transitioning;
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
    // Démarre le journal d'activité dès l'ouverture (pour que l'IA connaisse
    // toutes les actions opérateur, même celles faites avant d'ouvrir l'IA).
    ref.read(activityLogProvider);
    // Démarre le veilleur d'évènements critiques (alarme, E-STOP, surchauffe).
    ref.read(criticalEventWatcherProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Le mobile a son propre parcours : les étapes desktop visent une barre
      // latérale et un pied de page qui n'existent pas ici. Même critère que
      // ResponsiveLayout (côté court) pour rester cohérent en paysage.
      final isMobile = ResponsiveLayout.isMobile(context);
      ref.read(tutorialProvider.notifier).checkAutoStart(isMobile: isMobile);
      
      // 1. Charge la dernière adresse IP connue
      await loadNetworkPreferences(ref);
      
      // 2. Lance la découverte réseau avec auto-connexion sur le premier ESP32 trouvé
      ref.read(discoveryProvider.notifier).scan(autoConnect: true);
    });
  }

  void _onNavItemTapped(int index) {
    if (ref.read(selectedNavIndexProvider) != index) {
      // Déclenche le warmUp au premier clic pour débloquer l'audio sur le Web
      ref.read(audioServiceProvider).warmUp();
      ref.read(audioServiceProvider).play(SoundEffect.navigation);
      ref.read(selectedNavIndexProvider.notifier).state = index;
    }
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    ProbingScreen(),
    ToolTableScreen(),
    FileManagerScreen(),
    MDITerminalScreen(),
    DiagnosticsScreen(),
    AiAssistantScreen(),
  ];

  static const _navItems = [
    _NavDef(Icons.dashboard, 'TABLEAU DE BORD'),
    _NavDef(Icons.center_focus_strong, 'PALPAGE & ORIGINES'),
    _NavDef(Icons.build, 'MAGASIN D\'OUTILS'),
    _NavDef(Icons.folder_open, 'ESPACE DE TRAVAIL'),
    _NavDef(Icons.terminal, 'TERMINAL MDI'),
    _NavDef(Icons.monitor_heart, 'DIAGNOSTICS'),
    _NavDef(Icons.smart_toy_outlined, 'AGENT IA'),
  ];

  @override
  Widget build(BuildContext context) {
    final machineState = ref.watch(machineStateProvider);
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return TutorialOverlay(
      child: ResponsiveLayout(
        mobile: _buildMobileScaffold(machineState, selectedIndex),
        tablet: _buildDesktopScaffold(machineState, selectedIndex, false),
        desktop: _buildDesktopScaffold(machineState, selectedIndex, _isSidebarExpanded),
      ),
    );
  }

  Widget _buildDesktopScaffold(AsyncValue<MachineState> machineState, int selectedIndex, bool isExpanded) {
    return Scaffold(
      backgroundColor: context.fc.background,
      bottomNavigationBar: _StatusFooter(
        key: TutorialKeys.statusFooter,
        machineState: machineState,
      ),
      body: Column(
        children: [
          const SafetyBanner(),
          _HeaderBar(
            key: TutorialKeys.headerBar,
            isSidebarExpanded: isExpanded,
            onMenuToggle: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            machineState: machineState,
            onEmergencyStop: () {
              // Passe par le contrôleur : il purge le flux ET vérifie que la
              // commande est réellement partie (sinon SafetyBanner alerte).
              ref.read(streamingProvider.notifier).stopStream();
            },
            onSettingsPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
              );
            },
          ),
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  key: TutorialKeys.sidebar,
                  selectedIndex: selectedIndex,
                  isExpanded: isExpanded,
                  items: _navItems,
                  onItemSelected: _onNavItemTapped,
                ),
                Expanded(
                  child: Container(
                    color: context.fc.background,
                    child: _screens[selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Écrans mobiles : séparation complète desktop/mobile par page
  // Chaque écran est une version dédiée optimisée pour les petits écrans.
  // L'Agent IA n'est plus une face du cube : il est accessible via le bouton
  // flottant animé (_FloatingAiButton), pour désengorger la barre de nav.
  static const List<Widget> _mobileScreens = [
    MobileDashboardScreen(),     // 0 — Tableau de bord
    MobileProbingScreen(),       // 1 — Palpage & Origines
    MobileToolTableScreen(),     // 2 — Magasin d'outils
    FileManagerScreen(),         // 3 — Espace de travail (tabbed, compatible mobile)
    MobileTerminalScreen(),      // 4 — Terminal MDI
    MobileDiagnosticsScreen(),   // 5 — Diagnostics
  ];

  // Libellés courts pour la barre de navigation mobile (l'ordre suit
  // _navItems / _mobileScreens). L'IA est volontairement exclue (bouton flottant).
  static const List<String> _mobileNavLabels = [
    'TABLEAU', 'PALPAGE', 'OUTILS', 'TRAVAIL', 'MDI', 'DIAG',
  ];

  Widget _buildMobileScaffold(AsyncValue<MachineState> machineState, int selectedIndex) {
    final fc = context.fc;
    final aiInbox = ref.watch(aiInboxProvider);
    final state = machineState.valueOrNull;
    final statusColor =
        _getMachineStatusColor(context, state?.status ?? MachineStatus.offline);
    final statusLabel = state?.status.name.toUpperCase() ?? 'OFFLINE';
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;

    final destinations = [
      for (int i = 0; i < _mobileNavLabels.length; i++)
        ForgeNavDestination(_navItems[i].icon, _mobileNavLabels[i]),
    ];

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            const ForgeronLogoGlow(height: 26),
            SizedBox(width: 10),
            const ForgeronWordmark(fontSize: 16),
            SizedBox(width: 10),
            // Badge statut compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(color: statusColor, blurRadius: 6),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Paramètres de l'app (remplace l'ancienne bascule de thème, qui a
          // déménagé dans Paramètres → Apparence).
          IconButton(
            icon: Icon(Icons.settings_rounded, color: fc.primary, size: 20),
            tooltip: 'Paramètres',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? fc.success : fc.textDisabled,
              size: 20,
            ),
            tooltip: 'Connexion ESP32',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      // ── FAB E-STOP persistant, pulsant, au centre (accès pouce) ─────────
      floatingActionButton: _EstopFab(
        key: TutorialKeys.mobileEstop,
        onPressed: () {
          ref.read(machineRepositoryProvider).emergencyStop();
          HapticFeedback.heavyImpact();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // ── Navigation en cube 3D rotatif ──────────────────────────────────
      body: Stack(
        children: [
          Column(
            children: [
              const SafetyBanner(),
              // Progression d'exécution — globale, visible sur toutes les pages.
              const _GlobalProgressBar(),
              Expanded(
                child: CubePageView(
                  controller: _pageController,
                  onPageChanged: _onNavItemTapped,
                  children: _mobileScreens,
                ),
              ),
            ],
          ),
          // ── Bouton IA flottant, déplaçable à la main ────────────────────
          Positioned.fill(
            child: _DraggableAiButton(
              alert: aiInbox.hasAlert,
              problem: aiInbox.problem,
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(aiInboxProvider.notifier).markRead();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _AiAssistantPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ForgeBottomNav(
        key: TutorialKeys.mobileNav,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onTap: (i) {
          _onNavItemTapped(i);
          HapticFeedback.selectionClick();
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeInOutCubic,
            );
          }
        },
      ),
    );
  }

  Color _getMachineStatusColor(BuildContext context, MachineStatus s) {
    final fc = context.fc;
    switch (s) {
      case MachineStatus.idle: return fc.success;
      case MachineStatus.run: return fc.primary;
      case MachineStatus.hold: return fc.warning;
      case MachineStatus.alarm: return fc.error;
      case MachineStatus.home: return fc.axisZ;
      default: return fc.textDisabled;
    }
  }
}

/// FAB E-STOP pulsant — halo rouge respirant pour être impossible à rater.
/// S'insère dans l'encoche centrale de [ForgeBottomNav].
class _EstopFab extends StatefulWidget {
  final VoidCallback onPressed;
  const _EstopFab({super.key, required this.onPressed});

  @override
  State<_EstopFab> createState() => _EstopFabState();
}

class _EstopFabState extends State<_EstopFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.fc.danger;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: danger.withValues(alpha: 0.35 + 0.35 * t),
                blurRadius: 12 + 12 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: danger,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        tooltip: 'Arrêt d\'urgence',
        child: const Icon(Icons.warning_amber_rounded, size: 26),
      ),
    );
  }
}

/// Page hôte de l'Agent IA lorsqu'il est ouvert via le bouton flottant.
/// [AiAssistantScreen] est conçu sans Scaffold (embarqué comme onglet) : on lui
/// fournit ici le chrome (Material + AppBar unique + retour). L'AppBar porte
/// titre, paramètres et effacer → pas de double barre.
class _AiAssistantPage extends ConsumerWidget {
  const _AiAssistantPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [fc.primary, fc.primary.withValues(alpha: 0.7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: fc.primary.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AGENT IA',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fc.textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          fontSize: 15,
                          height: 1.1)),
                  Text('Assistant CNC · Gemini',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fc.textDisabled,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Builder(builder: (context) {
            final ttsOn = ref.watch(aiTtsEnabledProvider);
            return IconButton(
              icon: Icon(ttsOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: ttsOn ? fc.primary : fc.textSecondary, size: 20),
              tooltip: ttsOn ? 'Lecture vocale activée' : 'Lecture vocale',
              onPressed: () => ref.read(aiTtsEnabledProvider.notifier).state = !ttsOn,
            );
          }),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: fc.textSecondary, size: 20),
            tooltip: 'Paramètres de l\'agent',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiAgentSettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: fc.textSecondary, size: 20),
            tooltip: 'Effacer la discussion',
            // Confirmation obligatoire : l'historique est irrécupérable, et le
            // bouton est juste à côté de « paramètres ».
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: fc.surface,
                  title: Text('Effacer cette discussion ?',
                      style: TextStyle(color: fc.textPrimary, fontSize: 16)),
                  content: Text(
                    'Tous les messages de la discussion ouverte seront '
                    'supprimés. Les autres discussions ne sont pas touchées.',
                    style: TextStyle(
                        color: fc.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: fc.danger,
                          foregroundColor: Colors.white),
                      child: const Text('Effacer'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref
                    .read(aiAgentControllerProvider.notifier)
                    .clearConversation();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      body: const SafeArea(child: AiAssistantScreen(embedded: true)),
    );
  }
}

/// Barre de progression d'exécution globale : slim, affichée sur toutes les
/// pages tant qu'un programme G-code tourne (fini de changer d'onglet pour
/// suivre l'avancement).
class _GlobalProgressBar extends ConsumerWidget {
  const _GlobalProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(streamProgressProvider);
    if (!p.active) return const SizedBox.shrink();
    final fc = context.fc;
    final eta = p.eta;
    return Container(
      decoration: BoxDecoration(
        color: fc.primary.withValues(alpha: 0.10),
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 5),
            child: Row(
              children: [
                Icon(Icons.play_arrow_rounded, size: 15, color: fc.primary),
                const SizedBox(width: 6),
                Text('${p.percent}%',
                    style: TextStyle(
                        color: fc.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
                const SizedBox(width: 12),
                Text('Ligne ${p.currentLine}/${p.totalLines}',
                    style: TextStyle(color: fc.textSecondary, fontSize: 11)),
                const Spacer(),
                Icon(Icons.timer_outlined, size: 11, color: fc.textDisabled),
                const SizedBox(width: 4),
                Text(
                  eta != null
                      ? '${formatDuration(p.elapsed)} · -${formatDuration(eta)}'
                      : formatDuration(p.elapsed),
                  style: TextStyle(
                      color: fc.textSecondary,
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono'),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: p.fraction,
            minHeight: 3,
            backgroundColor: fc.surfaceBorder,
            color: fc.primary,
          ),
        ],
      ),
    );
  }
}

/// Enveloppe déplaçable du bouton IA : l'opérateur peut le glisser n'importe où
/// pour dégager la vue ; au relâcher il s'aimante au bord gauche ou droit le
/// plus proche et reste toujours dans l'écran. Un simple tap ouvre l'assistant.
class _DraggableAiButton extends StatefulWidget {
  final bool alert;
  final bool problem;
  final VoidCallback onTap;
  const _DraggableAiButton({
    required this.alert,
    required this.problem,
    required this.onTap,
  });

  @override
  State<_DraggableAiButton> createState() => _DraggableAiButtonState();
}

class _DraggableAiButtonState extends State<_DraggableAiButton> {
  // Position du coin haut-gauche du bouton dans la zone de contenu.
  Offset? _pos;
  bool _dragging = false;
  static const double _size = 58;
  static const double _margin = 12;

  Offset _clamp(Offset p, double w, double h) => Offset(
        p.dx.clamp(_margin, w - _size - _margin),
        p.dy.clamp(_margin, h - _size - _margin),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // Défaut : bas-droite (au-dessus du FAB E-STOP central).
        final pos = _clamp(
          _pos ?? Offset(w - _size - 16, h - _size - 24),
          w,
          h,
        );
        return Stack(
          children: [
            AnimatedPositioned(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: (d) {
                  setState(() => _pos = _clamp(pos + d.delta, w, h));
                },
                onPanEnd: (_) {
                  // Aimantation horizontale au bord le plus proche.
                  final center = pos.dx + _size / 2;
                  final snapped = center < w / 2
                      ? _margin
                      : w - _size - _margin;
                  setState(() {
                    _dragging = false;
                    _pos = _clamp(Offset(snapped, pos.dy), w, h);
                  });
                  HapticFeedback.selectionClick();
                },
                child: _FloatingAiButton(
                  alert: widget.alert,
                  problem: widget.problem,
                  onTap: widget.onTap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bouton flottant « Agent IA » — un emoji robot qui respire, ondule et
/// réagit au toucher. Remplace l'onglet IA dans la barre de navigation.
class _FloatingAiButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool alert;
  final bool problem;
  const _FloatingAiButton({
    required this.onTap,
    this.alert = false,
    this.problem = false,
  });

  @override
  State<_FloatingAiButton> createState() => _FloatingAiButtonState();
}

class _FloatingAiButtonState extends State<_FloatingAiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value; // 0 → 1
        // Ondulation verticale douce + léger balancement.
        final bob = sin(t * 2 * pi) * 4.0;
        final tilt = sin(t * 2 * pi) * 0.06;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(angle: tilt, child: child),
        );
      },
      child: _buildButton(fc),
    );
  }

  Widget _buildButton(ForgeronColorPalette fc) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final glow = 0.35 + 0.35 * (0.5 + 0.5 * sin(_ctrl.value * 4 * pi));
            return Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    fc.primary,
                    fc.primary.withValues(alpha: 0.75),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fc.primary.withValues(alpha: glow),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('🤖', style: TextStyle(fontSize: 28)),
            );
          },
            ),
            // Badge d'alerte : « ? » (info) ou « ! » (problème).
            if (widget.alert)
              Positioned(
                right: -2,
                top: -2,
                child: _AiBadge(problem: widget.problem, fc: fc),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pastille d'alerte du bouton IA — pulse doucement pour attirer l'œil.
class _AiBadge extends StatefulWidget {
  final bool problem;
  final ForgeronColorPalette fc;
  const _AiBadge({required this.problem, required this.fc});

  @override
  State<_AiBadge> createState() => _AiBadgeState();
}

class _AiBadgeState extends State<_AiBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    final color = widget.problem ? fc.danger : fc.warning;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4 + 0.4 * t),
                blurRadius: 6 + 4 * t,
                spreadRadius: 0.5 + t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        width: 21,
        height: 21,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: fc.background, width: 2),
        ),
        child: Text(
          widget.problem ? '!' : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String title;
  const _NavDef(this.icon, this.title);
}

class _HeaderBar extends ConsumerWidget {
  final bool isSidebarExpanded;
  final VoidCallback onMenuToggle;
  final AsyncValue<MachineState> machineState;
  final VoidCallback onEmergencyStop;
  final VoidCallback onSettingsPressed;

  const _HeaderBar({
    super.key,
    required this.isSidebarExpanded,
    required this.onMenuToggle,
    required this.machineState,
    required this.onEmergencyStop,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = machineState.valueOrNull;
    final isOnline = state?.status != null &&
        state?.status != MachineStatus.offline;
    final statusLabel =
        state?.status.name.toUpperCase() ?? 'HORS LIGNE';
    final statusColor = _statusColor(context, state?.status ?? MachineStatus.offline);
    final ip = ref.watch(espIpProvider);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.fc.surface,
        border: Border(bottom: BorderSide(color: context.fc.surfaceBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            key: TutorialKeys.menuToggleBtn,
            icon: Icon(
                isSidebarExpanded ? Icons.menu_open : Icons.menu,
                color: context.fc.textPrimary),
            onPressed: onMenuToggle,
          ),
          SizedBox(width: 8),
          const ForgeronLogoGlow(height: 32),
          SizedBox(width: 12),
          const ForgeronWordmark(fontSize: 22),
          SizedBox(width: 24),
          _StatusBadge(
            label: isOnline ? 'EN LIGNE' : 'HORS LIGNE',
            color: isOnline ? context.fc.success : context.fc.error,
            isActive: isOnline,
          ),
          SizedBox(width: 12),
          _StatusBadge(
            label: statusLabel,
            color: statusColor,
            isActive: true,
          ),
          SizedBox(width: 12),
          Text(
            ip,
            style: TextStyle(
                color: context.fc.textDisabled,
                fontSize: 10,
                fontFamily: 'JetBrains Mono'),
          ),
          const Spacer(),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                ref.watch(themeModeProvider) == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(ref.watch(themeModeProvider)),
                color: ref.watch(themeModeProvider) == ThemeMode.dark
                    ? context.fc.primary
                    : context.fc.textSecondary,
                size: 20,
              ),
            ),
            tooltip: 'Changer le thème',
            onPressed: () {
              final notifier = ref.read(themeModeProvider.notifier);
              notifier.state = notifier.state == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              ref.read(audioServiceProvider).play(SoundEffect.click);
              HapticFeedback.lightImpact();
            },
          ),
          IconButton(
            icon: Icon(Icons.help_outline,
                color: context.fc.textSecondary, size: 20),
            tooltip: 'Tutoriel interactif',
            onPressed: () => ref.read(tutorialProvider.notifier).start(),
          ),
          IconButton(
            key: TutorialKeys.settingsBtn,
            icon: Icon(Icons.settings_ethernet,
                color: context.fc.textSecondary, size: 20),
            tooltip: 'Configuration de la connexion ESP32',
            onPressed: onSettingsPressed,
          ),
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.fc.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton.icon(
              key: TutorialKeys.emergencyStopBtn,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.fc.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              ),
              onPressed: onEmergencyStop,
              icon: const Icon(Icons.warning_amber, size: 18),
              label: const Text('ARRÊT D\'URGENCE',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, MachineStatus s) {
    switch (s) {
      case MachineStatus.idle:
        return context.fc.success;
      case MachineStatus.run:
        return context.fc.primary;
      case MachineStatus.hold:
        return context.fc.warning;
      case MachineStatus.alarm:
        return context.fc.error;
      case MachineStatus.home:
        return context.fc.axisZ;
      default:
        return context.fc.textDisabled;
    }
  }
}

class _StatusBadge extends StatefulWidget {
  final String label;
  final Color color;
  final bool isActive;
  const _StatusBadge(
      {required this.label, required this.color, required this.isActive});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: widget.color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = widget.isActive ? _pulse.value : 0.0;
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive ? widget.color : context.fc.textDisabled,
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.6 + 0.4 * t),
                            blurRadius: 5 + 6 * t,
                            spreadRadius: 0.5 * t,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(widget.label,
              style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isExpanded;
  final List<_NavDef> items;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({
    super.key,
    required this.selectedIndex,
    required this.isExpanded,
    required this.items,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isExpanded ? 260 : 72,
      decoration: BoxDecoration(
        color: context.fc.sidebar,
        border: Border(right: BorderSide(color: context.fc.surfaceBorder)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: context.fc.surfaceBorder))),
            child: isExpanded
                ? Row(
                    children: [
                      const ForgeronLogoGlow(height: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CNC_TRUNNION_5X',
                                style: TextStyle(
                                    color: context.fc.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text('AXES: X Y Z A C',
                                style: TextStyle(
                                    color: context.fc.success,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'JetBrains Mono')),
                          ],
                        ),
                      ),
                    ],
                  )
                : const ForgeronLogoGlow(height: 28),
          ),
          const SizedBox(height: 8),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final selected = i == selectedIndex;
            return _NavItem(
              icon: item.icon,
              title: item.title,
              selected: selected,
              isExpanded: isExpanded,
              onTap: () => onItemSelected(i),
            );
          }),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: context.fc.surfaceBorder))),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: context.fc.surfaceBright,
                  radius: 16,
                  child: Icon(Icons.person,
                      color: context.fc.textSecondary, size: 18),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OPÉRATEUR L01',
                            style: TextStyle(
                                color: context.fc.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                        Text('NIV_AUTH: ADMIN',
                            style: TextStyle(
                                color: context.fc.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'JetBrains Mono')),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? context.fc.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border(
              left: BorderSide(
                  color: selected ? context.fc.primary : Colors.transparent,
                  width: 3)),
        ),
        child: Row(
          mainAxisAlignment: isExpanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            if (isExpanded) const SizedBox(width: 12),
            Icon(icon,
                color: selected ? context.fc.primary : context.fc.textDisabled,
                size: 20),
            if (isExpanded) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? context.fc.textPrimary
                        : context.fc.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w900 : FontWeight.normal,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  final AsyncValue<MachineState> machineState;
  const _StatusFooter({super.key, required this.machineState});

  @override
  Widget build(BuildContext context) {
    final state = machineState.valueOrNull;
    final mPos = state?.mPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    final feed = state?.feedrate.toStringAsFixed(0) ?? '0';
    final spindle = state?.spindleSpeed.toStringAsFixed(0) ?? '0';
    final isOnline = state?.status != null &&
        state?.status != MachineStatus.offline;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: context.fc.surface,
        border: Border(top: BorderSide(color: context.fc.surfaceBorder)),
      ),
      child: Row(
        children: [
          Text('FORGERON v1.0.0',
              style: TextStyle(
                  color: context.fc.textDisabled,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
          const SizedBox(width: 24),
          Text(
              'X:${mPos[0].toStringAsFixed(3)}  Y:${mPos[1].toStringAsFixed(3)}  Z:${mPos[2].toStringAsFixed(3)}  A:${mPos[3].toStringAsFixed(2)}°  C:${mPos[4].toStringAsFixed(2)}°',
              style: TextStyle(
                  color: context.fc.secondary,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(children: [
                Text('F:$feed mm/min',
                    style: TextStyle(
                        color: context.fc.primary,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
                const SizedBox(width: 16),
                Text('S:$spindle RPM',
                    style: TextStyle(
                        color: context.fc.primary,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
                const SizedBox(width: 24),
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? context.fc.success : context.fc.error,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'ESP32 CONNECTÉ' : 'DÉCONNECTÉ',
                  style: TextStyle(
                      color: isOnline ? context.fc.success : context.fc.error,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
