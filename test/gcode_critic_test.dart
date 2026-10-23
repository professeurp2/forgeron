import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_critic.dart';

/// Le critique doit reconnaître les pannes que cette machine a réellement
/// subies. Chaque cas ci-dessous vient d'un incident constaté, pas d'un
/// scénario imaginé.
void main() {
  const critic = GcodeCritic();

  group('GcodeCritic — avance écrasée par la rotation', () {
    test('reconnaît le bloc qui a divisé l\'avance par 45', () {
      // Le parcours écrit à la main : un quart d'arc de 7,85 mm accompagné
      // d'un tour complet de plateau. GRBL répartit F sur √(mm² + deg²), donc
      // l'avance linéaire réelle tombe à 2,6 mm/min au lieu de 120.
      const gcode = '''
G21 G90 G94
G1 F120
G0 X5.000 Y0.000 Z-1.500 A0.000 C0.000
G2 X0.000 Y5.000 I-5.000 J0.000 A0.000 C360.000 F120
''';
      final r = critic.review(gcode);
      final f = r.findings
          .where((f) => f.code == 'avance_ecrasee_par_la_rotation')
          .toList();

      expect(f, isNotEmpty, reason: 'le défaut doit être relevé');
      expect(f.first.severity, CriticSeverity.blocking,
          reason: 'une perte de plus de 90 % doit bloquer');
      expect(r.usable, isFalse);
      // La perte doit être de l'ordre du facteur 45 constaté sur la machine.
      expect(1 / (r.stats['perte_avance_max'] as double), greaterThan(10));
    });

    test('accepte un bloc mixte dont le F est compensé', () {
      // En 5 axes continu, mêler les mots est inévitable. Ce qui compte est
      // que la part linéaire reste significative.
      const gcode = '''
G21 G90 G94
G1 X0.000 Y0.000 Z0.000 A0.000 C0.000 F300
G1 X1.000 Y1.000 Z-0.500 A2.000 C1.500 F320
''';
      final r = critic.review(gcode);
      expect(
        r.findings.where((f) => f.code == 'avance_ecrasee_par_la_rotation'),
        isEmpty,
      );
    });
  });

  group('GcodeCritic — limites machine', () {
    test('bloque un dépassement de course Z', () {
      const gcode = 'G21 G90\nG1 Z-150.000 F100\n';
      final r = critic.review(gcode);
      expect(r.findings.any((f) => f.code == 'course_z_depassee'), isTrue);
      expect(r.usable, isFalse);
    });

    test('bloque un axe A hors de sa plage', () {
      // Le berceau va de -88 à +90 degrés.
      const gcode = 'G21 G90\nG1 X1 A120.000 F100\n';
      final r = critic.review(gcode);
      final f = r.findings.firstWhere((f) => f.code == 'axe_a_hors_course');
      expect(f.severity, CriticSeverity.blocking);
      expect(f.remedy, isNotNull, reason: 'l\'agent doit savoir quoi changer');
    });

    test('signale une avance au-dessus du plafond ForceGuard', () {
      const gcode = 'G21 G90\nG1 X10.000 F2000\n';
      final r = critic.review(gcode);
      expect(
        r.findings.any((f) => f.code == 'avance_au_dessus_du_plafond'),
        isTrue,
        reason: 'le ForceGuard réécrirait ce F pendant le streaming',
      );
    });
  });

  group('GcodeCritic — défauts de génération', () {
    test('bloque un programme sans aucun mouvement', () {
      final r = critic.review('G21 G90 G94\nM3 S1000\nM5\nM30\n');
      expect(r.findings.any((f) => f.code == 'aucun_mouvement'), isTrue);
      expect(r.usable, isFalse);
    });

    test('bloque un G1 émis avant toute définition de F', () {
      const gcode = 'G21 G90\nG1 X10.000 Y5.000\n';
      final r = critic.review(gcode);
      expect(r.findings.any((f) => f.code == 'avance_non_definie'), isTrue);
    });

    test('signale les rotations brutales', () {
      // Un dixième de millimètre d'avance pour 45° de rotation : le plateau
      // ferait une embardée que rien ne justifie.
      const gcode = '''
G21 G90
G1 X0.000 C0.000 F200
G1 X0.100 C45.000 F200
''';
      final r = critic.review(gcode);
      expect(r.findings.any((f) => f.code == 'rotations_brutales'), isTrue);
    });
  });

  group('GcodeCritic — verdict exploitable par l\'agent', () {
    test('un programme sain passe et ne bloque sur rien', () {
      const gcode = '''
(FORGERON - ESSAI)
G21 G90 G94 G17 G40
G54
M5
G0 Z20.000
M3 S1000
G4 P1 (MONTEE EN REGIME)
G0 X10.000 Y0.000
G1 Z-1.000 F100.000
G1 X12.000 Y0.000 F400.000
G1 X12.000 Y8.000
G0 Z20.000
M5
M30
''';
      final r = critic.review(gcode);
      expect(r.usable, isTrue,
          reason: 'défauts relevés : '
              '${r.findings.map((f) => f.code).join(", ")}');
      expect(r.stats['blocs_de_mouvement'], greaterThan(0));
    });

    test('chaque défaut porte un code stable et un remède', () {
      const gcode = 'G21 G90\nG1 Z-150.000 A120.000 F2000\n';
      final r = critic.review(gcode);
      expect(r.findings, isNotEmpty);
      for (final f in r.findings) {
        expect(f.code, isNotEmpty);
        expect(f.message, isNotEmpty);
        // Sans remède, l'agent ne peut que constater l'échec — la boucle
        // « générer, juger, relancer » se casse là.
        expect(f.remedy, isNotNull, reason: 'défaut ${f.code} sans remède');
      }
    });

    test('le verdict est sérialisable pour l\'agent', () {
      final r = critic.review('G21 G90\nG1 X5.000 F300\n');
      final json = r.toJson();
      expect(json['exploitable'], isA<bool>());
      expect(json['defauts'], isA<List>());
      expect(json['statistiques'], isA<Map>());
    });
  });
}
