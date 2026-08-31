import 'package:flutter/material.dart';
import '../theme/forgeron_colors.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  final double minRatio;
  final double maxRatio;

  const ResizableSplitView({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.5,
    this.minRatio = 0.1,
    this.maxRatio = 0.9,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;
  double _maxWidth = 0;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxWidth = constraints.maxWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _maxWidth * _ratio,
              child: widget.left,
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                setState(() {
                  _ratio += details.delta.dx / _maxWidth;
                  if (_ratio < widget.minRatio) _ratio = widget.minRatio;
                  if (_ratio > widget.maxRatio) _ratio = widget.maxRatio;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Container(
                  width: 16,
                  color: Colors.transparent, // Easy to grab
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.fc.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.right,
            ),
          ],
        );
      },
    );
  }
}
