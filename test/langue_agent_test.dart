import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/core/i18n/app_language.dart';

/// Ce que l'agent a le droit de dire, et dans quelle langue.
///
/// Historique à garder en tête : le bambara a été langue de réponse, puis
/// interdit (réponses incompréhensibles constatées en atelier), puis rétabli
/// sur décision de l'utilisateur le 27/10/2026 — avec trois garde-fous à la
/// place de l'interdiction. Ces tests fixent les garde-fous, pour qu'un
/// prochain aller-retour ne les emporte pas en silence.
void main() {
  group('langue de réponse', () {
    test('le bambara est redevenu une langue de réponse', () {
      final bm = appLanguageById('bm');
      expect(bm.writesPoorly, isFalse,
          reason: 'décision utilisateur : il veut des réponses en bambara');
      final d = bm.promptDirective;
      expect(d, contains('SYSTÉMATIQUEMENT en bambara'));
      expect(d, isNot(contains("N'écris jamais")));
    });

    test('le mode automatique ne fait plus de cas particulier du bambara', () {
      final d = appLanguageById('auto').promptDirective;
      expect(d, contains('langue du dernier message'));
      expect(d, isNot(contains('bambara')));
    });

    /// Le drapeau reste utilisable : la raison qui l'avait motivé est réelle
    /// et resservira si une mesure la confirme pour un modèle donné.
    test('le mécanisme writesPoorly reste en état de marche', () {
      const essai = AppLanguage('xx', 'Essai', 'essai', 'xx-XX',
          writesPoorly: true);
      final d = essai.promptDirective;
      expect(d, contains('FRANÇAIS SIMPLE'));
      expect(d, contains("N'écris jamais"));
    });
  });

  group("règle du parler d'atelier", () {
    test('elle vise les langues peu dotées, et elles seules', () {
      expect(appLanguageById('bm').promptDirective, contains("PARLER D'ATELIER"));
      expect(appLanguageById('wo').promptDirective, contains("PARLER D'ATELIER"));
      for (final id in ['fr', 'en', 'ar', 'sw']) {
        expect(appLanguageById(id).promptDirective,
            isNot(contains("PARLER D'ATELIER")),
            reason: id);
      }
    });

    test('elle nomme les mots-clés des outils, en français', () {
      final d = appLanguageById('bm').promptDirective;
      // Ce sont les mots que l'opérateur emploie réellement devant la
      // machine, et que le modèle doit reconnaître au milieu du bambara.
      for (final mot in ['broche', 'jog', 'homing', 'origine', 'palpage',
        'avance', 'arrosage', 'programme', 'fichier', 'outil', 'axe',
        'alarme', 'offset']) {
        expect(d, contains(mot), reason: mot);
      }
      expect(d, contains('Ne forge jamais de mot'));
    });
  });

  group('glossaire sourcé', () {
    late Map<String, String> glossaires;

    setUpAll(() {
      final json = jsonDecode(File('assets/lexicon/lexique.json')
          .readAsStringSync()) as Map<String, dynamic>;
      glossaires = buildGlossaries(json);
    });

    test('le bambara en a un, bâti sur les mots du lexique', () {
      final g = glossaires['bm'];
      expect(g, isNotNull);
      // Mots relevés un par un sur An ka taa (voir lexique.json/sources).
      expect(g, contains('jɔ'));       // arrêter
      expect(g, contains('daminɛ'));   // démarrer
      expect(g, contains('mansin'));   // machine
      expect(g, contains('kelen=1'));  // nombres
    });

    test('il dit son statut de relecture plutôt que de le taire', () {
      final g = glossaires['bm']!;
      expect(g, contains('brouillon'));
      expect(g, contains('non relu par un locuteur'));
      expect(g, contains("N'en invente pas d'autres"));
    });

    test('le français et l\'anglais n\'en ont pas : ce sont les sources', () {
      expect(glossaires.containsKey('fr'), isFalse);
      expect(glossaires.containsKey('en'), isFalse);
    });

    test('une langue sans sources est écartée', () {
      final sansSource = {
        'languages': {
          'zz': {
            'name': 'sans source',
            'sources': <String>[],
            'actions': {'stop': ['xxx']},
          }
        }
      };
      expect(buildGlossaries(sansSource), isEmpty);
    });
  });
}
