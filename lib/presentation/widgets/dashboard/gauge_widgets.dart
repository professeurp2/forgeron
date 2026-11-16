import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/services/audio_service.dart';
import '../../../core/i18n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FORGERON GAUGE WIDGETS — Jauges cinétiques à traînée lumineuse (A et C)
// ═══════════════════════════════════════════════════════════════════════════════

/// Jauge en demi-arc pour l'axe A (Tilt), limite [-90°, +90°].
/// Ressemble à un tachymètre aéronautique : arc avec graduations fines,
/// aiguille lumineuse et traînée cinétique lors du déplacement.
class ArcGauge extends StatefulWidget {
  final double value;       // valeur courante en degrés
  final double minValue;    // minimum (défaut -90)
  final double maxValue;    // maximum (défaut +90)
  final Color color;
  final String axisLabel;
  final double size;

  const ArcGauge({
    super.key,
    required this.value,
    this.minValue = -90.0,
    this.maxValue = 90.0,
    this.color = Colors.orange,
    this.axisLabel = 'A',
    this.size = 160,
  });

  @override
  State<ArcGauge> createState() => _ArcGaugeState();
}

class _ArcGaugeState extends State<ArcGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late Animation<double> _trailAnim;
  double _displayValue = 0;
  double _trailValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _trailValue = widget.value;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _anim = Tween<double>(begin: widget.value, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _trailAnim = Tween<double>(begin: widget.value, end: widget.value).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.18, 1.0, curve: Curves.easeInOutCubic)));
    _ctrl.addListener(() {
      setState(() {
        _displayValue = _anim.value;
        _trailValue = _trailAnim.value;
      });
    });
  }

  @override
  void didUpdateWidget(ArcGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final fromMain = _displayValue;
      final fromTrail = _ctrl.isAnimating ? _trailValue : _displayValue;
      _anim = Tween<double>(begin: fromMain, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _trailAnim = Tween<double>(begin: fromTrail, end: widget.value).animate(
          CurvedAnimation(
              parent: _ctrl,
              curve: const Interval(0.18, 1.0, curve: Curves.easeInOutCubic)));
      _ctrl.forward(from: 0);
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
    final atLimit = _displayValue >= widget.maxValue - 0.5 ||
        _displayValue <= widget.minValue + 0.5;
    final activeColor = atLimit ? fc.danger : widget.color;

    return SizedBox(
      width: widget.size,
      height: widget.size * 0.65, // demi-cercle + espace valeur
      child: CustomPaint(
        painter: _ArcGaugePainter(
          value: _displayValue,
          trailValue: _trailValue,
          minValue: widget.minValue,
          maxValue: widget.maxValue,
          color: activeColor,
          surfaceBorder: fc.surfaceBorder,
          textDisabled: fc.textDisabled,
          danger: fc.danger,
        ),
        child: Align(
          alignment: const Alignment(0, 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_displayValue >= 0 ? '+' : ''}${_displayValue.toStringAsFixed(1)}°',
                style: TextStyle(
                  color: atLimit ? fc.danger : fc.textPrimary,
                  fontSize: widget.size * 0.135,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(
                      color: activeColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              Text(
                tr('AXE {}', [widget.axisLabel]),
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: fc.textDisabled,
                  fontSize: widget.size * 0.072,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double value;
  final double trailValue;
  final double minValue;
  final double maxValue;
  final Color color;
  final Color surfaceBorder;
  final Color textDisabled;
  final Color danger;

  _ArcGaugePainter({
    required this.value,
    required this.trailValue,
    required this.minValue,
    required this.maxValue,
    required this.color,
    required this.surfaceBorder,
    required this.textDisabled,
    required this.danger,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final radius = size.width * 0.44;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Arc va de 210° à 330° (demi-cercle bas vers haut)
    const startAngle = math.pi * 1.1;   // gauche
    const sweepAngle = math.pi * 0.8;   // 144° de sweep total

    // ── Arc intérieur fin métallique ──
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius - 7),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = surfaceBorder.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── Arc de fond (piste grise) ──
    final trackPaint = Paint()
      ..color = surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // ── Arc de valeur (progression colorée) ──
    final range = maxValue - minValue;
    final normalizedValue = ((value - minValue) / range).clamp(0.0, 1.0);
    final normalizedTrail = ((trailValue - minValue) / range).clamp(0.0, 1.0);
    final valueSweep = sweepAngle * normalizedValue;

    if (valueSweep > 0) {
      final valuePaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: startAngle + valueSweep,
          colors: [
            color.withValues(alpha: 0.45),
            color,
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, valueSweep, false, valuePaint);
    }

    // ── Traînée cinétique entre ancienne position et aiguille ──
    final trailDelta = (normalizedValue - normalizedTrail).abs();
    if (trailDelta > 0.004) {
      final a1 = startAngle + sweepAngle * normalizedTrail;
      final a2 = startAngle + sweepAngle * normalizedValue;
      final arcStart = math.min(a1, a2);
      final arcSweep = (a2 - a1).abs();
      final forward = a2 >= a1;
      final trailPaint = Paint()
        ..shader = SweepGradient(
          startAngle: arcStart,
          endAngle: arcStart + arcSweep,
          colors: forward
              ? [color.withValues(alpha: 0.05), color.withValues(alpha: 0.72)]
              : [color.withValues(alpha: 0.72), color.withValues(alpha: 0.05)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius + 4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 2),
        arcStart,
        arcSweep,
        false,
        trailPaint,
      );
    }

    // ── Graduations (toutes les 10°) ──
    final tickCount = ((maxValue - minValue) / 10).round() + 1;
    for (int i = 0; i < tickCount; i++) {
      final frac = i / (tickCount - 1);
      final angle = startAngle + sweepAngle * frac;
      final isMajor = i % 3 == 0;
      final tickLen = isMajor ? 8.0 : 4.0;
      final outerR = radius + 12;
      final innerR = outerR - tickLen;
      final tickPaint = Paint()
        ..color = isMajor
            ? textDisabled.withValues(alpha: 0.65)
            : textDisabled.withValues(alpha: 0.28)
        ..strokeWidth = isMajor ? 1.5 : 1.0;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR),
        Offset(cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR),
        tickPaint,
      );
    }

    // ── Aiguille (tick lumineux) ──
    final needleAngle = startAngle + sweepAngle * normalizedValue;
    final needleOuter = radius + 16;
    final needleInner = radius - 8;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + math.cos(needleAngle) * needleInner,
          cy + math.sin(needleAngle) * needleInner),
      Offset(cx + math.cos(needleAngle) * needleOuter,
          cy + math.sin(needleAngle) * needleOuter),
      glowPaint,
    );
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + math.cos(needleAngle) * needleInner,
          cy + math.sin(needleAngle) * needleInner),
      Offset(cx + math.cos(needleAngle) * needleOuter,
          cy + math.sin(needleAngle) * needleOuter),
      needlePaint,
    );

    // ── Labels limites ──
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, double angle, double r) {
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
            color: textDisabled,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.w700),
      );
      tp.layout();
      final pos = Offset(cx + math.cos(angle) * r - tp.width / 2,
          cy + math.sin(angle) * r - tp.height / 2);
      tp.paint(canvas, pos);
    }

    drawLabel('${minValue.toInt()}°', startAngle, radius + 26);
    drawLabel('0°', startAngle + sweepAngle / 2, radius + 26);
    drawLabel('+${maxValue.toInt()}°', startAngle + sweepAngle, radius + 26);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.value != value ||
      old.trailValue != trailValue ||
      old.color != color ||
      old.surfaceBorder != surfaceBorder;
}

// ═══════════════════════════════════════════════════════════════════════════════
/// Jauge anneau 360° pour l'axe C (plateau rotatif).
/// Anneau donut avec tick lumineux, traînée cinétique, 12 points cardinaux, valeur au centre.
class RingGauge extends StatefulWidget {
  final double value;  // 0 à 360
  final Color color;
  final String axisLabel;
  final double size;

  const RingGauge({
    super.key,
    required this.value,
    this.color = Colors.cyan,
    this.axisLabel = 'C',
    this.size = 150,
  });

  @override
  State<RingGauge> createState() => _RingGaugeState();
}

class _RingGaugeState extends State<RingGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late Animation<double> _trailAnim;
  double _displayValue = 0;
  double _trailValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _trailValue = widget.value;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _anim = Tween<double>(begin: widget.value, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _trailAnim = Tween<double>(begin: widget.value, end: widget.value).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.18, 1.0, curve: Curves.easeInOutCubic)));
    _ctrl.addListener(() {
      setState(() {
        _displayValue = _anim.value;
        _trailValue = _trailAnim.value;
      });
    });
  }

  @override
  void didUpdateWidget(RingGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final fromMain = _displayValue;
      final fromTrail = _ctrl.isAnimating ? _trailValue : _displayValue;
      _anim = Tween<double>(begin: fromMain, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _trailAnim = Tween<double>(begin: fromTrail, end: widget.value).animate(
          CurvedAnimation(
              parent: _ctrl,
              curve: const Interval(0.18, 1.0, curve: Curves.easeInOutCubic)));
      _ctrl.forward(from: 0);
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _RingGaugePainter(
          value: _displayValue,
          trailValue: _trailValue,
          color: widget.color,
          surfaceBorder: fc.surfaceBorder,
          textDisabled: fc.textDisabled,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_displayValue.toStringAsFixed(1)}°',
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: widget.size * 0.13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              Text(
                tr('AXE {}', [widget.axisLabel]),
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: fc.textDisabled,
                  fontSize: widget.size * 0.072,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double value;
  final double trailValue;
  final Color color;
  final Color surfaceBorder;
  final Color textDisabled;

  const _RingGaugePainter({
    required this.value,
    required this.trailValue,
    required this.color,
    required this.surfaceBorder,
    required this.textDisabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width * 0.46;
    final innerR = size.width * 0.35;
    final midR = (outerR + innerR) / 2;
    final ringRect = Rect.fromCircle(center: Offset(cx, cy), radius: midR);

    // ── Anneau interne biseauté ──
    canvas.drawCircle(
      Offset(cx, cy),
      innerR - 3,
      Paint()
        ..color = surfaceBorder.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── Piste de fond ──
    final trackPaint = Paint()
      ..color = surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR;
    canvas.drawCircle(Offset(cx, cy), midR, trackPaint);

    // ── Arc de progression ──
    final progressAngle = (value / 360) * 2 * math.pi;
    if (progressAngle > 0) {
      final arcPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + progressAngle,
          colors: [color.withValues(alpha: 0.35), color],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        ringRect,
        -math.pi / 2, progressAngle, false, arcPaint,
      );
    }

    // ── Traînée cinétique angulaire (hors franchissement 360°→0°) ──
    final degDiff = (value - trailValue).abs();
    if (degDiff > 1.0 && degDiff < 180.0) {
      final a1 = (trailValue - 90) * math.pi / 180;
      final a2 = (value - 90) * math.pi / 180;
      final arcStart = math.min(a1, a2);
      final arcSweep = (a2 - a1).abs();
      final forward = value >= trailValue;
      final trailPaint = Paint()
        ..shader = SweepGradient(
          startAngle: arcStart,
          endAngle: arcStart + arcSweep,
          colors: forward
              ? [color.withValues(alpha: 0.05), color.withValues(alpha: 0.72)]
              : [color.withValues(alpha: 0.72), color.withValues(alpha: 0.05)],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (outerR - innerR) + 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(ringRect, arcStart, arcSweep, false, trailPaint);
    }

    // ── Points cardinaux (0°, 30°, 60°, ...) ──
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final isMajor = i % 3 == 0;
      final dotR = isMajor ? 3.2 : 1.5;
      final dotPos = Offset(
        cx + math.cos(angle) * (outerR + 6),
        cy + math.sin(angle) * (outerR + 6),
      );
      canvas.drawCircle(
        dotPos,
        dotR,
        Paint()
          ..color = isMajor
              ? color.withValues(alpha: 0.75)
              : textDisabled.withValues(alpha: 0.25),
      );
    }

    // ── Aiguille tick lumineux ──
    final needleAngle = (value - 90) * math.pi / 180;
    // Glow
    canvas.drawLine(
      Offset(cx + math.cos(needleAngle) * innerR,
          cy + math.sin(needleAngle) * innerR),
      Offset(cx + math.cos(needleAngle) * (outerR + 10),
          cy + math.sin(needleAngle) * (outerR + 10)),
      Paint()
        ..color = color.withValues(alpha: 0.42)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    // Tick net
    canvas.drawLine(
      Offset(cx + math.cos(needleAngle) * innerR,
          cy + math.sin(needleAngle) * innerR),
      Offset(cx + math.cos(needleAngle) * (outerR + 10),
          cy + math.sin(needleAngle) * (outerR + 10)),
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // ── Ligne du centre vers aiguille (subtile) ──
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.cos(needleAngle) * innerR,
          cy + math.sin(needleAngle) * innerR),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RingGaugePainter old) =>
      old.value != value ||
      old.trailValue != trailValue ||
      old.color != color ||
      old.surfaceBorder != surfaceBorder;
}

// ═══════════════════════════════════════════════════════════════════════════════
/// Croix de jog XY redesignée — boutons flat modernes avec glow directionnel.
class DpadCross extends StatelessWidget {
  final VoidCallback onXPlus;
  final VoidCallback onXMinus;
  final VoidCallback onYPlus;
  final VoidCallback onYMinus;
  final VoidCallback? onStop;
  final double size;

  const DpadCross({
    super.key,
    required this.onXPlus,
    required this.onXMinus,
    required this.onYPlus,
    required this.onYMinus,
    this.onStop,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = size * 0.32;
    final centerSize = size * 0.22;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Y+
          Positioned(
            top: 0,
            left: size / 2 - btnSize / 2,
            child: _DpadBtn(
              icon: Icons.arrow_drop_up_rounded,
              color: context.fc.axisY,
              size: btnSize,
              onTap: onYPlus,
            ),
          ),
          // Y-
          Positioned(
            bottom: 0,
            left: size / 2 - btnSize / 2,
            child: _DpadBtn(
              icon: Icons.arrow_drop_down_rounded,
              color: context.fc.axisY,
              size: btnSize,
              onTap: onYMinus,
            ),
          ),
          // X-
          Positioned(
            left: 0,
            top: size / 2 - btnSize / 2,
            child: _DpadBtn(
              icon: Icons.arrow_left_rounded,
              color: context.fc.axisX,
              size: btnSize,
              onTap: onXMinus,
            ),
          ),
          // X+
          Positioned(
            right: 0,
            top: size / 2 - btnSize / 2,
            child: _DpadBtn(
              icon: Icons.arrow_right_rounded,
              color: context.fc.axisX,
              size: btnSize,
              onTap: onXPlus,
            ),
          ),
          // Centre (stop) — son alert + vibration forte
          _DpadStopBtn(size: centerSize, onStop: onStop),
        ],
      ),
    );
  }
}

// Bouton directionnel du D-pad — son click uniforme + haptic light
class _DpadBtn extends ConsumerStatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _DpadBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  ConsumerState<_DpadBtn> createState() => _DpadBtnState();
}

class _DpadBtnState extends ConsumerState<_DpadBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
        // Son click uniforme (même pattern que cnc_panel_screen)
        ref.read(audioServiceProvider).play(SoundEffect.click);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _pressed
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fc.surfaceBright, fc.surface],
                  ),
            color: _pressed ? widget.color.withValues(alpha: 0.25) : null,
            border: Border.all(
              color: _pressed
                  ? widget.color.withValues(alpha: 0.75)
                  : fc.surfaceBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.15 : 0.38),
                blurRadius: _pressed ? 2 : 8,
                offset: Offset(0, _pressed ? 0 : 3),
              ),
              if (_pressed)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: _pressed ? widget.color : fc.textSecondary,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );
  }
}

// Bouton stop central du D-pad — son alert + vibration forte
class _DpadStopBtn extends ConsumerStatefulWidget {
  final double size;
  final VoidCallback? onStop;
  const _DpadStopBtn({required this.size, this.onStop});

  @override
  ConsumerState<_DpadStopBtn> createState() => _DpadStopBtnState();
}

class _DpadStopBtnState extends ConsumerState<_DpadStopBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onStop == null) return;
        setState(() => _pressed = true);
        widget.onStop!();
        // Son d'alerte différencié pour le stop (plus grave que click)
        ref.read(audioServiceProvider).play(SoundEffect.alert);
        HapticFeedback.heavyImpact();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _pressed
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fc.surfaceBright, fc.surface],
                  ),
            color: _pressed ? fc.danger.withValues(alpha: 0.22) : null,
            border: Border.all(
              color: _pressed
                  ? fc.danger.withValues(alpha: 0.7)
                  : fc.surfaceBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.15 : 0.38),
                blurRadius: _pressed ? 2 : 8,
                offset: Offset(0, _pressed ? 0 : 2),
              ),
              if (_pressed)
                BoxShadow(
                  color: fc.danger.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Icon(
            Icons.stop_rounded,
            color: _pressed
                ? fc.danger
                : fc.textDisabled.withValues(alpha: 0.55),
            size: widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
/// Bouton axe Z — pill button vertical (Z+ / Z-)
// Bouton axe Z — son click + haptic light (même pattern que D-pad)
class ZAxisButton extends ConsumerStatefulWidget {
  final bool isPlus;
  final VoidCallback onTap;

  const ZAxisButton({super.key, required this.isPlus, required this.onTap});

  @override
  ConsumerState<ZAxisButton> createState() => _ZAxisButtonState();
}

class _ZAxisButtonState extends ConsumerState<ZAxisButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
        ref.read(audioServiceProvider).play(SoundEffect.click);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 60,
          height: 52, // cible tactile confortable (≥ 48 dp)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: _pressed
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fc.surfaceBright, fc.surface],
                  ),
            color: _pressed ? fc.axisZ.withValues(alpha: 0.22) : null,
            border: Border.all(
              color: _pressed
                  ? fc.axisZ.withValues(alpha: 0.75)
                  : fc.surfaceBorder,
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [BoxShadow(color: fc.axisZ.withValues(alpha: 0.25), blurRadius: 10)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isPlus ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                color: _pressed ? fc.axisZ : fc.axisZ.withValues(alpha: 0.65),
                size: 22,
              ),
              Text(
                widget.isPlus ? 'Z+' : 'Z−',
                style: TextStyle(
                  color: _pressed ? fc.axisZ : fc.axisZ.withValues(alpha: 0.65),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
/// Bouton de jog rotatif A/C — pill button avec flèche et label
// Bouton jog rotatif A/C — son click uniforme + haptic light
class RotaryJogButton extends ConsumerStatefulWidget {
  final bool isPlus;
  final String axisLabel;
  final Color color;
  final VoidCallback onTap;

  const RotaryJogButton({
    super.key,
    required this.isPlus,
    required this.axisLabel,
    required this.color,
    required this.onTap,
  });

  @override
  ConsumerState<RotaryJogButton> createState() => _RotaryJogButtonState();
}

class _RotaryJogButtonState extends ConsumerState<RotaryJogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
        // Son click uniforme (même que les autres boutons de jog)
        ref.read(audioServiceProvider).play(SoundEffect.click);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: _pressed
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fc.surfaceBright, fc.surface],
                  ),
            color: _pressed ? widget.color.withValues(alpha: 0.22) : null,
            border: Border.all(
              color: _pressed
                  ? widget.color.withValues(alpha: 0.85)
                  : widget.color.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.28), blurRadius: 10)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isPlus)
                Icon(Icons.rotate_left_rounded,
                    color: _pressed ? widget.color : widget.color.withValues(alpha: 0.65),
                    size: 16),
              const SizedBox(width: 4),
              Text(
                '${widget.axisLabel}${widget.isPlus ? '+' : '−'}',
                style: TextStyle(
                  color: _pressed ? widget.color : widget.color.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(width: 4),
              if (widget.isPlus)
                Icon(Icons.rotate_right_rounded,
                    color: _pressed ? widget.color : widget.color.withValues(alpha: 0.65),
                    size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
/// Carte DRO premium — grande police, indicateur de direction animé.
class DroBigCard extends StatefulWidget {
  final String axis;
  final double value;
  final Color color;
  final bool isRotary; // true = affiche °, false = mm

  const DroBigCard({
    super.key,
    required this.axis,
    required this.value,
    required this.color,
    this.isRotary = false,
  });

  @override
  State<DroBigCard> createState() => _DroBigCardState();
}

class _DroBigCardState extends State<DroBigCard> {
  double? _oldValue;
  String _direction = 'idle';
  Timer? _idleTimer;

  @override
  void didUpdateWidget(DroBigCard old) {
    super.didUpdateWidget(old);
    if (_oldValue != null && widget.value != old.value) {
      final diff = widget.value - _oldValue!;
      if (diff.abs() > 0.0005) {
        setState(() => _direction = diff > 0 ? 'up' : 'down');
        _idleTimer?.cancel();
        _idleTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _direction = 'idle');
        });
      }
    }
    _oldValue = widget.value;
  }

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = widget.isRotary
        ? '${widget.value.toStringAsFixed(2)}°'
        : widget.value.toStringAsFixed(3);

    final moving = _direction != 'idle';
    final isUp = _direction == 'up';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: context.fc.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.fc.surfaceBorder, width: 1),
        boxShadow: moving
            ? [BoxShadow(
                color: widget.color.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: 1,
              )]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Bord gauche coloré animé (contourne la limitation Border non-uniforme)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                color: moving
                    ? widget.color
                    : widget.color.withValues(alpha: 0.4),
              ),
              // Contenu principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      // Lettre de l'axe
                      SizedBox(
                        width: 22,
                        child: Text(
                          widget.axis,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono',
                            shadows: moving
                                ? [Shadow(
                                    color: widget.color.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  )]
                                : null,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      // Indicateur direction ▲/▼
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: moving ? 1.0 : 0.2,
                        child: Icon(
                          moving
                              ? (isUp
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded)
                              : Icons.remove,
                          color: isUp ? context.fc.success : context.fc.danger,
                          size: 20,
                        ),
                      ),
                      // Valeur numérique
                      Expanded(
                        child: Text(
                          displayVal,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: context.fc.textPrimary,
                            fontSize: widget.isRotary ? 20 : 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono',
                            shadows: moving
                                ? [Shadow(
                                    color: widget.color.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                  )]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

