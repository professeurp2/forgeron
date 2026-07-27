import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Suivi local de la consommation de l'API Gemini (palier gratuit).
///
/// Google n'expose pas de « solde restant » via l'API : on compte donc
/// localement l'usage du jour (messages, images, tokens), **par modèle**, et on
/// l'affiche face au RPD gratuit du modèle actif. Le vrai dépassement est
/// détecté via l'erreur HTTP 429 renvoyée par l'API ([quotaHit]).
class AiUsageState {
  final int requests; // total de requêtes aujourd'hui (info)
  final int images; // images jointes aujourd'hui
  final int tokens; // tokens cumulés (usageMetadata) aujourd'hui
  final Map<String, int> perModel; // requêtes par modèle aujourd'hui
  final bool quotaHit; // 429 rencontré aujourd'hui

  const AiUsageState({
    this.requests = 0,
    this.images = 0,
    this.tokens = 0,
    this.perModel = const {},
    this.quotaHit = false,
  });

  /// Requêtes déjà consommées aujourd'hui pour un modèle donné.
  int usedFor(String modelId) => perModel[modelId] ?? 0;

  AiUsageState copyWith({
    int? requests,
    int? images,
    int? tokens,
    Map<String, int>? perModel,
    bool? quotaHit,
  }) =>
      AiUsageState(
        requests: requests ?? this.requests,
        images: images ?? this.images,
        tokens: tokens ?? this.tokens,
        perModel: perModel ?? this.perModel,
        quotaHit: quotaHit ?? this.quotaHit,
      );
}

class AiUsageNotifier extends StateNotifier<AiUsageState> {
  static const _key = 'ai_usage_v1';
  bool _loaded = false;
  String _day = '';

  AiUsageNotifier() : super(const AiUsageState()) {
    _load();
  }

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    _day = _today;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        if (j['day'] == _today) {
          final pm = (j['perModel'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
              <String, int>{};
          state = AiUsageState(
            requests: (j['req'] as num?)?.toInt() ?? 0,
            images: (j['img'] as num?)?.toInt() ?? 0,
            tokens: (j['tok'] as num?)?.toInt() ?? 0,
            perModel: pm,
            quotaHit: (j['quota'] as bool?) ?? false,
          );
        }
        // Sinon (nouveau jour) → compteurs à zéro (état par défaut).
      }
    } catch (_) {
    } finally {
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key,
          jsonEncode({
            'day': _today,
            'req': state.requests,
            'img': state.images,
            'tok': state.tokens,
            'perModel': state.perModel,
            'quota': state.quotaHit,
          }));
    } catch (_) {}
  }

  /// Bascule les compteurs si on a passé minuit avec l'app ouverte.
  void _rolloverIfNeeded() {
    if (_day != _today) {
      _day = _today;
      state = const AiUsageState();
    }
  }

  /// Un appel API abouti sur [modelId] : +1 requête (globale et par modèle) et
  /// +[tokens].
  void recordRequest(String modelId, {int tokens = 0}) {
    _rolloverIfNeeded();
    final pm = {...state.perModel};
    pm[modelId] = (pm[modelId] ?? 0) + 1;
    state = state.copyWith(
      requests: state.requests + 1,
      tokens: state.tokens + tokens,
      perModel: pm,
    );
    _save();
  }

  /// Une image jointe à un message.
  void recordImage() {
    _rolloverIfNeeded();
    state = state.copyWith(images: state.images + 1);
    _save();
  }

  /// L'API a renvoyé 429 (quota gratuit épuisé).
  void markQuotaHit() {
    state = state.copyWith(quotaHit: true);
    _save();
  }
}

final aiUsageProvider =
    StateNotifierProvider<AiUsageNotifier, AiUsageState>((ref) => AiUsageNotifier());
