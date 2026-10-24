// Ce fichier est la suite de la classe `AiAgentController` (même bibliothèque) : il
// écrit `state` comme elle le ferait. L'analyseur ne le voit pas, car les membres
// protégés de StateNotifier ne sont pas accessibles depuis une extension.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'ai_agent_provider.dart';

/// Porte d'entrée « lexique fermé » du contrôleur de l'assistant.
///
/// Un message de l'opérateur passe ici AVANT le modèle de langage (voir
/// `command_understanding.dart` pour la politique, `docs/lexique-gouvernance.md`
/// pour le pourquoi) :
///
/// - compris et sans risque → exécuté, réponse en phrase fixe, **sans modèle** ;
/// - compris mais qui agit → carte de confirmation avec ce qui a été reconnu ;
/// - question ou négation → le modèle n'aura que les outils de lecture ;
/// - sinon → le modèle, comme avant.
///
/// Tout ce qui est exécuté ici passe par `_executeTool`, donc par les mêmes
/// outils, le même journal d'activité et les mêmes garde-fous machine que les
/// appels du modèle : le lexique est un appelant de plus, pas un contournement.
///
/// Fichier `part` : il touche aux champs privés du contrôleur (`_contents`,
/// `_addMessage`, `_executeTool`…) sans les rendre publics.

/// Le lexique lu pour UN message : le moteur et ce qu'il en a décidé.
class _Front {
  const _Front(this.lexicon, this.decision);

  final CommandLexicon lexicon;
  final CommandDecision decision;

  /// Arrêt d'urgence compris sans réserve : part tout de suite, même si
  /// l'assistant est occupé (voir `sendUserMessage`).
  bool get isEmergencyStop {
    final d = decision;
    return d is RunNow && d.reason == RunReason.emergencyStop;
  }

  LexiconMatch? get match => switch (decision) {
        RunNow d => d.match,
        AskConfirmation d => d.match,
        _ => null,
      };

  /// Raison du refus du lexique, si le message n'est pas devenu une action.
  String? get refusal => switch (decision) {
        RestrictToReading d => d.refusal,
        DeferToModel d => d.refusal,
        _ => null,
      };
}

extension _LexiconFront on AiAgentController {
  /// `version/empreinte` du lexique chargé — inscrite dans le journal, pour
  /// savoir QUEL lexique a compris (ou refusé) un message.
  String? get _lexiconStamp {
    final lexicon = _ref.read(lexiconLoadProvider).valueOrNull?.lexicon;
    if (lexicon == null) return null;
    return '${lexicon.version}/${lexicon.fingerprint.substring(0, 8)}';
  }

  /// Lit [text] avec le lexique. `null` = pas de lexique (réglage coupé, fichier
  /// invalide) : l'assistant se comporte alors exactement comme avant.
  Future<_Front?> _readFront(String text) async {
    try {
      final settings = _ref.read(aiAgentSettingsProvider);
      if (!settings.lexiconEnabled) return null;
      final lexicon = (await _ref.read(lexiconLoadProvider.future)).lexicon;
      if (lexicon == null) return null;
      final decision = CommandUnderstanding(
        lexicon,
        categoryOf: (tool) => AiToolCatalog.byName(tool)?.category,
        levelFor: settings.levelFor,
      ).decide(text);
      return _Front(lexicon, decision);
    } catch (_) {
      return null; // jamais fatal : sans lexique, comportement d'avant
    }
  }

  /// Applique la décision. `true` = le tour est soldé ici (le modèle n'est pas
  /// appelé) ; `false` = le modèle prend la suite, éventuellement restreint à
  /// la lecture (`_readOnlyTurn`).
  Future<bool> _applyFront(
    String text,
    _Front front, {
    required bool allowModel,
  }) async {
    final clock = Stopwatch()..start();
    switch (front.decision) {
      case RunNow d:
        await _runLexiconNow(text, front, d, clock);
        return true;
      case AskConfirmation d:
        _askLexiconConfirmation(text, front, d, clock);
        return true;
      case RestrictToReading d:
        _readOnlyTurn = true;
        _frontTag = 'lexique:lecture_seule:${d.refusal}';
      case DeferToModel d:
        _frontTag = 'lexique:refus:${d.refusal}';
    }
    if (!allowModel) {
      _answerWithoutModel(text, front.refusal, disabled: true);
      return true;
    }
    return false;
  }

  /// Exécute l'outil d'un appel du lexique par le chemin commun des outils et
  /// rend son résultat brut (`OK…`, `REFUSÉ…`, `ERREUR…`, ou le JSON d'une
  /// lecture).
  Future<String> _executeLexiconTool(LexiconMatch match) async {
    final tool = AiToolCatalog.byName(match.tool);
    if (tool == null) return 'ERREUR: outil « ${match.tool} » introuvable';
    state = state.copyWith(
        isProcessing: true, runningTool: tool.name, clearError: true);
    final parts = await _executeTool(tool, tool.name, match.args);
    state = state.copyWith(isProcessing: false, clearRunningTool: true);
    final response = parts.isEmpty
        ? null
        : (parts.first['functionResponse'] as Map?)?['response'] as Map?;
    return '${response?['result'] ?? response?['error'] ?? 'ERREUR: pas de réponse'}';
  }

  Future<void> _runLexiconNow(
      String text, _Front front, RunNow d, Stopwatch clock) async {
    final epoch = _epoch;
    _addMessage(
        AiChatMessage(role: 'user', text: text, timestamp: DateTime.now()));
    final result = await _executeLexiconTool(d.match);
    if (_epoch != epoch) return; // discussion changée pendant l'appel
    final reply = lexiconReply(
        match: d.match, toolResult: result, lexicon: front.lexicon);
    _addMessage(AiChatMessage(
        role: 'assistant', text: reply, timestamp: DateTime.now()));
    _recordLexiconHistory(text, d.match, result, reply);
    _logFront(front, 'lexique:direct:${d.reason.name}:${d.match.intent}', clock,
        tools: [d.match.tool]);
  }

  void _askLexiconConfirmation(
      String text, _Front front, AskConfirmation d, Stopwatch clock) {
    _addMessage(
        AiChatMessage(role: 'user', text: text, timestamp: DateTime.now()));
    final call = AiLexiconCall(
      match: d.match,
      originalText: text,
      reasons: d.reasons,
      label: lexiconActionLabel(d.match),
      reasonText: confirmReasonText(d.reasons, d.match.languages),
    );
    state = state.copyWith(
      isProcessing: false,
      clearTurnStartedAt: true,
      pendingConfirmation: AiPendingToolCall(
        id: '${d.match.tool}_${_callCounter++}',
        toolName: d.match.tool,
        input: d.match.args,
        lexicon: call,
      ),
    );
    _logFront(front, 'lexique:confirmer:${d.match.intent}', clock);
  }

  /// L'opérateur a confirmé une action du lexique.
  Future<void> _confirmLexiconPending(AiPendingToolCall pending) async {
    final call = pending.lexicon!;
    final clock = Stopwatch()..start();
    final epoch = _epoch;
    final lexicon = _ref.read(lexiconLoadProvider).valueOrNull?.lexicon;
    state = state.copyWith(clearPendingConfirmation: true);
    final result = await _executeLexiconTool(call.match);
    if (_epoch != epoch) return;
    final reply =
        lexiconReply(match: call.match, toolResult: result, lexicon: lexicon);
    _addMessage(AiChatMessage(
        role: 'assistant', text: reply, timestamp: DateTime.now()));
    _recordLexiconHistory(call.originalText, call.match, result, reply);
    final stamp = _lexiconStamp;
    unawaited(() async {
      final journal = await _journalOrNull();
      await journal?.record(AiTurnRecord(
        time: DateTime.now(),
        backend: 'lexique',
        model: 'lexique-ferme',
        outcome: AiTurnOutcome.ok,
        latencyMs: clock.elapsedMilliseconds,
        tools: [call.match.tool],
        release: AiAgentController._releaseTag,
        front: 'lexique:execute:${call.match.intent}',
        lexicon: stamp,
      ));
    }());
  }

  /// Action du lexique abandonnée : refusée, annulée, ou remplacée par un
  /// nouveau message. Rien n'est exécuté, rien ne reste en attente.
  void _dropLexiconPending(String why, {bool quiet = false}) {
    final pending = state.pendingConfirmation;
    final call = pending?.lexicon;
    if (pending == null || call == null) return;
    state = state.copyWith(
        clearPendingConfirmation: true,
        isProcessing: false,
        clearTurnStartedAt: true);
    _addMessage(AiChatMessage(
      role: 'tool',
      text: '${pending.toolName} → non exécuté ($why)',
      timestamp: DateTime.now(),
      toolName: pending.toolName,
      toolArgs: pending.input,
      toolResult: 'non exécuté ($why)',
      toolDuration: Duration.zero,
    ));
    final reply = quiet
        ? null
        : tr('D\'accord, je n\'exécute pas : {}.', [call.label.toLowerCase()]);
    if (reply != null) {
      _addMessage(AiChatMessage(
          role: 'assistant', text: reply, timestamp: DateTime.now()));
    }
    _recordLexiconHistory(call.originalText, call.match, 'Action non exécutée ($why).',
        reply ?? tr('D\'accord.'),
        failed: true);
    final stamp = _lexiconStamp;
    unawaited(() async {
      final journal = await _journalOrNull();
      await journal?.record(AiTurnRecord(
        time: DateTime.now(),
        backend: 'lexique',
        model: 'lexique-ferme',
        outcome: AiTurnOutcome.cancelled,
        latencyMs: 0,
        release: AiAgentController._releaseTag,
        front: 'lexique:abandon:${call.match.intent}',
        lexicon: stamp,
      ));
    }());
  }

  /// Le lexique n'a rien compris et il n'y a pas de modèle pour prendre la
  /// suite : on le dit, avec ce qui marche quand même.
  void _answerWithoutModel(String text, String? refusal,
      {bool disabled = false}) {
    _addMessage(
        AiChatMessage(role: 'user', text: text, timestamp: DateTime.now()));
    final help = lexiconHelp(refusal);
    _addMessage(AiChatMessage(
      role: 'assistant',
      text: disabled
          ? '${tr('L\'assistant IA est désactivé (Paramètres > Agent IA).')} $help'
          : help,
      timestamp: DateTime.now(),
    ));
  }

  /// Garde l'échange dans le fil de protocole du modèle (texte, appel, réponse,
  /// texte) : si l'assistant est activé plus tard, il sait ce qui s'est passé.
  void _recordLexiconHistory(
      String text, LexiconMatch match, String result, String reply,
      {bool failed = false}) {
    _contents
      ..add({'role': 'user', 'parts': [{'text': text}]})
      ..add({
        'role': 'model',
        'parts': [
          {'functionCall': {'name': match.tool, 'args': match.args}}
        ]
      })
      ..add({
        'role': 'user',
        'parts': [
          failed
              ? _functionResponse(match.tool, error: result)
              : _functionResponse(match.tool, result: result)
        ],
      })
      ..add({'role': 'model', 'parts': [{'text': reply}]});
    unawaited(_persist());
  }

  /// Une ligne du journal pour un tour traité par le lexique (sans le contenu
  /// du message, comme toutes les lignes du journal).
  void _logFront(_Front front, String tag, Stopwatch clock,
      {List<String> tools = const []}) {
    final stamp = _lexiconStamp;
    unawaited(() async {
      final journal = await _journalOrNull();
      await journal?.record(AiTurnRecord(
        time: DateTime.now(),
        backend: 'lexique',
        model: 'lexique-ferme',
        outcome: AiTurnOutcome.ok,
        latencyMs: clock.elapsedMilliseconds,
        tools: tools,
        release: AiAgentController._releaseTag,
        front: tag,
        lexicon: stamp,
      ));
    }());
  }
}
