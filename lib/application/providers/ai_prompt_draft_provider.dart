import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier partagé stockant le brouillon de saisie utilisateur
/// afin que le texte soit synchronisé lors du basculement entre
/// la fenêtre omniprésente Forgeron IA et la page plein écran Agent IA.
class AiPromptDraftNotifier extends StateNotifier<String> {
  AiPromptDraftNotifier() : super('');

  void updateDraft(String text) {
    if (state != text) {
      state = text;
    }
  }

  void clear() {
    state = '';
  }
}

final aiPromptDraftProvider =
    StateNotifierProvider<AiPromptDraftNotifier, String>(
  (ref) => AiPromptDraftNotifier(),
);
