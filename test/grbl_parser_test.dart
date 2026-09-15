import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/data/fluidnc/grbl_parser.dart';

void main() {
  const initialState = MachineState();

  group('GrblParser Tests', () {
    test('Parses FluidNC 5-Axis Status Report', () {
      final msg = '<Idle|MPos:10.0,20.0,30.0,40.0,0.0,50.0|WCO:0.0,0.0,0.0,0.0,0.0,0.0|FS:1200,10000|Pn:P>';
      final state = GrblParser.parse(msg, initialState);

      expect(state, isNotNull);
      expect(state!.status, MachineStatus.idle);
      // X=10, Y=20, Z=30, A=40, C=50 (index 5)
      expect(state.mPos, [10.0, 20.0, 30.0, 40.0, 50.0]);
      expect(state.feedrate, 1200.0);
      expect(state.spindleSpeed, 10000.0);
      expect(state.probeTriggered, true);
    });

    test('Parses MSG format', () {
      final msg = '[MSG:Reset to continue]';
      final state = GrblParser.parse(msg, initialState);

      expect(state, isNotNull);
      expect(state!.lastMessage, 'Reset to continue');
    });

    test('Parses ALARM format', () {
      final msg = 'ALARM:1';
      final state = GrblParser.parse(msg, initialState);

      expect(state, isNotNull);
      expect(state!.status, MachineStatus.alarm);
      expect(state.alarmCode, 1);
    });
  });

  // ── Couverture complémentaire ──────────────────────────────────────────────

  group('Statut — champs additionnels', () {
    test('calcule wPos = mPos - wco', () {
      final s = GrblParser.parse(
          '<Idle|MPos:100.000,50.000,10.000,0.000,0.000,0.000'
          '|WCO:10.000,5.000,2.000,0.000,0.000,0.000>',
          initialState)!;
      expect(s.wPos[0], 90.0);
      expect(s.wPos[1], 45.0);
      expect(s.wPos[2], 8.0);
    });

    test('extrait les overrides (Ov:feed,rapid,spindle)', () {
      final s = GrblParser.parse(
          '<Idle|MPos:0,0,0,0,0,0|Ov:110,100,90>', initialState)!;
      expect(s.overrides, [110, 100, 90]);
    });

    test('gère les sous-états (Hold:0 → hold)', () {
      final s = GrblParser.parse('<Hold:0|MPos:0,0,0,0,0,0>', initialState)!;
      expect(s.status, MachineStatus.hold);
    });

    test('état Jog (pendant \$J=) → run (en ligne, pas offline)', () {
      final s = GrblParser.parse('<Jog|MPos:5,0,0,0,0,0|FS:800,0>', initialState)!;
      expect(s.status, MachineStatus.run);
    });

    test('parse les fins de course (Lim:XZ)', () {
      final s =
          GrblParser.parse('<Alarm|MPos:0,0,0,0,0,0|Lim:XZ>', initialState)!;
      expect(s.limitSwitches, [true, false, true, false, false]);
    });

    test('fin de course s\'efface quand Pn: disparaît (état momentané)', () {
      final s1 = GrblParser.parse('<Run|MPos:0,0,0,0,0,0|Pn:X>', initialState)!;
      expect(s1.limitSwitches[0], true);
      // Rapport suivant sans Pn: → le pin est relâché, la fin de course efface.
      final s2 = GrblParser.parse('<Run|MPos:0,0,0,0,0,0>', s1)!;
      expect(s2.limitSwitches[0], false,
          reason: 'Pn: absent = pin inactif → ne doit pas rester « actif »');
    });

    test('préserve la valeur courante pour un champ absent', () {
      final withFeed = initialState.copyWith(feedrate: 800);
      final s = GrblParser.parse('<Idle|MPos:1,2,3,0,0,0>', withFeed)!;
      expect(s.feedrate, 800, reason: 'FS absent → on garde la valeur courante');
    });

    test('broche ON via le champ accessoire A:S (relais M3)', () {
      final s = GrblParser.parse('<Run|MPos:0,0,0,0,0,0|A:S>', initialState)!;
      expect(s.spindleOn, true);
    });

    test('broche ON aussi pour A:C (anti-horaire) et champ mixte A:SFM', () {
      expect(GrblParser.parse('<Run|MPos:0,0,0,0,0,0|A:C>', initialState)!.spindleOn, true);
      expect(GrblParser.parse('<Run|MPos:0,0,0,0,0,0|A:SFM>', initialState)!.spindleOn, true);
    });

    test('broche s\'éteint quand A: disparaît (état momentané, M5)', () {
      final on = GrblParser.parse('<Run|MPos:0,0,0,0,0,0|A:S>', initialState)!;
      expect(on.spindleOn, true);
      // Rapport suivant sans A: → broche coupée, ne doit pas rester « active ».
      final off = GrblParser.parse('<Idle|MPos:0,0,0,0,0,0>', on)!;
      expect(off.spindleOn, false,
          reason: 'A: absent = accessoires éteints → broche OFF');
    });

    test('A: sans S/C (ex. arrosage seul A:F) → broche OFF', () {
      final s = GrblParser.parse('<Run|MPos:0,0,0,0,0,0|A:F>', initialState)!;
      expect(s.spindleOn, false);
    });

    test('broche ON dérivée de FS quand A: absent (relais M3 S1000)', () {
      // Cas réel Forgeron : la machine n'émet pas `A:`, seulement FS.
      final s =
          GrblParser.parse('<Idle|MPos:0,0,0,0,0,0|FS:0,1000>', initialState)!;
      expect(s.spindleOn, true, reason: 'FS spindle > 0 → broche active');
      expect(s.spindleSpeed, 1000);
    });

    test('broche OFF quand FS spindle = 0 (M5) sans A:', () {
      final s =
          GrblParser.parse('<Idle|MPos:0,0,0,0,0,0|FS:0,0>', initialState)!;
      expect(s.spindleOn, false);
    });
  });

  group('État modal [GC:…]', () {
    test('extrait WCS, outil, avance et broche', () {
      final s =
          GrblParser.parse('[GC:G0 G55 T3 F1200 S12000]', initialState)!;
      expect(s.activeWCS, 'G55');
      expect(s.activeToolNum, 3);
      expect(s.feedrate, 1200.0);
      expect(s.spindleSpeed, 12000.0);
    });
  });

  group('Palpage [PRB:…]', () {
    test('détecte un palpage réussi (:1)', () {
      final prb = GrblParser.parseProbeReport('[PRB:100.000,50.000,-10.000:1]')!;
      expect(prb['success'], true);
      expect((prb['coords'] as List)[2], -10.0);
    });

    test('détecte un palpage raté (:0)', () {
      final prb = GrblParser.parseProbeReport('[PRB:0,0,0:0]')!;
      expect(prb['success'], false);
    });
  });

  group('Trames non reconnues', () {
    test('ok / error / vide → null (ignorés)', () {
      expect(GrblParser.parse('ok', initialState), isNull);
      expect(GrblParser.parse('error:5', initialState), isNull);
      expect(GrblParser.parse('', initialState), isNull);
    });

    test('statut sans chevrons → null', () {
      expect(
          GrblParser.parseStatusReport('Idle|MPos:0,0,0,0,0,0', initialState),
          isNull);
    });
  });
}
