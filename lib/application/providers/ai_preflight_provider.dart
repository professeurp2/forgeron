import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/cellular_http_client.dart';
import '../../domain/models/machine_state.dart';
import '../services/local_ai_agent_service.dart';
import '../services/ollama_discovery.dart';
import 'ai_agent_settings_provider.dart';
import 'ai_model_provider.dart';
import 'backoffice_provider.dart' show ollamaDiscoveryProvider;
import 'di_providers.dart';
import 'lexicon_provider.dart';

/// Verdict d'un point de contrôle.
enum PreflightStatus {
  /// Vérifié, conforme.
  ok,

  /// Fonctionne, avec une limite que l'opérateur doit connaître.
  warning,

  /// Bloquant : l'assistant ne répondra pas, ou ne pourra pas agir.
  failed,

  /// Sans objet dans cette configuration (dit, pour ne pas laisser croire à
  /// un oubli).
  skipped,
}

/// Un point de contrôle du pré-vol : ce qui a été vérifié, ce qu'on a trouvé,
/// et — s'il y a un défaut — quoi faire, en une phrase.
class PreflightCheck {
  const PreflightCheck(this.id, this.label, this.status, this.detail, {this.fix});

  final String id;
  final String label;
  final PreflightStatus status;
  final String detail;

  /// Le geste qui corrige. `null` quand il n'y a rien à corriger.
  final String? fix;
}

/// Le pré-vol de l'assistant : toute la chaîne, du réglage à la machine,
/// vérifiée AVANT que l'opérateur ne pose sa question.
///
/// Pourquoi : chaque maillon savait déjà dire qu'il était cassé, mais
/// seulement au moment où l'on s'en servait — clé absente au premier message,
/// contexte trop court au premier tour, photo ignorée sans un mot. Le pré-vol
/// rassemble ces vérifications, toutes déterministes, en une liste lisible.
/// Rien n'y est estimé : un point qu'on ne peut pas vérifier est marqué
/// « non vérifiable », pas « ok ».
class AiPreflightReport {
  const AiPreflightReport(this.checks, this.at);

  final List<PreflightCheck> checks;
  final DateTime at;

  int count(PreflightStatus s) => checks.where((c) => c.status == s).length;

  /// Prêt = aucun point bloquant.
  bool get ready => count(PreflightStatus.failed) == 0;

  PreflightStatus get worst => count(PreflightStatus.failed) > 0
      ? PreflightStatus.failed
      : count(PreflightStatus.warning) > 0
          ? PreflightStatus.warning
          : PreflightStatus.ok;

  PreflightCheck? byId(String id) {
    for (final c in checks) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Une clé Gemini est-elle enregistrée ? `null` = illisible (coffre de la
/// plateforme indisponible). Injectable : le coffre n'existe pas en test.
final aiApiKeyProbeProvider = Provider<Future<bool?> Function()>((ref) {
  return () async {
    try {
      final key = await ref.read(aiAgentSettingsProvider.notifier).readApiKey();
      return key != null && key.isNotEmpty;
    } catch (_) {
      return null;
    }
  };
});

/// Le réseau qui porte Gemini est-il disponible ? `null` = non vérifiable ici
/// (seul Android sait interroger la 4G).
final aiCloudNetworkProbeProvider = Provider<Future<bool?> Function()>((ref) {
  return () async {
    try {
      return await CellularNetwork.isAvailable();
    } catch (_) {
      return null;
    }
  };
});

/// Lance le pré-vol. `ref.invalidate(aiPreflightProvider)` le relance.
final aiPreflightProvider = FutureProvider<AiPreflightReport>((ref) async {
  final settings = ref.watch(aiAgentSettingsProvider);
  final discovery = ref.watch(ollamaDiscoveryProvider);
  final checks = <PreflightCheck>[];
  final local = settings.localBaseUrl.isNotEmpty;

  // 1. L'agent est-il activé ?
  checks.add(settings.enabled
      ? const PreflightCheck('agent', 'Agent activé', PreflightStatus.ok,
          'L\'assistant peut consulter et piloter la machine.')
      : const PreflightCheck('agent', 'Agent activé', PreflightStatus.warning,
          'Désactivé : seules les commandes du lexique fermé sont comprises.',
          fix: 'Paramètres > Agent IA > « Agent IA activé ».'));

  final hasKey = await ref.read(aiApiKeyProbeProvider)();

  // 2-4. Le fournisseur : joignable, modèle présent, capable.
  OllamaServer? server;
  if (local) {
    final diag = await discovery.diagnose(settings.localBaseUrl, wantedModel: settings.localModel);
    server = diag.server;
    if (diag.server == null && !diag.ok) {
      // Injoignable, sans modèle, ou modèle inutilisable : le message de
      // `diagnose` est déjà écrit pour l'opérateur.
      final probed = await discovery.probe(
          LocalAiAgentService.normalizeBaseUrl(settings.localBaseUrl),
          timeout: const Duration(seconds: 3));
      if (probed == null) {
        checks.add(PreflightCheck('fournisseur', 'Serveur local joignable',
            PreflightStatus.failed, diag.message,
            fix: settings.cloudFallback && hasKey == true
                ? 'Le secours Gemini prendra le relais. Sinon : lance Ollama sur le PC.'
                : 'Lance Ollama sur le PC, même Wi-Fi que cet appareil.'));
      } else {
        server = await discovery.describe(probed);
        checks.add(PreflightCheck('fournisseur', 'Serveur local joignable',
            PreflightStatus.ok, 'Ollama répond sur ${probed.host}.'));
        checks.add(PreflightCheck('modele', 'Modèle pilote « ${settings.localModel} »',
            PreflightStatus.failed, diag.message,
            fix: 'Paramètres > Agent IA > « Chercher mon serveur », puis choisis un modèle de la liste.'));
      }
    } else {
      final pilot = server!.models
          .where((m) => LocalAiAgentService.isListed([m.name], settings.localModel))
          .firstOrNull;
      checks.add(PreflightCheck('fournisseur', 'Serveur local joignable',
          PreflightStatus.ok, 'Ollama répond sur ${server.host}, ${server.models.length} modèle(s).'));
      checks.add(PreflightCheck(
          'modele',
          'Modèle pilote « ${settings.localModel} »',
          PreflightStatus.ok,
          pilot?.contextTokens == null
              ? 'Installé. Contexte non annoncé par le serveur.'
              : 'Installé, contexte ${pilot!.contextTokens} tokens.'));
      checks.add(pilot?.supportsTools == null
          ? const PreflightCheck('outils', 'Appel d\'outils', PreflightStatus.skipped,
              'Le serveur ne dit pas si ce modèle sait appeler des outils.')
          : const PreflightCheck('outils', 'Appel d\'outils', PreflightStatus.ok,
              'Le modèle sait appeler des outils : il peut agir, pas seulement répondre.'));
    }
  } else {
    final net = await ref.read(aiCloudNetworkProbeProvider)();
    final model = ref.read(aiModelProvider).active.id;
    checks.add(switch (hasKey) {
      true => PreflightCheck('fournisseur', 'Clé Gemini', PreflightStatus.ok,
          'Clé enregistrée. Modèle : $model.'),
      false => const PreflightCheck('fournisseur', 'Clé Gemini', PreflightStatus.failed,
          'Aucune clé enregistrée, et aucun serveur local réglé : l\'assistant ne peut pas répondre.',
          fix: 'Paramètres > Agent IA : enregistre une clé, ou « Chercher mon serveur » pour un modèle local.'),
      null => const PreflightCheck('fournisseur', 'Clé Gemini', PreflightStatus.skipped,
          'Coffre de clés illisible sur cet appareil : non vérifiable.'),
    });
    checks.add(switch (net) {
      true => const PreflightCheck('reseau', 'Réseau vers Gemini', PreflightStatus.ok,
          'Données mobiles disponibles.'),
      false => const PreflightCheck('reseau', 'Réseau vers Gemini', PreflightStatus.failed,
          'Données mobiles coupées : le Wi-Fi de la machine n\'a pas Internet.',
          fix: 'Active les données mobiles en gardant le Wi-Fi de la machine.'),
      null => const PreflightCheck('reseau', 'Réseau vers Gemini', PreflightStatus.skipped,
          'Non vérifiable depuis cet appareil.'),
    });
  }

  // 5. Les images : qui les lit ?
  if (local) {
    final vision = settings.localVisionModel;
    if (vision.isEmpty) {
      final seeing = server == null
          ? null
          : OllamaDiscovery.recommendVision(server.models, main: settings.localModel);
      checks.add(PreflightCheck('images', 'Lecture des images', PreflightStatus.warning,
          'Aucun modèle d\'images branché : une photo jointe ne sera pas lue.',
          fix: seeing == null
              ? 'Installe un modèle qui voit (gemma3n), puis branche-le dans le Backoffice.'
              : 'Backoffice > Santé > « ${seeing.name} » > BRANCHER.'));
    } else if (server != null &&
        !server.models.any((m) => LocalAiAgentService.isListed([m.name], vision))) {
      checks.add(PreflightCheck('images', 'Lecture des images', PreflightStatus.failed,
          'Le modèle d\'images « $vision » n\'est pas installé sur le serveur.',
          fix: 'ollama pull $vision, ou choisis-en un autre dans le Backoffice.'));
    } else {
      checks.add(PreflightCheck('images', 'Lecture des images',
          server == null ? PreflightStatus.skipped : PreflightStatus.ok,
          server == null
              ? 'Réglé sur « $vision », non vérifiable sans le serveur.'
              : 'Les photos vont à « $vision », qui décrit ; le pilote agit ensuite.'));
    }
  } else {
    checks.add(const PreflightCheck('images', 'Lecture des images', PreflightStatus.ok,
        'Gemini lit les images lui-même.'));
  }

  // 6. Le lexique fermé (compréhension sans modèle, arrêt d'urgence multilingue).
  if (!settings.lexiconEnabled) {
    checks.add(const PreflightCheck('lexique', 'Lexique fermé', PreflightStatus.warning,
        'Coupé : sans modèle joignable, plus aucune commande n\'est comprise.',
        fix: 'Paramètres > Agent IA > « Comprendre les commandes sans l\'IA ».'));
  } else {
    final load = ref.watch(lexiconLoadProvider);
    final lexicon = load.valueOrNull?.lexicon;
    checks.add(load.isLoading
        ? const PreflightCheck('lexique', 'Lexique fermé', PreflightStatus.skipped,
            'Chargement en cours.')
        : lexicon == null
            ? PreflightCheck('lexique', 'Lexique fermé', PreflightStatus.warning,
                'Illisible (${load.valueOrNull?.failure ?? 'erreur'}) : l\'assistant dépend du modèle seul.')
            : const PreflightCheck('lexique', 'Lexique fermé', PreflightStatus.ok,
                'Chargé : ordres courts et arrêt d\'urgence compris sans modèle.'));
  }

  // 7. Le secours.
  if (local) {
    checks.add(!settings.cloudFallback
        ? const PreflightCheck('secours', 'Secours Gemini', PreflightStatus.skipped,
            'Coupé (par défaut) : si le serveur tombe, l\'agent attend son retour.')
        : hasKey == true
            ? const PreflightCheck('secours', 'Secours Gemini', PreflightStatus.ok,
                'Activé : un tour sans serveur local part chez Gemini, et c\'est dit.')
            : const PreflightCheck('secours', 'Secours Gemini', PreflightStatus.warning,
                'Activé, mais aucune clé Gemini lisible : il ne pourra pas servir.',
                fix: 'Enregistre une clé Gemini, ou coupe le secours.'));
  }

  // 8. La machine : l'agent peut-il agir ?
  MachineStatus? status;
  try {
    status = ref.read(machineRepositoryProvider).currentState.status;
  } catch (_) {
    status = null;
  }
  checks.add(status == null || status == MachineStatus.offline
      ? const PreflightCheck('machine', 'Liaison machine', PreflightStatus.warning,
          'Carte hors ligne : l\'assistant répond, mais aucune action n\'atteindra la machine.',
          fix: 'Connexion ESP32 (icône Wi-Fi), ou mode simulation.')
      : status == MachineStatus.alarm
          ? const PreflightCheck('machine', 'Liaison machine', PreflightStatus.warning,
              'Carte en ALARME : les mouvements seront refusés jusqu\'au déverrouillage.',
              fix: 'Demande « déverrouille l\'alarme », ou refais une prise d\'origine.')
          : PreflightCheck('machine', 'Liaison machine', PreflightStatus.ok,
              'Carte en ligne (${status.name}).'));

  return AiPreflightReport(checks, DateTime.now());
});
