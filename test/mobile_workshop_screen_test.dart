import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/streaming_provider.dart';
import 'package:forgeron/application/providers/ui_state_provider.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/widgets/mobile/mobile_workshop_screen.dart';

import 'support/fake_machine_repository.dart';

/// Le mode atelier masque toute l'application : plus de barre de navigation,
/// plus de FAB d'arrêt d'urgence. Ce qu'il affiche doit donc se suffire —
/// alertes de sécurité comprises — et son gros bouton STOP doit être un vrai
/// arrêt d'urgence, pas un `reset()` qui laisse la file d'envoi se vider dans
/// une carte qui vient de redémarrer.
void main() {
  late FakeMachineRepository repo;
  late ProviderContainer container;

  Future<void> pumpWorkshop(WidgetTester tester,
      {bool linkUp = true}) async {
    // Écran de téléphone : le pupitre est dimensionné pour du 360 dp.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    repo = FakeMachineRepository(sendSucceeds: linkUp);
    final overrides = [
      machineRepositoryProvider.overrideWithValue(repo),
      machineStateProvider
          .overrideWith((ref) => Stream.value(const MachineState())),
    ];
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MobileWorkshopScreen()),
    ));
    await tester.pump();
  }

  testWidgets('le STOP géant passe par le contrôleur d\'arrêt d\'urgence',
      (tester) async {
    await pumpWorkshop(tester);

    await tester.tap(find.text('STOP'));
    await tester.pump();

    expect(repo.emergencyStopCalls, 1);
    expect(repo.resetCalls, 0,
        reason: 'reset() envoie le Ctrl-X sans purger la file d\'envoi');
    expect(container.read(streamingProvider), isFalse);
  });

  testWidgets('un arrêt non transmis s\'affiche dans le pupitre lui-même',
      (tester) async {
    await pumpWorkshop(tester, linkUp: false);

    await tester.tap(find.text('STOP'));
    await tester.pump();

    // Sans le bandeau embarqué, cette alerte n'existait nulle part en mode
    // atelier : l'opérateur repartait en croyant la machine arrêtée.
    expect(find.text('ARRÊT D\'URGENCE NON TRANSMIS'), findsOneWidget);
  });

  testWidgets('la croix rend la main à la navigation normale', (tester) async {
    await pumpWorkshop(tester);
    container.read(isWorkshopModeProvider.notifier).state = true;

    await tester.tap(find.byIcon(Icons.close_fullscreen_rounded));
    await tester.pump();

    expect(container.read(isWorkshopModeProvider), isFalse);
  });
}
