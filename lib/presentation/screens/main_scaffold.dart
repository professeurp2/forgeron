import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/machine_state.dart';
import 'dashboard_screen.dart';
import 'probing_screen.dart';
import 'tool_table_screen.dart';
import 'file_manager_screen.dart';
import 'mdi_terminal_screen.dart';
import 'diagnostics_screen.dart';
import 'connection_settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});
  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  final List<Widget> _screens = const [
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

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _StatusFooter(machineState: machineState),
      body: Column(
        children: [
          _HeaderBar(
            isSidebarExpanded: _isSidebarExpanded,
            onMenuToggle: () =>
                setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            machineState: machineState,
            onEmergencyStop: () {
              final repo = ref.read(machineRepositoryProvider);
              repo.emergencyStop();
            },
            onSettingsPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ConnectionSettingsScreen(),
                ),
              );
            },
          ),
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  selectedIndex: _selectedIndex,
                  isExpanded: _isSidebarExpanded,
                  items: _navItems,
                  onItemSelected: (i) =>
                      setState(() => _selectedIndex = i),
                ),
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: _screens[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String title;
  const _NavDef(this.icon, this.title);
}

// ═══════════════════════════════════════════════════════════════
// HEADER BAR — avec connexion réelle et E-STOP fonctionnel
// ═══════════════════════════════════════════════════════════════
class _HeaderBar extends ConsumerWidget {
  final bool isSidebarExpanded;
  final VoidCallback onMenuToggle;
  final AsyncValue<MachineState> machineState;
  final VoidCallback onEmergencyStop;
  final VoidCallback onSettingsPressed;

  const _HeaderBar({
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                isSidebarExpanded ? Icons.menu_open : Icons.menu,
                color: AppColors.textPrimary),
            onPressed: onMenuToggle,
          ),
          const SizedBox(width: 8),
          Image.asset('assets/logo.png', height: 32),
          const SizedBox(width: 12),
          const Text(
            'FORGERON',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 24),
          // Connexion dynamique
          _StatusBadge(
            label: isOnline ? 'EN LIGNE' : 'HORS LIGNE',
            color: isOnline ? AppColors.success : AppColors.error,
            isActive: isOnline,
          ),
          const SizedBox(width: 12),
          _StatusBadge(
            label: statusLabel,
            color: statusColor,
            isActive: true,
          ),
          const SizedBox(width: 12),
          Text(
            ip,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
                fontFamily: 'JetBrains Mono'),
          ),
          const Spacer(),
          // Bouton settings
          IconButton(
            icon: const Icon(Icons.settings_ethernet,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Configuration de la connexion ESP32',
            onPressed: onSettingsPressed,
          ),
          const SizedBox(width: 8),
          // E-STOP
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          const SizedBox(width: 8),
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

// ═══════════════════════════════════════════════════════════════
// SIDEBAR
// ═══════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isExpanded;
  final List<_NavDef> items;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({
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
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.surfaceBorder))),
            child: isExpanded
                ? Row(
                    children: [
                      Image.asset('assets/logo.png', height: 32),
                      const SizedBox(width: 12),
                      const Expanded(
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
            decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.surfaceBorder))),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.surfaceBright,
                  radius: 16,
                  child: Icon(Icons.person,
                      color: AppColors.textSecondary, size: 18),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
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
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              const SizedBox(width: 16),
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

// ═══════════════════════════════════════════════════════════════
// STATUS FOOTER — données temps réel
// ═══════════════════════════════════════════════════════════════
class _StatusFooter extends StatelessWidget {
  final AsyncValue<MachineState> machineState;
  const _StatusFooter({required this.machineState});

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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          const Text('FORGERON v1.0.0',
              style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
          const SizedBox(width: 24),
          Text(
              'X:${mPos[0].toStringAsFixed(3)}  Y:${mPos[1].toStringAsFixed(3)}  Z:${mPos[2].toStringAsFixed(3)}  A:${mPos[3].toStringAsFixed(2)}°  C:${mPos[4].toStringAsFixed(2)}°',
              style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(children: [
                Text('F:$feed mm/min',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
                const SizedBox(width: 16),
                Text('S:$spindle RPM',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
                const SizedBox(width: 24),
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? AppColors.success : AppColors.error,
                  size: 12,
                ),
                const SizedBox(width: 6),
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
