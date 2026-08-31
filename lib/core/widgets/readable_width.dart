import 'package:flutter/material.dart';

/// Garde le contenu dans une colonne de largeur lisible, centrée.
///
/// Les écrans de réglages sont des listes : un libellé, une valeur, parfois un
/// chevron. Étirés sur les 1280 dp d'un écran de poste, ils mettent le libellé
/// à un bout de la ligne et le chevron à l'autre — une mise en page de
/// téléphone tirée à la largeur d'un moniteur, illisible et sans hiérarchie.
///
/// Sous [maxWidth], rien ne change : sur mobile, le contenu occupe toute la
/// largeur comme avant.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // topCenter, pas center : une page courte (la calibration, par exemple) se
    // retrouvait centrée verticalement, avec un grand vide au-dessus du titre.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
