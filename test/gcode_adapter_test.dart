import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_adapter.dart';

void main() {
  group('GcodeAdapter — nettoyage SolidWorks/Fanuc → FluidNC', () {
    test('supprime les marqueurs % et les numéros de programme O', () {
      final r = GcodeAdapter.adaptForFluidNC('%\nO1234\nG21 G90\n%');
      expect(r.gcode, 'G21 G90');
      expect(r.warnings.any((w) => w.contains('programme')), true);
    });

    test('retire les numéros de séquence N en tête de ligne', () {
      final r = GcodeAdapter.adaptForFluidNC('N10 G0 X5\nN20 G1 X10 F100');
      expect(r.gcode, 'G0 X5\nG1 X10 F100');
    });

    test('retire la compensation de longueur (G43 H1) et garde le mouvement Z',
        () {
      final r = GcodeAdapter.adaptForFluidNC('G43 H1 Z5');
      expect(r.gcode, 'Z5');
      expect(r.warnings.any((w) => w.contains('longueur')), true);
    });

    test('ne touche PAS à G43.1 dynamique (supporté par FluidNC)', () {
      final r = GcodeAdapter.adaptForFluidNC('G43.1 Z10');
      expect(r.gcode, 'G43.1 Z10');
      expect(r.blocking, false);
    });

    test('convertit le changement d\'outil M6 en pause M0', () {
      final r = GcodeAdapter.adaptForFluidNC('M6 T2');
      expect(r.gcode.startsWith('M0'), true);
      expect(r.gcode.contains('T2'), true);
    });

    test('développe le cycle de pointage G82 (avec tempo P ms → s)', () {
      final r = GcodeAdapter.adaptForFluidNC(
          'G0 X10 Y10\nZ25\nG98 G82 Z-3 P1000 R2 F100\nG80 Z25');
      expect(r.blocking, false);
      expect(r.gcode.contains('G0 Z2.000'), true, reason: 'plan R');
      expect(r.gcode.contains('G1 Z-3.000 F100.000'), true, reason: 'perçage');
      expect(r.gcode.contains('G4 P1.000'), true, reason: 'tempo 1000ms → 1s');
      expect(r.gcode.contains('G0 Z25.000'), true, reason: 'retour initial (G98)');
      expect(r.warnings.any((w) => w.contains('développé')), true);
    });

    test('développe le cycle de débourrage G83 (peck) jusqu\'à la profondeur',
        () {
      final r = GcodeAdapter.adaptForFluidNC(
          'G0 X5 Y5\nZ10\nG98 G83 Z-6 Q3 R2 F100\nG80 Z10');
      expect(r.blocking, false);
      expect(r.gcode.contains('G1 Z-6.000 F100.000'), true,
          reason: 'profondeur finale atteinte');
      expect(r.gcode.contains('G0 Z2.000'), true,
          reason: 'retraits au plan R entre les pecks');
      expect(r.gcode.contains('G0 Z10.000'), true, reason: 'retour initial');
    });

    test('bloque la compensation de rayon côté machine (G41/G42)', () {
      final r = GcodeAdapter.adaptForFluidNC('G1 G41 D21 X10 Y10 F100');
      expect(r.blocking, true);
      expect(r.warnings.any((w) => w.contains('rayon')), true);
    });

    test('bloque le RTCP (G43.4)', () {
      final r = GcodeAdapter.adaptForFluidNC('G43.4');
      expect(r.blocking, true);
      expect(r.warnings.any((w) => w.contains('RTCP')), true);
    });

    test('retire les retours à la référence machine (G28/G30)', () {
      final r = GcodeAdapter.adaptForFluidNC('G91 G28 Z0\nG0 X10\nG28 X0 Y0');
      expect(r.gcode.contains('G28'), false, reason: 'G28 retiré (crash switch)');
      expect(r.gcode.contains('G0 X10'), true,
          reason: 'les vrais mouvements restent');
      expect(r.warnings.any((w) => w.contains('référence machine')), true);
    });

    test('ne retire PAS G28.1 (définition de référence, ≠ retour)', () {
      final r = GcodeAdapter.adaptForFluidNC('G28.1 Z0');
      expect(r.gcode.contains('G28.1'), true);
    });

    test('avertit sur les pouces (G20) sans bloquer', () {
      final r = GcodeAdapter.adaptForFluidNC('G20\nG0 X1');
      expect(r.blocking, false);
      expect(r.warnings.any((w) => w.contains('POUCES')), true);
    });

    test('préserve les axes rotatifs A et C (5 axes)', () {
      final r = GcodeAdapter.adaptForFluidNC('G1 X10 Y20 Z-3 A45 C90 F500');
      expect(r.gcode, 'G1 X10 Y20 Z-3 A45 C90 F500');
      expect(r.blocking, false);
    });

    test('bloque la transformation d\'orientation Siemens (TRAORI)', () {
      final r = GcodeAdapter.adaptForFluidNC(
          'TRAORI(1)\nG1 X11.5 Y-24.3 Z-10.8 A3.5 C46. F1800\nTRAFOOF');
      expect(r.blocking, true,
          reason: 'programme en repère pièce → FluidNC ne peut pas le RTCP');
      expect(r.warnings.any((w) => w.contains('REPÈRE PIÈCE')), true);
    });

    test('bloque le TCPM Heidenhain (M128 / FUNCTION TCPM)', () {
      final r1 = GcodeAdapter.adaptForFluidNC('M128\nG1 X10 Y5 Z-2 A10 C30');
      expect(r1.blocking, true);
      final r2 =
          GcodeAdapter.adaptForFluidNC('FUNCTION TCPM F TCP AXIS POS PATHCTRL');
      expect(r2.blocking, true);
      expect(r2.warnings.any((w) => w.contains('orientation')), true);
    });

    test('ne confond pas M128 avec un autre M-code (M12/M1280)', () {
      // M1280 ne doit PAS déclencher le blocage TCPM (frontière de mot).
      final r = GcodeAdapter.adaptForFluidNC('M1280\nG1 X5');
      expect(r.blocking, false);
    });

    test('parcours 5 axes continu (A+C simultanés, C enroulé >360°) passe propre',
        () {
      final r = GcodeAdapter.adaptForFluidNC(
          'G90 G94\n'
          'G1 X-40. Y-5. Z0. A-10. C0. F800.\n'
          'G1 X-35. Y-4.8 Z0.1 A-10.2 C2.\n'
          'G1 X35. Y7.5 Z10.2 A-53. C360.\n'
          'G1 X40. Y6. Z11.8 A-60. C410.');
      expect(r.blocking, false, reason: 'coords machine, aucune transfo active');
      // A et C simultanés préservés, y compris l'enroulement C au-delà de 360°.
      expect(r.gcode.contains('A-60. C410.'), true);
      expect(r.gcode.contains('F800.'), true, reason: 'avance préservée');
    });

    test('préserve les commentaires ;', () {
      final r = GcodeAdapter.adaptForFluidNC('G0 X10 ; approche');
      expect(r.gcode.contains('; approche'), true);
    });

    test('un G-code déjà propre passe sans avertissement ni blocage', () {
      final r = GcodeAdapter.adaptForFluidNC(
          'G21\nG90\nG54\nG0 X10 Y10\nG1 Z-2 F100\nM5');
      expect(r.blocking, false);
      expect(r.warnings, isEmpty);
    });
  });
}
