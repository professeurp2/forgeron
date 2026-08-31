import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/streaming_provider.dart';
import 'support/fake_machine_repository.dart';

/// Un arrêt d'urgence qui n'arrive pas jusqu'à la carte est le pire des cas :
/// l'opérateur lâche le bouton en croyant la machine arrêtée, alors que la
/// broche tourne toujours. Seul [StreamingController.stopStream] sait le
/// détecter — il regarde si le Ctrl-X est réellement parti et lève
/// [estopFailedProvider], que `SafetyBanner` transforme en bandeau rouge.
///
/// Appeler `emergencyStop()` directement sur le repository court-circuite ce
/// garde-fou : la commande part « au mieux » et l'échec passe inaperçu. C'est
/// ce qui restait branché sur le bouton E-STOP mobile.
void main() {
  ProviderContainer containerWith(FakeMachineRepository repo) => ProviderContainer(
        overrides: [machineRepositoryProvider.overrideWithValue(repo)],
      );

  group('StreamingController.stopStream — contrat de l\'arrêt d\'urgence', () {
    test('liaison coupée → estopFailed levé, l\'UI doit alerter', () async {
      final repo = FakeMachineRepository(sendSucceeds: false);
      final container = containerWith(repo);
      addTearDown(container.dispose);

      final sent = await container.read(streamingProvider.notifier).stopStream();

      expect(sent, isFalse);
      expect(repo.emergencyStopCalls, 1);
      expect(container.read(estopFailedProvider), isTrue,
          reason: 'sans ce drapeau, SafetyBanner reste muet et l\'opérateur '
              'croit la machine arrêtée');
    });

    test('arrêt transmis → pas de fausse alerte', () async {
      final repo = FakeMachineRepository(sendSucceeds: true);
      final container = containerWith(repo);
      addTearDown(container.dispose);

      final sent = await container.read(streamingProvider.notifier).stopStream();

      expect(sent, isTrue);
      expect(container.read(estopFailedProvider), isFalse);
    });

    test('l\'état « streaming » retombe à false dans les deux cas', () async {
      for (final ok in [true, false]) {
        final container = containerWith(FakeMachineRepository(sendSucceeds: ok));
        addTearDown(container.dispose);
        await container.read(streamingProvider.notifier).stopStream();
        expect(container.read(streamingProvider), isFalse);
      }
    });
  });

  test(
    'aucun bouton ne court-circuite le contrôleur en appelant emergencyStop()',
    () {
      // Garde de non-régression : le bouton E-STOP mobile a vécu des mois sur
      // l'appel direct au repository, invisible parce qu'il « marchait » tant
      // que le Wi-Fi tenait. On vérifie donc la règle à la source plutôt que
      // d'attendre la panne de liaison sur la machine.
      const allowed = {
        // Le seul endroit autorisé : c'est lui qui vérifie et qui alerte.
        'lib/application/providers/streaming_provider.dart',
        // Implémentations du repository (la commande elle-même).
        'lib/data/fluidnc/fluidnc_machine_repository.dart',
        'lib/data/mock/mock_machine_repository.dart',
        'lib/domain/repositories/machine_repository.dart',
      };

      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (allowed.contains(path)) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('.emergencyStop()')) {
            offenders.add('$path:${i + 1}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'passez par streamingProvider.notifier.stopStream() : '
              'lui seul purge le flux et signale un arrêt non transmis');
    },
  );
}
