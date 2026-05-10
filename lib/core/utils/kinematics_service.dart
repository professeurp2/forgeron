import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Service Cinématique Industriel pour configuration Table-Table (Trunnion A/C).
/// Supporte le Remote Tool Center Point (RTCP) et la détection de singularités.
class KinematicsService {
  final double pivotToTableOffset; // Distance Z entre le centre de rotation A et le plateau
  final double toolLength;        // Longueur totale de l'outil (offset H)

  KinematicsService({
    this.pivotToTableOffset = 45.0,
    this.toolLength = 0.0,
  });

  /// --- CINÉMATIQUE DIRECTE (Forward Kinematics) ---
  /// Calcule la position de la pointe de l'outil dans le repère pièce (Work)
  /// à partir des coordonnées machine (X, Y, Z, A, C).
  Vector3 forward(Vector3 mPos, double angleA, double angleC) {
    final aRad = angleA * math.pi / 180;
    final cRad = angleC * math.pi / 180;

    // 1. Position relative au pivot de l'axe A
    // On considère que machine Z=0 est le niveau du pivot.
    // La pointe de l'outil est à Z_machine - toolLength.
    double zRel = mPos.z - toolLength;

    // 2. Inversion des rotations de la table
    // La table tourne de C puis A. Pour trouver le point dans le repère pièce,
    // on applique les rotations inverses dans l'ordre inverse.
    final rotC = Matrix4.identity()..rotateZ(-cRad);
    final rotA = Matrix4.identity()..rotateX(-aRad);

    // Position par rapport au centre de la table (Translation de l'offset pivot)
    final posInCradle = Vector3(mPos.x, mPos.y, zRel + pivotToTableOffset);
    
    // Application des rotations inverses
    final posAfterA = rotA.transform3(posInCradle);
    final posInWork = rotC.transform3(posAfterA);

    return posInWork;
  }

  /// --- CINÉMATIQUE INVERSE (Inverse Kinematics / RTCP) ---
  /// Calcule les coordonnées machine (Xm, Ym, Zm) pour atteindre 
  /// une position pièce cible (Xw, Yw, Zw) avec des angles A et C donnés.
  Vector3 inverseRTCP(Vector3 wPos, double angleA, double angleC) {
    final aRad = angleA * math.pi / 180;
    final cRad = angleC * math.pi / 180;

    // 1. Rotation de la position pièce par le plateau (C) puis le berceau (A)
    final rotMat = Matrix4.identity()
      ..rotateX(aRad)
      ..rotateZ(cRad);

    final rotatedWorkPos = rotMat.transform3(wPos);

    // 2. Transformation vers le repère machine
    // On doit compenser l'offset du pivot et la longueur de l'outil.
    final machineX = rotatedWorkPos.x;
    final machineY = rotatedWorkPos.y;
    // Z_m = Z_rotated - offset_pivot + tool_length
    final machineZ = rotatedWorkPos.z - pivotToTableOffset + toolLength;

    return Vector3(machineX, machineY, machineZ);
  }

  /// --- DÉTECTION DE SINGULARITÉ ---
  /// Calcule le risque de singularité (Gimbal Lock).
  /// Dans une config Trunnion, la singularité se produit à A = 0.
  /// Risque = 1.0 (Critique) si A ≈ 0, 0.0 si A est éloigné.
  double calculateSingularityRisk(double angleA) {
    // On définit une zone de danger de ±5 degrés
    const double dangerZone = 5.0;
    final absA = angleA.abs();
    
    if (absA >= dangerZone) return 0.0;
    
    // Courbe de risque exponentielle pour alerter avant le blocage
    return math.pow(1.0 - (absA / dangerZone), 2).toDouble();
  }

  /// Calcule le vecteur normal à la surface de la pièce en coordonnées machine
  Vector3 getSurfaceNormal(double angleA, double angleC) {
    final aRad = angleA * math.pi / 180;
    final cRad = angleC * math.pi / 180;
    
    final rotMat = Matrix4.identity()
      ..rotateX(aRad)
      ..rotateZ(cRad);
      
    return rotMat.transform3(Vector3(0, 0, 1));
  }
}
