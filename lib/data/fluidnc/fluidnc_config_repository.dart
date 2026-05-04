import 'package:http/http.dart' as http;

import '../../domain/repositories/config_repository.dart';

/// Repository de configuration FluidNC — lit config.yaml via HTTP GET /config
class FluidNcConfigRepository implements ConfigRepository {
  final String baseUrl; // ex: "http://192.168.1.100"
  final http.Client _client;

  FluidNcConfigRepository(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<String> getConfig() async {
    try {
      final uri = Uri.parse('$baseUrl/config');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.body;
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      return '# FluidNC — Impossible de charger la configuration\n# Erreur: $e\n'
          '# Vérifiez la connexion à l\'ESP32 ($baseUrl)\n';
    }
  }

  @override
  Future<void> saveConfig(String yaml) async {
    final uri = Uri.parse('$baseUrl/config');
    final response = await _client
        .post(uri, body: yaml, headers: {'Content-Type': 'text/plain'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Sauvegarde config échouée: HTTP ${response.statusCode}');
    }
  }

  @override
  Future<void> backupConfig() async {
    final yaml = await getConfig();
    // Sauvegarde locale en mémoire — à étendre avec file_picker si besoin
    // ignore: avoid_print
    print('[FluidNCConfig] Backup: ${yaml.length} caractères');
  }

  @override
  Future<void> restoreConfig() async {
    // À implémenter avec file_picker pour sélectionner un fichier YAML local
    throw UnimplementedError('Restore config non implémenté');
  }
}
