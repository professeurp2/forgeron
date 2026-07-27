import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_parser.dart';

void main() {
  group('GCodeParser — modes G91/G20', () {
    test('G91 accumule les déplacements relatifs au lieu de les remplacer', () async {
      const program = 'G91 G21\nG1 X10\nG1 X10\nG1 X-5\n';
      final analyzed = await GCodeParser.parseLargeFile(program);

      // Chaque ligne "G1 X..." doit s'ajouter à la précédente : 10, 20, 15
      final xs = analyzed.toolpath.map((p) => p[0]).toList();
      expect(xs, [10.0, 20.0, 15.0]);
    });

    test('G90 traite chaque coordonnée comme absolue (comportement historique)', () async {
      const program = 'G90 G21\nG1 X10\nG1 X10\nG1 X5\n';
      final analyzed = await GCodeParser.parseLargeFile(program);

      final xs = analyzed.toolpath.map((p) => p[0]).toList();
      expect(xs, [10.0, 10.0, 5.0]);
    });

    test('G20 convertit les axes linéaires de pouces en mm', () async {
      const program = 'G90 G20\nG1 X1 Y2 Z-1\n';
      final analyzed = await GCodeParser.parseLargeFile(program);

      final pos = analyzed.toolpath.first;
      expect(pos[0], closeTo(25.4, 1e-9));
      expect(pos[1], closeTo(50.8, 1e-9));
      expect(pos[2], closeTo(-25.4, 1e-9));
    });

    test('G20 ne convertit pas les axes rotatifs A/C (toujours en degrés)', () async {
      const program = 'G90 G20\nG1 A10 C20\n';
      final analyzed = await GCodeParser.parseLargeFile(program);

      final pos = analyzed.toolpath.first;
      expect(pos[3], 10.0); // A
      expect(pos[4], 20.0); // C
    });

    test('G91 + G20 combinés : delta en pouces accumulé puis converti en mm', () async {
      const program = 'G91 G20\nG1 X1\nG1 X1\n';
      final analyzed = await GCodeParser.parseLargeFile(program);

      final xs = analyzed.toolpath.map((p) => p[0]).toList();
      expect(xs[0], closeTo(25.4, 1e-9));
      expect(xs[1], closeTo(50.8, 1e-9));
    });

    test('Un axe absent de la ligne ne modifie pas la position courante', () async {
      const program = 'G91 G21\nG1 X10\nG1 Y5\n';
      final analyzed = await GCodeParser.parseLargeFile(program);

      final last = analyzed.toolpath.last;
      expect(last[0], 10.0); // X inchangé sur la 2e ligne
      expect(last[1], 5.0);
    });
  });
}
