import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CNC PANEL WIDGETS — Composants réutilisables style pupitre FANUC industriel
// ═══════════════════════════════════════════════════════════════════════════════

/// Étiquette de section du pupitre, style gravure industrielle.
class CncSectionLabel extends StatelessWidget {
  final String text;
  const CncSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 3, height: 10, color: AppColors.primary.withValues(alpha: 0.5)),
        SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
/// Voyant LED rond animé — style pupitre industriel.
/// [isActive] contrôle si le voyant pulse.
class CncLedIndicator extends StatefulWidget {
  final Color color;
  final bool isActive;
  final double size;

  const CncLedIndicator({
    super.key,
    required this.color,
    this.isActive = true,
    this.size = 10,
  });

  @override
  State<CncLedIndicator> createState() => _CncLedIndicatorState();
}

class _CncLedIndicatorState extends State<CncLedIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(CncLedIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isActive && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isActive ? widget.color : AppColors.textDisabled.withValues(alpha: 0.3);
    return AnimatedBuilder(
      animation: _anim,
      // ignore: avoid_types_on_closure_parameters
      builder: (context, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: widget.isActive ? _anim.value : 0.25),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: _anim.value * 0.8),
                    blurRadius: widget.size * 1.2,
                    spreadRadius: widget.size * 0.2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
/// Touche physique style pupitre CNC.
/// Supporte le maintien (hold) pour le jog continu.
class CncKeyButton extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final double height;
  final double? width;
  final bool isActive;
  final bool isDanger;

  const CncKeyButton({
    super.key,
    required this.child,
    required this.color,
    this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
    this.height = 52,
    this.width,
    this.isActive = false,
    this.isDanger = false,
  });

  @override
  State<CncKeyButton> createState() => _CncKeyButtonState();
}

class _CncKeyButtonState extends State<CncKeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Dégradé 3D du bouton : clair en haut, plus sombre en bas (effet bombé)
    final normalGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: widget.isActive
          ? [
              widget.color.withValues(alpha: 0.25),
              widget.color.withValues(alpha: 0.1),
            ]
          : widget.isDanger
              ? [
                  AppColors.danger.withValues(alpha: 0.3),
                  AppColors.danger.withValues(alpha: 0.12),
                ]
              : [
                  AppColors.surfaceBright,
                  AppColors.keyBezel,
                ],
    );

    final pressedGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: widget.isDanger
          ? [
              AppColors.danger.withValues(alpha: 0.05),
              AppColors.danger.withValues(alpha: 0.18),
            ]
          : [
              AppColors.keyActive,
              AppColors.surface,
            ],
    );

    final borderColor = widget.isActive
        ? widget.color.withValues(alpha: 0.8)
        : _pressed
            ? widget.color.withValues(alpha: 0.5)
            : AppColors.keyBorder;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onHoldStart != null
          ? (_) {
              setState(() => _pressed = true);
              widget.onHoldStart!();
            }
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onHoldEnd != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onHoldEnd!();
            }
          : (_) => setState(() => _pressed = false),
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.onHoldEnd?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: widget.height,
        width: widget.width,
        transform: _pressed
            ? Matrix4.translationValues(0, 2.5, 0) // Enfoncement plus marqué
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: _pressed ? pressedGradient : normalGradient,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: _pressed
              ? [
                  // Ombre fine quand le bouton est cliqué
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : [
                  // Ombre portée 3D prononcée en position relevée
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 4.5),
                    blurRadius: 4,
                  ),
                  // Ligne de lumière interne en haut
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    offset: const Offset(0, -1),
                    blurRadius: 0,
                  ),
                  if (widget.isActive)
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
/// Écran LCD style FANUC industriel.
/// Fond vert très sombre, texte phosphore.
class CncLcdScreen extends StatelessWidget {
  final Widget child;
  final String? title;

  const CncLcdScreen({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.lcdBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.lcdText.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
          // Ombre interne pour l'effet de cadre physique
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Fond avec gradient radial pour simuler l'effet écran CRT (plus lumineux au centre)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      // Point chaud légèrement plus vert-lumineux au centre
                      Color(0xFF0D250A),
                      AppColors.lcdBackground,
                    ],
                  ),
                ),
              ),
            ),
            
            // Les scanlines par-dessus le fond mais sous le texte
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: const _CncLcdScanlinePainter(),
                ),
              ),
            ),
            
            // Contenu de l'écran
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.lcdBorder,
                      ),
                      child: Text(
                        title!,
                        style: TextStyle(
                          color: AppColors.lcdTextDim,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dessine de fines scanlines horizontales pour un rendu écran cathodique (CRT) réaliste.
class _CncLcdScanlinePainter extends CustomPainter {
  const _CncLcdScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    // Lignes horizontales tous les 3.0 pixels
    for (double y = 0; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CncLcdScanlinePainter oldDelegate) => false;
}

// ───────────────────────────────────────────────────────────────────────────────
/// Ligne DRO dans l'écran LCD style FANUC.
class CncLcdAxisRow extends StatelessWidget {
  final String axis;
  final double value;
  final Color axisColor;
  final bool isRotary;
  final double fontSize;

  const CncLcdAxisRow({
    super.key,
    required this.axis,
    required this.value,
    required this.axisColor,
    this.isRotary = false,
    this.fontSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = isRotary
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(3);
    final unit = isRotary ? '°' : 'mm';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              axis,
              style: TextStyle(
                color: axisColor,
                fontSize: fontSize * 0.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.lcdText,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono',
                shadows: [
                  Shadow(
                    color: AppColors.lcdText.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.lcdTextDim,
              fontSize: 10,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
/// Croix directionelle JOG pour les axes XY — style pupitre.
/// Les boutons utilisent le hold-to-jog.
class CncJogCrossXY extends StatelessWidget {
  final VoidCallback onXPlus;
  final VoidCallback onXMinus;
  final VoidCallback onYPlus;
  final VoidCallback onYMinus;
  final VoidCallback onStop;

  const CncJogCrossXY({
    super.key,
    required this.onXPlus,
    required this.onXMinus,
    required this.onYPlus,
    required this.onYMinus,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dirBtn('Y+', AppColors.axisY, onYPlus),
        SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _dirBtn('X−', AppColors.axisX, onXMinus),
            SizedBox(width: 5),
            _CncRoundStopButton(onTap: onStop),
            SizedBox(width: 5),
            _dirBtn('X+', AppColors.axisX, onXPlus),
          ],
        ),
        SizedBox(height: 5),
        _dirBtn('Y−', AppColors.axisY, onYMinus),
      ],
    );
  }

  Widget _dirBtn(String label, Color color, VoidCallback onHold) {
    return _HoldButton(label: label, color: color, onHoldStart: onHold, onHoldEnd: () {});
  }
}

/// Bouton d'arrêt JOG rond et mécanique.
class _CncRoundStopButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CncRoundStopButton({required this.onTap});

  @override
  State<_CncRoundStopButton> createState() => _CncRoundStopButtonState();
}

class _CncRoundStopButtonState extends State<_CncRoundStopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 44,
        height: 44,
        transform: _pressed
            ? Matrix4.translationValues(0, 2.0, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed
                ? [AppColors.keyActive, AppColors.surface]
                : [AppColors.surfaceBright, AppColors.keyBezel],
          ),
          border: Border.all(
            color: _pressed ? AppColors.ledRed.withValues(alpha: 0.6) : AppColors.keyBorder,
            width: 1.5,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    offset: const Offset(0, 3.5),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    offset: const Offset(0, -1),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            Icons.stop_rounded,
            color: AppColors.ledRed,
            size: 20,
            shadows: [
              Shadow(color: AppColors.ledRed, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton directionnel à maintien — émet onHoldStart en continu tant que pressé.
class _HoldButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _HoldButton({
    required this.label,
    required this.color,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _pressed = false;
  Timer? _timer;

  void _startHold() {
    if (_pressed) return;
    setState(() => _pressed = true);
    widget.onHoldStart();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (_pressed) widget.onHoldStart();
    });
  }

  void _endHold() {
    _timer?.cancel();
    _timer = null;
    if (_pressed) {
      setState(() => _pressed = false);
      widget.onHoldEnd();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.surfaceBright,
        AppColors.keyBezel,
      ],
    );

    final pressedGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.keyActive,
        AppColors.surface,
      ],
    );

    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _endHold(),
      onTapCancel: _endHold,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 52,
        height: 40,
        transform: _pressed
            ? Matrix4.translationValues(0, 2.5, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: _pressed ? pressedGradient : normalGradient,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _pressed
                ? widget.color.withValues(alpha: 0.6)
                : AppColors.keyBorder,
            width: 1.5,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    offset: const Offset(0, 3.5),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    offset: const Offset(0, -1),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: _pressed ? widget.color : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ),
      ),
    );
  }
}

/// Volant rotatif interactif (Jog Dial / MPG virtuel) pour les axes rotatifs.
class CncJogDial extends StatefulWidget {
  final String axis;
  final String label;
  final Color color;
  final double currentValue;
  final int multiplier;
  final void Function(double step) onJog;
  final double size;

  const CncJogDial({
    super.key,
    required this.axis,
    required this.label,
    required this.color,
    required this.currentValue,
    required this.multiplier,
    required this.onJog,
    this.size = 110,
  });

  @override
  State<CncJogDial> createState() => _CncJogDialState();
}

class _CncJogDialState extends State<CncJogDial> {
  double _currentRotationAngle = 0.0; // Angle visuel du disque (en radians)
  double _accumulatedAngle = 0.0;    // Rotation accumulée pour les clics

  @override
  Widget build(BuildContext context) {
    final double radius = widget.size / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Étiquette avec la position de l'axe
        Text(
          '${widget.axis} : ${widget.currentValue.toStringAsFixed(1)}°',
          style: TextStyle(
            color: widget.color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            fontFamily: 'JetBrains Mono',
            shadows: [
              Shadow(color: widget.color.withValues(alpha: 0.15), blurRadius: 4),
            ],
          ),
        ),
        SizedBox(height: 2),
        Text(
          widget.label,
          style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),

        // Volant rotatif tactile
        GestureDetector(
          onPanStart: (details) {
            _accumulatedAngle = 0.0;
          },
          onPanUpdate: (details) {
            final pos = details.localPosition;
            final dx = pos.dx - radius;
            final dy = pos.dy - radius;
            
            // Calcul de l'angle du point de contact actuel
            final currentAngle = math.atan2(dy, dx);
            
            // On retrouve le point précédent en soustrayant le delta de déplacement
            final prevX = dx - details.delta.dx;
            final prevY = dy - details.delta.dy;
            final prevAngle = math.atan2(prevY, prevX);

            double delta = currentAngle - prevAngle;
            
            // Ajustement pour éviter le saut lors de la transition -PI/PI
            if (delta > math.pi) delta -= 2 * math.pi;
            if (delta < -math.pi) delta += 2 * math.pi;

            if (delta.isNaN || delta.isInfinite) return;

            setState(() {
              _currentRotationAngle += delta;
              _accumulatedAngle += delta;
            });

            // Seuil angulaire pour un clic de molette (15 degrés = 0.2618 radians)
            const double clickThreshold = 0.261799387799;

            if (_accumulatedAngle.abs() >= clickThreshold) {
              final clicks = (_accumulatedAngle / clickThreshold).truncate();
              _accumulatedAngle -= clicks * clickThreshold;
              _triggerJog(clicks);
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Cercle extérieur de fond avec graduations
              Container(
                width: widget.size + 14,
                height: widget.size + 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.panelBody,
                  border: Border.all(color: AppColors.keyBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _DialTicksPainter(color: AppColors.keyBorder),
                ),
              ),

              // 2. Disque rotatif principal (effet métallique)
              Transform.rotate(
                angle: _currentRotationAngle,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        AppColors.surfaceBright,
                        AppColors.keyBezel,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 3,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Texture radiale métallique brossée subtile
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            center: Alignment.center,
                            colors: [
                              Colors.white.withValues(alpha: 0.03),
                              Colors.black.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.03),
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                      
                      // Repère d'indexation LED lumineuse en périphérie du volant
                      Positioned(
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.color,
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.8),
                                blurRadius: 6,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Renfoncement au centre du volant pour le pouce (effet ergonomique)
                      Container(
                        width: widget.size * 0.45,
                        height: widget.size * 0.45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.3),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 2,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _triggerJog(int clicks) {
    // Échelle des pas : x1 -> 0.1°, x10 -> 1.0°, x100 -> 10.0°
    final double stepVal = widget.multiplier / 10.0;
    double simulatedValue = widget.currentValue;

    for (int i = 0; i < clicks.abs(); i++) {
      final direction = clicks > 0 ? 1.0 : -1.0;
      final increment = direction * stepVal;

      if (widget.axis == 'A') {
        final nextVal = simulatedValue + increment;
        // Limites strictes [-90°, +90°]
        if (nextVal > 90.0 || nextVal < -90.0) {
          HapticFeedback.vibrate(); // Alerte tactile
          break;
        }
        simulatedValue = nextVal;
      } else if (widget.axis == 'C') {
        // Limites [0°, 360°] : boucle infinie sur un tour complet
        double nextVal = simulatedValue + increment;
        if (nextVal >= 360.0) nextVal -= 360.0;
        if (nextVal < 0.0) nextVal += 360.0;
        simulatedValue = nextVal;
      }

      // Envoi du jog relatif
      widget.onJog(increment);
      HapticFeedback.lightImpact();
    }
  }
}

/// Peintre pour dessiner des gradations de type vernier autour du bouton rotatif.
class _DialTicksPainter extends CustomPainter {
  final Color color;

  const _DialTicksPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 2;
    const int tickCount = 24;

    for (int i = 0; i < tickCount; i++) {
      final angle = (i * 360 / tickCount) * math.pi / 180;
      // Les graduations cardinales (toutes les 4) sont plus longues
      final isMajor = i % 4 == 0;
      final tickLength = isMajor ? 5.0 : 3.0;

      final startX = center.dx + (outerRadius - tickLength) * math.cos(angle);
      final startY = center.dy + (outerRadius - tickLength) * math.sin(angle);
      final endX = center.dx + outerRadius * math.cos(angle);
      final endY = center.dy + outerRadius * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialTicksPainter oldDelegate) => false;
}

/// Conteneur de section style pupitre métallique vissé, avec vis Allen de fixation simulées aux 4 coins.
class CncPanelSectionContainer extends StatelessWidget {
  final Widget child;
  final String title;
  final Widget? trailing;

  const CncPanelSectionContainer({
    super.key,
    required this.child,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelSection,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.keyBorder, width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.panelSection,
            AppColors.panelSection.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 4 Vis Allen simulées dans les angles du panneau à membrane
          Positioned(top: 4, left: 4, child: _buildAllenScrew()),
          Positioned(top: 4, right: 4, child: _buildAllenScrew()),
          Positioned(bottom: 4, left: 4, child: _buildAllenScrew()),
          Positioned(bottom: 4, right: 4, child: _buildAllenScrew()),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CncSectionLabel(title),
                    if (trailing != null) ...[
                      const Spacer(),
                      trailing!,
                    ],
                  ],
                ),
                SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllenScrew() {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF6B7280), // Couleur métal gris
        border: Border.all(color: Colors.black.withValues(alpha: 0.6), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            offset: const Offset(-0.6, -0.6),
            blurRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 2.2,
          height: 2.2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.75), // Tête hexagonale noire
          ),
        ),
      ),
    );
  }
}
