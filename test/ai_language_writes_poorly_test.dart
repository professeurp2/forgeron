import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/i18n/app_language.dart';

/// Le bambara en sortie a connu deux décisions successives :
///
/// 1. interdit (`writesPoorly`) parce que le modèle l'écrivait mal — un
///    opérateur avait jugé ses réponses illisibles ;
/// 2. rétabli à la demande de l'utilisateur (962849c), adossé à un glossaire
///    sourcé et à la règle du parler d'atelier.
///
/// Ce fichier vérifiait encore la décision 1 et restait rouge depuis la 2. Il
/// verrouille désormais les deux choses qui comptent : la décision en vigueur
/// pour le bambara, ET le mécanisme `writesPoorly`, qui doit rester prêt à
/// resservir si une langue s'avère mal écrite.
void main() {
  test('bambara : langue de réponse, avec les mots d\'atelier en français', () {
    final bm = appLanguageById('bm');
    expect(bm.writesPoorly, isFalse);
    expect(bm.lowResource, isTrue);
    final d = bm.promptDirective;
    expect(d, contains('SYSTÉMATIQUEMENT en bambara'));
    expect(d, contains('PARLER D\'ATELIER'));
    expect(d, contains('Ne forge jamais de mot technique en bambara'));
    expect(d, isNot(contains('FRANÇAIS SIMPLE')));
  });

  test('la note du bambara dit ce qui reste en français, et pourquoi', () {
    final note = appLanguageById('bm').note!;
    expect(note, contains('répond en bambara'));
    expect(note, contains('pas encore été relu'));
    expect(note, contains('restent en français'));
  });

  test('le mécanisme « écrit mal » reste prêt : français simple, jamais la langue',
      () {
    const mal = AppLanguage('xx', 'Test', 'testois', 'xx-XX', writesPoorly: true);
    final d = mal.promptDirective;
    expect(d, contains('FRANÇAIS SIMPLE'));
    expect(d, contains('N\'écris jamais de testois'));
    expect(d, isNot(contains('SYSTÉMATIQUEMENT en testois')));
  });

  test('mode automatique : la langue du dernier message, français si indécidable', () {
    final d = appLanguageById('auto').promptDirective;
    expect(d, contains('langue du dernier message'));
    expect(d, contains('réponds en français'));
  });

  test('les autres langues gardent la consigne d\'origine', () {
    expect(appLanguageById('en').promptDirective, contains('SYSTÉMATIQUEMENT en anglais'));
    expect(appLanguageById('sw').writesPoorly, isFalse);
  });

  test('les invariants de sécurité restent identiques dans toutes les langues', () {
    for (final id in ['auto', 'fr', 'bm', 'en', 'sw']) {
      final d = appLanguageById(id).promptDirective;
      expect(d, contains('Ne traduis JAMAIS'), reason: id);
      expect(d, contains('G54..G59'), reason: id);
    }
  });
}
