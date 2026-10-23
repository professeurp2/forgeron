import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../providers/ai_agent_settings_provider.dart' show defaultLocalModel;
import 'local_ai_agent_service.dart';

/// Un modèle servi par Ollama, avec ce qu'il faut pour dire à un opérateur s'il
/// convient — sans qu'il ait à connaître un nom de modèle.
class OllamaModel {
  const OllamaModel(this.name, {this.supportsTools, this.contextTokens});

  final String name;

  /// Le modèle sait appeler des outils (piloter la machine). `null` : le
  /// serveur ne l'a pas dit. Sans cela, l'agent répondrait mais n'agirait jamais.
  final bool? supportsTools;
  final int? contextTokens;

  /// Pourquoi l'agent ne peut pas s'en servir (`null` s'il le peut). N'est écarté
  /// que ce qui est CONNU pour ne pas convenir : ne sait pas appeler d'outils, ou
  /// contexte trop court (le serveur tronquerait le prompt sans rien dire).
  String? get unusableReason {
    if (supportsTools == false) return 'tools';
    if (LocalAiAgentService.problemFor(name, LocalModelInfo(contextTokens: contextTokens)) != null) {
      return 'context';
    }
    return null;
  }

  bool get usable => unusableReason == null;
}

class OllamaServer {
  const OllamaServer(this.url, this.models);

  /// Adresse complète (`http://192.168.0.42:11434`).
  final String url;
  final List<OllamaModel> models;

  /// Adresse sans schéma ni port, ce que l'opérateur reconnaît.
  String get host => Uri.parse(url).host;
}

/// Ce que dit le diagnostic d'une adresse saisie ou déjà enregistrée.
class OllamaDiagnosis {
  const OllamaDiagnosis.ok(this.server, this.message)
      : ok = true;
  const OllamaDiagnosis.failed(this.message)
      : ok = false,
        server = null;

  final bool ok;
  final OllamaServer? server;

  /// Phrase pour l'opérateur, sans jargon.
  final String message;
}

/// Trouve et décrit un serveur Ollama sur le réseau — pour qu'un utilisateur
/// non technique n'ait ni adresse IP, ni port, ni nom de modèle à saisir.
///
/// Le réseau en question est celui du téléphone : s'il est joint à l'AP de
/// l'ESP32 (192.168.0.x), le PC doit y être aussi, et c'est ce sous-réseau
/// qu'on balaie.
class OllamaDiscovery {
  OllamaDiscovery({
    http.Client? client,
    Future<List<String>> Function()? localAddresses,
    this.probeTimeout = const Duration(milliseconds: 700),
    this.concurrency = 48,
  })  : _client = client ?? http.Client(),
        _localAddresses = localAddresses ?? _deviceAddresses;

  final http.Client _client;
  final Future<List<String>> Function() _localAddresses;
  final Duration probeTimeout;
  final int concurrency;

  static const port = 11434;

  /// Adresses IPv4 de l'appareil (hors boucle locale).
  static Future<List<String>> _deviceAddresses() async {
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return [for (final i in ifaces) for (final a in i.addresses) a.address];
    } catch (_) {
      return const [];
    }
  }

  /// Hôtes à essayer d'abord (rapides), puis le /24 de chaque réseau de
  /// l'appareil. `10.0.2.2` est le PC vu depuis l'émulateur Android.
  Future<List<String>> candidateHosts() async {
    final hosts = <String>['localhost', '127.0.0.1', '10.0.2.2'];
    for (final ip in await _localAddresses()) {
      final p = ip.split('.');
      if (p.length != 4) continue;
      final base = '${p[0]}.${p[1]}.${p[2]}';
      for (var i = 1; i <= 254; i++) {
        final h = '$base.$i';
        if (h != ip && !hosts.contains(h)) hosts.add(h);
      }
    }
    return hosts;
  }

  /// Interroge `/api/tags` : répond « c'est Ollama » ET donne ses modèles. Une
  /// seule requête par hôte, pour que le balayage d'un /24 reste court.
  Future<OllamaServer?> probe(String url, {Duration? timeout}) async {
    try {
      final res = await _client
          .get(Uri.parse('$url/api/tags'))
          .timeout(timeout ?? probeTimeout);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map || json['models'] is! List) return null;
      final names = [
        for (final m in json['models'] as List)
          if (m is Map && m['name'] != null) '${m['name']}',
      ];
      return OllamaServer(url, [for (final n in names) OllamaModel(n)]);
    } catch (_) {
      return null;
    }
  }

  /// Balaie le réseau. [onProgress] reçoit une fraction de 0 à 1. Rend tous les
  /// serveurs trouvés, le premier atteint en tête.
  Future<List<OllamaServer>> scan({void Function(double)? onProgress}) async {
    final hosts = await candidateHosts();
    final found = <OllamaServer>[];
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= hosts.length) return;
        final s = await probe('http://${hosts[i]}:$port');
        if (s != null && !found.any((f) => _sameServer(f, s))) found.add(s);
        done++;
        onProgress?.call(done / hosts.length);
      }
    }

    await Future.wait([for (var k = 0; k < concurrency; k++) worker()]);
    return found;
  }

  // « localhost » et « 127.0.0.1 » sont le même PC : une seule fiche.
  static bool _sameServer(OllamaServer a, OllamaServer b) =>
      a.models.map((m) => m.name).join('|') == b.models.map((m) => m.name).join('|') &&
      (a.host == b.host || {'localhost', '127.0.0.1'}.containsAll([a.host, b.host]));

  /// Complète chaque modèle : sait-il appeler des outils ? quel contexte ?
  /// (`/api/show`, en parallèle.)
  Future<OllamaServer> describe(OllamaServer s) async {
    Future<OllamaModel> one(OllamaModel m) async {
      try {
        final res = await _client
            .post(
              Uri.parse('${s.url}/api/show'),
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({'model': m.name}),
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode != 200) return m;
        final json = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
        final caps = (json['capabilities'] as List?)?.map((e) => '$e').toList();
        final info = LocalAiAgentService.parseShow(json);
        return OllamaModel(
          m.name,
          // Les versions d'Ollama qui ne listent pas les capacités ne disent
          // rien : on ne déclare pas « incapable » ce qu'on ne sait pas.
          supportsTools: caps == null ? null : caps.contains('tools'),
          contextTokens: info.contextTokens,
        );
      } catch (_) {
        return m;
      }
    }

    return OllamaServer(s.url, await Future.wait(s.models.map(one)));
  }

  /// Le modèle à proposer d'office : celui de Forgeron s'il est là, puis les
  /// familles mesurées par le banc, puis n'importe quel modèle capable
  /// d'appeler des outils. `null` si aucun ne convient.
  static OllamaModel? recommend(List<OllamaModel> models) {
    final usable = models.where((m) => m.usable).toList();
    if (usable.isEmpty) return null;
    int rank(OllamaModel m) {
      final n = m.name.toLowerCase();
      // Le modèle par défaut, validé par le banc ; puis ses dérivés, sauf ceux
      // qui « réfléchissent » (6 à 13 s par réponse, trop lent devant la machine).
      if (n == defaultLocalModel || n.startsWith('$defaultLocalModel:')) return 0;
      if (n.startsWith('forgeron') && !n.contains('reflexion')) return 1;
      if (n.startsWith('qwen3')) return 2;
      if (n.startsWith('qwen2.5')) return 3;
      return m.supportsTools == true ? 4 : 5;
    }

    usable.sort((a, b) => rank(a).compareTo(rank(b)));
    return usable.first;
  }

  /// Vérifie une adresse (saisie ou enregistrée) et dit, en phrases simples,
  /// ce qui ne va pas.
  Future<OllamaDiagnosis> diagnose(String rawUrl, {String? wantedModel}) async {
    final url = LocalAiAgentService.normalizeBaseUrl(rawUrl);
    if (url.isEmpty) {
      return const OllamaDiagnosis.failed('Aucun serveur choisi.');
    }
    final s = await probe(url, timeout: const Duration(seconds: 4));
    if (s == null) {
      return const OllamaDiagnosis.failed(
          'Je ne joins pas ce serveur. Vérifie que le téléphone et le PC sont '
          'sur le même Wi-Fi, qu\'Ollama est lancé sur le PC, et qu\'il est '
          'ouvert au réseau (voir « Ça ne marche pas ? »).');
    }
    final full = await describe(s);
    if (full.models.isEmpty) {
      return const OllamaDiagnosis.failed(
          'Ollama répond, mais aucun modèle n\'est installé sur le PC.');
    }
    if (wantedModel != null && wantedModel.isNotEmpty) {
      final m = full.models.where((m) => LocalAiAgentService.isListed([m.name], wantedModel));
      if (m.isEmpty) {
        return OllamaDiagnosis.failed(
            'Ollama répond, mais le modèle « $wantedModel » n\'est pas installé. '
            'Choisis-en un dans la liste.');
      }
      if (!m.first.usable) {
        return OllamaDiagnosis.failed(m.first.unusableReason == 'context'
            ? '« $wantedModel » a un contexte trop court : l\'assistant serait tronqué '
                'sans rien dire. Choisis un modèle « forgeron-… » ou un autre de la liste.'
            : '« $wantedModel » ne sait pas piloter la machine : l\'assistant '
                'pourrait discuter mais jamais agir. Choisis un autre modèle.');
      }
    }
    return OllamaDiagnosis.ok(full, 'Connecté à ${full.host}.');
  }
}

/// Aide en langage simple quand le serveur reste introuvable.
const kOllamaHelpSteps = <String>[
  'Sur le PC, installe Ollama (ollama.com) et ouvre-le : une icône apparaît près de l\'horloge.',
  'Dans les réglages d\'Ollama, active « Exposer Ollama au réseau » (ou, pour les connaisseurs, la variable OLLAMA_HOST=0.0.0.0), puis redémarre Ollama.',
  'Quand Windows demande l\'autorisation du pare-feu, accepte pour les réseaux privés.',
  'Connecte le PC et le téléphone au même Wi-Fi (par exemple celui de la machine), puis relance la recherche.',
];
