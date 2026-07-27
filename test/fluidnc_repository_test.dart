import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/data/fluidnc/fluidnc_connection.dart';
import 'package:forgeron/data/fluidnc/fluidnc_machine_repository.dart';

/// Fausse connexion : streams pilotables + capture des envois, sans réseau.
class _FakeConnection extends FluidNCConnection {
  _FakeConnection() : super('ws://fake');

  final _status = StreamController<bool>.broadcast();
  final _msgs = StreamController<String>.broadcast();
  final List<String> sent = [];

  @override
  Future<void> connect() async {} // pas de vraie socket

  @override
  Stream<bool> get status => _status.stream;

  @override
  Stream<String> get messages => _msgs.stream;

  @override
  Stream<String> get traffic => const Stream.empty();

  @override
  bool sendRaw(String data) {
    sent.add(data);
    return true;
  }

  void pushStatus(bool connected) => _status.add(connected);

  /// Lignes de programme réellement parties (hors commandes temps réel).
  List<String> get programLines =>
      sent.where((l) => l.startsWith('G1')).toList();

  void clearSent() => sent.clear();

  @override
  void dispose() {
    _status.close();
    _msgs.close();
  }
}

void main() {
  // 'G1 X1.000 Y1.000 F100\n' = 22 octets → 5 lignes tiennent dans 127, pas 6.
  const line = 'G1 X1.000 Y1.000 F100';

  test(
      'coupure en plein stream : les compteurs repartent de zéro et l\'UI est débloquée',
      () async {
    final conn = _FakeConnection();
    final repo = FluidNCMachineRepository(conn);
    addTearDown(repo.dispose);

    // 1) Lancement d'un programme : le buffer se remplit (5 lignes en vol,
    //    jamais acquittées — exactement l'état au moment où le WiFi tombe).
    var completed = 0;
    await repo.sendGCodeBatch(List.filled(10, line),
        onComplete: () => completed++);
    expect(conn.programLines.length, 5, reason: 'buffer 127 o saturé');

    // 2) Coupure de liaison.
    conn.pushStatus(false);
    await Future<void>.delayed(Duration.zero); // laisse le listener s'exécuter

    expect(completed, 1,
        reason: 'onComplete doit être appelé → l\'UI ne reste pas en RUN');

    // 3) Reconnexion + nouveau programme : l'ESP32 a vidé son buffer, l'app
    //    DOIT repartir de zéro. Sans la purge (le bug P0), _bytesInFlight
    //    valait encore 110 et rien de neuf ne serait parti.
    conn.clearSent();
    await repo.sendGCodeBatch(List.filled(10, line));

    expect(conn.programLines.length, 5,
        reason: 'compteur d\'octets réinitialisé après la coupure');
  });

  test('un E-STOP hors ligne est signalé (sendRaw retourne false)', () async {
    // Connexion réelle jamais établie → sendRaw ne transmet rien.
    final conn = FluidNCConnection('ws://192.0.2.1'); // IP de test, injoignable
    addTearDown(conn.dispose);
    expect(conn.sendRaw('\x18'), isFalse,
        reason: 'hors ligne, l\'arrêt d\'urgence ne part pas — et le dit');
  });
}
