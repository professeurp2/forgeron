import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/guarded_backend.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Faux fournisseur : rejoue des réponses et note les prompts reçus.
class _Scripted implements AiBackend {
  _Scripted(this.script);
  final List<AiApiResponse> script;
  final prompts = <String?>[];

  @override
  String get model => 'gemini-test';
  @override
  int get historyBudgetChars => 100000;
  @override
  bool get usesCellular => true;
  @override
  Future<bool> isReachable() async => true;
  @override
  String get unreachableMessage => '';
  @override
  void dispose() {}

  AiApiResponse _next(String? p) {
    prompts.add(p);
    return script.removeAt(0);
  }

  @override
  Future<AiApiResponse> sendMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt}) async =>
      _next(systemPrompt);

  @override
  Future<AiApiResponse> streamMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt,
          void Function(String partialText)? onDelta,
          bool Function()? shouldCancel}) async =>
      _next(systemPrompt);
}

AiApiResponse _text(String t) =>
    AiApiResponse(parts: [{'text': t}], finishReason: 'STOP');

const _contents = [
  {
    'role': 'user',
    'parts': [
      {'text': 'Donne-moi l\'état de la machine.'}
    ]
  }
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('réglage du fournisseur', () {
    test('le serveur local configuré est utilisé, sauf si l\'opérateur choisit Gemini', () {
      const local = AiAgentSettings(localBaseUrl: 'http://192.168.0.10:11434');
      expect(local.usesLocal, isTrue);
      expect(local.copyWith(preferOnline: true).usesLocal, isFalse);
      expect(const AiAgentSettings().usesLocal, isFalse, reason: 'rien de configuré : Gemini');
    });

    test('le choix est enregistré, et basculer n\'efface pas le serveur local', () {
      const s = AiAgentSettings(
          localBaseUrl: 'http://192.168.0.10:11434', preferOnline: true);
      final back = AiAgentSettings.fromJson(s.toJson());
      expect(back.preferOnline, isTrue);
      expect(back.localBaseUrl, 'http://192.168.0.10:11434');
      expect(AiAgentSettings.fromJson(const {}).preferOnline, isFalse);
    });

    test('en ligne choisi : l\'agent part bien sur Gemini malgré le serveur local', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final c = ProviderContainer(overrides: [
        machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
        lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString()),
      ]);
      addTearDown(c.dispose);
      final n = c.read(aiAgentSettingsProvider.notifier);
      n.setEnabled(true);
      n.setLocalBaseUrl('http://192.168.0.10:11434');
      n.setPreferOnline(true);

      await c.read(aiAgentControllerProvider.notifier)
          .sendUserMessage('Bonjour, que peux-tu faire ?');
      // Sans clé enregistrée, c'est l'erreur de GEMINI qui remonte : preuve
      // que le serveur local, pourtant renseigné, n'a pas été choisi.
      expect(c.read(aiAgentControllerProvider).error, contains('Gemini'));
    });
  });

  group('Gemini tient les mêmes garde-fous que le modèle local', () {
    test('dérive en chinois : redemandée avec le rappel de langue', () async {
      final inner = _Scripted([_text('La machine est讨论中 prête.'), _text('La machine est prête.')]);
      final r = await GuardedBackend(inner).streamMessages(
          contents: _contents, functionDeclarations: const [], systemPrompt: 'P');
      expect(r.text, 'La machine est prête.');
      expect(inner.prompts.last, 'P${LocalAiAgentService.languageReminder}');
      expect(r.notes, contains(LocalAiAgentService.noteLanguageRetry));
    });

    test('réponse vide : redemandée une fois', () async {
      final inner = _Scripted([
        const AiApiResponse(parts: [], finishReason: 'STOP'),
        _text('Arrêt demandé.'),
      ]);
      final r = await GuardedBackend(inner).sendMessages(
          contents: _contents, functionDeclarations: const [], systemPrompt: 'P');
      expect(r.text, 'Arrêt demandé.');
      expect(inner.prompts.last, 'P${LocalAiAgentService.emptyReminder}');
    });

    test('réponse correcte : un seul appel, rien d\'ajouté', () async {
      final inner = _Scripted([_text('Tout va bien.')]);
      final r = await GuardedBackend(inner).sendMessages(
          contents: _contents, functionDeclarations: const [], systemPrompt: 'P');
      expect(r.text, 'Tout va bien.');
      expect(inner.prompts, ['P']);
      expect(r.notes, isEmpty);
    });
  });

  test('le rappel de langue renvoie à la langue choisie, il n\'impose plus le français', () {
    expect(LocalAiAgentService.languageReminder, contains('LANGUE DE RÉPONSE'));
    expect(LocalAiAgentService.languageReminder, isNot(contains('uniquement en français')));
  });
}
