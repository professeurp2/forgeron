import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/streaming_service.dart';
import 'package:forgeron/data/fluidnc/fluidnc_connection.dart';

/// Connexion factice : capture ce qui part sur le fil, sans réseau.
class _FakeConnection extends FluidNCConnection {
  final List<String> sent = [];
  _FakeConnection() : super('ws://fake');

  @override
  bool sendRaw(String data) {
    sent.add(data);
    return true;
  }

  /// Octets réellement envoyés (hors commandes temps réel comme '?').
  int get gcodeBytes =>
      sent.where((l) => l != '?').fold(0, (sum, l) => sum + l.length);

  List<String> get gcodeLines => sent.where((l) => l != '?').toList();
}

void main() {
  late _FakeConnection conn;
  late GCodeStreamingService svc;

  // 'G1 X1.000 Y1.000 F100' = 21 caractères, +'\n' = 22 octets par ligne.
  const line = 'G1 X1.000 Y1.000 F100';
  const lineBytes = 22;

  setUp(() {
    conn = _FakeConnection();
    svc = GCodeStreamingService(conn);
  });

  tearDown(() => svc.dispose());

  group('Character-counting (protection du buffer RX 127 o de l\'ESP32)', () {
    test('ne dépasse jamais 127 octets en vol', () {
      svc.streamLines(List.filled(10, line));

      // 5 lignes = 110 o (OK) ; une 6e ferait 132 o (> 127) → doit être retenue.
      expect(conn.gcodeLines.length, 5);
      expect(conn.gcodeBytes, 5 * lineBytes);
      expect(conn.gcodeBytes, lessThanOrEqualTo(127));
    });

    test('libère de la place à chaque acquittement', () {
      svc.streamLines(List.filled(10, line));
      expect(conn.gcodeLines.length, 5);

      svc.handleAck(); // 22 o libérés → une ligne de plus peut partir
      expect(conn.gcodeLines.length, 6);

      svc.handleAck();
      expect(conn.gcodeLines.length, 7);
    });
  });

  group('stop() — le correctif de la déconnexion', () {
    test('remet le compteur d\'octets à zéro', () {
      // Un premier run sature le buffer : 110 octets en vol, jamais acquittés
      // (c'est exactement ce qui se passe quand le WiFi tombe en plein usinage).
      svc.streamLines(List.filled(10, line));
      expect(conn.gcodeLines.length, 5);

      // Coupure de liaison → le repository appelle stop().
      svc.stop();
      conn.sent.clear();

      // Reconnexion, nouveau run : l'ESP32 a vidé son buffer, l'app doit
      // repartir de zéro. Sans la purge, _bytesInFlight valait encore 110 et
      // le comptage restait désynchronisé → débordement du buffer réel.
      svc.streamLines(List.filled(10, line));
      expect(conn.gcodeLines.length, 5,
          reason: 'Le compteur d\'octets doit repartir de zéro après stop()');
      expect(conn.gcodeBytes, lessThanOrEqualTo(127));
    });

    test('notifie l\'UI que le programme est interrompu', () {
      var completed = false;
      svc.streamLines(List.filled(5, line), onComplete: () => completed = true);

      svc.stop();

      expect(completed, isTrue,
          reason: 'Sans ça, l\'UI resterait bloquée en « RUN »');
    });
  });

  group('Watchdog', () {
    test('détecte un blocage quand aucune ligne n\'est acquittée', () async {
      final stalled = Completer<String>();
      svc.streamLines(List.filled(3, line),
          onStall: (reason) => stalled.complete(reason));

      final reason = await stalled.future.timeout(const Duration(seconds: 4));
      expect(reason, contains('acquittement'));
    });

    test(
        'RESTE ARMÉ tant que des octets sont en vol, même après le dernier envoi',
        () async {
      // Régression : avant le correctif, handleAck() annulait le watchdog sans
      // le réarmer, et _attemptSend() ne le réarmait que s'il envoyait une
      // ligne. En fin de programme (tout envoyé, derniers 'ok' en attente),
      // plus RIEN ne surveillait : un blocage machine passait inaperçu et l'UI
      // restait indéfiniment en « RUN ».
      final stalled = Completer<String>();
      svc.streamLines([line, line], onStall: (r) => stalled.complete(r));

      // Les 2 lignes tiennent dans le buffer → tout est envoyé, rien en attente.
      expect(conn.gcodeLines.length, 2);

      // Un seul acquittement : il reste 22 octets en vol, et plus rien à envoyer.
      svc.handleAck();

      // Le watchdog DOIT quand même se déclencher.
      final reason = await stalled.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => fail(
            'Watchdog désarmé alors que des octets sont encore en vol : '
            'un blocage machine ne serait jamais détecté.'),
      );
      expect(reason, isNotEmpty);
    });

    test('notifyActivity() évite le faux blocage sur un mouvement long', () async {
      // Régression du bug « FLUX SUSPENDU » : sur un mouvement plus long que le
      // timeout, la carte n'acquitte pas de nouvelle ligne (buffer de
      // planification plein) mais bouge et répond au heartbeat. Ces signaux de
      // vie doivent réarmer le watchdog.
      var stalled = false;
      svc.streamLines([line, line], onStall: (_) => stalled = true);
      svc.handleAck(); // il reste 22 octets en vol → watchdog armé

      // La machine donne signe de vie régulièrement (< timeout de 3 s).
      final ticker = Timer.periodic(
          const Duration(milliseconds: 1500), (_) => svc.notifyActivity());
      await Future<void>.delayed(const Duration(seconds: 4));
      ticker.cancel();

      expect(stalled, isFalse,
          reason: 'Un mouvement long ne doit pas être pris pour un blocage '
              'tant que la machine donne signe de vie.');
    });

    test('se tait quand tout est acquitté', () async {
      var stalledCalled = false;
      var completed = false;
      svc.streamLines([line, line],
          onComplete: () => completed = true,
          onStall: (_) => stalledCalled = true);

      svc.handleAck();
      svc.handleAck();

      expect(completed, isTrue);

      // Passé le délai du watchdog, aucun faux positif ne doit survenir.
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      expect(stalledCalled, isFalse);
    });
  });

  group('isStreaming — garde du déverrouillage d\'alarme', () {
    test('faux avant, vrai pendant, faux après stop()', () {
      expect(svc.isStreaming, isFalse);
      svc.streamLines(List.filled(3, line));
      expect(svc.isStreaming, isTrue);
      svc.stop();
      expect(svc.isStreaming, isFalse);
    });

    test('faux une fois tout acquitté (les ok suivants sont hors-bande)', () {
      svc.streamLines([line, line]);
      expect(svc.isStreaming, isTrue);
      svc.handleAck();
      svc.handleAck();
      expect(svc.isStreaming, isFalse);
    });

    test('après une alarme (stop en plein run), le \$X ne relance rien', () {
      // Simule un dépassement de limite en plein programme : 5 lignes en vol.
      svc.streamLines(List.filled(10, line));
      expect(conn.gcodeLines.length, 5);
      final sentBefore = conn.gcodeLines.length;

      // Le repository purge le flux à l'entrée en ALARM.
      svc.stop();
      expect(svc.isStreaming, isFalse);

      // Même si un 'ok' de \$X arrivait et déclenchait handleAck par erreur, la
      // file est purgée → aucune ligne ne repart dans la butée (défense en
      // profondeur, en plus du garde isStreaming côté repository).
      svc.handleAck();
      expect(conn.gcodeLines.length, sentBefore,
          reason: 'aucun renvoi après la purge d\'alarme');
    });
  });
}
