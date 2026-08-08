import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catégories d'actions que l'agent IA peut exécuter sur la machine.
/// La lecture seule (état machine, diagnostics) et l'arrêt d'urgence ne sont
/// PAS configurables ici : la lecture est toujours autorisée sans porte, et
/// l'arrêt d'urgence est toujours immédiat (cohérent avec le comportement de
/// l'UI manuelle, qui n'a jamais de confirmation sur E-STOP non plus).
enum AiActionCategory {
  movement, // Jog, homing
  spindleCoolant, // Broche, arrosage
  wcsTool, // Changement de WCS, offsets, outil
  streaming, // Démarrage/pause/reprise/reset d'un programme G-code
  fileEdit, // Écriture/correction d'un fichier G-code de l'espace de travail
}

extension AiActionCategoryLabel on AiActionCategory {
  String get label {
    switch (this) {
      case AiActionCategory.movement:
        return 'Mouvement (Jog, Origines)';
      case AiActionCategory.spindleCoolant:
        return 'Broche & Arrosage';
      case AiActionCategory.wcsTool:
        return 'WCS & Outil';
      case AiActionCategory.streaming:
        return 'Streaming G-code';
      case AiActionCategory.fileEdit:
        return 'Édition de fichiers G-code';
    }
  }
}

/// Niveau d'autonomie accordé à l'agent pour une catégorie d'action donnée.
enum AiAutonomyLevel {
  autoExecute,
  requireConfirmation,
}

/// Réglages persistants de l'agent IA : activation, permissions par
/// catégorie d'action. La clé API est gérée séparément (stockage sécurisé),
/// jamais incluse dans cet objet ni dans sa sérialisation JSON.
class AiAgentSettings {
  final bool enabled;
  final Map<AiActionCategory, AiAutonomyLevel> autonomy;

  const AiAgentSettings({
    this.enabled = false,
    this.autonomy = const {
      AiActionCategory.movement: AiAutonomyLevel.requireConfirmation,
      AiActionCategory.spindleCoolant: AiAutonomyLevel.requireConfirmation,
      AiActionCategory.wcsTool: AiAutonomyLevel.requireConfirmation,
      AiActionCategory.streaming: AiAutonomyLevel.requireConfirmation,
      AiActionCategory.fileEdit: AiAutonomyLevel.requireConfirmation,
    },
  });

  AiAutonomyLevel levelFor(AiActionCategory category) =>
      autonomy[category] ?? AiAutonomyLevel.requireConfirmation;

  AiAgentSettings copyWith({
    bool? enabled,
    Map<AiActionCategory, AiAutonomyLevel>? autonomy,
  }) {
    return AiAgentSettings(
      enabled: enabled ?? this.enabled,
      autonomy: autonomy ?? this.autonomy,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'autonomy': autonomy.map((k, v) => MapEntry(k.name, v.name)),
      };

  factory AiAgentSettings.fromJson(Map<String, dynamic> json) {
    final rawAutonomy =
        (json['autonomy'] as Map?)?.cast<String, dynamic>() ?? const {};
    final autonomy = <AiActionCategory, AiAutonomyLevel>{};
    for (final category in AiActionCategory.values) {
      final raw = rawAutonomy[category.name] as String?;
      autonomy[category] = AiAutonomyLevel.values.firstWhere(
        (l) => l.name == raw,
        orElse: () => AiAutonomyLevel.requireConfirmation,
      );
    }
    return AiAgentSettings(
      enabled: json['enabled'] as bool? ?? false,
      autonomy: autonomy,
    );
  }
}

class AiAgentSettingsNotifier extends StateNotifier<AiAgentSettings> {
  static const _storageKey = 'ai_agent_settings';
  static const _apiKeyStorageKey = 'ai_agent_api_key';
  static const _secureStorage = FlutterSecureStorage();

  AiAgentSettingsNotifier() : super(const AiAgentSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      state = AiAgentSettings.fromJson(jsonDecode(data) as Map<String, dynamic>);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _persist();
  }

  void setAutonomy(AiActionCategory category, AiAutonomyLevel level) {
    final updated = Map<AiActionCategory, AiAutonomyLevel>.from(state.autonomy);
    updated[category] = level;
    state = state.copyWith(autonomy: updated);
    _persist();
  }

  /// Lit la clé API Gemini depuis le stockage sécurisé (Keychain / Keystore
  /// / DPAPI selon la plateforme) — jamais en clair dans SharedPreferences.
  Future<String?> readApiKey() => _secureStorage.read(key: _apiKeyStorageKey);

  Future<void> saveApiKey(String key) =>
      _secureStorage.write(key: _apiKeyStorageKey, value: key);

  Future<void> clearApiKey() => _secureStorage.delete(key: _apiKeyStorageKey);
}

final aiAgentSettingsProvider =
    StateNotifierProvider<AiAgentSettingsNotifier, AiAgentSettings>((ref) {
  return AiAgentSettingsNotifier();
});

/// Provider asynchrone pratique pour lire la clé API ailleurs dans l'app
/// (ex: pour activer/désactiver un bouton "Envoyer" tant qu'aucune clé n'est
/// configurée) sans dupliquer l'accès au stockage sécurisé.
final aiAgentApiKeyProvider = FutureProvider<String?>((ref) {
  return ref.watch(aiAgentSettingsProvider.notifier).readApiKey();
});
