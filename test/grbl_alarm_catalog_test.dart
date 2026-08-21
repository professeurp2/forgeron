import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/grbl_alarm_catalog.dart';

void main() {
  test('sans code rapporte, pas de fiche', () {
    expect(GrblAlarmCatalog.lookup(null), isNull);
  });

  test('toute l\'enumeration FluidNC est couverte', () {
    for (var code = 1; code <= 18; code++) {
      expect(GrblAlarmCatalog.isKnown(code), isTrue,
          reason: 'code $code absent du catalogue');
      final info = GrblAlarmCatalog.lookup(code)!;
      expect(info.code, code);
      expect(info.title, isNotEmpty);
      expect(info.cause, isNotEmpty);
      expect(info.action, isNotEmpty);
    }
  });

  group('perte de position — l\'information la plus couteuse a ignorer', () {
    test('fin de course materielle : position perdue', () {
      final info = GrblAlarmCatalog.lookup(1)!;
      expect(info.positionLost, isTrue);
      expect(info.unlockable, isFalse);
    });

    test('depassement de course : position conservee et deverrouillable', () {
      // Le mouvement a ete REFUSE avant execution : la machine n'a pas bouge.
      final info = GrblAlarmCatalog.lookup(2)!;
      expect(info.positionLost, isFalse);
      expect(info.unlockable, isTrue);
    });

    test('tous les echecs de prise d\'origine perdent la position', () {
      // 10 n'en fait PAS partie chez FluidNC : c'est un défaut de broche.
      for (final code in [6, 7, 8, 9, 12]) {
        expect(GrblAlarmCatalog.lookup(code)!.positionLost, isTrue,
            reason: 'code $code');
      }
    });

    test('les echecs de palpage ne perdent pas la position', () {
      for (final code in [4, 5]) {
        expect(GrblAlarmCatalog.lookup(code)!.positionLost, isFalse,
            reason: 'code $code');
      }
    });
  });

  test('le code 10 est un defaut de broche, pas un echec d\'equerrage', () {
    // Piege : GRBL 1.1 met « echec d'equerrage axe double » sur le 10.
    // FluidNC y met SpindleControl. Reprendre la table GRBL donnerait une
    // cause fausse sur cette machine.
    final info = GrblAlarmCatalog.lookup(10)!;
    expect(info.title.toLowerCase(), contains('broche'));
    expect(info.positionLost, isFalse);
  });

  test('le demarrage en alarme est explique comme normal', () {
    // FluidNC demarre en alarme quand la config exige une prise d'origine :
    // l'operateur doit lire que ce n'est pas une panne.
    final info = GrblAlarmCatalog.lookup(15)!;
    expect(info.cause.toLowerCase(), contains('normal'));
  });

  group('code inconnu', () {
    test('annonce le numero sans inventer de cause', () {
      expect(GrblAlarmCatalog.isKnown(99), isFalse);
      final info = GrblAlarmCatalog.lookup(99)!;
      expect(info.code, 99);
      expect(info.title, contains('99'));
      expect(info.cause, contains('n\'est pas répertorié'));
      // Aucune consigne dangereuse par defaut : on ne declare pas la position
      // perdue, et on n'invite pas non plus a deverrouiller sans regarder.
      expect(info.positionLost, isFalse);
      expect(info.unlockable, isFalse);
    });
  });
}
