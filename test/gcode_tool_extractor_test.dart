import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_tool_extractor.dart';

/// Les cas sont repris des **vrais** fichiers du projet : la sortie du post
/// SolidWorks CAM (`Carre35x35`) et le programme 5 axes continu
/// (`turbine_blade_5axis.nc`). Un extracteur qui marche sur un format inventé
/// ne prouve rien.
void main() {
  List<String> lines(String s) => s.trim().split('\n');

  group('sortie SolidWorks CAM', () {
    // Format réel : numérotation N, opération et descriptif en commentaires
    // juste avant le changement, vitesse juste après.
    final program = lines('''
O0001
N1 G21
N2 G91 G28 X0 Y0 Z0

N3 ( Fraisage d'ebauche1 )
N4 (6MM CRB 2FL 19 LOC)
N5 T01 M06
N6 S12000 M03
N7 G90 G54 G00 X4.25 Y4.5
N8 G43 Z2.5 H01 M08
N9 G01 Z-2.75 F518.16
''');

    test('trouve l\'outil et son numero', () {
      final tools = GCodeToolExtractor.extract(program);
      expect(tools, hasLength(1));
      expect(tools.first.number, 1, reason: 'T01 -> 1');
    });

    test('lit le descriptif et l\'operation', () {
      final t = GCodeToolExtractor.extract(program).first;
      expect(t.description, '6MM CRB 2FL 19 LOC');
      expect(t.operation, 'Fraisage d\'ebauche1');
    });

    test('decode les caracteristiques', () {
      final t = GCodeToolExtractor.extract(program).first;
      expect(t.diameterMm, 6.0);
      expect(t.flutes, 2);
      expect(t.cuttingLengthMm, 19.0);
      expect(t.material, 'Carbure');
      expect(t.shape, ToolShape.flatEndMill);
    });

    test('associe la vitesse de broche demandee', () {
      final t = GCodeToolExtractor.extract(program).first;
      expect(t.spindleSpeed, 12000);
    });
  });

  group('programme 5 axes (commentaire en en-tete)', () {
    final program = lines('''
%
(TITLE: TURBINE BLADE - 5 AXIS CONTINUOUS FINISHING)
(TOOL: BALL END MILL 6MM)
(MACHINE: TRUNNION A-TILT C-ROTARY)

G90 G94 G17 G49 G40 G80
G21

T1 M6
S12000 M3
G54
''');

    test('reconnait une fraise hemispherique', () {
      final tools = GCodeToolExtractor.extract(program);
      expect(tools, hasLength(1));
      expect(tools.first.shape, ToolShape.ballNose,
          reason: 'BALL END MILL contient MILL : la forme specifique prime');
      expect(tools.first.diameterMm, 6.0);
    });
  });

  group('robustesse', () {
    test('un T dans un commentaire ne cree pas d\'outil', () {
      final tools = GCodeToolExtractor.extract(lines('''
( TERMINER LA PASSE T2 AVANT DE CONTINUER )
G01 X10 Y10
'''));
      expect(tools, isEmpty);
    });

    test('un T sans M6 est ignore', () {
      // Pre-selection d'outil sans changement : rien a afficher.
      final tools = GCodeToolExtractor.extract(lines('''
T5
G01 X10
'''));
      expect(tools, isEmpty);
    });

    test('T et M6 sur deux lignes consecutives', () {
      final tools = GCodeToolExtractor.extract(lines('''
(12MM HSS 4FL)
T3
M6
S8000 M3
'''));
      expect(tools, hasLength(1));
      expect(tools.first.number, 3);
      expect(tools.first.material, 'HSS');
      expect(tools.first.flutes, 4);
    });

    test('un outil rappele plusieurs fois n\'apparait qu\'une fois', () {
      final tools = GCodeToolExtractor.extract(lines('''
(6MM CRB 2FL)
T1 M06
G01 X10
(EBAUCHE 2)
T1 M06
G01 X20
'''));
      expect(tools, hasLength(1));
      expect(tools.first.changeLines, hasLength(2),
          reason: 'les deux appels sont conserves');
      expect(tools.first.description, '6MM CRB 2FL',
          reason: 'le premier descriptif trouve n\'est pas ecrase');
    });

    test('sans commentaire, l\'outil reste nu — rien n\'est invente', () {
      final tools = GCodeToolExtractor.extract(lines('''
G21 G90
T7 M06
S9000 M03
'''));
      expect(tools, hasLength(1));
      final t = tools.first;
      expect(t.number, 7);
      expect(t.isBare, isTrue);
      expect(t.description, isNull);
      expect(t.diameterMm, isNull);
      expect(t.flutes, isNull);
      expect(t.shape, ToolShape.unknown);
      // La vitesse, elle, est bien dans le G-code.
      expect(t.spindleSpeed, 9000);
    });

    test('plusieurs outils, ordre d\'apparition conserve', () {
      final tools = GCodeToolExtractor.extract(lines('''
(FORET CARBURE 3MM)
T4 M06
S10000 M03
G01 Z-5
(6MM CRB 2FL 19 LOC)
T1 M06
S12000 M03
(V-BIT 60 DEG)
T8 M06
S15000 M03
'''));
      expect(tools.map((t) => t.number).toList(), [4, 1, 8]);
      expect(tools[0].shape, ToolShape.drill);
      expect(tools[1].shape, ToolShape.flatEndMill);
      expect(tools[2].shape, ToolShape.vBit);
    });

    test('commentaires en point-virgule', () {
      final tools = GCodeToolExtractor.extract(lines('''
; 10MM CRB 3FL 25 LOC
T2 M6
S11000 M3
'''));
      expect(tools, hasLength(1));
      expect(tools.first.diameterMm, 10.0);
      expect(tools.first.flutes, 3);
      expect(tools.first.cuttingLengthMm, 25.0);
    });

    test('programme vide', () {
      expect(GCodeToolExtractor.extract(const []), isEmpty);
    });
  });
}
