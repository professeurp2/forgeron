import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/backoffice_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/services/chat_relay.dart';
import 'package:forgeron/core/theme/app_theme.dart';
import 'package:forgeron/core/theme/forgeron_colors.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/presentation/screens/cowork_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_cowork.dart';

/// L'écran Coworking, des deux côtés : la tablette reliée (poste du PC,
/// simulateur, discussion, STOP à deux chemins) et le PC hôte (session,
/// participants, règles).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeCoworkClient client;

  Future<void> pump(WidgetTester tester,
      {required Size size, required bool guest, RemoteChatState? state}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isSimulationModeProvider.overrideWith((ref) => true),
        machineStateProvider.overrideWith((ref) => Stream.value(const MachineState())),
        backofficeBusProvider.overrideWith((ref) => BackofficeBus()),
        coworkLocalAddressesProvider.overrideWith((ref) async => ['192.168.0.10']),
        fakeCoworkOverride(state ?? const RemoteChatState(), onCreate: (c) => client = c),
      ],
      child: ForgeronTheme(
        colors: forgeronDarkColors,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: CoworkScreen(standalone: true, forceGuest: guest),
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('iPad relié : le poste du PC, les participants et la discussion côte à côte',
      (tester) async {
    await pump(tester, size: const Size(1180, 820), guest: true, state: coworkSessionState());
    expect(tester.takeException(), isNull);

    // Présence et liaison.
    expect(find.textContaining('Relié à PC-ATELIER'), findsOneWidget);
    // Le poste du PC : statut, cotes réelles, programme.
    expect(find.text('RUN'), findsOneWidget);
    expect(find.text('12.345'), findsOneWidget);
    expect(find.text('15.50°'), findsOneWidget);
    expect(find.text('Ligne 420 / 2970'), findsOneWidget);
    expect(find.text('14 %'), findsOneWidget);
    expect(find.text('JUMEAU'), findsOneWidget);
    expect(find.textContaining('0.12 mm'), findsOneWidget);
    // La discussion partagée et la confirmation en attente.
    expect(find.text('Où en est le dôme ?'), findsOneWidget);
    expect(find.text('Action en attente de confirmation'), findsOneWidget);
    // Pas d'onglets à cette largeur : les deux volets sont visibles.
    expect(find.text('POSTE'), findsNothing);
  });

  testWidgets('l\'invité pilote le simulateur du PC par l\'écran', (tester) async {
    await pump(tester, size: const Size(1180, 820), guest: true, state: coworkSessionState());

    for (final label in ['Arrêter le jumeau', '×50', 'Remettre à zéro']) {
      await tester.ensureVisible(find.text(label));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(client.simCalls, [('stop_follow', null), ('speed', 50), ('reset', null)]);
  });

  testWidgets('STOP : l\'écran dit quel chemin a arrêté la machine', (tester) async {
    await pump(tester, size: const Size(1180, 820), guest: true, state: coworkSessionState());
    await tester.tap(find.text('STOP'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(client.stops, 1);
    expect(find.text('Arrêt d\'urgence transmis à la carte par le PC.'), findsOneWidget);
  });

  testWidgets('téléphone relié : deux onglets, le poste d\'abord', (tester) async {
    await pump(tester, size: const Size(390, 844), guest: true, state: coworkSessionState());
    expect(tester.takeException(), isNull);
    expect(find.text('POSTE'), findsOneWidget);
    expect(find.text('DISCUSSION'), findsOneWidget);
    expect(find.text('12.345'), findsOneWidget);

    await tester.tap(find.text('DISCUSSION'));
    // Le voyant de liaison pulse en continu : pas de pumpAndSettle ici.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Où en est le dôme ?'), findsOneWidget);
  });

  testWidgets('pas encore d\'état du poste : des squelettes, pas des zéros', (tester) async {
    await pump(tester,
        size: const Size(1180, 820),
        guest: true,
        state: const RemoteChatState(
            status: RemoteChatStatus.connected, selfId: 'invite-1', hostName: 'PC'));
    expect(find.text('En attente de l\'état du poste…'), findsOneWidget);
    expect(find.text('0.000'), findsNothing);
  });

  testWidgets('invité non relié : le formulaire, avec l\'erreur du PC', (tester) async {
    await pump(tester,
        size: const Size(820, 1180),
        guest: true,
        state: const RemoteChatState(error: 'Code de liaison incorrect.'));
    expect(tester.takeException(), isNull);
    expect(find.text('Nom de cet appareil'), findsOneWidget);
    expect(find.text('Code de liaison incorrect.'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
  });

  testWidgets('hôte : session fermée, règles affichées, aucun invité inventé', (tester) async {
    await pump(tester, size: const Size(1600, 900), guest: false);
    expect(tester.takeException(), isNull);
    expect(find.text('FERMÉE'), findsOneWidget);
    expect(find.text('Ouvrir la session'), findsOneWidget);
    expect(find.text('La session est fermée.'), findsOneWidget);
    expect(find.text('Commander un axe par le lien : jamais'), findsOneWidget);
    expect(find.text('Rien encore.'), findsOneWidget);
  });
}
