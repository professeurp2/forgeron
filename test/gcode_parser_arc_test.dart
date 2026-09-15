import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_parser.dart';

double _radius(List<double> p, double cx, double cy) =>
    math.sqrt(math.pow(p[0] - cx, 2) + math.pow(p[1] - cy, 2));

void main() {
  group('GCodeParser — interpolation des arcs', () {
    test('quart de cercle G3 (anti-horaire) suit la courbe, pas la corde', () async {
      // De (10,0) à (0,10), centre (0,0).
      final a = await GCodeParser.parseLargeFile(
          'G17 G21 G90\nG1 X10 Y0\nG3 X0 Y10 I-10 J0');
      // Bien plus que 2 points (l'arc est échantillonné).
      final arcPts = a.toolpath.skip(1).toList(); // après le point de départ
      expect(arcPts.length, greaterThan(5));
      // Tous les points de l'arc sont sur le rayon 10.
      for (final p in arcPts) {
        expect(_radius(p, 0, 0), closeTo(10.0, 1e-6));
      }
      // Le dernier point est bien l'arrivée.
      expect(a.toolpath.last[0], closeTo(0, 1e-6));
      expect(a.toolpath.last[1], closeTo(10, 1e-6));
      // Anti-horaire : un point intermédiaire passe par X>10? Non : il monte en
      // Y en gardant le rayon → milieu ≈ (7.07, 7.07).
      final mid = arcPts[(arcPts.length / 2).floor()];
      expect(mid[0], greaterThan(6));
      expect(mid[1], greaterThan(6));
    });

    test('G2 (horaire) part dans l\'autre sens que G3', () async {
      // De (10,0) à (0,10) : en G2 (horaire) l'arc fait le grand tour par le bas.
      final cw = await GCodeParser.parseLargeFile(
          'G17 G90\nG1 X10 Y0\nG2 X0 Y10 I-10 J0');
      final mid = cw.toolpath[(cw.toolpath.length / 2).floor()];
      // Le milieu du grand arc horaire passe côté négatif.
      expect(mid[0] < 0 || mid[1] < 0, true);
      for (final p in cw.toolpath.skip(1)) {
        expect(_radius(p, 0, 0), closeTo(10.0, 1e-6));
      }
    });

    test('cercle complet (arrivée = départ)', () async {
      final a = await GCodeParser.parseLargeFile(
          'G17 G90\nG1 X10 Y0\nG2 X10 Y0 I-10 J0');
      expect(a.toolpath.length, greaterThan(20));
      // Revient au départ.
      expect(a.toolpath.last[0], closeTo(10, 1e-6));
      expect(a.toolpath.last[1], closeTo(0, 1e-6));
      for (final p in a.toolpath.skip(1)) {
        expect(_radius(p, 0, 0), closeTo(10.0, 1e-6));
      }
    });

    test('hélice : le Z est interpolé le long de l\'arc', () async {
      final a = await GCodeParser.parseLargeFile(
          'G17 G90\nG1 X10 Y0 Z0\nG3 X0 Y10 Z-5 I-10 J0');
      final arcPts = a.toolpath.skip(1).toList();
      // Z croît (en négatif) régulièrement de 0 à -5.
      expect(arcPts.first[2], lessThan(0));
      expect(arcPts.first[2], greaterThan(-5));
      expect(arcPts.last[2], closeTo(-5, 1e-6));
    });

    test('format RAYON (R) équivalent au format centre', () async {
      final a = await GCodeParser.parseLargeFile(
          'G17 G90\nG1 X10 Y0\nG3 X0 Y10 R10');
      for (final p in a.toolpath.skip(1)) {
        expect(_radius(p, 0, 0), closeTo(10.0, 1e-6));
      }
      expect(a.toolpath.last[0], closeTo(0, 1e-6));
      expect(a.toolpath.last[1], closeTo(10, 1e-6));
    });

    test('G17/G21 ne sont PAS pris pour des mouvements (bug de préfixe)',
        () async {
      final a = await GCodeParser.parseLargeFile('G17\nG21\nG90\nG1 X10 Y5');
      // Un seul vrai point de mouvement.
      expect(a.toolpath.length, 1);
      expect(a.toolpath.first[0], closeTo(10, 1e-9));
      expect(a.toolpath.first[1], closeTo(5, 1e-9));
    });

    test('les commentaires (…) ne créent pas de points fantômes', () async {
      final a = await GCodeParser.parseLargeFile(
          '(10MM X 90DEG SPOT DRILL)\nG90\nG1 X5 Y5');
      expect(a.toolpath.length, 1);
      expect(a.toolpath.first[0], closeTo(5, 1e-9));
    });
  });
}
