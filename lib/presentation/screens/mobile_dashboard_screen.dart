import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../domain/models/machine_state.dart';
import '../../application/services/audio_service.dart';

/// Dashboard optimisÃ© pour la plateforme mobile (< 600 px).
/// Architecture verticale scrollable, zoning tactile gÃ©nÃ©reux.
class MobileDashboardScreen extends ConsumerStatefulWidget {
  const MobileDashboardScreen({super.key});
  @override
  ConsumerState<MobileDashboardScreen> createState() =>
      _MobileDashboardScreenState();
}

class _MobileDashboardScreenState
    extends ConsumerState<MobileDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sections : 0 = DRO, 1 = ContrÃ´les, 2 = G-Code
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
        // â”€â”€ Tab selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _MobileTabBar(controller: _tabController),

        // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DROTab(state: state),
              _ControlsTab(state: state),
              _GcodeTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TAB BAR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MobileTabBar extends StatelessWidget {
  final TabController controller;
  const _MobileTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: controller,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textDisabled,
        labelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2),
        tabs: [
          Tab(icon: Icon(Icons.display_settings, size: 20), text: 'DRO'),
          Tab(icon: Icon(Icons.touch_app, size: 20), text: 'CONTRÃ”LES'),
          Tab(icon: Icon(Icons.terminal, size: 20), text: 'G-CODE'),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ONGLET 1 : DRO (Digital Read-Out)  â€” prioritÃ© absolue sur mobile
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DROTab extends ConsumerWidget {
  final MachineState? state;
  const _DROTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wPos = state?.wPos ?? List.filled(5, 0.0);
    final mPos = state?.mPos ?? List.filled(5, 0.0);
    final feed = state?.feedrate ?? 0.0;
    final spindle = state?.spindleSpeed ?? 0.0;
    final isOnline = state?.status != null &&
        state?.status != MachineStatus.offline;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // â”€â”€ Statut connexion â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _MobileStatusBanner(isOnline: isOnline, status: state?.status),

          SizedBox(height: 16),

          // â”€â”€ DRO Axes linÃ©aires â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const _SectionLabel('POSITION PIÃˆCE (W)'),
          SizedBox(height: 8),
          _MobileDROCard('X', wPos[0], AppColors.axisX),
          _MobileDROCard('Y', wPos[1], AppColors.axisY),
          _MobileDROCard('Z', wPos[2], AppColors.axisZ),

          SizedBox(height: 8),

          // â”€â”€ DRO Axes rotatifs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              Expanded(child: _MiniDROCard('A', wPos[3], AppColors.axisA, 'Â°')),
              SizedBox(width: 10),
              Expanded(child: _MiniDROCard('C', wPos[4], AppColors.axisC, 'Â°')),
            ],
          ),

          SizedBox(height: 20),

          // â”€â”€ Jauges F & S â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const _SectionLabel('DYNAMIQUE'),
          SizedBox(height: 8),
          _MobileGauge('AVANCE (F)', feed, 5000, AppColors.primary, 'mm/min'),
          SizedBox(height: 8),
          _MobileGauge('BROCHE (S)', spindle, 24000, AppColors.secondary, 'RPM'),

          SizedBox(height: 20),

          // â”€â”€ Position machine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const _SectionLabel('POSITION MACHINE (M)'),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                _mPosRow('X', mPos[0], AppColors.axisX),
                _mPosRow('Y', mPos[1], AppColors.axisY),
                _mPosRow('Z', mPos[2], AppColors.axisZ),
                _mPosRow('A', mPos[3], AppColors.axisA, unit: 'Â°'),
                _mPosRow('C', mPos[4], AppColors.axisC, unit: 'Â°'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mPosRow(String ax, double val, Color c, {String unit = 'mm'}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(ax,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(
            unit == 'Â°'
                ? '${val.toStringAsFixed(2)}Â°'
                : val.toStringAsFixed(3),
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFamily: 'JetBrains Mono'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ONGLET 2 : CONTRÃ”LES TACTILES
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ControlsTab extends ConsumerWidget {
  final MachineState? state;
  const _ControlsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(machineRepositoryProvider);
    final isWorkshop = ref.watch(isWorkshopModeProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // â”€â”€ Actions principales â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const _SectionLabel('ACTIONS CYCLE'),
          SizedBox(height: 12),

          // Bouton DÃ‰PART â€” large, touch-friendly
          _BigActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'DÃ‰PART CYCLE',
            color: AppColors.success,
            onTap: () {
              ref.read(audioServiceProvider).play(SoundEffect.click);
              repo.resume();
              HapticFeedback.mediumImpact();
            },
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BigActionButton(
                  icon: Icons.pause_rounded,
                  label: 'PAUSE',
                  color: AppColors.warning,
                  onTap: () {
                    repo.pause();
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _BigActionButton(
                  icon: Icons.stop_rounded,
                  label: 'ABANDON',
                  color: AppColors.danger,
                  onTap: () {
                    repo.reset();
                    HapticFeedback.heavyImpact();
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // â”€â”€ Navigation / Homing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const _SectionLabel('NAVIGATION'),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigActionButton(
                  icon: Icons.home_rounded,
                  label: 'HOMING',
                  color: AppColors.axisZ,
                  onTap: () {
                    repo.sendRaw('\$X\n');
                    Future.delayed(
                        const Duration(milliseconds: 300), () => repo.home([]));
                    HapticFeedback.mediumImpact();
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _BigActionButton(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GOTO ZÃ‰RO',
                  color: AppColors.secondary,
                  onTap: () {
                    repo.sendGCode('G90 G0 X0 Y0 Z0 A0 C0');
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _BigActionButton(
            icon: Icons.refresh_rounded,
            label: 'SOFT RESET + DÃ‰VERR.',
            color: AppColors.textSecondary,
            onTap: () {
              repo.sendRaw('\x18');
              Future.delayed(const Duration(milliseconds: 500),
                  () => repo.sendRaw('\$X\n'));
              HapticFeedback.mediumImpact();
            },
          ),

          SizedBox(height: 20),

          // â”€â”€ Mode Atelier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const _SectionLabel('MODE ATELIER'),
          SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ref.read(isWorkshopModeProvider.notifier).state = !isWorkshop;
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWorkshop
                      ? [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.05),
                        ]
                      : [
                          AppColors.surface,
                          AppColors.surface,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isWorkshop
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    width: isWorkshop ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.factory_rounded,
                      color: isWorkshop
                          ? AppColors.primary
                          : AppColors.textDisabled,
                      size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MODE ATELIER',
                            style: TextStyle(
                                color: isWorkshop
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.0)),
                        Text('DRO gÃ©ant + commandes gants',
                            style: TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isWorkshop,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) =>
                        ref.read(isWorkshopModeProvider.notifier).state = v,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ONGLET 3 : G-CODE (compact)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _GcodeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(machineRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Macros rapides
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: const _SectionLabel('MACROS RAPIDES'),
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              _MacroChip('G28', () => repo.sendGCode('G28')),
              _MacroChip('G0 Z5', () => repo.sendGCode('G0 Z5')),
              _MacroChip('M3 S8000', () => repo.sendGCode('M3 S8000')),
              _MacroChip('M5', () => repo.sendGCode('M5')),
              _MacroChip('\$?', () => repo.sendRaw('\$?\n')),
              _MacroChip('\$H', () => repo.sendRaw('\$H\n')),
            ],
          ),
        ),

        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _SectionLabel('CONSOLE TERMINAL'),
        ),
        SizedBox(height: 8),

        // Saisie MDI
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _MobileGCodeInput(repo: repo),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// COMPOSANTS RÃ‰UTILISABLES
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MobileStatusBanner extends StatelessWidget {
  final bool isOnline;
  final MachineStatus? status;
  const _MobileStatusBanner({required this.isOnline, this.status});

  Color _statusColor() {
    switch (status) {
      case MachineStatus.idle:   return AppColors.success;
      case MachineStatus.run:    return AppColors.primary;
      case MachineStatus.hold:   return AppColors.warning;
      case MachineStatus.alarm:  return AppColors.error;
      case MachineStatus.home:   return AppColors.axisZ;
      default:                   return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? _statusColor() : AppColors.textDisabled;
    final label = status?.name.toUpperCase() ?? 'HORS LIGNE';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Dot animÃ© (pulsation via opacity â€” stateless simplifiÃ©)
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color, blurRadius: 8)],
            ),
          ),
          SizedBox(width: 12),
          Text(isOnline ? 'ESP32 EN LIGNE' : 'ESP32 HORS LIGNE',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
          const Spacer(),
          if (isOnline)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: _statusColor(),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: AppColors.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      );
}

class _MobileDROCard extends StatelessWidget {
  final String axis;
  final double value;
  final Color color;
  const _MobileDROCard(this.axis, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(axis,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value.toStringAsFixed(3),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          SizedBox(width: 6),
          Text('mm',
              style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}

class _MiniDROCard extends StatelessWidget {
  final String axis;
  final double value;
  final Color color;
  final String unit;
  const _MiniDROCard(this.axis, this.value, this.color, this.unit);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(axis,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          FittedBox(
            child: Text(
              '${value.toStringAsFixed(2)}$unit',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileGauge extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String unit;
  const _MobileGauge(this.label, this.value, this.max, this.color, this.unit);

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0)),
              Text('${value.toInt()} $unit',
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.surfaceBright,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MacroChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrains Mono')),
      ),
    );
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
  final _focus = FocusNode();

  void _send() {
    final cmd = _ctrl.text.trim();
    if (cmd.isEmpty) return;
    widget.repo.sendGCode(cmd);
    _ctrl.clear();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.terminalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: TextStyle(
                  color: AppColors.primary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ex: G0 X10 Y0 Z5',
                hintStyle: TextStyle(
                    color: AppColors.textDisabled,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixText: '> ',
                prefixStyle: TextStyle(
                    color: AppColors.textDisabled,
                    fontFamily: 'JetBrains Mono'),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
          IconButton(
            onPressed: _send,
            icon: Icon(Icons.send_rounded,
                color: AppColors.primary, size: 22),
            tooltip: 'Envoyer',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}