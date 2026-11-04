import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/gcode_provider.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/viewer_snapshot_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Dessine une scène synthétique 640×360 imitant fidèlement le rendu Three.js
/// (fond studio sombre, plateau C turquoise, brut cylindrique bleu entamé,
/// passes G1 vertes, rapide G0 rouge et bandeau télémétrique).
Future<Uint8List> _buildSyntheticSimulatorPng() async {
  const w = 640.0;
  const h = 360.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  // Fond studio sombre
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF141A24),
  );

  // Plateau rotatif C (turquoise)
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(320, 235), width: 250, height: 110),
    Paint()..color = const Color(0xFF0F8B7D),
  );

  // Brut cylindrique bleu en cours d'usinage
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(320, 195), width: 150, height: 78),
      const Radius.circular(18),
    ),
    Paint()..color = const Color(0xFF3B82F6),
  );

  // Parcours d'outil G1 (passes vertes) + G0 (dégagement rouge)
  final g1Paint = Paint()
    ..color = const Color(0xFF3FB950)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  for (var dy = -20.0; dy <= 20.0; dy += 8.0) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(320, 185 + dy), width: 120, height: 32),
      0.15,
      2.8,
      false,
      g1Paint,
    );
  }
  canvas.drawLine(
    const Offset(265, 165),
    const Offset(320, 95),
    Paint()
      ..color = const Color(0xFFF85149)
      ..strokeWidth = 2.2,
  );

  // Fraise boule orange en contact
  canvas.drawRect(
    const Rect.fromLTWH(315, 70, 10, 85),
    Paint()..color = const Color(0xFFFF6B35),
  );

  // Bandeau HUD en haut à gauche
  canvas.drawRect(
    const Rect.fromLTWH(12, 12, 560, 26),
    Paint()..color = const Color(0xDD0E1117),
  );
  final tp = TextPainter(
    text: const TextSpan(
      text:
          'SIMULATEUR 5X | VUE ISOMETRIC | X:14.2 Y:-6.5 Z:-2.8 A:18.0° C:120.0° | BRUT COUPÉ:42.5%',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, const Offset(20, 18));

  final picture = recorder.endRecording();
  final img = await picture.toImage(w.toInt(), h.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return byteData!.buffer.asUint8List();
}

Future<bool> _hasLiveOllamaModels() async {
  try {
    final res = await http
        .get(Uri.parse('http://localhost:11434/api/tags'))
        .timeout(const Duration(seconds: 2));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final names = (body['models'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => '${m['name']}')
        .toList();
    return names.any((n) => n.startsWith('forgeron-qwen')) &&
        names.any((n) => n.startsWith('gemma3n'));
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // TestWidgetsFlutterBinding remplace HttpClient par un bouchon qui renvoie 400 :
  // on restaure la pile réseau réelle pour parler à Ollama sur localhost:11434.
  HttpOverrides.global = null;

  test(
    'E2E réel Ollama (forgeron-qwen + gemma3n auto-découvert) : capture simulateur & parcours en français',
    () async {
      if (!await _hasLiveOllamaModels()) {
        // Saute proprement sur un poste CI sans Ollama local.
        return;
      }

      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
          isSimulationModeProvider.overrideWith((ref) => true),
          lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Configure le serveur local SANS renseigner localVisionModel pour
      // vérifier que gemma3n:latest est découvert automatiquement !
      final settingsNotifier = container.read(aiAgentSettingsProvider.notifier);
      settingsNotifier.setEnabled(true);
      settingsNotifier.setLocalBaseUrl('http://localhost:11434');
      settingsNotifier.setLocalModel('forgeron-qwen:latest');
      settingsNotifier.setLocalVisionModel('');

      await container.read(gcodeProvider.notifier).loadFile('''
(Forgeron Cranial Implant PEEK)
(Tools: T1 = 4.0mm ball endmill)
G21 G90 G54
T1 M6 (BALL_ENDMILL D=4.0mm)
M3 S10000
G0 X0 Y0 Z15 A0 C0
G1 X14.2 Y-6.5 Z-2.8 A18.0 C120.0 F600
G1 X18.0 Y4.0 Z-3.2 A20.0 C180.0 F600
M5
M30
''');

      final simPng = await _buildSyntheticSimulatorPng();
      int captureCalls = 0;

      container.read(viewerSnapshotServiceProvider).register(
            ViewerSnapshotHandle(
              id: 'live_webgl',
              describeScene: () => const {
                'machine': true,
                'toolpath': true,
                'part': true,
                'workpiece': true,
              },
              capture: ({cameraPreset, temporaryScene, hudBanner}) async {
                captureCalls++;
                return ViewerSnapshotResult(
                  pngBytes: simPng,
                  source: 'webgl_3d',
                  width: 640,
                  height: 360,
                  metrics: const {
                    'stock': {
                      'shape': 'cylinder',
                      'dimensionsMm': [40, 40, 25],
                      'removedPct': 42.5,
                    },
                    'cameraPreset': 'ISOMETRIC',
                  },
                );
              },
            ),
          );

      final ctrl = container.read(aiAgentControllerProvider.notifier);
      await ctrl.sendUserMessage(
        'Prends une capture d\'écran du simulateur pour savoir ce qui se passe sur la pièce.',
      );

      final state = container.read(aiAgentControllerProvider);
      expect(state.error, isNull, reason: 'Erreur agent: ${state.error}');
      expect(captureCalls, greaterThanOrEqualTo(1),
          reason: 'forgeron-qwen doit appeler capture_workspace_view');

      // Vérifie que gemma3n:latest a été auto-découvert et enregistré
      expect(
        container.read(aiAgentSettingsProvider).localVisionModel,
        contains('gemma3n'),
      );

      final reply = state.messages.last.text;
      // ignore: avoid_print
      print('\n=== RÉPONSE LIVE AGENT (SIMULATEUR + VISION) ===\n$reply\n');
      expect(reply.trim(), isNotEmpty);
      // La réponse doit s'appuyer sur la capture (télémesures ou contenu visible),
      // pas sur une description générique de la machine tirée du prompt.
      final lower = reply.toLowerCase();
      expect(
        ['42', '14.2', '14,2', '120', 'brut', 'parcours', 'vert', 'rouge', 'outil', 'fraise']
            .any(lower.contains),
        isTrue,
        reason: 'La réponse doit refléter la capture et ses télémesures : $reply',
      );
      expect(
        LocalAiAgentService.driftedToEnglish(
          AiApiResponse(
            parts: [
              {'text': reply}
            ],
            finishReason: 'STOP',
          ),
          const [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Prends une capture d\'écran du simulateur pour savoir ce qui se passe sur la pièce.'
                }
              ],
            }
          ],
        ),
        isFalse,
        reason: 'La réponse finale doit rester en français : $reply',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

