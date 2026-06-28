import 'package:flutter/material.dart';

class TrunnionVisualizer extends StatelessWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '3D Visualizer is only available on Web (Chrome).',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
