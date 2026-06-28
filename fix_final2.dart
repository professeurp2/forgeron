import 'dart:io';

void main() {
  final files = [
    'lib/presentation/screens/mobile_screens.dart',
    'lib/presentation/tutorial/tutorial_highlight_painter.dart',
    'lib/presentation/tutorial/tutorial_step.dart',
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart'
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();

    if (f.endsWith('mobile_screens.dart')) {
      content = content.replaceAll(RegExp(r'static const (_[a-zA-Z0-9]+)\s*=\s*\['), 'static final \$1 = [');
    }
    else if (f.endsWith('tutorial_highlight_painter.dart')) {
      content = '''import 'package:flutter/material.dart';

class TutorialHighlightPainter extends CustomPainter {
  final Rect? spotlightRect;
  final double borderRadius;
  final Color overlayColor;
  final double glowOpacity;
  final Color accentColor;

  TutorialHighlightPainter({
    this.spotlightRect,
    this.borderRadius = 8,
    this.overlayColor = const Color(0xCC050A15),
    required this.glowOpacity,
    this.accentColor = const Color(0xFF6DDDFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final overlayPath = Path()..addRect(fullRect);

    if (spotlightRect != null) {
      final targetRRect = RRect.fromRectAndRadius(
          spotlightRect!.inflate(6), Radius.circular(borderRadius));
      overlayPath.addRRect(targetRRect);
      overlayPath.fillType = PathFillType.evenOdd;
    }

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(overlayPath, paint);

    if (spotlightRect != null && glowOpacity > 0) {
      final targetRRect = RRect.fromRectAndRadius(
          spotlightRect!.inflate(6), Radius.circular(borderRadius));
      final glowPaint = Paint()
        ..color = accentColor.withOpacity(glowOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8.0);
      canvas.drawRRect(targetRRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TutorialHighlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}
''';
    }
    else if (f.endsWith('tutorial_step.dart')) {
      content = content.replaceAll('this.color = Colors.blue', 'this.color = const Color(0xFF2196F3)');
    }
    else if (f.endsWith('trunnion_visualizer_web.dart') || f.endsWith('trunnion_visualizer_windows.dart')) {
      content = content.replaceAll('this.color = Colors.orange', 'this.color = const Color(0xFFFF9800)');
      content = content.replaceAll('this.color = Colors.cyan', 'this.color = const Color(0xFF00BCD4)');
    }
    
    file.writeAsStringSync(content);
  }
}
