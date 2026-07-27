import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_agent_service.dart';
import '../services/ai_agent_tools.dart';
import '../../core/net/cellular_http_client.dart';
import 'ai_agent_settings_provider.dart';
import 'ai_inbox_provider.dart';
import 'ai_usage_provider.dart';
import 'ai_model_provider.dart';

class AiChatMessage {
  final String role; // 'user' | 'assistant' | 'tool'
  final String text;
  final DateTime timestamp;

  /// Miniature de l'image jointe (session uniquement, non persistée pour ne
  /// pas gonfler le stockage). Sert à l'aperçu dans l'historique.
  final Uint8List? imageBytes;

  const AiChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.imageBytes,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> j) => AiChatMessage(
        role: j['role'] as String? ?? 'assistant',
        text: j['text'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (j['ts'] as num?)?.toInt() ?? 0),
      );
}

/// Appel d'outil en attente de confirmation utilisateur (catégorie gatée par
/// [AiAgentSettings] sur `requireConfirmation`). [id] est généré localement
/// pour l'UI (clé de widget) — Gemini n'a pas de notion d'identifiant
/// d'appel, les réponses de fonction sont corrélées par nom/ordre.
class AiPendingToolCall {
  final String id;
  final String toolName;
  final Map<String, dynamic> input;

  const AiPendingToolCall({
    required this.id,
    required this.toolName,
    required this.input,
  });
}

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isProcessing;
  final AiPendingToolCall? pendingConfirmation;
  final String? error;

  /// Une action est en attente de renvoi (échec réseau) → l'UI propose
  /// « Réessayer » et la reprise automatique tente dès que la 4G revient.
  final bool retryable;

  /// Reprise automatique armée : on attend le retour du réseau.
  final bool awaitingNetwork;

  /// Texte de la réponse en cours de streaming (aperçu live, non encore
  /// finalisé en message). `null` quand aucun streaming n'est en cours.
  final String? streamingText;

  const AiChatState({
    this.messages = const [],
    this.isProcessing = false,
    this.pendingConfirmation,
    this.error,
    this.retryable = false,
    this.awaitingNetwork = false,
    this.streamingText,
  });

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isProcessing,
    AiPendingToolCall? pendingConfirmation,
    bool clearPendingConfirmation = false,
    String? error,
    bool clearError = false,
    bool? retryable,
    bool? awaitingNetwork,
    String? streamingText,
    bool clearStreamingText = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      pendingConfirmation: clearPendingConfirmation
          ? null
          : (pendingConfirmation ?? this.pendingConfirmation),
      error: clearError ? null : (error ?? this.error),
      retryable: retryable ?? this.retryable,
      awaitingNetwork: awaitingNetwork ?? this.awaitingNetwork,
      streamingText:
          clearStreamingText ? null : (streamingText ?? this.streamingText),
    );
  }
}

/// Orchestre la conversation avec Gemini : historique brut (`contents`,
/// protocole Gemini, avec parts `functionCall`/`functionResponse`), et la
/// porte de permission qui décide, pour chaque appel de fonction, s'il
/// s'exécute immédiatement ou attend une confirmation explicite (selon
/// [AiAgentSettings]).
class AiAgentController extends StateNotifier<AiChatState> {
  final Ref _ref;
  final List<Map<String, dynamic>> _contents = [];
  List<Map<String, dynamic>> _pendingToolQueue = [];
  List<Map<String, dynamic>> _collectedResults = [];
  AiAgentService? _service;
  int _callCounter = 0;

  /// Action à rejouer après un échec réseau (renvoi manuel ou automatique).
  Future<void> Function()? _retry;
  Timer? _autoRetryTimer;

  // Persistance locale de la conversation : l'historique protocole Gemini
  // (_contents) ET l'affichage (messages) survivent au redémarrage de l'app,
  // pour que l'IA ne perde jamais le fil.
  static const _kContentsKey = 'ai_history_contents_v1';
  static const _kMessagesKey = 'ai_history_messages_v1';
  bool _restored = false;

  AiAgentController(this._ref) : super(const AiChatState()) {
    _restore();
  }

  /// Recharge la conversation persistée au démarrage.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawContents = prefs.getString(_kContentsKey);
      final rawMessages = prefs.getString(_kMessagesKey);
      if (rawContents != null) {
        final decoded = jsonDecode(rawContents) as List;
        _contents
          ..clear()
          ..addAll(decoded.map((e) => (e as Map).cast<String, dynamic>()));
      }
      if (rawMessages != null) {
        final decoded = jsonDecode(rawMessages) as List;
        final restored = decoded
            .map((e) => AiChatMessage.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        state = state.copyWith(messages: restored);
      }
    } catch (_) {
      // Historique corrompu → on repart proprement, sans planter.
    } finally {
      _restored = true;
    }
  }

  /// Sauvegarde la conversation courante (best-effort, non bloquant).
  Future<void> _persist() async {
    if (!_restored) return; // évite d'écraser avant la fin du chargement
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kContentsKey, jsonEncode(_sanitizeForStorage()));
      await prefs.setString(
          _kMessagesKey, jsonEncode(state.messages.map((m) => m.toJson()).toList()));
    } catch (_) {
      // Échec d'écriture non critique.
    }
  }

  /// Copie de `_contents` où les images inline sont remplacées par un marqueur :
  /// on évite de stocker des Mo de base64 dans les préférences.
  List<Map<String, dynamic>> _sanitizeForStorage() {
    return _contents.map((entry) {
      final parts = entry['parts'];
      if (parts is! List) return entry;
      final cleaned = parts.map((p) {
        if (p is Map && p.containsKey('inlineData')) {
          return {'text': '[image jointe]'};
        }
        return p;
      }).toList();
      return {...entry, 'parts': cleaned};
    }).toList();
  }

  static const _systemPrompt =
      'Tu es l\'assistant intégré de Forgeron, un contrôleur CNC 5 axes '
      '(trunnion X, Y, Z, A, C) piloté par un firmware FluidNC/GRBL. Tu peux '
      'consulter l\'état de la machine et agir dessus via les outils '
      'fournis. Sois concis et confirme toujours ce que tu as fait. Si une '
      'action semble risquée ou ambiguë (position inconnue, distance de jog '
      'importante, changement d\'origine pièce...), explique-le à '
      'l\'utilisateur et demande une précision plutôt que de deviner. '
      'Réponds en texte clair : tu peux utiliser du **gras** et des listes à '
      'puces simples, mais évite le LaTeX et les formules mathématiques (\$...\$) '
      '— écris les valeurs et unités en clair (ex. « 15 mm », « 14,25 mm »).';

  Future<AiAgentService?> _ensureService() async {
    final modelId = _ref.read(aiModelProvider).active.id;
    // Réutilise le service si le modèle actif n'a pas changé.
    if (_service != null && _service!.model == modelId) return _service;
    if (_service != null) {
      _service!.dispose();
      _service = null;
    }
    final key = await _ref.read(aiAgentSettingsProvider.notifier).readApiKey();
    if (key == null || key.isEmpty) {
      state = state.copyWith(
        error: 'Aucune clé API Gemini configurée (Paramètres > Agent IA).',
      );
      return null;
    }
    // Client cellulaire : force les appels Gemini sur la 4G/5G quand le
    // téléphone est joint à l'AP WiFi de l'ESP32 (sans Internet). Repli
    // automatique sur le client standard hors Android.
    _service =
        AiAgentService(apiKey: key, model: modelId, client: CellularHttpClient());
    return _service;
  }

  void _addMessage(AiChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
    unawaited(_persist());
  }

  /// Envoie un message. [imageBytes] (optionnel) joint une image analysée par
  /// Gemini (vision) : photo de pièce, plan, écran, défaut à inspecter…
  Future<void> sendUserMessage(
    String text, {
    Uint8List? imageBytes,
    String? imageMime,
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && imageBytes == null) || state.isProcessing) return;

    final service = await _ensureService();
    if (service == null) return;

    // Construit les parts au format Gemini : texte + éventuelle image inline.
    final parts = <Map<String, dynamic>>[];
    if (trimmed.isNotEmpty) parts.add({'text': trimmed});
    if (imageBytes != null) {
      parts.add({
        'inlineData': {
          'mimeType': imageMime ?? 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
      });
    }
    _contents.add({'role': 'user', 'parts': parts});

    if (imageBytes != null) {
      _ref.read(aiUsageProvider.notifier).recordImage();
    }

    _addMessage(AiChatMessage(
      role: 'user',
      text: trimmed,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    ));

    // Pré-vérif réseau : le WiFi de l'ESP32 n'a pas d'Internet, l'IA doit
    // passer par la 4G/5G. Si les données mobiles sont coupées, on prévient
    // tout de suite (≤ 2 s) au lieu d'attendre un timeout HTTP, et on arme la
    // reprise automatique dès que le réseau revient.
    if (!await CellularNetwork.isAvailable()) {
      _armRetry(
        () => _runTurn(service),
        'Données mobiles désactivées : l\'IA a besoin de la 4G/5G, car le WiFi '
        'de l\'ESP32 n\'a pas d\'accès Internet. Active les données mobiles (en '
        'gardant le WiFi) — l\'envoi reprendra tout seul.',
      );
      return;
    }

    await _runTurn(service);
  }

  /// Arme une reprise : mémorise l'action à rejouer, affiche l'erreur et lance
  /// la surveillance réseau qui la relancera automatiquement dès que possible.
  void _armRetry(Future<void> Function() action, String message) {
    _retry = action;
    state = state.copyWith(
      isProcessing: false,
      error: message,
      retryable: true,
      awaitingNetwork: true,
    );
    // Alerte « problème » sur le bouton IA si l'écran n'est pas ouvert.
    _ref.read(aiInboxProvider.notifier).pushAlert(message, problem: true);
    _startAutoRetryWatch();
  }

  void _startAutoRetryWatch() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer.periodic(const Duration(seconds: 4), (t) async {
      if (_retry == null) {
        t.cancel();
        return;
      }
      if (await CellularNetwork.isAvailable()) {
        t.cancel();
        await retryNow();
      }
    });
  }

  /// Rejoue immédiatement la dernière action échouée (bouton « Réessayer »).
  Future<void> retryNow() async {
    final action = _retry;
    if (action == null) return;
    _retry = null;
    _autoRetryTimer?.cancel();
    state = state.copyWith(
      clearError: true,
      retryable: false,
      awaitingNetwork: false,
    );
    await action();
  }

  void _clearRetry() {
    _retry = null;
    _autoRetryTimer?.cancel();
    if (state.retryable || state.awaitingNetwork) {
      state = state.copyWith(retryable: false, awaitingNetwork: false);
    }
  }

  Future<void> _runTurn(AiAgentService service) async {
    state = state.copyWith(
        isProcessing: true,
        clearError: true,
        retryable: false,
        awaitingNetwork: false,
        clearStreamingText: true);
    try {
      final response = await service.streamMessages(
        contents: _contents,
        functionDeclarations:
            AiToolCatalog.tools.map((t) => t.toGeminiFunctionDeclaration()).toList(),
        systemPrompt: _systemPrompt,
        // Aperçu live : le texte s'affiche au fur et à mesure.
        onDelta: (partial) => state = state.copyWith(streamingText: partial),
      );
      // Fin du streaming : on efface l'aperçu et on fige le message.
      state = state.copyWith(clearStreamingText: true);
      _contents.add({'role': 'model', 'parts': response.parts});
      unawaited(_persist());
      // Comptabilise l'appel abouti (quotas du jour, par modèle).
      _ref
          .read(aiUsageProvider.notifier)
          .recordRequest(service.model, tokens: response.totalTokens);

      if (response.text.isNotEmpty) {
        _addMessage(AiChatMessage(
          role: 'assistant',
          text: response.text,
          timestamp: DateTime.now(),
        ));
        // Badge le bouton IA si l'écran n'est pas ouvert (info à présenter).
        _ref.read(aiInboxProvider.notifier).pushAlert(response.text);
      }

      if (response.functionCalls.isNotEmpty) {
        _pendingToolQueue = List.of(response.functionCalls);
        await _processNextToolCall(service);
      } else {
        _clearRetry();
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      state = state.copyWith(clearStreamingText: true);
      final raw = e.toString();

      // Quota gratuit épuisé (429) → bascule automatique sur le modèle suivant.
      if (_isQuota(raw)) {
        _ref.read(aiUsageProvider.notifier).markQuotaHit();
        final next =
            _ref.read(aiModelProvider.notifier).handleQuotaHit(service.model);
        if (next != null) {
          // Rebâtit le service avec le nouveau modèle et rejoue le tour.
          _service?.dispose();
          _service = null;
          final s = await _ensureService();
          if (s != null) return _runTurn(s);
        }
        final auto = _ref.read(aiModelProvider).auto;
        _armRetry(
          () => _runTurn(service),
          auto
              ? 'Quota gratuit atteint sur tous les modèles disponibles. '
                  'Réessaie plus tard (remise à zéro quotidienne) ou active la '
                  'facturation.'
              : 'Quota atteint sur ${service.model}. Active la bascule '
                  'automatique (Paramètres > Modèle IA) ou choisis un autre '
                  'modèle.',
        );
        return;
      }

      // Échec réseau/API → on garde le tour en mémoire pour le rejouer (le
      // message utilisateur est déjà dans _contents), et on tente une reprise
      // automatique dès que la connexion revient.
      _armRetry(() => _runTurn(service), _friendlyError(e));
    }
  }

  bool _isQuota(String raw) =>
      raw.contains('HTTP 429') ||
      raw.contains('RESOURCE_EXHAUSTED') ||
      raw.contains('Too Many Requests');

  /// Traduit une erreur technique en message court et actionnable.
  String _friendlyError(Object e) {
    final raw = e.toString();
    if (e is CellularNetworkException) return raw;
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('TimeoutException') ||
        raw.contains('Connection')) {
      return 'Connexion perdue avec le service IA. L\'envoi reprendra dès que '
          'le réseau (4G/5G) sera de nouveau disponible.';
    }
    return raw;
  }

  Future<void> _processNextToolCall(AiAgentService service) async {
    if (_pendingToolQueue.isEmpty) {
      _contents.add({'role': 'user', 'parts': _collectedResults});
      _collectedResults = [];
      unawaited(_persist());
      await _runTurn(service);
      return;
    }

    final block = _pendingToolQueue.removeAt(0);
    final functionCall = (block['functionCall'] as Map).cast<String, dynamic>();
    final toolName = functionCall['name'] as String;
    final input = ((functionCall['args'] as Map?) ?? const {}).cast<String, dynamic>();
    final callId = '${toolName}_${_callCounter++}';
    final tool = AiToolCatalog.byName(toolName);

    if (tool == null) {
      _collectedResults.add(
        _functionResponse(toolName, error: 'Outil inconnu "$toolName"'),
      );
      await _processNextToolCall(service);
      return;
    }

    final category = tool.category;
    final needsConfirmation = category != null &&
        _ref.read(aiAgentSettingsProvider).levelFor(category) ==
            AiAutonomyLevel.requireConfirmation;

    if (needsConfirmation) {
      state = state.copyWith(
        isProcessing: false,
        pendingConfirmation:
            AiPendingToolCall(id: callId, toolName: toolName, input: input),
      );
      return;
    }

    _collectedResults.add(await _executeTool(tool, toolName, input));
    await _processNextToolCall(service);
  }

  /// Approuve l'appel d'outil en attente et poursuit la conversation.
  Future<void> confirmPendingAction() async {
    final pending = state.pendingConfirmation;
    final service = _service;
    if (pending == null || service == null) return;

    state = state.copyWith(isProcessing: true, clearPendingConfirmation: true);
    final tool = AiToolCatalog.byName(pending.toolName);
    if (tool == null) {
      _collectedResults.add(
        _functionResponse(pending.toolName, error: 'Outil inconnu "${pending.toolName}"'),
      );
    } else {
      _collectedResults.add(await _executeTool(tool, pending.toolName, pending.input));
    }
    await _processNextToolCall(service);
  }

  /// Refuse l'appel d'outil en attente : Gemini reçoit une functionResponse
  /// d'échec et la conversation continue sans que l'action soit exécutée.
  Future<void> rejectPendingAction() async {
    final pending = state.pendingConfirmation;
    final service = _service;
    if (pending == null || service == null) return;

    _collectedResults.add(
      _functionResponse(pending.toolName, error: 'Action refusée par l\'utilisateur.'),
    );
    _addMessage(AiChatMessage(
      role: 'tool',
      text: '${pending.toolName} → refusé par l\'utilisateur',
      timestamp: DateTime.now(),
    ));
    state = state.copyWith(isProcessing: true, clearPendingConfirmation: true);
    await _processNextToolCall(service);
  }

  Future<Map<String, dynamic>> _executeTool(
    AiTool tool,
    String toolName,
    Map<String, dynamic> input,
  ) async {
    try {
      final result = await tool.execute(input, _ref);
      _addMessage(AiChatMessage(
        role: 'tool',
        text: '${tool.name} → $result',
        timestamp: DateTime.now(),
      ));
      return _functionResponse(toolName, result: result);
    } catch (e) {
      final message = 'Erreur: $e';
      _addMessage(AiChatMessage(
        role: 'tool',
        text: '${tool.name} → $message',
        timestamp: DateTime.now(),
      ));
      return _functionResponse(toolName, error: message);
    }
  }

  Map<String, dynamic> _functionResponse(String name, {String? result, String? error}) {
    return {
      'functionResponse': {
        'name': name,
        'response': error != null ? {'error': error} : {'result': result},
      },
    };
  }

  /// Efface la conversation (nouvel historique côté API, UI et stockage local).
  void clearConversation() {
    _contents.clear();
    _pendingToolQueue = [];
    _collectedResults = [];
    _retry = null;
    _autoRetryTimer?.cancel();
    state = const AiChatState();
    unawaited(_clearStorage());
  }

  Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kContentsKey);
      await prefs.remove(_kMessagesKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    _service?.dispose();
    super.dispose();
  }
}

final aiAgentControllerProvider =
    StateNotifierProvider<AiAgentController, AiChatState>((ref) {
  return AiAgentController(ref);
});

/// Lecture vocale (TTS) des réponses de l'agent : activée ou non.
final aiTtsEnabledProvider = StateProvider<bool>((ref) => false);
