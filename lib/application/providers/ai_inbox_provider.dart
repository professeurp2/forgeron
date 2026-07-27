import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

/// État des alertes de l'agent IA à présenter à l'opérateur.
///
/// Sert à badger le bouton flottant 🤖 (point d'interrogation / d'exclamation)
/// quand l'agent a une information ou un problème à signaler alors que l'écran
/// de discussion n'est pas ouvert.
class AiInboxState {
  /// Nombre d'alertes non lues depuis la dernière ouverture de l'écran IA.
  final int unread;

  /// Dernier résumé (première ligne de la réponse ou du problème).
  final String? lastSummary;

  /// `true` si au moins une alerte non lue est un problème (badge « ! » rouge).
  final bool problem;

  const AiInboxState({
    this.unread = 0,
    this.lastSummary,
    this.problem = false,
  });

  bool get hasAlert => unread > 0;

  AiInboxState copyWith({int? unread, String? lastSummary, bool? problem}) =>
      AiInboxState(
        unread: unread ?? this.unread,
        lastSummary: lastSummary ?? this.lastSummary,
        problem: problem ?? this.problem,
      );
}

class AiInbox extends StateNotifier<AiInboxState> {
  AiInbox() : super(const AiInboxState());

  bool _screenOpen = false;

  /// L'écran IA signale son ouverture/fermeture. À l'ouverture, on marque tout
  /// comme lu (l'opérateur voit les messages en direct).
  void setScreenOpen(bool open) {
    _screenOpen = open;
    if (open) markRead();
  }

  /// L'agent a une info à présenter. Ignoré si l'écran IA est déjà ouvert.
  /// [summary] : première ligne à afficher plus tard ; [problem] : alerte grave.
  void pushAlert(String summary, {bool problem = false}) {
    if (_screenOpen) return;
    final trimmed = summary.trim();
    state = state.copyWith(
      unread: state.unread + 1,
      lastSummary: trimmed.isEmpty ? state.lastSummary : trimmed,
      problem: problem || state.problem,
    );
    // Notification système (barre Android) en plus du badge in-app.
    NotificationService.instance.show(
      problem ? 'Agent IA — problème' : 'Agent IA',
      trimmed.isEmpty ? 'Nouvelle information disponible.' : trimmed,
      problem: problem,
    );
  }

  /// Remet le compteur à zéro (à l'ouverture de l'écran IA).
  void markRead() {
    if (state.unread != 0 || state.problem || state.lastSummary != null) {
      state = const AiInboxState();
    }
  }
}

final aiInboxProvider =
    StateNotifierProvider<AiInbox, AiInboxState>((ref) => AiInbox());
