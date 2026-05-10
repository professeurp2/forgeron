import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import '../../core/theme/app_colors.dart';

class TrunnionVisualizer extends StatelessWidget {
  final List<double> mPos; // [X, Y, Z, A, C]
  final List<double>? targetPos; // [X, Y, Z, A, C]
  final List<List<double>>? toolpath;

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                AppColors.surfaceBright.withOpacity(0.1),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: TrunnionPainter(
              mPos: mPos,
              targetPos: targetPos,
              toolpath: toolpath,
            ),
          ),
        );
      },
    );
  }
}

class TrunnionPainter extends CustomPainter {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;

  TrunnionPainter({required this.mPos, this.targetPos, this.toolpath});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6); // Abaisser un peu le centre
    final scale = math.min(size.width, size.height) / 350; // Agrandir l'échelle

    // Vue perspective plus "Pro"
    double yaw = -math.pi / 5;
    double pitch = math.pi / 8;

    final projection = v64.Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(scale, -scale, scale) 
      ..rotateX(pitch)
      ..rotateY(yaw);

    _drawMachineBase(canvas, projection);
    
    // --- GHOST (Cible) ---
    if (targetPos != null) {
      _drawKinematicChain(canvas, projection, targetPos!, isGhost: true);
    }

    // --- RÉEL ---
    _drawKinematicChain(canvas, projection, mPos);
    
    // --- TOOLPATH ---
    if (toolpath != null && toolpath!.isNotEmpty) {
       _drawToolpath(canvas, projection);
    }
  }

  void _drawMachineBase(Canvas canvas, v64.Matrix4 transform) {
    final paint = Paint()
      ..color = AppColors.surfaceBorder.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Socle de la machine
    _drawBox(canvas, transform, v64.Vector3(-120, -120, -50), v64.Vector3(120, 120, -40), paint, filled: true);
    
    // Colonnes Z (fond)
    final colPaint = Paint()..color = AppColors.surfaceBright.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 2;
    _drawBox(canvas, transform, v64.Vector3(-100, 80, -40), v64.Vector3(-80, 100, 150), colPaint);
    _drawBox(canvas, transform, v64.Vector3(80, 80, -40), v64.Vector3(100, 100, 150), colPaint);
  }

  void _drawKinematicChain(Canvas canvas, v64.Matrix4 transform, List<double> pos, {bool isGhost = false}) {
    final opacity = isGhost ? 0.2 : 1.0;
    
    // 1. Berceau (Axe A)
    final angleA = pos[3] * math.pi / 180;
    final cradleMat = transform.clone()..rotateX(angleA);
    _drawCradleProfessional(canvas, cradleMat, opacity);

    // 2. Plateau (Axe C)
    final angleC = pos[4] * math.pi / 180;
    final tableMat = cradleMat.clone()..rotateZ(angleC);
    _drawTableProfessional(canvas, tableMat, opacity);

    // 3. Outil (X, Y, Z)
    _drawToolProfessional(canvas, transform, pos[0], pos[1], pos[2], opacity);
  }

  void _drawCradleProfessional(Canvas canvas, v64.Matrix4 transform, double opacity) {
    final paint = Paint()
      ..color = AppColors.axisA.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Bras latéraux massifs
    _drawBox(canvas, transform, v64.Vector3(-90, -30, -20), v64.Vector3(-70, 30, 20), paint);
    _drawBox(canvas, transform, v64.Vector3(70, -30, -20), v64.Vector3(90, 30, 20), paint);
    
    // Traverse centrale
    _drawBox(canvas, transform, v64.Vector3(-70, -40, -15), v64.Vector3(70, 40, -5), paint);
  }

  void _drawTableProfessional(Canvas canvas, v64.Matrix4 transform, double opacity) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Plateau circulaire avec rainures en T
    final radius = 65.0;
    for (var r in [radius, radius * 0.7, radius * 0.4]) {
      final points = <Offset>[];
      for (var i = 0; i <= 24; i++) {
        final phi = (i / 24) * 2 * math.pi;
        points.add(_project(transform, v64.Vector3(r * math.cos(phi), r * math.sin(phi), 0)));
      }
      canvas.drawPoints(PointMode.polygon, points, paint);
    }
    
    // Rainures radiales
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawLine(
        _project(transform, v64.Vector3(10 * math.cos(angle), 10 * math.sin(angle), 0)),
        _project(transform, v64.Vector3(radius * math.cos(angle), radius * math.sin(angle), 0)),
        paint
      );
    }
  }

  void _drawToolProfessional(Canvas canvas, v64.Matrix4 transform, double x, double y, double z, double opacity) {
    final toolPos = v64.Vector3(x, y, z);
    final pTip = _project(transform, toolPos);
    final pBase = _project(transform, toolPos + v64.Vector3(0, 0, 40));
    final pHead = _project(transform, toolPos + v64.Vector3(0, 0, 80));

    // Broche industrielle
    final spindlePaint = Paint()..color = AppColors.secondary.withOpacity(opacity * 0.4)..style = PaintingStyle.fill;
    _drawBox(canvas, transform, toolPos + v64.Vector3(-15, -15, 40), toolPos + v64.Vector3(15, 15, 80), spindlePaint, filled: true);
    
    // Corps de l'outil
    canvas.drawLine(pBase, pTip, Paint()..color = AppColors.primary.withOpacity(opacity)..strokeWidth = 4..strokeCap = StrokeCap.round);
    
    // Effet de rotation (cercle à la base)
    final ringPoints = <Offset>[];
    for (var i = 0; i <= 12; i++) {
      final phi = (i / 12) * 2 * math.pi;
      ringPoints.add(_project(transform, toolPos + v64.Vector3(5 * math.cos(phi), 5 * math.sin(phi), 10)));
    }
    canvas.drawPoints(PointMode.polygon, ringPoints, Paint()..color = Colors.white.withOpacity(opacity * 0.3)..strokeWidth = 1);
  }

  void _drawToolpath(Canvas canvas, v64.Matrix4 transform) {
    final pathPaint = Paint()
      ..shader = LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.primary]).createShader(Rect.fromLTWH(0, 0, 1000, 1000))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final points = toolpath!.map((p) => _project(transform, v64.Vector3(p[0], p[1], p[2]))).toList();
    canvas.drawPoints(PointMode.polygon, points, pathPaint);
  }

  void _drawBox(Canvas canvas, v64.Matrix4 transform, v64.Vector3 min, v64.Vector3 max, Paint paint, {bool filled = false}) {
    final vertices = [
      v64.Vector3(min.x, min.y, min.z), v64.Vector3(max.x, min.y, min.z),
      v64.Vector3(max.x, max.y, min.z), v64.Vector3(min.x, max.y, min.z),
      v64.Vector3(min.x, min.y, max.z), v64.Vector3(max.x, min.y, max.z),
      v64.Vector3(max.x, max.y, max.z), v64.Vector3(min.x, max.y, max.z),
    ];
    final p = vertices.map((v) => _project(transform, v)).toList();

    if (filled) {
       final path = Path()..moveTo(p[4].dx, p[4].dy)..lineTo(p[5].dx, p[5].dy)..lineTo(p[6].dx, p[6].dy)..lineTo(p[7].dx, p[7].dy)..close();
       canvas.drawPath(path, paint);
    }
    
    void line(int i, int j) => canvas.drawLine(p[i], p[j], paint);
    line(0, 1); line(1, 2); line(2, 3); line(3, 0);
    line(4, 5); line(5, 6); line(6, 7); line(7, 4);
    line(0, 4); line(1, 5); line(2, 6); line(3, 7);
  }

  Offset _project(v64.Matrix4 transform, v64.Vector3 v) {
    final v4 = v64.Vector4(v.x, v.y, v.z, 1.0);
    final proj = transform * v4;
    return Offset(proj.x, proj.y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
