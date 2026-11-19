import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart'
    show AiAutonomyLevel;
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/command_understanding.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:forgeron/core/utils/command_lexicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Changer la langue de l'application par le lexique fermé, sans modèle.
///
/// Banc de conversation (5 nov. 2026) : le modèle local refusait « Passe
/// l'interface en anglais » une fois sur deux et « Mets l'application en
/// bambara » à chaque fois (« cette langue n'est pas disponible »). Une
/// demande aussi fermée n'a pas besoin d'un modèle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final lexicon = CommandLexicon.fromJsonString(
      File('assets/lexicon/lexique.json').readAsStringSync());

  group('compris par le lexique', () {
    void langue(String phrase, String code) {
      final r = lexicon.interpret(phrase);
      expect(r.match?.tool, 'set_app_language', reason: '$phrase → ${r.refusal}');
      expect(r.match!.args['language'], code, reason: phrase);
    }

    test('français', () {
      langue("Passe l'interface de l'application en anglais", 'en');
      langue("Mets l'application en bambara", 'bm');
      langue("Change la langue en wolof", 'wo');
      langue("Mets l'appli en kiswahili", 'sw');
      langue("Repasse l'interface en français", 'fr');
      langue("Passe l'application en automatique", 'auto');
      langue('Bascule en automatique', 'auto');
      langue("Peux-tu mettre l'interface en haoussa ?", 'ha');
    });

    test('anglais', () {
      langue('Switch the app interface to French please', 'fr');
      langue('Change language to Swahili', 'sw');
      langue('Set the interface to Lingala', 'ln');
      langue('Switch to phone language', 'auto');
    });

    test('bambara (mots sourcés An ka taa)', () {
      langue('Application kan yɛlɛma ka kɛ bamanankan ye', 'bm');
      langue('Application kan yelema ka ke bamanankan ye', 'bm');
      langue('Kan yɛlɛma tùbàbùkan', 'fr');
    });
  });

  group('refus prudents : le modèle reprend la main', () {
    String? refus(String phrase) => lexicon.interpret(phrase).refusal;

    test('un nom de langue dans un autre ordre', () {
      expect(refus('Allume la broche en anglais'), 'langue_inattendue');
    });
    test('pas de langue nommée', () {
      expect(refus('Change la langue'), 'manque:langue');
    });
    test('deux langues', () {
      expect(refus("Passe l'interface anglais wolof"), 'langues_multiples');
    });
    test('une question, une négation', () {
      expect(refus("Pourquoi l'interface est en anglais ?"), 'question');
      expect(refus('Ne change pas la langue en anglais'), 'negation');
    });
    // « passe » n'est PAS un verbe de changement : « ce qui se passe » faisait
    // d'une demande de capture une question, et le tour perdait ses outils
    // (régression trouvée par viewer_snapshot_and_tools_test).
    test('« ce qui se passe » ne touche à rien', () {
      expect(refus('Prends une capture du simulateur pour vérifier ce qui se '
          'passe.'), 'aucune_intention');
      expect(refus("Qu'est-ce qui se passe ?"), 'aucune_intention');
    });

    test('un nombre', () {
      expect(refus("Passe l'interface en anglais 5"), 'nombre_inattendu');
    });
  });

  test('toujours une carte de confirmation (langue brouillon, outil sans '
      'catégorie)', () {
    final d = CommandUnderstanding(lexicon,
            categoryOf: (_) => null,
            levelFor: (_) => AiAutonomyLevel.requireConfirmation)
        .decide("Passe l'interface en anglais");
    expect(d, isA<AskConfirmation>());
    expect((d as AskConfirmation).reasons,
        containsAll({ConfirmReason.draftLanguage, ConfirmReason.uncategorized}));
  });

  group('dans le contrôleur, de bout en bout', () {
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      c = ProviderContainer(overrides: [
        machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
        lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString()),
      ]);
      addTearDown(c.dispose);
      await c.read(lexiconLoadProvider.future);
      await AppLocalizations.delegate.load(const Locale('fr'));
    });

    AiAgentController ctl() => c.read(aiAgentControllerProvider.notifier);
    AiChatState chat() => c.read(aiAgentControllerProvider);
    String last() =>
        chat().messages.lastWhere((m) => m.role == 'assistant').text;

    test('« Passe l\'interface en anglais » : carte, puis anglais', () async {
      await ctl().sendUserMessage(
          "Passe l'interface de l'application en anglais",
          allowModel: false);
      final p = chat().pendingConfirmation!;
      expect(p.toolName, 'set_app_language');
      expect(p.lexicon!.label, "Changer la langue de l'interface : English");
      expect(c.read(appLanguageProvider).isAuto, isTrue,
          reason: 'rien ne change avant le geste');

      await ctl().confirmPendingAction();
      expect(c.read(appLanguageProvider).id, 'en');
      // La réponse est dans la langue qu'il vient de choisir, avec la part
      // réellement traduite.
      expect(last(), startsWith('Interface switched to English. To go back: '
          'Settings > Language.'));
      expect(last(), matches(RegExp(r'\d+ texts translated out of \d+')));
    });

    test('demandé en bambara : passe en bambara', () async {
      await ctl().sendUserMessage('Application kan yɛlɛma ka kɛ bamanankan ye',
          allowModel: false);
      expect(chat().pendingConfirmation!.toolName, 'set_app_language');
      await ctl().confirmPendingAction();
      expect(c.read(appLanguageProvider).id, 'bm');
      // Ces phrases n'existent pas (encore) en bambara relu : français.
      expect(last(), startsWith('Interface passée en Bamanankan (bambara)'));
    });

    test('refusée par l\'opérateur : la langue ne bouge pas', () async {
      await ctl().sendUserMessage("Mets l'application en wolof",
          allowModel: false);
      await ctl().rejectPendingAction();
      expect(c.read(appLanguageProvider).isAuto, isTrue);
    });

    test('déjà dans cette langue', () async {
      await c.read(appLanguageProvider.notifier).select(appLanguageById('fr'));
      await ctl().sendUserMessage("Repasse l'interface en français",
          allowModel: false);
      await ctl().confirmPendingAction();
      expect(last(), "L'interface est déjà en Français.");
    });
  });
}
