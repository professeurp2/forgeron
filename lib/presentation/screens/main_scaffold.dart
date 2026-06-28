import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import '../tutorial/tutorial_overlay.dart';
import '../tutorial/tutorial_keys.dart';
import '../tutorial/tutorial_controller.dart';
import 'dashboard_screen.dart';
import 'probing_screen.dart';
import 'tool_table_screen.dart';
import 'file_manager_screen.dart';
import 'mdi_terminal_screen.dart';
import 'diagnostics_screen.dart';
import 'connection_settings_screen.dart';
import 'mobile_dashboard_screen.dart';
import 'mobile_screens.dart';
import '../../core/widgets/responsive_layout.dart';

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
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tutorialProvider.notifier).checkAutoStart();
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

  final List<Widget> _screens = [
    DashboardScreen(),
    ProbingScreen(),
    ToolTableScreen(),
    FileManagerScreen(),
    MDITerminalScreen(),
    DiagnosticsScreen(),
  ];

  static const _navItems = [
    _NavDef(Icons.dashboard, 'TABLEAU DE BORD'),
    _NavDef(Icons.center_focus_strong, 'PALPAGE & ORIGINES'),
    _NavDef(Icons.build, 'MAGASIN D\'OUTILS'),
    _NavDef(Icons.folder_open, 'ESPACE DE TRAVAIL'),
    _NavDef(Icons.terminal, 'TERMINAL MDI'),
    _NavDef(Icons.monitor_heart, 'DIAGNOSTICS'),
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
      backgroundColor: AppColors.background,
      bottomNavigationBar: _StatusFooter(
        key: TutorialKeys.statusFooter,
        machineState: machineState,
      ),
      body: Column(
        children: [
          _HeaderBar(
            key: TutorialKeys.headerBar,
            isSidebarExpanded: isExpanded,
            onMenuToggle: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            machineState: machineState,
            onEmergencyStop: () {
              final repo = ref.read(machineRepositoryProvider);
              repo.emergencyStop();
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
                    color: AppColors.background,
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
  static const List<Widget> _mobileScreens = [
    MobileDashboardScreen(),     // 0 — Tableau de bord
    MobileProbingScreen(),       // 1 — Palpage & Origines
    MobileToolTableScreen(),     // 2 — Magasin d'outils
    FileManagerScreen(),         // 3 — Espace de travail (tabbed, compatible mobile)
    MobileTerminalScreen(),      // 4 — Terminal MDI
    MobileDiagnosticsScreen(),   // 5 — Diagnostics
  ];

  Widget _buildMobileScaffold(AsyncValue<MachineState> machineState, int selectedIndex) {
    final state = machineState.valueOrNull;
    final statusColor = _getMachineStatusColor(state?.status ?? MachineStatus.offline);
    final statusLabel = state?.status.name.toUpperCase() ?? 'OFFLINE';
    final isOnline = state?.status != null && state?.status != MachineStatus.offline;

    // Tous les index utilisent leur écran mobile dédié
    final body = _mobileScreens[selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 26),
            SizedBox(width: 10),
            Text(
              'FORGERON',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(width: 10),
            // Badge statut compact
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          IconButton(
            icon: Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? AppColors.success : AppColors.textDisabled,
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
          child: Container(height: 1, color: AppColors.surfaceBorder),
        ),
      ),
      // ── FAB E-STOP persistant ──────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(machineRepositoryProvider).emergencyStop();
          HapticFeedback.heavyImpact();
        },
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        icon: Icon(Icons.warning_amber_rounded, size: 20),
        label: Text('ARRÊT',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0)),
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: body,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // 5 premiers onglets (les 5 premières entrées)
              ..._navItems.asMap().entries.take(5).map((e) {
                final i = e.key;
                final item = e.value;
                final sel = selectedIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onNavItemTapped(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon,
                            size: 22,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textDisabled),
                        SizedBox(height: 2),
                        Text(
                          item.title.split(' ').first,
                          style: TextStyle(
                              fontSize: 9,
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textDisabled,
                              fontWeight: sel
                                  ? FontWeight.w900
                                  : FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              // Espace pour le FAB
              SizedBox(width: 56),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMachineStatusColor(MachineStatus s) {
    switch (s) {
      case MachineStatus.idle: return AppColors.success;
      case MachineStatus.run: return AppColors.primary;
      case MachineStatus.hold: return AppColors.warning;
      case MachineStatus.alarm: return AppColors.error;
      case MachineStatus.home: return AppColors.axisZ;
      default: return AppColors.textDisabled;
    }
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
    final statusColor = _statusColor(state?.status ?? MachineStatus.offline);
    final ip = ref.watch(espIpProvider);

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            key: TutorialKeys.menuToggleBtn,
            icon: Icon(
                isSidebarExpanded ? Icons.menu_open : Icons.menu,
                color: AppColors.textPrimary),
            onPressed: onMenuToggle,
          ),
          SizedBox(width: 8),
          Image.asset('assets/logo.png', height: 32),
          SizedBox(width: 12),
          Text(
            'FORGERON',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(width: 24),
          _StatusBadge(
            label: isOnline ? 'EN LIGNE' : 'HORS LIGNE',
            color: isOnline ? AppColors.success : AppColors.error,
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
                color: AppColors.textDisabled,
                fontSize: 10,
                fontFamily: 'JetBrains Mono'),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark 
                  ? Icons.light_mode 
                  : Icons.dark_mode,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Basculer le thème',
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.help_outline,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Tutoriel interactif',
            onPressed: () => ref.read(tutorialProvider.notifier).start(),
          ),
          IconButton(
            key: TutorialKeys.settingsBtn,
            icon: Icon(Icons.settings_ethernet,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Configuration de la connexion ESP32',
            onPressed: onSettingsPressed,
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton.icon(
              key: TutorialKeys.emergencyStopBtn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                padding:
                    EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              ),
              onPressed: onEmergencyStop,
              icon: Icon(Icons.warning_amber, size: 18),
              label: Text('ARRÊT D\'URGENCE',
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

  Color _statusColor(MachineStatus s) {
    switch (s) {
      case MachineStatus.idle:
        return AppColors.success;
      case MachineStatus.run:
        return AppColors.primary;
      case MachineStatus.hold:
        return AppColors.warning;
      case MachineStatus.alarm:
        return AppColors.error;
      case MachineStatus.home:
        return AppColors.axisZ;
      default:
        return AppColors.textDisabled;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  const _StatusBadge(
      {required this.label, required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : AppColors.textDisabled,
              boxShadow: isActive
                  ? [BoxShadow(color: color, blurRadius: 8)]
                  : null,
            ),
          ),
          SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color,
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
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.surfaceBorder))),
            child: isExpanded
                ? Row(
                    children: [
                      Image.asset('assets/logo.png', height: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CNC_TRUNNION_5X',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                            SizedBox(height: 2),
                            Text('AXES: X Y Z A C',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'JetBrains Mono')),
                          ],
                        ),
                      ),
                    ],
                  )
                : Image.asset('assets/logo.png', height: 28),
          ),
          SizedBox(height: 8),
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
                EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.surfaceBorder))),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.surfaceBright,
                  radius: 16,
                  child: Icon(Icons.person,
                      color: AppColors.textSecondary, size: 18),
                ),
                if (isExpanded) ...[
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OPÉRATEUR L01',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                        Text('NIV_AUTH: ADMIN',
                            style: TextStyle(
                                color: AppColors.primary,
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
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border(
              left: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 3)),
        ),
        child: Row(
          mainAxisAlignment: isExpanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            SizedBox(width: isExpanded ? 12 : 0),
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textDisabled,
                size: 20),
            if (isExpanded) ...[
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
      padding: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          Text('FORGERON v1.0.0',
              style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
          SizedBox(width: 24),
          Text(
              'X:${mPos[0].toStringAsFixed(3)}  Y:${mPos[1].toStringAsFixed(3)}  Z:${mPos[2].toStringAsFixed(3)}  A:${mPos[3].toStringAsFixed(2)}°  C:${mPos[4].toStringAsFixed(2)}°',
              style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(children: [
                Text('F:$feed mm/min',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
                SizedBox(width: 16),
                Text('S:$spindle RPM',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
                SizedBox(width: 24),
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? AppColors.success : AppColors.error,
                  size: 12,
                ),
                SizedBox(width: 6),
                Text(
                  isOnline ? 'ESP32 CONNECTÉ' : 'DÉCONNECTÉ',
                  style: TextStyle(
                      color: isOnline ? AppColors.success : AppColors.error,
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