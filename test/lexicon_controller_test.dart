import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/command_understanding.dart' show isReadOnlyToolName;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Faux modèle : rejoue des réponses scriptées et note les outils déclarés.
class _FakeBackend implements AiBackend {
  _FakeBackend(this.modelId, this.script);
  final String modelId;
  final List<AiApiResponse> script;
  final List<List<String>> declared = [];

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

  AiApiResponse _next(List<Map<String, dynamic>> decl) {
    declared.add([for (final d in decl) '${d['name']}']);
    return script.isEmpty
        ? const AiApiResponse(
            parts: [
              {'text': 'ok'}
            ],
            finishReason: 'STOP')
        : script.removeAt(0);
  }

  @override
  Future<AiApiResponse> sendMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt}) async =>
      _next(functionDeclarations);

  @override
  Future<AiApiResponse> streamMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt,
          void Function(String partialText)? onDelta,
          bool Function()? shouldCancel}) async =>
      _next(functionDeclarations);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMachineRepository repo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeMachineRepository();
    container = ProviderContainer(overrides: [
      machineRepositoryProvider.overrideWithValue(repo),
      lexiconSourceProvider.overrideWithValue(
          () async => File('assets/lexicon/lexique.json').readAsString()),
    ]);
    addTearDown(container.dispose);
  });

  AiAgentController ctl() => container.read(aiAgentControllerProvider.notifier);
  AiChatState chat() => container.read(aiAgentControllerProvider);
  String lastAssistant() =>
      chat().messages.lastWhere((m) => m.role == 'assistant').text;

  test('« état de la machine » : répondu sans modèle', () async {
    await ctl().sendUserMessage('État de la machine', allowModel: false);
    expect(chat().pendingConfirmation, isNull);
    expect(chat().isProcessing, isFalse);
    expect(lastAssistant(), contains('hors ligne'));
  });

  test('« allume la broche » : carte, puis exécution à la confirmation',
      () async {
    await ctl().sendUserMessage('Allume la broche', allowModel: false);
    final p = chat().pendingConfirmation!;
    expect(p.toolName, 'set_spindle');
    expect(p.lexicon!.isDraft, isTrue);
    expect(repo.sentGCode, isEmpty, reason: 'rien ne part avant le geste');

    await ctl().confirmPendingAction();
    expect(repo.sentGCode, ['M3 S1000']);
    expect(chat().pendingConfirmation, isNull);
    expect(lastAssistant(), contains('Broche allumée'));
  });

  test('refus de la carte : rien n\'est envoyé', () async {
    await ctl().sendUserMessage('Éteins la broche', allowModel: false);
    await ctl().rejectPendingAction();
    expect(repo.sentGCode, isEmpty);
    expect(chat().pendingConfirmation, isNull);
    expect(lastAssistant(), contains('je n\'exécute pas'));
  });

  test('déplacement : confirmé, il part avec les nombres dits', () async {
    await ctl().sendUserMessage('Déplace X de 5 mm vitesse 300', allowModel: false);
    await ctl().confirmPendingAction();
    expect(repo.jogCalls.single.$1, 'X');
    expect(repo.jogCalls.single.$2, 5.0);
    expect(repo.jogCalls.single.$3, 300.0);
  });

  test('un nouveau message abandonne l\'action en attente', () async {
    await ctl().sendUserMessage('Allume la broche', allowModel: false);
    await ctl().sendUserMessage('État de la machine', allowModel: false);
    expect(chat().pendingConfirmation, isNull);
    expect(repo.sentGCode, isEmpty);
  });

  test('arrêt dit en bambara : immédiat, sans carte', () async {
    await ctl().sendUserMessage('Mansin jɔ sisan, joona!', allowModel: false);
    expect(repo.emergencyStopCalls, 1);
    expect(chat().pendingConfirmation, isNull);
  });

  test('négation sans modèle : rien n\'agit, l\'aide l\'explique', () async {
    await ctl().sendUserMessage('Ne démarre pas la broche', allowModel: false);
    expect(repo.sentGCode, isEmpty);
    expect(chat().pendingConfirmation, isNull);
    expect(lastAssistant(), contains('négatives'));
  });

  test('lexique coupé : aucun traitement (comportement d\'avant)', () async {
    container.read(aiAgentSettingsProvider.notifier).setLexiconEnabled(false);
    await ctl().sendUserMessage('Allume la broche', allowModel: false);
    expect(chat().pendingConfirmation, isNull);
    expect(chat().messages, isEmpty);
  });

  test('lexique invalide : indisponible, pas de plantage', () async {
    final c = ProviderContainer(overrides: [
      machineRepositoryProvider.overrideWithValue(repo),
      lexiconSourceProvider.overrideWithValue(() async => '{"schema": 1}'),
    ]);
    addTearDown(c.dispose);
    expect((await c.read(lexiconLoadProvider.future)).available, isFalse);
    expect(c.read(lexiconUsableProvider), isFalse);
  });

  group('modèle pour les images', () {
    test('réglage : enregistré et relu', () {
      const s = AiAgentSettings(localVisionModel: 'gemma3n:latest');
      expect(AiAgentSettings.fromJson(s.toJson()).localVisionModel, 'gemma3n:latest');
      expect(AiAgentSettings.fromJson(const {}).localVisionModel, isEmpty);
    });

    test('un message avec image va au modèle d\'images, sans outils ; le texte, au principal', () async {
      final main = _FakeBackend(container.read(aiModelProvider).active.id, []);
      final vision = _FakeBackend('gemma3n:latest', [
        const AiApiResponse(parts: [{'text': 'Je vois une pièce.'}], finishReason: 'STOP'),
      ]);
      ctl().debugUseBackend(main);
      ctl().debugUseVisionBackend(vision);

      await ctl().sendUserMessage('Que vois-tu sur cette photo ?',
          imageBytes: Uint8List.fromList([1, 2, 3]));
      expect(vision.declared, hasLength(1));
      expect(vision.declared.single, isEmpty, reason: 'il décrit, il n\'agit pas');
      expect(main.declared, isEmpty);
      expect(lastAssistant(), 'Je vois une pièce.');

      await ctl().sendUserMessage('Bonjour, peux-tu analyser mon fichier ?');
      expect(main.declared, hasLength(1));
      expect(main.declared.single, contains('set_spindle'));
      expect(vision.declared, hasLength(1), reason: 'pas de nouvel appel au modèle d\'images');
    });
  });

  group('avec un modèle', () {
    _FakeBackend backend(List<AiApiResponse> script) {
      final b = _FakeBackend(container.read(aiModelProvider).active.id, script);
      ctl().debugUseBackend(b);
      return b;
    }

    const spindleCall = AiApiResponse(parts: [
      {
        'functionCall': {
          'name': 'set_spindle',
          'args': {'state': 'cw'}
        }
      }
    ], finishReason: 'STOP');

    test('négation : le modèle n\'a que la lecture, et son appel est bloqué',
        () async {
      final b = backend([spindleCall]);
      await ctl().sendUserMessage('Ne démarre pas la broche');
      expect(b.declared.first, isNotEmpty);
      expect(b.declared.first.every(isReadOnlyToolName), isTrue,
          reason: '${b.declared.first}');
      expect(repo.sentGCode, isEmpty);
      expect(chat().pendingConfirmation, isNull,
          reason: 'l\'appel interdit n\'arrive même pas à la confirmation');
    });

    test('message ordinaire : le modèle garde tous ses outils', () async {
      final b = backend([]);
      await ctl().sendUserMessage('Bonjour, peux-tu analyser mon fichier ?');
      expect(b.declared.first, contains('set_spindle'));
    });

    test('ordre compris : le modèle n\'est pas appelé', () async {
      final b = backend([]);
      await ctl().sendUserMessage('Allume la broche');
      expect(b.declared, isEmpty);
      expect(chat().pendingConfirmation, isNotNull);
    });
  });
}
