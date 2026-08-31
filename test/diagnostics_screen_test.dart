import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/core/theme/forgeron_colors.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/screens/diagnostics_screen.dart';
import 'package:forgeron/presentation/screens/mobile_screens.dart'
    show KinematicsTable;

/// L'écran Diagnostics desktop affichait des valeurs inventées (12 ms de
/// latence, 58 °C, 42 % de RAM, X à 160 pas/mm) et n'avait jamais été migré
/// vers le thème dynamique. Ces tests verrouillent les deux corrections : il
/// rend dans les deux thèmes, et il n'annonce plus de mesure qu'il n'a pas.
Future<void> _pumpDiagnostics(
  WidgetTester tester, {
  required ForgeronColorPalette palette,
}) async {
  // Côté court ≥ 1024 dp → ResponsiveLayout choisit la branche desktop.
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Mode simulation : tout le graphe (repo machine, config, firmware,
        // télémétrie) bascule sur les mocks — aucune socket ouverte.
        isSimulationModeProvider.overrideWith((ref) => true),
        machineStateProvider
            .overrideWith((ref) => Stream.value(const MachineState())),
      ],
      child: ForgeronTheme(
        colors: palette,
        child: const MaterialApp(
          home: Scaffold(body: DiagnosticsScreen()),
        ),
      ),
    ),
  );
  // Plusieurs frames courtes plutôt qu'une longue : SharedPreferences doit
  // répondre avant que le repository mock ne lance son délai de 400 ms, et on
  // reste sous la seconde pour ne pas armer le tick périodique de télémétrie.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('rend sans exception en thème sombre', (tester) async {
    await _pumpDiagnostics(tester, palette: forgeronDarkColors);

    expect(tester.takeException(), isNull);
    expect(find.text('GPIO & CAPTEURS (LIVE)'), findsOneWidget);
    expect(find.text('TÉLÉMÉTRIE RÉSEAU'), findsOneWidget);
  });

  testWidgets('rend sans exception en thème clair', (tester) async {
    await _pumpDiagnostics(tester, palette: forgeronLightColors);

    expect(tester.takeException(), isNull);
    expect(find.text('GPIO & CAPTEURS (LIVE)'), findsOneWidget);
  });

  testWidgets("la latence n'invente plus de valeur hors connexion",
      (tester) async {
    await _pumpDiagnostics(tester, palette: forgeronDarkColors);

    expect(find.text('LATENCE'), findsOneWidget);

    // Le grand chiffre de latence (police 48) affichait « 12 » en dur, quel que
    // soit l'état de la liaison. Il suit désormais networkStatsProvider : on
    // vérifie sur le widget lui-même, pas sur le texte « 12 » qui existe aussi
    // comme numéro de ligne dans le visualiseur YAML voisin.
    final bigNumber = tester.widgetList<Text>(find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontSize == 48));
    expect(bigNumber, hasLength(1));
    expect(bigNumber.single.data, isNot('12'));
  });

  testWidgets('les métriques non rapportées par FluidNC sont marquées « — »',
      (tester) async {
    await _pumpDiagnostics(tester, palette: forgeronDarkColors);

    // RAM / uptime / RSSI ne sont pas dans le protocole FluidNC standard :
    // trois tirets, et non « 42 % », « 14h 22m », « -64 dBm ».
    expect(find.text('42%'), findsNothing);
    expect(find.text('14h 22m'), findsNothing);
    expect(find.text('-64 dBm'), findsNothing);
    expect(find.text('—'), findsAtLeastNWidgets(3));
  });

  testWidgets('la cinématique vient de la carte, pas de constantes',
      (tester) async {
    await _pumpDiagnostics(tester, palette: forgeronDarkColors);

    // Le tableau partagé avec le mobile lit le config.yaml de la carte (ici
    // celui du mock) au lieu des constantes qui étaient écrites dans l'écran.
    expect(find.byType(KinematicsTable), findsOneWidget);
  });
}
