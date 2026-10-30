import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Un utilitaire pour gérer les mises en page réactives en fonction de la taille de l'écran.
///
/// **La plateforme décide de la famille, la taille décide de la densité.**
///
/// - Téléphone et tablette (Android, iOS, web) : on classe par le CÔTÉ LE PLUS
///   COURT, pas par la largeur. Un téléphone en paysage reste un téléphone
///   (côté court ~360 dp) et doit garder la mise en page mobile ; avec la
///   largeur (~800 dp en paysage), il basculait sur la barre latérale et les
///   panneaux, sur ~360 dp de haut — illisible.
/// - PC (Windows, macOS, Linux) : jamais la mise en page du téléphone. Classé
///   par le côté court, un écran 1536×864 logiques (portable courant à 125 %)
///   n'atteignait jamais la branche desktop, et une fenêtre de moins de 600 de
///   haut affichait toute l'interface mobile élargie (constaté le
///   29 octobre 2026). Sur PC, seule la LARGEUR choisit entre barre latérale
///   repliée (`tablet`) et dépliée (`desktop`).
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

  /// Largeur à partir de laquelle un PC affiche la barre latérale dépliée.
  static const double desktopWideWidth = 1280;

  /// Vrai sur Windows, macOS et Linux (hors navigateur).
  static bool get isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static double _shortest(BuildContext c) =>
      MediaQuery.sizeOf(c).shortestSide;

  static _FormFactor _of(BuildContext context) {
    if (isDesktopPlatform) {
      return MediaQuery.sizeOf(context).width >= desktopWideWidth
          ? _FormFactor.desktop
          : _FormFactor.tablet;
    }
    final shortest = _shortest(context);
    if (shortest >= 1024) return _FormFactor.desktop;
    if (shortest >= 600) return _FormFactor.tablet;
    return _FormFactor.mobile;
  }

  static bool isMobile(BuildContext context) =>
      _of(context) == _FormFactor.mobile;

  static bool isTablet(BuildContext context) =>
      _of(context) == _FormFactor.tablet;

  static bool isDesktop(BuildContext context) =>
      _of(context) == _FormFactor.desktop;

  @override
  Widget build(BuildContext context) {
    switch (_of(context)) {
      case _FormFactor.desktop:
        return desktop;
      case _FormFactor.tablet:
        return tablet;
      case _FormFactor.mobile:
        return mobile;
    }
  }
}

enum _FormFactor { mobile, tablet, desktop }
