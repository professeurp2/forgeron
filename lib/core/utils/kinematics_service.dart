import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Service de calcul cinématique pour machine CNC 5-axes (Configuration Trunnion)
/// Gère le RTCP (Remote Tool Center Point) et les transformations de repères.
class KinematicsService {
  // --- Paramètres Machine (Valeurs par défaut issues du PFE) ---
  
  /// Distance entre le pivot de l'axe A et la surface du plateau (en mm)
  final double pivotToTableOffset;
  
  /// Longueur de l'outil (du nez de broche à la pointe)
  final double toolLength;

  KinematicsService({
    this.pivotToTableOffset = 45.0, // Ajustable selon la machine réelle
    this.toolLength = 30.0,
  });

  /// Calcule la position Machine (Xm, Ym, Zm) nécessaire pour atteindre 
  /// une position Pièce (Xw, Yw, Zw) avec des angles A et C donnés.
  /// C'est le cœur de l'algorithme RTCP (G43.4).
  Vector3 calculateMachinePosition(Vector3 workPos, double angleA, double angleC) {
    final aRad = angleA * math.pi / 180;
    final cRad = angleC * math.pi / 180;

    // 1. Rotation de la pièce par l'axe C (Plateau)
    // 2. Rotation par l'axe A (Berceau)
    // 3. Translation par rapport au pivot
    
    // Matrice de rotation combinée C puis A
    final rotMat = Matrix4.identity()
      ..rotateX(aRad)
      ..rotateZ(cRad);

    // Position du point sur la pièce après rotations
    final rotatedPos = rotMat.transform3(workPos);

    // Compensation du pivot : 
    // Le pivot de l'axe A est à Z=0 dans le modèle machine.
    // La table est à -pivotToTableOffset.
    final compensation = Vector3(
      rotatedPos.x,
      rotatedPos.y,
      rotatedPos.z - pivotToTableOffset,
    );

    // En RTCP, la machine doit déplacer X, Y, Z pour que la pointe de l'outil 
    // (fixe en rotation) touche ce point compensé.
    return compensation;
  }

  /// Cinématique Inverse simplifiée pour le visualiseur
  /// Transforme les positions machine en positions relatives à la pièce
  Vector3 calculateWorkPosition(Vector3 machinePos, double angleA, double angleC) {
    final aRad = -angleA * math.pi / 180;
    final cRad = -angleC * math.pi / 180;

    final invRotMat = Matrix4.identity()
      ..rotateZ(cRad)
      ..rotateX(aRad);

    final posRelativeToPivot = Vector3(
      machinePos.x,
      machinePos.y,
      machinePos.z + pivotToTableOffset,
    );

    return invRotMat.transform3(posRelativeToPivot);
  }
}
