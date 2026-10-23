import 'package:freezed_annotation/freezed_annotation.dart';

part 'trunnion_config.freezed.dart';
part 'trunnion_config.g.dart';

/// Configuration mécanique du Trunnion — constantes issues du
/// dimensionnement PFE (Chapitre 3, §3.4).
///
/// Le Trunnion est un système compact à deux axes rotatifs :
///   - Axe A (berceau / tilt) : rotation autour de X, plage ±90°.
///   - Axe C (plateau / rotation) : rotation autour de Z, plage 360°.
///
/// Transmission : courroie crantée GT2 avec rapport de réduction 6:1
/// (poulie menante 20 dents → poulie menée 120 dents) pour chaque axe,
/// entraînée par un moteur NEMA 17.
@freezed
class TrunnionConfig with _$TrunnionConfig {
  const TrunnionConfig._();

  const factory TrunnionConfig({
    // ── Plages angulaires ──────────────────────────────────────────────
    /// Plage de l'axe A (berceau) en degrés. ±90°.
    @Default(90.0) double aAxisMaxAngle,

    /// Plage de l'axe C (plateau) en degrés. 360° continu.
    @Default(360.0) double cAxisMaxAngle,

    // ── Transmission GT2 ───────────────────────────────────────────────
    /// Pas de la courroie GT2 (mm).
    @Default(2.0) double gt2Pitch,

    /// Nombre de dents de la poulie menante (moteur).
    @Default(20) int drivingPulleyTeeth,

    /// Nombre de dents de la poulie menée (arbre).
    @Default(120) int drivenPulleyTeeth,

    // ── Moteurs NEMA 17 ────────────────────────────────────────────────
    /// Pas par tour du moteur (1,8° / pas → 200 pas/tour).
    @Default(200) int motorStepsPerRev,

    /// Niveau de microstepping (1/16).
    @Default(16) int microstepping,

    // ── Efforts de coupe ───────────────────────────────────────────────
    /// Force résultante nominale en mode 5 axes (N).
    @Default(30.0) double r5axForce,

    /// Force résultante maximale autorisée en 5 axes (N).
    /// Le ForceGuard embarqué bride automatiquement à cette valeur.
    @Default(45.6) double rMaxForce,

    /// Force résultante nominale en mode 3 axes (N).
    @Default(180.0) double r3axForce,

    // ── Géométrie ──────────────────────────────────────────────────────
    /// Distance Z entre le centre de rotation A et la surface du plateau (mm).
    /// Mesuré sur la machine réelle (2026-08-05) : 8 mm.
    @Default(8.0) double pivotToTableOffset,

    /// Zone de singularité autour de A = 0° (degrés).
    @Default(5.0) double singularityZone,

    // ── Vitesses max ───────────────────────────────────────────────────
    /// Vitesse de rotation max de l'axe A (°/min).
    @Default(3600.0) double aAxisMaxFeed,

    /// Vitesse de rotation max de l'axe C (°/min).
    @Default(7200.0) double cAxisMaxFeed,

    // ── Courses linéaires (vis T8) ─────────────────────────────────────
    /// Course utile axe X (mm).
    @Default(200.0) double travelX,

    /// Course utile axe Y (mm).
    @Default(300.0) double travelY,

    /// Course utile axe Z (mm).
    @Default(150.0) double travelZ,
  }) = _TrunnionConfig;

  factory TrunnionConfig.fromJson(Map<String, dynamic> json) =>
      _$TrunnionConfigFromJson(json);

  // ── Propriétés calculées ───────────────────────────────────────────

  /// Rapport de réduction de la transmission GT2.
  /// 120 / 20 = 6:1.
  double get reductionRatio => drivenPulleyTeeth / drivingPulleyTeeth;

  /// Pas par degré de l'axe rotatif.
  /// (200 × 16 × 6) / 360 = 53,333 steps/°.
  double get stepsPerDegree =>
      (motorStepsPerRev * microstepping * reductionRatio) / 360.0;

  /// Couple moteur amplifié par le rapport de réduction.
  /// Pour un NEMA 17 de 0,4 N·m : couple arbre = 0,4 × 6 = 2,4 N·m.
  double motorTorqueAmplified(double motorTorqueNm) =>
      motorTorqueNm * reductionRatio;
}
