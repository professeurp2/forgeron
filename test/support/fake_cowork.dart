import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/services/chat_relay.dart';

/// Invité de coworking factice : relié d'emblée à un PC, sans socket. Note
/// ce que l'écran lui demande (simulateur, arrêt).
class FakeCoworkClient extends RemoteChatClient {
  FakeCoworkClient(super.ref, RemoteChatState initial) {
    state = initial;
  }

  final List<(String, num?)> simCalls = [];
  int stops = 0;
  bool disconnected = false;

  @override
  void sim(String action, [num? value]) => simCalls.add((action, value));

  @override
  Future<bool> stopEverywhere() async {
    stops++;
    // Tablette sans liaison directe : le chemin local échoue, le PC répond.
    state = state.copyWith(estopRelayed: true);
    return false;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    state = const RemoteChatState();
  }
}

/// Une session en cours : le PC usine, la tablette et un téléphone regardent.
RemoteChatState coworkSessionState() => RemoteChatState(
      status: RemoteChatStatus.connected,
      host: '192.168.0.10',
      hostName: 'PC-ATELIER',
      selfId: 'invite-1',
      participants: const [
        CoworkParticipant(id: 'hote', name: 'PC-ATELIER', kind: CoworkKind.host),
        CoworkParticipant(id: 'invite-1', name: 'iPad atelier', kind: CoworkKind.tablet),
        CoworkParticipant(id: 'invite-2', name: 'Téléphone de Moussa', kind: CoworkKind.phone),
      ],
      workspace: const CoworkWorkspace(
        status: 'run',
        wPos: [12.345, -8.2, 3.5, 15.5, 90.0],
        mPos: [22.345, -3.2, 28.5, 15.5, 90.0],
        feed: 300,
        spindle: 1000,
        line: 420,
        totalLines: 2970,
        streaming: true,
        simStatus: 'live',
        simProgress: 14,
        simSpeed: 10,
        simDeviation: 0.12,
      ),
      snapshot: RemoteChatSnapshot(
        messages: [
          AiChatMessage(
              role: 'user',
              text: 'Où en est le dôme ?',
              timestamp: DateTime(2026, 11, 16, 9, 30)),
          AiChatMessage(
              role: 'assistant',
              text: 'Ligne 420 sur 2 970, la passe de finition est en cours. Aucune alarme.',
              timestamp: DateTime(2026, 11, 16, 9, 30, 4)),
        ],
        pendingTool: 'set_feed_override',
        pendingInput: const {'percent': 80},
      ),
    );

Override fakeCoworkOverride(RemoteChatState initial, {void Function(FakeCoworkClient)? onCreate}) =>
    remoteChatClientProvider.overrideWith((ref) {
      final c = FakeCoworkClient(ref, initial);
      onCreate?.call(c);
      return c;
    });
