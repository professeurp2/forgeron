import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/backoffice_event.dart';
import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import '../services/ai_turn_journal.dart';
import '../services/backoffice_bus.dart';
import '../services/backoffice_firmware_probe.dart';
import '../services/backoffice_journal.dart';
import '../services/backoffice_stats.dart';
import '../services/local_ai_agent_service.dart' show LocalAiAgentService;
import '../services/ollama_discovery.dart';
import 'activity_log_provider.dart' show interpretMachineCommand;
import 'ai_agent_settings_provider.dart';
import 'di_providers.dart';
import 'machine_provider.dart';
import 'streaming_provider.dart';

export '../../domain/models/backoffice_event.dart';
export '../services/backoffice_bus.dart' show BackofficeBus, BackofficeActor;
export '../services/backoffice_stats.dart';
export '../services/ollama_discovery.dart' show OllamaModel, OllamaLoadedModel;

/// Le bus d'audit, unique pour l'application, avec son journal sur disque
/// (dossier de support de l'application, à côté de `ai_journal.jsonl`).
///
/// Il est lu par le contrôleur de l'agent, le relais de chat et le veilleur :
/// à l'emplacement d'un `Provider` ordinaire, un test le remplace par un
/// `BackofficeBus()` nu, sans disque.
final backofficeBusProvider =
    StateNotifierProvider<BackofficeBus, List<BackofficeEvent>>((ref) {
      final bus = BackofficeBus(
        journalFactory: () async {
          final dir = await getApplicationSupportDirectory();
          return BackofficeJournal(dir.path);
        },
      );
      unawaited(
        bus.restore().then((_) {
          bus.emit(
            source: BackofficeSource.systeme,
            kind: 'systeme.demarrage',
            summary: 'Backoffice démarré',
          );
        }),
      );
      return bus;
    });

/// Branche les sondes qui n'ont pas de « propriétaire » naturel : le trafic
/// de la carte, l'état machine, le flux d'usinage. Les autres sources (agent
/// IA, relais, veilleur) émettent elles-mêmes sur le bus.
///
/// Instancié une fois au démarrage (`MainScaffold`), comme le veilleur.
final backofficeProbesProvider = Provider<BackofficeProbes>((ref) {
  final probes = BackofficeProbes(ref);
  ref.onDispose(probes.dispose);
  return probes;
});

class BackofficeProbes {
  BackofficeProbes(this._ref) {
    final bus = _ref.read(backofficeBusProvider.notifier);
    firmware = BackofficeFirmwareProbe(bus, interpret: interpretMachineCommand);

    // Le dépôt change quand l'adresse de la carte change ou quand on bascule
    // en simulation : on se réabonne à chaque fois (le `LoggerService`, lui,
    // ne lit le dépôt qu'une fois — ce n'est pas un modèle à suivre).
    _ref.listen<MachineRepository>(
      machineRepositoryProvider,
      (_, repo) => _subscribe(repo),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<MachineState>>(machineStateProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null) firmware.onState(s);
    });
    _ref.listen<bool>(
      streamingProvider,
      (_, next) => firmware.onStreaming(next),
    );
    _ref.listen<String?>(
      streamStallProvider,
      (_, next) => firmware.onStall(next),
    );
    _ref.listen<bool>(
      estopFailedProvider,
      (_, next) => firmware.onEstopFailed(next),
    );
  }

  final Ref _ref;
  late final BackofficeFirmwareProbe firmware;
  StreamSubscription<String>? _traffic;

  void _subscribe(MachineRepository repo) {
    _traffic?.cancel();
    _traffic = repo.trafficStream.listen(firmware.onTraffic, onError: (_) {});
  }

  void dispose() {
    _traffic?.cancel();
  }
}

/// Les comptes affichés en tête de l'écran, recalculés à chaque événement.
final backofficeStatsProvider = Provider<BackofficeStats>(
  (ref) => BackofficeStats.of(ref.watch(backofficeBusProvider)),
);

/// Les chaînes « appel d'outil → carte », la plus récente d'abord.
final backofficeChainsProvider = Provider<List<BackofficeChain>>(
  (ref) => BackofficeChain.build(ref.watch(backofficeBusProvider)),
);

// ───────────────────────── Modèles locaux (Ollama) ──────────────────────────

/// Un modèle installé sur le serveur local, vu du backoffice : ce qu'il sait
/// faire, s'il est chargé, et le rôle que l'application lui donne.
class LocalModelStatus {
  const LocalModelStatus(this.model, {this.loaded, required this.role});

  final OllamaModel model;

  /// `null` si le modèle n'est pas en mémoire en ce moment.
  final OllamaLoadedModel? loaded;

  /// `pilote` (il commande la machine), `images` (il lit les photos), ou
  /// `aucun`.
  final String role;

  String get name => model.name;
  bool get isLoaded => loaded != null;

  /// Un modèle qui voit, qui n'est ni le pilote ni déjà branché pour les
  /// images : on peut le brancher d'un geste.
  bool get canWireForImages => model.supportsVision && role == 'aucun';
}

/// Ce que le backoffice sait du serveur de modèles local.
class LocalModelsReport {
  const LocalModelsReport({
    required this.url,
    required this.reachable,
    this.configured = true,
    this.models = const [],
    this.pilot = '',
    this.vision = '',
  });

  /// Adresse interrogée (celle des réglages, ou `localhost` à défaut).
  final String url;
  final bool reachable;

  /// Faux quand aucune adresse n'est réglée : `url` est alors une supposition
  /// (le PC lui-même) et rien n'est branché tant que l'opérateur ne le dit pas.
  final bool configured;
  final List<LocalModelStatus> models;
  final String pilot;
  final String vision;

  /// Le modèle d'images réglé n'est pas sur le serveur.
  bool get visionMissing =>
      vision.isNotEmpty && reachable && !models.any((m) => m.role == 'images');

  /// Le pilote réglé n'est pas sur le serveur.
  bool get pilotMissing =>
      configured && reachable && !models.any((m) => m.role == 'pilote');

  /// Les modèles qui voient et ne servent à rien pour l'instant.
  List<LocalModelStatus> get wirableForImages =>
      models.where((m) => m.canWireForImages).toList();
}

/// Découverte injectable (un faux client HTTP en test).
final ollamaDiscoveryProvider = Provider<OllamaDiscovery>((ref) => OllamaDiscovery());

/// Adresse par défaut quand rien n'est réglé : le PC lui-même héberge Ollama
/// (c'est lui qui porte le modèle local et le relais). Sur le web, aucune
/// supposition.
String? defaultLocalServerGuess() => kIsWeb ? null : 'http://localhost:${OllamaDiscovery.port}';

/// Les modèles du serveur local, avec leur rôle et leur état de chargement.
/// Recalculé quand l'adresse ou les modèles réglés changent ; « Rafraîchir »
/// l'invalide.
final localModelsReportProvider = FutureProvider<LocalModelsReport>((ref) async {
  final settings = ref.watch(aiAgentSettingsProvider);
  final discovery = ref.watch(ollamaDiscoveryProvider);
  final configured = settings.localBaseUrl.isNotEmpty;
  final url = configured
      ? LocalAiAgentService.normalizeBaseUrl(settings.localBaseUrl)
      : defaultLocalServerGuess();
  if (url == null || url.isEmpty) {
    return const LocalModelsReport(url: '', reachable: false, configured: false);
  }
  final server = await discovery.probe(url, timeout: const Duration(seconds: 3));
  if (server == null) {
    return LocalModelsReport(
        url: url,
        reachable: false,
        configured: configured,
        pilot: configured ? settings.localModel : '',
        vision: configured ? settings.localVisionModel : '');
  }
  final full = await discovery.describe(server);
  final loaded = await discovery.loaded(url);
  final pilot = configured ? settings.localModel : '';
  final vision = configured ? settings.localVisionModel : '';
  String roleOf(String name) {
    if (pilot.isNotEmpty && LocalAiAgentService.isListed([name], pilot)) return 'pilote';
    if (vision.isNotEmpty && LocalAiAgentService.isListed([name], vision)) return 'images';
    return 'aucun';
  }

  final models = [
    for (final m in full.models)
      LocalModelStatus(
        m,
        loaded: loaded.where((l) => LocalAiAgentService.isListed([l.name], m.name)).firstOrNull,
        role: roleOf(m.name),
      ),
  ];
  // Pilote et images d'abord, puis ceux qui voient, puis le reste.
  models.sort((a, b) {
    int rank(LocalModelStatus s) =>
        s.role == 'pilote' ? 0 : s.role == 'images' ? 1 : s.model.supportsVision ? 2 : 3;
    return rank(a).compareTo(rank(b));
  });
  return LocalModelsReport(
      url: url,
      reachable: true,
      configured: configured,
      models: models,
      pilot: pilot,
      vision: vision);
});

/// Le seul geste que le backoffice s'autorise : un RÉGLAGE de l'application
/// (jamais une action sur la machine).
final localModelsWiringProvider =
    Provider<LocalModelsWiring>((ref) => LocalModelsWiring(ref));

class LocalModelsWiring {
  LocalModelsWiring(this._ref);
  final Ref _ref;

  /// Branche [model] comme modèle d'images, et, si aucun serveur n'était réglé,
  /// l'adresse interrogée (sans quoi le service d'images ne serait jamais
  /// créé). Le pilote n'est touché que s'il n'est pas installé sur ce serveur :
  /// on lui donne alors le modèle recommandé, pour que le réglage reste
  /// cohérent. Tracé dans le backoffice comme un réglage.
  void wireForImages(LocalModelsReport report, LocalModelStatus model) {
    final n = _ref.read(aiAgentSettingsProvider.notifier);
    final changes = <String>[];
    if (!report.configured) {
      n.setLocalBaseUrl(report.url);
      changes.add('serveur ${report.url}');
      final current = _ref.read(aiAgentSettingsProvider).localModel;
      final installed = report.models.map((m) => m.model).toList();
      if (!LocalAiAgentService.isListed(installed.map((m) => m.name), current)) {
        final pilot = OllamaDiscovery.recommend(installed);
        if (pilot != null) {
          n.setLocalModel(pilot.name);
          changes.add('pilote ${pilot.name}');
        }
      }
    }
    n.setLocalVisionModel(model.name);
    changes.add('images ${model.name}');
    _ref.read(backofficeBusProvider.notifier).emit(
          source: BackofficeSource.systeme,
          kind: 'systeme.reglage',
          summary: 'Modèle d\'images branché : ${changes.join(', ')}',
          severity: BackofficeSeverity.notice,
          details: {
            'modele_images': model.name,
            'serveur': report.url,
            'changements': changes,
          },
          origin: BackofficeOrigin.local,
        );
    _ref.invalidate(localModelsReportProvider);
  }
}

/// Résumé du journal des tours de l'agent (`ai_journal.jsonl`), toutes
/// sessions confondues. `null` si le journal est introuvable.
final aiJournalSummaryProvider = FutureProvider<AiJournalSummary?>((ref) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final records = await AiTurnJournal(dir.path).readAll();
    return AiJournalSummary.of(records);
  } catch (_) {
    return null;
  }
});
