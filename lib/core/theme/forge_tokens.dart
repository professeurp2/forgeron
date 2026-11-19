import 'package:flutter/material.dart';

import 'forgeron_colors.dart';

/// Version de l'application, dite à UN endroit (pied de page, diagnostic,
/// pupitre, export). Elle était écrite en dur à trois endroits, avec trois
/// valeurs différentes.
const kForgeronVersion = '2.0.0';

/// Jetons du design v2 : espacements, rayons, mouvement, typographie.
///
/// La v1 écrivait ses valeurs au fil des écrans (rayons 4, 6, 8, 10, 12 ;
/// corps 8 à 11 ; durées 120 à 350 ms). La v2 les nomme, pour que la coque,
/// les cartes et les nouveaux écrans parlent la même langue visuelle.
abstract final class FSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class FRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double pill = 999;
}

/// Mouvement. Trois durées, une courbe ; et le respect de « réduire les
/// animations » du système — sur une machine, un écran qui bouge moins n'est
/// pas une préférence esthétique.
abstract final class FMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 380);

  /// Décalage entre deux éléments d'une entrée en cascade.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], ou zéro si l'appareil demande moins d'animations.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Échelle typographique. Rajdhani pour l'interface, JetBrains Mono pour les
/// données (cotes, G-code, adresses) — jamais l'inverse.
abstract final class FText {
  static const String ui = 'Rajdhani';
  static const String mono = 'JetBrains Mono';

  /// Surtitre de section : petites capitales espacées.
  static TextStyle overline(ForgeronColorPalette c) => TextStyle(
        fontFamily: ui,
        color: c.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        height: 1.2,
      );

  static TextStyle title(ForgeronColorPalette c) => TextStyle(
        fontFamily: ui,
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.15,
      );

  static TextStyle heading(ForgeronColorPalette c) => TextStyle(
        fontFamily: ui,
        color: c.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.2,
      );

  static TextStyle body(ForgeronColorPalette c) => TextStyle(
        fontFamily: ui,
        color: c.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.35,
      );

  static TextStyle caption(ForgeronColorPalette c) => TextStyle(
        fontFamily: ui,
        color: c.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  /// Donnée : chiffres à chasse fixe, pour que les colonnes ne dansent pas.
  static TextStyle data(ForgeronColorPalette c, {double size = 13, Color? color}) => TextStyle(
        fontFamily: mono,
        color: color ?? c.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.2,
      );
}

/// Ombres : deux niveaux, pas davantage. La v1 posait une ombre de 16 px et
/// un flou d'arrière-plan sur chaque panneau ; sur un téléphone d'atelier,
/// c'est du temps de trame dépensé pour rien.
abstract final class FShadow {
  static List<BoxShadow> card(ForgeronColorPalette c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: c.isDark ? 0.28 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> raised(ForgeronColorPalette c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: c.isDark ? 0.42 : 0.12),
          blurRadius: 24,
          offset: const Offset(0, 10),
          spreadRadius: -8,
        ),
      ];
}

extension ForgeronPaletteX on ForgeronColorPalette {
  bool get isDark => background.computeLuminance() < 0.5;
}
