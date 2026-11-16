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
///
/// Remplace l'emoji statique par un orbe cinématique composé de trois anneaux
/// coaxiaux inclinés (évoquant les axes rotatifs A/C et la broche 5 axes) et
/// d'un cœur thermique animé.
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

    // Point spéculaire supérieur gauche
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

    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
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

/// Cascade Bento échelonnée pour l'apparition orchestrée des panneaux.
///
/// N'utilise aucun [Timer] externe : l'échelonnement repose sur une courbe
/// [Interval] dans un [TweenAnimationBuilder], garantissant zéro fuite et
/// compatibilité totale avec les tests de balayage.
class BentoCascadeEntry extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration totalDuration;
  final Offset slideOffset;

  const BentoCascadeEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.totalDuration = const Duration(milliseconds: 520),
    this.slideOffset = const Offset(0, 14),
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) return child;

    final start = (index * 0.08).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: totalDuration,
      curve: Interval(start, 1.0, curve: Curves.easeOutQuart),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: slideOffset * (1.0 - t),
            child: Transform.scale(
              scale: 0.985 + 0.015 * t,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Barre de progression avec balayage laser continu et point chaud lumineux.
class LaserShimmerBar extends StatefulWidget {
  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final bool animate;
  final BorderRadius? borderRadius;

  const LaserShimmerBar({
    super.key,
    required this.value,
    this.height = 5,
    this.color,
    this.backgroundColor,
    this.animate = true,
    this.borderRadius,
  });

  @override
  State<LaserShimmerBar> createState() => _LaserShimmerBarState();
}

class _LaserShimmerBarState extends State<LaserShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(LaserShimmerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate || oldWidget.value != widget.value) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final active = widget.animate &&
        _shouldLoopInfiniteAnimations(context) &&
        widget.value > 0.0;
    if (active) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      if (_ctrl.isAnimating) _ctrl.stop();
      _ctrl.value = 0.5;
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
    final barColor = widget.color ?? fc.primary;
    final trackColor = widget.backgroundColor ?? fc.surfaceBorder;
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.height);
    final clamped = widget.value.isFinite ? widget.value.clamp(0.0, 1.0) : 0.0;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: trackColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 0.0;
              final fillW = maxW * clamped;
              if (fillW <= 0.5) return const SizedBox.shrink();

              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final sweep = _ctrl.value;
                      return Container(
                        width: fillW,
                        height: widget.height,
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          gradient: LinearGradient(
                            colors: [
                              barColor.withValues(alpha: 0.72),
                              barColor,
                              Color.lerp(barColor, Colors.white, 0.55)!,
                              barColor,
                            ],
                            stops: [
                              0.0,
                              (sweep - 0.18).clamp(0.0, 1.0),
                              sweep.clamp(0.0, 1.0),
                              (sweep + 0.18).clamp(0.0, 1.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Point chaud lumineux à la pointe de progression
                  if (clamped > 0.02 && clamped < 0.995)
                    Positioned(
                      left: (fillW - 3.0).clamp(0.0, math.max(0.0, maxW - 4.0)),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: radius,
                          boxShadow: [
                            BoxShadow(
                              color: barColor,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Enveloppe de surbrillance laser pour la ligne G-code active.
///
/// Lorsque [isCurrent] est vrai, anime une impulsion douce sur un liseré néon
/// latéral et un balayage horizontal subtil. Lorsque [isCurrent] est faux,
/// évite tout contrôleur d'animation inutile pour des listes à 60 fps.
class LaserActiveLineWrapper extends StatefulWidget {
  final bool isCurrent;
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const LaserActiveLineWrapper({
    super.key,
    required this.isCurrent,
    required this.color,
    required this.child,
    this.padding,
  });

  @override
  State<LaserActiveLineWrapper> createState() => _LaserActiveLineWrapperState();
}

class _LaserActiveLineWrapperState extends State<LaserActiveLineWrapper>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(LaserActiveLineWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrent != widget.isCurrent) {
      _syncController();
    }
  }

  void _syncController() {
    if (widget.isCurrent && _shouldLoopInfiniteAnimations(context)) {
      _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      );
      if (!_ctrl!.isAnimating) {
        _ctrl!.repeat(reverse: true);
      }
    } else {
      _ctrl?.stop();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent) {
      return Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: widget.child,
      );
    }

    final ctrl = _ctrl;
    if (ctrl == null) {
      return Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.14),
          border: Border(
            left: BorderSide(color: widget.color, width: 3),
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final t = ctrl.value;
        return Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.color.withValues(alpha: 0.18 + 0.08 * t),
                widget.color.withValues(alpha: 0.05 + 0.04 * t),
                Colors.transparent,
              ],
              stops: [0.0, 0.35 + 0.25 * t, 1.0],
            ),
            border: Border(
              left: BorderSide(color: widget.color, width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12 + 0.10 * t),
                blurRadius: 8,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Arrière-plan technique à grille orthogonale et repères en croix (`+`).
class TacticalGridBackground extends StatelessWidget {
  final Widget child;
  final double spacing;

  const TacticalGridBackground({
    super.key,
    required this.child,
    this.spacing = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return CustomPaint(
      painter: _TacticalGridPainter(
        gridColor: fc.tacticalGrid,
        accentColor: fc.primary.withValues(alpha: fc.isDark ? 0.09 : 0.07),
        spacing: spacing,
      ),
      child: child,
    );
  }
}

class _TacticalGridPainter extends CustomPainter {
  final Color gridColor;
  final Color accentColor;
  final double spacing;

  const _TacticalGridPainter({
    required this.gridColor,
    required this.accentColor,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || spacing <= 4) return;

    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final crossPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.0;

    int col = 0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      if (col % 4 == 0) {
        int row = 0;
        for (double y = 0; y <= size.height; y += spacing) {
          if (row % 4 == 0) {
            canvas.drawLine(Offset(x - 3, y), Offset(x + 3, y), crossPaint);
            canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), crossPaint);
          }
          row++;
        }
      }
      col++;
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_TacticalGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.spacing != spacing;
}

/// Visualiseur Trunnion 5-Axes natif Flutter (`CustomPainter` 3D isométrique).
///
/// Sert à la fois de moteur de rendu instantané pendant l'initialisation WebView2,
/// de repli haute fidélité sur Linux / macOS / headless tests (sans écran noir ni
/// spinner bloquant), et réagit en direct à `mPos`, `targetPos`, `toolpath`,
/// `activeIndex`, `showVectors` et `machineLimits`.
class ForgeNativeTrunnionCanvas extends StatefulWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;
  final List<double>? machineLimits;
  final Map<String, dynamic>? partMesh;
  final bool showMachine;
  final bool showWorkpiece;
  final bool showToolpath;
  final bool isInitialLoading;
  final String? fallbackReason;

  const ForgeNativeTrunnionCanvas({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
    this.machineLimits,
    this.partMesh,
    this.showMachine = true,
    this.showWorkpiece = true,
    this.showToolpath = true,
    this.isInitialLoading = false,
    this.fallbackReason,
  });

  @override
  State<ForgeNativeTrunnionCanvas> createState() =>
      _ForgeNativeTrunnionCanvasState();
}

class _ForgeNativeTrunnionCanvasState extends State<ForgeNativeTrunnionCanvas> {
  double _yaw = 0.64; // rad (~36.7°)
  double _pitch = 0.46; // rad (~26.4°)

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final x = widget.mPos.isNotEmpty ? widget.mPos[0] : 0.0;
    final y = widget.mPos.length > 1 ? widget.mPos[1] : 0.0;
    final z = widget.mPos.length > 2 ? widget.mPos[2] : 0.0;
    final a = widget.mPos.length > 3 ? widget.mPos[3] : 0.0;
    final c = widget.mPos.length > 4 ? widget.mPos[4] : 0.0;

    return ClipRect(
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _yaw = (_yaw - details.delta.dx * 0.008) % (math.pi * 2);
            _pitch = (_pitch + details.delta.dy * 0.006).clamp(0.14, 1.25);
          });
        },
        onDoubleTap: () {
          setState(() {
            _yaw = 0.64;
            _pitch = 0.46;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _NativeTrunnionPainter(
                fc: fc,
                mPos: widget.mPos,
                targetPos: widget.targetPos,
                toolpath: widget.toolpath,
                activeIndex: widget.activeIndex,
                showVectors: widget.showVectors,
                machineLimits: widget.machineLimits,
                partMesh: widget.partMesh,
                showMachine: widget.showMachine,
                showWorkpiece: widget.showWorkpiece,
                showToolpath: widget.showToolpath,
                yaw: _yaw,
                pitch: _pitch,
              ),
              child: const SizedBox.expand(),
            ),
            // Pill télémétrique supérieur droit (dégagé du badge haut-gauche & du ViewCube)
            Positioned(
              top: 12,
              right: 58,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fc.background.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: fc.surfaceBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isInitialLoading
                            ? fc.primary
                            : fc.secondary,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isInitialLoading
                                    ? fc.primary
                                    : fc.secondary)
                                .withValues(alpha: 0.65),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !widget.showMachine && widget.partMesh != null
                          ? 'APERÇU CAO · MAILLAGE 3D'
                          : (!widget.showMachine && widget.showToolpath
                              ? 'PARCOURS 5-AX · G-CODE'
                              : (widget.isInitialLoading
                                  ? 'TRUNNION 5-AX · SYNC'
                                  : '3D NATIF · RTCP')),
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: fc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bandeau discret A/C & XYZ en bas à droite (desktop / tablette)
            Positioned(
              right: 10,
              bottom: 10,
              child: LayoutBuilder(
                builder: (ctx, _) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: fc.background.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: fc.surfaceBorder),
                  ),
                  child: Text(
                    'X ${x.toStringAsFixed(1)}  Y ${y.toStringAsFixed(1)}  Z ${z.toStringAsFixed(1)}  ·  A ${a.toStringAsFixed(1)}°  C ${c.toStringAsFixed(1)}°',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: fc.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pt3 {
  final double x;
  final double y;
  final double z;
  const _Pt3(this.x, this.y, this.z);
}

class _NativeTrunnionPainter extends CustomPainter {
  final ForgeronColorPalette fc;
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;
  final List<double>? machineLimits;
  final Map<String, dynamic>? partMesh;
  final bool showMachine;
  final bool showWorkpiece;
  final bool showToolpath;
  final double yaw;
  final double pitch;

  _NativeTrunnionPainter({
    required this.fc,
    required this.mPos,
    required this.targetPos,
    required this.toolpath,
    required this.activeIndex,
    required this.showVectors,
    required this.machineLimits,
    required this.partMesh,
    required this.showMachine,
    required this.showWorkpiece,
    required this.showToolpath,
    required this.yaw,
    required this.pitch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 12 || size.height <= 12) return;
    final isDark = fc.background.computeLuminance() < 0.5;

    // 1. Fond studio radial CNC
    final bgTop = isDark ? const Color(0xFF0A0F17) : const Color(0xFFEBF0F6);
    final bgCenter = isDark ? const Color(0xFF141D2B) : const Color(0xFFF6F9FC);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.05),
        radius: 0.95,
        colors: [bgCenter, bgTop],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final minDim = math.min(size.width, size.height);
    final center = Offset(size.width * 0.50, size.height * 0.57);
    final scale = minDim * 0.00295; // ~100 mm -> ~0.295 * minDim

    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

    Offset project(_Pt3 p) {
      // Rotation yaw autour Z
      final rx = p.x * cosY - p.y * sinY;
      final ry = p.x * sinY + p.y * cosY;
      // Rotation pitch : Z monte vers le haut de l'écran
      final sx = rx * scale;
      final sy = (ry * sinP - p.z * cosP) * scale;
      return Offset(center.dx + sx, center.dy + sy);
    }

    // Transformation cinématique table A (autour X) & C (autour Z local)
    final aRad = (mPos.length > 3 ? mPos[3] : 0.0) * math.pi / 180.0;
    final cRad = (mPos.length > 4 ? mPos[4] : 0.0) * math.pi / 180.0;
    final cosA = math.cos(aRad);
    final sinA = math.sin(aRad);
    final cosC = math.cos(cRad);
    final sinC = math.sin(cRad);

    _Pt3 transformCradle(_Pt3 local) {
      // Rotation C autour Z local du plateau
      final cx = local.x * cosC - local.y * sinC;
      final cy = local.x * sinC + local.y * cosC;
      final cz = local.z;
      // Rotation A autour X (axe pivot trunnion à z = 0)
      final ay = cy * cosA - cz * sinA;
      final az = cy * sinA + cz * cosA;
      return _Pt3(cx, ay, az);
    }

    _Pt3 tiltOnlyA(_Pt3 local) {
      final ay = local.y * cosA - local.z * sinA;
      final az = local.y * sinA + local.z * cosA;
      return _Pt3(local.x, ay, az);
    }

    // 2. Grille perspective de référence sur le socle Z = -34
    const baseZ = -34.0;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF2B3A4D))
          .withValues(alpha: isDark ? 0.065 : 0.09)
      ..strokeWidth = 0.9;
    final majorGridPaint = Paint()
      ..color = fc.secondary.withValues(alpha: isDark ? 0.14 : 0.16)
      ..strokeWidth = 1.05;

    for (int g = -120; g <= 120; g += 24) {
      final pPaint = g == 0 ? majorGridPaint : gridPaint;
      canvas.drawLine(
        project(_Pt3(g.toDouble(), -120, baseZ)),
        project(_Pt3(g.toDouble(), 120, baseZ)),
        pPaint,
      );
      canvas.drawLine(
        project(_Pt3(-120, g.toDouble(), baseZ)),
        project(_Pt3(120, g.toDouble(), baseZ)),
        pPaint,
      );
    }

    // 3..6 Enveloppe machine, paliers A, berceau U et plateau rotatif C
    const platterR = 46.0;
    const platterZ = -8.0;
    if (showMachine) {
      final limX = (machineLimits != null && machineLimits!.isNotEmpty)
          ? machineLimits![0].clamp(80.0, 420.0) * 0.55
          : 108.0;
      final limY = (machineLimits != null && machineLimits!.length > 1)
          ? machineLimits![1].clamp(80.0, 420.0) * 0.55
          : 92.0;
      final limZ = (machineLimits != null && machineLimits!.length > 2)
          ? machineLimits![2].clamp(60.0, 320.0) * 0.55
          : 84.0;

      final envPaint = Paint()
        ..color = fc.surfaceBorder.withValues(alpha: isDark ? 0.45 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      final hx = limX * 0.5;
      final hy = limY * 0.5;
      final boxBottom = [
        _Pt3(-hx, -hy, baseZ),
        _Pt3(hx, -hy, baseZ),
        _Pt3(hx, hy, baseZ),
        _Pt3(-hx, hy, baseZ),
      ];
      final boxTop = [
        _Pt3(-hx, -hy, baseZ + limZ + 22),
        _Pt3(hx, -hy, baseZ + limZ + 22),
        _Pt3(hx, hy, baseZ + limZ + 22),
        _Pt3(-hx, hy, baseZ + limZ + 22),
      ];
      for (int i = 0; i < 4; i++) {
        final next = (i + 1) % 4;
        canvas.drawLine(
            project(boxBottom[i]), project(boxBottom[next]), envPaint);
        canvas.drawLine(project(boxTop[i]), project(boxTop[next]), envPaint);
        canvas.drawLine(project(boxBottom[i]), project(boxTop[i]), envPaint);
      }

      // 4. Paliers latéraux fixes du berceau Trunnion (axe A)
      final stanchionStroke = Paint()
        ..color = isDark ? const Color(0xFF44546B) : const Color(0xFF6B7B8F)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final stanchionFill = Paint()
        ..color = isDark ? const Color(0xFF1D2634) : const Color(0xFFCFD8E3)
        ..style = PaintingStyle.fill;

      for (final side in [-1.0, 1.0]) {
        final sx = side * 66.0;
        final poly = Path()
          ..moveTo(project(_Pt3(sx, -18, baseZ)).dx,
              project(_Pt3(sx, -18, baseZ)).dy)
          ..lineTo(project(_Pt3(sx, 18, baseZ)).dx,
              project(_Pt3(sx, 18, baseZ)).dy)
          ..lineTo(
              project(_Pt3(sx, 10, 6)).dx, project(_Pt3(sx, 10, 6)).dy)
          ..lineTo(
              project(_Pt3(sx, -10, 6)).dx, project(_Pt3(sx, -10, 6)).dy)
          ..close();
        canvas.drawPath(poly, stanchionFill);
        canvas.drawPath(poly, stanchionStroke);

        // Axe pivot A
        final pivotScreen = project(_Pt3(sx * 0.92, 0, 0));
        canvas.drawCircle(
          pivotScreen,
          5.5,
          Paint()..color = fc.primary.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          pivotScreen,
          2.4,
          Paint()..color = fc.background,
        );
      }

      // 5. Berceau basculant U-Cradle (rotatif A)
      final cradlePath = Path();
      final cradlePts = [
        tiltOnlyA(const _Pt3(-60, 0, 0)),
        tiltOnlyA(const _Pt3(-56, 0, -20)),
        tiltOnlyA(const _Pt3(56, 0, -20)),
        tiltOnlyA(const _Pt3(60, 0, 0)),
      ].map(project).toList();
      cradlePath.moveTo(cradlePts[0].dx, cradlePts[0].dy);
      for (int i = 1; i < cradlePts.length; i++) {
        cradlePath.lineTo(cradlePts[i].dx, cradlePts[i].dy);
      }
      canvas.drawPath(
        cradlePath,
        Paint()
          ..color = isDark ? const Color(0xFF566A82) : const Color(0xFF536378)
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );

      // 6. Plateau circulaire rotatif C (divisé en degrés + rainures en T)
      final ringPath = Path();
      for (int i = 0; i <= 48; i++) {
        final th = (i / 48.0) * math.pi * 2;
        final pt = project(transformCradle(
            _Pt3(math.cos(th) * platterR, math.sin(th) * platterR, platterZ)));
        if (i == 0) {
          ringPath.moveTo(pt.dx, pt.dy);
        } else {
          ringPath.lineTo(pt.dx, pt.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(
        ringPath,
        Paint()
          ..color = isDark ? const Color(0xFF1F2A3A) : const Color(0xFFDCE3EC)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        ringPath,
        Paint()
          ..color = fc.secondary.withValues(alpha: 0.72)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );

      // Rainures orthogonales T-slot du plateau (tournent avec C)
      final slotPaint = Paint()
        ..color = fc.secondary.withValues(alpha: 0.32)
        ..strokeWidth = 1.0;
      for (final deg in [0.0, 45.0, 90.0, 135.0]) {
        final r = deg * math.pi / 180.0;
        final p1 = project(transformCradle(_Pt3(
            math.cos(r) * (platterR - 4), math.sin(r) * (platterR - 4), platterZ)));
        final p2 = project(transformCradle(_Pt3(
            -math.cos(r) * (platterR - 4),
            -math.sin(r) * (platterR - 4),
            platterZ)));
        canvas.drawLine(p1, p2, slotPaint);
      }

      // Marqueur 0° du plateau C en Magma
      final cZero = project(transformCradle(const _Pt3(platterR + 2, 0, platterZ)));
      canvas.drawCircle(cZero, 3.0, Paint()..color = fc.primary);
    }

    // 7. Brut / pièce usinée centrée sur le plateau
    const stockX = 24.0;
    const stockY = 18.0;
    const stockH = 14.0;
    if (showWorkpiece) {
      final sBot = [
        const _Pt3(-stockX, -stockY, platterZ + 1),
        const _Pt3(stockX, -stockY, platterZ + 1),
        const _Pt3(stockX, stockY, platterZ + 1),
        const _Pt3(-stockX, stockY, platterZ + 1),
      ].map((p) => project(transformCradle(p))).toList();
      final sTop = [
        const _Pt3(-stockX, -stockY, platterZ + 1 + stockH),
        const _Pt3(stockX, -stockY, platterZ + 1 + stockH),
        const _Pt3(stockX, stockY, platterZ + 1 + stockH),
        const _Pt3(-stockX, stockY, platterZ + 1 + stockH),
      ].map((p) => project(transformCradle(p))).toList();

      final stockTopPath = Path()
        ..moveTo(sTop[0].dx, sTop[0].dy)
        ..lineTo(sTop[1].dx, sTop[1].dy)
        ..lineTo(sTop[2].dx, sTop[2].dy)
        ..lineTo(sTop[3].dx, sTop[3].dy)
        ..close();
      canvas.drawPath(
        stockTopPath,
        Paint()
          ..color = isDark
              ? const Color(0xFF2D3B4F).withValues(alpha: 0.72)
              : const Color(0xFFBBC6D6).withValues(alpha: 0.78),
      );
      final stockEdgePaint = Paint()
        ..color = isDark ? const Color(0xFF697F9B) : const Color(0xFF56667A)
        ..strokeWidth = 1.15
        ..style = PaintingStyle.stroke;
      canvas.drawPath(stockTopPath, stockEdgePaint);
      for (int i = 0; i < 4; i++) {
        final n = (i + 1) % 4;
        canvas.drawLine(sBot[i], sBot[n], stockEdgePaint);
        canvas.drawLine(sBot[i], sTop[i], stockEdgePaint);
      }
    }

    // 7b. Maillage 3D CAO (STEP / STL) lorsque `partMesh` est fourni
    if (partMesh != null) {
      final rawVerts = partMesh!['vertices'];
      final rawIdx = partMesh!['indices'];
      if (rawVerts is List && rawVerts.length >= 9) {
        final vCount = rawVerts.length ~/ 3;
        final verts = <_Pt3>[];
        double minX = double.infinity, maxX = -double.infinity;
        double minY = double.infinity, maxY = -double.infinity;
        double minZ = double.infinity, maxZ = -double.infinity;
        for (int i = 0; i < vCount; i++) {
          final x = (rawVerts[i * 3] as num).toDouble();
          final y = (rawVerts[i * 3 + 1] as num).toDouble();
          final z = (rawVerts[i * 3 + 2] as num).toDouble();
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
          if (z < minZ) minZ = z;
          if (z > maxZ) maxZ = z;
          verts.add(_Pt3(x, y, z));
        }
        final cx = (minX + maxX) * 0.5;
        final cy = (minY + maxY) * 0.5;
        final cz = (minZ + maxZ) * 0.5;
        final span = math.max(
          math.max(maxX - minX, maxY - minY),
          math.max(maxZ - minZ, 1.0),
        );
        final meshScale = (showMachine ? 24.0 : 54.0) * 2.0 / span;
        final zCenter = showMachine ? (platterZ + 1 + stockH * 0.5) : 0.0;

        final normVerts = verts.map((v) {
          final p = _Pt3(
            (v.x - cx) * meshScale,
            (v.y - cy) * meshScale,
            (v.z - cz) * meshScale + zCenter,
          );
          return showMachine ? transformCradle(p) : p;
        }).toList();

        final triIndices = <int>[];
        if (rawIdx is List && rawIdx.length >= 3) {
          for (final idx in rawIdx) {
            triIndices.add((idx as num).toInt());
          }
        } else {
          for (int i = 0; i + 2 < vCount; i += 3) {
            triIndices.addAll([i, i + 1, i + 2]);
          }
        }

        final tris = <(double, _Pt3, _Pt3, _Pt3, double)>[];
        for (int i = 0; i + 2 < triIndices.length; i += 3) {
          final a = triIndices[i];
          final b = triIndices[i + 1];
          final c = triIndices[i + 2];
          if (a < 0 || a >= normVerts.length || b < 0 || b >= normVerts.length || c < 0 || c >= normVerts.length) {
            continue;
          }
          final p0 = normVerts[a];
          final p1 = normVerts[b];
          final p2 = normVerts[c];
          final ux = p1.x - p0.x, uy = p1.y - p0.y, uz = p1.z - p0.z;
          final vx = p2.x - p0.x, vy = p2.y - p0.y, vz = p2.z - p0.z;
          final nx = uy * vz - uz * vy;
          final ny = uz * vx - ux * vz;
          final nz = ux * vy - uy * vx;
          final len = math.sqrt(nx * nx + ny * ny + nz * nz);
          final shade = len > 1e-6
              ? (0.28 + 0.72 * ((nx * 0.3 + ny * 0.35 + nz * 0.88).abs() / len))
                  .clamp(0.15, 1.0)
              : 0.5;
          double camDepth(_Pt3 p) {
            final ry = p.x * sinY + p.y * cosY;
            return ry * cosP + p.z * sinP;
          }
          final depth = (camDepth(p0) + camDepth(p1) + camDepth(p2)) / 3.0;
          tris.add((depth, p0, p1, p2, shade));
        }
        tris.sort((x, y) => x.$1.compareTo(y.$1));

        final edgePaint = Paint()
          ..color = fc.secondary.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = showMachine ? 0.8 : 1.1;
        for (final t in tris) {
          final s0 = project(t.$2);
          final s1 = project(t.$3);
          final s2 = project(t.$4);
          final path = Path()
            ..moveTo(s0.dx, s0.dy)
            ..lineTo(s1.dx, s1.dy)
            ..lineTo(s2.dx, s2.dy)
            ..close();
          final fill = Color.lerp(fc.surfaceBright, fc.secondary, t.$5 * 0.78) ??
              fc.surfaceBright;
          canvas.drawPath(
            path,
            Paint()..color = fill.withValues(alpha: 0.78),
          );
          canvas.drawPath(path, edgePaint);
        }
      }
    }

    // 8. Parcours d'outil 3D (ou courbe hélicoïdale nominale si vide)
    if (showToolpath) {
      final pts = toolpath;
      if (pts != null && pts.isNotEmpty) {
        double minX = double.infinity, maxX = -double.infinity;
        double minY = double.infinity, maxY = -double.infinity;
        double minZ = double.infinity, maxZ = -double.infinity;
        for (final p in pts) {
          if (p.length < 3) continue;
          if (p[0] < minX) minX = p[0];
          if (p[0] > maxX) maxX = p[0];
          if (p[1] < minY) minY = p[1];
          if (p[1] > maxY) maxY = p[1];
          if (p[2] < minZ) minZ = p[2];
          if (p[2] > maxZ) maxZ = p[2];
        }
        final spanX = math.max(maxX - minX, 1.0);
        final spanY = math.max(maxY - minY, 1.0);
        final spanZ = math.max(maxZ - minZ, 1.0);
        final maxXY = math.max(spanX, spanY);
        final normScale = (showMachine ? 38.0 : 64.0) / maxXY;
        final cx = (minX + maxX) * 0.5;
        final cy = (minY + maxY) * 0.5;
        final tpBaseZ = showMachine ? (platterZ + 1 + stockH + 2) : -14.0;
        final tpHeight = showMachine ? 18.0 : 32.0;

        _Pt3 mapTp(List<double> p) {
          final px = (p[0] - cx) * normScale;
          final py = (p[1] - cy) * normScale;
          final pz = tpBaseZ + ((p[2] - minZ) / spanZ) * tpHeight;
          return transformCradle(_Pt3(px, py, pz));
        }

        final donePath = Path();
        final todoPath = Path();
        final clampedActive = activeIndex.clamp(0, pts.length - 1);
        bool doneStarted = false;
        bool todoStarted = false;

        final step = math.max(1, pts.length ~/ 220);
        for (int i = 0; i < pts.length; i += step) {
          final p = pts[i];
          if (p.length < 3) continue;
          final worldPt = mapTp(p);
          final sp = project(worldPt);
          if (i <= clampedActive) {
            if (!doneStarted) {
              donePath.moveTo(sp.dx, sp.dy);
              doneStarted = true;
            } else {
              donePath.lineTo(sp.dx, sp.dy);
            }
          } else {
            if (!todoStarted) {
              // Relie au dernier point exécuté
              if (clampedActive < pts.length && pts[clampedActive].length >= 3) {
                final actSp = project(mapTp(pts[clampedActive]));
                todoPath.moveTo(actSp.dx, actSp.dy);
                todoPath.lineTo(sp.dx, sp.dy);
              } else {
                todoPath.moveTo(sp.dx, sp.dy);
              }
              todoStarted = true;
            } else {
              todoPath.lineTo(sp.dx, sp.dy);
            }
          }

          // Vecteurs normaux d'orientation outil si showVectors
          if (showVectors && i % (step * 4) == 0) {
            final tipWorld = mapTp(p);
            final tailWorld = _Pt3(
              tipWorld.x,
              tipWorld.y - sinA * 10,
              tipWorld.z + cosA * 10,
            );
            canvas.drawLine(
              project(tipWorld),
              project(tailWorld),
              Paint()
                ..color = fc.secondary.withValues(alpha: 0.45)
                ..strokeWidth = 0.9,
            );
          }
        }

        if (doneStarted) {
          canvas.drawPath(
            donePath,
            Paint()
              ..color = fc.success
              ..strokeWidth = 2.0
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke,
          );
        }
        if (todoStarted) {
          canvas.drawPath(
            todoPath,
            Paint()
              ..color = fc.primary.withValues(alpha: 0.85)
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke,
          );
        }
      } else {
        // Parcours calibré visuel si aucun G-code n'est chargé
        final idleArc = Path();
        for (int i = 0; i <= 40; i++) {
          final t = i / 40.0 * math.pi * 1.5;
          final p = project(transformCradle(_Pt3(
            math.cos(t) * 16.0,
            math.sin(t) * 11.0,
            platterZ + 1 + stockH + 4.0 + math.sin(t * 2) * 2.5,
          )));
          if (i == 0) {
            idleArc.moveTo(p.dx, p.dy);
          } else {
            idleArc.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(
          idleArc,
          Paint()
            ..color = fc.secondary.withValues(alpha: 0.45)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // 9. Broche verticale & fraise pointe active à mPos
    if (showMachine) {
      final mx = ((mPos.isNotEmpty ? mPos[0] : 0.0).clamp(-120.0, 120.0)) * 0.25;
      final my = ((mPos.length > 1 ? mPos[1] : 0.0).clamp(-120.0, 120.0)) * 0.25;
      final mz = ((mPos.length > 2 ? mPos[2] : 18.0).clamp(-10.0, 90.0)) * 0.35;
      final tip3 = _Pt3(mx, my, platterZ + 1 + stockH + 8 + mz);
      final tipScreen = project(tip3);
      final colletBottom = project(_Pt3(mx, my, tip3.z + 20));
      final spindleBottom = project(_Pt3(mx, my, tip3.z + 36));
      final spindleTop = project(_Pt3(mx, my, tip3.z + 70));

      // Portique / corps de broche
      canvas.drawLine(
        spindleTop,
        spindleBottom,
        Paint()
          ..color = isDark ? const Color(0xFF4B5C73) : const Color(0xFF475569)
          ..strokeWidth = 15
          ..strokeCap = StrokeCap.butt,
      );
      canvas.drawLine(
        spindleTop,
        spindleBottom,
        Paint()
          ..color = fc.rimHighlight.withValues(alpha: 0.45)
          ..strokeWidth = 1.2,
      );
      // Cône HSK
      canvas.drawLine(
        spindleBottom,
        colletBottom,
        Paint()
          ..color = isDark ? const Color(0xFF8395AB) : const Color(0xFF7B8CA1)
          ..strokeWidth = 8.5
          ..strokeCap = StrokeCap.round,
      );
      // Fraise carbure
      canvas.drawLine(
        colletBottom,
        tipScreen,
        Paint()
          ..color = fc.primaryLight
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );

      // Halo thermique pointe outil
      canvas.drawCircle(
        tipScreen,
        9.0,
        Paint()
          ..color = fc.primary.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(tipScreen, 3.2, Paint()..color = fc.primary);

      // Cible targetPos optionnelle
      if (targetPos != null && targetPos!.length >= 3) {
        final tx = (targetPos![0].clamp(-120.0, 120.0)) * 0.25;
        final ty = (targetPos![1].clamp(-120.0, 120.0)) * 0.25;
        final tz = (targetPos![2].clamp(-10.0, 90.0)) * 0.35;
        final tScreen = project(_Pt3(tx, ty, platterZ + 1 + stockH + 8 + tz));
        canvas.drawCircle(
          tScreen,
          5.5,
          Paint()
            ..color = fc.secondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
      }
    }

    // 10. Trièdre d'axes XYZ en bas à gauche
    final triadOrigin = Offset(28, size.height - 26);
    Offset projectDir(_Pt3 d) {
      final rx = d.x * cosY - d.y * sinY;
      final ry = d.x * sinY + d.y * cosY;
      return Offset(
        triadOrigin.dx + rx * 18.0,
        triadOrigin.dy + (ry * sinP - d.z * cosP) * 18.0,
      );
    }

    final axes = [
      ('X', const _Pt3(1, 0, 0), fc.axisX),
      ('Y', const _Pt3(0, 1, 0), fc.axisY),
      ('Z', const _Pt3(0, 0, 1), fc.axisZ),
    ];
    for (final (label, dir, col) in axes) {
      final end = projectDir(dir);
      canvas.drawLine(
        triadOrigin,
        end,
        Paint()
          ..color = col
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: col,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, end - Offset(tp.width * 0.5, tp.height * 0.5) + (end - triadOrigin) * 0.28);
    }

    // 11. ViewCube isométrique minimaliste en haut à droite
    if (size.width >= 200 && size.height >= 140) {
      final cubeCenter = Offset(size.width - 28, 28);
      Offset projCube(_Pt3 d) {
        final rx = d.x * cosY - d.y * sinY;
        final ry = d.x * sinY + d.y * cosY;
        return Offset(
          cubeCenter.dx + rx * 11.0,
          cubeCenter.dy + (ry * sinP - d.z * cosP) * 11.0,
        );
      }

      final cPts = [
        projCube(const _Pt3(-1, -1, 1)), // 0 top
        projCube(const _Pt3(1, -1, 1)),  // 1 top
        projCube(const _Pt3(1, 1, 1)),   // 2 top
        projCube(const _Pt3(-1, 1, 1)),  // 3 top
        projCube(const _Pt3(-1, -1, -1)), // 4 bot
        projCube(const _Pt3(1, -1, -1)),  // 5 bot
        projCube(const _Pt3(1, 1, -1)),   // 6 bot
        projCube(const _Pt3(-1, 1, -1)),  // 7 bot
      ];
      final topFace = Path()
        ..moveTo(cPts[0].dx, cPts[0].dy)
        ..lineTo(cPts[1].dx, cPts[1].dy)
        ..lineTo(cPts[2].dx, cPts[2].dy)
        ..lineTo(cPts[3].dx, cPts[3].dy)
        ..close();
      canvas.drawPath(
        topFace,
        Paint()
          ..color = fc.secondary.withValues(alpha: isDark ? 0.22 : 0.25),
      );
      final cubeStroke = Paint()
        ..color = fc.rimHighlight.withValues(alpha: 0.75)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 4; i++) {
        final n = (i + 1) % 4;
        canvas.drawLine(cPts[i], cPts[n], cubeStroke);
        canvas.drawLine(cPts[i + 4], cPts[n + 4], cubeStroke);
        canvas.drawLine(cPts[i], cPts[i + 4], cubeStroke);
      }
      final zLabel = TextPainter(
        text: TextSpan(
          text: 'ISO',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            color: fc.textDisabled,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      zLabel.paint(
        canvas,
        Offset(cubeCenter.dx - zLabel.width * 0.5, cubeCenter.dy + 16),
      );
    }
  }

  @override
  bool shouldRepaint(_NativeTrunnionPainter oldDelegate) =>
      oldDelegate.fc != fc ||
      oldDelegate.mPos != mPos ||
      oldDelegate.targetPos != targetPos ||
      oldDelegate.toolpath != toolpath ||
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.showVectors != showVectors ||
      oldDelegate.machineLimits != machineLimits ||
      oldDelegate.partMesh != partMesh ||
      oldDelegate.showMachine != showMachine ||
      oldDelegate.showWorkpiece != showWorkpiece ||
      oldDelegate.showToolpath != showToolpath ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch;
}

