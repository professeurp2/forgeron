/// Modes d'usinage conformes au dimensionnement PFE §3.4
///
/// Le logiciel Forgeron distingue deux régimes de fonctionnement :
/// - **5 axes simultanés** : interpolation A/C active, efforts bridés par le
///   ForceGuard embarqué (R_max = 45,6 N).
/// - **3 axes** : A et C verrouillés par logiciel, efforts nominaux R = 180 N.
///
/// Deux familles de limites cohabitent ici, et elles ne se comportent pas de
/// la même façon :
///
/// | Limite | Origine | Dépend du mode ? |
/// |---|---|---|
/// | [maxResultantForce], [maxFeedrate] | enveloppe d'effort (PFE §3.4) | oui |
/// | [maxDepthOfCut], [maxWidthOfCut] | **vibration de la structure** | non |
///
/// L'effort admissible change avec le mode parce que le berceau, incliné,
/// travaille moins bien. Le broutage, lui, vient de la raideur du bâti et de
/// la broche : il ne sait pas si A et C bougent.
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

  /// Profondeur de passe max (mm) — aluminium AW-2017A.
  ///
  /// **Plafond VIBRATOIRE, identique dans les deux modes.** Les valeurs
  /// précédentes (0,3 en 5 axes, 2,0 en 3 axes) découlaient de l'enveloppe
  /// d'EFFORT du dimensionnement PFE — 45,6 N et 180 N. Sur la machine
  /// construite, ce n'est pas l'effort qui mord le premier : c'est le
  /// broutage. Bâti léger, broche DC en porte-à-faux, pièce tenue d'un seul
  /// côté sur le plateau — la structure entre en vibration bien avant que la
  /// limite d'effort ne soit approchée.
  ///
  /// La vibration ne fait pas la différence entre 3 et 5 axes : que A et C
  /// bougent ou non ne change rien à la raideur du bâti. Les deux modes
  /// partagent donc le même plafond, et [maxResultantForce] reste, lui,
  /// distinct — c'est une limite d'une autre nature.
  double get maxDepthOfCut => 0.2;

  /// Largeur d'engagement radial max (mm) — aluminium AW-2017A.
  /// Même plafond vibratoire que [maxDepthOfCut], même raison.
  double get maxWidthOfCut => 0.5;

  /// Vitesse d'avance max autorisée (mm/min).
  double get maxFeedrate => switch (this) {
        MachiningMode.fiveAxis => 500.0,
        MachiningMode.threeAxis => 2000.0,
      };

  /// Les axes rotatifs A/C sont-ils actifs dans ce mode ?
  bool get rotaryAxesActive => this == MachiningMode.fiveAxis;
}
