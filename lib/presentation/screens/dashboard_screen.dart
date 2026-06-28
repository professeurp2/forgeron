import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../application/providers/ui_state_provider.dart';

import '../widgets/dashboard/dro_panel.dart';
import '../widgets/dashboard/visualizer_panel.dart';
import '../widgets/dashboard/action_grid.dart';
import '../widgets/dashboard/overrides_panel.dart';
import '../widgets/dashboard/macros_panel.dart';
import '../widgets/dashboard/gcode_console_panel.dart';
import '../widgets/dashboard/workshop_layout.dart';
import '../widgets/dashboard/mode_selector_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWorkshopMode = ref.watch(isWorkshopModeProvider);
    final isFullScreen = ref.watch(isVisualizerFullScreenProvider);

    if (isWorkshopMode) {
      return const WorkshopLayout();
    }

    if (isFullScreen) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: FullScreenVisualizer(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LIGNE 1 : DRO, VISUALISEUR 3D, CONTRÔLE RAPIDE
            SizedBox(
              height: 380,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 2, child: DROPanel()),
                  const SizedBox(width: 24),
                  const Expanded(flex: 5, child: VisualizerPanel()),
                  const SizedBox(width: 24),
                  const Expanded(flex: 2, child: ActionGrid()),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // LIGNE 2 : ÉTAT MODAL & G-CODE & OVERRIDES
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: const [
                      ModeSelectorWidget(),
                      SizedBox(height: 16),
                      OverridesPanel(),
                      SizedBox(height: 16),
                      DynamicsPanel(),
                      SizedBox(height: 16),
                      ModalStatePanel(),
                      SizedBox(height: 16),
                      TelemetryPanel(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(flex: 5, child: SizedBox(height: 500, child: GCodeConsolePanel())),
                const SizedBox(width: 24),
                const Expanded(flex: 2, child: MacrosPanel()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
