import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_artifacts_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/gcode_provider.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/simulation_provider.dart';
import 'package:forgeron/application/providers/viewer_snapshot_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/application/services/tool_router.dart';
import 'package:forgeron/presentation/screens/desktop/ai_console_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Petit PNG 1×1 valide pour simuler le retour `canvas.toDataURL('image/png')`.
final Uint8List _kSamplePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _FakeBackend implements AiBackend {
  _FakeBackend(this.model, this.script);

  @override
  final String model;
  final List<AiApiResponse> script;
  final List<List<Map<String, dynamic>>> receivedContents = [];
  final List<List<String>> declaredTools = [];

  @override
  int get historyBudgetChars => 100000;
  @override
  bool get usesCellular => false;
  @override
  Future<bool> isReachable() async => true;
  @override
  String get unreachableMessage => '';
  @override
  void dispose() {}

  AiApiResponse _handle(
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> declarations,
  ) {
    receivedContents.add(
      (jsonDecode(jsonEncode(contents)) as List).cast<Map<String, dynamic>>(),
    );
    declaredTools.add(declarations.map((d) => '${d['name']}').toList());
    if (script.isEmpty) {
      return const AiApiResponse(
        parts: [
          {'text': 'OK.'}
        ],
        finishReason: 'STOP',
      );
    }
    return script.removeAt(0);
  }

  @override
  Future<AiApiResponse> sendMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
  }) async =>
      _handle(contents, functionDeclarations);

  @override
  Future<AiApiResponse> streamMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String partialText)? onDelta,
    bool Function()? shouldCancel,
  }) async =>
      _handle(contents, functionDeclarations);
}

final _testRefProvider = Provider<Ref>((ref) => ref);

ProviderContainer _makeContainer({bool simMode = true}) {
  return ProviderContainer(
    overrides: [
      machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
      isSimulationModeProvider.overrideWith((ref) => simMode),
      lexiconSourceProvider.overrideWithValue(
        () async => File('assets/lexicon/lexique.json').readAsString(),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ViewerSnapshotService & sélection de scène 3D', () {
    test('décode proprement un dataURL PNG base64 et ignore les entrées invalides', () {
      final b64 = base64Encode(_kSamplePng);
      final decoded =
          ViewerSnapshotService.decodeDataUrlPng('data:image/png;base64,$b64');
      expect(decoded, isNotNull);
      expect(decoded!.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));

      expect(ViewerSnapshotService.decodeDataUrlPng(null), isNull);
      expect(ViewerSnapshotService.decodeDataUrlPng(''), isNull);
      expect(
        ViewerSnapshotService.decodeDataUrlPng('data:image/png;base64,@@@'),
        isNull,
      );
    });

    test('sélectionne la poignée 3D adaptée à simulator / toolpath / part', () {
      final svc = ViewerSnapshotService();

      svc.register(
        ViewerSnapshotHandle(
          id: 'sim_main',
          describeScene: () => const {
            'machine': true,
            'toolpath': true,
            'part': false,
            'workpiece': true,
          },
          capture: ({cameraPreset, temporaryScene, hudBanner}) async => null,
        ),
      );
      svc.register(
        ViewerSnapshotHandle(
          id: 'step_only',
          describeScene: () => const {
            'machine': false,
            'toolpath': false,
            'part': true,
            'workpiece': false,
          },
          capture: ({cameraPreset, temporaryScene, hudBanner}) async => null,
        ),
      );
      svc.register(
        ViewerSnapshotHandle(
          id: 'tp_only',
          describeScene: () => const {
            'machine': false,
            'toolpath': true,
            'part': false,
            'workpiece': false,
          },
          capture: ({cameraPreset, temporaryScene, hudBanner}) async => null,
        ),
      );

      expect(svc.selectHandle('simulator')?.id, 'sim_main');
      expect(svc.selectHandle('toolpath')?.id, 'tp_only');
      expect(svc.selectHandle('part')?.id, 'step_only');

      svc.unregister('tp_only');
      // Sans panneau toolpath isolé, retombe sur le simulateur qui porte aussi le parcours
      expect(svc.selectHandle('toolpath')?.id, 'sim_main');
    });
  });

  group('Routage ToolRouter & libellés console pour la capture d\'écran', () {
    const router = ToolRouter();
    final all = AiToolCatalog.tools.map((t) => t.name).toList();

    test('route les demandes de capture simulateur, parcours, caméra et écran', () {
      for (final prompt in [
        'Prends une capture d\'écran du simulateur pour voir ce qui se passe.',
        'Montre-moi le parcours d\'outils en 3D.',
        'Regarde la caméra de la zone de coupe.',
        'Fais un screenshot de l\'écran actuel.',
        'Que se passe-t-il en ce moment ?',
      ]) {
        final r = router.route(text: prompt, allTools: all);
        expect(
          r.tools,
          contains('capture_workspace_view'),
          reason: 'Échec de routage pour : $prompt',
        );
      }
    });

    test('libellé et résumé humains dans ai_console_timeline', () {
      expect(
        friendlyToolLabel('capture_workspace_view'),
        contains('Capture visuelle'),
      );
      final summary = resultSummary(
        'capture_workspace_view',
        jsonEncode({'target': 'simulator', 'source': 'webgl_3d'}),
      );
      expect(summary, 'Vue simulator · webgl_3d');
    });
  });

  group('Exécution de capture_workspace_view (WebGL 3D, Parcours, Caméra)', () {
    test('capture 3D du simulateur avec programme chargé, preset caméra et métriques', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // Charge un programme G-code 5 axes réaliste avec outil déclaré
      await container.read(gcodeProvider.notifier).loadFile('''
(Forgeron Medical Implant)
(Tools: T1 = 4.0mm ball endmill)
G21 G90 G54
T1 M6 (BALL_ENDMILL D=4.0mm)
M3 S10000
G0 X0 Y0 Z15 A0 C0
G1 X12.5 Y-8.0 Z-2.4 A15.0 C90.0 F600
G1 X18.0 Y4.0 Z-3.5 A22.5 C180.0 F600
M5
M30
''');

      String? capturedPreset;
      Map<String, dynamic>? capturedTempScene;
      String? capturedHud;

      container.read(viewerSnapshotServiceProvider).register(
            ViewerSnapshotHandle(
              id: 'test_webgl',
              describeScene: () => const {
                'machine': true,
                'toolpath': true,
                'part': true,
                'workpiece': true,
              },
              capture: ({cameraPreset, temporaryScene, hudBanner}) async {
                capturedPreset = cameraPreset;
                capturedTempScene = temporaryScene;
                capturedHud = hudBanner;
                return ViewerSnapshotResult(
                  pngBytes: _kSamplePng,
                  source: 'webgl_3d',
                  width: 800,
                  height: 600,
                  metrics: const {
                    'stock': {'removedPct': 37.5, 'remainingVoxels': 1250},
                    'cameraPreset': 'TOP',
                  },
                );
              },
            ),
          );

      final tool = AiToolCatalog.byName('capture_workspace_view')!;
      expect(tool.producesImage, isTrue);
      expect(tool.category, isNull, reason: 'lecture seule : aucune confirmation bloquante');

      final rawJson = await tool.execute(
        {'target': 'simulator', 'camera_preset': 'top'},
        container.read(_testRefProvider),
      );

      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      expect(data['ok'], isTrue);
      expect(data['captured'], isTrue);
      expect(data['target'], 'simulator');
      expect(data['source'], 'webgl_3d');
      expect(capturedPreset, 'TOP');
      expect(capturedTempScene, isNull);
      expect(capturedHud, contains('SIMULATEUR 5X | VUE TOP'));

      final tp = data['toolpath'] as Map<String, dynamic>;
      expect(tp['loaded'], isTrue);
      expect((tp['pointsCount'] as int), greaterThanOrEqualTo(3));
      expect((tp['tools'] as List).first['toolNumber'], 1);

      final scene3d = data['scene3d'] as Map<String, dynamic>;
      expect((scene3d['stock'] as Map)['removedPct'], 37.5);

      // L'image PNG est bien déposée dans la boîte aux lettres de l'agent
      final toolImg = container.read(aiToolImageProvider);
      expect(toolImg, isNotNull);
      expect(toolImg!.mimeType, 'image/png');
      expect(toolImg.bytes, equals(_kSamplePng));

      // Le panneau 3D a été ouvert automatiquement sur l'onglet simulateur
      expect(
        container.read(aiArtifactsProvider).openPanes,
        contains(AiDockedViewer.toolpath),
      );
      expect(
        container.read(simulationProvider).activeTab,
        ConsoleRightTab.simulator,
      );
    });

    test('target="toolpath" isole temporairement le tracé 3D sans cabine ni brut', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      Map<String, dynamic>? receivedTempScene;
      container.read(viewerSnapshotServiceProvider).register(
            ViewerSnapshotHandle(
              id: 'test_webgl_tp',
              describeScene: () => const {'machine': true, 'toolpath': true},
              capture: ({cameraPreset, temporaryScene, hudBanner}) async {
                receivedTempScene = temporaryScene;
                return ViewerSnapshotResult(
                  pngBytes: _kSamplePng,
                  source: 'webgl_3d',
                );
              },
            ),
          );

      final tool = AiToolCatalog.byName('capture_workspace_view')!;
      await tool.execute({'target': 'toolpath'}, container.read(_testRefProvider));

      expect(receivedTempScene, isNotNull);
      expect(receivedTempScene!['machine'], isFalse);
      expect(receivedTempScene!['workpiece'], isFalse);
      expect(receivedTempScene!['toolpath'], isTrue);
    });

    test('target="camera" en mode simulation signale honnêtement l\'absence de caméra physique', () async {
      final container = _makeContainer(simMode: true);
      addTearDown(container.dispose);

      final tool = AiToolCatalog.byName('capture_workspace_view')!;
      final rawJson = await tool.execute(
        {'target': 'camera'},
        container.read(_testRefProvider),
      );

      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      expect(data['ok'], isTrue);
      expect(data['target'], 'camera');
      expect(data['cameraDiagnostic'], contains('Mode simulation'));
      expect(
        container.read(simulationProvider).activeTab,
        ConsoleRightTab.camera,
      );
    });
  });

  group('Capture d\'écran Flutter RepaintBoundary & boucle Agent IA + Vision', () {
    testWidgets('capture réelle d\'un RepaintBoundary en PNG valide', (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final boundaryKey =
          container.read(viewerSnapshotServiceProvider).screenRepaintBoundaryKey;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: RepaintBoundary(
              key: boundaryKey,
              child: const Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 240,
                    height: 160,
                    child: ColoredBox(color: Colors.blueGrey),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final tool = AiToolCatalog.byName('capture_workspace_view')!;
      late String rawJson;
      await tester.runAsync(() async {
        rawJson = await tool.execute(
          {'target': 'screen'},
          container.read(_testRefProvider),
        );
      });

      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      expect(data['captured'], isTrue);
      expect(data['source'], 'flutter_screen');

      final img = container.read(aiToolImageProvider);
      expect(img, isNotNull);
      // Signature magique PNG : 89 50 4E 47
      expect(img!.bytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
    });

    test('boucle complète : le pilote déclenche capture_workspace_view et le modèle Vision analyse image + télémesures', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(gcodeProvider.notifier).loadFile(
        'G21 G90\nG0 X0 Y0 Z10\nG1 X10 Y5 Z-1.5 F400\nM30\n',
      );

      container.read(viewerSnapshotServiceProvider).register(
            ViewerSnapshotHandle(
              id: 'sim_3d',
              describeScene: () => const {'machine': true, 'toolpath': true},
              capture: ({cameraPreset, temporaryScene, hudBanner}) async =>
                  ViewerSnapshotResult(
                pngBytes: _kSamplePng,
                source: 'webgl_3d',
                metrics: const {
                  'stock': {'removedPct': 24.0},
                },
              ),
            ),
          );

      final activeModelId = container.read(aiModelProvider).active.id;
      final pilot = _FakeBackend(activeModelId, [
        const AiApiResponse(
          parts: [
            {
              'functionCall': {
                'name': 'capture_workspace_view',
                'args': {'target': 'simulator', 'camera_preset': 'ISOMETRIC'},
              }
            }
          ],
          finishReason: 'STOP',
        ),
      ]);
      final vision = _FakeBackend('gemma3n:latest', [
        const AiApiResponse(
          parts: [
            {
              'text':
                  'Sur la capture du simulateur 5 axes (vue ISOMETRIC), le parcours d\'outil '
                  'est bien centré et 24 % du brut a déjà été usiné sans aucune collision.'
            }
          ],
          finishReason: 'STOP',
        ),
      ]);

      final ctrl = container.read(aiAgentControllerProvider.notifier);
      ctrl.debugUseBackend(pilot);
      ctrl.debugUseVisionBackend(vision);

      await ctrl.sendUserMessage(
        'Prends une capture du simulateur pour vérifier ce qui se passe.',
      );

      // 1. Le modèle Vision a bien été sollicité sur le tour portant l'image capturée
      expect(vision.receivedContents, hasLength(1));
      final lastVisionTurn = vision.receivedContents.single.last;
      final visionParts = (lastVisionTurn['parts'] as List).cast<Map>();
      expect(
        visionParts.any((p) => p.containsKey('inlineData')),
        isTrue,
        reason: 'le PNG du simulateur est transmis au modèle de vision',
      );
      expect(
        visionParts.any(
          (p) =>
              p['text'] is String &&
              (p['text'] as String).contains('Télémesures exactes au moment de la capture') &&
              (p['text'] as String).contains('24.0'),
        ),
        isTrue,
        reason: 'les télémesures JSON sont jointes en clair pour le modèle de vision',
      );

      // 2. La vignette de capture est attachée à l'étape d'outil dans le fil opérateur
      final state = container.read(aiAgentControllerProvider);
      final toolMsg = state.messages.firstWhere((m) => m.isTool);
      expect(toolMsg.toolName, 'capture_workspace_view');
      expect(toolMsg.imageBytes, isNotNull);

      // 3. La réponse finale en français est affichée et la fiche d'image est mémorisée
      expect(
        state.messages.last.text,
        contains('24 % du brut a déjà été usiné sans aucune collision'),
      );

      // 4. Au tour suivant, le pilote texte reçoit la fiche rédigée par gemma3n:latest
      await ctrl.sendUserMessage(
        'Parfait, résume ce constat visuel pour le rapport d\'usinage.',
      );
      expect(
        jsonEncode(pilot.receivedContents.last),
        contains(LocalAiAgentService.imageFichePrefix),
      );
    });
  });
}
