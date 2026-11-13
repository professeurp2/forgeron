import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/backoffice_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/core/theme/forgeron_colors.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/screens/backoffice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// L'écran Backoffice doit rendre, sans exception ni débordement, avec un
/// journal réel : une chaîne IA → carte complète, un refus de garde-fou, une
/// alarme. En largeur PC (trois panneaux côte à côte) et en largeur téléphone
/// (trois onglets), dans les deux thèmes.
BackofficeBus _busWithHistory() {
  final bus = BackofficeBus();
  bus.emit(
      source: BackofficeSource.ia,
      kind: 'ia.message',
      summary: 'Message du téléphone (relais) : « Avance X de 5 »',
      turnId: 't1',
      origin: BackofficeOrigin.relais);
  bus.emit(
      source: BackofficeSource.ia,
      kind: 'ia.tour',
      summary: 'forgeron-qwen (local) → réponse livrée, outil(s) : jog_axis — 840 ms',
      details: const {'issue': 'ok', 'latence_ms': 840, 'tokens': 1200},
      turnId: 't1',
      origin: BackofficeOrigin.modele);
  bus.emit(
      source: BackofficeSource.ia,
      kind: 'ia.outil.demande',
      summary: 'Le modèle demande jog_axis',
      details: const {'outil': 'jog_axis', 'arguments': {'axis': 'X', 'distance': 5.0, 'feedrate': 500}},
      turnId: 't1',
      callId: 'jog_axis_0',
      origin: BackofficeOrigin.modele);
  bus.emit(
      source: BackofficeSource.ia,
      kind: 'ia.outil.attente',
      summary: 'Confirmation demandée à l\'opérateur pour jog_axis',
      severity: BackofficeSeverity.notice,
      details: const {'outil': 'jog_axis', 'arguments': {'axis': 'X'}, 'categorie': 'movement'},
      turnId: 't1',
      callId: 'jog_axis_0',
      origin: BackofficeOrigin.modele);
  bus.emit(
      source: BackofficeSource.ia,
      kind: 'ia.outil.confirme',
      summary: 'jog_axis confirmé depuis le téléphone',
      severity: BackofficeSeverity.notice,
      details: const {'outil': 'jog_axis'},
      turnId: 't1',
      callId: 'jog_axis_0',
      origin: BackofficeOrigin.relais);
  bus.emit(
      source: BackofficeSource.firmware,
      kind: 'firmware.tx',
      summary: 'Jog manuel : X5.000 F500',
      details: const {'commande': '\$J=G91 G21 X5.000 F500', 'outil': 'jog_axis'},
      turnId: 't1',
      callId: 'jog_axis_0',
      origin: BackofficeOrigin.relais);
  bus.emit(
      source: BackofficeSource.firmware,
      kind: 'firmware.reponse',
      summary: 'ok ← \$J=G91 G21 X5.000 F500 (11 ms)',
      details: const {'reponse': 'ok', 'latence_ms': 11, 'commande': '\$J=G91 G21 X5.000 F500'},
      turnId: 't1',
      callId: 'jog_axis_0',
      origin: BackofficeOrigin.relais);
  bus.emit(
      source: BackofficeSource.ia,
      kind: 'ia.outil.execute',
      summary: 'jog_axis → ok en 32 ms',
      details: const {'outil': 'jog_axis', 'arguments': {'axis': 'X'}, 'duree_ms': 32, 'echec': false, 'resultat': 'OK'},
      turnId: 't1',
      callId: 'jog_axis_0',
      origin: BackofficeOrigin.relais);
  bus.emit(
      source: BackofficeSource.garde,
      kind: 'garde.outil',
      summary: 'send_gcode refusé par un garde-fou : la commande « \$RST=* » modifie ou efface les réglages',
      severity: BackofficeSeverity.warning,
      details: const {'outil': 'send_gcode', 'arguments': {'gcode': '\$RST=*'}, 'echec': true},
      turnId: 't2',
      callId: 'send_gcode_1',
      origin: BackofficeOrigin.modele);
  bus.emit(
      source: BackofficeSource.firmware,
      kind: 'firmware.alarme',
      summary: 'ALARME 1 — Fin de course matérielle',
      severity: BackofficeSeverity.critical,
      details: const {'code': 1, 'position_perdue': true});
  bus.emit(
      source: BackofficeSource.veilleur,
      kind: 'veilleur.ia',
      summary: 'Diagnostic IA sur « ALARME 1 » en 1 900 ms : dégage l\'axe X puis refais le homing',
      severity: BackofficeSeverity.notice,
      details: const {'type': 'ALARME 1', 'latence_ms': 1900, 'reponse': 'dégage l\'axe X'},
      origin: BackofficeOrigin.veilleur);
  return bus;
}

/// Le serveur local de l'atelier : qwen pilote, gemma installé et chargé mais
/// pas encore branché pour les images.
LocalModelsReport _localModels() => const LocalModelsReport(
      url: 'http://192.168.0.42:11434',
      reachable: true,
      pilot: 'forgeron-qwen',
      models: [
        LocalModelStatus(
          OllamaModel('forgeron-qwen:latest', supportsTools: true, contextTokens: 16384),
          role: 'pilote',
        ),
        LocalModelStatus(
          OllamaModel('gemma3n:latest', supportsTools: false, contextTokens: 16384, supportsVision: true),
          loaded: OllamaLoadedModel('gemma3n:latest', size: 4000000000, sizeVram: 4000000000),
          role: 'aucun',
        ),
      ],
    );

/// Le conteneur de la portée montée : lu APRÈS le pump, et jamais gardé au-delà
/// du test (la portée se ferme avec l'arbre, ses minuteries avec elle).
ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(BackofficeScreen)));

Future<void> _pump(WidgetTester tester,
    {required Size size, required ForgeronColorPalette palette, bool standalone = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isSimulationModeProvider.overrideWith((ref) => true),
        machineStateProvider.overrideWith(
            (ref) => Stream.value(const MachineState(status: MachineStatus.idle))),
        backofficeBusProvider.overrideWith((ref) => _busWithHistory()),
        aiJournalSummaryProvider.overrideWith((ref) async => null),
        localModelsReportProvider.overrideWith((ref) async => _localModels()),
      ],
      child: ForgeronTheme(
        colors: palette,
        child: MaterialApp(
          home: Scaffold(body: BackofficeScreen(standalone: standalone)),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('PC : trois panneaux, chiffres tirés du journal, sans débordement',
      (tester) async {
    await _pump(tester, size: const Size(1600, 1000), palette: forgeronDarkColors);
    expect(tester.takeException(), isNull);

    expect(find.text('BACKOFFICE'), findsOneWidget);
    expect(find.text('CHAÎNES IA → CARTE'), findsOneWidget);
    expect(find.text('SANTÉ'), findsOneWidget);
    // KPI : 1 tour IA, 1 appel d'outil, 1 commande IA → carte.
    expect(find.text('TOURS IA'), findsOneWidget);
    expect(find.text('IA → CARTE'), findsOneWidget);
    // Le journal montre la chaîne et le garde-fou.
    expect(find.textContaining('jog_axis confirmé depuis le téléphone'), findsOneWidget);
    // Dans le journal ET comme étape de la carte de chaîne send_gcode.
    expect(find.textContaining('refusé par un garde-fou'), findsNWidgets(2));
    expect(find.textContaining('ALARME 1'), findsWidgets);
    // Les chaînes : jog_axis (ok) et send_gcode (refusée).
    expect(find.text('jog_axis'), findsWidgets);
    expect(find.text('send_gcode'), findsWidgets);
    expect(find.text('REFUSÉE'), findsOneWidget);
    expect(find.text('OK'), findsWidgets);
  });

  testWidgets('PC : déplier une ligne montre le détail et le lien vers la chaîne',
      (tester) async {
    await _pump(tester, size: const Size(1600, 1000), palette: forgeronLightColors);
    await tester.tap(find.textContaining('jog_axis confirmé depuis le téléphone'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('ia.outil.confirme'), findsOneWidget);
    expect(find.textContaining('voir toute la chaîne jog_axis_0'), findsOneWidget);

    // Filtrer sur la chaîne : seuls ses événements restent dans le journal
    // (la carte de chaîne send_gcode, à droite, garde son étape).
    await tester.tap(find.textContaining('voir toute la chaîne jog_axis_0'));
    await tester.pump();
    expect(find.textContaining('refusé par un garde-fou'), findsOneWidget);
    expect(find.textContaining('Diagnostic IA sur'), findsNothing);
    expect(find.textContaining('chaîne jog_axis_0'), findsWidgets);
  });

  testWidgets('téléphone : trois onglets, le journal d\'abord', (tester) async {
    await _pump(tester,
        size: const Size(400, 850), palette: forgeronDarkColors, standalone: true);
    expect(tester.takeException(), isNull);
    expect(find.text('JOURNAL'), findsOneWidget);
    expect(find.text('IA → CARTE'), findsWidgets);
    // Le plus récent d'abord : la première ligne est visible sans défiler.
    expect(find.textContaining('Diagnostic IA sur'), findsOneWidget);

    await tester.tap(find.text('SANTÉ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('MODÈLE'), findsOneWidget);
    expect(find.text('CARTE FLUIDNC'), findsOneWidget);
  });

  testWidgets('santé : gemma installé apparaît, « Brancher » le règle comme modèle d\'images',
      (tester) async {
    await _pump(tester, size: const Size(1600, 1100), palette: forgeronDarkColors);
    expect(find.text('MODÈLES LOCAUX (OLLAMA)'), findsOneWidget);
    expect(find.text('forgeron-qwen:latest'), findsOneWidget);
    expect(find.text('gemma3n:latest'), findsOneWidget);
    expect(find.text('PILOTE'), findsOneWidget);
    // 4 000 000 000 octets = 3,7 Gio : le chiffre affiché est celui-là.
    expect(find.textContaining('3.7 Go en VRAM'), findsOneWidget);
    expect(find.text('BRANCHER'), findsOneWidget);

    final container = _containerOf(tester);
    await tester.tap(find.text('BRANCHER'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(container.read(aiAgentSettingsProvider).localVisionModel, 'gemma3n:latest');
    expect(container.read(backofficeBusProvider).last.kind, 'systeme.reglage');
  });

  testWidgets('journal vide : message d\'attente, aucun chiffre inventé', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSimulationModeProvider.overrideWith((ref) => true),
          machineStateProvider.overrideWith((ref) => const Stream<MachineState>.empty()),
          backofficeBusProvider.overrideWith((ref) => BackofficeBus()),
          aiJournalSummaryProvider.overrideWith((ref) async => null),
          localModelsReportProvider.overrideWith((ref) async =>
              const LocalModelsReport(url: 'http://localhost:11434', reachable: false, configured: false)),
        ],
        child: ForgeronTheme(
          colors: forgeronDarkColors,
          child: const MaterialApp(home: Scaffold(body: BackofficeScreen())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Aucun événement pour l\'instant'), findsOneWidget);
    expect(find.text('Aucun appel d\'outil enregistré.'), findsOneWidget);
    expect(find.text('aucun journal'), findsOneWidget);
    expect(find.textContaining('rien ne répond sur http://localhost:11434'), findsOneWidget);
  });
}
