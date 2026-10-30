import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Service cinématique pour une machine **table-table (trunnion A/C)** :
/// le berceau A incline la table (rotation autour de X), le plateau C la fait
/// tourner (rotation autour de Z), tous deux portant la PIÈCE ; l'outil (broche)
/// ne fait que du linéaire X/Y/Z.
///
/// Convention de la chaîne cinématique (identique au graphe de scène du
/// simulateur `web/three_viewer.html` : pièce ⊂ cAxis(Rz C) ⊂ aAxis(Rx A)) :
///
///   pièce → machine :  T(Pivot) · Rx(A) · T(0,0,d) · Rz(C)
///
/// où `Pivot` est le centre de rotation A (repère machine), `d`
/// [pivotToTableOffset] la distance pivot→plateau (le pivot est SOUS la table,
/// donc d > 0), et la pointe d'outil est à `Zm − toolLength`.
class KinematicsService {
  /// Distance Z entre le centre de rotation A et la surface du plateau (mm).
  /// Le pivot est sous la table → valeur positive. Mesuré machine : 8 mm.
  final double pivotToTableOffset;

  /// Longueur d'outil sous la jauge broche (mm). 0 si le Z programmé est déjà
  /// à la pointe (longueur prise via le WCS).
  final double toolLength;

  /// Position du centre de rotation A dans le repère machine (mm).
  /// Constante de calibration ; par défaut (0,0,0).
  final Vector3 pivot;

  KinematicsService({
    this.pivotToTableOffset = 8.0,
    this.toolLength = 0.0,
    Vector3? pivot,
  }) : pivot = pivot ?? Vector3.zero();

  /// --- CINÉMATIQUE DIRECTE ---
  /// Position de la pointe d'outil dans le repère PIÈCE à partir des
  /// coordonnées MACHINE (X, Y, Z, A, C).
  ///
  ///   p_pièce = Rz(−C) · ( Rx(−A)·(T − Pivot) − (0,0,d) ),  T = (X, Y, Z−Loutil)
  ///
  /// Implémentation scalaire directe sans allocation de Matrix4/Vector3
  /// intermédiaires pour éviter la pression GC sur 30 000+ points.
  Vector3 forward(Vector3 mPos, double angleA, double angleC) {
    final aRad = _deg(angleA);
    final cRad = _deg(angleC);
    final cosA = math.cos(aRad);
    final sinA = math.sin(aRad);
    final cosC = math.cos(cRad);
    final sinC = math.sin(cRad);

    final dx = mPos.x - pivot.x;
    final dy = mPos.y - pivot.y;
    final dz = (mPos.z - toolLength) - pivot.z;

    // Rx(-aRad) · (T - Pivot) - (0, 0, pivotToTableOffset)
    final cx = dx;
    final cy = dy * cosA + dz * sinA;
    final cz = -dy * sinA + dz * cosA - pivotToTableOffset;

    // Rz(-cRad) · inCradle
    final px = cx * cosC + cy * sinC;
    final py = -cx * sinC + cy * cosC;

    return Vector3(px, py, cz);
  }

  /// --- CINÉMATIQUE INVERSE (RTCP) ---
  /// Coordonnées MACHINE (Xm, Ym, Zm) pour amener la pointe d'outil sur une
  /// position PIÈCE cible avec les angles A et C donnés. Inverse exact de
  /// [forward].
  ///
  ///   T = Pivot + Rx(A)·( Rz(C)·p_pièce + (0,0,d) ) ;  Zm = T.z + Loutil
  Vector3 inverseRTCP(Vector3 wPos, double angleA, double angleC) {
    final aRad = _deg(angleA);
    final cRad = _deg(angleC);
    final cosA = math.cos(aRad);
    final sinA = math.sin(aRad);
    final cosC = math.cos(cRad);
    final sinC = math.sin(cRad);

    // Rz(cRad) · wPos + (0, 0, pivotToTableOffset)
    final cx = wPos.x * cosC - wPos.y * sinC;
    final cy = wPos.x * sinC + wPos.y * cosC;
    final cz = wPos.z + pivotToTableOffset;

    // Pivot + Rx(aRad) · inCradle + (0, 0, toolLength)
    final tx = pivot.x + cx;
    final ty = pivot.y + (cy * cosA - cz * sinA);
    final tz = pivot.z + (cy * sinA + cz * cosA) + toolLength;

    return Vector3(tx, ty, tz);
  }

  /// --- DÉTECTION DE SINGULARITÉ ---
  /// En table-table A/C, la singularité (orientation indéterminée du plateau C)
  /// survient quand la table est à plat, soit **A ≈ 0**. Risque 1.0 (critique)
  /// à A = 0, décroît jusqu'à 0 à ±[dangerZone] degrés.
  double calculateSingularityRisk(double angleA, {double dangerZone = 5.0}) {
    final absA = angleA.abs();
    if (absA >= dangerZone) return 0.0;
    final ratio = 1.0 - (absA / dangerZone);
    return ratio * ratio;
  }

  /// Vecteur normal à la surface pièce (axe outil pièce) exprimé dans le repère
  /// machine, pour les angles A/C donnés. À A=0,C=0 → (0,0,1).
  Vector3 getSurfaceNormal(double angleA, double angleC) {
    final aRad = _deg(angleA);
    return Vector3(0.0, -math.sin(aRad), math.cos(aRad));
  }

  static double _deg(double d) => d * math.pi / 180.0;
}
