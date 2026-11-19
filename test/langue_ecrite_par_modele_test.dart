import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Règle générale qui remplace les filtres de sortie au cas par cas (5 nov.
/// 2026) : le modèle n'écrit que les langues qu'il sait écrire. Le modèle
/// local recombinait en bambara les mots du glossaire (« Dabila daminɛ.
/// Mɛnɛ, masini cogoya fo in ye. Joona joona. ») ; un filtre qui cherchait
/// ces phrases précises ne rattrapait que celles-là.
class _Backend implements AiBackend {
  _Backend(this.modelId);
  final String modelId;
  String? lastSystemPrompt;
  int calls = 0;

  @override
  String get model => modelId;
  @override
  int get historyBudgetChars => 100000;
  @override
  bool get usesCellular => false;
  @override
  Future<bool> isReachable() async => true;
  @override
  String get unreachableMessage => 'hors ligne';
  @override
  void dispose() {}

  Future<AiApiResponse> _reply(String? prompt) async {
    calls++;
    lastSystemPrompt = prompt;
    return const AiApiResponse(parts: [
      {'text': 'ok'}
    ], finishReason: 'STOP');
  }

  @override
  Future<AiApiResponse> sendMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt}) =>
      _reply(systemPrompt);

  @override
  Future<AiApiResponse> streamMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt,
          void Function(String partialText)? onDelta,
          bool Function()? shouldCancel}) =>
      _reply(systemPrompt);
}

/// Comme le modèle local : n'écrit que [langues].
class _LocalBackend extends _Backend implements WritesLanguages {
  _LocalBackend(super.modelId, this.langues);
  final Set<String> langues;
  @override
  bool writesLanguage(String languageId) => langues.contains(languageId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  String id() => c.read(aiModelProvider).active.id;
  Future<void> langue(String code) =>
      c.read(appLanguageProvider.notifier).select(appLanguageById(code));
  String? cible(_Backend b) =>
      LocalAiAgentService.targetLanguageFromPrompt(b.lastSystemPrompt);

  group('langue que le modèle sait écrire', () {
    const question = "C'est quoi le homing et pourquoi il faut le faire ?";

    test('modèle local, bambara choisi : il comprend, répond en français '
        'simple', () async {
      await langue('bm');
      final b = _LocalBackend(id(), LocalAiAgentService.defaultWrittenLanguages);
      ctl().debugUseBackend(b);
      await ctl().sendUserMessage(question);
      expect(b.calls, greaterThan(0));
      expect(b.lastSystemPrompt, contains('FRANÇAIS SIMPLE'));
      expect(cible(b), 'fr');
      expect(b.lastSystemPrompt, isNot(contains('Réponds en bambara')));
    });

    test('Gemini (ne déclare rien), bambara choisi : répond en bambara',
        () async {
      await langue('bm');
      final b = _Backend(id());
      ctl().debugUseBackend(b);
      await ctl().sendUserMessage(question);
      expect(cible(b), 'bm');
      expect(b.lastSystemPrompt, isNot(contains('FRANÇAIS SIMPLE')));
    });

    test('automatique : un message en swahili au modèle local → français '
        'simple', () async {
      final b = _LocalBackend(id(), LocalAiAgentService.defaultWrittenLanguages);
      ctl().debugUseBackend(b);
      // Phrase du banc de conversation, reconnue comme du swahili.
      await ctl().sendUserMessage('Hali ya mashine ikoje sasa hivi?');
      expect(cible(b), 'fr');
      expect(b.lastSystemPrompt, contains('FRANÇAIS SIMPLE'));
    });

    test('automatique : l\'arabe, que le modèle local écrit, reste en arabe',
        () async {
      final b = _LocalBackend(id(), LocalAiAgentService.defaultWrittenLanguages);
      ctl().debugUseBackend(b);
      await ctl().sendUserMessage('ما هو الـ homing ولماذا يجب القيام به؟');
      expect(cible(b), 'ar');
    });

    test('un modèle entraîné qui déclare le bambara le reçoit', () async {
      await langue('bm');
      final b = _LocalBackend(id(), {'fr', 'en', 'bm'});
      ctl().debugUseBackend(b);
      await ctl().sendUserMessage(question);
      expect(cible(b), 'bm');
    });
  });

  group('formules sociales : seulement les messages qui n\'en contiennent '
      'pas d\'autre', () {
    String last() => c
        .read(aiAgentControllerProvider)
        .messages
        .lastWhere((m) => m.role == 'assistant',
            orElse: () => AiChatMessage(
                role: 'assistant', text: '', timestamp: DateTime.now()))
        .text;

    Future<_Backend> envoie(String text) async {
      final b = _Backend(id());
      ctl().debugUseBackend(b);
      await ctl().sendUserMessage(text);
      return b;
    }

    test('« Bonjour ! » : réponse fixe, sans modèle', () async {
      final b = await envoie('Bonjour !');
      expect(b.calls, 0);
      expect(last(), startsWith('Bonjour !'));
    });

    test('« I ni ce » : réponse fixe en bambara', () async {
      final b = await envoie('I ni ce');
      expect(b.calls, 0);
      expect(last(), startsWith('I ni ce !'));
    });

    test('« Hi, what can you help me with? » : capacités, en anglais',
        () async {
      final b = await envoie('Hi, what can you help me with?');
      expect(b.calls, 0);
      expect(last(), startsWith('I can help you with'));
    });

    // Avant le 5 nov. 2026, ces messages recevaient « Bonjour ! … » ou
    // « Avec plaisir ! » et l'ordre ou la question étaient perdus.
    for (final m in [
      'Bonjour, allume la broche à 8000 tours',
      'Merci, maintenant lance le homing',
      "J'ai besoin d'aide, la broche fait un bruit bizarre",
      'Bonjour, quel est l\'état de la machine ?',
    ]) {
      test('« $m » n\'est pas une politesse', () async {
        final b = await envoie(m);
        final st = c.read(aiAgentControllerProvider);
        // Atteint le modèle, ou le lexique (carte, ou lecture faite d'office).
        expect(
            b.calls > 0 ||
                st.pendingConfirmation != null ||
                st.messages.any((m) => m.role == 'tool'),
            isTrue,
            reason: 'le message doit atteindre le lexique ou le modèle');
        expect(last(), isNot(startsWith('Bonjour ! Forgeron IA')));
        expect(last(), isNot(startsWith('Avec plaisir')));
        expect(last(), isNot(startsWith('Je peux vous aider à')));
      });
    }
  });

  test('plus de filtre « salade de mots » par phrases connues', () {
    // La phrase de la capture d'écran du 5 nov. passe telle quelle dans le
    // nettoyage des boucles : elle n'est plus remplacée par un texte français
    // écrit en dur. La prévention est en amont (langue écrite par le modèle).
    const salade = 'Dabila daminɛ. Mɛnɛ, masini cogoya fo in ye. Joona joona.';
    expect(LocalAiAgentService.cleanRepetitiveDegeneration(salade), salade);
  });
}
