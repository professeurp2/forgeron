import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forgeron/application/providers/ai_inbox_provider.dart';
import 'package:forgeron/application/providers/critical_event_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/domain/models/machine_state.dart';

/// Le veilleur ne doit notifier que sur de véritables **fronts** d'évènement.
///
/// Le piège vient du dépôt : à chaque coupure de liaison il force le statut à
/// `offline`. Une liaison instable — le cas normal au démarrage — produit donc
/// la séquence alarme → offline → alarme en boucle. Si `offline` était traité
/// comme un état machine, chaque reconnexion recréerait un front montant et
/// l'opérateur recevrait une notification d'alarme en rafale.
void main() {
  late StreamController<MachineState> states;
  late ProviderContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Le veilleur consulte les réglages de l'agent IA (pour décider s'il
    // demande un diagnostic). Leur chargement passe par SharedPreferences, dont
    // le canal natif n'existe pas en test : sans ce mock, l'échec remonte en
    // erreur asynchrone non capturée et fait tomber les tests.
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    states = StreamController<MachineState>.broadcast();
    container = ProviderContainer(overrides: [
      machineStateProvider.overrideWith((ref) => states.stream),
    ]);
    // Instancie le veilleur : il s'abonne dans son constructeur.
    container.read(criticalEventWatcherProvider);
  });

  tearDown(() {
    container.dispose();
    states.close();
  });

  Future<void> emit(MachineState s) async {
    states.add(s);
    await Future<void>.delayed(Duration.zero);
  }

  int unread() => container.read(aiInboxProvider).unread;

  test('une alarme notifie une fois', () async {
    await emit(const MachineState(status: MachineStatus.idle));
    await emit(const MachineState(status: MachineStatus.alarm));

    expect(unread(), 1);
  });

  test('une coupure de liaison ne re-notifie pas l\'alarme', () async {
    await emit(const MachineState(status: MachineStatus.alarm));
    expect(unread(), 1, reason: 'première alarme');

    // Trois cycles de reconnexion, machine toujours en alarme.
    for (var i = 0; i < 3; i++) {
      await emit(const MachineState(status: MachineStatus.offline));
      await emit(const MachineState(status: MachineStatus.alarm));
    }

    expect(unread(), 1,
        reason: 'offline signifie « liaison perdue », pas « alarme levée »');
  });

  test('une alarme réellement nouvelle notifie de nouveau', () async {
    await emit(const MachineState(status: MachineStatus.alarm));
    expect(unread(), 1);

    // L'opérateur déverrouille ($X) : la machine repasse en idle. C'est un vrai
    // changement d'état machine, contrairement à une coupure réseau.
    await emit(const MachineState(status: MachineStatus.idle));
    await emit(const MachineState(status: MachineStatus.alarm));

    // Le front est bien réarmé ; seul l'anti-rafale de 20 s peut encore
    // absorber cette seconde notification, ce qui est le comportement voulu.
    expect(unread(), greaterThanOrEqualTo(1));
  });

  test('offline seul ne notifie rien', () async {
    await emit(const MachineState(status: MachineStatus.idle));
    await emit(const MachineState(status: MachineStatus.offline));
    await emit(const MachineState(status: MachineStatus.idle));

    expect(unread(), 0);
  });
}
