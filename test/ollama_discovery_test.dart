import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/services/ollama_discovery.dart';
import 'package:forgeron/presentation/widgets/local_server_assistant.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un « PC » à 192.168.0.42 qui sert deux modèles : un qui sait appeler des
/// outils, un qui ne sait pas (gemma3n, tel qu'installé en atelier).
http.Client _fakeNetwork({String host = '192.168.0.42', bool tools = true}) =>
    MockClient((req) async {
      if (req.url.host != host) throw Exception('injoignable');
      if (req.url.path == '/api/tags') {
        return http.Response(
            jsonEncode({
              'models': [
                {'name': 'forgeron-qwen:latest'},
                {'name': 'gemma3n:latest'},
              ]
            }),
            200);
      }
      if (req.url.path == '/api/show') {
        final model = jsonDecode(req.body)['model'] as String;
        return http.Response(
            jsonEncode({
              'capabilities': model.startsWith('gemma') ? ['completion', 'vision'] : ['completion', 'tools'],
              'parameters': 'num_ctx 12288',
            }),
            200);
      }
      return http.Response('', 404);
    });

OllamaDiscovery _discovery(http.Client c) => OllamaDiscovery(
    client: c, localAddresses: () async => ['192.168.0.7'], concurrency: 64);

void main() {
  test('les hôtes essayés : le PC lui-même, puis le sous-réseau du téléphone', () async {
    final hosts = await _discovery(_fakeNetwork()).candidateHosts();
    expect(hosts.take(3), ['localhost', '127.0.0.1', '10.0.2.2']);
    expect(hosts, contains('192.168.0.42'));
    expect(hosts, isNot(contains('192.168.0.7')), reason: 'le téléphone lui-même');
    expect(hosts.length, 3 + 253);
  });

  test('le balayage trouve le serveur et ses modèles', () async {
    final found = await _discovery(_fakeNetwork()).scan();
    expect(found, hasLength(1));
    expect(found.single.url, 'http://192.168.0.42:11434');
    expect(found.single.models.map((m) => m.name), contains('forgeron-qwen:latest'));
  });

  test('rien d\'Ollama sur le réseau : liste vide, pas d\'exception', () async {
    final found = await _discovery(MockClient((_) async => http.Response('<html>', 200))).scan();
    expect(found, isEmpty);
  });

  test('un serveur HTTP qui n\'est pas Ollama est ignoré', () async {
    final s = await _discovery(MockClient((_) async => http.Response('{"x":1}', 200)))
        .probe('http://192.168.0.9:11434');
    expect(s, isNull);
  });

  test('describe : sait-il appeler des outils ?', () async {
    final d = _discovery(_fakeNetwork());
    final s = await d.describe((await d.scan()).single);
    final byName = {for (final m in s.models) m.name: m};
    expect(byName['forgeron-qwen:latest']!.supportsTools, isTrue);
    expect(byName['forgeron-qwen:latest']!.contextTokens, 12288);
    expect(byName['gemma3n:latest']!.supportsTools, isFalse);
    expect(byName['gemma3n:latest']!.usable, isFalse);
  });

  group('modèle proposé d\'office', () {
    OllamaModel m(String n, [bool? tools]) => OllamaModel(n, supportsTools: tools);
    test('celui de Forgeron d\'abord, puis qwen3, puis qwen2.5', () {
      expect(OllamaDiscovery.recommend([m('qwen2.5:7b', true), m('qwen3:8b', true), m('forgeron-qwen:latest', true)])!.name,
          'forgeron-qwen:latest');
      expect(OllamaDiscovery.recommend([m('qwen2.5:7b', true), m('qwen3:8b', true)])!.name, 'qwen3:8b');
    });
    test('jamais un modèle connu pour ne pas appeler d\'outils', () {
      expect(OllamaDiscovery.recommend([m('gemma3n:latest', false)]), isNull);
      expect(OllamaDiscovery.recommend([m('gemma3n:latest', false), m('llama3.2', true)])!.name, 'llama3.2');
    });
    test('un contexte trop court écarte le modèle (le serveur tronquerait le prompt)', () {
      expect(const OllamaModel('qwen3:8b', supportsTools: true, contextTokens: 4096).usable, isFalse);
      expect(const OllamaModel('forgeron-qwen', supportsTools: true, contextTokens: 16384).usable, isTrue);
    });
    test('la liste réelle de l atelier : forgeron-qwen, pas le modèle qui réfléchit', () {
      OllamaModel mm(String n, int ctx, bool t) => OllamaModel(n, supportsTools: t, contextTokens: ctx);
      final list = [
        mm('gemma3n:latest', 4096, false),
        mm('forgeron-qwen3-8b-reflexion:latest', 8192, true),
        mm('qwen3:8b', 4096, true),
        mm('forgeron-qwen:latest', 16384, true),
        mm('qwen2.5:7b', 4096, true),
      ];
      expect(OllamaDiscovery.recommend(list)!.name, 'forgeron-qwen:latest');
    });
    test('capacité inconnue : proposé en dernier recours, pas écarté', () {
      expect(OllamaDiscovery.recommend([m('autre')])!.name, 'autre');
    });
  });

  group('modèle pour les images', () {
    test('gemma3n lit les images mais ne pilote pas la machine', () async {
      final d = _discovery(_fakeNetwork());
      final s = await d.describe((await d.scan()).single);
      final g = s.models.firstWhere((m) => m.name.startsWith('gemma'));
      expect(g.supportsVision, isTrue);
      expect(g.usable, isFalse);
      expect(OllamaDiscovery.recommend(s.models)!.name, 'forgeron-qwen:latest');
      expect(OllamaDiscovery.recommendVision(s.models, main: 'forgeron-qwen:latest')!.name, 'gemma3n:latest');
    });
    test('pas de modèle d\'images quand le principal voit déjà', () {
      const both = OllamaModel('seul', supportsTools: true, supportsVision: true);
      expect(OllamaDiscovery.recommendVision([both], main: 'seul'), isNull);
    });
    test('aucun modèle qui voit : aucune proposition', () {
      expect(OllamaDiscovery.recommendVision([const OllamaModel('a', supportsTools: true)], main: 'a'), isNull);
    });
  });

  group('diagnostic en phrases simples', () {
    test('serveur introuvable : on dit quoi vérifier', () async {
      final d = await _discovery(_fakeNetwork()).diagnose('192.168.0.99');
      expect(d.ok, isFalse);
      expect(d.message, contains('même Wi-Fi'));
    });
    test('modèle absent', () async {
      final d = await _discovery(_fakeNetwork()).diagnose('192.168.0.42', wantedModel: 'inconnu');
      expect(d.ok, isFalse);
      expect(d.message, contains('pas installé'));
    });
    test('modèle sans outils : refusé avec l\'explication', () async {
      final d = await _discovery(_fakeNetwork()).diagnose('192.168.0.42', wantedModel: 'gemma3n');
      expect(d.ok, isFalse);
      expect(d.message, contains('piloter'));
    });
    test('tout va bien', () async {
      final d = await _discovery(_fakeNetwork()).diagnose('192.168.0.42', wantedModel: 'forgeron-qwen');
      expect(d.ok, isTrue);
      expect(d.message, contains('192.168.0.42'));
    });
  });

  group('l\'écran', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('chercher puis utiliser : adresse et modèle enregistrés', (tester) async {
      var saved = 0;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocalServerAssistant(
                discovery: _discovery(_fakeNetwork()),
                onSaved: () => saved++,
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('CHERCHER MON SERVEUR'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('192.168.0.42'), findsWidgets);
      expect(find.text('recommandé'), findsOneWidget);
      expect(find.text('lit les images, ne pilote pas la machine'), findsOneWidget);

      await tester.tap(find.text('UTILISER CE SERVEUR'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(saved, 1);
      expect(find.textContaining('Connecté à 192.168.0.42'), findsOneWidget);
    });

    testWidgets('modèle d\'images proposé et enregistré avec le modèle principal', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocalServerAssistant(discovery: _discovery(_fakeNetwork())),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('CHERCHER MON SERVEUR'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('lit les images, ne pilote pas la machine'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget, reason: 'proposé d\'office');
      await tester.tap(find.text('UTILISER CE SERVEUR'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final s = container.read(aiAgentSettingsProvider);
      expect(s.localModel, 'forgeron-qwen:latest');
      expect(s.localVisionModel, 'gemma3n:latest');
      expect(find.textContaining('images lues par'), findsOneWidget);
    });

    testWidgets('rien trouvé : l\'aide s\'ouvre toute seule', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocalServerAssistant(
                  discovery: _discovery(MockClient((_) async => throw Exception('x')))),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('CHERCHER MON SERVEUR'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Aucun serveur trouvé sur ce réseau.'), findsOneWidget);
      expect(find.textContaining('Exposer Ollama au réseau'), findsOneWidget);
    });
  });
}
