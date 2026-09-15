import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/fallback_localizations.dart';
import 'package:forgeron/core/i18n/translations/translations.dart';

void main() {
  setUp(() => AppLocalizations.setCurrentForTest(const <String, String>{}));
  tearDown(() => AppLocalizations.setCurrentForTest(const <String, String>{}));

  group('tr', () {
    test('retombe sur le français quand la langue n\'a pas la chaîne', () {
      expect(tr('Enregistrer'), 'Enregistrer');
    });

    test('traduit quand la table courante contient la clé', () {
      AppLocalizations.setCurrentForTest(const {'Enregistrer': 'Save'});
      expect(tr('Enregistrer'), 'Save');
    });

    test('substitue les paramètres dans l\'ordre', () {
      AppLocalizations.setCurrentForTest(const {'Ligne {}/{}': 'Line {}/{}'});
      expect(tr('Ligne {}/{}', [12, 480]), 'Line 12/480');
    });

    test('substitue aussi quand la traduction manque', () {
      expect(tr('Ligne {}/{}', [3, 9]), 'Ligne 3/9');
    });

    test('un argument surnuméraire ne casse rien', () {
      expect(tr('Erreur: {}', ['E13', 'ignoré']), 'Erreur: E13');
    });
  });

  group('dictionnaires', () {
    test('chaque langue du sélecteur a une locale valide', () {
      for (final l in kAppLanguages.where((l) => !l.isAuto)) {
        expect(l.locale, isNotNull, reason: l.id);
        expect(l.locale!.languageCode, l.id, reason: l.id);
      }
      expect(kSupportedLocales.length, kAppLanguages.length - 1);
      // Le premier repli de MaterialApp doit rester le français.
      expect(kSupportedLocales.first.languageCode, 'fr');
    });

    test('le français n\'a pas de dictionnaire : c\'est la langue source', () {
      expect(kAppTranslations.containsKey('fr'), isFalse);
    });

    test('toute langue traduite est proposée dans le sélecteur', () {
      final ids = kAppLanguages.map((l) => l.id).toSet();
      for (final code in kAppTranslations.keys) {
        expect(ids, contains(code), reason: code);
      }
    });

    test('aucune valeur vide (ça afficherait du blanc, pas du français)', () {
      for (final entry in kAppTranslations.entries) {
        for (final e in entry.value.entries) {
          expect(e.value.trim(), isNotEmpty,
              reason: '${entry.key} : « ${e.key} »');
        }
      }
    });

    /// Le garde-fou qui compte : un `{}` perdu en traduction fait disparaître
    /// un code d'alarme, un numéro de ligne ou un nom de fichier — sans
    /// aucune erreur visible à l'exécution.
    test('le nombre de {} est identique entre la clé et la traduction', () {
      final holes = RegExp(r'\{\}');
      final faults = <String>[];
      for (final entry in kAppTranslations.entries) {
        for (final e in entry.value.entries) {
          final expected = holes.allMatches(e.key).length;
          final actual = holes.allMatches(e.value).length;
          if (expected != actual) {
            faults.add('${entry.key} : « ${e.key} » '
                '($expected attendu(s), $actual trouvé(s))');
          }
        }
      }
      expect(faults, isEmpty, reason: faults.join('\n'));
    });

    test('les sauts de ligne des clés sont préservés', () {
      for (final entry in kAppTranslations.entries) {
        for (final e in entry.value.entries) {
          if (!e.key.contains('\n')) continue;
          expect(e.value, contains('\n'),
              reason: '${entry.key} : « ${e.key.replaceAll('\n', r'\n')} »');
        }
      }
    });

    test('les langues peu dotées sont bien signalées comme telles', () {
      // L'avertissement de l'écran de réglages dépend de ce drapeau : s'il
      // saute, l'opérateur ne sait plus quelles langues sont approximatives.
      for (final id in ['wo', 'ln', 'rw', 'sn', 'mg']) {
        expect(appLanguageById(id).lowResource, isTrue, reason: id);
      }
      for (final id in ['fr', 'en', 'ar', 'sw', 'af']) {
        expect(appLanguageById(id).lowResource, isFalse, reason: id);
      }
    });
  });

  group('bout en bout dans un MaterialApp', () {
    Widget app(Locale? locale) => MaterialApp(
          locale: locale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FallbackMaterialLocalizationsDelegate(),
            FallbackCupertinoLocalizationsDelegate(),
          ],
          home: Builder(builder: (_) => Text(tr('Enregistrer'))),
        );

    testWidgets('le français affiche la chaîne source', (tester) async {
      await tester.pumpWidget(app(const Locale('fr')));
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('une langue traduite affiche sa traduction', (tester) async {
      await tester.pumpWidget(app(const Locale('en')));
      expect(find.text('Save'), findsOneWidget);
      await tester.pumpWidget(app(const Locale('sw')));
      expect(find.text('Hifadhi'), findsOneWidget);
    });

    /// Flutter ne fournit pas de MaterialLocalizations pour le wolof : sans
    /// les délégués de repli, ce test échouerait sur « No MaterialLocalizations
    /// found » — c'est-à-dire que l'app tomberait au choix de la langue.
    testWidgets("une langue absente de Flutter ne fait pas tomber l'app",
        (tester) async {
      for (final code in ['wo', 'ln', 'rw', 'sn']) {
        await tester.pumpWidget(app(Locale(code)));
        expect(tester.takeException(), isNull, reason: code);
        expect(find.byType(Text), findsOneWidget, reason: code);
      }
    });

    testWidgets('la locale nulle laisse le système résoudre', (tester) async {
      await tester.pumpWidget(app(null));
      expect(tester.takeException(), isNull);
    });
  });

  group('délégué', () {
    test('installe la table de la locale et la retire pour une inconnue',
        () async {
      const delegate = AppLocalizations.delegate;
      final en = await delegate.load(const Locale('en'));
      expect(en.entries, isNotEmpty);
      expect(AppLocalizations.current, same(en.entries));

      final unknown = await delegate.load(const Locale('xx'));
      expect(unknown.entries, isEmpty);
      expect(tr('Enregistrer'), 'Enregistrer');
    });

    test('accepte toutes les locales pour ne jamais écarter la résolution', () {
      const delegate = AppLocalizations.delegate;
      expect(delegate.isSupported(const Locale('wo')), isTrue);
      expect(delegate.isSupported(const Locale('xx')), isTrue);
    });
  });
}
