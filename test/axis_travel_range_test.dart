import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/machine_params_provider.dart';

/// Bornes de course machine, deduites du homing.
///
/// Valeurs reprises de la config reelle de la machine : X et Y cherchent leur
/// capteur en negatif (capteur au minimum), Z en positif (capteur EN HAUT), et
/// A est bipolaire — capteur a -88, course 178, donc -88 -> +90.
void main() {
  const yaml = '''
axes:
  x:
    steps_per_mm: 264.000
    max_rate_mm_per_min: 500.000
    acceleration_mm_per_sec2: 30.000
    max_travel_mm: 88.000
    homing:
      cycle: 2
      positive_direction: false
      mpos_mm: 0.000
  z:
    steps_per_mm: 400.000
    max_rate_mm_per_min: 300.000
    acceleration_mm_per_sec2: 20.000
    max_travel_mm: 110.000
    homing:
      cycle: 1
      positive_direction: true
      mpos_mm: 0.000
  a:
    steps_per_mm: 16.667
    max_rate_mm_per_min: 3600.000
    acceleration_mm_per_sec2: 50.000
    max_travel_mm: 178.000
    homing:
      cycle: 3
      positive_direction: false
      mpos_mm: -88.000
''';

  AxisKinematics axis(String letter) =>
      parseAxisKinematics(yaml).firstWhere((k) => k.axis == letter);

  group('lecture du homing', () {
    test('mpos_mm est lu malgre son imbrication sous homing:', () {
      expect(axis('A').homingMpos, -88.0);
      expect(axis('X').homingMpos, 0.0);
    });

    test('positive_direction est lu, booleen compris', () {
      expect(axis('Z').homingPositive, isTrue);
      expect(axis('X').homingPositive, isFalse);
    });
  });

  group('plage machine', () {
    test('capteur au minimum : la course part vers le positif', () {
      expect(axis('X').machineRange, (0.0, 88.0));
    });

    test('capteur au maximum : la course part vers le negatif', () {
      // Z a son capteur EN HAUT : la machine descend donc en negatif.
      expect(axis('Z').machineRange, (-110.0, 0.0));
    });

    test('axe bipolaire : les bornes encadrent le zero', () {
      expect(axis('A').machineRange, (-88.0, 90.0));
    });
  });

  group('fraction de course', () {
    test('les extremites donnent 0 et 1', () {
      expect(axis('X').travelFraction(0), 0.0);
      expect(axis('X').travelFraction(88), 1.0);
      expect(axis('Z').travelFraction(-110), 0.0);
      expect(axis('Z').travelFraction(0), 1.0);
    });

    test('le milieu donne 0,5', () {
      expect(axis('X').travelFraction(44), closeTo(0.5, 1e-9));
      expect(axis('A').travelFraction(1), closeTo(0.5, 1e-9));
    });

    test('un axe bipolaire ne confond pas ses deux cotes', () {
      // Le piege qu'une simple valeur absolue rapportee a la course
      // introduirait : -88 et +88 y donneraient la meme fraction.
      final a = axis('A');
      expect(a.travelFraction(-88), isNot(closeTo(a.travelFraction(88)!, 0.01)));
      expect(a.travelFraction(-88), 0.0);
      expect(a.travelFraction(88), closeTo(0.9888, 1e-3));
    });

    test('hors course, la fraction reste bornee', () {
      expect(axis('X').travelFraction(-50), 0.0);
      expect(axis('X').travelFraction(999), 1.0);
    });
  });

  test('course inconnue : aucune fraction plutot qu\'une fausse', () {
    const bare = AxisKinematics(axis: 'Y');
    expect(bare.machineRange, isNull);
    expect(bare.travelFraction(10), isNull);
  });
}
