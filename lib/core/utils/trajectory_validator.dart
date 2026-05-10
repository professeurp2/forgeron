import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'gcode_parser.dart';

/// Résultat de la validation Lookahead
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? errorLine;

  ValidationResult.success() : isValid = true, errorMessage = null, errorLine = null;
  ValidationResult.error(this.errorMessage, this.errorLine) : isValid = false;
}

/// Service de Validation Lookahead (Anticipation de trajectoire).
/// Analyse le toolpath complet avant l'usinage pour prévenir les collisions matérielles.
class TrajectoryValidator {
  // Limites physiques de la machine (à synchroniser avec FluidNC)
  static const double minZ = -5.0; // Interdiction de descendre sous le plateau (incluant offset)
  static const double maxA = 110.0;
  static const double minA = -110.0;
  
  /// Valide l'intégralité d'un programme G-Code analysé
  static ValidationResult validate(AnalyzedGCode analyzed) {
    for (int i = 0; i < analyzed.toolpath.length; i++) {
      final pos = analyzed.toolpath[i]; // [X, Y, Z, A, C]
      
      // 1. Vérification Limite Z (Sécurité Plateau)
      // On vérifie si la coordonnée Z dépasse la limite basse de sécurité
      if (pos[2] < minZ) {
        return ValidationResult.error(
          'Collision détectée avec le plateau (Z=${pos[2].toStringAsFixed(2)} < $minZ)',
          i + 1,
        );
      }

      // 2. Vérification Limite Angulaire Axe A (Tilt)
      if (pos[3] > maxA || pos[3] < minA) {
        return ValidationResult.error(
          'Dépassement de limite angulaire sur l\'axe A (${pos[3].toStringAsFixed(1)}°)',
          i + 1,
        );
      }

      // 3. (Optionnel) Vérification de vitesse excessive en 5-axes
      // Le mouvement combiné peut générer des accélérations violentes près des singularités.
    }

    return ValidationResult.success();
  }

  /// Calcule la Bounding Box réelle de l'usinage
  static Aabb3 calculateBoundingBox(List<List<double>> toolpath) {
    if (toolpath.isEmpty) return Aabb3();
    
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minZ = double.infinity, maxZ = double.negativeInfinity;

    for (var p in toolpath) {
      if (p[0] < minX) minX = p[0]; if (p[0] > maxX) maxX = p[0];
      if (p[1] < minY) minY = p[1]; if (p[1] > maxY) maxY = p[1];
      if (p[2] < minZ) minZ = p[2]; if (p[2] > maxZ) maxZ = p[2];
    }

    return Aabb3.minMax(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
  }
}
