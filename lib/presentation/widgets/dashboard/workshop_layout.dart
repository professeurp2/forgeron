import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../screens/cnc_panel_screen.dart';
import '../mobile/mobile_workshop_screen.dart';

class WorkshopLayout extends StatelessWidget {
  const WorkshopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: MobileWorkshopScreen(),
      tablet: CncPanelScreen(),
      desktop: CncPanelScreen(),
    );
  }
}
