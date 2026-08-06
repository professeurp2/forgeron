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
///
/// ⚠️ `Pivot` (position machine du pivot) et l'offset WCS sont des données de
/// **calibration de montage** (dépendent du zéro pièce G54), pas de simples
/// constantes machine. Par défaut `Pivot = (0,0,0)` : la reconstruction est
/// alors correcte en FORME (rotations + offset table) à une translation près.
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

  Vector3 get _tableOffset => Vector3(0, 0, pivotToTableOffset);

  /// --- CINÉMATIQUE DIRECTE ---
  /// Position de la pointe d'outil dans le repère PIÈCE à partir des
  /// coordonnées MACHINE (X, Y, Z, A, C).
  ///
  ///   p_pièce = Rz(−C) · ( Rx(−A)·(T − Pivot) − (0,0,d) ),  T = (X, Y, Z−Loutil)
  Vector3 forward(Vector3 mPos, double angleA, double angleC) {
    final aRad = _deg(angleA);
    final cRad = _deg(angleC);

    // Pointe d'outil dans le repère machine.
    final tip = Vector3(mPos.x, mPos.y, mPos.z - toolLength);

    // Relatif au pivot, puis on annule l'inclinaison A (repère berceau).
    final inCradle = _rotX(-aRad).transform3(tip - pivot) - _tableOffset;

    // On annule la rotation plateau C → repère pièce.
    return _rotZ(-cRad).transform3(inCradle);
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

    // NB : Matrix4.transform3 mute son argument sur place → on clone l'entrée
    // pour ne pas corrompre le Vector3 fourni par l'appelant.
    final inCradle = _rotZ(cRad).transform3(wPos.clone()) + _tableOffset;
    final tip = pivot + _rotX(aRad).transform3(inCradle);

    return Vector3(tip.x, tip.y, tip.z + toolLength);
  }

  /// --- DÉTECTION DE SINGULARITÉ ---
  /// En table-table A/C, la singularité (orientation indéterminée du plateau C)
  /// survient quand la table est à plat, soit **A ≈ 0**. Risque 1.0 (critique)
  /// à A = 0, décroît jusqu'à 0 à ±[dangerZone] degrés.
  double calculateSingularityRisk(double angleA, {double dangerZone = 5.0}) {
    final absA = angleA.abs();
    if (absA >= dangerZone) return 0.0;
    return math.pow(1.0 - (absA / dangerZone), 2).toDouble();
  }

  /// Vecteur normal à la surface pièce (axe outil pièce) exprimé dans le repère
  /// machine, pour les angles A/C donnés. À A=0,C=0 → (0,0,1).
  Vector3 getSurfaceNormal(double angleA, double angleC) {
    final rot = _rotX(_deg(angleA))..multiply(_rotZ(_deg(angleC)));
    return rot.transform3(Vector3(0, 0, 1));
  }

  static double _deg(double d) => d * math.pi / 180.0;
  static Matrix4 _rotX(double r) => Matrix4.identity()..rotateX(r);
  static Matrix4 _rotZ(double r) => Matrix4.identity()..rotateZ(r);
}
