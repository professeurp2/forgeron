import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/i18n/app_language.dart';

/// Un opérateur a jugé illisibles les réponses de l'assistant en bambara : le
/// modèle comprend la langue mais ne sait pas l'écrire. Il répond en français
/// simple ; le bambara ne viendra que de phrases fixes relues.
void main() {
  test('bambara choisi : réponse en français simple, jamais en bambara', () {
    final d = appLanguageById('bm').promptDirective;
    expect(d, contains('FRANÇAIS SIMPLE'));
    expect(d, contains('N\'écris jamais de bambara'));
    expect(d, isNot(contains('Réponds SYSTÉMATIQUEMENT en bambara')));
  });

  test('mode automatique : un message en bambara reçoit une réponse en français', () {
    final d = appLanguageById('auto').promptDirective;
    expect(d, contains('bambara'));
    expect(d, contains('sans jamais écrire de bambara'));
  });

  test('les autres langues gardent la consigne d\'origine', () {
    expect(appLanguageById('en').promptDirective, contains('SYSTÉMATIQUEMENT en anglais'));
    expect(appLanguageById('sw').writesPoorly, isFalse);
  });

  test('les invariants de sécurité restent identiques', () {
    for (final id in ['auto', 'fr', 'bm']) {
      final d = appLanguageById(id).promptDirective;
      expect(d, contains('Ne traduis JAMAIS'));
      expect(d, contains('G54..G59'));
    }
  });

  test('la note du bambara dit ce qui change', () {
    expect(appLanguageById('bm').note, contains('en français'));
  });
}
