import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_command_guard.dart';

void main() {
  group('refusées : l\'assistant n\'écrit jamais les réglages', () {
    const refused = [
      r'$RST=*',
      r'$rst=#',
      r'$RST=$',
      r'$20=0', // désactiver les limites logicielles
      r'$21=0', // désactiver les limites matérielles
      r'$100=250',
      r'$N0=G54',
      r'$Bye',
      r'$Restart',
      r'$Config/Dump',
      r'$Config/Filename=x.yaml',
      r'$Erase/Config',
      r'$LocalFS/Delete=config.yaml',
      r'$SD/Delete=a.nc',
      r'$Report/Interval=0',
      r'  $RST=*  ', // espaces autour
      r'$20=0 ; désactive les limites', // commentaire de fin
    ];
    for (final c in refused) {
      test('« $c »', () {
        final why = GcodeCommandGuard.refusal(c);
        expect(why, isNotNull);
        expect(why, contains('réglages'));
      });
    }
  });

  group('admises : lectures et actions surveillées', () {
    const allowed = [
      r'$$', // lire les réglages
      r'$#', // lire les décalages
      r'$G', // état de l'interpréteur
      r'$I', // informations
      r'$N', // lire les lignes de démarrage
      r'$X', // déverrouiller
      r'$H', // homing
      r'$HZ',
      r'$HXY',
      r'$J=G91 X5 F300', // jog
      r'$j=g91 z-1 f200',
      'G0 X10',
      'G1 Z-1 F100',
      'M3 S1000',
      'M5',
      '',
      '   ',
      '; commentaire seul',
      '(commentaire) G0 X1',
    ];
    for (final c in allowed) {
      test('« $c »', () => expect(GcodeCommandGuard.refusal(c), isNull));
    }
  });

  group('programme', () {
    test('un programme sain passe', () {
      expect(
          GcodeCommandGuard.refusalInProgram('G90\nG0 X10\nG1 Z-1 F100\nM5'),
          isNull);
    });

    test('le premier refus est signalé avec son numéro de ligne', () {
      final why = GcodeCommandGuard.refusalInProgram('G90\nG0 X10\n\$RST=*\nM5');
      expect(why, startsWith('ligne 3'));
    });

    test('fins de ligne Windows', () {
      expect(GcodeCommandGuard.refusalInProgram('G0 X1\r\n\$20=0\r\nM5'),
          startsWith('ligne 2'));
    });
  });
}
