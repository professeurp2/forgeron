import 'dart:collection';
import 'dart:convert';
import 'dart:math' show max, min;
import 'package:http/http.dart' as http;

import 'ai_agent_service.dart';

/// Ce que le serveur local sait dire de SON modèle — pas ce que le modèle sait
/// faire en théorie, mais ce que ce serveur lui laisse faire.
///
/// Le contexte en est l'exemple type : Qwen2.5 en annonce 32 768, Ollama le
/// charge pourtant à 4 096 (mesuré, `ollama ps`) et tronque le prompt EN
/// SILENCE quand il déborde — par le début, donc le prompt système part en
/// premier.
class LocalModelInfo {
  /// Le modèle lit-il les images ? Faux par défaut : mieux vaut ne pas envoyer
  /// une image qu'une erreur HTTP 400 qui, l'image restant dans l'historique,
  /// casserait tous les tours suivants.
  final bool supportsImages;

  /// Fenêtre de contexte EFFECTIVE en tokens ; `null` si le serveur ne la dit
  /// pas (tout serveur qui n'est pas Ollama).
  final int? contextTokens;

  const LocalModelInfo({this.supportsImages = false, this.contextTokens});
}

/// Agent servi par un **modèle local** exposant l'API OpenAI `/v1/chat/…`
/// (Ollama, llama.cpp, LM Studio, vLLM…), sur le réseau de l'atelier.
///
/// ── Pourquoi c'est un simple client HTTP ───────────────────────────────────
///
/// Aucun pont natif ici, contrairement à [AiAgentService] et son
/// [CellularHttpClient]. Quand le téléphone rejoint l'AP de l'ESP32, le code
/// natif appelle `bindProcessToNetwork` : TOUT le processus sort déjà par ce
/// WiFi — c'est ce qui fait marcher le WebSocket FluidNC. Gemini est
/// l'exception qui doit forcer la 4G, faute d'Internet sur cet AP. Un serveur
/// local vit précisément SUR ce réseau : le client standard est non seulement
/// suffisant, il est le seul correct. Router `192.168.x.x` vers la 4G
/// n'aboutirait nulle part.
///
/// ── Ce que fait cette classe ───────────────────────────────────────────────
///
/// Elle traduit, dans les deux sens, entre le format Gemini que parle le reste
/// de l'application et le format OpenAI que parlent les serveurs locaux :
///
/// | Gemini                                   | OpenAI                          |
/// |------------------------------------------|---------------------------------|
/// | `contents[].role: user \| model`          | `messages[].role: user \| assistant` |
/// | `parts[].text`                            | `content`                       |
/// | `parts[].inlineData`                      | `content[].image_url` (data URI)|
/// | `parts[].functionCall{name,args}`         | `tool_calls[].function`         |
/// | `parts[].functionResponse{name,response}` | `{role:'tool', tool_call_id}`   |
/// | `systemInstruction`                       | `messages[0].role = 'system'`   |
///
/// **Le piège principal, c'est l'appariement des appels d'outils.** Gemini
/// relie une réponse à son appel par le NOM de la fonction ; OpenAI exige un
/// `tool_call_id` unique. Il faut donc parcourir l'historique dans l'ordre, en
/// attribuant un identifiant à chaque appel et en le rendant à la première
/// réponse portant le même nom. Sans cela, tout échange comportant plus d'un
/// appel d'outil devient invalide dès le deuxième tour — et l'agent en
/// enchaîne couramment plusieurs.
class LocalAiAgentService implements AiBackend {
  /// Racine du serveur, sans chemin — ex. `http://192.168.0.42:11434`.
  final String baseUrl;

  @override
  final String model;

  final http.Client _client;

  /// Un modèle local répond plus lentement qu'une API distante sur les longs
  /// contextes (et le premier appel paie le chargement en VRAM).
  final Duration timeout;

  /// Capacités du modèle, sondées une fois à la création du service (voir
  /// [probe]). Sans sondage : un modèle texte seul au contexte inconnu.
  final LocalModelInfo info;

  LocalAiAgentService({
    required this.baseUrl,
    required this.model,
    this.info = const LocalModelInfo(),
    http.Client? client,
    this.timeout = const Duration(seconds: 180),
  }) : _client = client ?? http.Client();

  // ── Contexte ──────────────────────────────────────────────────────────────

  /// Part du contexte prise par ce qui n'est PAS l'historique : le prompt
  /// système et les déclarations des 38 outils.
  ///
  /// Mesuré à 6 827 tokens sur la vraie charge utile (prompt ~2 000, outils
  /// ~4 800) ; la marge couvre ce que le prompt injecte à chaque tour et qui
  /// varie (journal d'activité, cinématique). `test/local_ai_agent_live_test.dart`
  /// échoue dès que la charge utile dépasse cette valeur — typiquement quand
  /// on ajoute des outils — pour que le budget d'historique ne devienne pas
  /// trop généreux sans que personne s'en aperçoive.
  static const promptOverheadTokens = 10000;

  /// Place laissée à la réponse — un appel d'outil ou un paragraphe.
  static const replyTokens = 1500;

  /// Caractères de JSON par token, côté prudent : le français accentué et les
  /// lignes de G-code (chiffres, points) se découpent plus finement que la
  /// prose anglaise.
  static const charsPerToken = 3;

  /// Serveur qui ne dit pas son contexte : on suppose petit. Se tromper vers le
  /// bas coûte un historique plus court ; se tromper vers le haut coûte le
  /// prompt système, en silence.
  static const fallbackContextTokens = 8192;

  /// Le prompt de l'agent n'y tient pas : en dessous, [historyBudgetChars] n'a
  /// plus de sens et le serveur tronquerait le prompt.
  static const minUsableContextTokens = 8192;

  /// Contexte qu'Ollama alloue quand le modèle n'en fixe pas (`num_ctx` absent
  /// du Modelfile) — mesuré à 4 096 sur une carte de 8 Go.
  static const ollamaDefaultContextTokens = 4096;

  /// Plafond d'historique au-delà duquel un modèle de 7 milliards de paramètres
  /// devient peu fiable, QUELLE QUE SOIT la taille de sa fenêtre.
  ///
  /// Mesuré sur une vraie discussion rejouée 30 fois par budget (Qwen2.5-7B,
  /// contexte 16 384, question « état de la machine ») : le bon appel d'outil
  /// sort 28/30 à 4 000 caractères, 29/30 à 12 000, mais seulement 18/30 à
  /// 22 000 — le reste, c'est du texte à la place de l'appel, ou une réponse
  /// qui ignore l'outil. La fenêtre n'était pas pleine (11 400 tokens sur
  /// 16 384) : le modèle se noie avant que le serveur ne tronque.
  ///
  /// C'est un plafond, pas une garantie : une discussion extrême (40
  /// interrogations d'état d'affilée) reste autour de 50 % quel que soit le
  /// plafond, le modèle recopiant alors d'anciennes valeurs au lieu de relire
  /// l'outil. Les vrais leviers sont un modèle plus gros ou moins d'outils
  /// déclarés par tour (~4 800 des ~6 800 tokens fixes). Un modèle plus gros
  /// pourra relever ce plafond, après mesure.
  static const reliableHistoryChars = 12000;

  @override
  int get historyBudgetChars {
    final ctx = info.contextTokens ?? fallbackContextTokens;
    final tokens = ctx - promptOverheadTokens - replyTokens;
    return max(4000, min(tokens * charsPerToken, reliableHistoryChars));
  }

  /// Non nul si le serveur ne peut pas faire tourner l'agent tel quel — à
  /// montrer à l'opérateur AVANT la première question plutôt que de laisser le
  /// serveur dégrader les réponses sans rien dire.
  String? get configurationProblem => problemFor(model, info);

  /// Même verdict sans instancier de service — l'écran de réglages s'en sert
  /// pour le bouton « Tester », avant que l'adresse soit enregistrée.
  static String? problemFor(String model, LocalModelInfo info) {
    final ctx = info.contextTokens;
    if (ctx == null || ctx >= minUsableContextTokens) return null;
    return 'Le modèle local « $model » n\'a qu\'un contexte de $ctx tokens, '
        'trop court : le prompt de l\'agent à lui seul en occupe '
        '~$promptOverheadTokens et le serveur le tronquerait sans rien signaler. '
        'Crée le modèle dérivé : « ollama create forgeron-qwen -f '
        'tool/ollama/Modelfile », puis choisis-le dans Paramètres > Agent IA.';
  }

  /// [wanted] figure-t-il dans la liste `/v1/models` du serveur ?
  ///
  /// Ollama complète un nom sans étiquette par `:latest` — `forgeron-qwen`
  /// répond aux requêtes — mais LISTE le modèle sous son nom complet,
  /// `forgeron-qwen:latest`. Une comparaison stricte déclarait donc absent un
  /// modèle présent (constaté sur le bouton « Tester » avec le nom par
  /// défaut), et faisait chercher un problème qui n'existait pas.
  static bool isListed(Iterable<String> ids, String wanted) {
    final name = wanted.trim();
    if (name.isEmpty) return false;
    if (ids.contains(name)) return true;
    return !name.contains(':') && ids.contains('$name:latest');
  }

  /// Interroge `/api/show` (Ollama) pour lire ce que le serveur dit de ce
  /// modèle. Toute erreur — serveur injoignable, autre que Ollama, modèle
  /// absent — rend un [LocalModelInfo] vide : le sondage est une aide, jamais
  /// une condition d'envoi.
  static Future<LocalModelInfo> probe(
    String baseUrl,
    String model, {
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse('$baseUrl/api/show'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'model': model}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return const LocalModelInfo();
      return parseShow(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } catch (_) {
      return const LocalModelInfo();
    } finally {
      if (client == null) c.close();
    }
  }

  /// Réponse de `/api/show` → [LocalModelInfo].
  static LocalModelInfo parseShow(Map<String, dynamic> json) {
    final capabilities = (json['capabilities'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    int? ctx;
    final parameters = json['parameters'];
    if (parameters is String) {
      final m = RegExp(r'^\s*num_ctx\s+(\d+)', multiLine: true)
          .firstMatch(parameters);
      ctx = int.tryParse(m?.group(1) ?? '');
    }
    // C'est bien Ollama qui répond (ces clés n'existent pas ailleurs) mais le
    // modèle ne fixe pas son contexte : c'est le défaut du serveur qui joue.
    if (ctx == null &&
        (json.containsKey('modelfile') || json.containsKey('model_info'))) {
      ctx = ollamaDefaultContextTokens;
    }

    return LocalModelInfo(
      supportsImages: capabilities.contains('vision'),
      contextTokens: ctx,
    );
  }

  /// Normalise ce que l'opérateur a saisi : `192.168.0.42` devient
  /// `http://192.168.0.42:11434`, une barre finale est retirée.
  static String normalizeBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    // Hôte nu sans port : celui d'Ollama par défaut.
    final uri = Uri.tryParse(s);
    if (uri != null && !uri.hasPort) s = '$s:11434';
    return s;
  }

  Uri get _endpoint => Uri.parse('$baseUrl/v1/chat/completions');

  static const Map<String, String> _headers = {
    'content-type': 'application/json',
    // Ollama ignore la clé, les serveurs compatibles OpenAI l'exigent parfois.
    'authorization': 'Bearer local',
  };

  // ── Gemini → OpenAI ───────────────────────────────────────────────────────

  /// Texte laissé à la place d'une image qu'un modèle texte seul ne peut pas
  /// lire.
  ///
  /// Deux raisons de ne pas la supprimer sans rien dire. Le modèle doit SAVOIR
  /// qu'une image existait : sans cela, interrogé sur une image qu'il n'a
  /// jamais vue, il en invente une description — c'est le pire des cas pour un
  /// opérateur qui s'en sert pour juger d'un état de la machine. Et la phrase
  /// lui dit quoi faire (le dire), au lieu de le laisser improviser.
  ///
  /// Formulée comme un constat adressé au modèle plutôt que comme une consigne
  /// à relayer : une première version (« dis-le à l'opérateur ») a été reprise
  /// presque telle quelle dans la réponse de Qwen2.5-7B (observé une fois).
  static const imageNote = '[Image jointe par l\'opérateur — tu ne peux pas la '
      'voir, ce modèle ne lit que du texte. Réponds sans la décrire et '
      'préviens l\'opérateur que tu n\'as pas pu l\'examiner.]';

  /// Début de la fiche qu'écrit le modèle d'images (voir [imageFichePart]).
  static const imageFichePrefix = '[Fiche d\'image';

  /// Remplace l'image, pour un modèle texte seul, quand le modèle d'images l'a
  /// déjà examinée.
  ///
  /// Sans elle, le pilote recevait [imageNote] (« tu ne peux pas la voir…
  /// préviens l'opérateur ») au tour suivant, alors que la description était
  /// juste au-dessus : il annonçait n'avoir pas vu la photo qu'on venait de
  /// lui décrire. La fiche lui donne ce qui a été vu ; la note lui interdit
  /// d'y ajouter quoi que ce soit.
  static const imageFicheNote = '[Image jointe — tu ne la vois pas toi-même. '
      'Le modèle d\'images l\'a examinée : sa fiche suit. Appuie-toi sur elle, '
      'sans rien affirmer de l\'image qu\'elle ne dise pas.]';

  /// Longueur maximale d'une fiche : elle reste dans l'historique à chaque
  /// tour, et le plafond fiable du modèle local est de 12 000 caractères
  /// ([reliableHistoryChars]).
  static const imageFicheMaxChars = 1500;

  /// Part texte à joindre au message qui porte l'image, avec ce qu'en a dit
  /// le modèle d'images [model].
  static Map<String, dynamic> imageFichePart(String description, String model) {
    var d = description.trim();
    if (d.length > imageFicheMaxChars) {
      d = '${d.substring(0, imageFicheMaxChars)}…';
    }
    return {'text': '$imageFichePrefix — rédigée par le modèle d\'images $model]\n$d'};
  }

  static bool _isImageFiche(Map p) =>
      p['text'] is String && (p['text'] as String).startsWith(imageFichePrefix);

  /// Historique Gemini → `messages` OpenAI.
  ///
  /// [supportsImages] à `false` remplace chaque image par [imageNote] : un
  /// serveur qui reçoit une image qu'il ne sait pas lire répond HTTP 400, et
  /// comme l'historique garde toujours la dernière image, TOUS les tours
  /// suivants échoueraient — la discussion serait cassée jusqu'à son
  /// effacement. Si le message porte une fiche du modèle d'images, c'est
  /// [imageFicheNote] qui remplace l'image, et la fiche suit.
  static List<Map<String, dynamic>> toOpenAiMessages(
    List<Map<String, dynamic>> contents,
    String? systemPrompt, {
    bool supportsImages = true,
  }) {
    final out = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      out.add({'role': 'system', 'content': systemPrompt});
    }

    // Identifiants d'appels en attente de leur réponse, par nom d'outil. Une
    // file et non une simple valeur : le même outil peut être appelé plusieurs
    // fois avant que les réponses n'arrivent.
    final pendingIds = <String, Queue<String>>{};
    var seq = 0;

    for (final content in contents) {
      final role = content['role'] as String? ?? 'user';
      final parts =
          (content['parts'] as List?)?.whereType<Map>().toList() ?? const [];

      final texts = <String>[];
      final images = <Map<String, dynamic>>[];
      final toolCalls = <Map<String, dynamic>>[];
      final toolMessages = <Map<String, dynamic>>[];
      final hasFiche = parts.any(_isImageFiche);

      for (final raw in parts) {
        final p = raw.cast<String, dynamic>();

        if (p.containsKey('text')) {
          final t = p['text'] as String? ?? '';
          if (t.isNotEmpty) texts.add(t);
        } else if (p.containsKey('inlineData')) {
          if (!supportsImages) {
            texts.add(hasFiche ? imageFicheNote : imageNote);
            continue;
          }
          final d = (p['inlineData'] as Map).cast<String, dynamic>();
          final mime = d['mimeType'] as String? ?? 'image/jpeg';
          images.add({
            'type': 'image_url',
            'image_url': {'url': 'data:$mime;base64,${d['data']}'},
          });
        } else if (p.containsKey('functionCall')) {
          final fc = (p['functionCall'] as Map).cast<String, dynamic>();
          final name = fc['name'] as String? ?? '';
          final id = 'call_${seq++}';
          (pendingIds[name] ??= Queue<String>()).add(id);
          toolCalls.add({
            'id': id,
            'type': 'function',
            'function': {
              'name': name,
              'arguments': jsonEncode(fc['args'] ?? const <String, dynamic>{}),
            },
          });
        } else if (p.containsKey('functionResponse')) {
          final fr = (p['functionResponse'] as Map).cast<String, dynamic>();
          final name = fr['name'] as String? ?? '';
          final queue = pendingIds[name];
          // Repli sur un identifiant dérivé du nom si l'appel correspondant
          // manque (historique tronqué par la compaction, par exemple).
          final id = (queue != null && queue.isNotEmpty)
              ? queue.removeFirst()
              : 'call_$name';
          toolMessages.add({
            'role': 'tool',
            'tool_call_id': id,
            'content': jsonEncode(fr['response'] ?? const <String, dynamic>{}),
          });
        }
      }

      // Les réponses d'outils sont des messages autonomes chez OpenAI, et
      // doivent précéder tout nouveau tour de l'utilisateur.
      out.addAll(toolMessages);

      if (role == 'model') {
        if (texts.isNotEmpty || toolCalls.isNotEmpty) {
          out.add({
            'role': 'assistant',
            'content': texts.isEmpty ? null : texts.join('\n'),
            if (toolCalls.isNotEmpty) 'tool_calls': toolCalls,
          });
        }
      } else if (images.isNotEmpty) {
        out.add({
          'role': 'user',
          'content': [
            if (texts.isNotEmpty) {'type': 'text', 'text': texts.join('\n')},
            ...images,
          ],
        });
      } else if (texts.isNotEmpty) {
        out.add({'role': 'user', 'content': texts.join('\n')});
      }
    }
    return out;
  }

  /// Déclarations d'outils Gemini → `tools` OpenAI.
  ///
  /// Le schéma repasse en minuscules : `AiTool` part d'un JSON Schema
  /// classique que `_toGeminiSchema` met en majuscules pour Google. OpenAI
  /// veut la casse d'origine.
  static List<Map<String, dynamic>> toOpenAiTools(
    List<Map<String, dynamic>> declarations,
  ) =>
      declarations
          .map((d) => {
                'type': 'function',
                'function': {
                  'name': d['name'],
                  'description': d['description'],
                  'parameters': _lowerCaseSchema(
                    (d['parameters'] as Map?)?.cast<String, dynamic>() ??
                        const {'type': 'object', 'properties': {}},
                  ),
                },
              })
          .toList();

  static Map<String, dynamic> _lowerCaseSchema(Map<String, dynamic> schema) {
    final out = <String, dynamic>{};
    schema.forEach((key, value) {
      if (key == 'type' && value is String) {
        out[key] = value.toLowerCase();
      } else if (key == 'properties' && value is Map) {
        out[key] = value.map((k, v) => MapEntry(
              k as String,
              _lowerCaseSchema((v as Map).cast<String, dynamic>()),
            ));
      } else if (key == 'items' && value is Map) {
        out[key] = _lowerCaseSchema(value.cast<String, dynamic>());
      } else {
        out[key] = value;
      }
    });
    // OpenAI refuse un objet sans `properties`.
    if (out['type'] == 'object' && out['properties'] == null) {
      out['properties'] = <String, dynamic>{};
    }
    return out;
  }

  // ── OpenAI → Gemini ───────────────────────────────────────────────────────

  /// `finish_reason` OpenAI → `finishReason` Gemini.
  static String mapFinishReason(Object? raw) => switch (raw) {
        'stop' || 'tool_calls' || 'function_call' => 'STOP',
        'length' => 'MAX_TOKENS',
        'content_filter' => 'SAFETY',
        String s => s.toUpperCase(),
        _ => '',
      };

  /// Décode les `arguments` d'un appel d'outil.
  ///
  /// Tolérant à dessein : un petit modèle rend parfois une chaîne vide, du
  /// JSON malformé, ou l'objet déjà décodé. Mieux vaut un appel aux arguments
  /// vides — que l'outil rejettera proprement — qu'une exception qui casse le
  /// tour entier.
  static Map<String, dynamic> decodeArgs(Object? raw) {
    if (raw == null) return const {};
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is! String || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Récupère un appel d'outil que le modèle a écrit EN TEXTE au lieu de le
  /// passer par le canal prévu.
  ///
  /// Qwen2.5-7B, sur une longue discussion, rend parfois
  /// `<tool_call>{"name": …, "arguments": {…}}</tool_call>` avec la balise
  /// remplacée par un mot sans rapport (« Ronaldo {…} », « leton {…} ») : le
  /// serveur ne la reconnaît pas et le tout arrive comme du texte, que
  /// l'opérateur verrait tel quel pendant que l'outil ne se déclenche jamais.
  ///
  /// Prudent à dessein : rien n'est touché si la réponse contient déjà un vrai
  /// appel, et seul un objet dont le `name` est un outil RÉELLEMENT déclaré est
  /// repris — un nom inventé reste du texte. Le texte autour est écarté : c'est
  /// le résultat de l'outil, au tour suivant, qui donnera la vraie réponse.
  static List<Map<String, dynamic>> recoverTextToolCalls(
      List<Map<String, dynamic>> parts, Set<String> knownTools) {
    if (knownTools.isEmpty || parts.any((p) => p.containsKey('functionCall'))) {
      return parts;
    }
    final text = parts.map((p) => p['text']).whereType<String>().join('\n');
    final recovered = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final start = text.indexOf('{', from);
      if (start < 0) break;
      final end = _closingBrace(text, start);
      if (end > start) {
        try {
          final obj = jsonDecode(text.substring(start, end + 1));
          if (obj is Map) {
            String? toolName;
            Map<String, dynamic>? toolArgs;

            // Forme 1 : {"name": "tool_name", "arguments": {...}}
            if (obj['name'] is String && knownTools.contains(obj['name'])) {
              toolName = obj['name'] as String;
              toolArgs = decodeArgs(obj['arguments'] ?? obj['parameters']);
            } else {
              // Forme 2 : tool_name({"arg": "val"}) ou tool_name {"arg": "val"}
              final prefix = text.substring(0, start).trimRight();
              final fnMatch = RegExp(r'\b([a-zA-Z0-9_]+)\s*\(?$').firstMatch(prefix);
              if (fnMatch != null) {
                final candidate = fnMatch.group(1)!;
                if (knownTools.contains(candidate)) {
                  toolName = candidate;
                  toolArgs = decodeArgs(obj);
                }
              }
            }

            if (toolName != null && toolArgs != null) {
              recovered.add({
                'functionCall': {
                  'name': toolName,
                  'args': toolArgs,
                },
              });
              from = end + 1;
              continue;
            }
          }
        } catch (_) {
          // pas du JSON : on continue plus loin
        }
      }
      from = start + 1;
    }

    if (recovered.isNotEmpty) return recovered;
    return parts;
  }

  /// Index de l'accolade qui ferme celle ouverte en [start], ou -1. Ignore les
  /// accolades des chaînes JSON.
  static int _closingBrace(String s, int start) {
    var depth = 0;
    var inString = false;
    for (var i = start; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (inString) {
        if (c == 0x5C) {
          i++; // caractère échappé
        } else if (c == 0x22) {
          inString = false;
        }
      } else if (c == 0x22) {
        inString = true;
      } else if (c == 0x7B) {
        depth++;
      } else if (c == 0x7D && --depth == 0) {
        return i;
      }
    }
    return -1;
  }

  /// Réponse complète OpenAI → [AiApiResponse] (format Gemini).
  ///
  /// [knownTools] : les outils déclarés dans la requête, pour [recoverTextToolCalls].
  static AiApiResponse fromOpenAiJson(Map<String, dynamic> json,
      {Set<String> knownTools = const {}}) {
    final usage = (json['usage'] as Map?)?.cast<String, dynamic>();
    final tokens = (usage?['total_tokens'] as num?)?.toInt() ?? 0;

    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return AiApiResponse(
          parts: const [], finishReason: 'EMPTY', totalTokens: tokens);
    }
    final choice = (choices.first as Map).cast<String, dynamic>();
    final message =
        (choice['message'] as Map?)?.cast<String, dynamic>() ?? const {};

    final parts = <Map<String, dynamic>>[];
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      parts.add({'text': content});
    }
    for (final raw in (message['tool_calls'] as List?) ?? const []) {
      final call = (raw as Map).cast<String, dynamic>();
      final fn = (call['function'] as Map?)?.cast<String, dynamic>() ?? const {};
      parts.add({
        'functionCall': {
          'name': fn['name'] ?? '',
          'args': decodeArgs(fn['arguments']),
        },
      });
    }

    final recovered = recoverTextToolCalls(parts, knownTools);
    return AiApiResponse(
      parts: recovered,
      finishReason: mapFinishReason(choice['finish_reason']),
      totalTokens: tokens,
      notes: identical(recovered, parts) ? const [] : const [noteTextCallRecovered],
    );
  }

  /// Noms des outils déclarés dans une requête.
  static Set<String> _toolNames(List<Map<String, dynamic>> declarations) =>
      {for (final d in declarations) if (d['name'] is String) d['name'] as String};

  // ── Appels ────────────────────────────────────────────────────────────────

  String _requestBody({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    required bool stream,
  }) =>
      jsonEncode({
        'model': model,
        'messages': toOpenAiMessages(contents, systemPrompt,
            supportsImages: info.supportsImages),
        if (functionDeclarations.isNotEmpty)
          'tools': toOpenAiTools(functionDeclarations),
        'stream': stream,
        if (stream) 'stream_options': {'include_usage': true},
      });

  // ── Joignabilité ──────────────────────────────────────────────────────────

  /// Le serveur est sur le WiFi de l'atelier : aucune exigence de réseau mobile.
  @override
  bool get usesCellular => false;

  /// Le serveur répond-il ? Une requête légère (`/v1/models`, la même que le
  /// bouton « Tester » des réglages), avec un délai court.
  @override
  Future<bool> isReachable() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/v1/models'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  String get unreachableMessage =>
      'Le serveur IA local ne répond pas ($baseUrl). Vérifie qu\'il est '
      'démarré (Ollama) et que cet appareil est sur le même WiFi que le PC : '
      'l\'envoi reprendra dès qu\'il répondra.';

  // ── Dérive de langue ──────────────────────────────────────────────────────

  static final _cjk = RegExp(r'[　-〿㐀-䶿一-鿿＀-￯]');

  /// Vrai si [text] contient des caractères chinois, japonais ou coréens
  /// (idéogrammes, ponctuation CJK, formes pleine largeur).
  static bool containsCjk(String text) => _cjk.hasMatch(text);

  /// Rappel ajouté au prompt système quand le modèle a dérivé en chinois.
  ///
  /// Il renvoie à la consigne de langue du prompt au lieu d'imposer le
  /// français : avec le bambara (ou l'anglais…) comme langue de réponse,
  /// « réponds uniquement en français » contredisait cette consigne.
  static const languageReminder =
      '\n\nRAPPEL : ta réponse précédente contenait des caractères chinois, '
      'ce qui est interdit ici. Réponds uniquement dans la langue de réponse '
      'demandée plus haut (=== LANGUE DE RÉPONSE ===), sans un seul caractère '
      'chinois, même pour un mot isolé.';

  /// Nombre de nouvelles tentatives quand le modèle dérive en chinois.
  static const maxLanguageRetries = 2;

  /// Qwen2.5 a été entraîné surtout sur du chinois : en pleine phrase française
  /// il lui arrive de basculer (« …à côté de la讨论中… »), puis de finir sa
  /// réponse dans cette langue — mesuré dans l'application, sur une discussion
  /// de neuf messages. L'opérateur ne lit pas le chinois ; il verrait une
  /// réponse illisible là où l'outil a pourtant réussi.
  ///
  /// On ne retente que si l'opérateur n'a PAS écrit lui-même en chinois — dans
  /// ce cas la réponse chinoise est légitime.
  static bool driftedToChinese(
      AiApiResponse r, List<Map<String, dynamic>> contents) {
    if (r.finishReason == 'CANCELLED') return false;
    if (!containsCjk(r.text)) return false;
    for (final c in contents.reversed) {
      if (c['role'] != 'user') continue;
      final texts = ((c['parts'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => p['text'])
          .whereType<String>();
      if (texts.isEmpty) continue; // résultat d'outil : on remonte
      return !texts.any(containsCjk);
    }
    return true;
  }

  /// Notes déposées dans [AiApiResponse.notes] quand un garde-fou intervient.
  static const noteTextCallRecovered = 'appel_en_texte:recupere';
  static const noteLanguageRetry = 'langue:nouvelle_tentative';
  static const noteEmptyRetry = 'vide:nouvelle_tentative';

  /// Rappel ajouté au prompt système quand le modèle n'a rien répondu.
  static const emptyReminder =
      '\n\nRAPPEL : ta réponse précédente était vide. Réponds par une phrase '
      'claire en français, ou appelle l\'outil adapté. Ne reste pas muet.';

  /// Réponse vide : ni texte, ni appel d'outil. Mesuré au banc : 4 essais sur
  /// 231 (« Arrête tout, c'est urgent ! » une fois ; « passe en mode
  /// maintenance » trois fois sur trois). Devant une machine, le silence est
  /// pire qu'un refus : l'opérateur croirait l'ordre exécuté.
  static bool isEmptyReply(AiApiResponse r) =>
      r.finishReason != 'CANCELLED' &&
      r.text.trim().isEmpty &&
      r.functionCalls.isEmpty;

  /// Ajoute le nombre de tokens de la tentative écartée : l'usage affiché doit
  /// rester celui réellement consommé. Les notes des deux tentatives sont
  /// conservées, avec celle de la nouvelle tentative.
  static AiApiResponse _afterRetry(AiApiResponse first, AiApiResponse again,
          [String note = noteLanguageRetry]) =>
      AiApiResponse(
        parts: again.parts,
        finishReason: again.finishReason,
        totalTokens: again.totalTokens + first.totalTokens,
        notes: [...first.notes, ...again.notes, note],
      );

  @override
  Future<AiApiResponse> sendMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
  }) async {
    var r = await _send(contents, functionDeclarations, systemPrompt);
    for (var i = 0; i < maxLanguageRetries && driftedToChinese(r, contents); i++) {
      final again = await _send(
          contents, functionDeclarations, '${systemPrompt ?? ''}$languageReminder');
      r = _afterRetry(r, again);
    }
    // Une seule nouvelle tentative : un modèle qui reste muet deux fois ne dira
    // rien de plus à la troisième ; le contrôleur le signale à l'opérateur.
    if (isEmptyReply(r)) {
      final again = await _send(
          contents, functionDeclarations, '${systemPrompt ?? ''}$emptyReminder');
      r = _afterRetry(r, again, noteEmptyRetry);
    }
    return r;
  }

  Future<AiApiResponse> _send(
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
  ) async {
    final response = await _client
        .post(
          _endpoint,
          headers: _headers,
          body: _requestBody(
            contents: contents,
            functionDeclarations: functionDeclarations,
            systemPrompt: systemPrompt,
            stream: false,
          ),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception(
          'Serveur IA local HTTP ${response.statusCode}: ${response.body}');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return fromOpenAiJson(json, knownTools: _toolNames(functionDeclarations));
  }

  @override
  Future<AiApiResponse> streamMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String partialText)? onDelta,
    bool Function()? shouldCancel,
  }) async {
    var r = await _stream(contents, functionDeclarations, systemPrompt,
        onDelta, shouldCancel);
    // La nouvelle tentative n'est pas streamée : elle remplace d'un coup
    // l'aperçu en cours, qui montrait la réponse dérivée.
    for (var i = 0; i < maxLanguageRetries && driftedToChinese(r, contents); i++) {
      if (shouldCancel?.call() ?? false) break;
      final again = await _send(
          contents, functionDeclarations, '${systemPrompt ?? ''}$languageReminder');
      r = _afterRetry(r, again);
      onDelta?.call(r.text);
    }
    if (isEmptyReply(r) && !(shouldCancel?.call() ?? false)) {
      final again = await _send(
          contents, functionDeclarations, '${systemPrompt ?? ''}$emptyReminder');
      r = _afterRetry(r, again, noteEmptyRetry);
      onDelta?.call(r.text);
    }
    return r;
  }

  Future<AiApiResponse> _stream(
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String partialText)? onDelta,
    bool Function()? shouldCancel,
  ) async {
    final request = http.Request('POST', _endpoint)
      ..headers.addAll(_headers)
      ..body = _requestBody(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt,
        stream: true,
      );

    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception(
          'Serveur IA local HTTP ${response.statusCode}: $body');
    }

    final textBuf = StringBuffer();
    // Fragments d'appels d'outils, indexés comme le fait OpenAI : le nom
    // arrive dans un fragment, les arguments en plusieurs morceaux à
    // concaténer avant de pouvoir décoder quoi que ce soit.
    final callsByIndex = SplayTreeMap<int, Map<String, dynamic>>();
    var finishReason = '';
    var totalTokens = 0;
    var gotAny = false;
    var cancelled = false;

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (shouldCancel?.call() ?? false) {
        cancelled = true;
        break; // quitter la boucle annule l'abonnement → requête coupée
      }
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      Map<String, dynamic> chunk;
      try {
        chunk = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        continue; // fragment illisible → on ignore
      }
      gotAny = true;

      final usage = (chunk['usage'] as Map?)?.cast<String, dynamic>();
      final tok = (usage?['total_tokens'] as num?)?.toInt();
      if (tok != null) totalTokens = tok;

      final choices = chunk['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final choice = (choices.first as Map).cast<String, dynamic>();
      final reason = choice['finish_reason'];
      if (reason != null) finishReason = mapFinishReason(reason);

      final delta = (choice['delta'] as Map?)?.cast<String, dynamic>();
      if (delta == null) continue;

      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        textBuf.write(content);
        onDelta?.call(textBuf.toString());
      }

      for (final raw in (delta['tool_calls'] as List?) ?? const []) {
        final frag = (raw as Map).cast<String, dynamic>();
        final index = (frag['index'] as num?)?.toInt() ?? 0;
        final slot = callsByIndex.putIfAbsent(
            index, () => {'name': '', 'arguments': StringBuffer()});
        final fn = (frag['function'] as Map?)?.cast<String, dynamic>();
        if (fn != null) {
          final name = fn['name'];
          if (name is String && name.isNotEmpty) slot['name'] = name;
          final args = fn['arguments'];
          if (args is String) (slot['arguments'] as StringBuffer).write(args);
        }
      }
    }

    // Un flux vide signale un serveur qui ne sait pas streamer (ou pas avec
    // des outils) : on repasse en non-streamé. Après une annulation en
    // revanche, relancer referait exactement ce qu'on vient d'interrompre.
    if (!gotAny && !cancelled) {
      final r = await sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt,
      );
      if (r.text.isNotEmpty) onDelta?.call(r.text);
      return r;
    }

    final raw = <Map<String, dynamic>>[
      if (textBuf.isNotEmpty) {'text': textBuf.toString()},
      for (final slot in callsByIndex.values)
        {
          'functionCall': {
            'name': slot['name'],
            'args': decodeArgs((slot['arguments'] as StringBuffer).toString()),
          },
        },
    ];
    final parts = recoverTextToolCalls(raw, _toolNames(functionDeclarations));

    return AiApiResponse(
      parts: parts,
      finishReason: cancelled ? 'CANCELLED' : finishReason,
      totalTokens: totalTokens,
      notes: identical(parts, raw) ? const [] : const [noteTextCallRecovered],
    );
  }

  @override
  void dispose() => _client.close();
}
