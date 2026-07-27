import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/config_repository.dart';
import '../../data/fluidnc/fluidnc_config_repository.dart';
import '../../data/mock/mock_config_repository.dart';
import 'machine_provider.dart';

/// Repository de configuration FluidNC — Bascule entre Mock et Réel selon le mode
final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);
  if (isSim) {
    return MockConfigRepository();
  }
  final ip = ref.watch(espIpProvider);
  return FluidNcConfigRepository('http://$ip');
});

const _kCachedConfigKey = 'cached_config_yaml';
const _kCachedConfigTimeKey = 'cached_config_time';

/// Résultat de config avec provenance (live vs cache) pour l'affichage offline.
class ConfigResult {
  final String yaml;
  final bool fromCache;
  final DateTime? cachedAt;
  const ConfigResult(this.yaml, {this.fromCache = false, this.cachedAt});
}

/// Config FluidNC avec **cache local** : au succès on stocke le YAML dans les
/// préférences ; hors ligne (ou captive portal) on ressert la dernière version
/// connue pour permettre la consultation sans machine.
final configResultProvider = FutureProvider<ConfigResult>((ref) async {
  final repo = ref.watch(configRepositoryProvider);
  final prefs = await SharedPreferences.getInstance();

  String yaml;
  try {
    yaml = await repo.getConfig();
  } catch (e) {
    yaml = '# erreur: $e';
  }

  // getConfig() ne lève pas : en cas d'échec réseau il renvoie un YAML-commentaire
  // d'erreur. On détecte ce cas pour retomber sur le cache.
  final looksLikeError = yaml.contains('Impossible de charger') ||
      yaml.contains('Captive Portal') ||
      yaml.trimLeft().startsWith('# erreur');

  if (looksLikeError) {
    final cached = prefs.getString(_kCachedConfigKey);
    if (cached != null) {
      final ts = prefs.getString(_kCachedConfigTimeKey);
      return ConfigResult(cached,
          fromCache: true,
          cachedAt: ts != null ? DateTime.tryParse(ts) : null);
    }
    return ConfigResult(yaml); // pas de cache : on montre l'erreur
  }

  // Succès → on met à jour le cache.
  await prefs.setString(_kCachedConfigKey, yaml);
  await prefs.setString(_kCachedConfigTimeKey, DateTime.now().toIso8601String());
  return ConfigResult(yaml);
});

/// Ancien provider (String brut) conservé pour compatibilité — délègue au cache.
final configProvider = FutureProvider<String>((ref) async {
  final res = await ref.watch(configResultProvider.future);
  return res.yaml;
});
