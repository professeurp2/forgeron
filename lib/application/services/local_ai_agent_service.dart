import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ai_agent_service.dart';

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

  LocalAiAgentService({
    required this.baseUrl,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(seconds: 180),
  }) : _client = client ?? http.Client();

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

  /// Historique Gemini → `messages` OpenAI.
  static List<Map<String, dynamic>> toOpenAiMessages(
    List<Map<String, dynamic>> contents,
    String? systemPrompt,
  ) {
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

      for (final raw in parts) {
        final p = raw.cast<String, dynamic>();

        if (p.containsKey('text')) {
          final t = p['text'] as String? ?? '';
          if (t.isNotEmpty) texts.add(t);
        } else if (p.containsKey('inlineData')) {
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

  /// Réponse complète OpenAI → [AiApiResponse] (format Gemini).
  static AiApiResponse fromOpenAiJson(Map<String, dynamic> json) {
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

    return AiApiResponse(
      parts: parts,
      finishReason: mapFinishReason(choice['finish_reason']),
      totalTokens: tokens,
    );
  }

  // ── Appels ────────────────────────────────────────────────────────────────

  String _requestBody({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    required bool stream,
  }) =>
      jsonEncode({
        'model': model,
        'messages': toOpenAiMessages(contents, systemPrompt),
        if (functionDeclarations.isNotEmpty)
          'tools': toOpenAiTools(functionDeclarations),
        'stream': stream,
        if (stream) 'stream_options': {'include_usage': true},
      });

  @override
  Future<AiApiResponse> sendMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
  }) async {
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
    return fromOpenAiJson(json);
  }

  @override
  Future<AiApiResponse> streamMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String partialText)? onDelta,
    bool Function()? shouldCancel,
  }) async {
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

    final parts = <Map<String, dynamic>>[
      if (textBuf.isNotEmpty) {'text': textBuf.toString()},
      for (final slot in callsByIndex.values)
        {
          'functionCall': {
            'name': slot['name'],
            'args': decodeArgs((slot['arguments'] as StringBuffer).toString()),
          },
        },
    ];

    return AiApiResponse(
      parts: parts,
      finishReason: cancelled ? 'CANCELLED' : finishReason,
      totalTokens: totalTokens,
    );
  }

  @override
  void dispose() => _client.close();
}
