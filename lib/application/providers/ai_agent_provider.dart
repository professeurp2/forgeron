import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_agent_service.dart';
import '../services/ai_agent_tools.dart';
import '../../core/net/cellular_http_client.dart';
import '../../core/utils/gemini_context.dart';
import 'ai_agent_settings_provider.dart';
import 'ai_inbox_provider.dart';
import 'ai_usage_provider.dart';
import 'ai_model_provider.dart';
import '../../core/i18n/app_language.dart';
import 'activity_log_provider.dart';
import 'machine_params_provider.dart';

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

  const AiChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.interrupted = false,
    this.imageBytes,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'ts': timestamp.millisecondsSinceEpoch,
        if (interrupted) 'cut': true,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> j) => AiChatMessage(
        role: j['role'] as String? ?? 'assistant',
        text: j['text'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (j['ts'] as num?)?.toInt() ?? 0),
        interrupted: j['cut'] == true,
      );
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

  /// Discussions sauvegardées, la plus récemment utilisée en tête.
  final List<AiConversationMeta> conversations;

  /// Identifiant de la discussion ouverte (`null` avant la restauration).
  final String? activeId;

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

  static const _systemPrompt =
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
      'get_wcs_offsets, get_activity_log) plutôt que de deviner. '
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
      'provoquer une collision. '
      'Tu reçois en contexte le journal des actions récentes (manuelles de '
      'l\'opérateur ET les tiennes) : surveille-le pour la sécurité et '
      'l\'optimisation — signale spontanément tout enchaînement risqué (ex. '
      'lancer un programme sans homing, changer d\'origine en plein usinage). '
      'Tu peux générer un programme G-code et l\'exécuter directement avec '
      'run_gcode_program (ou run_program pour le programme déjà chargé). Avant '
      'de lancer un programme ou un mouvement, vérifie/annonce les points de '
      'sécurité clés (homing fait, Z dégagé, bon WCS) et laisse l\'utilisateur '
      'confirmer les actions gatées. '
      'Sois concis et confirme toujours ce que tu as fait. Si une action semble '
      'risquée ou ambiguë, explique-le et demande une précision. '
      'Réponds en texte clair : tu peux utiliser du **gras** et des listes à '
      'puces simples, mais évite le LaTeX et les formules mathématiques (\$...\$) '
      '— écris les valeurs et unités en clair (ex. « 15 mm »). '
      'Quand tu donnes du G-code, mets-le TOUJOURS dans un bloc de code '
      'markdown ouvert par ```gcode et fermé par ``` : l\'app y ajoute alors '
      'les boutons « copier » et « enregistrer dans l\'espace de travail ».';

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

  /// Cinématique réelle lue dans la config FluidNC (live ou cache offline).
  /// Injectée à chaque tour pour que l'agent cite les VRAIES courses et pas/mm
  /// — des constantes figées dans le code dérivent au premier recalibrage.
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
    return '$_systemPrompt\n\n'
        '$_machineSpecs\n\n'
        '${_kinematicsBlock()}\n\n'
        '${_ref.read(appLanguageProvider).promptDirective}\n\n'
        '=== JOURNAL D\'ACTIVITÉ MACHINE (récent, opérateur + toi) ===\n'
        '$activity';
  }

  // ---------------------------------------------------------------------
  // Conversation
  // ---------------------------------------------------------------------

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

    _cancelled = false;

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

  /// Interrompt la génération en cours (bouton « Stop »). Le texte déjà reçu
  /// est conservé et marqué comme tronqué ; l'historique protocole reste
  /// valide (chaque appel d'outil resté en attente reçoit une réponse
  /// « interrompu », faute de quoi Gemini rejetterait le tour suivant).
  void stopGeneration() {
    final pending = state.pendingConfirmation;
    if (!state.isProcessing && pending == null) return;
    _cancelled = true;

    if (pending != null) {
      // Aucune boucle asynchrone en vol dans ce cas : on solde immédiatement.
      _collectedResults.add(_functionResponse(pending.toolName,
          error: 'Interrompu par l\'utilisateur.'));
      _abortToolChain();
      return;
    }

    final partial = state.streamingText;
    state = state.copyWith(isProcessing: false, clearStreamingText: true);
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

  Future<void> _runTurn(AiAgentService service) async {
    final epoch = _epoch;
    // Borne le contexte AVANT l'envoi : c'est la taille de `_contents` qui est
    // facturée (et comptée dans le quota gratuit) à chaque tour.
    compactGeminiContents(_contents);
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
        systemPrompt: _buildSystemPrompt(),
        // Aperçu live : le texte s'affiche au fur et à mesure.
        onDelta: (partial) {
          if (_cancelled) return;
          state = state.copyWith(streamingText: partial);
        },
        shouldCancel: () => _cancelled || _epoch != epoch,
      );

      // La discussion a changé pendant l'appel : cette réponse appartient à un
      // fil qui n'est plus ouvert, on la laisse tomber sans rien écrire.
      if (_epoch != epoch) return;

      if (_cancelled) {
        _finishCancelled(response);
        return;
      }

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
        await _processNextToolCall(service, epoch);
      } else {
        _clearRetry();
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      if (_epoch != epoch) return; // discussion changée → erreur sans objet
      state = state.copyWith(clearStreamingText: true);

      // Interruption demandée : l'échec est attendu, pas une panne à rejouer.
      if (_cancelled) {
        _finishCancelled(const AiApiResponse(parts: [], finishReason: 'CANCELLED'));
        return;
      }

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
        clearPendingConfirmation: true);
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
        clearPendingConfirmation: true);
    unawaited(_persist());
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

  Future<void> _processNextToolCall(AiAgentService service, int epoch) async {
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

    _collectedResults.addAll(await _executeTool(tool, toolName, input));
    await _processNextToolCall(service, epoch);
  }

  /// Approuve l'appel d'outil en attente et poursuit la conversation.
  Future<void> confirmPendingAction() async {
    final pending = state.pendingConfirmation;
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
      _collectedResults.addAll(await _executeTool(tool, pending.toolName, pending.input));
    }
    await _processNextToolCall(service, epoch);
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
    try {
      final result = await tool.execute(input, _ref);

      // On vide systématiquement la boîte aux lettres, même si l'outil n'a
      // finalement rien déposé : une image oubliée là serait rattachée au
      // prochain appel visuel, qui montrerait alors une scène périmée.
      final image = tool.producesImage ? _readAndClearToolImage() : null;

      // L'image apparaît dans le fil de discussion : l'opérateur doit pouvoir
      // voir exactement ce que l'agent a vu, sinon il n'a aucun moyen de juger
      // si son analyse repose sur une image exploitable.
      _addMessage(AiChatMessage(
        role: 'tool',
        text: '${tool.name} → $result',
        timestamp: DateTime.now(),
        imageBytes: image?.bytes,
      ));

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
      _addMessage(AiChatMessage(
        role: 'tool',
        text: '${tool.name} → $message',
        timestamp: DateTime.now(),
      ));
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
    _epoch++;
    _contents.clear();
    _pendingToolQueue = [];
    _collectedResults = [];
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
