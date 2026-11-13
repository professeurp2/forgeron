import 'package:flutter/material.dart';

/// Un nombre qui GLISSE vers sa nouvelle valeur au lieu de sauter.
///
/// La carte envoie sa position par rapports successifs (toutes les 250 ms en
/// mouvement) : sans interpolation, un afficheur de cotes clignote de
/// valeur en valeur. Ici, chaque nouvelle valeur est atteinte en [duration],
/// ce qui rend le mouvement lisible — et la valeur affichée est toujours
/// celle de la carte à la fin de l'animation, jamais une invention : on
/// n'interpole qu'entre deux mesures réelles.
class AnimatedNumberText extends StatelessWidget {
  const AnimatedNumberText(
    this.value, {
    super.key,
    this.decimals = 3,
    this.suffix = '',
    this.style,
    this.textAlign,
    this.maxLines,
    this.duration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOutCubic,
  });

  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    // Une valeur non finie (jamais reçue, NaN) s'affiche telle quelle : pas de
    // tween vers l'infini.
    if (!value.isFinite) {
      return Text('—$suffix', style: style, textAlign: textAlign, maxLines: maxLines);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(
        '${v.toStringAsFixed(decimals)}$suffix',
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }
}

/// Un texte qui change en fondu-glissé (compteurs, statuts). Sert là où la
/// valeur n'est pas un nombre continu (« IDLE » → « RUN », « 12 » → « 13 »).
class AnimatedSwapText extends StatelessWidget {
  const AnimatedSwapText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.duration = const Duration(milliseconds: 220),
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: textAlign == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Text(text,
          key: ValueKey(text),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis),
    );
  }
}

/// Apparition en fondu + léger glissement, une seule fois, à l'insertion
/// dans l'arbre (lignes de journal, cartes). À poser avec une `key` stable
/// par élément, sinon chaque reconstruction rejoue l'entrée.
class AppearIn extends StatelessWidget {
  const AppearIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.offset = const Offset(0, -6),
  });

  final Widget child;
  final Duration duration;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: offset * (1 - t),
          child: child,
        ),
      ),
    );
  }
}
