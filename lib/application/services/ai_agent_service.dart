import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/net/cellular_http_client.dart';

/// Client HTTP pour l'API Gemini (Google Generative Language API), avec
/// function calling.
///
/// Suit le même schéma que [FluidNcHttpClient] : client injectable, timeout
/// explicite, exceptions sur statut HTTP non-200, `dispose()`.
class AiAgentService {
  static const _apiVersion = 'v1beta';

  final String apiKey;

  /// Alias "roulant" du modèle (ex. `gemini-flash-lite-latest`) : évite de se
  /// refaire piéger quand Google retire un modèle daté aux nouveaux comptes.
  final String model;

  final http.Client _client;

  AiAgentService({
    required this.apiKey,
    this.model = 'gemini-flash-lite-latest',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri get _endpoint => Uri.parse(
      'https://generativelanguage.googleapis.com/$_apiVersion/models/$model:generateContent');

  Uri get _streamEndpoint => Uri.parse(
      'https://generativelanguage.googleapis.com/$_apiVersion/models/$model:streamGenerateContent?alt=sse');

  Map<String, String> get _headers => {
        'x-goog-api-key': apiKey,
        'content-type': 'application/json',
      };

  String _requestBody({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
  }) =>
      jsonEncode({
        'contents': contents,
        if (functionDeclarations.isNotEmpty)
          'tools': [
            {'functionDeclarations': functionDeclarations},
          ],
        if (systemPrompt != null)
          'systemInstruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
      });

  /// Envoie l'historique de conversation (`contents`, format Gemini) + le
  /// catalogue d'outils à Gemini et retourne sa réponse (texte et/ou
  /// demandes d'appel de fonction).
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
          ),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Gemini API HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return AiApiResponse.fromJson(json);
  }

  /// Version **streamée** : diffuse le texte au fur et à mesure via [onDelta]
  /// (texte agrégé courant) et retourne la réponse complète agrégée pour la
  /// logique d'outils. Replie automatiquement sur [sendMessages] si le flux
  /// n'est pas disponible.
  ///
  /// [shouldCancel] est consulté à chaque fragment reçu : dès qu'il retourne
  /// `true`, on quitte la boucle — ce qui annule l'abonnement au flux — et on
  /// retourne ce qui a déjà été reçu (bouton « Stop » de l'écran de chat).
  Future<AiApiResponse> streamMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String partialText)? onDelta,
    bool Function()? shouldCancel,
  }) async {
    final body = _requestBody(
      contents: contents,
      functionDeclarations: functionDeclarations,
      systemPrompt: systemPrompt,
    );

    Stream<String> source;
    if (CellularSse.isSupported) {
      source = CellularSse.stream(
          url: _streamEndpoint.toString(), headers: _headers, body: body);
    } else {
      source = _httpSseStream(body);
    }

    final otherParts = <Map<String, dynamic>>[];
    final textBuf = StringBuffer();
    var finishReason = '';
    var totalTokens = 0;
    var gotAny = false;
    var cancelled = false;

    try {
      await for (final payload in source) {
        if (shouldCancel?.call() ?? false) {
          cancelled = true;
          break; // quitter la boucle annule l'abonnement → requête coupée
        }
        Map<String, dynamic> chunk;
        try {
          chunk = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue; // fragment SSE incomplet/illisible → on ignore
        }
        gotAny = true;
        final usage = (chunk['usageMetadata'] as Map?)?.cast<String, dynamic>();
        final tok = (usage?['totalTokenCount'] as num?)?.toInt();
        if (tok != null) totalTokens = tok;
        final candidates = chunk['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) continue;
        final cand = (candidates.first as Map).cast<String, dynamic>();
        finishReason = cand['finishReason'] as String? ?? finishReason;
        final content = (cand['content'] as Map?)?.cast<String, dynamic>();
        final parts =
            (content?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        for (final p in parts) {
          if (p.containsKey('text')) {
            textBuf.write(p['text'] as String? ?? '');
            onDelta?.call(textBuf.toString());
          } else {
            otherParts.add(p); // functionCall, etc.
          }
        }
      }
    } on MissingPluginException {
      // Pont natif absent (ancien build) → repli non-streamé.
      return _fallback(contents, functionDeclarations, systemPrompt, onDelta);
    }

    // Repli seulement sur un vrai flux vide : après une annulation, relancer un
    // appel non-streamé referait exactement ce qu'on vient d'interrompre.
    if (!gotAny && !cancelled) {
      return _fallback(contents, functionDeclarations, systemPrompt, onDelta);
    }

    final parts = <Map<String, dynamic>>[
      if (textBuf.isNotEmpty) {'text': textBuf.toString()},
      ...otherParts,
    ];
    return AiApiResponse(
      parts: parts,
      finishReason: cancelled ? 'CANCELLED' : finishReason,
      totalTokens: totalTokens,
    );
  }

  Future<AiApiResponse> _fallback(
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String)? onDelta,
  ) async {
    final r = await sendMessages(
      contents: contents,
      functionDeclarations: functionDeclarations,
      systemPrompt: systemPrompt,
    );
    if (r.text.isNotEmpty) onDelta?.call(r.text);
    return r;
  }

  /// Flux SSE via HTTP standard (plateformes non-Android : le client délègue
  /// à un client HTTP classique qui gère le streaming).
  Stream<String> _httpSseStream(String body) async* {
    final req = http.Request('POST', _streamEndpoint)
      ..headers.addAll(_headers)
      ..body = body;
    final resp = await _client.send(req).timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      final b = await resp.stream.bytesToString();
      throw Exception('Gemini API HTTP ${resp.statusCode}: $b');
    }
    await for (final line
        in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final l = line.trim();
      if (l.startsWith('data:')) {
        final payload = l.substring(5).trim();
        if (payload.isNotEmpty && payload != '[DONE]') yield payload;
      }
    }
  }

  void dispose() => _client.close();
}

/// Réponse brute de l'API Gemini : parts du premier candidat (texte et/ou
/// `functionCall`) et raison d'arrêt (`STOP`, `MAX_TOKENS`, ...).
class AiApiResponse {
  final List<Map<String, dynamic>> parts;
  final String finishReason;

  /// Tokens totaux de l'échange (`usageMetadata.totalTokenCount`), 0 si absent.
  final int totalTokens;

  const AiApiResponse({
    required this.parts,
    required this.finishReason,
    this.totalTokens = 0,
  });

  factory AiApiResponse.fromJson(Map<String, dynamic> json) {
    final usage = (json['usageMetadata'] as Map?)?.cast<String, dynamic>();
    final tokens = (usage?['totalTokenCount'] as num?)?.toInt() ?? 0;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return AiApiResponse(parts: const [], finishReason: 'EMPTY', totalTokens: tokens);
    }
    final candidate = (candidates.first as Map).cast<String, dynamic>();
    final content = (candidate['content'] as Map?)?.cast<String, dynamic>();
    final parts =
        (content?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return AiApiResponse(
      parts: parts,
      finishReason: candidate['finishReason'] as String? ?? '',
      totalTokens: tokens,
    );
  }

  List<Map<String, dynamic>> get functionCalls =>
      parts.where((p) => p.containsKey('functionCall')).toList();

  String get text => parts
      .where((p) => p.containsKey('text'))
      .map((p) => p['text'] as String? ?? '')
      .join('\n')
      .trim();
}
