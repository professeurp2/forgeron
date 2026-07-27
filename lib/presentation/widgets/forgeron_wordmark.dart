import 'package:flutter/material.dart';
import '../../core/theme/forgeron_colors.dart';

/// Wordmark animé "FORGERON" — un reflet de métal en fusion balaie le texte
/// toutes les quelques secondes, comme une pièce qui sort de la forge.
///
/// Remplace les `Text('FORGERON', ...)` statiques de la barre d'en-tête pour
/// donner à la marque un moment de signature visuelle cohérent sur tous les
/// écrans (desktop, mobile).
class ForgeronWordmark extends StatefulWidget {
  final double fontSize;

  const ForgeronWordmark({super.key, this.fontSize = 22});

  @override
  State<ForgeronWordmark> createState() => _ForgeronWordmarkState();
}

class _ForgeronWordmarkState extends State<ForgeronWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.fc.primary;
    final hot = context.fc.primaryLight;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, base, hot, base, base],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              tileMode: TileMode.clamp,
              transform: _SlidingGradientTransform(_ctrl.value),
            ).createShader(bounds);
          },
          child: Text(
            'FORGERON',
            style: TextStyle(
              color: base,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 2.0,
            ),
          ),
        );
      },
    );
  }
}

/// Translate le dégradé de -1.5x à +1.5x la largeur du texte : le reflet
/// entre par la gauche, traverse le mot, puis ressort par la droite avant
/// de revenir (le `tileMode: clamp` laisse la couleur de base en dehors).
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.progress);
  final double progress;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = (progress * 3.0 - 1.5) * bounds.width;
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// Logo avec une lueur d'ambre douce et respirante — rappelle la lueur d'une
/// pièce de métal qui vient d'être forgée.
class ForgeronLogoGlow extends StatefulWidget {
  final double height;

  const ForgeronLogoGlow({super.key, this.height = 32});

  @override
  State<ForgeronLogoGlow> createState() => _ForgeronLogoGlowState();
}

class _ForgeronLogoGlowState extends State<ForgeronLogoGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = context.fc.primary;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = _glow.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.18 + 0.14 * t),
                blurRadius: 10 + 8 * t,
                spreadRadius: 1 + 1.5 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Image.asset('assets/logo.png', height: widget.height),
    );
  }
}
