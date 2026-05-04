import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/models/gcode_file.dart';
import '../../domain/repositories/file_repository.dart';

/// Client HTTP réel pour l'API FluidNC (ESP32)
///
/// Endpoints FluidNC :
///   GET  /files?path=/           -> liste JSON des fichiers SD
///   GET  /sd/filename            -> téléchargement d'un fichier
///   POST /upload?path=/sd/       -> upload multipart
///   DELETE /files?path=/sd/file  -> suppression
class FluidNcHttpClient implements FileRepository {
  final String baseUrl; // ex: "http://192.168.1.100"
  final http.Client _client;

  FluidNcHttpClient(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  // ── Liste des fichiers ────────────────────────────────────────────────────
  @override
  Future<List<GCodeFile>> listFiles({String path = '/'}) async {
    try {
      final uri = Uri.parse('$baseUrl/files').replace(
        queryParameters: {'path': path},
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      // Format FluidNC : {"files": [{"name": "file.nc", "size": 1234}], "path": "/"}
      final List<dynamic> files = decoded['files'] as List<dynamic>? ?? [];

      return files.map((f) {
        final name = f['name'] as String? ?? 'unknown';
        final size = (f['size'] as num?)?.toInt() ?? 0;
        return GCodeFile(name: name, size: size, lines: 0);
      }).toList();
    } catch (e) {
      // En cas d'erreur réseau, retourner liste vide
      return [];
    }
  }

  // ── Lecture d'un fichier ──────────────────────────────────────────────────
  @override
  Future<String> readFile(String path) async {
    final url = path.startsWith('/sd/')
        ? '$baseUrl$path'
        : '$baseUrl/sd/$path';
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Lecture fichier échouée: HTTP ${response.statusCode}');
    }
    return response.body;
  }

  // ── Upload d'un fichier ───────────────────────────────────────────────────
  @override
  Future<void> uploadFile(String path, List<int> bytes) async {
    final uri = Uri.parse('$baseUrl/upload').replace(
      queryParameters: {'path': '/sd/'},
    );

    final request = http.MultipartRequest('POST', uri);
    final filename = path.split('/').last;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        Uint8List.fromList(bytes),
        filename: filename,
      ),
    );

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload échoué: HTTP ${response.statusCode}');
    }
  }

  // ── Suppression d'un fichier ──────────────────────────────────────────────
  @override
  Future<void> deleteFile(String path) async {
    final uri = Uri.parse('$baseUrl/files').replace(
      queryParameters: {'path': '/sd/$path'},
    );
    final response = await _client
        .delete(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Suppression échouée: HTTP ${response.statusCode}');
    }
  }

  void dispose() => _client.close();
}
