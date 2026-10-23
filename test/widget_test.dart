import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/streaming_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/widgets/safety_banner.dart';

/// Tests de la bannière de sécurité — la seule chose qui rend visibles
/// deux défaillances jusque-là totalement silencieuses.
Future<void> _pump(WidgetTester tester, List<Override> overrides) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Évite d'instancier la vraie connexion machine (Timers heartbeat) —
        // la bannière lit désormais le statut pour le cas ALARME.
        machineStateProvider
            .overrideWith((ref) => Stream.value(const MachineState())),
        ...overrides,
      ],
      child: const MaterialApp(
        home: Scaffold(body: SafetyBanner()),
      ),
    ),
  );
}

void main() {
  testWidgets('reste invisible quand tout va bien', (tester) async {
    await _pump(tester, []);

    expect(find.byType(Icon), findsNothing);
    expect(find.textContaining('ARRÊT'), findsNothing);
    expect(find.textContaining('SUSPENDU'), findsNothing);
  });

  testWidgets('alerte quand l\'arrêt d\'urgence n\'a PAS été transmis',
      (tester) async {
    await _pump(tester, [
      estopFailedProvider.overrideWith((ref) => true),
    ]);

    expect(find.text('ARRÊT D\'URGENCE NON TRANSMIS'), findsOneWidget);
    // Le message doit dire sans ambiguïté que la machine tourne encore.
    expect(find.textContaining('n\'est PAS arrêtée'), findsOneWidget);
  });

  testWidgets('alerte quand le flux est bloqué, en donnant la raison',
      (tester) async {
    await _pump(tester, [
      streamStallProvider.overrideWith((ref) => 'Aucun acquittement depuis 2 s'),
    ]);

    expect(find.text('FLUX SUSPENDU'), findsOneWidget);
    expect(find.textContaining('Aucun acquittement depuis 2 s'), findsOneWidget);
  });

  testWidgets('l\'E-STOP non transmis prime sur le blocage de flux',
      (tester) async {
    await _pump(tester, [
      estopFailedProvider.overrideWith((ref) => true),
      streamStallProvider.overrideWith((ref) => 'blocage'),
    ]);

    expect(find.text('ARRÊT D\'URGENCE NON TRANSMIS'), findsOneWidget);
    expect(find.text('FLUX SUSPENDU'), findsNothing);
  });

  testWidgets('l\'opérateur peut acquitter l\'alerte', (tester) async {
    await _pump(tester, [
      estopFailedProvider.overrideWith((ref) => true),
    ]);
    expect(find.text('ARRÊT D\'URGENCE NON TRANSMIS'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text('ARRÊT D\'URGENCE NON TRANSMIS'), findsNothing);
  });
}
