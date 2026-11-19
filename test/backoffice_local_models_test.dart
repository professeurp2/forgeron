import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/backoffice_provider.dart';
import 'package:forgeron/application/services/ollama_discovery.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un PC qui sert forgeron-qwen (outils) et gemma3n (vision, chargé en
/// mémoire) — l'atelier tel qu'il est.
http.Client _fakeOllama({Set<String> hosts = const {'localhost', '192.168.0.42'}}) =>
    MockClient((req) async {
      if (!hosts.contains(req.url.host)) throw Exception('injoignable');
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
        case '/api/ps':
          return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'gemma3n:latest', 'size': 4000000000, 'size_vram': 4000000000},
                ]
              }),
              200);
        case '/api/show':
          final model = jsonDecode(req.body)['model'] as String;
          return http.Response(
              jsonEncode({
                'capabilities':
                    model.startsWith('gemma') ? ['completion', 'vision'] : ['completion', 'tools'],
                'parameters': 'num_ctx 16384',
              }),
              200);
      }
      return http.Response('', 404);
    });

/// Le rapport des modèles locaux : qui est installé, qui est chargé, quel rôle
/// l'application lui donne — et le geste « Brancher » qui règle gemma comme
/// modèle d'images.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer c;

  ProviderContainer make({http.Client? client}) {
    final c = ProviderContainer(overrides: [
      backofficeBusProvider.overrideWith((ref) => BackofficeBus()),
      ollamaDiscoveryProvider.overrideWith(
          (ref) => OllamaDiscovery(client: client ?? _fakeOllama(), localAddresses: () async => [])),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('serveur réglé : rôles, chargement, et gemma proposé pour les images', () async {
    c = make();
    final n = c.read(aiAgentSettingsProvider.notifier);
    n.setLocalBaseUrl('http://192.168.0.42:11434');
    n.setLocalModel('forgeron-qwen');
    await Future<void>.delayed(Duration.zero);

    final r = await c.read(localModelsReportProvider.future);
    expect(r.configured, isTrue);
    expect(r.reachable, isTrue);
    expect(r.models.map((m) => m.name), ['forgeron-qwen:latest', 'gemma3n:latest']);

    final qwen = r.models.first;
    expect(qwen.role, 'pilote', reason: '« forgeron-qwen » vaut « forgeron-qwen:latest »');
    expect(qwen.isLoaded, isFalse);
    expect(qwen.model.supportsTools, isTrue);

    final gemma = r.models.last;
    expect(gemma.role, 'aucun');
    expect(gemma.model.supportsVision, isTrue);
    expect(gemma.isLoaded, isTrue);
    expect(gemma.loaded!.gpuShare, 1.0);
    expect(gemma.canWireForImages, isTrue);
    expect(r.wirableForImages.map((m) => m.name), ['gemma3n:latest']);
    expect(r.pilotMissing, isFalse);
    expect(r.visionMissing, isFalse);
  });

  test('brancher gemma : réglage posé, tracé comme un réglage, rapport refait', () async {
    c = make();
    final n = c.read(aiAgentSettingsProvider.notifier);
    n.setLocalBaseUrl('http://192.168.0.42:11434');
    n.setLocalModel('forgeron-qwen');
    await Future<void>.delayed(Duration.zero);
    final r = await c.read(localModelsReportProvider.future);

    c.read(localModelsWiringProvider).wireForImages(r, r.wirableForImages.single);

    expect(c.read(aiAgentSettingsProvider).localVisionModel, 'gemma3n:latest');
    expect(c.read(aiAgentSettingsProvider).localModel, 'forgeron-qwen',
        reason: 'le pilote installé n\'est pas touché');
    final e = c.read(backofficeBusProvider).single;
    expect(e.kind, 'systeme.reglage');
    expect(e.source, BackofficeSource.systeme);
    expect(e.details['modele_images'], 'gemma3n:latest');

    final again = await c.read(localModelsReportProvider.future);
    expect(again.models.last.role, 'images');
    expect(again.wirableForImages, isEmpty);
  });

  test('aucun serveur réglé : le PC lui-même est interrogé, et « Brancher » règle tout',
      () async {
    c = make();
    final r = await c.read(localModelsReportProvider.future);
    expect(r.configured, isFalse);
    expect(r.url, 'http://localhost:11434');
    expect(r.reachable, isTrue);
    expect(r.models.map((m) => m.role), everyElement('aucun'),
        reason: 'rien n\'est branché tant que l\'opérateur ne le dit pas');

    c.read(localModelsWiringProvider).wireForImages(r, r.wirableForImages.single);

    final s = c.read(aiAgentSettingsProvider);
    expect(s.localBaseUrl, 'http://localhost:11434');
    expect(s.localVisionModel, 'gemma3n:latest');
    expect(s.localModel, defaultLocalModel,
        reason: 'le pilote par défaut est installé : il reste');
    final e = c.read(backofficeBusProvider).single;
    expect('${e.details['changements']}', contains('serveur'));
  });

  test('modèle réglé mais absent du serveur : signalé, pas inventé', () async {
    c = make();
    final n = c.read(aiAgentSettingsProvider.notifier);
    n.setLocalBaseUrl('http://192.168.0.42:11434');
    n.setLocalModel('qwen3:14b');
    n.setLocalVisionModel('llava:latest');
    await Future<void>.delayed(Duration.zero);
    final r = await c.read(localModelsReportProvider.future);
    expect(r.pilotMissing, isTrue);
    expect(r.visionMissing, isTrue);
    expect(r.models.map((m) => m.role), everyElement('aucun'));
  });

  test('serveur injoignable : rapport honnête, aucune exception', () async {
    c = make(client: _fakeOllama(hosts: const {}));
    c.read(aiAgentSettingsProvider.notifier).setLocalBaseUrl('http://192.168.0.42:11434');
    await Future<void>.delayed(Duration.zero);
    final r = await c.read(localModelsReportProvider.future);
    expect(r.reachable, isFalse);
    expect(r.models, isEmpty);
    expect(r.wirableForImages, isEmpty);
  });
}
