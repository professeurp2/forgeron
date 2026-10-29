import 'ai_agent_service.dart';
import 'local_ai_agent_service.dart';

/// Les garde-fous de réponse du modèle local, appliqués à un autre
/// fournisseur (Gemini).
///
/// L'agent doit tenir les mêmes contraintes quel que soit le modèle qui
/// répond : une réponse qui bascule dans une écriture que l'opérateur n'a pas
/// employée (chinois, mesuré sur Qwen) est redemandée avec un rappel de langue,
/// et une réponse vide — ni texte ni appel d'outil — est redemandée une fois,
/// parce que devant une machine le silence passe pour un ordre exécuté. Les
/// règles sont celles de [LocalAiAgentService], pour qu'un changement de
/// fournisseur ne change pas le comportement.
class GuardedBackend implements AiBackend {
  GuardedBackend(this.inner);

  final AiBackend inner;

  @override
  String get model => inner.model;

  @override
  int get historyBudgetChars => inner.historyBudgetChars;

  @override
  bool get usesCellular => inner.usesCellular;

  @override
  Future<bool> isReachable() => inner.isReachable();

  @override
  String get unreachableMessage => inner.unreachableMessage;

  static AiApiResponse _merge(AiApiResponse first, AiApiResponse again, String note) =>
      AiApiResponse(
        parts: again.parts,
        finishReason: again.finishReason,
        totalTokens: again.totalTokens + first.totalTokens,
        notes: [...first.notes, ...again.notes, note],
      );

  Future<AiApiResponse> _guard(
    AiApiResponse r,
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt, {
    void Function(String)? onDelta,
    bool Function()? shouldCancel,
  }) async {
    for (var i = 0;
        i < LocalAiAgentService.maxLanguageRetries &&
            LocalAiAgentService.driftedToChinese(r, contents);
        i++) {
      if (shouldCancel?.call() ?? false) return r;
      final again = await inner.sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: '${systemPrompt ?? ''}${LocalAiAgentService.languageReminder}',
      );
      r = _merge(r, again, LocalAiAgentService.noteLanguageRetry);
      onDelta?.call(r.text);
    }
    if (LocalAiAgentService.isEmptyReply(r) && !(shouldCancel?.call() ?? false)) {
      final again = await inner.sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: '${systemPrompt ?? ''}${LocalAiAgentService.emptyReminder}',
      );
      r = _merge(r, again, LocalAiAgentService.noteEmptyRetry);
      onDelta?.call(r.text);
    }
    return r;
  }

  @override
  Future<AiApiResponse> sendMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
  }) async {
    final r = await inner.sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt);
    return _guard(r, contents, functionDeclarations, systemPrompt);
  }

  @override
  Future<AiApiResponse> streamMessages({
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> functionDeclarations,
    String? systemPrompt,
    void Function(String partialText)? onDelta,
    bool Function()? shouldCancel,
  }) async {
    final r = await inner.streamMessages(
      contents: contents,
      functionDeclarations: functionDeclarations,
      systemPrompt: systemPrompt,
      onDelta: onDelta,
      shouldCancel: shouldCancel,
    );
    return _guard(r, contents, functionDeclarations, systemPrompt,
        onDelta: onDelta, shouldCancel: shouldCancel);
  }

  @override
  void dispose() => inner.dispose();
}
