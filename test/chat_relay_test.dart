import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/backoffice_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/providers/simulation_provider.dart';
import 'package:forgeron/application/services/chat_relay.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

Future<void> _until(bool Function() ok, {String? what}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) fail('délai dépassé : ${what ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

ProviderContainer _device(FakeMachineRepository repo) {
  final c = ProviderContainer(overrides: [
    machineRepositoryProvider.overrideWithValue(repo),
    lexiconSourceProvider.overrideWithValue(
        () async => File('assets/lexicon/lexique.json').readAsString()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('protocole', () {
    test('un instantané se relit à l\'identique, étape en cours comprise', () {
      final running = AiChatMessage.toolStarted('home', const {'axes': 'XYZ'});
      final state = AiChatState(
        messages: [
          AiChatMessage(role: 'user', text: 'Fais le homing', timestamp: DateTime(2026, 10, 29)),
          running,
        ],
        isProcessing: true,
        streamingText: 'Je lance…',
        specialists: const ['mouvement'],
        pendingConfirmation: const AiPendingToolCall(
            id: '1', toolName: 'home', input: {'axes': 'XYZ'}),
      );
      final snap = ChatRelayProtocol.parseSnapshot(ChatRelayProtocol.snapshot(state))!;
      expect(snap.messages.first.text, 'Fais le homing');
      expect(snap.messages.last.isRunningTool, isTrue,
          reason: 'une étape en cours ne doit pas passer pour interrompue');
      expect(snap.processing, isTrue);
      expect(snap.streaming, 'Je lance…');
      expect(snap.specialists, ['mouvement']);
      expect(snap.pendingTool, 'home');
      expect(snap.pendingInput, {'axes': 'XYZ'});
    });

    test('code de liaison : 6 chiffres', () {
      for (var i = 0; i < 20; i++) {
        expect(ChatRelayProtocol.newPairingCode(), matches(RegExp(r'^\d{6}$')));
      }
    });
  });

  group('liaison réelle sur la boucle locale', () {
    late ProviderContainer pc;
    late ProviderContainer phone;
    late FakeMachineRepository pcRepo;
    late FakeMachineRepository phoneRepo;

    setUp(() async {
      pcRepo = FakeMachineRepository();
      pc = _device(pcRepo);
      phoneRepo = FakeMachineRepository();
      phone = _device(phoneRepo);
      await pc.read(lexiconLoadProvider.future);
      await pc.read(chatRelayHostProvider.notifier).start();
      addTearDown(() => pc.read(chatRelayHostProvider.notifier).stop());
      expect(pc.read(chatRelayHostProvider).running, isTrue,
          reason: pc.read(chatRelayHostProvider).error);
    });

    test('mauvais code : refusé', () async {
      final client = phone.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', '000000x');
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.refused,
          what: 'refus');
      expect(pc.read(chatRelayHostProvider).clients, 0);
    });

    test('bon code : le téléphone voit le fil du PC et confirme l\'action', () async {
      final client = phone.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', pc.read(chatRelayHostProvider).code!);
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.connected,
          what: 'liaison');

      await client.send('Allume la broche');
      await _until(() => phone.read(remoteChatClientProvider).snapshot.pendingTool != null,
          what: 'carte de confirmation relayée');
      expect(pcRepo.sentGCode, isEmpty, reason: 'rien ne part avant le geste');

      client.confirm();
      await _until(() => pcRepo.sentGCode.isNotEmpty, what: 'exécution sur le PC');
      await _until(() => phone.read(remoteChatClientProvider).snapshot.pendingTool == null,
          what: 'carte refermée côté téléphone');
    });

    test('un arrêt d\'urgence tapé sur le téléphone ne passe pas par le PC', () async {
      final client = phone.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', pc.read(chatRelayHostProvider).code!);
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.connected,
          what: 'liaison');

      final local = await client.send('Arrêt d\'urgence !');
      expect(local, isTrue);
      await _until(() => phoneRepo.emergencyStopCalls > 0,
          what: 'arrêt exécuté par le téléphone');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(pcRepo.emergencyStopCalls, 0, reason: 'le PC n\'a rien exécuté');
      expect(pc.read(aiAgentControllerProvider).messages, isEmpty,
          reason: 'le PC n\'a rien reçu');
    });
  });

  // ── Ce que le backoffice voit du relais, des DEUX côtés ───────────────────
  //
  // Dans ce fichier et pas dans un fichier à part : le relais écoute un port
  // fixe (8767), et deux fichiers de test tournent en parallèle — le second
  // trouverait le port pris.
  group('backoffice du relais', () {
    late ProviderContainer pc;
    late ProviderContainer phone;
    late FakeMachineRepository pcRepo;

    setUp(() async {
      pcRepo = FakeMachineRepository();
      pc = _device(pcRepo);
      phone = _device(FakeMachineRepository());
      await pc.read(lexiconLoadProvider.future);
      await pc.read(chatRelayHostProvider.notifier).start();
      addTearDown(() => pc.read(chatRelayHostProvider.notifier).stop());
      expect(pc.read(chatRelayHostProvider).running, isTrue,
          reason: pc.read(chatRelayHostProvider).error);
    });

    List<String> kinds(ProviderContainer c) =>
        c.read(backofficeBusProvider).map((e) => e.kind).toList();

    test('démarrage, refus d\'un mauvais code, puis liaison', () async {
      expect(kinds(pc), contains('relais.demarre'));

      final client = phone.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', '000000x');
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.refused);
      await _until(() => kinds(pc).contains('relais.refus'), what: 'refus tracé côté PC');
      expect(pc.read(backofficeBusProvider).lastWhere((e) => e.kind == 'relais.refus').severity,
          BackofficeSeverity.warning);
      expect(kinds(phone), contains('relais.client.refus'));

      await client.connect('127.0.0.1', pc.read(chatRelayHostProvider).code!);
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.connected);
      await _until(() => kinds(pc).contains('relais.liaison'), what: 'liaison tracée');
      final liaison = pc.read(backofficeBusProvider).lastWhere((e) => e.kind == 'relais.liaison');
      expect(liaison.details['clients'], 1);
      expect(liaison.details['adresse'], '127.0.0.1');
      expect(kinds(phone), contains('relais.client.connexion'));
    });

    test('une action confirmée depuis le téléphone est attribuée au téléphone', () async {
      final client = phone.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', pc.read(chatRelayHostProvider).code!);
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.connected);

      await client.send('Allume la broche');
      await _until(() => phone.read(remoteChatClientProvider).snapshot.pendingTool != null,
          what: 'carte relayée');
      final msg = pc.read(backofficeBusProvider).lastWhere((e) => e.kind == 'ia.message');
      expect(msg.origin, BackofficeOrigin.relais);
      expect(kinds(pc), contains('relais.message'));

      client.confirm();
      await _until(() => pcRepo.sentGCode.isNotEmpty, what: 'exécution sur le PC');
      await _until(() => kinds(pc).contains('ia.outil.execute'));

      final confirme = pc.read(backofficeBusProvider).lastWhere((e) => e.kind == 'ia.outil.confirme');
      expect(confirme.origin, BackofficeOrigin.relais);
      final execute = pc.read(backofficeBusProvider).lastWhere((e) => e.kind == 'ia.outil.execute');
      expect(execute.origin, BackofficeOrigin.relais);
      expect(execute.callId, confirme.callId);
      expect(execute.details['outil'], 'set_spindle');

      expect(pc.read(backofficeStatsProvider).confirmationsRelais, 1);
      expect(kinds(phone), contains('relais.client.envoi'));
    });

    test('un arrêt d\'urgence tapé sur le téléphone est tracé comme exécuté localement', () async {
      final client = phone.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', pc.read(chatRelayHostProvider).code!);
      await _until(() => phone.read(remoteChatClientProvider).status == RemoteChatStatus.connected);

      await client.send('Arrêt d\'urgence !');
      await _until(() => kinds(phone).contains('ia.urgence'));
      expect(kinds(phone), contains('relais.client.urgence_locale'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(kinds(pc).where((k) => k == 'relais.message'), isEmpty,
          reason: 'rien n\'est passé par le lien');
    });
  });

  // ── Coworking (protocole v2) : présence, espace de travail, simulateur ────
  //
  // Dans ce fichier pour la même raison que le groupe précédent : un seul
  // port, donc un seul fichier de test à s'en servir.
  group('coworking', () {
    late ProviderContainer pc;
    late ProviderContainer tablet;
    late FakeMachineRepository pcRepo;
    late FakeMachineRepository tabletRepo;

    Future<void> startHost({bool pcLinkUp = true}) async {
      pcRepo = FakeMachineRepository(
          sendSucceeds: pcLinkUp,
          current: const MachineState(
            status: MachineStatus.idle,
            wPos: [2.5, -3.0, 10.0, 15.0, 90.0],
            mPos: [12.5, 2.0, 35.0, 15.0, 90.0],
            feedrate: 600,
          ));
      pc = _device(pcRepo);
      tabletRepo = FakeMachineRepository();
      tablet = _device(tabletRepo);
      await pc.read(lexiconLoadProvider.future);
      await pc.read(chatRelayHostProvider.notifier).start();
      addTearDown(() => pc.read(chatRelayHostProvider.notifier).stop());
      expect(pc.read(chatRelayHostProvider).running, isTrue,
          reason: pc.read(chatRelayHostProvider).error);
    }

    Future<RemoteChatClient> join(ProviderContainer c,
        {String name = 'iPad atelier', String kind = CoworkKind.tablet}) async {
      final client = c.read(remoteChatClientProvider.notifier);
      await client.connect('127.0.0.1', pc.read(chatRelayHostProvider).code!,
          name: name, kind: kind);
      await _until(() => c.read(remoteChatClientProvider).status == RemoteChatStatus.connected,
          what: 'liaison de $name');
      return client;
    }

    RemoteChatState guest() => tablet.read(remoteChatClientProvider);
    List<BackofficeEvent> pcEvents() => pc.read(backofficeBusProvider);

    test('une tablette qui arrive se présente, et voit qui est là', () async {
      await startHost();
      await join(tablet);
      await _until(() => guest().participants.length == 2, what: 'présence reçue');

      expect(guest().cowork, isTrue);
      expect(guest().selfId, 'invite-1');
      expect(guest().participants.first.isHost, isTrue);
      final me = guest().participants.last;
      expect(me.name, 'iPad atelier');
      expect(me.kind, CoworkKind.tablet);

      final host = pc.read(chatRelayHostProvider);
      expect(host.clients, 1);
      expect(host.participants.single.name, 'iPad atelier');
      final liaison = pcEvents().lastWhere((e) => e.kind == 'relais.liaison');
      expect(liaison.details['participant'], 'iPad atelier');
      expect(liaison.details['genre'], CoworkKind.tablet);
      expect(liaison.details['coworking'], isTrue);
    });

    test('la présence suit les arrivées et les départs', () async {
      await startHost();
      await join(tablet);
      final phone = _device(FakeMachineRepository());
      final phoneClient = await join(phone, name: 'Téléphone de Moussa', kind: CoworkKind.phone);
      await _until(() => guest().participants.length == 3, what: 'la tablette voit le téléphone');
      expect(guest().participants.map((p) => p.name),
          containsAll(['iPad atelier', 'Téléphone de Moussa']));

      await phoneClient.disconnect();
      await _until(() => guest().participants.length == 2, what: 'départ vu par la tablette');
      expect(pc.read(chatRelayHostProvider).clients, 1);
    });

    test('un invité ne peut pas se faire passer pour l\'hôte', () async {
      await startHost();
      await join(tablet, name: 'Faux PC', kind: CoworkKind.host);
      await _until(() => guest().participants.length == 2);
      expect(guest().participants.where((p) => p.isHost), hasLength(1));
      expect(pc.read(chatRelayHostProvider).participants.single.kind, CoworkKind.phone);
    });

    test('l\'espace de travail du PC arrive chez l\'invité, sans liaison machine côté tablette',
        () async {
      await startHost();
      await join(tablet);
      await _until(() => guest().workspace != null, what: 'espace de travail reçu');

      final w = guest().workspace!;
      expect(w.status, 'idle');
      expect(w.online, isTrue);
      expect(w.wPos, [2.5, -3.0, 10.0, 15.0, 90.0]);
      expect(w.feed, 600);
      expect(w.simStatus, 'idle');
      expect(tabletRepo.currentState.status, MachineStatus.offline,
          reason: 'la tablette, elle, n\'a aucune liaison à la carte');
    });

    test('l\'invité pilote le simulateur du PC — et rien ne part vers la carte', () async {
      await startHost();
      final client = await join(tablet);
      await _until(() => guest().workspace != null);

      client.sim('follow');
      await _until(() => pc.read(simulationProvider).isLive, what: 'jumeau enclenché sur le PC');
      await _until(() => guest().workspace!.simStatus == 'live', what: 'retour chez l\'invité');

      client.sim('stop_follow');
      await _until(() => !pc.read(simulationProvider).isLive);
      client.sim('speed', 25);
      await _until(() => pc.read(simulationProvider).speedMultiplier == 25);

      expect(pcEvents().where((e) => e.kind == 'relais.simulateur'), hasLength(3));
      expect(pcRepo.sentGCode, isEmpty);
      expect(pcRepo.sentRaw, isEmpty);
      expect(pcRepo.jogCalls, isEmpty);
      expect(pcRepo.emergencyStopCalls, 0);

      client.sim('efface_tout');
      await _until(() => pcEvents().any((e) =>
          e.kind == 'relais.illisible' && '${e.details['action']}' == 'efface_tout'));
    });

    test('STOP sur la tablette : arrêt local ET arrêt relayé par le PC', () async {
      await startHost();
      final client = await join(tablet);

      final local = await client.stopEverywhere();
      expect(local, isTrue);
      expect(tabletRepo.emergencyStopCalls, 1, reason: 'le chemin local part toujours');
      await _until(() => guest().estopRelayed != null, what: 'réponse du PC');
      expect(guest().estopRelayed, isTrue);
      expect(pcRepo.emergencyStopCalls, 1, reason: 'second chemin : le PC arrête aussi');

      final e = pcEvents().lastWhere((e) => e.kind == 'relais.urgence');
      expect(e.severity, BackofficeSeverity.critical);
      expect(e.details['transmis'], isTrue);
      expect(e.details['participant'], 'iPad atelier');
    });

    test('STOP relayé alors que le PC a perdu la carte : l\'invité le sait', () async {
      await startHost(pcLinkUp: false);
      final client = await join(tablet);
      await client.stopEverywhere();
      await _until(() => guest().estopRelayed != null);
      expect(guest().estopRelayed, isFalse);
      expect(pcEvents().lastWhere((e) => e.kind == 'relais.urgence').details['transmis'], isFalse);
    });

    test('un téléphone resté en v1 ne reçoit que le chat, comme avant', () async {
      await startHost();
      final ws = await WebSocket.connect(
          'ws://127.0.0.1:${ChatRelayProtocol.port}${ChatRelayProtocol.path}');
      addTearDown(ws.close);
      final types = <String>[];
      ws.listen((raw) => types.add('${(jsonDecode(raw as String) as Map)['type']}'));
      ws.add(jsonEncode({'type': 'hello', 'code': pc.read(chatRelayHostProvider).code}));
      await _until(() => types.isNotEmpty, what: 'instantané reçu');
      // Le simulateur bouge : un invité v2 recevrait un espace de travail.
      pc.read(simulationProvider.notifier).setSpeed(5);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(types.toSet(), {'snapshot'});
      expect(pc.read(chatRelayHostProvider).participants.single.name, 'Téléphone');
    });
  });

  group('CoworkWorkspace', () {
    test('se relit à l\'identique', () {
      final w = CoworkWorkspace(
        status: 'run',
        wPos: const [1, 2, 3, 4, 5],
        mPos: const [6, 7, 8, 9, 10],
        feed: 300,
        spindle: 1000,
        alarm: 2,
        line: 40,
        totalLines: 200,
        streaming: true,
        simStatus: 'live',
        simProgress: 20,
        simSpeed: 10,
        simDeviation: 0.4,
        at: DateTime(2026, 11, 16, 9),
      );
      final back = CoworkWorkspace.fromJson(jsonDecode(jsonEncode(w.toJson())))!;
      expect(back.sameContentAs(w), isTrue);
      expect(back.programFraction, 0.2);
      expect(back.hasProgram, isTrue);
    });

    test('une trame abîmée donne des zéros, jamais une exception', () {
      final w = CoworkWorkspace.fromJson(
          {'status': 'idle', 'w': ['x', null, 3], 'f': 'vite', 'lines': -4, 'simPct': 400})!;
      expect(w.wPos, [0, 0, 3, 0, 0]);
      expect(w.feed, 0);
      expect(w.simProgress, 100);
      expect(w.programFraction, 0);
      expect(CoworkWorkspace.fromJson('pas une table'), isNull);
      expect(CoworkParticipant.fromJson({'name': 'sans id'}), isNull);
      expect(CoworkParticipant.fromJson({'id': 'a', 'name': 'x' * 200})!.name.length, 40);
    });
  });
}
