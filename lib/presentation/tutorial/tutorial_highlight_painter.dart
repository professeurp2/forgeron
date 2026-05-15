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
    this.overlayColor = const Color(0xCC050A15), // Deep semi-transparent industrial blue-black
    required this.glowOpacity,
    this.accentColor = const Color(0xFF6DDDFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final overlayPath = Path()..addRect(fullRect);

    if (spotlightRect != null) {
      // Inflate slightly to create clean margin around targeted widgets
      final targetRRect = RRect.fromRectAndRadius(
        spotlightRect!.inflate(2),
        Radius.circular(borderRadius),
      );

      final spotlightPath = Path()..addRRect(targetRRect);

      final combinedPath = Path.combine(
        PathOperation.difference,
        overlayPath,
        spotlightPath,
      );
      
      // Draw background overlay with cutout
      canvas.drawPath(combinedPath, Paint()..color = overlayColor);

      // Draw sharp high-precision laser inner border outline
      canvas.drawRRect(
        targetRRect,
        Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Draw multi-layered hyper-realistic outer neon halo
      // 1. Broad soft ambient halo
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          spotlightRect!.inflate(4),
          Radius.circular(borderRadius + 2),
        ),
        Paint()
          ..color = accentColor.withValues(alpha: glowOpacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );

      // 2. Intense sharp inner emission core
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          spotlightRect!.inflate(3),
          Radius.circular(borderRadius + 1),
        ),
        Paint()
          ..color = accentColor.withValues(alpha: glowOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    } else {
      canvas.drawPath(overlayPath, Paint()..color = overlayColor);
    }
  }

  @override
  bool shouldRepaint(covariant TutorialHighlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.accentColor != accentColor;
  }
}
