import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/language_detector.dart';

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
      expect(d, contains('Réponds en bambara'));
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
      expect(d, contains('Ne forge JAMAIS de mot'));
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
      expect(g, contains('NE RÉCITE JAMAIS cette liste'));
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

  // Banc de conversation du 5 nov. 2026 (tool/eval/conversation_langues_test.dart) :
  // le prompt disait « réponds en bambara » au milieu, « en français » à la
  // fin ; le wolof et le haoussa n'étaient pas reconnus et recevaient
  // l'ordre de répondre en français.
  group('une seule langue de réponse dans tout le prompt', () {
    test('bambara choisi : la consigne de fin dit bambara, pas français', () {
      final a = appLanguageById('bm').trailingPromptAnchor(
          detectedLanguageCode: 'bm');
      expect(a, contains('Réponds en bambara.'));
      expect(a, isNot(contains('FRANÇAIS SIMPLE')));
    });

    test('automatique : la consigne de fin suit la langue détectée', () {
      final auto = appLanguageById('auto');
      for (final e in {
        'bm': 'bambara',
        'wo': 'wolof',
        'ha': 'haoussa',
        'sw': 'swahili',
        'ln': 'lingala',
        'en': 'anglais',
      }.entries) {
        expect(auto.trailingPromptAnchor(detectedLanguageCode: e.key),
            contains('Réponds en ${e.value}.'));
        expect(auto.replyLanguage(e.key).id, e.key);
      }
    });

    test('automatique : langue inconnue ou indécidable → français', () {
      final auto = appLanguageById('auto');
      expect(auto.replyLanguage('zh').id, 'fr');
      expect(auto.replyLanguage(null).id, 'fr');
      expect(auto.trailingPromptAnchor(), contains('Réponds en français.'));
    });

    test('langue imposée : elle gagne sur la langue détectée', () {
      expect(appLanguageById('sw').replyLanguage('fr').id, 'sw');
    });

    test('writesPoorly : la consigne de fin reste du français simple', () {
      const essai = AppLanguage('xx', 'Essai', 'essai', 'xx-XX',
          writesPoorly: true);
      expect(essai.trailingPromptAnchor(), contains('FRANÇAIS SIMPLE'));
    });

    test("la directive ne prétend plus que l'interface est en français", () {
      for (final id in ['auto', 'fr', 'bm', 'sw']) {
        expect(appLanguageById(id).promptDirective,
            isNot(contains('est en français')));
      }
    });
  });

  group('détection de la langue de l\'opérateur', () {
    String d(String t) => LanguageDetector.detectOperatorLanguage(t);

    test('les langues africaines de l\'application sont reconnues', () {
      const cas = {
        'I ni ce. I bɛ se ka mun kɛ n ye?': 'bm',
        'Mansin cogoya ka di sisan?': 'bm',
        'Application kan yɛlɛma ka kɛ bamanankan ye': 'bm',
        'Habari, unaweza kunisaidia nini?': 'sw',
        'Badilisha lugha ya programu iwe Kiswahili': 'sw',
        'Salaam aleekum, lan nga mënn a def ngir man?': 'wo',
        'Naka la masin bi mel léegi?': 'wo',
        'Sannu, me za ka iya yi mini?': 'ha',
        'Yaya yanayin injin yanzu?': 'ha',
        'Bawo ni, ṣe ẹrọ naa ti ṣetan?': 'yo',
        'Kedu, biko gbanwee asụsụ': 'ig',
        'Sawubona, umshini unjani manje?': 'zu',
        'Fadlan, mashiinka hadda sidee yahay?': 'so',
        'Muraho, imashini imeze ite ubu?': 'rw',
        'Mhoroi, muchina uri sei zvino?': 'sn',
        'Mbote, masini ezali ndenge nini?': 'ln',
        'Manao ahoana, inona ny toetry ny milina ankehitriny?': 'mg',
        'Goeie môre, hoe gaan dit met die masjien nou?': 'af',
        'مرحبا، ما هي حالة الآلة الآن؟': 'ar',
        'ማሽኑ እንዴት ነው?': 'am',
      };
      cas.forEach((texte, langue) => expect(d(texte), langue, reason: texte));
    });

    test("le parler d'atelier : un mot-témoin avec des mots techniques", () {
      expect(d('Broche daminɛ'), 'bm');
      expect(d('Homing kɛ'), 'bm');
      expect(d('Washa spindle tafadhali'), 'sw');
    });

    test('le français et l\'anglais ne basculent pas', () {
      expect(d('Bonjour, pourquoi la machine affiche une alarme ?'), 'fr');
      expect(d('Vérifie le réseau LAN de la machine avant de lancer'), 'fr');
      expect(d('Allume la broche à 8000 tours'), 'fr');
      expect(d('What is the machine state right now?'), 'en');
      expect(d('Switch the app interface to French please'), 'en');
      expect(d('Home all axes please'), 'en');
    });

    test('indécidable : la valeur de repli', () {
      expect(LanguageDetector.detectOperatorLanguage('G0 X10 Y5',
          fallback: ''), '');
      expect(LanguageDetector.detectOperatorLanguage('ok', fallback: 'sw'),
          'sw');
    });
  });
}
