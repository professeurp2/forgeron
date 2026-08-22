import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/presentation/widgets/mobile/wcs_offset_dialog.dart';

/// Écrire un décalage d'origine pièce est une opération que la machine accepte
/// sans discuter : une erreur ne se voit pas, elle se découvre au premier
/// mouvement. D'où ces tests sur la correspondance et le formatage.
void main() {
  const axes = ['X', 'Y', 'Z', 'A', 'C'];

  group('correspondance WCS -> P', () {
    test('G54 a G59 donnent P1 a P6', () {
      expect(wcsPNumber('G54'), 1);
      expect(wcsPNumber('G55'), 2);
      expect(wcsPNumber('G56'), 3);
      expect(wcsPNumber('G57'), 4);
      expect(wcsPNumber('G58'), 5);
      expect(wcsPNumber('G59'), 6);
    });

    test('une entree hors plage retombe sur P1 plutot que de deriver', () {
      // Mieux vaut ecrire dans G54 — visible immediatement — que dans un
      // numero calcule hors des six systemes existants.
      expect(wcsPNumber('G53'), 1);
      expect(wcsPNumber('G60'), 1);
      expect(wcsPNumber('n import quoi'), 1);
    });
  });

  group('saisie', () {
    test('la virgule decimale est acceptee', () {
      expect(parseOffset('-120,5'), -120.5);
      expect(parseOffset('-120.5'), -120.5);
      expect(parseOffset('  12,25  '), 12.25);
    });

    test('une valeur non numerique est refusee, pas convertie en zero', () {
      // Silencieusement transformer « abc » en 0 poserait l'origine au zero
      // machine, c'est-a-dire sur les capteurs.
      expect(parseOffset('abc'), isNull);
      expect(parseOffset(''), isNull);
      expect(parseOffset('12,5,3'), isNull);
    });
  });

  group('commande', () {
    test('utilise G10 L2 et non L20', () {
      final cmd = buildWcsOffsetCommand('G55', [-120.5, -80, -15, 0, 0], axes);
      expect(cmd, startsWith('G10 L2 P2 '));
      expect(cmd, isNot(contains('L20')),
          reason: 'L20 poserait la position COURANTE, pas le decalage saisi');
    });

    test('tous les axes sont ecrits, y compris les nuls', () {
      // Omettre un axe le laisserait a son ancienne valeur : l'utilisateur
      // croirait avoir tout defini.
      final cmd = buildWcsOffsetCommand('G54', [0, 0, 0, 0, 0], axes);
      expect(cmd, 'G10 L2 P1 X0 Y0 Z0 A0 C0');
    });

    test('les zeros inutiles sont retires, la precision conservee', () {
      final cmd = buildWcsOffsetCommand('G54', [-120.5, -80.125, 0, 0, 0], axes);
      expect(cmd, contains('X-120.5'));
      expect(cmd, contains('Y-80.125'));
      expect(cmd, isNot(contains('X-120.500')));
    });

    test('les negatifs passent intacts', () {
      // Cas nominal sur cette machine : le zero machine est aux capteurs, donc
      // le zero piece est toujours en negatif.
      final cmd = buildWcsOffsetCommand('G56', [-75.25, -42.1, -3.5, 0, 0], axes);
      expect(cmd, 'G10 L2 P3 X-75.25 Y-42.1 Z-3.5 A0 C0');
    });
  });
}
