import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/docs_provider.dart';
import 'package:forgeron/application/services/docs_prefetch.dart';

void main() {
  final index = buildCorpus(
          File('assets/docs/fiches.json').readAsStringSync(encoding: utf8))
      .index;

  group('une question de connaissance, pas un ordre', () {
    test('reconnue', () {
      for (final q in [
        'C\'est quoi l\'alarme 9 ?',
        'Comment allumer la broche',
        'Pourquoi la broche fait des étincelles',
        'What does G10 L20 do',
        'À quoi sert la commande \$X',
      ]) {
        expect(looksLikeKnowledgeQuestion(q), isTrue, reason: q);
      }
    });
    test('un ordre ou un merci n\'en est pas une', () {
      for (final q in ['Allume la broche', 'Merci, c\'est tout', 'Stop', '']) {
        expect(looksLikeKnowledgeQuestion(q), isFalse, reason: q);
      }
    });
  });

  group('bloc de fiches ajouté au prompt', () {
    test('fiche trouvée : id, texte, source et consigne de citer', () {
      final b = docsBlock('C\'est quoi l\'alarme 9 ?', index)!;
      expect(b, startsWith('=== FICHES TROUVÉES'));
      expect(b, contains('[alarme-9]'));
      expect(b, contains('source :'));
      expect(b, contains('identifiant'));
      expect(b.length, lessThan(2400), reason: 'le contexte d\'un modèle local est fini');
    });
    test('pas une question : aucun bloc (le prompt ne change pas)', () {
      expect(docsBlock('Allume la broche', index), isNull);
    });
    test('question hors du domaine, sans fiche : aucun bloc non plus', () {
      expect(docsBlock('Comment vas-tu ?', index), isNull);
      expect(docsBlock('Quelle est la capitale du Mali ?', index), isNull);
    });
    test('question du domaine sans fiche : constat « aucune fiche »', () {
      final b = docsBlock('Quelle est la procédure de réglage du refroidisseur de fraise ?', index);
      expect(b == null || isNoFicheBlock(b), isTrue);
      final c = docsBlock('Comment régler le laser de gravure de la fraise ?', index);
      if (c != null) expect(isNoFicheBlock(c) || c.contains('FICHES'), isTrue);
    });
  });

  group('un refus reste un refus', () {
    const block = '=== FICHES TROUVÉES POUR CETTE QUESTION ===\n\n[broche-relais] Broche\ntexte\n(source : x)';
    test('refus suivi d\'une procédure sans citation : coupé au refus', () {
      final out = enforceNoFicheReply(
          'Je ne trouve pas cette information dans mes fiches.\n\nCependant, pour changer l\'huile : 1. arrête la broche.',
          block: block);
      expect(out, kNoFicheSentence);
    });
    test('refus puis réponse qui cite une fiche : gardée entière', () {
      const text = 'Je ne trouve pas cette information dans mes fiches. Mais (broche-relais) dit que M3 S1000 allume la broche.';
      expect(enforceNoFicheReply(text, block: block), text);
    });
    test('réponse qui ne commence pas par le refus : inchangée', () {
      const text = 'La broche s\'allume avec M3 S1000 (broche-relais).';
      expect(enforceNoFicheReply(text, block: block), text);
    });
    test('« aucune fiche » : toujours coupé au refus', () {
      expect(enforceNoFicheReply('Je ne trouve pas cette information dans mes fiches. Cependant voici ma mémoire.', block: '=== AUCUNE FICHE NE CORRESPOND'),
          kNoFicheSentence);
    });
  });

  test('le résultat de l\'outil est le même pour l\'application et le banc', () {
    final j = jsonDecode(searchDocsResult(index, 'alarme 9')) as Map;
    expect((j['resultats'] as List).first['id'], 'alarme-9');
    final none = jsonDecode(searchDocsResult(index, 'recette de crêpes')) as Map;
    expect(none['resultats'], isEmpty);
    expect('${none['note']}', contains('invente'));
  });

  test('« pas » (pas par millimètre) n\'est plus un mot vide', () {
    final hits = index.search('pas par millimètre axe X vis');
    expect(hits.map((h) => h.chunk.id), contains('axes-vis-pas'));
  });
}
