import 'package:flutter/material.dart';
import '../../screens/cnc_panel_screen.dart';

// WorkshopLayout délègue entièrement au Pupitre CNC industriel 5 axes.
// Les anciens widgets (CockpitHeader, GiantIndustrialDRO, etc.) ont été
// supprimés lors de la refonte design premium (Phase 3).

class WorkshopLayout extends StatelessWidget {
  const WorkshopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const CncPanelScreen();
  }
}
