import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle Gemini sélectionnable pour l'agent IA, avec sa limite gratuite (RPD).
class AiModel {
  /// Alias/ID de l'API (les `-latest` résolvent la dernière version publiée).
  final String id;
  final String label;

  /// Requêtes/jour du palier gratuit (source : console AI Studio).
  final int rpd;

  final String note;

  const AiModel(this.id, this.label, this.rpd, this.note);
}

/// Modèles supportant le function calling (indispensable à l'agent), ordonnés
/// par préférence = ordre de bascule automatique. Chaque modèle a son propre
/// quota journalier → les enchaîner cumule ~560 req/jour en gratuit.
const kAiModels = <AiModel>[
  AiModel('gemini-flash-lite-latest', 'Gemini Flash Lite', 500,
      'Rapide et léger — 500 req/jour (recommandé).'),
  AiModel('gemini-flash-latest', 'Gemini Flash', 20,
      'Plus capable — 20 req/jour.'),
  AiModel('gemini-2.5-flash', 'Gemini 2.5 Flash', 20, '20 req/jour.'),
  AiModel('gemini-2.5-flash-lite', 'Gemini 2.5 Flash Lite', 20, '20 req/jour.'),
];

class AiModelState {
  final AiModel active;

  /// IDs de modèles épuisés (429) aujourd'hui.
  final Set<String> exhausted;

  /// Bascule automatique vers le modèle suivant quand le quota est atteint.
  final bool auto;

  const AiModelState({
    required this.active,
    this.exhausted = const {},
    this.auto = true,
  });

  bool get allExhausted => kAiModels.every((m) => exhausted.contains(m.id));

  AiModelState copyWith({AiModel? active, Set<String>? exhausted, bool? auto}) =>
      AiModelState(
        active: active ?? this.active,
        exhausted: exhausted ?? this.exhausted,
        auto: auto ?? this.auto,
      );
}

class AiModelNotifier extends StateNotifier<AiModelState> {
  static const _key = 'ai_model_v2';
  String _day = '';

  AiModelNotifier() : super(AiModelState(active: kAiModels.first)) {
    _load();
  }

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  AiModel _byId(String? id) =>
      kAiModels.firstWhere((m) => m.id == id, orElse: () => kAiModels.first);

  Future<void> _load() async {
    _day = _today;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final active = _byId(j['id'] as String?);
        final auto = (j['auto'] as bool?) ?? true;
        // Les épuisements ne valent que pour la journée en cours.
        final ex = j['day'] == _today
            ? ((j['exhausted'] as List?)?.cast<String>().toSet() ?? <String>{})
            : <String>{};
        state = AiModelState(active: active, exhausted: ex, auto: auto);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key,
          jsonEncode({
            'day': _today,
            'id': state.active.id,
            'auto': state.auto,
            'exhausted': state.exhausted.toList(),
          }));
    } catch (_) {}
  }

  void _rollover() {
    if (_day != _today) {
      _day = _today;
      state = state.copyWith(exhausted: <String>{});
    }
  }

  /// Sélection manuelle d'un modèle.
  void select(AiModel model) {
    state = state.copyWith(active: model);
    _save();
  }

  /// Active/désactive la bascule automatique.
  void setAuto(bool value) {
    state = state.copyWith(auto: value);
    _save();
  }

  /// 429 sur [id] : marque le modèle épuisé et, si [auto], bascule sur le
  /// prochain modèle non épuisé. Retourne le nouveau modèle actif, ou null si
  /// aucune bascule (auto désactivé ou tous les modèles épuisés).
  AiModel? handleQuotaHit(String id) {
    _rollover();
    final ex = {...state.exhausted, id};
    AiModel? next;
    if (state.auto) {
      final avail = kAiModels.where((m) => !ex.contains(m.id));
      if (avail.isNotEmpty) next = avail.first;
    }
    state = state.copyWith(exhausted: ex, active: next ?? state.active);
    _save();
    return next;
  }
}

final aiModelProvider =
    StateNotifierProvider<AiModelNotifier, AiModelState>(
        (ref) => AiModelNotifier());
