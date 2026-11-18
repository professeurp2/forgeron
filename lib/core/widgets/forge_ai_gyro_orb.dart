import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/forgeron_colors.dart';

bool _shouldLoopInfiniteAnimations(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  if (bindingName.contains('Test')) return false;
  return true;
}

/// Noyau IA Gyroscopique 5-Axes — signature visuelle vectorielle de Forgeron IA.
class ForgeAiGyroOrb extends StatefulWidget {
  final double size;
  final bool alert;
  final bool problem;
  final bool active;

  const ForgeAiGyroOrb({
    super.key,
    this.size = 34,
    this.alert = false,
    this.problem = false,
    this.active = false,
  });

  @override
  State<ForgeAiGyroOrb> createState() => _ForgeAiGyroOrbState();
}

class _ForgeAiGyroOrbState extends State<ForgeAiGyroOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shouldLoopInfiniteAnimations(context)) {
      if (_ctrl.isAnimating) _ctrl.stop();
      _ctrl.value = 0.35;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final primary = widget.problem
        ? fc.danger
        : (widget.alert ? fc.warning : fc.primary);
    final secondary = widget.problem ? fc.error : fc.secondary;
    final coreHot = widget.problem ? Colors.white : fc.primaryLight;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _GyroOrbPainter(
                progress: _ctrl.value,
                primary: primary,
                secondary: secondary,
                coreHot: coreHot,
                active: widget.active || widget.alert || widget.problem,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GyroOrbPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color secondary;
  final Color coreHot;
  final bool active;

  const _GyroOrbPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.coreHot,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);
    final center = Offset(cx, cy);
    final t = progress;
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2);

    // 1. Halo radial d'ambiance
    final glowRadius = r * (active ? 0.96 : 0.88);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: active ? 0.42 + 0.16 * pulse : 0.28),
          primary.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, haloPaint);

    // 2. Trois anneaux gyroscopiques inclinés (axes A, C et broche)
    final strokeW = math.max(1.2, r * 0.085);
    _drawGyroRing(
      canvas,
      center,
      rx: r * 0.84,
      ry: r * 0.34,
      tilt: 0.42 + t * 2 * math.pi,
      sweepAngle: t * 2 * math.pi,
      colorA: primary,
      colorB: coreHot,
      strokeWidth: strokeW,
    );
    _drawGyroRing(
      canvas,
      center,
      rx: r * 0.80,
      ry: r * 0.32,
      tilt: -0.78 - t * 2 * math.pi * 0.7,
      sweepAngle: -t * 2 * math.pi * 0.7,
      colorA: secondary,
      colorB: primary,
      strokeWidth: strokeW * 0.9,
    );
    _drawGyroRing(
      canvas,
      center,
      rx: r * 0.66,
      ry: r * 0.56,
      tilt: 1.15 + t * 2 * math.pi * 0.5,
      sweepAngle: t * 4 * math.pi,
      colorA: coreHot.withValues(alpha: 0.9),
      colorB: secondary.withValues(alpha: 0.75),
      strokeWidth: strokeW * 0.75,
    );

    // 3. Cœur énergétique central pulsant + point spéculaire blanc
    final coreR = r * (0.24 + (active ? 0.05 * pulse : 0.02 * pulse));
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          coreHot,
          primary,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreR));
    canvas.drawCircle(center, coreR, corePaint);

    canvas.drawCircle(
      Offset(cx - coreR * 0.32, cy - coreR * 0.32),
      math.max(0.8, coreR * 0.28),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawGyroRing(
    Canvas canvas,
    Offset center, {
    required double rx,
    required double ry,
    required double tilt,
    required double sweepAngle,
    required Color colorA,
    required Color colorB,
    required double strokeWidth,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);

    final rect =
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: [
          colorA.withValues(alpha: 0.15),
          colorA,
          colorB,
          colorA.withValues(alpha: 0.2),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(rect);

    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GyroOrbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.active != active;
}
