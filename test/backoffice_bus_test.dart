import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/activity_log_provider.dart'
    show interpretMachineCommand;
import 'package:forgeron/application/services/backoffice_bus.dart';
import 'package:forgeron/application/services/backoffice_firmware_probe.dart';
import 'package:forgeron/application/services/backoffice_journal.dart';
import 'package:forgeron/application/services/backoffice_stats.dart';
import 'package:forgeron/domain/models/backoffice_event.dart';
import 'package:forgeron/domain/models/machine_state.dart';

/// Le bus d'audit : ce qu'il garde, ce qu'il relie, ce qu'il persiste.
///
/// Le point qui compte le plus est l'attribution : quand l'IA exécute un
/// outil, la commande qui part vers la carte doit porter l'identifiant de cet
/// appel — c'est la seule façon de répondre après coup à « qu'est-ce que le
/// modèle a réellement envoyé ? ».
void main() {
  group('BackofficeBus', () {
    test('numérote, borne et publie', () {
      final bus = BackofficeBus(capacity: 3);
      for (var i = 0; i < 5; i++) {
        bus.emit(source: BackofficeSource.systeme, kind: 'k', summary: 'e$i');
      }
      expect(bus.state.map((e) => e.summary), ['e2', 'e3', 'e4']);
      expect(bus.state.map((e) => e.seq), [3, 4, 5]);
      expect(bus.lastSeq, 5);
    });

    test('un événement se relit à l\'identique', () {
      final e = BackofficeEvent(
        seq: 7,
        time: DateTime(2026, 11, 12, 10, 30, 15, 250),
        source: BackofficeSource.ia,
        kind: 'ia.outil.execute',
        severity: BackofficeSeverity.warning,
        summary: 'jog_axis → ÉCHEC',
        details: const {'outil': 'jog_axis', 'arguments': {'axis': 'X', 'distance': 5.0}},
        turnId: 't1',
        callId: 'jog_axis_0',
        origin: BackofficeOrigin.relais,
      );
      final back = BackofficeEvent.fromJson(
          (jsonDecode(jsonEncode(e.toJson())) as Map).cast<String, dynamic>())!;
      expect(back.seq, 7);
      expect(back.time, e.time);
      expect(back.source, BackofficeSource.ia);
      expect(back.kind, 'ia.outil.execute');
      expect(back.severity, BackofficeSeverity.warning);
      expect(back.details['arguments'], {'axis': 'X', 'distance': 5.0});
      expect(back.turnId, 't1');
      expect(back.callId, 'jog_axis_0');
      expect(back.origin, 'relais');
      expect(back.isProblem, isTrue);
    });

    test('une ligne illisible n\'est jamais fatale', () {
      expect(BackofficeEvent.fromJson(const {'seq': 'x'}), isNull);
      expect(BackofficeEvent.fromJson(const {}), isNull);
    });

    test('la fenêtre d\'attribution se ferme après la boucle d\'événements, pas avant',
        () async {
      final bus = BackofficeBus();
      bus.beginAction(const BackofficeActor(callId: 'home_1', tool: 'home'));
      expect(bus.currentActor?.callId, 'home_1');
      bus.endAction();
      // Encore là dans la même boucle : une commande en vol doit pouvoir
      // être attribuée.
      expect(bus.currentActor?.callId, 'home_1');
      await Future<void>.delayed(Duration.zero);
      expect(bus.currentActor, isNull);
    });

    test('export JSON : tout le tampon, du plus ancien au plus récent', () {
      final bus = BackofficeBus();
      bus.emit(source: BackofficeSource.ia, kind: 'a', summary: 'un');
      bus.emit(source: BackofficeSource.firmware, kind: 'b', summary: 'deux');
      final j = bus.exportJson(extra: {'x': 1});
      expect(j['evenements'], 2);
      expect(j['x'], 1);
      expect((j['journal'] as List).map((e) => e['summary']), ['un', 'deux']);
    });
  });

  group('BackofficeJournal', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('forgeron_bo_'));
    tearDown(() => dir.delete(recursive: true));

    test('écrit, tourne, relit dans l\'ordre et ignore une ligne corrompue', () async {
      final journal = BackofficeJournal(dir.path, maxBytes: 300, keep: 2);
      for (var i = 0; i < 12; i++) {
        await journal.record(BackofficeEvent(
          seq: i,
          time: DateTime(2026, 1, 1, 0, 0, i),
          source: BackofficeSource.systeme,
          kind: 'k',
          summary: 'événement $i',
        ));
      }
      await journal.file.writeAsString('{pas du json\n', mode: FileMode.append);
      final all = await journal.readAll();
      expect(all, isNotEmpty);
      expect(all.length, lessThan(12), reason: 'la rotation a jeté les plus anciens');
      final seqs = all.map((e) => e.seq).toList();
      expect(seqs, List.generate(seqs.length, (i) => seqs.first + i),
          reason: 'du plus ancien au plus récent, sans trou');
      expect(seqs.last, 11);
    });

    test('le bus relit son journal au démarrage et continue la numérotation', () async {
      final journal = BackofficeJournal(dir.path);
      final first = BackofficeBus(journalFactory: () async => journal);
      first.emit(source: BackofficeSource.ia, kind: 'ia.tour', summary: 'hier');
      // L'écriture est asynchrone : on la laisse se poser.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = BackofficeBus(journalFactory: () async => journal);
      second.emit(source: BackofficeSource.ia, kind: 'ia.tour', summary: 'aujourd\'hui');
      await second.restore();
      expect(second.state.map((e) => e.summary), ['hier', 'aujourd\'hui']);
      expect(second.state.map((e) => e.seq), [1, 2]);
      final next = second.emit(source: BackofficeSource.ia, kind: 'k', summary: 'suite');
      expect(next.seq, 3);
    });
  });

  group('BackofficeFirmwareProbe', () {
    late BackofficeBus bus;
    late BackofficeFirmwareProbe probe;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 11, 12, 9, 0);
      bus = BackofficeBus(clock: () => now);
      probe = BackofficeFirmwareProbe(bus, interpret: interpretMachineCommand, clock: () => now);
    });

    List<String> kinds() => bus.state.map((e) => e.kind).toList();

    test('le heartbeat et les rapports d\'état ne font pas d\'événement', () {
      probe.onTraffic('TX: ?');
      probe.onTraffic('RX: <Idle|MPos:0,0,0|FS:0,0>');
      probe.onTraffic('RX: ok'); // acquittement sans commande attendue, manuel
      expect(bus.state, isEmpty);
    });

    test('une commande de l\'IA porte son appel, et la réponse de la carte aussi', () {
      bus.beginAction(const BackofficeActor(
          callId: 'jog_axis_3', tool: 'jog_axis', origin: BackofficeOrigin.modele, turnId: 't1'));
      probe.onTraffic('TX: \x85');
      probe.onTraffic('TX: \$J=G91 G21 X5.000 F500\n');
      bus.endAction();
      now = now.add(const Duration(milliseconds: 12));
      probe.onTraffic('RX: ok');

      final tx = bus.state.where((e) => e.kind == 'firmware.tx').toList();
      expect(tx.map((e) => e.callId), everyElement('jog_axis_3'));
      expect(tx.last.summary, contains('Jog manuel'));
      expect(tx.last.origin, BackofficeOrigin.modele);
      expect(tx.last.turnId, 't1');

      final rx = bus.state.singleWhere((e) => e.kind == 'firmware.reponse');
      expect(rx.callId, 'jog_axis_3');
      expect(rx.details['reponse'], 'ok');
      expect(rx.details['latence_ms'], 12);
      expect(rx.details['commande'], contains('\$J=G91'));
      expect(rx.severity, BackofficeSeverity.info);
    });

    test('un error:N de la carte est un problème, avec son libellé', () {
      bus.beginAction(const BackofficeActor(callId: 'send_gcode_1', tool: 'send_gcode'));
      probe.onTraffic('TX: G0 X999\n');
      bus.endAction();
      probe.onTraffic('RX: error:15');
      final rx = bus.state.singleWhere((e) => e.kind == 'firmware.reponse');
      expect(rx.severity, BackofficeSeverity.warning);
      expect(rx.summary, contains('error:15'));
      expect(rx.summary, contains('hors des courses'));
      expect(rx.callId, 'send_gcode_1');
    });

    test('une commande manuelle est attribuée à l\'opérateur, son ok est muet', () {
      probe.onTraffic('TX: \$H\n');
      probe.onTraffic('RX: ok');
      expect(kinds(), ['firmware.tx']);
      expect(bus.state.single.origin, BackofficeOrigin.operateur);
      expect(bus.state.single.callId, isNull);
      expect(bus.state.single.summary, contains('Homing'));
    });

    test('un envoi sur liaison coupée est critique', () {
      probe.onTraffic('TX ÉCHEC (hors ligne) : \x18');
      expect(kinds(), ['firmware.tx_echec']);
      expect(bus.state.single.severity, BackofficeSeverity.critical);
      expect(bus.state.single.summary, contains('Ctrl-X'));
    });

    test('une alarme reçue est critique et vide la file d\'acquittements', () {
      probe.onTraffic('TX: G1 X1 F100\n');
      probe.onTraffic('RX: ALARM:1');
      probe.onTraffic('RX: ok'); // plus rien à relier : muet
      expect(kinds(), ['firmware.tx', 'firmware.alarme']);
      final a = bus.state.last;
      expect(a.severity, BackofficeSeverity.critical);
      expect(a.summary, contains('ALARME 1'));
      expect(a.details['position_perdue'], isTrue);
    });

    test('pendant un usinage, les lignes sont comptées, pas journalisées une à une', () {
      bus.beginAction(const BackofficeActor(callId: 'run_program_0', tool: 'run_program'));
      probe.onStreaming(true);
      bus.endAction();
      for (var i = 0; i < 200; i++) {
        probe.onTraffic('TX: G1 X$i F300\n');
        probe.onTraffic('RX: ok');
      }
      probe.onTraffic('TX: G1 X999\n');
      probe.onTraffic('RX: error:33');
      probe.onStreaming(false);

      expect(kinds(), ['firmware.programme.debut', 'firmware.reponse', 'firmware.programme.fin']);
      expect(bus.state.first.callId, 'run_program_0',
          reason: 'le programme a été lancé par un outil de l\'IA');
      expect(bus.state.first.summary, contains('IA'));
      final fin = bus.state.last;
      expect(fin.details['lignes'], 201);
      expect(fin.details['ok'], 200);
      expect(fin.details['erreurs'], 1);
      expect(fin.severity, BackofficeSeverity.warning);
      expect(fin.callId, 'run_program_0');
    });

    test('les transitions d\'état sont tracées, l\'alarme en critique', () {
      probe.onState(const MachineState(status: MachineStatus.idle));
      probe.onState(const MachineState(status: MachineStatus.idle));
      probe.onState(const MachineState(status: MachineStatus.alarm, alarmCode: 2));
      probe.onState(const MachineState(status: MachineStatus.alarm, alarmCode: 2));
      expect(kinds(), ['machine.statut', 'machine.statut']);
      expect(bus.state.last.severity, BackofficeSeverity.critical);
      expect(bus.state.last.summary, contains('idle → alarm'));
      expect(bus.state.last.details['alarme'], 2);
    });

    test('blocage du flux et arrêt d\'urgence non transmis sont critiques', () {
      probe.onStall(null);
      probe.onStall('Heartbeat timeout');
      probe.onEstopFailed(false);
      probe.onEstopFailed(true);
      expect(kinds(), ['firmware.blocage', 'firmware.urgence_non_transmise']);
      expect(bus.state.map((e) => e.severity), everyElement(BackofficeSeverity.critical));
    });
  });

  group('BackofficeStats et chaînes', () {
    test('comptent ce qui est enregistré, rien d\'autre', () {
      final bus = BackofficeBus();
      bus.emit(
          source: BackofficeSource.ia,
          kind: 'ia.tour',
          summary: '',
          details: const {'issue': 'ok', 'latence_ms': 800});
      bus.emit(
          source: BackofficeSource.ia,
          kind: 'ia.tour',
          summary: '',
          details: const {'issue': 'ok', 'latence_ms': 1200});
      bus.emit(
          source: BackofficeSource.ia,
          kind: 'ia.tour',
          summary: '',
          details: const {'issue': 'error'});
      bus.emit(source: BackofficeSource.ia, kind: 'ia.outil.demande', summary: '', callId: 'c1',
          details: const {'outil': 'jog_axis', 'arguments': {'axis': 'X'}});
      bus.emit(source: BackofficeSource.ia, kind: 'ia.outil.attente', summary: '', callId: 'c1');
      bus.emit(
          source: BackofficeSource.ia,
          kind: 'ia.outil.confirme',
          summary: '',
          callId: 'c1',
          origin: BackofficeOrigin.relais);
      bus.emit(
          source: BackofficeSource.ia,
          kind: 'ia.outil.execute',
          summary: '',
          callId: 'c1',
          details: const {'echec': false, 'duree_ms': 40});
      bus.emit(source: BackofficeSource.firmware, kind: 'firmware.tx', summary: '', callId: 'c1');
      bus.emit(
          source: BackofficeSource.firmware,
          kind: 'firmware.reponse',
          summary: '',
          callId: 'c1',
          details: const {'reponse': 'ok', 'latence_ms': 9});
      bus.emit(source: BackofficeSource.firmware, kind: 'firmware.tx', summary: '');
      bus.emit(
          source: BackofficeSource.garde,
          kind: 'garde.gcode',
          summary: '',
          severity: BackofficeSeverity.warning,
          callId: 'c2',
          details: const {'outil': 'send_gcode'});

      final s = BackofficeStats.of(bus.state);
      expect(s.toursIa, 3);
      expect(s.toursOk, 2);
      expect(s.toursErreur, 1);
      expect(s.latenceIaP50Ms, 800);
      expect(s.appelsOutils, 1);
      expect(s.confirmationsRelais, 1);
      expect(s.confirmationsLocal, 0);
      expect(s.commandesIa, 1);
      expect(s.commandesOperateur, 1);
      expect(s.reponsesOk, 1);
      expect(s.latenceCarteP50Ms, 9);
      expect(s.gardes, 1);
      expect(s.problemes, 1);

      final chains = BackofficeChain.build(bus.state);
      expect(chains.map((c) => c.callId), ['c2', 'c1'], reason: 'la plus récente d\'abord');
      final c1 = chains.last;
      expect(c1.tool, 'jog_axis');
      expect(c1.args, {'axis': 'X'});
      expect(c1.status, BackofficeChainStatus.ok);
      expect(c1.confirmation?.origin, BackofficeOrigin.relais);
      expect(c1.commandes, hasLength(1));
      expect(c1.reponses.single.details['latence_ms'], 9);
      expect(chains.first.status, BackofficeChainStatus.refusee);
    });
  });
}
