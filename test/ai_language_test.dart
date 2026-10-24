import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/utils/voice_locale.dart';

void main() {
  group('bestVoiceLocale', () {
    test('préfère la correspondance exacte, quelle que soit la graphie', () {
      expect(bestVoiceLocale('sw-KE', ['fr_FR', 'sw_KE', 'en_US']), 'sw_KE');
      expect(bestVoiceLocale('fr-FR', ['fr-FR', 'fr-CA']), 'fr-FR');
    });

    test('retombe sur la même langue dans une autre région', () {
      expect(bestVoiceLocale('fr-FR', ['en_US', 'fr_CA']), 'fr_CA');
      expect(bestVoiceLocale('ar-MA', ['ar_EG', 'en_US']), 'ar_EG');
    });

    test('utilise les langues de repli quand la langue est absente', () {
      expect(
        bestVoiceLocale('wo-SN', ['en_US', 'fr_FR'],
            fallbacks: const ['fr-FR', 'en-US']),
        'fr_FR',
      );
    });

    test('retourne null si rien ne correspond, même avec les replis', () {
      expect(
        bestVoiceLocale('mg-MG', ['de_DE'], fallbacks: const ['fr-FR']),
        isNull,
      );
      expect(bestVoiceLocale('fr-FR', const []), isNull);
    });
  });

  group('AppLanguage', () {
    test('le mode automatique est le défaut et n\'impose pas de langue', () {
      expect(kAppLanguages.first.id, 'auto');
      expect(kAppLanguages.first.isAuto, isTrue);
      expect(appLanguageById(null).id, 'auto');
      expect(appLanguageById('inconnu').id, 'auto');
    });

    test('les identifiants sont uniques', () {
      final ids = kAppLanguages.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('toute langue explicite a un nom de prompt et une étiquette voix', () {
      for (final l in kAppLanguages.where((l) => !l.isAuto)) {
        expect(l.promptName, isNotEmpty, reason: l.id);
        expect(l.voiceTag, contains('-'), reason: l.id);
        expect(l.voiceTag.split('-').first, l.id, reason: l.id);
      }
    });

    test('la consigne auto suit l\'opérateur, la consigne forcée impose', () {
      expect(appLanguageById('auto').promptDirective,
          contains('langue du dernier message'));
      final en = appLanguageById('en').promptDirective;
      expect(en, contains('SYSTÉMATIQUEMENT en anglais'));
      expect(en, isNot(contains('langue du dernier message')));
    });

    test('les invariants de sécurité sont dans les deux modes', () {
      for (final l in [appLanguageById('auto'), appLanguageById('sw')]) {
        final d = l.promptDirective;
        expect(d, contains('Ne traduis JAMAIS'), reason: l.id);
        expect(d, contains('G54..G59'), reason: l.id);
        expect(d, contains('alarme'), reason: l.id);
        // Le G-code garde le point décimal quelle que soit la langue.
        expect(d, contains('X14.25'), reason: l.id);
      }
    });
  });
}
