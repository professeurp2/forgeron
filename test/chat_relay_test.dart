import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/chat_relay.dart';
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
}
