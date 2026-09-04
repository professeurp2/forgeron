import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';

class TrunnionVisualizer extends StatelessWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;

  /// Presente pour aligner la signature sur les implementations reelles :
  /// l'export conditionnel resout vers ce stub a l'analyse, et un
  /// parametre manquant ici casse la compilation chez tous les appelants.
  final List<double>? machineLimits;

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
    this.machineLimits,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        tr('3D Visualizer is only available on Web (Chrome).'),
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
