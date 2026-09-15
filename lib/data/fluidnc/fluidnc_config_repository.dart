import 'dart:convert';
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
      final uri = Uri.parse('$baseUrl/config.yaml');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body;
        // Détection du Captive Portal (ESP32 non connecté au WiFi renvoie du HTML)
        if (body.trimLeft().startsWith('<HTML>') || body.trimLeft().startsWith('<!DOCTYPE html>')) {
          throw Exception('Captive Portal détecté (ESP32 en mode Point d\'Accès). Le fichier config.yaml est inaccessible.');
        }
        return body;
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      return '# FluidNC — Impossible de charger la configuration\n# Erreur: $e\n'
          '# Vérifiez la connexion à l\'ESP32 ($baseUrl)\n';
    }
  }

  @override
  Future<void> saveConfig(String yaml) async {
    // FluidNC (serveur ESP3D) n'accepte pas un POST texte simple sur
    // /config.yaml (« Connection closed while receiving data »). Le vrai
    // mécanisme d'upload est un POST multipart vers /files, avec le fichier
    // et sa taille (champ « <nom>S » attendu par ESP3D).
    final bytes = utf8.encode(yaml);
    final uri = Uri.parse('$baseUrl/files');
    final req = http.MultipartRequest('POST', uri)
      ..fields['path'] = '/'
      ..fields['config.yamlS'] = bytes.length.toString()
      ..files.add(http.MultipartFile.fromBytes(
        'config.yaml',
        bytes,
        filename: 'config.yaml',
      ));
    final streamed = await req.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Upload config échoué: HTTP ${response.statusCode}');
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

  void dispose() {
    _client.close();
  }
}

