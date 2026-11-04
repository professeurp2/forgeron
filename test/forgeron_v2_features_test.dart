import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/controller_memory_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/hardware_root_cause_correlator.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:forgeron/core/i18n/language_detector.dart';
import 'package:forgeron/core/theme/forgeron_colors.dart';
import 'package:forgeron/core/utils/grbl_alarm_catalog.dart';
import 'package:forgeron/domain/models/demo_benchmark_catalog.dart';
import 'package:forgeron/domain/models/esp32_reboot_event.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/domain/repositories/machine_repository.dart';
import 'package:forgeron/presentation/widgets/ai/omnipresent_ai_shell.dart';

class _InertMachineRepository implements MachineRepository {
  @override
  Stream<MachineState> get stateStream => const Stream.empty();
  @override
  Stream<String> get messageStream => const Stream.empty();
  @override
  Stream<String> get trafficStream => const Stream.empty();
  @override
  MachineState get currentState => const MachineState();
  @override
  Future<void> sendGCode(String gcode) async {}
  @override
  void sendRaw(String data) {}
  @override
  Future<void> sendGCodeBatch(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int index)? onProgress,
    void Function(String reason)? onStall,
  }) async {}
  @override
  Future<bool> emergencyStop() async => true;
  @override
  Future<void> home([List<String> axes = const []]) async {}
  @override
  Future<void> jog(String axis, double distance, double feedrate) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> reset() async {}
  @override
  Future<void> setFeedOverride(int percent) async {}
  @override
  Future<void> setSpindleOverride(int percent) async {}
  @override
  void setSimulationSpeed(double speed) {}
  @override
  Future<void> setWcsOffset(String wcs, List<double> offset) async {}
}

void main() {
  group('Axe 1 — Multilingue local & Anti-dérive Anglais/CJK', () {
    test('detectOperatorLanguage identifie le français, l\'anglais et le bambara', () {
      expect(
        LanguageDetector.detectOperatorLanguage(
          'Bonjour, pourquoi la machine affiche une alarme fin de course ?',
          fallback: 'en',
        ),
        equals('fr'),
      );

      expect(
        LanguageDetector.detectOperatorLanguage(
          'What is the current spindle speed and why did the machine stop?',
          fallback: 'fr',
        ),
        equals('en'),
      );

      expect(
        LanguageDetector.detectOperatorLanguage(
          'I ni ce, mansin dabila munna ?',
          fallback: 'fr',
        ),
        equals('bm'),
      );
    });

    test('detectOperatorLanguage conserve la langue par défaut sur du G-code pur', () {
      expect(
        LanguageDetector.detectOperatorLanguage(
          'G90 G21 G0 X0 Y0 Z10',
          fallback: 'fr',
        ),
        equals('fr'),
      );
    });

    test('isEnglishDrift et LocalAiAgentService.driftedToEnglish détectent le basculement post-outil', () {
      const driftedReply =
          'Here is the 5-axis toolpath for the impeller. You can see the parameters in the window while attempting to check the machine file.';
      expect(
        LanguageDetector.isEnglishDrift(driftedReply, expectedLangCode: 'fr'),
        isTrue,
      );

      const apiResp = AiApiResponse(
        parts: [
          {'text': driftedReply}
        ],
        finishReason: 'STOP',
      );
      final contentsFr = [
        {
          'role': 'user',
          'parts': [
            {'text': 'Génère le parcours pour la pièce en aluminium.'}
          ],
        }
      ];
      expect(
        LocalAiAgentService.driftedToEnglish(
          apiResp,
          contentsFr,
          systemPrompt: appLanguageById('fr').promptDirective,
        ),
        isTrue,
      );

      // Si la langue cible est l'anglais, ce n'est pas une dérive
      expect(
        LocalAiAgentService.driftedToEnglish(
          apiResp,
          contentsFr,
          systemPrompt: appLanguageById('en').promptDirective,
        ),
        isFalse,
      );
    });

    test('isEnglishDrift ignore les blocs de code G-code dans une réponse en français', () {
      const validFrenchWithGcode = '''
Voici le programme d'usinage généré pour la turbine 5 axes :
```gcode
G90 G21
G0 X0 Y0 Z15
M3 S12000
```
Vous pouvez maintenant lancer la simulation cinématique.
''';
      expect(
        LanguageDetector.isEnglishDrift(
          validFrenchWithGcode,
          expectedLangCode: 'fr',
        ),
        isFalse,
      );
    });

    test('trailingPromptAnchor génère un rappel de fin de prompt Sandwich', () {
      final frLang = appLanguageById('fr');
      expect(frLang.trailingPromptAnchor(), contains('CONSIGNE FINALE DE LANGUE'));

      final bmLang = appLanguageById('bm');
      expect(bmLang.trailingPromptAnchor(), contains('bambara'));
    });

    test('GrblAlarmCatalog et le dictionnaire Bambara traduisent dynamiquement selon la langue active', () async {
      await AppLocalizations.delegate.load(const Locale('bm'));
      expect(tr('Démarrer'), equals('A daminɛ'));

      AppLocalizations.setCurrentForTest(const {
        'Fin de course matérielle': 'Hard limit switch triggered',
      });
      final infoTranslated = GrblAlarmCatalog.lookup(1)!;
      expect(infoTranslated.title, equals('Hard limit switch triggered'));

      await AppLocalizations.delegate.load(const Locale('fr'));
      final infoFr = GrblAlarmCatalog.lookup(1)!;
      expect(infoFr.title, equals('Fin de course matérielle'));
    });
  });

  group('Axe 2 — Benchmarks STEP (Manufacturing & Medicine) & Mémoire Contrôleur', () {
    test('Le catalogue de démo couvre les capsules de prise en main et les fichiers Manufacturing/Medicine', () {
      expect(DemoBenchmarkCatalog.handsOnGuides.length, greaterThanOrEqualTo(5));
      expect(DemoBenchmarkCatalog.byDomain(DemoDomain.manufacturing), isNotEmpty);
      expect(DemoBenchmarkCatalog.byDomain(DemoDomain.medicine), isNotEmpty);

      // Vérifie que les fichiers STEP/STL/NC intégrés dans scratch/ existent sur le disque
      for (final sample in DemoBenchmarkCatalog.samples) {
        final file = File(sample.cadPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Fichier CAO introuvable pour le sample ${sample.id} (${sample.cadPath})',
        );
      }
    });

    test('ControllerMemoryNotifier et NextBestActionEngine adaptent les suggestions après chaque opération', () {
      final container = ProviderContainer(
        overrides: [
          machineRepositoryProvider.overrideWithValue(_InertMachineRepository()),
        ],
      );
      addTearDown(container.dispose);

      // 1. État initial -> dispose de suggestions initiales
      final initialMemory = container.read(controllerMemoryProvider);
      expect(initialMemory.nextSuggestions, isNotEmpty);

      // 2. Enregistrement du chargement d'un fichier STEP -> met à jour la mémoire et les suggestions
      container.read(controllerMemoryProvider.notifier).recordOperation(
            OperationEventType.stepFileLoaded,
            summary: 'Chargement de IMPELLER.STP',
            filePath: 'scratch/3D/IMPELLER.STP',
            demoDomain: 'manufacturing',
          );
      final afterStep = container.read(controllerMemoryProvider);
      expect(afterStep.activeFilePath, equals('scratch/3D/IMPELLER.STP'));
      expect(afterStep.nextSuggestions, isNotEmpty);

      // 3. Le bloc mémoire injecté dans le prompt système contient la fenêtre et la pièce active
      final promptBlock = afterStep.toSystemPromptBlock();
      expect(promptBlock, contains('MÉMOIRE DU CONTRÔLEUR FORGERON'));
      expect(promptBlock, contains('IMPELLER.STP'));
    });
  });

  group('Axe 4 — Détection temps réel des redémarrages ESP32 & Corrélation matérielle GPIO', () {
    test('Esp32RebootDetector identifie un Brownout ESP32 après démarrage broche M3', () {
      const machine = MachineState(
        status: MachineStatus.run,
        mPos: [12.0, -5.0, -1.5, 15.0, 90.0],
        spindleSpeed: 12000,
      );
      final now = DateTime(2026, 11, 4, 10, 30, 3);
      final spindleStart = DateTime(2026, 11, 4, 10, 30, 0);

      final event = Esp32RebootDetector.inspectRawLine(
        'Brownout detector was triggered',
        currentState: machine,
        sessionAlreadyInitialized: true,
        lastSpindleStartAt: spindleStart,
        now: now,
      );

      expect(event, isNotNull);
      expect(event!.reason, equals(Esp32RebootReason.brownoutSpindleSurge));
      expect(event.wasSpindleRecentlyStarted, isTrue);
      expect(event.previousStatus, equals(MachineStatus.run));
    });

    test('Esp32RebootDetector ignore les lignes normales mais détecte une bannière FluidNC en session', () {
      const machine = MachineState(
        status: MachineStatus.idle,
        mPos: [10.0, 20.0, -5.0, 0.0, 0.0],
      );

      expect(
        Esp32RebootDetector.inspectRawLine(
          'ok',
          currentState: machine,
          sessionAlreadyInitialized: true,
        ),
        isNull,
      );

      final bootBanner = Esp32RebootDetector.inspectRawLine(
        '[MSG:INFO: FluidNC v3.9.1]',
        currentState: machine,
        sessionAlreadyInitialized: true,
      );
      expect(bootBanner, isNotNull);
      expect(bootBanner!.reason, equals(Esp32RebootReason.powerSupplyDrop));
    });

    test('HardwareRootCauseCorrelator relie un Brownout en rotation broche au GPIO 21 et à l\'ATX 12V', () {
      final event = Esp32RebootEvent(
        timestamp: DateTime(2026, 11, 4, 10, 30),
        reason: Esp32RebootReason.brownoutSpindleSurge,
        rawSignature: 'Brownout detector was triggered',
        previousStatus: MachineStatus.run,
        previousMPos: const [12.5, -4.0, -1.2, 0.0, 0.0],
        wasSpindleRecentlyStarted: true,
      );

      final diagnosis = HardwareRootCauseCorrelator.diagnoseEsp32Reboot(event);
      expect(diagnosis.gpioPinDetail, contains('GPIO 21'));
      expect(diagnosis.probableHardwareCause, contains('775'));
      expect(diagnosis.quickActions.any((a) => a.gcodeCommand == r'$H'), isTrue);
      expect(diagnosis.quickActions.any((a) => a.gcodeCommand == 'M5'), isTrue);
    });

    test('HardwareRootCauseCorrelator relie ALARM:1 aux pins GPIO des capteurs fin de course', () {
      const machine = MachineState(
        status: MachineStatus.alarm,
        alarmCode: 1,
        limitSwitches: [true, false, false, false, false],
      );
      final diagnosis = HardwareRootCauseCorrelator.diagnoseAlarm(machine);
      expect(diagnosis.gpioPinDetail, contains('GPIO 4'));
      expect(diagnosis.quickActions.any((a) => a.gcodeCommand == r'$X'), isTrue);
    });
  });

  group('Axe 3 — Fenêtre Forgeron IA (Thème, Sobriété & Masquage sur page Agent IA)', () {
    testWidgets('Forgeron IA respecte le thème, affiche un texte sobre et se masque sur la page Agent IA', (tester) async {
      final overrides = [
        machineRepositoryProvider.overrideWithValue(_InertMachineRepository()),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: ForgeronTheme(
            colors: forgeronLightColors,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 1200,
                  height: 800,
                  child: OmnipresentAiShell(
                    hideOverlay: false,
                    child: Center(child: Text('Contenu métier')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Le bouton d'accès porte le nom exact « Forgeron IA »
      expect(find.text('Forgeron IA'), findsOneWidget);
      expect(find.textContaining('Prises en main'), findsNothing);
      expect(find.textContaining('STEP Manufacturing'), findsNothing);

      // 2. Ouverture de la fenêtre flottante : sobre, avec pickers, audio et sans barres démo
      await tester.tap(find.text('Forgeron IA'));
      await tester.pumpAndSettle();
      expect(find.text('Forgeron IA'), findsWidgets);
      expect(find.textContaining('Prises en main'), findsNothing);
      expect(find.textContaining('STEP Manufacturing'), findsNothing);
      expect(find.textContaining('COPILOTE IA'), findsNothing);

      // Présence des contrôles enrichis (FilePicker, ImagePicker, Audio STT & TTS)
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

      // 3. Sur la page Agent IA (hideOverlay: true), la fenêtre disparaît complètement
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: ForgeronTheme(
            colors: forgeronLightColors,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 1200,
                  height: 800,
                  child: OmnipresentAiShell(
                    hideOverlay: true,
                    child: Center(child: Text('Page Agent IA principale')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page Agent IA principale'), findsOneWidget);
      expect(find.text('Forgeron IA'), findsNothing);
    });
  });
}
