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

/// Le chargement des discussions sauvegardées remplace state.messages en
/// finissant. Un message envoyé dès la création du contrôleur (voix au
/// lancement, synchro PC) disparaissait, question et réponse (vu le 6 nov.
/// 2026 en générant le corpus de distillation).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final langue in [null, 'fr', 'bm']) {
    test('message envoyé dès la création, langue ${langue ?? 'auto'} : '
        'il reste affiché', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(overrides: [
        machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
        lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString()),
      ]);
      addTearDown(c.dispose);
      await c.read(lexiconLoadProvider.future);
      await AppLocalizations.delegate.load(const Locale('fr'));
      if (langue != null) {
        await c
            .read(aiLanguageOverrideProvider.notifier)
            .select(appLanguageById(langue));
      }
      // Contrôleur créé ici, message envoyé dans la foulée.
      await c
          .read(aiAgentControllerProvider.notifier)
          .sendUserMessage('Bonjour !');
      final m = c.read(aiAgentControllerProvider).messages;
      expect(m.map((x) => x.role), containsAllInOrder(['user', 'assistant']));
      expect(m.first.text, 'Bonjour !');
    });
  }
}
