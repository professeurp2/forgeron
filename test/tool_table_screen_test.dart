import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/program_tools_provider.dart';
import 'package:forgeron/core/utils/gcode_tool_extractor.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/screens/tool_table_screen.dart';

import 'support/fake_machine_repository.dart';
import 'package:forgeron/application/providers/di_providers.dart';

/// Le magasin d'outils desktop affichait douze outils écrits en dur — dont un
/// « BRIS DÉTECTÉ » et un « USURE : 85 % » — avec un bouton qui envoyait
/// `T.. M6` pour des outils que la machine n'a jamais eus. L'application ne
/// tient aucune table d'outils : la seule source est le G-code chargé.
Future<void> _pump(WidgetTester tester, List<ProgramTool> tools) async {
  // Côté long : l'écran est un split view, il lui faut de la place.
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        programToolsProvider.overrideWithValue(tools),
        machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
        machineStateProvider
            .overrideWith((ref) => Stream.value(const MachineState())),
      ],
      child: const MaterialApp(home: Scaffold(body: ToolTableScreen())),
    ),
  );
  await tester.pump();
}

void main() {
  const decrit = ProgramTool(
    number: 1,
    changeLines: [4, 120],
    description: '6MM CRB 2FL 19 LOC',
    operation: 'Fraisage debauche1',
    diameterMm: 6,
    flutes: 2,
    cuttingLengthMm: 19,
    material: 'CRB',
    spindleSpeed: 12000,
    shape: ToolShape.flatEndMill,
  );

  const nu = ProgramTool(number: 7, changeLines: [300]);

  testWidgets('sans programme, il le dit au lieu d\'inventer un magasin',
      (tester) async {
    await _pump(tester, const []);

    expect(find.text('AUCUN PROGRAMME CHARGÉ'), findsOneWidget);
    expect(find.text('0 outil'), findsOneWidget);
    // Les anciens outils fictifs ne doivent plus exister nulle part.
    expect(find.textContaining('FORET CARBURE'), findsNothing);
    expect(find.textContaining('BRIS DÉTECTÉ'), findsNothing);
  });

  testWidgets('les outils affichés viennent du G-code chargé', (tester) async {
    await _pump(tester, const [decrit, nu]);

    expect(find.text('2 outils'), findsOneWidget);
    expect(find.text('T1'), findsWidgets);
    // Le descriptif brut du post, pas un nom d'outil reconstitué.
    expect(find.text('6MM CRB 2FL 19 LOC'), findsWidgets);
    expect(find.text('Fraisage debauche1'), findsWidgets);
    // Caractéristiques extraites, affichées telles quelles.
    expect(find.text('DIAMÈTRE (D)'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
  });

  testWidgets('un outil sans descriptif ne reçoit aucune caractéristique',
      (tester) async {
    await _pump(tester, const [nu]);

    expect(find.text('descriptif absent du programme'), findsWidgets);
    expect(
        find.textContaining(
            'Le programme ne décrit pas cet outil'),
        findsOneWidget);
    // Pas de fiche technique fabriquée pour combler le vide.
    expect(find.text('CARACTÉRISTIQUES'), findsNothing);
    expect(find.text('DIAMÈTRE (D)'), findsNothing);
  });

  testWidgets('le régime broche est présenté comme une demande du programme',
      (tester) async {
    await _pump(tester, const [decrit]);

    expect(find.textContaining('Le programme demande S12000'), findsOneWidget);
    expect(find.textContaining('en tout-ou-rien elle est ignorée'),
        findsOneWidget);
  });

  testWidgets('aucun onglet usure ni durée de vie — rien ne les alimente',
      (tester) async {
    await _pump(tester, const [decrit]);

    expect(find.textContaining('USURE'), findsNothing);
    expect(find.textContaining('DURÉE DE VIE'), findsNothing);
    expect(find.textContaining('PIÈCES USINÉES'), findsNothing);
  });
}
