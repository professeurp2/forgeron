import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/ai_preflight_provider.dart';
import 'package:forgeron/application/providers/backoffice_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/ollama_discovery.dart';
import 'package:forgeron/core/utils/gcode_provenance.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Faux modèle : rejoue un script, ou lève [failure] à chaque appel.
class _Backend implements AiBackend {
  _Backend(this.model, this.script, {this.failure, this.cellular = false});
  final List<AiApiResponse> script;
  final Object? failure;
  final bool cellular;
  int calls = 0;

  @override
  final String model;
  @override
  int get historyBudgetChars => 100000;
  @override
  bool get usesCellular => cellular;
  @override
  Future<bool> isReachable() async => failure == null;
  @override
  String get unreachableMessage => 'serveur injoignable';
  @override
  void dispose() {}

  AiApiResponse _next() {
    calls++;
    if (failure != null) throw failure!;
    return script.isEmpty
        ? const AiApiResponse(parts: [
            {'text': 'Voilà.'}
          ], finishReason: 'STOP')
        : script.removeAt(0);
  }

  @override
  Future<AiApiResponse> sendMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt}) async =>
      _next();

  @override
  Future<AiApiResponse> streamMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt,
          void Function(String partialText)? onDelta,
          bool Function()? shouldCancel}) async =>
      _next();
}

AiApiResponse _call(String name, Map<String, dynamic> args) => AiApiResponse(parts: [
      {
        'functionCall': {'name': name, 'args': args}
      }
    ], finishReason: 'STOP');

AiApiResponse _say(String text) => AiApiResponse(parts: [
      {'text': text}
    ], finishReason: 'STOP');

Future<void> _until(bool Function() ok, {String? what}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) fail('délai dépassé : ${what ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Un PC qui sert le pilote (outils) et gemma (vision).
http.Client _ollama({bool up = true, bool pilotTools = true, int ctx = 16384}) =>
    MockClient((req) async {
      if (!up) throw const SocketException('injoignable');
      switch (req.url.path) {
        case '/api/tags':
          return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'forgeron-qwen:latest'},
                  {'name': 'gemma3n:latest'},
                ]
              }),
              200);
        case '/api/show':
          final model = jsonDecode(req.body)['model'] as String;
          final gemma = model.startsWith('gemma');
          return http.Response(
              jsonEncode({
                'capabilities': gemma
                    ? ['completion', 'vision']
                    : ['completion', if (pilotTools) 'tools'],
                'parameters': 'num_ctx $ctx',
              }),
              200);
        case '/api/ps':
          return http.Response(jsonEncode({'models': []}), 200);
      }
      return http.Response('', 404);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Provenance : la règle « jamais de G-code écrit par le modèle » ────────

  group('GcodeProvenance', () {
    const operator = 'Lance ça :\nG21 G90\nG0 X0 Y0 Z5\nG1 X10 Y0 Z-1 F300\nM30';

    test('un programme recopié de l\'opérateur est entièrement sourcé', () {
      const program = 'g21 g90\nN10 G0 X0 Y0 Z5 ; approche\nG1 X10  Y0 Z-1 F300\nM30';
      expect(GcodeProvenance.unsourced(program, [operator]), isEmpty,
          reason: 'casse, espaces, numéros de ligne et commentaires ne comptent pas');
    });

    test('une seule cote changée suffit à refuser, avec son numéro de ligne', () {
      const program = 'G21 G90\nG0 X0 Y0 Z5\nG1 X10 Y0 Z-2 F300\nM30';
      final missing = GcodeProvenance.unsourced(program, [operator]);
      expect(missing, hasLength(1));
      expect(missing.single.$1, 3);
      expect(missing.single.$2, 'G1 X10 Y0 Z-2 F300');
    });

    test('les lignes sans cote (M3, G21, M30) n\'ont pas à être sourcées', () {
      expect(GcodeProvenance.unsourced('G21\nG90\nM3 S1000\nM5\nM30', const []), isEmpty);
      expect(GcodeProvenance.isMotion('M3 S1000'), isFalse);
      expect(GcodeProvenance.isMotion('G1 X10'), isTrue);
      expect(GcodeProvenance.isMotion('(X10 en commentaire)'), isFalse);
    });

    test('un résultat d\'outil en JSON (\\n échappés) est une source', () {
      final tool = jsonEncode({'contenu': 'G0 X5 Y5\nG1 Z-0.5 F100'});
      expect(GcodeProvenance.unsourced('G0 X5 Y5\nG1 Z-0.5 F100', [tool]), isEmpty);
    });

    test('un bloc écrit par le modèle est repéré', () {
      expect(GcodeProvenance.hasUnsourcedBlock(['G81 X10 Y10 Z-0.5 R1 F100'], [operator]), isTrue);
      expect(GcodeProvenance.hasUnsourcedBlock(['G0 X0 Y0 Z5'], [operator]), isFalse);
    });
  });

  // ── Contrôleur : garde de provenance, marquage, bascule de secours ────────

  group('contrôleur', () {
    late FakeMachineRepository repo;
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = FakeMachineRepository();
      c = ProviderContainer(overrides: [
        machineRepositoryProvider.overrideWithValue(repo),
        backofficeBusProvider.overrideWith((ref) => BackofficeBus()),
        lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString()),
      ]);
      addTearDown(c.dispose);
      await c.read(lexiconLoadProvider.future);
    });

    AiAgentController ctl() => c.read(aiAgentControllerProvider.notifier);
    AiChatState chat() => c.read(aiAgentControllerProvider);
    List<BackofficeEvent> events() => c.read(backofficeBusProvider);
    _Backend main(List<AiApiResponse> script) =>
        _Backend(c.read(aiModelProvider).active.id, script);

    test('un programme inventé par le modèle est refusé AVANT la carte de confirmation',
        () async {
      ctl().debugUseBackend(main([
        _call('run_gcode_program', const {'gcode': 'G21 G90\nG0 X0 Y0 Z5\nG81 X10 Y10 Z-0.5 R1 F100\nM30'}),
        _say('Je ne peux pas écrire ce programme moi-même.'),
      ]));
      await ctl().sendUserMessage('Peux-tu me faire un perçage de test dans la grille ?');
      await _until(() => !chat().isProcessing, what: 'fin du tour');

      expect(chat().pendingConfirmation, isNull,
          reason: 'on ne demande pas à l\'opérateur d\'approuver un programme inventé');
      expect(repo.sentGCode, isEmpty);
      final garde = events().singleWhere((e) => e.kind == 'garde.provenance');
      expect(garde.source, BackofficeSource.garde);
      // « G0 X0 Y0 Z5 » et le cycle G81 : deux lignes à cotes, aucune fournie.
      expect(garde.details['lignes_inventees'], 2);
      expect(events().where((e) => e.kind == 'ia.outil.attente'), isEmpty);
    });

    test('le programme que l\'opérateur a collé passe jusqu\'à la confirmation', () async {
      const program = 'G21 G90\nG0 X0 Y0 Z5\nG1 X10 Y0 Z-1 F300\nM30';
      ctl().debugUseBackend(main([
        _call('run_gcode_program', const {'gcode': program}),
      ]));
      await ctl().sendUserMessage('Peux-tu exécuter exactement ceci pour moi :\n$program');
      await _until(() => chat().pendingConfirmation != null, what: 'carte de confirmation');
      expect(chat().pendingConfirmation!.toolName, 'run_gcode_program');
      expect(events().where((e) => e.kind == 'garde.provenance'), isEmpty);
    });

    test('un bloc G-code écrit dans la réponse est marqué « non vérifié »', () async {
      ctl().debugUseBackend(main([
        _say('Voici un programme :\n```gcode\nG0 X0 Y0\nG1 X25 Y0 Z-2 F200\n```'),
      ]));
      await ctl().sendUserMessage('Peux-tu me proposer quelque chose pour surfacer la pièce ?');
      await _until(() => !chat().isProcessing);

      final reply = chat().messages.lastWhere((m) => m.role == 'assistant');
      expect(reply.unverifiedGcode, isTrue);
      expect(events().where((e) => e.kind == 'garde.gcode_invente'), hasLength(1));
      // Le drapeau survit à l'enregistrement de la discussion.
      expect(AiChatMessage.fromJson(reply.toJson()).unverifiedGcode, isTrue);
    });

    test('un bloc qui recopie l\'opérateur n\'est PAS marqué', () async {
      ctl().debugUseBackend(main([
        _say('Tu m\'as donné :\n```gcode\nG1 X10 Y0 Z-1 F300\n```\nC\'est une passe droite.'),
      ]));
      await ctl().sendUserMessage('Peux-tu m\'expliquer cette ligne de programme ? G1 X10 Y0 Z-1 F300');
      await _until(() => !chat().isProcessing);
      expect(chat().messages.lastWhere((m) => m.role == 'assistant').unverifiedGcode, isFalse);
    });

    test('secours coupé (défaut) : serveur injoignable → attente, rien ne part ailleurs',
        () async {
      final down = _Backend(c.read(aiModelProvider).active.id, [],
          failure: const SocketException('Connection refused'));
      final cloud = _Backend('gemini-secours', [_say('Réponse du secours.')], cellular: true);
      ctl().debugUseBackend(down);
      ctl().debugUseFallbackBackend(cloud);

      await ctl().sendUserMessage('Peux-tu me dire comment va la fraiseuse aujourd\'hui ?');
      await _until(() => chat().error != null, what: 'erreur affichée');
      expect(cloud.calls, 0, reason: 'sans accord explicite, la discussion ne sort pas');
      expect(chat().retryable, isTrue);
      expect(events().where((e) => e.kind == 'ia.bascule'), isEmpty);
      ctl().stopGeneration();
    });

    test('secours activé : le tour part chez Gemini, et c\'est dit dans le fil', () async {
      c.read(aiAgentSettingsProvider.notifier).setCloudFallback(true);
      final down = _Backend(c.read(aiModelProvider).active.id, [],
          failure: const SocketException('Connection refused'));
      final cloud = _Backend('gemini-secours', [_say('Réponse du secours.')], cellular: true);
      ctl().debugUseBackend(down);
      ctl().debugUseFallbackBackend(cloud);

      await ctl().sendUserMessage('Peux-tu me dire comment va la fraiseuse aujourd\'hui ?');
      await _until(() => chat().messages.any((m) => m.text == 'Réponse du secours.'),
          what: 'réponse du secours');

      expect(cloud.calls, 1);
      expect(chat().error, isNull);
      final note = chat().messages.singleWhere((m) => m.toolName == 'bascule_secours');
      expect(note.toolResult, contains('gemini-secours'));
      final e = events().singleWhere((e) => e.kind == 'ia.bascule');
      expect(e.severity, BackofficeSeverity.warning);
      expect(e.details['vers'], 'gemini-secours');
      // Le tour du secours est tracé à son nom.
      expect(events().where((e) => e.kind == 'ia.tour').last.details['modele'], 'gemini-secours');
    });

    test('le réglage du secours est enregistré et relu', () {
      expect(const AiAgentSettings().cloudFallback, isFalse);
      const s = AiAgentSettings(cloudFallback: true);
      expect(AiAgentSettings.fromJson(s.toJson()).cloudFallback, isTrue);
      expect(AiAgentSettings.fromJson(const {}).cloudFallback, isFalse);
    });
  });

  // ── Pré-vol ───────────────────────────────────────────────────────────────

  group('pré-vol', () {
    ProviderContainer make({
      http.Client? client,
      bool? hasKey = true,
      bool? cloudNet = true,
      MachineState machine = const MachineState(status: MachineStatus.idle),
    }) {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(overrides: [
        machineRepositoryProvider.overrideWithValue(FakeMachineRepository(current: machine)),
        ollamaDiscoveryProvider.overrideWith(
            (ref) => OllamaDiscovery(client: client ?? _ollama(), localAddresses: () async => [])),
        aiApiKeyProbeProvider.overrideWithValue(() async => hasKey),
        aiCloudNetworkProbeProvider.overrideWithValue(() async => cloudNet),
        lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<AiPreflightReport> run(ProviderContainer c) async {
      await c.read(lexiconLoadProvider.future);
      await Future<void>.delayed(Duration.zero);
      return c.read(aiPreflightProvider.future);
    }

    void local(ProviderContainer c, {String vision = ''}) {
      final n = c.read(aiAgentSettingsProvider.notifier);
      n.setEnabled(true);
      n.setLocalBaseUrl('http://192.168.0.42:11434');
      n.setLocalModel('forgeron-qwen');
      n.setLocalVisionModel(vision);
    }

    test('chaîne locale complète : prêt, aucun point bloquant', () async {
      final c = make();
      local(c, vision: 'gemma3n:latest');
      final r = await run(c);
      expect(r.ready, isTrue, reason: r.checks.map((x) => '${x.id}:${x.status.name}').join(' '));
      expect(r.byId('fournisseur')!.status, PreflightStatus.ok);
      expect(r.byId('modele')!.detail, contains('16384'));
      expect(r.byId('outils')!.status, PreflightStatus.ok);
      expect(r.byId('images')!.status, PreflightStatus.ok);
      expect(r.byId('lexique')!.status, PreflightStatus.ok);
      expect(r.byId('machine')!.status, PreflightStatus.ok);
      expect(r.byId('secours')!.status, PreflightStatus.skipped);
      expect(r.worst, PreflightStatus.ok);
    });

    test('gemma installé mais pas branché : averti, avec le geste qui corrige', () async {
      final c = make();
      local(c);
      final r = await run(c);
      final images = r.byId('images')!;
      expect(images.status, PreflightStatus.warning);
      expect(images.fix, contains('gemma3n:latest'));
      expect(images.fix, contains('BRANCHER'));
      expect(r.ready, isTrue, reason: 'une limite, pas un blocage');
    });

    test('serveur local éteint : bloquant, et le secours dit s\'il couvre', () async {
      final c = make(client: _ollama(up: false));
      local(c);
      var r = await run(c);
      expect(r.ready, isFalse);
      expect(r.byId('fournisseur')!.status, PreflightStatus.failed);
      expect(r.byId('fournisseur')!.fix, contains('Lance Ollama'));

      c.read(aiAgentSettingsProvider.notifier).setCloudFallback(true);
      await Future<void>.delayed(Duration.zero);
      r = await c.read(aiPreflightProvider.future);
      expect(r.byId('fournisseur')!.fix, contains('secours Gemini'));
      expect(r.byId('secours')!.status, PreflightStatus.ok);
    });

    test('contexte trop court : le modèle est refusé avant la première question', () async {
      final c = make(client: _ollama(ctx: 4096));
      local(c);
      final r = await run(c);
      expect(r.byId('fournisseur')!.status, PreflightStatus.ok, reason: 'le serveur, lui, répond');
      expect(r.byId('modele')!.status, PreflightStatus.failed);
      expect(r.byId('modele')!.detail, contains('contexte trop court'));
    });

    test('Gemini sans clé ni serveur local : bloquant', () async {
      final c = make(hasKey: false);
      c.read(aiAgentSettingsProvider.notifier).setEnabled(true);
      final r = await run(c);
      expect(r.ready, isFalse);
      expect(r.byId('fournisseur')!.status, PreflightStatus.failed);
      expect(r.byId('images')!.status, PreflightStatus.ok);
    });

    test('ce qui n\'est pas vérifiable est dit « non vérifiable », jamais « ok »', () async {
      final c = make(hasKey: null, cloudNet: null);
      c.read(aiAgentSettingsProvider.notifier).setEnabled(true);
      final r = await run(c);
      expect(r.byId('fournisseur')!.status, PreflightStatus.skipped);
      expect(r.byId('reseau')!.status, PreflightStatus.skipped);
    });

    test('carte hors ligne ou en alarme : l\'agent répond mais est averti', () async {
      var c = make(machine: const MachineState(status: MachineStatus.offline));
      local(c, vision: 'gemma3n:latest');
      expect((await run(c)).byId('machine')!.status, PreflightStatus.warning);

      c = make(machine: const MachineState(status: MachineStatus.alarm));
      local(c, vision: 'gemma3n:latest');
      final m = (await run(c)).byId('machine')!;
      expect(m.status, PreflightStatus.warning);
      expect(m.detail, contains('ALARME'));
    });

    test('agent désactivé : averti, le lexique reste', () async {
      final c = make();
      final r = await run(c);
      expect(r.byId('agent')!.status, PreflightStatus.warning);
    });
  });
}
