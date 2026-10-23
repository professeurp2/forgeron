import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/docs_provider.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/command_understanding.dart';
import 'package:forgeron/core/utils/doc_search.dart';

DocCorpus _corpus() =>
    buildCorpus(File('assets/docs/fiches.json').readAsStringSync(encoding: utf8));

void main() {
  final corpus = _corpus();
  final index = corpus.index;

  List<String> ids(String q, {int k = 3}) =>
      [for (final h in index.search(q, topK: k)) h.chunk.id];

  group('le corpus', () {
    test('contient les fiches et une fiche par alarme du catalogue', () {
      expect(corpus.size, greaterThan(30));
      expect(index.chunks.where((c) => c.id.startsWith('alarme-')).length,
          greaterThanOrEqualTo(15));
    });
    test('identifiants uniques, texte et source renseignés', () {
      final seen = <String>{};
      for (final c in index.chunks) {
        expect(seen.add(c.id), isTrue, reason: 'doublon ${c.id}');
        expect(c.text.trim(), isNotEmpty, reason: c.id);
        expect(c.source.trim(), isNotEmpty, reason: c.id);
      }
    });
    test('un fichier illisible laisse au moins les alarmes', () {
      final c = buildCorpus('pas du json');
      expect(c.size, greaterThanOrEqualTo(15));
    });
  });

  group('questions avec réponse', () {
    final cases = <String, String>{
      'C\'est quoi l\'alarme 9 ?': 'alarme-9',
      'ALARM:1': 'alarme-1',
      'comment allumer la broche avec M3': 'broche-relais',
      'pourquoi la broche fait des étincelles': 'broche-alimentation',
      'l\'ESP32 plante et la broche continue de tourner': 'estop-defaut-materiel',
      'dans quel sens se fait le homing de Z': 'homing-procedure',
      'G10 L20 zéro pièce': 'gcode-origines',
      'palpage G38.2': 'gcode-deplacements',
      'pas de la vis de l\'axe X': 'axes-vis-pas',
      'fins de course NC gpio': 'fins-de-course',
      'F en 5 axes avance réelle': 'avance-5-axes',
      'arrosage M8': 'gcode-broche-arrosage',
    };
    cases.forEach((q, expected) {
      test('« $q » → $expected', () {
        expect(ids(q), contains(expected), reason: '${ids(q)}');
        expect(ids(q).first, expected, reason: '${ids(q)}');
      });
    });
    test('« à quoi sert \$X » : fiche des commandes temps réel', () {
      expect(ids(r'à quoi sert $X'), contains('commandes-temps-reel'));
    });
  });

  group('questions sans réponse : le silence vaut mieux qu\'une fiche à peu près', () {
    for (final q in [
      'quelle est la capitale du Mali',
      'recette de crêpes',
      'qui a gagné le match hier',
      '',
      '   ',
      'le la les',
    ]) {
      test('« $q » → aucune fiche', () {
        expect(ids(q), isEmpty, reason: '${ids(q)}');
      });
    }
  });

  test('chaque fiche se retrouve par son propre titre', () {
    for (final c in index.chunks) {
      expect(ids(c.title, k: 3), contains(c.id), reason: c.title);
    }
  });

  test('l\'outil est en lecture seule et cité dans le routeur', () {
    expect(isReadOnlyToolName('search_docs'), isTrue);
    expect(AiToolCatalog.byName('search_docs')!.category, isNull);
  });

  group('l\'outil search_docs', () {
    late ProviderContainer c;
    late Ref ref;
    setUp(() {
      c = ProviderContainer(overrides: [
        docsSourceProvider.overrideWithValue(
            () async => File('assets/docs/fiches.json').readAsString()),
      ]);
      ref = c.read(Provider((r) => r));
    });
    tearDown(() => c.dispose());

    test('rend les fiches avec id, source et statut, en taille bornée', () async {
      final out = await AiToolCatalog.byName('search_docs')!
          .execute({'query': 'alarme 9'}, ref);
      final j = jsonDecode(out) as Map;
      final r = (j['resultats'] as List).cast<Map>();
      expect(r.first['id'], 'alarme-9');
      expect(r.first['source'], isNotEmpty);
      expect(r.first['statut'], 'brouillon');
      expect(out.length, lessThan(2800));
    });

    test('rien de trouvé : liste vide et consigne de ne rien inventer',
        () async {
      final out = await AiToolCatalog.byName('search_docs')!
          .execute({'query': 'recette de crêpes'}, ref);
      final j = jsonDecode(out) as Map;
      expect(j['resultats'], isEmpty);
      expect('${j['note']}', contains('invente'));
    });

    test('requête vide : erreur claire', () async {
      final out = await AiToolCatalog.byName('search_docs')!
          .execute({'query': ' '}, ref);
      expect(out, startsWith('ERREUR'));
    });
  });
}
