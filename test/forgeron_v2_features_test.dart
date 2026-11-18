import 'package:forgeron/application/providers/ai_prompt_draft_provider.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/gcode_provider.dart';
import 'package:forgeron/application/providers/machining_mode_provider.dart';
import 'package:forgeron/application/providers/camera_provider.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forgeron/core/utils/gcode_critic.dart';
import 'package:forgeron/domain/models/machining_mode.dart';
import 'package:forgeron/core/i18n/translations/ha.dart';
import 'dart:async';
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
import 'package:forgeron/core/i18n/waxal_voice_engine.dart';
import 'package:forgeron/core/theme/forgeron_colors.dart';
import 'package:forgeron/core/utils/emergency_intent.dart';
import 'package:forgeron/core/utils/grbl_alarm_catalog.dart';
import 'package:forgeron/domain/models/demo_benchmark_catalog.dart';
import 'package:forgeron/domain/models/esp32_reboot_event.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/domain/repositories/machine_repository.dart';
import 'package:forgeron/presentation/widgets/ai/omnipresent_ai_shell.dart';

class _InertMachineRepository implements MachineRepository {
  @override
  MachineState get currentState => const MachineState();

  @override
  Stream<MachineState> get stateStream => const Stream.empty();

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  Stream<String> get trafficStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  group('Axe 1 — Multilingue local & Anti-dérive Anglais/CJK', () {
    test(
      'detectOperatorLanguage identifie le français, l\'anglais et le bambara',
      () {
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
      },
    );

    test(
      'detectOperatorLanguage conserve la langue par défaut sur du G-code pur',
      () {
        expect(
          LanguageDetector.detectOperatorLanguage(
            'G90 G21 G0 X0 Y0 Z10',
            fallback: 'fr',
          ),
          equals('fr'),
        );
      },
    );

    test(
      'isEnglishDrift et LocalAiAgentService.driftedToEnglish détectent le basculement post-outil',
      () {
        const driftedReply =
            'Here is the 5-axis toolpath for the impeller. You can see the parameters in the window while attempting to check the machine file.';
        expect(
          LanguageDetector.isEnglishDrift(driftedReply, expectedLangCode: 'fr'),
          isTrue,
        );

        const apiResp = AiApiResponse(
          parts: [
            {'text': driftedReply},
          ],
          finishReason: 'STOP',
        );
        final contentsFr = [
          {
            'role': 'user',
            'parts': [
              {'text': 'Génère le parcours pour la pièce en aluminium.'},
            ],
          },
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
      },
    );

    test(
      'isEnglishDrift ignore les blocs de code G-code dans une réponse en français',
      () {
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
      },
    );

    test('trailingPromptAnchor génère un rappel de fin de prompt Sandwich', () {
      final frLang = appLanguageById('fr');
      expect(
        frLang.trailingPromptAnchor(),
        contains('CONSIGNE FINALE DE LANGUE'),
      );

      final bmLang = appLanguageById('bm');
      expect(bmLang.trailingPromptAnchor(), contains('bambara'));
    });

    test(
      'GrblAlarmCatalog et le dictionnaire Bambara traduisent dynamiquement selon la langue active',
      () async {
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
      },
    );
  });

  group('Axe 2 — Benchmarks STEP (Manufacturing & Medicine) & Mémoire Contrôleur', () {
    test(
      'Le catalogue de démo couvre les capsules de prise en main et les fichiers Manufacturing/Medicine',
      () {
        expect(
          DemoBenchmarkCatalog.handsOnGuides.length,
          greaterThanOrEqualTo(5),
        );
        expect(
          DemoBenchmarkCatalog.byDomain(DemoDomain.manufacturing),
          isNotEmpty,
        );
        expect(DemoBenchmarkCatalog.byDomain(DemoDomain.medicine), isNotEmpty);

        // Vérifie que les fichiers STEP/STL/NC intégrés dans scratch/ existent sur le disque
        for (final sample in DemoBenchmarkCatalog.samples) {
          final file = File(sample.cadPath);
          expect(
            file.existsSync(),
            isTrue,
            reason:
                'Fichier CAO introuvable pour le sample ${sample.id} (${sample.cadPath})',
          );
        }
      },
    );

    test(
      'ControllerMemoryNotifier et NextBestActionEngine adaptent les suggestions après chaque opération',
      () {
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
        container
            .read(controllerMemoryProvider.notifier)
            .recordOperation(
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
      },
    );
  });

  group(
    'Axe 4 — Détection temps réel des redémarrages ESP32 & Corrélation matérielle GPIO',
    () {
      test(
        'Esp32RebootDetector identifie un Brownout ESP32 après démarrage broche M3',
        () {
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
        },
      );

      test(
        'Esp32RebootDetector ignore les lignes normales mais détecte une bannière FluidNC en session',
        () {
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
        },
      );

      test(
        'HardwareRootCauseCorrelator relie un Brownout en rotation broche au GPIO 21 et à l\'ATX 12V',
        () {
          final event = Esp32RebootEvent(
            timestamp: DateTime(2026, 11, 4, 10, 30),
            reason: Esp32RebootReason.brownoutSpindleSurge,
            rawSignature: 'Brownout detector was triggered',
            previousStatus: MachineStatus.run,
            previousMPos: const [12.5, -4.0, -1.2, 0.0, 0.0],
            wasSpindleRecentlyStarted: true,
          );

          final diagnosis = HardwareRootCauseCorrelator.diagnoseEsp32Reboot(
            event,
          );
          expect(diagnosis.gpioPinDetail, contains('GPIO 21'));
          expect(diagnosis.probableHardwareCause, contains('775'));
          expect(
            diagnosis.quickActions.any((a) => a.gcodeCommand == r'$H'),
            isTrue,
          );
          expect(
            diagnosis.quickActions.any((a) => a.gcodeCommand == 'M5'),
            isTrue,
          );
        },
      );

      test(
        'HardwareRootCauseCorrelator relie ALARM:1 aux pins GPIO des capteurs fin de course',
        () {
          const machine = MachineState(
            status: MachineStatus.alarm,
            alarmCode: 1,
            limitSwitches: [true, false, false, false, false],
          );
          final diagnosis = HardwareRootCauseCorrelator.diagnoseAlarm(machine);
          expect(diagnosis.gpioPinDetail, contains('GPIO 4'));
          expect(
            diagnosis.quickActions.any((a) => a.gcodeCommand == r'$X'),
            isTrue,
          );
        },
      );
    },
  );

  group(
    'Axe 3 — Fenêtre Forgeron IA (Thème, Sobriété & Masquage sur page Agent IA)',
    () {
      testWidgets(
        'Forgeron IA respecte le thème, affiche un texte sobre et se masque sur la page Agent IA',
        (tester) async {
          final inertRepo = _InertMachineRepository();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                machineRepositoryProvider.overrideWithValue(inertRepo),
              ],
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
              overrides: [
                machineRepositoryProvider.overrideWithValue(inertRepo),
              ],
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
        },
      );
    },
  );

  group(
    'Axe 5 — Corpus Google WAXAL (google/WaxalNLP) & Lecture vocale TTS Bambara / Multilingue',
    () {
      test(
        'WaxalVoiceEngine catalogue les langues africaines de google/WaxalNLP et RobotsMali',
        () {
          for (final id in ['sw', 'ha', 'yo', 'ig', 'ln', 'sn', 'mg']) {
            final p = WaxalVoiceEngine.kProfiles[id];
            expect(p, isNotNull, reason: 'Profil WAXAL manquant pour $id');
            expect(p!.inGoogleWaxal, isTrue);
            expect(p.huggingFaceDataset, equals('google/WaxalNLP'));
          }

          final bm = WaxalVoiceEngine.kProfiles['bm'];
          expect(bm, isNotNull);
          expect(bm!.iso639_3, equals('bam'));
          expect(bm.phoneticFallbackTag, equals('fr-FR'));
        },
      );

      test(
        'transcribeBambaraForFrenchTts convertit les lettres IPA (ɛ, ɔ, ɲ, ŋ) et la phonétique bambara sans altérer les mots français d\'atelier',
        () {
          final raw =
              'I ni ce! Mashini jɔ sisan. X taa milimɛtɛri duuru la, kɛmɛ saba. A ɲɛfɔ n ye.';
          final spoken = WaxalVoiceEngine.transcribeBambaraForFrenchTts(raw);

          // Plus aucun caractère IPA africain qui ferait bégayer SAPI/Android TTS
          expect(spoken.contains(RegExp(r'[ɛɔɲŋ]')), isFalse);
          expect(spoken, contains('I ni tché'));
          expect(spoken, contains('Machini'));
          expect(spoken, contains('djò'));
          expect(spoken, contains('ssissan'));
          expect(spoken, contains('milimètèri'));
          expect(spoken, contains('dourou'));
          expect(spoken, contains('kèmè'));
          expect(spoken, contains('ssaba'));
          expect(spoken, contains('gnèfò'));
          expect(spoken, contains('yé'));

          // Phrase mixte Bambara + Français d'atelier CNC
          final mixed = 'Broche daminɛ sisan, machine bɛ homing kɛ.';
          final mixedSpoken =
              WaxalVoiceEngine.transcribeBambaraForFrenchTts(mixed);
          expect(mixedSpoken, contains('Broche'));
          expect(mixedSpoken, contains('machine'));
          expect(mixedSpoken, contains('homing'));
          expect(mixedSpoken, contains('daminè'));
          expect(mixedSpoken, contains('bè'));
          expect(mixedSpoken, contains('kè'));
        },
      );

      test(
        'prepareForTts sélectionne la voix de repli fr-FR et adapte le texte bambara + symboles CNC (\$H, mm/min)',
        () {
          final prep = WaxalVoiceEngine.prepareForTts(
            '**I ni ce !** Envoyez `\$H` à 500 mm/min. Mashini jɔ sisan.',
            preferredLanguageId: 'bm',
            availableVoices: const ['fr-FR', 'en-US'],
          );

          expect(prep.languageId, equals('bm'));
          expect(prep.usesPhoneticFallback, isTrue);
          expect(prep.selectedVoiceLocale, equals('fr-FR'));
          expect(prep.spokenText, contains('I ni tché'));
          expect(prep.spokenText, contains('commande H'));
          expect(prep.spokenText, contains('millimètres par minute'));
          expect(prep.spokenText, contains('djò'));
          expect(prep.spokenText.contains('*'), isFalse);
        },
      );

      test(
        'prepareForTts utilise la voix native quand elle est disponible sur l\'OS (ex. sw-KE pour Swahili)',
        () {
          final prep = WaxalVoiceEngine.prepareForTts(
            'Mashine imesimama sasa.',
            preferredLanguageId: 'sw',
            availableVoices: const ['fr-FR', 'en-US', 'sw-KE'],
          );

          expect(prep.languageId, equals('sw'));
          expect(prep.usesPhoneticFallback, isFalse);
          expect(prep.selectedVoiceLocale, equals('sw-KE'));
        },
      );
    },
  );

  group(
    'Axe 6 — Anti-hallucination, Normalisation STT (Vocal & Écrit) & Ancrage Atelier',
    () {
      test(
        'WaxalVoiceEngine.normalizeSttInput répare les termes CNC français déformés par le STT acoustique',
        () {
          final rawFrenchStt =
              "allume la proche à dix mille tr/min et fais le j'ai 54 eau mine pas le page aime 3 fluide ainsi";
          final normalized = WaxalVoiceEngine.normalizeSttInput(rawFrenchStt, activeLanguageId: 'fr');

          expect(normalized, contains('allume la broche'));
          expect(normalized, contains('G54'));
          expect(normalized, contains('homing'));
          expect(normalized, contains('palpage'));
          expect(normalized, contains('M3'));
          expect(normalized, contains('FluidNC'));
        },
      );

      test(
        'WaxalVoiceEngine.normalizeSttInput répare la dictée bambara transcrite phonétiquement en français',
        () {
          final rawBmStt = 'inicié mashini josissant d\'amener d\'habilla qu\'aimait ça va doux roux';
          final normalized = WaxalVoiceEngine.normalizeSttInput(rawBmStt, activeLanguageId: 'bm');

          expect(normalized, contains('I ni ce'));
          expect(normalized, contains('mashini'));
          expect(normalized, contains('jɔ sisan'));
          expect(normalized, contains('daminɛ'));
          expect(normalized, contains('dabila'));
          expect(normalized, contains('kɛmɛ saba'));
          expect(normalized, contains('duuru'));
        },
      );

      test(
        'isEmergencyStopRequest valide les ordres d\'arrêt d\'urgence en bambara',
        () {
          expect(isEmergencyStopRequest('jɔ sisan'), isTrue);
          expect(isEmergencyStopRequest('mashini jɔ sisan'), isTrue);
          expect(isEmergencyStopRequest('mashini dabila sisan'), isTrue);
          expect(isEmergencyStopRequest('mashini jɔ ?'), isFalse);
        },
      );

      test(
        'trailingPromptAnchor et promptDirective intègrent les garde-fous anti-hallucination atelier',
        () {
          final bm = appLanguageById('bm');
          final anchor = bm.trailingPromptAnchor();
          expect(anchor, contains('ANTI-HALLUCINATION'));
          expect(anchor, contains("français d'atelier"));
          expect(anchor, contains('imaginaire'));

          final directive = bm.promptDirective;
          expect(directive, contains("PARLER D'ATELIER"));
          expect(directive, contains('broche'));
          expect(directive, contains('homing'));
        },
      );
    },
  );

    group('Axe 7 — Synchronisation Brouillon & Rupture des Boucles de Dégénérescence LLM Local', () {
      test('findRepetitionLoop et cleanRepetitiveDegeneration stoppent net les boucles infinies de tokens', () {
        const loopHaBm = 'I ni sogoma ! Mo ni haoussa, amma mafi hanyar termiinon cikin atelairu CNC kuma ko kuma ko kuma ko kuma ko kuma ko kuma ko kuma ko';
        final detected = LocalAiAgentService.findRepetitionLoop(loopHaBm);
        expect(detected, isNotNull);
        expect(detected!.repetitions, greaterThanOrEqualTo(3));

        final cleaned = LocalAiAgentService.cleanRepetitiveDegeneration(loopHaBm);
        expect(cleaned, isNot(contains('kuma ko kuma ko')));
        expect(cleaned, endsWith('kuma ko'));

        const loopCnc = 'Verification machine cnc cnc cnc cnc cnc cnc cnc';
        final cleanedCnc = LocalAiAgentService.cleanRepetitiveDegeneration(loopCnc);
        expect(cleanedCnc, isNot(contains('cnc cnc')));
        expect(cleanedCnc, endsWith('cnc'));
      });

      test('aiPromptDraftProvider synchronise le texte saisi entre la fenêtre Forgeron IA et la page Agent IA', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(aiPromptDraftProvider), isEmpty);

        // L'opérateur commence à taper dans la fenêtre flottante
        container.read(aiPromptDraftProvider.notifier).updateDraft('Analyse le G-code de la pièce');
        expect(container.read(aiPromptDraftProvider), 'Analyse le G-code de la pièce');

        // Basculement vers la page Agent IA : le brouillon est disponible
        final fullScreenDraft = container.read(aiPromptDraftProvider);
        expect(fullScreenDraft, 'Analyse le G-code de la pièce');

        // Envoi du message : le brouillon partagé est vidé
        container.read(aiPromptDraftProvider.notifier).clear();
        expect(container.read(aiPromptDraftProvider), isEmpty);
      });

      test('SuggestedNextAction.localizedLabel et suggestions traduisent dynamiquement selon la langue active', () {
        final actions = NextBestActionEngine.compute(
          lastOp: OperationEventType.appStarted,
          machineStatus: MachineStatus.idle,
        );

        expect(actions, isNotEmpty);
        final defaultChip = actions.first;
        expect(defaultChip.label, 'État de la machine');

        // En français par défaut
        AppLocalizations.setCurrentForTest(const {});
        expect(defaultChip.localizedLabel, 'État de la machine');

        // Basculement en Haoussa (HA) : les puces se traduisent instantanément
        AppLocalizations.setCurrentForTest(kHa);
        expect(defaultChip.localizedLabel, 'Yanayin injin');

        final analyzeChip = actions.firstWhere((a) => a.id == 'analyze_program');
        expect(analyzeChip.localizedLabel, 'Bincika shirin');

        final diagChip = actions.firstWhere((a) => a.id == 'pre_machining_diag');
        expect(diagChip.localizedLabel, 'Bincike kafin sarrafawa');

        // Rétablissement de la locale de test
        AppLocalizations.setCurrentForTest(const {});
      });
    });

    group('Axe 8 — Démo METI Japan (Anglais intégral, Voix Humaine SSML, STT Offline & Dôme 5 Axes)', () {
      test('detectOperatorLanguage reconnaît "Mill a 20mm dome on aluminium" comme anglais', () {
        expect(
          LanguageDetector.detectOperatorLanguage(
            'Mill a 20mm dome on aluminium',
            fallback: 'fr',
          ),
          equals('en'),
        );
        expect(
          LanguageDetector.detectOperatorLanguage(
            'Carve a 30mm dome in brass',
            fallback: 'fr',
          ),
          equals('en'),
        );
      });

      test('normalizeSttInput répare la dictée anglaise transcrite par un moteur STT fr-FR hors ligne', () {
        expect(
          WaxalVoiceEngine.normalizeSttInput(
            'mille à 20 mm dôme en aluminium',
            activeLanguageId: 'en',
          ),
          equals('Mill a 20mm dome on aluminium'),
        );
        expect(
          WaxalVoiceEngine.normalizeSttInput(
            'mill a 20 millimeter dome on aluminum',
            activeLanguageId: 'en',
          ),
          equals('Mill a 20mm dome on aluminum'),
        );
      });

      test('prepareForTts produit une lecture vocale humaine (unités compactes, décimales, SSML et respirations)', () {
        final prepEn = WaxalVoiceEngine.prepareForTts(
          "I've prepared the 5-axis toolpath for your 20mm dome on aluminium at 400 mm/min (±0.2 mm, 45°). Tap Confirm to start?",
          preferredLanguageId: 'en',
          availableVoices: const ['fr-FR'],
        );
        expect(prepEn.languageId, equals('en'));
        expect(prepEn.spokenText, contains('20 millimeters'));
        expect(prepEn.spokenText, contains('millimeters per minute'));
        expect(prepEn.spokenText, contains('plus or minus 0.2'));
        expect(prepEn.spokenText, contains('45 degrees'));
        expect(prepEn.ssmlText, contains('<speak'));
        expect(prepEn.ssmlText, contains('<prosody'));
        expect(prepEn.conversationalChunks.length, greaterThanOrEqualTo(2));

        final prepFr = WaxalVoiceEngine.prepareForTts(
          'Parcours généré avec generate_5axis_dome pour 20mm à 0.2 mm de tolérance et 45°.',
          preferredLanguageId: 'fr',
          availableVoices: const ['fr-FR'],
        );
        expect(prepFr.spokenText, contains('20 millimètres'));
        expect(prepFr.spokenText, contains('0,2'));
        expect(prepFr.spokenText, contains('45 degrés'));
        expect(prepFr.spokenText, isNot(contains('generate_5axis_dome')));
      });

      test('Scénario bout-en-bout METI Japan : "Mill a 20mm dome on aluminium" -> G-code 5 axes -> Confirm', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            machineRepositoryProvider.overrideWithValue(_InertMachineRepository()),
            lexiconSourceProvider.overrideWithValue(
              () async => File('assets/lexicon/lexique.json').readAsString(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(aiAgentControllerProvider.notifier);
        await controller.sendUserMessage('Mill a 20mm dome on aluminium');

        final st = container.read(aiAgentControllerProvider);
        expect(st.pendingConfirmation, isNotNull);
        expect(st.pendingConfirmation!.toolName, equals('run_program'));
        expect(container.read(machiningModeProvider), equals(MachiningMode.fiveAxis));
        expect(container.read(visualizerModeProvider), equals(VisualizerMode.simulation3d));

        final gcodeState = container.read(gcodeProvider);
        expect(gcodeState.allLines, isNotEmpty);
        final rawGcode = gcodeState.allLines.join('\n');
        expect(const GcodeCritic().review(rawGcode).usable, isTrue);

        final assistantReply = st.messages.lastWhere((m) => m.role == 'assistant').text;
        expect(assistantReply, contains('5-axis'));
        expect(assistantReply, contains('20mm dome'));
        expect(assistantReply, contains('Confirm'));

        await controller.confirmPendingAction();
        final afterConfirm = container.read(aiAgentControllerProvider);
        expect(afterConfirm.pendingConfirmation, isNull);
        expect(
          afterConfirm.messages.last.text,
          contains('5-axis dome machining'),
        );
      });

      test('Anti-hallucination : présentation, homing par axe, go to, diagnostic et analyse G-code déterministes', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            machineRepositoryProvider.overrideWithValue(_InertMachineRepository()),
            lexiconSourceProvider.overrideWithValue(
              () async => File('assets/lexicon/lexique.json').readAsString(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(aiAgentControllerProvider.notifier);

        // 1. Présentation humaine en anglais sans show_popup ni dérive LLM
        await controller.sendUserMessage('Please introduce yourself');
        var st = container.read(aiAgentControllerProvider);
        expect(st.messages.last.text, contains('Forgeron'));
        expect(st.messages.last.text, contains('5-axis CNC'));

        // 2. Homing d'un axe avec bruit de dictée vocale ("Homez axis" -> "home Z axis")
        await controller.sendUserMessage('Homez axis');
        st = container.read(aiAgentControllerProvider);
        expect(st.messages.any((m) => m.toolName == 'home'), isTrue);
        expect(st.messages.last.text, contains(r'$HZ'));

        // 3. Positionnement direct ("got to y50" -> "go to y50")
        await controller.sendUserMessage('got to y50');
        st = container.read(aiAgentControllerProvider);
        expect(st.messages.any((m) => m.toolName == 'goto_position'), isTrue);
        expect(st.messages.last.text, contains('Y = 50 mm'));

        // 4. Diagnostic pré-usinage
        await controller.sendUserMessage('Run a full pre-machining diagnostic.');
        st = container.read(aiAgentControllerProvider);
        expect(st.messages.any((m) => m.toolName == 'get_diagnostics'), isTrue);
        expect(st.messages.last.text, contains('Pre-machining diagnostic complete'));

        // 5. Récupération d'appels d'outils écrits en prose ("Run the get_diagnostics function now.")
        final recovered = LocalAiAgentService.recoverTextToolCalls(
          const [
            {'text': 'Run the `get_diagnostics` function now.'},
          ],
          const {'get_diagnostics', 'analyze_gcode'},
        );
        expect(recovered.first['functionCall'], isNotNull);
        expect((recovered.first['functionCall'] as Map)['name'], equals('get_diagnostics'));
      });
    });

}
