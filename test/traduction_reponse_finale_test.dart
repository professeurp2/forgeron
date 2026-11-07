import 'dart:convert';
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
import 'package:forgeron/application/services/local_translator.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Pilote local qui n'écrit que fr/en/ar et répond toujours [reply].
class _Pilot implements AiBackend, WritesLanguages {
  _Pilot(this.model, this.reply);
  @override
  final String model;
  final String reply;
  List<Map<String, dynamic>> lastContents = const [];

  @override
  bool writesLanguage(String id) =>
      LocalAiAgentService.defaultWrittenLanguages.contains(id);
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

  Future<AiApiResponse> _r(List<Map<String, dynamic>> contents) async {
    lastContents = List.of(contents);
    return AiApiResponse(parts: [
      {'text': reply}
    ], finishReason: 'STOP');
  }

  @override
  Future<AiApiResponse> sendMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt}) =>
      _r(contents);

  @override
  Future<AiApiResponse> streamMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt,
          void Function(String partialText)? onDelta,
          bool Function()? shouldCancel}) =>
      _r(contents);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer c;
  late int translatorCalls;

  setUp(() async {
    translatorCalls = 0;
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
  Future<void> langue(String code) =>
      c.read(appLanguageProvider.notifier).select(appLanguageById(code));

  LocalTranslator translator(String answer) => LocalTranslator(
        baseUrl: 'http://pc:11434',
        model: 'gemma3:12b',
        clientFactory: () => MockClient((req) async {
          translatorCalls++;
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'message': {'content': answer}
              })),
              200);
        }),
      );

  /// Laisse finir la traduction lancée en arrière-plan.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  AiChatMessage lastReply() => c
      .read(aiAgentControllerProvider)
      .messages
      .lastWhere((m) => m.role == 'assistant');

  const question = "C'est quoi le homing et pourquoi il faut le faire ?";
  const fr = 'Le homing met les axes à leur origine. Fais-le au démarrage.';
  const sw = 'Homing huweka mihimili kwenye asili yake. Ifanye unapoanza.';

  test('swahili choisi : la réponse française est remplacée par la '
      'traduction, le français reste joint', () async {
    await langue('sw');
    final pilot = _Pilot(c.read(aiModelProvider).active.id, fr);
    ctl()
      ..debugUseBackend(pilot)
      ..debugUseTranslator(translator(sw));
    await ctl().sendUserMessage(question);
    await settle();
    final m = lastReply();
    expect(translatorCalls, 1);
    expect(m.text, sw);
    expect(m.sourceText, fr);
    expect(m.isMachineTranslated, isTrue);
    // Persistance : le français d'origine survit au rechargement.
    expect(AiChatMessage.fromJson(m.toJson()).sourceText, fr);
  });

  test('le pilote relit son français, pas la traduction', () async {
    await langue('sw');
    final pilot = _Pilot(c.read(aiModelProvider).active.id, fr);
    ctl()
      ..debugUseBackend(pilot)
      ..debugUseTranslator(translator(sw));
    await ctl().sendUserMessage(question);
    await settle();
    await ctl().sendUserMessage('Na baada ya hapo?');
    await settle();
    final history = jsonEncode(pilot.lastContents);
    expect(history, contains('Le homing met les axes'));
    expect(history, isNot(contains('Homing huweka')));
  });

  test('traduction qui change un nombre : le français reste affiché',
      () async {
    await langue('sw');
    final pilot =
        _Pilot(c.read(aiModelProvider).active.id, 'Je descends Z de -5 mm.');
    ctl()
      ..debugUseBackend(pilot)
      ..debugUseTranslator(translator('Ninashusha Z kwa 5 mm.'));
    await ctl().sendUserMessage('Shusha Z milimita tano');
    await settle();
    final m = lastReply();
    expect(m.text, 'Je descends Z de -5 mm.');
    expect(m.sourceText, isNull);
  });

  test('haoussa (retiré au banc) et arabe (écrit par le pilote) : pas de '
      'traduction', () async {
    for (final code in ['ha', 'ar']) {
      await langue(code);
      final pilot = _Pilot(c.read(aiModelProvider).active.id, fr);
      ctl()
        ..debugUseBackend(pilot)
        ..debugUseTranslator(translator(sw));
      await ctl().sendUserMessage(question);
      await settle();
      expect(lastReply().sourceText, isNull, reason: code);
    }
    expect(translatorCalls, 0);
  });

  test('français choisi : jamais de traduction', () async {
    await langue('fr');
    ctl()
      ..debugUseBackend(_Pilot(c.read(aiModelProvider).active.id, fr))
      ..debugUseTranslator(translator(sw));
    await ctl().sendUserMessage(question);
    await settle();
    expect(translatorCalls, 0);
    expect(lastReply().text, fr);
  });
}
