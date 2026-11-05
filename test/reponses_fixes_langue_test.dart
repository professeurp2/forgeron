import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Les phrases fixes de l'assistant (lexique, état machine, arrêt d'urgence)
/// répondent dans la langue de l'OPÉRATEUR, pas dans celle de l'interface.
///
/// Banc de conversation du 5 nov. 2026 : un opérateur qui écrivait « Home all
/// axes please » sur un téléphone en français recevait « Homing lancé… », et
/// ces phrases n'étaient traduites dans aucune langue (absentes du catalogue).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
      lexiconSourceProvider.overrideWithValue(
          () async => File('assets/lexicon/lexique.json').readAsString()),
    ]);
    addTearDown(container.dispose);
    await container.read(lexiconLoadProvider.future);
    // Téléphone réglé en français : c'est la table de l'interface.
    await AppLocalizations.delegate.load(const Locale('fr'));
  });

  AiAgentController ctl() => container.read(aiAgentControllerProvider.notifier);
  String lastAssistant() => container
      .read(aiAgentControllerProvider)
      .messages
      .lastWhere((m) => m.role == 'assistant')
      .text;

  Future<void> say(String text) async {
    await ctl().sendUserMessage(text, allowModel: false);
    if (container.read(aiAgentControllerProvider).pendingConfirmation !=
        null) {
      await ctl().confirmPendingAction();
    }
  }

  group('mode automatique, interface en français', () {
    test('un ordre en anglais reçoit une réponse en anglais', () async {
      await say('Home all axes please');
      expect(lastAssistant(), startsWith('Homing started'));
    });

    test("l'état de la machine, demandé en anglais", () async {
      await say('What is the machine state right now?');
      expect(lastAssistant(), 'Machine offline: no reading available.');
    });

    test('demandé en français : réponse en français', () async {
      await say('État de la machine');
      expect(lastAssistant(), 'Machine hors ligne : aucune lecture disponible.');
    });

    // Le lexique ne connaît pas (encore) le swahili : sans modèle, l'aide
    // qu'il renvoie doit au moins être dans la langue de l'opérateur.
    test('en swahili, sans modèle : l\'aide est en swahili', () async {
      await say('Hali ya mashine ikoje sasa hivi?');
      expect(lastAssistant(), startsWith('Msaidizi wa AI umezimwa'));
      expect(lastAssistant(), contains('Sijaelewa.'));
    });

    test("la table de l'interface est rendue après la réponse", () async {
      await say('What is the machine state right now?');
      expect(tr('Machine hors ligne : aucune lecture disponible.'),
          'Machine hors ligne : aucune lecture disponible.');
    });
  });

  test('langue imposée : elle gagne sur la langue du message', () async {
    await container
        .read(appLanguageProvider.notifier)
        .select(appLanguageById('sw'));
    await say('État de la machine');
    expect(lastAssistant(),
        'Mashine haiko mtandaoni: hakuna usomaji unaopatikana.');
  });

  test('inLanguage : null garde la table courante, un code la remplace', () {
    AppLocalizations.setCurrentForTest(const {'Broche allumée.': 'X'});
    expect(inLanguage(null, () => tr('Broche allumée.')), 'X');
    expect(inLanguage('en', () => tr('Broche allumée.')), 'Spindle on.');
    expect(inLanguage('fr', () => tr('Broche allumée.')), 'Broche allumée.');
    expect(tr('Broche allumée.'), 'X', reason: 'table remise après coup');
  });
}
