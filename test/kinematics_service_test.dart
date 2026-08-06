import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/kinematics_service.dart';
import 'package:vector_math/vector_math_64.dart';

void expectVec(Vector3 a, Vector3 b, {double tol = 1e-9, String? reason}) {
  expect(a.x, closeTo(b.x, tol), reason: reason);
  expect(a.y, closeTo(b.y, tol), reason: reason);
  expect(a.z, closeTo(b.z, tol), reason: reason);
}

void main() {
  group('KinematicsService — table-table A/C', () {
    test('A=0 C=0 : la pointe descend juste de (Loutil + d)', () {
      final k = KinematicsService(pivotToTableOffset: 8, toolLength: 0);
      // tip_work = (x, y, z - L - d)
      expectVec(k.forward(Vector3(10, 20, 5), 0, 0), Vector3(10, 20, 5 - 8));
    });

    test('longueur d\'outil : décalage supplémentaire en Z à A=C=0', () {
      final k = KinematicsService(pivotToTableOffset: 8, toolLength: 18);
      expectVec(k.forward(Vector3(10, 20, 40), 0, 0), Vector3(10, 20, 40 - 18 - 8));
    });

    test('C=90° tourne la position autour de Z (main droite)', () {
      final k = KinematicsService(pivotToTableOffset: 0, toolLength: 0);
      // Rz(-90)·(10,0,0) = (0,-10,0)
      expectVec(k.forward(Vector3(10, 0, 0), 0, 90), Vector3(0, -10, 0), tol: 1e-9);
    });

    test('round-trip inverse↔direct sur une grille d\'angles (pivot=0)', () {
      final k = KinematicsService(pivotToTableOffset: 8, toolLength: 18);
      final pts = [
        Vector3(0, 0, 0),
        Vector3(12.5, -7.3, 4.2),
        Vector3(-30, 15, -2.5),
      ];
      for (final a in [-90.0, -47.0, -10.0, 0.0, 25.0, 60.0, 90.0]) {
        for (final c in [0.0, 46.5, 90.0, 185.0, 360.0, 410.0]) {
          for (final p in pts) {
            final machine = k.inverseRTCP(p, a, c);
            final back = k.forward(machine, a, c);
            expectVec(back, p, tol: 1e-6, reason: 'A=$a C=$c p=$p');
          }
        }
      }
    });

    test('round-trip avec un pivot machine non nul', () {
      final k = KinematicsService(
          pivotToTableOffset: 8, toolLength: 18, pivot: Vector3(80, 100, 300));
      final p = Vector3(5, -12, 3);
      for (final a in [-60.0, 0.0, 33.0]) {
        for (final c in [15.0, 270.0]) {
          final back = k.forward(k.inverseRTCP(p, a, c), a, c);
          expectVec(back, p, tol: 1e-6, reason: 'A=$a C=$c');
        }
      }
    });

    test('singularité : 1.0 à A=0, 0.0 hors zone, décroissante', () {
      final k = KinematicsService();
      expect(k.calculateSingularityRisk(0), closeTo(1.0, 1e-9));
      expect(k.calculateSingularityRisk(5), 0.0);
      expect(k.calculateSingularityRisk(90), 0.0);
      // symétrique et décroissant
      expect(k.calculateSingularityRisk(-2), closeTo(k.calculateSingularityRisk(2), 1e-9));
      expect(k.calculateSingularityRisk(1) > k.calculateSingularityRisk(3), true);
    });

    test('normale de surface : (0,0,1) à plat, bascule à A=90°', () {
      final k = KinematicsService();
      expectVec(k.getSurfaceNormal(0, 0), Vector3(0, 0, 1), tol: 1e-9);
      // A=90° autour de X : (0,0,1) → (0,-1,0)
      expectVec(k.getSurfaceNormal(90, 0), Vector3(0, -1, 0), tol: 1e-9);
    });
  });
}
