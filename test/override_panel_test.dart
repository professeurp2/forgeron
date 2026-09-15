import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/widgets/override_panel.dart';

import 'support/fake_machine_repository.dart';

/// Le panneau de corrections est désormais partagé entre le mobile et le
/// tableau de bord desktop, dont le bandeau droit ne fait que 320 dp de large.
/// Ces tests verrouillent les deux choses qui comptent : il tient dans cette
/// largeur, et il affiche la correction **renvoyée par le contrôleur**
/// (champ `Ov:`), jamais un compteur local qui mentirait si la machine
/// plafonnait ou refusait la commande.
void main() {
  late FakeMachineRepository repo;

  Future<void> pump(
    WidgetTester tester, {
    List<int> overrides = const [100, 100, 100],
    double width = 296, // largeur utile du bandeau droit desktop (320 - marges)
    bool dense = false,
  }) async {
    repo = FakeMachineRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineRepositoryProvider.overrideWithValue(repo),
          machineStateProvider.overrideWith(
              (ref) => Stream.value(MachineState(overrides: overrides))),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child:
                  SizedBox(width: width, child: OverridePanel(dense: dense)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('tient dans le bandeau droit du desktop', (tester) async {
    await pump(tester);

    // Un débordement lèverait une exception de rendu ; l'absence d'erreur ici
    // est l'assertion. On vérifie au passage que tout est bien là.
    expect(find.text('CORRECTIONS'), findsOneWidget);
    expect(find.text('−10'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('25 %'), findsOneWidget);
  });

  testWidgets('affiche la correction renvoyée par le contrôleur',
      (tester) async {
    await pump(tester, overrides: const [80, 50, 100]);

    expect(find.text('80 %'), findsOneWidget);
    // Deux fois : la valeur courante des rapides, et le cran « 50 % » qui se
    // trouve du coup sélectionné.
    expect(find.text('50 %'), findsNWidgets(2));
  });

  testWidgets('les boutons envoient les commandes temps réel GRBL',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('+10'));
    await tester.tap(find.text('−1'));
    await tester.tap(find.text('25 %'));
    await tester.pump();

    expect(repo.sentRaw, ['\x91', '\x94', '\x97']);
    // Rien ne doit partir en G-code : ces corrections sont des commandes
    // temps réel, elles doublent la file d'envoi au lieu d'y entrer.
    expect(repo.sentGCode, isEmpty);
  });

  testWidgets('à 100 %, le bouton de retour à 100 % ne sert à rien',
      (tester) async {
    await pump(tester);

    final reset = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.restart_alt_rounded));
    expect(reset.onPressed, isNull);
  });

  testWidgets('correction en cours : le retour à 100 % devient actif',
      (tester) async {
    await pump(tester, overrides: const [120, 100, 100]);

    final reset = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.restart_alt_rounded));
    expect(reset.onPressed, isNotNull);
  });

  testWidgets('en densité desktop : à plat, compact, et toujours pilotable',
      (tester) async {
    await pump(tester, dense: true, overrides: const [120, 50, 100]);

    // Pas de carte ni de titre : le bandeau droit fournit déjà les deux.
    expect(find.text('CORRECTIONS'), findsNothing);
    expect(find.text('AVANCE'), findsOneWidget);
    expect(find.text('120 %'), findsOneWidget);
    // Crans de rapides sans le « % » : la valeur est déjà au-dessus.
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.text('+10'));
    await tester.pump();
    expect(repo.sentRaw, ['\x91']);
  });

  testWidgets('la densité desktop tient dans une section du bandeau',
      (tester) async {
    // Rendu dans la place que lui laisse le bandeau droit, entre la
    // progression et les actions rapides. Un débordement lèverait ici.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineRepositoryProvider
              .overrideWithValue(FakeMachineRepository()),
          machineStateProvider
              .overrideWith((ref) => Stream.value(const MachineState())),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 296,
              height: 130,
              child: OverridePanel(dense: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('RAPIDES'), findsOneWidget);
  });
}
