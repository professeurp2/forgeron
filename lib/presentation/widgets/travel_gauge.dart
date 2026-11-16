import 'package:flutter/material.dart';
import '../../core/theme/forgeron_colors.dart';

/// Remplissage de fond d'une ligne de DRO, à proportion de la position de
/// l'axe dans sa course machine.
///
/// Le nombre affiché par le DRO est la position PIÈCE — c'est elle qui compte
/// pour usiner. Le remplissage répond à une autre question, « combien me
/// reste-t-il avant la butée ? », à laquelle la coordonnée pièce ne peut pas
/// répondre puisqu'elle dépend de l'origine posée.
///
/// La barre vire à l'orange dans les 5 % de chaque extrémité : approcher une
/// fin de course pendant une passe vaut d'être vu avant d'être entendu.
///
/// [fraction] vaut `null` quand la course n'est pas connue (config absente) —
/// aucune barre n'est alors dessinée, plutôt qu'une proportion inventée. Elle
/// vient de `AxisKinematics.travelFraction`.
///
/// Limite connue : FluidNC ne rapporte pas si la machine a été référencée.
/// Avant un homing, la position machine ne veut rien dire et la jauge non plus.
///
/// À placer dans un [Stack], sous le contenu de la ligne.
class TravelGaugeFill extends StatelessWidget {
  const TravelGaugeFill({
    super.key,
    required this.fraction,
    required this.color,
  });

  final double? fraction;
  final Color color;

  /// En deçà de cette distance relative à une extrémité, la jauge alerte.
  static const edge = 0.05;

  static bool isNearEdge(double? fraction) =>
      fraction != null && (fraction <= edge || fraction >= 1 - edge);

  @override
  Widget build(BuildContext context) {
    final f = fraction;
    if (f == null) return const SizedBox.shrink();

    final alert = isNearEdge(f);
    final barColor = alert ? context.fc.warning : color;

    return Positioned.fill(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            color: barColor.withValues(alpha: alert ? 0.26 : 0.16),
          ),
        ),
      ),
    );
  }
}
