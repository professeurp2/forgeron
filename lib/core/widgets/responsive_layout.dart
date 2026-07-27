import 'package:flutter/material.dart';

/// Un utilitaire pour gérer les mises en page réactives en fonction de la taille de l'écran.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  // On classe l'appareil par son CÔTÉ LE PLUS COURT, pas par la largeur : un
  // téléphone en paysage reste un téléphone (côté court ~360 dp) et doit garder
  // la mise en page mobile. Auparavant, la largeur ~800 dp en paysage
  // déclenchait la branche desktop (barre latérale + panneaux) sur ~360 dp de
  // haut — illisible.
  static double _shortest(BuildContext c) =>
      MediaQuery.sizeOf(c).shortestSide;

  static bool isMobile(BuildContext context) => _shortest(context) < 600;

  static bool isTablet(BuildContext context) =>
      _shortest(context) >= 600 && _shortest(context) < 1024;

  static bool isDesktop(BuildContext context) => _shortest(context) >= 1024;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest >= 1024) return desktop;
    if (shortest >= 600) return tablet;
    return mobile;
  }
}
