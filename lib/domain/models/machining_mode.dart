/// Modes d'usinage conformes au dimensionnement PFE §3.4
///
/// Le logiciel Forgeron distingue deux régimes de fonctionnement :
/// - **5 axes simultanés** : interpolation A/C active, efforts bridés par le
///   ForceGuard embarqué (R_max = 45,6 N).
/// - **3 axes** : A et C verrouillés par logiciel, efforts nominaux R = 180 N.
library;

enum MachiningMode {
  /// 5 axes simultanés — R_5ax = 30 N nominal, R_max = 45,6 N (bridage auto)
  /// RTCP actif, axes A et C en interpolation continue.
  fiveAxis,

  /// 3 axes (X, Y, Z) — A et C verrouillés par logiciel — R_3ax = 180 N
  /// Mode standard, pas de compensation RTCP nécessaire.
  threeAxis,
}

extension MachiningModeExtension on MachiningMode {
  String get label => switch (this) {
        MachiningMode.fiveAxis => '5 Axes Simultanés',
        MachiningMode.threeAxis => '3 Axes (A/C Verrouillés)',
      };

  String get shortLabel => switch (this) {
        MachiningMode.fiveAxis => '5AX',
        MachiningMode.threeAxis => '3AX',
      };

  /// Force de coupe nominale (N) — régime normal.
  double get nominalForce => switch (this) {
        MachiningMode.fiveAxis => 30.0, // R_5ax
        MachiningMode.threeAxis => 180.0, // R_3ax
      };

  /// Force résultante maximale autorisée (N).
  /// En mode 5 axes le ForceGuard embarqué bride à R_max = 45,6 N.
  /// En mode 3 axes, pas de bridage logiciel (les limites mécaniques s'appliquent).
  double get maxResultantForce => switch (this) {
        MachiningMode.fiveAxis => 45.6, // R_max bridé par Forgeron
        MachiningMode.threeAxis => 180.0, // R_3ax
      };

  /// Profondeur de passe max recommandée (mm) — aluminium AW-2017A.
  double get maxDepthOfCut => switch (this) {
        MachiningMode.fiveAxis => 0.3,
        MachiningMode.threeAxis => 2.0,
      };

  /// Largeur d'engagement radial max (mm) — aluminium AW-2017A.
  double get maxWidthOfCut => switch (this) {
        MachiningMode.fiveAxis => 1.0,
        MachiningMode.threeAxis => 6.0,
      };

  /// Vitesse d'avance max autorisée (mm/min).
  double get maxFeedrate => switch (this) {
        MachiningMode.fiveAxis => 500.0,
        MachiningMode.threeAxis => 2000.0,
      };

  /// Les axes rotatifs A/C sont-ils actifs dans ce mode ?
  bool get rotaryAxesActive => this == MachiningMode.fiveAxis;
}
