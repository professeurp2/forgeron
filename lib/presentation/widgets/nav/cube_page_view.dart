import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Navigation en **cube 3D rotatif** entre les écrans mobiles.
///
/// Chaque page est une face du cube : au changement d'onglet (via
/// [controller].animateToPage) ou au glissement horizontal, le cube pivote
/// autour de son arête partagée avec une perspective réelle. La face qui
/// recule est progressivement assombrie pour vendre la profondeur.
///
/// Sans dépendance externe : la transformation est recalculée à chaque frame
/// par un [AnimatedBuilder] branché sur le [PageController].
class CubePageView extends StatelessWidget {
  /// Contrôleur détenu par l'appelant (permet de piloter la nav depuis la
  /// barre du bas *et* de recevoir les changements de page au swipe).
  final PageController controller;

  /// Les faces du cube, une par destination.
  final List<Widget> children;

  /// Notifié quand la page « repose » sur un nouvel index (tap ou swipe).
  final ValueChanged<int>? onPageChanged;

  const CubePageView({
    super.key,
    required this.controller,
    required this.children,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: children.length,
      // Élan doux, cohérent avec un objet 3D qui a de l'inertie.
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            // Position courante du défilement (fraction de page).
            double page = controller.initialPage.toDouble();
            if (controller.hasClients &&
                controller.position.haveDimensions) {
              page = controller.page ?? page;
            }
            // Décalage signé de cette face par rapport au centre du viewport.
            final delta = (index - page).clamp(-1.0, 1.0);
            return _CubeFace(delta: delta, child: children[index]);
          },
        );
      },
    );
  }
}

/// Applique la rotation de cube + l'assombrissement à une face.
class _CubeFace extends StatelessWidget {
  /// `index - page`, borné à [-1, 1]. 0 = face de devant.
  final double delta;
  final Widget child;

  const _CubeFace({required this.delta, required this.child});

  @override
  Widget build(BuildContext context) {
    // Face de droite (delta > 0) : ancrée sur son arête gauche (partagée).
    // Face de gauche (delta < 0) : ancrée sur son arête droite.
    final alignment =
        delta > 0 ? Alignment.centerLeft : Alignment.centerRight;

    // Rotation jusqu'à ±90° : à |delta|=1 la face est perpendiculaire à
    // l'écran (donc invisible), à delta=0 elle est frontale.
    final rotationY = delta * (math.pi / 2);

    // Voile sombre qui suit l'éloignement de la face.
    final darken = (delta.abs() * 0.55).clamp(0.0, 0.55);

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective
      ..rotateY(rotationY);

    return Transform(
      alignment: alignment,
      transform: transform,
      // ClipRect : chaque face est bornée à SON propre rectangle. Sans lui, le
      // contenu d'une face (ombres, textes, panneaux) débordait sur la face
      // voisine → les chevauchements et coutures diagonales. Avec lui, les deux
      // faces se rejoignent proprement sur l'arête partagée (le coin du carton).
      child: ClipRect(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            if (darken > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: darken),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
