import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ToolPreview extends StatelessWidget {
  final String toolName;
  final double diameter;
  final double length;

  const ToolPreview({
    super.key,
    required this.toolName,
    required this.diameter,
    required this.length,
  });

  String _getImageAsset() {
    final name = toolName.toUpperCase();
    if (name.contains('FORET')) return 'assets/images/tools/drill.png';
    if (name.contains('HÉMISPHÉRIQUE')) return 'assets/images/tools/ball_nose_endmill.png';
    if (name.contains('V-BIT')) return 'assets/images/tools/v_bit.png';
    return 'assets/images/tools/flat_endmill.png';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background High-Res Image
            Image.asset(
              _getImageAsset(),
              fit: BoxFit.contain, // Contain so the tool is fully visible
              alignment: Alignment.center,
            ),
            // Foreground Dimension Overlay
            CustomPaint(
              painter: _ToolDimensionPainter(
                diameter: diameter,
                length: length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolDimensionPainter extends CustomPainter {
  final double diameter;
  final double length;

  _ToolDimensionPainter({required this.diameter, required this.length});

  @override
  void paint(Canvas canvas, Size size) {
    // We want to draw CAD-like dimensions.
    // D (Diameter) at the bottom.
    // L (Length) on the left side.
    
    final paintLine = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
      
    final paintText = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Common measurements
    final toolCenterX = size.width / 2;
    // Assuming the tool image is vertically centered and takes about 60% of the height
    final toolStartY = size.height * 0.2;
    final toolEndY = size.height * 0.8;
    // Assuming the tool width takes about 20% of the width
    final toolRadiusPx = size.width * 0.1;

    // --- Draw Length (L) Dimension ---
    final leftX = size.width * 0.15;
    
    // Vertical line
    canvas.drawLine(Offset(leftX, toolStartY), Offset(leftX, toolEndY), paintLine);
    // Top tick
    canvas.drawLine(Offset(leftX - 5, toolStartY), Offset(leftX + 15, toolStartY), paintLine);
    // Bottom tick
    canvas.drawLine(Offset(leftX - 5, toolEndY), Offset(leftX + 15, toolEndY), paintLine);
    
    // Text L
    paintText.text = TextSpan(
      text: 'L ${length.toStringAsFixed(1)}',
      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono', backgroundColor: AppColors.surface),
    );
    paintText.layout();
    
    // Draw text rotated sideways
    canvas.save();
    canvas.translate(leftX - 10, size.height / 2 + paintText.width / 2);
    canvas.rotate(-3.14159 / 2);
    paintText.paint(canvas, Offset.zero);
    canvas.restore();

    // --- Draw Diameter (D) Dimension ---
    final bottomY = size.height * 0.9;
    final leftEdge = toolCenterX - toolRadiusPx;
    final rightEdge = toolCenterX + toolRadiusPx;

    // Horizontal line
    canvas.drawLine(Offset(leftEdge, bottomY), Offset(rightEdge, bottomY), paintLine);
    // Left tick
    canvas.drawLine(Offset(leftEdge, bottomY - 15), Offset(leftEdge, bottomY + 5), paintLine);
    // Right tick
    canvas.drawLine(Offset(rightEdge, bottomY - 15), Offset(rightEdge, bottomY + 5), paintLine);

    // Text D
    paintText.text = TextSpan(
      text: 'Ø ${diameter.toStringAsFixed(1)}',
      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono', backgroundColor: AppColors.surface),
    );
    paintText.layout();
    paintText.paint(canvas, Offset(toolCenterX - paintText.width / 2, bottomY - 8 - paintText.height));
  }

  @override
  bool shouldRepaint(covariant _ToolDimensionPainter oldDelegate) {
    return oldDelegate.diameter != diameter || oldDelegate.length != length;
  }
}
