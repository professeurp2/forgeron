import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_ai_agent_service.dart';

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

/// Modèle local proposé par défaut : le dérivé de `tool/ollama/Modelfile`, pas
/// `qwen2.5:7b` tel quel. Ollama charge ce dernier avec un contexte de 4 096
/// tokens (mesuré) — le prompt de l'agent en occupe à lui seul ~6 800 et serait
/// tronqué en silence ; le service local le refuse d'ailleurs.
const defaultLocalModel = 'forgeron-qwen';

/// Réglages persistants de l'agent IA : activation, permissions par
/// catégorie d'action. La clé API est gérée séparément (stockage sécurisé),
/// jamais incluse dans cet objet ni dans sa sérialisation JSON.
class AiAgentSettings {
  final bool enabled;
  final Map<AiActionCategory, AiAutonomyLevel> autonomy;

  /// Adresse du serveur IA **local** (Ollama, llama.cpp, LM Studio…) sur le
  /// réseau de l'atelier. Vide = on interroge Gemini.
  ///
  /// Renseigné, l'agent peut tourner en local, sans Internet — donc sans 4G
  /// pendant que le téléphone est joint à l'AP de l'ESP32. Le choix effectif
  /// est [usesLocal].
  final String localBaseUrl;

  /// Choix explicite de Gemini alors qu'un serveur local est configuré.
  ///
  /// Avant, seul [localBaseUrl] choisissait le fournisseur : passer en ligne
  /// obligeait à effacer l'adresse (dans un réglage « avancé »), et revenir au
  /// local à tout reconfigurer. L'opérateur jugeait le basculement cassé.
  final bool preferOnline;

  /// Fournisseur effectif : le serveur local, s'il est configuré et que
  /// l'opérateur n'a pas choisi Gemini.
  bool get usesLocal => !preferOnline && localBaseUrl.isNotEmpty;

  /// Nom du modèle servi à cette adresse, tel que le serveur le connaît.
  final String localModel;

  /// Modèle local qui LIT LES IMAGES (photo jointe, caméra), vide = aucun. Souvent un
  /// autre que [localModel] : un modèle qui voit (gemma3n) n'appelle pas d\'outils, un
  /// modèle qui pilote la machine (forgeron-qwen) ne voit pas. Les tours qui portent
  /// une image vont au premier, sans outils ; tous les autres au second.
  final String localVisionModel;

  /// Compréhension des commandes par lexique fermé (`assets/lexicon`), AVANT le
  /// modèle : compréhension multilingue sans réseau, arrêt d'urgence dans
  /// toutes les langues du lexique, restriction à la lecture sur les questions
  /// et les négations. Activée par défaut ; la couper ramène l'assistant au
  /// comportement d'avant (modèle seul + chemin rapide de l'arrêt d'urgence).
  final bool lexiconEnabled;

  const AiAgentSettings({
    this.enabled = false,
    this.localBaseUrl = '',
    this.localModel = defaultLocalModel,
    this.localVisionModel = '',
    this.lexiconEnabled = true,
    this.preferOnline = false,
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
    String? localBaseUrl,
    String? localModel,
    String? localVisionModel,
    bool? lexiconEnabled,
    bool? preferOnline,
  }) {
    return AiAgentSettings(
      enabled: enabled ?? this.enabled,
      autonomy: autonomy ?? this.autonomy,
      localBaseUrl: localBaseUrl ?? this.localBaseUrl,
      localModel: localModel ?? this.localModel,
      localVisionModel: localVisionModel ?? this.localVisionModel,
      lexiconEnabled: lexiconEnabled ?? this.lexiconEnabled,
      preferOnline: preferOnline ?? this.preferOnline,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'autonomy': autonomy.map((k, v) => MapEntry(k.name, v.name)),
        'localBaseUrl': localBaseUrl,
        'localModel': localModel,
        'localVisionModel': localVisionModel,
        'lexiconEnabled': lexiconEnabled,
        'preferOnline': preferOnline,
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
      localBaseUrl: json['localBaseUrl'] as String? ?? '',
      localModel: json['localModel'] as String? ?? defaultLocalModel,
      localVisionModel: json['localVisionModel'] as String? ?? '',
      // Réglages enregistrés avant le lexique : activé, c'est le défaut voulu.
      lexiconEnabled: json['lexiconEnabled'] as bool? ?? true,
      preferOnline: json['preferOnline'] as bool? ?? false,
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

  /// Adresse du serveur IA local. Vide = retour à Gemini.
  ///
  /// L'adresse est normalisée à l'enregistrement (« 192.168.0.42 » devient
  /// « http://192.168.0.42:11434 ») : l'opérateur saisit ce qu'il lit sur son
  /// PC, pas une URL complète.
  void setLocalBaseUrl(String value) {
    state = state.copyWith(
        localBaseUrl: LocalAiAgentService.normalizeBaseUrl(value));
    _persist();
  }

  /// Modèle local pour les images ; vide = aucun.
  void setLocalVisionModel(String value) {
    state = state.copyWith(localVisionModel: value.trim());
    _persist();
  }

  /// Bascule entre le serveur local et Gemini, sans rien effacer.
  void setPreferOnline(bool value) {
    state = state.copyWith(preferOnline: value);
    _persist();
  }

  void setLexiconEnabled(bool value) {
    state = state.copyWith(lexiconEnabled: value);
    _persist();
  }

  void setLocalModel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(localModel: trimmed);
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
