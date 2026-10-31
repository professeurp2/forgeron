import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/machine_state.dart' show MachineStatus;
import '../services/ai_agent_service.dart';
import '../services/command_understanding.dart';
import '../services/docs_prefetch.dart';
import '../services/live_state_block.dart';
import '../services/ai_turn_journal.dart';
import '../services/local_ai_agent_service.dart';
import '../services/ai_agent_tools.dart';
import '../services/guarded_backend.dart';
import '../services/tool_router.dart';
import '../../core/net/cellular_http_client.dart';
import '../../core/utils/command_lexicon.dart';
import '../../core/utils/emergency_intent.dart';
import '../../core/utils/fingerprint.dart';
import '../../core/utils/gemini_context.dart';
import 'ai_agent_settings_provider.dart';
import 'di_providers.dart';
import 'ai_inbox_provider.dart';
import 'ai_usage_provider.dart';
import 'ai_model_provider.dart';
import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import 'activity_log_provider.dart';
import 'ai_artifacts_provider.dart';
import 'docs_provider.dart';
import 'lexicon_provider.dart';
import 'machine_params_provider.dart';

// Porte d'entrée « lexique fermé » du contrôleur : voir ai_lexicon_front.dart.
part 'ai_lexicon_front.dart';

class AiChatMessage {
  final String role; // 'user' | 'assistant' | 'tool'
  final String text;
  final DateTime timestamp;

  /// Réponse coupée en cours de route par l'opérateur (bouton « Stop ») :
  /// l'UI le signale pour qu'on ne prenne pas un texte tronqué pour complet.
  final bool interrupted;

  /// Miniature de l'image jointe (session uniquement, non persistée pour ne
  /// pas gonfler le stockage). Sert à l'aperçu dans l'historique.
  final Uint8List? imageBytes;

  // ── Étape d'outil (role == 'tool') ─────────────────────────────────────
  //
  // Avant, une étape n'existait qu'une fois TERMINÉE, et seulement sous forme
  // de texte « nom → résultat » que l'écran devait re-découper. Une étape est
  // désormais publiée DÈS SON DÉMARRAGE, avec ses arguments, puis remplacée
  // par sa version aboutie : c'est ce qui permet à l'écran de montrer ce que
  // l'agent est en train de faire au moment où il le fait, plutôt qu'un
  // indicateur générique le temps que ça tombe.

  /// Nom technique de l'outil (`run_step_pipeline`, `home`…).
  final String? toolName;

  /// Arguments passés à l'outil, tels que le modèle les a produits.
  final Map<String, dynamic>? toolArgs;

  /// Résultat brut. `null` tant que l'outil tourne — c'est CE champ qui
  /// distingue une étape en cours d'une étape terminée, jamais le texte.
  final String? toolResult;

  /// Temps d'exécution, `null` tant que l'outil tourne.
  final Duration? toolDuration;

  const AiChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.interrupted = false,
    this.imageBytes,
    this.toolName,
    this.toolArgs,
    this.toolResult,
    this.toolDuration,
  });

  /// Étape d'outil qui vient de démarrer : pas encore de résultat.
  factory AiChatMessage.toolStarted(String name, Map<String, dynamic> args) =>
      AiChatMessage(
        role: 'tool',
        text: '$name → …',
        timestamp: DateTime.now(),
        toolName: name,
        toolArgs: args,
      );

  /// La même étape, aboutie. Reprend l'horodatage de départ pour que l'ordre
  /// du fil ne bouge pas sous les yeux de l'opérateur.
  AiChatMessage toolFinished(String result, {Uint8List? image}) =>
      AiChatMessage(
        role: 'tool',
        text: '${toolName ?? role} → $result',
        timestamp: timestamp,
        imageBytes: image,
        toolName: toolName,
        toolArgs: toolArgs,
        toolResult: result,
        toolDuration: DateTime.now().difference(timestamp),
      );

  bool get isTool => role == 'tool';

  /// Étape encore en cours d'exécution.
  bool get isRunningTool => isTool && toolResult == null;

  /// Étape terminée en échec. Les outils signalent leurs échecs par un
  /// résultat préfixé `Erreur` (voir `_executeTool`), pas par une exception
  /// qui remonterait jusqu'ici.
  bool get toolFailed =>
      toolResult != null && toolResult!.startsWith('Erreur');

  // Les arguments sont bornés à la persistance : `write_workspace_file` peut
  // en porter un programme entier, qu'il serait absurde de stocker deux fois
  // (il est déjà dans le résultat, et sur le disque).
  static const _kMaxPersistedArgs = 2000;

  Map<String, dynamic> toJson() {
    final args = toolArgs;
    String? encodedArgs;
    if (args != null && args.isNotEmpty) {
      final raw = jsonEncode(args);
      if (raw.length <= _kMaxPersistedArgs) encodedArgs = raw;
    }
    return {
      'role': role,
      'text': text,
      'ts': timestamp.millisecondsSinceEpoch,
      if (interrupted) 'cut': true,
      if (toolName != null) 'tool': toolName,
      'args': ?encodedArgs,
      if (toolDuration != null) 'ms': toolDuration!.inMilliseconds,
    };
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> j) {
    final role = j['role'] as String? ?? 'assistant';
    final text = j['text'] as String? ?? '';

    String? toolName = j['tool'] as String?;
    String? toolResult;
    if (role == 'tool') {
      // Discussions enregistrées avant que l'étape ne soit structurée : tout
      // ce qu'on a est le texte « nom → résultat », qu'on redécoupe.
      final sep = text.indexOf(' → ');
      if (toolName == null && sep > 0) toolName = text.substring(0, sep);
      toolResult = sep > 0 ? text.substring(sep + 3) : text;
      // Une étape relue est forcément terminée : si l'app s'est fermée
      // pendant son exécution, elle resterait sinon à tourner pour toujours.
      if (toolResult == '…') toolResult = 'Erreur: interrompu (application fermée)';
    }

    Map<String, dynamic>? args;
    final rawArgs = j['args'];
    if (rawArgs is String) {
      try {
        args = (jsonDecode(rawArgs) as Map).cast<String, dynamic>();
      } catch (_) {
        // Arguments illisibles : l'étape reste affichable sans eux.
      }
    }

    final ms = (j['ms'] as num?)?.toInt();
    return AiChatMessage(
      role: role,
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (j['ts'] as num?)?.toInt() ?? 0),
      interrupted: j['cut'] == true,
      toolName: toolName,
      toolArgs: args,
      toolResult: toolResult,
      toolDuration: ms == null ? null : Duration(milliseconds: ms),
    );
  }
}

/// Fiche d'une discussion sauvegardée (le contenu, lui, est stocké à part
/// pour ne charger que la conversation ouverte).
class AiConversationMeta {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const AiConversationMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  AiConversationMeta copyWith({
    String? title,
    DateTime? updatedAt,
    int? messageCount,
  }) =>
      AiConversationMeta(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messageCount: messageCount ?? this.messageCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created': createdAt.millisecondsSinceEpoch,
        'updated': updatedAt.millisecondsSinceEpoch,
        'count': messageCount,
      };

  factory AiConversationMeta.fromJson(Map<String, dynamic> j) =>
      AiConversationMeta(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? AiAgentController.kDefaultTitle,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['created'] as num?)?.toInt() ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['updated'] as num?)?.toInt() ?? 0),
        messageCount: (j['count'] as num?)?.toInt() ?? 0,
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

  /// Renseigné quand l'action vient du **lexique fermé** et non du modèle : la
  /// carte de confirmation montre alors ce qui a été compris, dans quelle
  /// langue et pourquoi on demande.
  final AiLexiconCall? lexicon;

  const AiPendingToolCall({
    required this.id,
    required this.toolName,
    required this.input,
    this.lexicon,
  });
}

/// Ce que le lexique a compris, gardé avec l'action en attente.
class AiLexiconCall {
  const AiLexiconCall({
    required this.match,
    required this.originalText,
    required this.reasons,
    required this.label,
    required this.reasonText,
  });

  final LexiconMatch match;

  /// Le message tel que l'opérateur l'a écrit (pour l'historique protocole).
  final String originalText;

  final Set<ConfirmReason> reasons;

  /// Action en une phrase ordinaire (« Allumer la broche »).
  final String label;

  /// Pourquoi on demande, en une ligne sans jargon.
  final String reasonText;

  /// Ce qui a été reconnu, mot à mot (« broche→objet:broche »).
  List<String> get evidence => match.evidence;

  /// Langues des mots reconnus, déjà libellées (« bambara », « français »).
  List<String> get languageLabels =>
      match.languages.map(lexiconLanguageLabel).toList();

  /// Au moins un mot vient d'une langue pas encore relue par un locuteur.
  bool get isDraft => !match.trusted;

  /// Appariement souple : une suggestion.
  bool get isSuggestion => match.relaxed;
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

  /// Discussions sauvegardées, la plus récemment utilisée en tête.
  final List<AiConversationMeta> conversations;

  /// Identifiant de la discussion ouverte (`null` avant la restauration).
  final String? activeId;

  /// Nom de l'outil en cours d'exécution, `null` sinon.
  ///
  /// `_executeTool` n'ajoute le message `role: 'tool'` qu'une fois l'appel
  /// terminé : sans ce champ, l'écran n'a aucun moyen de savoir qu'un outil
  /// tourne encore — juste `isProcessing`, identique pendant la réflexion du
  /// modèle. Sert à afficher un nœud « en cours » dans la procédure plutôt
  /// qu'un simple indicateur générique.
  final String? runningTool;

  /// Début du tour en cours — `null` au repos. L'écran s'en sert pour une
  /// ligne d'état vivante (« 1 min 12 s · 12.4k jetons · exécution des
  /// outils… ») : sans ça, une génération longue est indiscernable d'une
  /// application figée.
  final DateTime? turnStartedAt;

  /// Jetons consommés depuis le début de l'échange en cours (cumul des
  /// allers-retours, appels d'outils compris).
  final int turnTokens;

  /// Spécialistes qui traitent le tour en cours (groupes du [ToolRouter], ou
  /// `images` pour le modèle d'images). Vide : l'agent généraliste, avec tout
  /// le catalogue.
  final List<String> specialists;

  const AiChatState({
    this.messages = const [],
    this.isProcessing = false,
    this.pendingConfirmation,
    this.error,
    this.retryable = false,
    this.awaitingNetwork = false,
    this.streamingText,
    this.conversations = const [],
    this.activeId,
    this.runningTool,
    this.turnStartedAt,
    this.turnTokens = 0,
    this.specialists = const [],
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
    List<AiConversationMeta>? conversations,
    String? activeId,
    String? runningTool,
    bool clearRunningTool = false,
    DateTime? turnStartedAt,
    bool clearTurnStartedAt = false,
    int? turnTokens,
    List<String>? specialists,
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
      conversations: conversations ?? this.conversations,
      activeId: activeId ?? this.activeId,
      runningTool:
          clearRunningTool ? null : (runningTool ?? this.runningTool),
      turnStartedAt:
          clearTurnStartedAt ? null : (turnStartedAt ?? this.turnStartedAt),
      turnTokens: turnTokens ?? this.turnTokens,
      specialists: specialists ?? this.specialists,
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
  AiBackend? _service;
  int _callCounter = 0;

  /// Interruption demandée par l'opérateur : lue par la boucle de streaming
  /// et par la chaîne d'appels d'outils, qui se soldent proprement.
  bool _cancelled = false;

  /// Incrémenté à chaque changement de discussion (nouvelle, bascule,
  /// suppression, effacement). Un tour asynchrone démarré avant le changement
  /// compare son époque à celle-ci et s'abandonne si elle a bougé : sans ça,
  /// une réponse encore en vol viendrait se déverser dans `_contents`, qui
  /// appartient désormais à une AUTRE discussion.
  int _epoch = 0;

  /// Action à rejouer après un échec réseau (renvoi manuel ou automatique).
  Future<void> Function()? _retry;
  Timer? _autoRetryTimer;

  /// Ce qui dit que la reprise automatique peut partir : le réseau mobile pour
  /// Gemini (défaut), la réponse du serveur pour un modèle local.
  Future<bool> Function()? _retryProbe;

  // ── Surveillance et routage d'outils ──────────────────────────────────────

  /// Routage d'outils (n'exposer au modèle local que les outils utiles au
  /// message, avec noyau de sécurité permanent et repli sur le catalogue
  /// complet en cas de doute). Ne concerne pas Gemini (`service.usesCellular`).
  static const _useToolRouting = true;

  String? _latestStreamingText;

  AiTurnJournal? _journal;
  Set<String> _recentToolGroups = const {};
  int _declaredToolCount = 0;

  // ── Porte d'entrée « lexique fermé » (voir ai_lexicon_front.dart) ─────────

  /// Le lexique a reconnu une QUESTION ou une NÉGATION dans le message en
  /// cours : le modèle n'a, pour ce tour, que les outils de lecture. Remis à
  /// faux à chaque nouveau message de l'opérateur.
  bool _readOnlyTurn = false;

  /// Ce que le lexique a décidé pour le tour en cours (`lexique:refus:…`,
  /// `lexique:lecture_seule:question`) — recopié dans la ligne du journal.
  String? _frontTag;

  /// Empreintes du prompt fixe et des outils, calculées une fois : elles
  /// disent, dans chaque ligne du journal, QUELLE version de l'IA a répondu.
  static final String _releaseTag = () {
    final prompt = fingerprint(baseSystemPrompt);
    final tools = fingerprint(jsonEncode(AiToolCatalog.tools
        .map((t) => t.toGeminiFunctionDeclaration())
        .toList()));
    return '${prompt.substring(0, 8)}/${tools.substring(0, 8)}';
  }();

  Future<AiTurnJournal?> _journalOrNull() async {
    if (_journal != null) return _journal;
    try {
      final dir = await getApplicationSupportDirectory();
      return _journal = AiTurnJournal(dir.path);
    } catch (_) {
      return null; // pas de journal ≠ pas d'agent
    }
  }

  /// Écrit une ligne dans le journal, sans jamais attendre ni échouer.
  void _logTurn(
    AiBackend service,
    AiTurnOutcome outcome,
    Stopwatch clock, {
    AiApiResponse? response,
    String? errorKind,
  }) {
    unawaited(() async {
      final journal = await _journalOrNull();
      if (journal == null) return;
      await journal.record(AiTurnRecord(
        time: DateTime.now(),
        backend: service.usesCellular ? 'gemini' : 'local',
        model: service.model,
        outcome: outcome,
        latencyMs: clock.elapsedMilliseconds,
        tokens: response?.totalTokens ?? 0,
        tools: [
          for (final c in response?.functionCalls ?? const <Map<String, dynamic>>[])
            '${(c['functionCall'] as Map)['name']}',
        ],
        notes: response?.notes ?? const [],
        declaredTools: _declaredToolCount,
        release: _releaseTag,
        errorKind: errorKind,
        front: _frontTag,
        lexicon: _lexiconStamp,
      ));
    }());
  }

  /// Texte du dernier message de l'opérateur (celui qui pilote le routage).
  String _lastUserText() {
    for (final c in _contents.reversed) {
      if (c['role'] != 'user') continue;
      for (final p in (c['parts'] as List? ?? const []).whereType<Map>()) {
        final t = p['text'];
        if (t is String && t.isNotEmpty) return t;
      }
    }
    return '';
  }

  /// Outils déclarés au modèle pour ce tour : tous, ou — modèle local avec le
  /// routage activé — ceux que [ToolRouter] retient.
  /// Bloc de fiches de ce tour (voir docs_prefetch.dart), `null` si ce n'est pas
  /// une question de connaissance ou si le corpus n'est pas chargé.
  String? _docsBlockOrNull() {
    // Une question posée sur une image porte sur l'image, pas sur les fiches.
    // Sans ce garde, « qu'est-ce que tu vois ? » (un « ? » suffit) recevait la
    // consigne « réponds UNIQUEMENT avec les fiches, sinon dis "Je ne trouve
    // pas cette information" » : le modèle d'images comme Gemini refusaient
    // de décrire la photo, et la réponse était tronquée à ce refus (vu dans
    // l'app, en local comme en ligne).
    if (_imageInPlay()) return null;
    try {
      final corpus = _ref.read(docCorpusProvider).valueOrNull;
      return corpus == null ? null : docsBlock(_lastUserText(), corpus.index);
    } catch (_) {
      return null;
    }
  }

  /// Groupes d'outils retenus pour le tour en cours, `null` quand le modèle
  /// reçoit tout le catalogue (routage coupé, Gemini, lecture seule, ou
  /// message non reconnu). Décide aussi des sections de spécialiste du prompt
  /// (voir [specialistSystemPrompt]).
  Set<String>? _turnGroups;

  List<Map<String, dynamic>> _declarationsFor(AiBackend service) {
    _turnGroups = null;
    var all = AiToolCatalog.tools
        .map((t) => t.toGeminiFunctionDeclaration())
        .toList();
    // Les fiches sont déjà dans le prompt : déclarer aussi search_docs poussait
    // le modèle à les rechercher une seconde fois (et à écrire l'appel en
    // texte au lieu de répondre) — mesuré au banc.
    if (_docsBlockOrNull() != null) {
      all = all.where((d) => d['name'] != 'search_docs').toList();
    }
    // Question ou négation reconnue par le lexique : lecture seule, quel que
    // soit le fournisseur (c'est une règle de sécurité, pas d'économie de jetons).
    if (_readOnlyTurn) {
      final readOnly =
          all.where((d) => isReadOnlyToolName('${d['name']}')).toList();
      _declaredToolCount = readOnly.length;
      return readOnly;
    }
    if (!_useToolRouting || service.usesCellular) {
      _declaredToolCount = all.length;
      return all;
    }
    final routing = const ToolRouter().route(
      text: _lastUserText(),
      allTools: all.map((d) => d['name'] as String),
      recentGroups: _recentToolGroups,
    );
    _recentToolGroups = routing.groups;
    if (routing.routed) _turnGroups = routing.groups;
    final routed =
        all.where((d) => routing.tools.contains(d['name'])).toList();
    _declaredToolCount = routed.length;
    return routed;
  }

  // Persistance locale des conversations : l'historique protocole Gemini
  // (_contents) ET l'affichage (messages) survivent au redémarrage de l'app,
  // pour que l'IA ne perde jamais le fil. L'index est chargé en entier, mais
  // seule la discussion ouverte a son contenu en mémoire.
  static const _kIndexKey = 'ai_conversations_v2';
  static const _kActiveKey = 'ai_conversation_active_v2';
  static String _payloadKey(String id) => 'ai_conversation_$id';

  // Clés de l'ancien format « conversation unique », migrées au 1er lancement.
  static const _kLegacyContentsKey = 'ai_history_contents_v1';
  static const _kLegacyMessagesKey = 'ai_history_messages_v1';

  static const kDefaultTitle = 'Nouvelle discussion';

  List<AiConversationMeta> _conversations = [];
  String? _activeId;
  bool _restored = false;

  AiAgentController(this._ref) : super(const AiChatState()) {
    _restore();
  }

  // ---------------------------------------------------------------------
  // Persistance / discussions
  // ---------------------------------------------------------------------

  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// Recharge l'index des discussions et ouvre la dernière utilisée.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawIndex = prefs.getString(_kIndexKey);
      if (rawIndex == null) {
        await _migrateLegacy(prefs);
      } else {
        _conversations = (jsonDecode(rawIndex) as List)
            .map((e) =>
                AiConversationMeta.fromJson((e as Map).cast<String, dynamic>()))
            .where((c) => c.id.isNotEmpty)
            .toList();
      }
      _sortConversations();

      final saved = prefs.getString(_kActiveKey);
      _activeId = _conversations.any((c) => c.id == saved)
          ? saved
          : (_conversations.isNotEmpty ? _conversations.first.id : null);

      final messages =
          _activeId == null ? <AiChatMessage>[] : await _loadPayload(prefs, _activeId!);
      state = state.copyWith(
        messages: messages,
        conversations: _conversations,
        activeId: _activeId,
      );
    } catch (_) {
      // Historique corrompu → on repart proprement, sans planter.
    } finally {
      _restored = true;
    }
  }

  /// Reprend l'unique conversation de l'ancien format et la convertit en
  /// première discussion du nouveau, puis efface les anciennes clés.
  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final rawContents = prefs.getString(_kLegacyContentsKey);
    final rawMessages = prefs.getString(_kLegacyMessagesKey);
    if (rawContents == null && rawMessages == null) return;

    final messages = <AiChatMessage>[];
    if (rawMessages != null) {
      try {
        messages.addAll((jsonDecode(rawMessages) as List).map((e) =>
            AiChatMessage.fromJson((e as Map).cast<String, dynamic>())));
      } catch (_) {}
    }
    final id = _newId();
    await prefs.setString(
      _payloadKey(id),
      jsonEncode({
        'contents': rawContents != null ? jsonDecode(rawContents) : const [],
        'messages': messages.map((m) => m.toJson()).toList(),
      }),
    );
    final now = DateTime.now();
    _conversations = [
      AiConversationMeta(
        id: id,
        title: _titleFrom(messages),
        createdAt: messages.isNotEmpty ? messages.first.timestamp : now,
        updatedAt: messages.isNotEmpty ? messages.last.timestamp : now,
        messageCount: messages.length,
      ),
    ];
    await prefs.setString(
        _kIndexKey, jsonEncode(_conversations.map((c) => c.toJson()).toList()));
    await prefs.setString(_kActiveKey, id);
    await prefs.remove(_kLegacyContentsKey);
    await prefs.remove(_kLegacyMessagesKey);
  }

  /// Charge le contenu d'une discussion dans `_contents` et retourne ses
  /// messages d'affichage.
  Future<List<AiChatMessage>> _loadPayload(
      SharedPreferences prefs, String id) async {
    _contents.clear();
    final raw = prefs.getString(_payloadKey(id));
    if (raw == null) return const [];
    try {
      final payload = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final contents = payload['contents'] as List? ?? const [];
      _contents.addAll(contents.map((e) => (e as Map).cast<String, dynamic>()));
      final messages = payload['messages'] as List? ?? const [];
      return messages
          .map((e) => AiChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _contents.clear();
      return const [];
    }
  }

  /// Sauvegarde la discussion courante (best-effort, non bloquant).
  Future<void> _persist() async {
    if (!_restored) return; // évite d'écraser avant la fin du chargement
    // Rien à sauvegarder et aucune discussion ouverte : ne pas en fabriquer
    // une au passage (sinon supprimer la dernière discussion en laisse une
    // vide derrière elle).
    if (_activeId == null && state.messages.isEmpty && _contents.isEmpty) {
      return;
    }
    final id = _activeId ??= _newId();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _payloadKey(id),
        jsonEncode({
          'contents': _sanitizeForStorage(),
          'messages': state.messages.map((m) => m.toJson()).toList(),
        }),
      );
      _touchMeta(id);
      await prefs.setString(_kIndexKey,
          jsonEncode(_conversations.map((c) => c.toJson()).toList()));
      await prefs.setString(_kActiveKey, id);
    } catch (_) {
      // Échec d'écriture non critique.
    }
  }

  /// Met à jour (ou crée) la fiche de la discussion courante : titre déduit du
  /// premier message, date et compteur. Un titre renommé à la main est
  /// conservé.
  void _touchMeta(String id) {
    final now = DateTime.now();
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index < 0) {
      _conversations.insert(
        0,
        AiConversationMeta(
          id: id,
          title: _titleFrom(state.messages),
          createdAt: now,
          updatedAt: now,
          messageCount: state.messages.length,
        ),
      );
    } else {
      final current = _conversations[index];
      _conversations[index] = current.copyWith(
        title: current.title == kDefaultTitle
            ? _titleFrom(state.messages)
            : current.title,
        updatedAt: now,
        messageCount: state.messages.length,
      );
    }
    _sortConversations();
    state = state.copyWith(conversations: List.of(_conversations), activeId: id);
  }

  void _sortConversations() =>
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Titre auto : début du premier message de l'opérateur.
  static String _titleFrom(List<AiChatMessage> messages) {
    for (final m in messages) {
      if (m.role != 'user') continue;
      final t = m.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (t.isEmpty) continue;
      return t.length <= 42 ? t : '${t.substring(0, 42)}…';
    }
    return kDefaultTitle;
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

  /// Ouvre une discussion vierge (la courante est sauvegardée telle quelle).
  Future<void> newConversation() async {
    stopGeneration();
    await _persist();
    // Les aperçus 3D appartiennent à la discussion qui les a produits : les
    // garder ferait proposer d'ouvrir la pièce d'une AUTRE conversation.
    _ref.read(aiArtifactsProvider.notifier).clear();

    final id = _newId();
    final now = DateTime.now();
    _epoch++;
    _activeId = id;
    // Purge APRÈS la bascule d'identifiant : appuyer deux fois sur « + » ne
    // doit pas laisser derrière soi une discussion vide jamais utilisée.
    _pruneEmpty();
    _contents.clear();
    _pendingToolQueue = [];
    _collectedResults = [];
    _readOnlyTurn = false;
    _retry = null;
    _autoRetryTimer?.cancel();
    _conversations.insert(
      0,
      AiConversationMeta(
          id: id, title: kDefaultTitle, createdAt: now, updatedAt: now),
    );
    state = AiChatState(
        conversations: List.of(_conversations), activeId: id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveKey, id);
      await prefs.setString(_kIndexKey,
          jsonEncode(_conversations.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  /// Bascule sur une autre discussion sauvegardée.
  Future<void> switchConversation(String id) async {
    if (id == _activeId) return;
    stopGeneration();
    await _persist();
    _ref.read(aiArtifactsProvider.notifier).clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final messages = await _loadPayload(prefs, id);
      _epoch++;
      _activeId = id;
      // Après la bascule : la discussion qu'on quitte, si elle est restée
      // vide, n'a pas à encombrer le sélecteur.
      _pruneEmpty();
      _pendingToolQueue = [];
      _collectedResults = [];
      _readOnlyTurn = false;
      _retry = null;
      _autoRetryTimer?.cancel();
      state = AiChatState(
        messages: messages,
        conversations: List.of(_conversations),
        activeId: id,
      );
      await prefs.setString(_kActiveKey, id);
    } catch (_) {}
  }

  /// Supprime une discussion (et bascule ailleurs si c'était la courante).
  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_payloadKey(id));
      await prefs.setString(_kIndexKey,
          jsonEncode(_conversations.map((c) => c.toJson()).toList()));
      if (id != _activeId) {
        state = state.copyWith(conversations: List.of(_conversations));
        return;
      }
      // C'était la discussion ouverte → on ouvre la plus récente, ou une neuve.
      stopGeneration();
      if (_conversations.isEmpty) {
        _epoch++;
        _activeId = null;
        _contents.clear();
        state = const AiChatState();
        await prefs.remove(_kActiveKey);
        await newConversation();
        return;
      }
      final next = _conversations.first.id;
      final messages = await _loadPayload(prefs, next);
      _epoch++;
      _activeId = next;
      _pendingToolQueue = [];
      _collectedResults = [];
      state = AiChatState(
        messages: messages,
        conversations: List.of(_conversations),
        activeId: next,
      );
      await prefs.setString(_kActiveKey, next);
    } catch (_) {}
  }

  /// Renomme une discussion (titre figé : plus d'auto-titrage ensuite).
  Future<void> renameConversation(String id, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index < 0) return;
    _conversations[index] = _conversations[index].copyWith(title: clean);
    state = state.copyWith(conversations: List.of(_conversations));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIndexKey,
          jsonEncode(_conversations.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  /// Retire les discussions vides autres que la courante, pour que le sélecteur
  /// ne se remplisse pas de fils jamais utilisés.
  void _pruneEmpty() {
    _conversations.removeWhere((c) => c.messageCount == 0 && c.id != _activeId);
  }

  // ---------------------------------------------------------------------
  // Prompt système
  // ---------------------------------------------------------------------

  // Le prompt système est découpé en un TRONC COMMUN (identité, lecture de
  // l'état, sécurité, style), toujours envoyé, et des SECTIONS DE SPÉCIALISTE
  // qui ne servent qu'à certains groupes d'outils (voir [_specialistSections]).
  // [_systemPrompt] les réunit dans l'ordre d'origine : le prompt complet est
  // identique, mot pour mot, à celui d'avant le découpage.

  /// Tronc commun, début : identité, écrans, lecture de l'état.
  static const _promptIdentity =
      'Tu es l\'assistant intégré de Forgeron, un contrôleur CNC 5 axes piloté '
      'par un firmware FluidNC/GRBL sur ESP32. '
      'Forgeron est une application Flutter (mobile/desktop) reliée à la machine '
      'par WebSocket : l\'ESP32 crée un point d\'accès WiFi sans Internet, donc '
      'tes propres appels passent par la 4G. La machine est un trunnion : table '
      'rotative C dans un berceau basculant A, plus les axes linéaires X, Y, Z. '
      'Écrans de l\'app : Tableau de bord (DRO, simulateur 3D, jog, exécution de '
      'programme), Palpage & Origines (WCS G54..G59, ForceGuard), Magasin '
      'd\'outils, Espace de travail (fichiers G-code), Terminal MDI, Diagnostics '
      '(température, réseau, firmware, GPIO, AMDEC), et toi (Agent IA). '
      'Concepts clés : ForceGuard bride l\'avance selon la force résultante en '
      'usinage 5 axes ; modes 3AX/5AX ; RTCP (G43.4) ; risque de singularité ; '
      'watchdog de streaming. '
      'Pour toute question factuelle sur la machine (état, config, cinématique, '
      'diagnostics, offsets, actions récentes), utilise les outils de lecture '
      '(get_machine_state, get_config, get_axis_kinematics, get_diagnostics, '
      'get_wcs_offsets, get_activity_log) plutôt que de deviner. Ce qu\'un '
      'résultat plus haut dans la discussion t\'a appris (position, statut, '
      'alarme) est PÉRIMÉ dès que la machine bouge : à chaque question sur '
      'l\'état présent, rappelle l\'outil de lecture, même si tu viens de le '
      'faire — ne recopie jamais une ancienne valeur comme si elle était actuelle. ';

  /// Spécialiste fichiers / programme : lecture, adaptation et contrôle
  /// du G-code avant exécution.
  static const _promptGcodeFiles =
      'Tu peux lister, lire, analyser et écrire les fichiers G-code de l\'espace '
      'de travail (list_workspace_files, read_workspace_file, analyze_gcode, '
      'write_workspace_file). Au chargement, Forgeron adapte automatiquement le '
      'G-code CAM pour FluidNC (cycles fixes développés, G43/H retirés, M6→pause). '
      'COWORK correction : quand un fichier SolidWorks/CAM pose souci, utilise '
      'analyze_gcode pour lister ce qui est traduit et ce qui BLOQUE, explique '
      'chaque point et guide l\'opérateur. Les blocages (RTCP G43.4, compensation '
      'de rayon MACHINE G41/G42) se corrigent dans le POST SolidWorks '
      '(compensation « ordinateur », sortie en coordonnées machine), PAS dans le '
      'G-code — ne les réécris pas toi-même. '
      'Avant d\'exécuter, VÉRIFIE qu\'aucun mouvement ne dépasse les courses '
      'indiquées dans la cinématique ci-dessous (coordonnées machine, après '
      'homing) : si un dépassement est détecté, SIGNALE la ligne et l\'axe '
      'fautif à l\'opérateur et propose une correction. '
      'N\'écris JAMAIS une version « corrigée » en '
      'silence : garde l\'original intact (écris sous un nouveau nom) et fais '
      'confirmer — un rognage aveugle des coordonnées peut abîmer la pièce ou '
      'provoquer une collision. ';

  /// Tronc commun, fin : sécurité (jamais de G-code écrit par le modèle,
  /// confirmations) et style des réponses.
  static const _promptRules =
      'Tu reçois en contexte le journal des actions récentes (manuelles de '
      'l\'opérateur ET les tiennes) : surveille-le pour la sécurité et '
      'l\'optimisation — signale spontanément tout enchaînement risqué (ex. '
      'lancer un programme sans homing, changer d\'origine en plein usinage). '
      'Tu n\'écris JAMAIS toi-même un programme G-code : une coordonnée fausse '
      'peut casser la fraise ou la machine, et l\'opérateur ne peut pas la '
      'relire. Pour obtenir un programme, utilise run_step_pipeline sur un '
      'fichier STEP, ou travaille sur un fichier DÉJÀ présent dans l\'espace de '
      'travail. Si aucun générateur ne convient, dis-le simplement et propose '
      'ces deux options, sans inventer de chemin de fichier. Tu peux lancer le '
      'programme déjà chargé (run_program) ou un programme que l\'OPÉRATEUR te '
      'donne mot pour mot (run_gcode_program) — jamais un programme de ta '
      'façon. Avant de lancer un programme ou un mouvement, vérifie/annonce les '
      'points de sécurité clés (homing fait, Z dégagé, bon WCS) et laisse '
      'l\'utilisateur confirmer les actions gatées. '
      'Sois concis et confirme toujours ce que tu as fait. Si une action semble '
      'risquée ou ambiguë, explique-le et demande une précision. '
      'Réponds en texte clair : tu peux utiliser du **gras** et des listes à '
      'puces simples, mais évite le LaTeX et les formules mathématiques (\$...\$) '
      '— écris les valeurs et unités en clair (ex. « 15 mm »). '
      'Quand tu cites des lignes de G-code (extraites d\'un fichier existant ou '
      'données par l\'opérateur), mets-les TOUJOURS dans un bloc de code '
      'markdown ouvert par ```gcode et fermé par ``` : l\'app y ajoute alors '
      'les boutons « copier » et « enregistrer dans l\'espace de travail ». '
      'MONTRE, ne décris pas : l\'opérateur n\'est ni développeur ni '
      'programmeur CAM, une liste de coordonnées ne lui apprend rien. Même '
      'chose pour le vocabulaire : "pièce de révolution", "prismatique", '
      '"FreeCAD", "pipeline", "OCP", "axe détecté" sont des termes internes, '
      'pas des mots à employer avec l\'opérateur — dis ce que tu fais et ce '
      'que ça donne ("j\'ai généré le G-code, 68 lignes, 3 passes"), jamais '
      'par quel moyen technique. Le nom de l\'outil déclenché ne doit jamais '
      'apparaître non plus tel quel (run_step_pipeline, etc.). ';

  /// Spécialiste FAO : aperçu 3D (STEP/STL), génération G-code et chargement machine.
  static const _promptCam =
      'PIPELINE FAO & USINAGE AUTOMATIQUE (STEP & STL) : '
      'Dès qu\'un fichier 3D (STEP ou STL) est mentionné ou transmis par l\'opérateur '
      'pour préparer, charger ou générer l\'usinage, DÉCLENCHE DIRECTEMENT les outils '
      'appropriés sans attendre et sans poser de question préalable : '
      '1. Ouvre l\'aperçu 3D avec preview_step_file. '
      '2. Exécute la génération de G-code avec run_step_pipeline (ce qui charge automatiquement '
      'le programme fini dans le contrôleur de la machine). '
      '3. Affiche le tracé 3D avec open_toolpath_window. '
      'N\'écris JAMAIS de code, de nom de commande ni de JSON technique en texte '
      '(pas de "preview_step_file(...)" ou "run_step_pipeline(...)"). '
      'Ne fais PAS de tutoriel décrivant les étapes théoriques à l\'avance (« Étape 1... »). '
      'Exécute les outils en coulisse et présente directement le résultat fini à l\'opérateur en français simple : '
      'la pièce est prête, le tracé d\'outil est visible, et le programme est déjà chargé dans la machine. '
      'LANCEMENT DE L\'USINAGE EN LANGAGE NATUREL : '
      'Dès que l\'opérateur demande en langage naturel d\'exécuter, d\'usiner ou de démarrer '
      '(ex: "lance l\'usinage", "usinons-le", "exécute ce code", "démarre la machine", "lance la pièce") : '
      'déclenche directement l\'outil run_program pour lancer l\'usinage réel sur FluidNC avec ForceGuard, '
      'puis confirme chaleureusement en langage humain que l\'usinage est en cours. ';

  /// Spécialiste scan 3D en machine.
  static const _promptScan =
      'SCAN 3D & NUMÉRISATION EN MACHINE : quand l\'opérateur veut numériser une pièce '
      'ou un maître bridé sur la machine, utilise start_machine_scan pour piloter la rotation '
      'calibrée des axes A et C et capturer les vues multi-angles. Vérifie d\'abord que '
      'le poste de calcul est joignable (get_reco3d_status, ou discover_reco3d_server si besoin). '
      'Suis l\'avancement avec get_scan_job_status, et une fois terminé, télécharge le résultat '
      'avec download_scan_result (format "step" ou "mesh") pour afficher immédiatement la pièce '
      'dans le visualiseur 3D. Rappelle honnêtement que la géométrie est approximative tant que '
      'l\'échelle n\'est pas certifiée par mire.';

  static const _systemPrompt =
      '$_promptIdentity$_promptGcodeFiles$_promptRules$_promptCam$_promptScan';

  /// Spécificités matérielles réelles de CETTE machine (faits qualitatifs qui
  /// ne se lisent pas dans la cinématique). Les VALEURS chiffrées, elles, sont
  /// injectées depuis la config FluidNC réelle — voir [_kinematicsBlock] : les
  /// recopier ici les ferait dériver à chaque recalibrage.
  static const _machineSpecs =
      '=== SPÉCIFICITÉS DE CETTE MACHINE (à respecter absolument) ===\n'
      'BROCHE : moteur à courant continu en TOUT-OU-RIEN via un relais 5 V '
      '(FluidNC type Relay sur gpio.21). Pour la démarrer il FAUT une vitesse '
      '> 0 : « M3 S1000 ». « M3 » seul (S0) ne l\'allume PAS. « M5 » l\'arrête. '
      'PAS de vitesse variable : la valeur S ne change pas le régime, et '
      'set_spindle_override n\'a AUCUN effet réel — ne le propose jamais comme '
      'réglage de vitesse. Alim broche actuellement sous-dimensionnée (chargeur '
      'PC 19,5 V / 3,3 A) → étincelles et instabilité ; correctif matériel en '
      'attente (alim forte + MOSFET) — pertinent si l\'opérateur signale des '
      'ratés de broche. '
      'AXES : X a une vis à pas de 3 mm, différente de Y/Z (pas de 2 mm) — leurs '
      'pas/mm ne sont donc PAS interchangeables. A et C sont rotatifs SANS fin '
      'de course (donc pas de homing possible sur A/C). '
      'FINS DE COURSE : X/Y/Z sur gpio.4/13/14, câblés en NC (fail-safe). '
      'soft_limits ET hard_limits actifs sur X/Y/Z. '
      'HOMING : le capteur Z est EN HAUT → Z se home vers le HAUT et se dégage '
      '(retrait outil), convention standard. Zéro machine Z en haut, course '
      'utile vers le bas (Z négatif). Le zéro pièce (haut du brut) est donc à '
      'un Z machine négatif, et l\'usinage descend en Z négatif — comme un CAO '
      'standard. Homer à chaque démarrage pour activer les soft_limits. '
      'RÉCUPÉRATION d\'une alarme fin de course : « \$X » pour déverrouiller, '
      'puis jog DOUX pour éloigner l\'axe du switch (voir écran Récupération).';

  /// Règle des questions techniques, placée EN FIN de prompt (le modèle local
  /// pèse davantage les dernières consignes) : mesuré (banc DOC, 5 répétitions),
  /// la même règle noyée au milieu du prompt n'était suivie qu'une fois sur deux,
  /// et le reste inventait une procédure (y compris avec des outils d'action).
  static const _docsRule =
      '=== QUESTIONS TECHNIQUES ===\n'
      'Section « FICHES TROUVÉES » ou « AUCUNE FICHE » plus bas = résultat de la '
      'recherche : réponds avec elle, cite (identifiant), sans search_docs. Sinon, '
      'question technique : search_docs d\'abord, jamais de mémoire. Rien trouvé : '
      'UNE phrase « Je ne trouve pas cette information dans mes fiches. ». Valeurs '
      'machine : get_axis_kinematics ou get_config. Une question n\'est pas un ordre.';

  /// La partie FIXE du prompt système (identité, règles, spécificités machine),
  /// sans les blocs injectés à chaque tour. Publique pour qu'un test mesure la
  /// charge utile RÉELLE envoyée à un modèle local — son contexte est fini, et
  /// un prompt qui le déborde est tronqué en silence par le début (voir
  /// `LocalAiAgentService.historyBudgetChars`).
  @visibleForTesting
  static const baseSystemPrompt =
      '$_systemPrompt\n\n$_machineSpecs\n\n$_docsRule';

  /// Sections de spécialiste, et les groupes du [ToolRouter] qui en ont
  /// besoin. Une section dont aucun groupe n'est retenu pour le tour n'est pas
  /// envoyée : c'est le pendant, côté prompt, du routage des outils.
  static const _specialistSections = <String, Set<String>>{
    _promptGcodeFiles: {'fichiers', 'programme'},
    _promptCam: {'cao', 'simulation'},
    _promptScan: {'scan'},
  };

  /// Prompt fixe d'un tour routé vers les groupes [groups] : le tronc commun
  /// (identité, sécurité, style, spécificités machine, règle des questions
  /// techniques) est TOUJOURS présent ; seules les sections de spécialiste
  /// inutiles sont retirées.
  @visibleForTesting
  static String specialistSystemPrompt(Set<String> groups) {
    String section(String text) =>
        _specialistSections[text]!.any(groups.contains) ? text : '';
    return '$_promptIdentity${section(_promptGcodeFiles)}$_promptRules'
        '${section(_promptCam)}${section(_promptScan)}'
        '\n\n$_machineSpecs\n\n$_docsRule';
  }

  /// Cinématique réelle lue dans la config FluidNC (live ou cache offline).
  /// Injectée à chaque tour pour que l'agent cite les VRAIES courses et pas/mm
  /// — des constantes figées dans le code dérivent au premier recalibrage.
  /// Glossaire sourcé de la langue active, ajouté au prompt pour les langues
  /// peu dotées seulement.
  ///
  /// Le modèle écrit mal ces langues parce qu'il improvise le vocabulaire.
  /// Lui donner les mots déjà vérifiés (An ka taa pour le bambara) coûte
  /// ~200 jetons et lui évite d'en forger. Rien n'est ajouté pour le
  /// français, l'anglais, ni une langue sans sources : un glossaire sans
  /// provenance ne vaut pas mieux que l'improvisation.
  String _glossaireBlockOrEmpty() {
    final langue = _ref.read(appLanguageProvider);
    if (!langue.lowResource) return '';
    final glossaire =
        _ref.read(lexiconLoadProvider).valueOrNull?.glossaries[langue.id];
    return glossaire == null ? '' : '\n\n$glossaire';
  }

  String _kinematicsBlock() {
    final axes = _ref.read(axisKinematicsProvider).asData?.value ?? const [];
    if (axes.isEmpty) {
      return 'Cinématique : configuration machine pas encore chargée. '
          'N\'annonce AUCUNE course ni pas/mm de mémoire — appelle '
          'get_axis_kinematics d\'abord.';
    }
    final buffer = StringBuffer(
        'Cinématique réelle (lue dans la config FluidNC de la machine) :\n');
    for (final a in axes) {
      final rotary = a.axis == 'A' || a.axis == 'C';
      final unit = rotary ? '°' : 'mm';
      final fields = <String>[
        if (a.maxTravel != null) 'course ${_num(a.maxTravel!)} $unit',
        if (a.stepsPerMm != null) '${_num(a.stepsPerMm!)} pas/$unit',
        if (a.maxRate != null) 'F max ${_num(a.maxRate!)} $unit/min',
        if (a.accel != null) 'accél. ${_num(a.accel!)} $unit/s²',
      ];
      if (fields.isEmpty) continue;
      buffer.writeln('- ${a.axis} : ${fields.join(', ')}');
    }
    return buffer.toString().trimRight();
  }

  static String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  /// Prompt système = base + specs machine + cinématique réelle + journal des
  /// actions récentes (injecté à chaque tour pour que l'IA soit au courant des
  /// actions de l'opérateur, sans appel API supplémentaire).
  String _buildSystemPrompt() {
    final activity = formatRecentActivity(_ref.read(activityLogProvider));
    // État lu À L'INSTANT de l'appel : le prompt est reconstruit à chaque
    // appel au modèle, donc l'état y est frais par construction (voir
    // live_state_block.dart — sans lui, le modèle recopiait d'anciennes
    // positions au lieu de rappeler l'outil, 10 fois sur 15 au banc).
    String liveState;
    try {
      final s = _ref.read(machineRepositoryProvider).currentState;
      liveState = liveStateBlock(
        state: machineStateMap(s),
        offline: s.status == MachineStatus.offline,
        now: DateTime.now(),
      );
    } catch (_) {
      liveState = liveStateBlock(state: null, offline: true, now: DateTime.now());
    }
    // Question de connaissance : les fiches pertinentes sont cherchées par
    // l'application et mises ici (voir docs_prefetch.dart) — on ne compte pas
    // sur le modèle pour penser à appeler search_docs.
    final block = _docsBlockOrNull();
    final docs = block == null ? '' : '\n\n$block';
    final groups = _turnGroups;
    final fixed =
        groups == null ? baseSystemPrompt : specialistSystemPrompt(groups);
    return '$fixed\n\n'
        '${_kinematicsBlock()}\n\n'
        '${_ref.read(appLanguageProvider).promptDirective}'
        '${_glossaireBlockOrEmpty()}\n\n'
        '$liveState$docs\n\n'
        '=== JOURNAL D\'ACTIVITÉ MACHINE (récent, opérateur + toi) ===\n'
        '$activity';
  }

  // ---------------------------------------------------------------------
  // Conversation
  // ---------------------------------------------------------------------

  /// Pose un faux fournisseur de modèle (tests du contrôleur). Il est réutilisé
  /// tel quel par [_ensureService] tant que son `model` est celui du réglage
  /// actif et qu'aucune adresse locale n'est renseignée.
  @visibleForTesting
  void debugUseBackend(AiBackend backend) => _service = backend;

  // ── Modèle pour les images ────────────────────────────────────────────────

  AiBackend? _visionService;

  /// Pose un faux modèle d'images (tests du contrôleur).
  @visibleForTesting
  void debugUseVisionBackend(AiBackend backend) => _visionService = backend;

  /// Modèle local qui lit les images, s'il est réglé ET différent du principal ;
  /// `null` sinon (le principal s'en charge, ou aucune image n'est lisible).
  Future<AiBackend?> _ensureVisionService() async {
    final settings = _ref.read(aiAgentSettingsProvider);
    // En ligne, Gemini lit les images lui-même : pas de modèle d'images local.
    final url = settings.usesLocal ? settings.localBaseUrl : '';
    final name = settings.localVisionModel;
    if (_visionService != null && (url.isEmpty || name.isEmpty)) {
      // Un faux posé par un test reste ; un vrai service dont le réglage a été
      // vidé est abandonné.
      if (_visionService is! LocalAiAgentService) return _visionService;
      _visionService!.dispose();
      _visionService = null;
      return null;
    }
    if (url.isEmpty || name.isEmpty || name == settings.localModel) return null;
    if (_visionService != null && _visionService!.model == name) return _visionService;
    _visionService?.dispose();
    final info = await LocalAiAgentService.probe(url, name);
    return _visionService = LocalAiAgentService(baseUrl: url, model: name, info: info);
  }

  /// Joint à l'image ce qu'en a dit le modèle d'images, pour les tours
  /// suivants : le modèle principal ne voit pas l'image, mais il lira cette
  /// fiche (voir `LocalAiAgentService.imageFicheNote`). Appelé juste après
  /// l'ajout de la réponse : le message qui porte l'image est l'avant-dernier.
  void _attachImageFiche(String description, String model) {
    if (_contents.length < 2) return;
    final i = _contents.length - 2;
    final parts = _contents[i]['parts'];
    if (parts is! List || !parts.any((p) => p is Map && p.containsKey('inlineData'))) {
      return;
    }
    _contents[i] = {
      ..._contents[i],
      'parts': [...parts, LocalAiAgentService.imageFichePart(description, model)],
    };
  }

  /// Groupes d'outils qui AGISSENT : une demande qui en relève, jointe à une
  /// photo, doit être exécutée par le modèle principal après la description.
  /// Ni « etat » ni « camera » : décrire suffit. Ni « fichiers » ni « cao » :
  /// leurs mots (« analyse », « pièce », « 3d ») sont ceux d'une simple
  /// question sur une photo, et relanceraient le pilote pour rien.
  static const _actionGroups = {
    'mouvement', 'broche', 'programme', 'scan', 'simulation',
  };

  /// Préfixe du message de relais (voir [_handOffImageRequestToPilot]).
  static const kImageRelayPrefix = '[Relais du modèle d\'images]';

  /// Si le message qui portait l'image demande une action, ajoute au fil un
  /// relais qui la confie au modèle principal, et rend `true`.
  ///
  /// Le relais est un message « user » que l'opérateur ne voit pas : le fil
  /// se termine sinon par la description du modèle d'images, et un modèle à
  /// qui l'on rend la parole sur sa propre réponse n'a rien à exécuter.
  bool _handOffImageRequestToPilot() {
    if (_contents.length < 2) return false;
    final imageTurn = _contents[_contents.length - 2];
    final parts = imageTurn['parts'];
    if (imageTurn['role'] != 'user' || parts is! List) return false;
    // Seulement une photo de l'opérateur, pas l'image rendue par un outil
    // (caméra) : celle-là répond déjà à un appel du modèle principal.
    if (parts.any((p) => p is Map && p.containsKey('functionResponse'))) {
      return false;
    }
    final request = _lastUserText();
    if (request.isEmpty || request.startsWith(kImageRelayPrefix)) return false;
    final groups = const ToolRouter().route(
      text: request,
      allTools: const [],
    ).groups;
    if (groups.intersection(_actionGroups).isEmpty) return false;
    _contents.add({
      'role': 'user',
      'parts': [
        {
          'text': '$kImageRelayPrefix La description de l\'image est faite '
              '(voir la fiche). Exécute maintenant la demande de l\'opérateur, '
              'avec tes outils : « $request »',
        }
      ],
    });
    return true;
  }

  /// Le message de l'opérateur en cours porte-t-il sur une image : photo
  /// jointe, image rendue par un outil (caméra), ou relais d'une photo vers le
  /// modèle principal ?
  bool _imageInPlay() {
    if (_lastTurnHasImage()) return true;
    for (final c in _contents.reversed) {
      if (c['role'] != 'user') continue;
      final parts = (c['parts'] as List? ?? const []).whereType<Map>().toList();
      if (parts.any((p) => p.containsKey('functionResponse'))) continue;
      if (parts.any((p) => p.containsKey('inlineData'))) return true;
      return parts.any((p) =>
          p['text'] is String && (p['text'] as String).startsWith(kImageRelayPrefix));
    }
    return false;
  }

  /// Le dernier message du fil porte-t-il une image (photo jointe, ou image
  /// rendue par un outil comme la caméra) ?
  bool _lastTurnHasImage() {
    if (_contents.isEmpty) return false;
    final parts = _contents.last['parts'];
    return parts is List && parts.any((p) => p is Map && p.containsKey('inlineData'));
  }

  Future<AiBackend?> _ensureService() async {
    // Une adresse de serveur local renseignée l'emporte : l'agent tourne alors
    // entièrement sur le réseau de l'atelier, sans Internet ni clé API.
    final settings = _ref.read(aiAgentSettingsProvider);
    final localUrl = settings.localBaseUrl;
    final useLocal = settings.usesLocal;
    final modelId =
        useLocal ? settings.localModel : _ref.read(aiModelProvider).active.id;

    // Réutilise le service si ni le modèle ni le fournisseur n'ont changé.
    final isLocal = _service is LocalAiAgentService;
    if (_service != null && _service!.model == modelId && isLocal == useLocal) {
      return _service;
    }
    if (_service != null) {
      _service!.dispose();
      _service = null;
    }

    if (useLocal) {
      // Client HTTP standard, volontairement : le process est déjà lié au WiFi
      // de l'ESP32 par bindProcessToNetwork, et c'est sur CE réseau que vit le
      // serveur. Le forcer sur la 4G comme Gemini n'aboutirait nulle part.
      //
      // Le sondage lit ce que le serveur dit de CE modèle (contexte, images) :
      // c'est lui qui décide du budget d'historique et du sort des images, et
      // il peut refuser une configuration qui dégraderait les réponses en
      // silence — avant la première question, pas après.
      final info = await LocalAiAgentService.probe(localUrl, modelId);
      final local = LocalAiAgentService(
          baseUrl: localUrl, model: modelId, info: info);
      final problem = local.configurationProblem;
      if (problem != null) {
        local.dispose();
        state = state.copyWith(error: problem);
        return null;
      }
      _service = local;
      return _service;
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
    // Mêmes garde-fous de réponse que le modèle local (langue, réponse vide) :
    // changer de fournisseur ne doit pas changer les contraintes.
    _service = GuardedBackend(
        AiAgentService(apiKey: key, model: modelId, client: CellularHttpClient()));
    return _service;
  }

  void _addMessage(AiChatMessage message, {bool persist = true}) {
    state = state.copyWith(messages: [...state.messages, message]);
    if (persist) unawaited(_persist());
  }

  /// Remplace un message par sa version aboutie, en place — l'étape ne saute
  /// pas en bas du fil, elle se met à jour là où elle est.
  ///
  /// La recherche se fait par identité et depuis la fin : un même outil peut
  /// être appelé plusieurs fois avec les mêmes arguments dans un même tour,
  /// et c'est bien l'exécution EN COURS qu'il faut mettre à jour. Si le
  /// message a disparu (discussion changée, historique effacé pendant
  /// l'appel), on n'ajoute rien : ce résultat appartient à un fil qui n'est
  /// plus ouvert.
  void _replaceMessage(AiChatMessage previous, AiChatMessage next) {
    final messages = state.messages;
    final index = messages.lastIndexWhere((m) => identical(m, previous));
    if (index < 0) return;
    final updated = List<AiChatMessage>.of(messages);
    updated[index] = next;
    state = state.copyWith(messages: updated);
    unawaited(_persist());
  }

  /// Envoie un message. [imageBytes] (optionnel) joint une image analysée par
  /// Gemini (vision) : photo de pièce, plan, écran, défaut à inspecter…
  ///
  /// [allowModel] = faux quand l'opérateur a désactivé l'agent IA : seul le
  /// lexique fermé répond (voir `ai_lexicon_front.dart`), jamais un modèle —
  /// local ou distant. Les écrans qui gardent la saisie ouverte malgré un agent
  /// désactivé le passent à faux.
  Future<void> sendUserMessage(
    String text, {
    Uint8List? imageBytes,
    String? imageMime,
    bool allowModel = true,
  }) async {
    final trimmed = text.trim();

    // Arrêt d'urgence : le chemin de sécurité ne passe PAS par le modèle (voir
    // emergency_intent.dart). Ni serveur IA, ni réseau mobile, ni tirage
    // probabiliste — et même si l'agent est en train de répondre.
    if (imageBytes == null && isEmergencyStopRequest(trimmed)) {
      await _emergencyStopFromChat(trimmed);
      return;
    }

    // Porte d'entrée « lexique fermé » : lit le message AVANT le modèle. Elle
    // passe avant le garde « agent occupé » ci-dessous parce qu'un arrêt
    // d'urgence dit dans une langue que l'expression ci-dessus ne connaît pas
    // (« jɔ sisan ») ne doit pas être jeté parce que le modèle réfléchit.
    final front = (imageBytes == null && trimmed.isNotEmpty)
        ? await _readFront(trimmed)
        : null;
    if (front != null && front.isEmergencyStop) {
      await _emergencyStopFromChat(trimmed, front: front);
      return;
    }

    if ((trimmed.isEmpty && imageBytes == null) || state.isProcessing) return;

    // Nouveau tour : l'éventuelle action du lexique restée en attente est
    // abandonnée (l'opérateur est passé à autre chose), et la restriction de
    // lecture du tour précédent ne se reporte pas.
    _readOnlyTurn = false;
    _frontTag = null;
    if (state.pendingConfirmation?.lexicon != null) {
      _dropLexiconPending('remplacée par un nouveau message', quiet: true);
    }

    if (front != null) {
      if (await _applyFront(trimmed, front, allowModel: allowModel)) return;
    } else if (!allowModel) {
      return; // agent désactivé et rien que le lexique puisse faire de ce message
    }

    final service = await _ensureService();
    if (service == null) {
      // Pas de modèle joignable (pas de clé, serveur absent) : le lexique reste
      // utile, et dit à l'opérateur ce qui marche quand même.
      if (front != null) _answerWithoutModel(trimmed, front.refusal);
      return;
    }

    _cancelled = false;
    try {
      await _ref.read(docCorpusProvider.future);
    } catch (_) {/* pas de fiches : le modèle répond comme avant */}

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
    state = state.copyWith(turnStartedAt: DateTime.now(), turnTokens: 0);

    // Pré-vérif réseau : le WiFi de l'ESP32 n'a pas d'Internet, l'IA distante
    // doit passer par la 4G/5G. Si les données mobiles sont coupées, on
    // prévient tout de suite (≤ 2 s) au lieu d'attendre un timeout HTTP, et on
    // arme la reprise automatique dès que le réseau revient.
    //
    // Un modèle LOCAL n'a pas besoin de la 4G : l'exiger ici l'empêcherait de
    // servir précisément là où il est utile — téléphone sur le WiFi de la
    // machine, données mobiles coupées ou absentes.
    if (service.usesCellular && !await CellularNetwork.isAvailable()) {
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

  /// Arrêt d'urgence demandé dans le chat : exécuté tout de suite, sans
  /// passer par le modèle. Mesuré sur le modèle local, « Arrête tout, c'est
  /// urgent ! » a un jour rendu une réponse vide : un ordre d'arrêt ne peut pas
  /// dépendre d'un tirage probabiliste.
  Future<void> _emergencyStopFromChat(String text, {_Front? front}) async {
    final clock = Stopwatch()..start();
    final wasBusy = state.isProcessing || state.pendingConfirmation != null;
    _addMessage(AiChatMessage(role: 'user', text: text, timestamp: DateTime.now()));

    var result = 'ERREUR: outil d\'arrêt d\'urgence introuvable';
    var parts = <Map<String, dynamic>>[];
    final tool = AiToolCatalog.byName('emergency_stop');
    if (tool != null) {
      parts = await _executeTool(tool, 'emergency_stop', const {});
      final response = parts.isEmpty
          ? null
          : (parts.first['functionResponse'] as Map?)?['response'] as Map?;
      result = '${response?['result'] ?? response?['error'] ?? result}';
    }

    // Un tour en cours est interrompu APRÈS l'arrêt, jamais avant : l'arrêt prime.
    if (wasBusy) stopGeneration();

    final sent = result.startsWith('OK');
    final match = front?.match;
    final reply = match != null
        // Compris par le lexique : phrase fixe, relue pour la langue si elle
        // l'est (voir CommandLexicon.reply), sinon celle de l'application.
        ? lexiconReply(match: match, toolResult: result, lexicon: front!.lexicon)
        : sent
            ? 'Arrêt d\'urgence envoyé à la machine.'
            : 'ATTENTION — $result. Utilise le bouton rouge « Arrêt d\'urgence » '
                'ou coupe l\'alimentation.';
    if (front != null) {
      _logFront(front, 'lexique:direct:emergencyStop:urgence', clock,
          tools: const ['emergency_stop']);
    }
    _addMessage(AiChatMessage(role: 'assistant', text: reply, timestamp: DateTime.now()));
    _ref.read(aiInboxProvider.notifier).pushAlert(reply, problem: !sent);

    // Fil de protocole valide (texte, appel, réponse, texte) — sauf si un tour
    // était en cours : y insérer des entrées romprait l'appariement appel /
    // réponse de ce tour.
    if (!wasBusy) {
      _contents
        ..add({'role': 'user', 'parts': [{'text': text}]})
        ..add({
          'role': 'model',
          'parts': [
            {'functionCall': {'name': 'emergency_stop', 'args': <String, dynamic>{}}}
          ]
        })
        ..add({
          'role': 'user',
          'parts': parts.isEmpty
              ? [_functionResponse('emergency_stop', result: result)]
              : parts,
        })
        ..add({'role': 'model', 'parts': [{'text': reply}]});
      unawaited(_persist());
    }
  }

  /// Interrompt la génération en cours (bouton « Stop »). Le texte déjà reçu
  /// est conservé et marqué comme tronqué ; l'historique protocole reste
  /// valide (chaque appel d'outil resté en attente reçoit une réponse
  /// « interrompu », faute de quoi Gemini rejetterait le tour suivant).
  void stopGeneration() {
    final pending = state.pendingConfirmation;
    if (!state.isProcessing && pending == null) return;

    // Action du lexique en attente : aucune boucle de modèle à interrompre,
    // aucune réponse d'outil à fabriquer pour l'historique du modèle.
    if (pending?.lexicon != null) {
      _dropLexiconPending('annulée par l\'opérateur');
      return;
    }
    _cancelled = true;

    if (pending != null) {
      // Aucune boucle asynchrone en vol dans ce cas : on solde immédiatement.
      _collectedResults.add(_functionResponse(pending.toolName,
          error: 'Interrompu par l\'utilisateur.'));
      _abortToolChain();
      return;
    }

    final partial = _latestStreamingText ?? state.streamingText;
    _latestStreamingText = null;
    state = state.copyWith(
        isProcessing: false,
        clearStreamingText: true,
        clearTurnStartedAt: true);
    if (partial != null && partial.trim().isNotEmpty) {
      _addMessage(AiChatMessage(
        role: 'assistant',
        text: partial,
        timestamp: DateTime.now(),
        interrupted: true,
      ));
    }
  }

  /// Arme une reprise : mémorise l'action à rejouer, affiche l'erreur et lance
  /// la surveillance réseau qui la relancera automatiquement dès que possible.
  void _armRetry(Future<void> Function() action, String message,
      {Future<bool> Function()? probe}) {
    _retry = action;
    _retryProbe = probe;
    state = state.copyWith(
      isProcessing: false,
      error: message,
      retryable: true,
      awaitingNetwork: true,
      clearTurnStartedAt: true,
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
      if (await (_retryProbe ?? CellularNetwork.isAvailable)()) {
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
    _cancelled = false;
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

  Future<void> _runTurn(AiBackend baseService) async {
    final epoch = _epoch;
    // Un tour qui porte une image va au modèle d'images (s'il y en a un), SANS
    // outils : il décrit, il n'agit pas. Les tours de texte restent au modèle
    // principal, qui pilote la machine.
    final vision = _lastTurnHasImage() ? await _ensureVisionService() : null;
    final service = vision ?? baseService;
    _turnGroups = null; // reposé par _declarationsFor pour un tour avec outils
    // Borne le contexte AVANT l'envoi : c'est la taille de `_contents` qui est
    // facturée (et comptée dans le quota gratuit) à chaque tour.
    compactGeminiContents(_contents, maxChars: service.historyBudgetChars);
    state = state.copyWith(
        isProcessing: true,
        clearError: true,
        retryable: false,
        awaitingNetwork: false,
        clearStreamingText: true,
        turnStartedAt: state.turnStartedAt ?? DateTime.now());
    final clock = Stopwatch()..start();
    _latestStreamingText = null;
    var lastDeltaEmit = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final declarations = vision != null
          ? const <Map<String, dynamic>>[]
          : _declarationsFor(service);
      final groups = _turnGroups;
      state = state.copyWith(
          specialists: vision != null
              ? const ['images']
              : (groups == null ? const [] : (groups.toList()..sort())));
      final response = await service.streamMessages(
        contents: _contents,
        functionDeclarations: declarations,
        systemPrompt: _buildSystemPrompt(),
        // Aperçu live cadencé à ~25 Hz (40 ms) pour éviter 80 rebuilds/s.
        onDelta: (partial) {
          if (_cancelled) return;
          _latestStreamingText = partial;
          final now = DateTime.now();
          if (now.difference(lastDeltaEmit).inMilliseconds >= 40) {
            lastDeltaEmit = now;
            state = state.copyWith(streamingText: partial);
          }
        },
        shouldCancel: () => _cancelled || _epoch != epoch,
      );

      // La discussion a changé pendant l'appel : cette réponse appartient à un
      // fil qui n'est plus ouvert, on la laisse tomber sans rien écrire.
      if (_epoch != epoch) return;

      if (_cancelled) {
        _logTurn(service, AiTurnOutcome.cancelled, clock, response: response);
        _finishCancelled(response);
        return;
      }

      // Réponse vide : ni texte, ni appel d'outil. Ne PAS l'inscrire dans
      // l'historique (une entrée sans contenu invalide le fil chez Gemini) et
      // ne pas se taire non plus : devant un ordre comme « arrête tout », un
      // silence ferait croire que c'est fait. Mesuré sur le modèle local :
      // « Arrête tout, c'est urgent ! » a rendu une réponse vide.
      if (response.text.trim().isEmpty && response.functionCalls.isEmpty) {
        _logTurn(service, AiTurnOutcome.empty, clock, response: response);
        _ref
            .read(aiUsageProvider.notifier)
            .recordRequest(service.model, tokens: response.totalTokens);
        _retry = () => _runTurn(baseService);
        _retryProbe = null;
        state = state.copyWith(
          clearStreamingText: true,
          isProcessing: false,
          error: 'L\'assistant n\'a rien répondu. Réessaie ; si cela se '
              'répète, reformule ta demande. Pour un arrêt immédiat, utilise '
              'le bouton rouge « Arrêt d\'urgence ».',
          retryable: true,
          clearTurnStartedAt: true,
        );
        return;
      }

      // Fin du streaming : on efface l'aperçu et on fige le message.
      state = state.copyWith(clearStreamingText: true);
      _contents.add({'role': 'model', 'parts': response.parts});
      if (vision != null && response.text.isNotEmpty) {
        _attachImageFiche(response.text, vision.model);
      }
      unawaited(_persist());
      // Comptabilise l'appel abouti (quotas du jour, par modèle).
      _ref
          .read(aiUsageProvider.notifier)
          .recordRequest(service.model, tokens: response.totalTokens);
      _logTurn(service, AiTurnOutcome.ok, clock, response: response);
      state = state.copyWith(
          turnTokens: state.turnTokens + response.totalTokens);

      if (response.text.isNotEmpty) {
        // Après une recherche (fiches trouvées ou non), un refus est un refus :
        // sans « cependant » ni procédure tirée de la mémoire du modèle.
        final block = _docsBlockOrNull();
        _addMessage(AiChatMessage(
          role: 'assistant',
          text: block != null ? enforceNoFicheReply(response.text, block: block) : response.text,
          timestamp: DateTime.now(),
        ));
        // Badge le bouton IA si l'écran n'est pas ouvert (info à présenter).
        _ref.read(aiInboxProvider.notifier).pushAlert(response.text);
      }

      // Photo + ordre (« regarde et lance le scan ») : le modèle d'images n'a
      // pas d'outils, il ne peut que décrire. On passe la main au modèle
      // principal, qui a la fiche et les outils, pour exécuter la demande.
      if (vision != null && _handOffImageRequestToPilot()) {
        unawaited(_persist());
        return _runTurn(baseService);
      }

      if (response.functionCalls.isNotEmpty) {
        _pendingToolQueue = List.of(response.functionCalls);
        await _processNextToolCall(baseService, epoch);
      } else {
        _clearRetry();
        state = state.copyWith(isProcessing: false, clearTurnStartedAt: true);
      }
    } catch (e) {
      if (_epoch != epoch) return; // discussion changée → erreur sans objet
      state = state.copyWith(clearStreamingText: true);

      // Interruption demandée : l'échec est attendu, pas une panne à rejouer.
      if (_cancelled) {
        _logTurn(service, AiTurnOutcome.cancelled, clock);
        _finishCancelled(const AiApiResponse(parts: [], finishReason: 'CANCELLED'));
        return;
      }

      final raw = e.toString();
      _logTurn(service, AiTurnOutcome.error, clock,
          errorKind: _isQuota(raw)
              ? 'quota'
              : _isUnreachable(e)
                  ? 'unreachable'
                  : 'other');

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
          () => _runTurn(baseService),
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
      _armRetry(
        () => _runTurn(baseService),
        _friendlyError(e, service),
        probe: service.usesCellular ? null : service.isReachable,
      );
    }
  }

  /// Solde un tour interrompu : seul le texte reçu entre dans l'historique
  /// protocole. Les `functionCall` sont volontairement jetés — sans leur
  /// `functionResponse`, ils rendraient tout le fil invalide pour Gemini.
  void _finishCancelled(AiApiResponse response) {
    final text = response.text;
    if (text.isNotEmpty) {
      _contents.add({
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      });
    }
    _pendingToolQueue = [];
    _collectedResults = [];
    _cancelled = false;
    _clearRetry();
    state = state.copyWith(
        isProcessing: false,
        clearStreamingText: true,
        clearPendingConfirmation: true,
        clearTurnStartedAt: true);
    unawaited(_persist());
  }

  /// Solde une chaîne d'appels d'outils interrompue : chaque appel encore en
  /// file reçoit une réponse d'échec, pour que l'historique reste appairé.
  void _abortToolChain() {
    for (final block in _pendingToolQueue) {
      final call = (block['functionCall'] as Map?)?.cast<String, dynamic>();
      final name = call?['name'] as String? ?? 'unknown';
      _collectedResults
          .add(_functionResponse(name, error: 'Interrompu par l\'utilisateur.'));
    }
    _pendingToolQueue = [];
    if (_collectedResults.isNotEmpty) {
      _contents.add({'role': 'user', 'parts': _collectedResults});
      _collectedResults = [];
    }
    _cancelled = false;
    _clearRetry();
    state = state.copyWith(
        isProcessing: false,
        clearStreamingText: true,
        clearPendingConfirmation: true,
        clearTurnStartedAt: true);
    unawaited(_persist());
  }

  bool _isQuota(String raw) =>
      raw.contains('HTTP 429') ||
      raw.contains('RESOURCE_EXHAUSTED') ||
      raw.contains('Too Many Requests');

  /// Traduit une erreur technique en message court et actionnable.
  String _friendlyError(Object e, AiBackend service) {
    if (e is CellularNetworkException) return e.toString();
    if (_isUnreachable(e)) return service.unreachableMessage;
    return e.toString();
  }

  /// Échec de joignabilité (réseau coupé, serveur éteint, délai dépassé).
  bool _isUnreachable(Object e) {
    final raw = e.toString();
    return raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('TimeoutException') ||
        raw.contains('Connection');
  }

  Future<void> _processNextToolCall(AiBackend service, int epoch) async {
    // Discussion changée pendant l'exécution d'un outil : la chaîne appartient
    // à un fil qui n'est plus ouvert, on l'abandonne sans toucher à l'état.
    if (_epoch != epoch) return;

    if (_cancelled) {
      _abortToolChain();
      return;
    }

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
      await _processNextToolCall(service, epoch);
      return;
    }

    // Le lexique a lu une question ou une négation : seuls les outils de
    // lecture ont été déclarés, et un appel à un autre outil (un modèle peut en
    // inventer un) n'est PAS exécuté — la restriction est une règle, pas un
    // souhait.
    if (_readOnlyTurn && !isReadOnlyToolName(toolName)) {
      _collectedResults.add(_functionResponse(toolName,
          error: 'Non exécuté : le message est une question ou une négation, '
              'aucune action sur la machine n\'est permise pour ce tour.'));
      await _processNextToolCall(service, epoch);
      return;
    }

    final category = tool.category;
    final needsConfirmation = category != null &&
        _ref.read(aiAgentSettingsProvider).levelFor(category) ==
            AiAutonomyLevel.requireConfirmation;

    if (needsConfirmation) {
      state = state.copyWith(
        isProcessing: false,
        clearTurnStartedAt: true,
        pendingConfirmation:
            AiPendingToolCall(id: callId, toolName: toolName, input: input),
      );
      return;
    }

    state = state.copyWith(runningTool: toolName);
    _collectedResults.addAll(await _executeTool(tool, toolName, input));
    state = state.copyWith(clearRunningTool: true);
    await _processNextToolCall(service, epoch);
  }

  /// Approuve l'appel d'outil en attente et poursuit la conversation.
  Future<void> confirmPendingAction() async {
    final pending = state.pendingConfirmation;
    // Action venue du lexique : pas de modèle dans la boucle, donc pas besoin
    // d'un service — la confirmation marche même agent désactivé ou hors ligne.
    if (pending?.lexicon != null) {
      await _confirmLexiconPending(pending!);
      return;
    }
    final service = _service;
    if (pending == null || service == null) return;

    final epoch = _epoch;
    _cancelled = false;
    state = state.copyWith(isProcessing: true, clearPendingConfirmation: true);
    final tool = AiToolCatalog.byName(pending.toolName);
    if (tool == null) {
      _collectedResults.add(
        _functionResponse(pending.toolName, error: 'Outil inconnu "${pending.toolName}"'),
      );
    } else {
      state = state.copyWith(runningTool: pending.toolName);
      _collectedResults.addAll(await _executeTool(tool, pending.toolName, pending.input));
      state = state.copyWith(clearRunningTool: true);
    }
    await _processNextToolCall(service, epoch);
  }

  /// Refuse l'appel d'outil en attente : Gemini reçoit une functionResponse
  /// d'échec et la conversation continue sans que l'action soit exécutée.
  Future<void> rejectPendingAction() async {
    final pending = state.pendingConfirmation;
    if (pending?.lexicon != null) {
      _dropLexiconPending('refusée par l\'opérateur');
      return;
    }
    final service = _service;
    if (pending == null || service == null) return;

    _collectedResults.add(
      _functionResponse(pending.toolName, error: 'Action refusée par l\'utilisateur.'),
    );
    _addMessage(AiChatMessage(
      role: 'tool',
      text: '${pending.toolName} → refusé par l\'utilisateur',
      timestamp: DateTime.now(),
      toolName: pending.toolName,
      toolArgs: pending.input,
      toolResult: 'refusé par l\'utilisateur',
      toolDuration: Duration.zero,
    ));
    state = state.copyWith(isProcessing: true, clearPendingConfirmation: true);
    await _processNextToolCall(service, _epoch);
  }

  /// Exécute un outil et retourne les parts à joindre au tour.
  ///
  /// Une liste et non une part unique : un outil visuel produit une
  /// `functionResponse` **et** une part `inlineData` portant l'image, les deux
  /// devant partir ensemble dans le même tour.
  Future<List<Map<String, dynamic>>> _executeTool(
    AiTool tool,
    String toolName,
    Map<String, dynamic> input,
  ) async {
    // L'étape entre dans le fil AVANT l'exécution, avec ses arguments : c'est
    // ce qui rend la procédure lisible en direct plutôt qu'à retardement. Le
    // placeholder n'est pas persisté — il ne représente rien d'abouti, et une
    // fermeture d'application pendant l'appel ne doit pas laisser une étape
    // qui tourne pour l'éternité au rechargement.
    final started = AiChatMessage.toolStarted(tool.name, input);
    _addMessage(started, persist: false);

    try {
      final result = await tool.execute(input, _ref);

      // On vide systématiquement la boîte aux lettres, même si l'outil n'a
      // finalement rien déposé : une image oubliée là serait rattachée au
      // prochain appel visuel, qui montrerait alors une scène périmée.
      final image = tool.producesImage ? _readAndClearToolImage() : null;

      // L'image apparaît dans le fil de discussion : l'opérateur doit pouvoir
      // voir exactement ce que l'agent a vu, sinon il n'a aucun moyen de juger
      // si son analyse repose sur une image exploitable.
      _replaceMessage(started, started.toolFinished(result, image: image?.bytes));

      final parts = <Map<String, dynamic>>[
        _functionResponse(toolName, result: result),
      ];

      if (image != null) {
        parts.add({
          'inlineData': {
            'mimeType': image.mimeType,
            'data': base64Encode(image.bytes),
          },
        });
        // Une image consomme des jetons comme n'importe quelle entrée : elle
        // doit être comptée au même titre que celles jointes à la main.
        _ref.read(aiUsageProvider.notifier).recordImage();
      }

      return parts;
    } catch (e) {
      final message = 'Erreur: $e';
      _replaceMessage(started, started.toolFinished(message));
      if (tool.producesImage) _readAndClearToolImage();
      return [_functionResponse(toolName, error: message)];
    }
  }

  AiToolImage? _readAndClearToolImage() {
    final image = _ref.read(aiToolImageProvider);
    if (image != null) _ref.read(aiToolImageProvider.notifier).state = null;
    return image;
  }

  Map<String, dynamic> _functionResponse(String name, {String? result, String? error}) {
    return {
      'functionResponse': {
        'name': name,
        'response': error != null ? {'error': error} : {'result': result},
      },
    };
  }

  /// Vide la discussion courante (historique API, affichage et stockage), sans
  /// toucher aux autres discussions sauvegardées.
  void clearConversation() {
    stopGeneration();
    _ref.read(aiArtifactsProvider.notifier).clear();
    _epoch++;
    _contents.clear();
    _pendingToolQueue = [];
    _collectedResults = [];
    _readOnlyTurn = false;
    _retry = null;
    _autoRetryTimer?.cancel();
    state = AiChatState(
      conversations: List.of(_conversations),
      activeId: _activeId,
    );
    unawaited(_clearStorage());
  }

  Future<void> _clearStorage() async {
    final id = _activeId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_payloadKey(id));
      final index = _conversations.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _conversations[index] = _conversations[index]
            .copyWith(title: kDefaultTitle, messageCount: 0);
        state = state.copyWith(conversations: List.of(_conversations));
        await prefs.setString(_kIndexKey,
            jsonEncode(_conversations.map((c) => c.toJson()).toList()));
      }
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
