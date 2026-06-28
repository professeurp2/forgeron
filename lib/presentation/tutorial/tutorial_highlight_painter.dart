import 'package:flutter/material.dart';

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
