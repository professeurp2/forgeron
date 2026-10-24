import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models/reco3d_models.dart';

class Reco3dClientException implements Exception {
  const Reco3dClientException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => 'Reco3dClientException: $message' + (statusCode != null ? ' (HTTP $statusCode)' : '');
}

/// Client HTTP pour communiquer avec le service local `reco3d` (FastAPI sur PC GPU).
///
/// Permet à l'application mobile ou desktop Forgeron de téléverser les photos,
/// suivre la file d'attente GPU, vérifier la provenance et récupérer le maillage/STEP.
class Reco3dClient {
  Reco3dClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Vérifie la disponibilité du service reco3d et l'état du GPU.
  Future<Reco3dHealth> checkHealth(Uri baseUri) async {
    final url = baseUri.replace(path: '/health');
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        throw Reco3dClientException('Service indisponible', res.statusCode);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return Reco3dHealth.fromJson(json);
    } catch (e) {
      if (e is Reco3dClientException) rethrow;
      throw Reco3dClientException('Impossible de joindre reco3d sur $baseUri : $e');
    }
  }

  /// Soumet un lot de photos ou une image conceptuelle.
  Future<Reco3dJobCreated> createJob({
    required Uri baseUri,
    required String mode, // 'photo' ou 'gen'
    String scaleType = 'none',
    double? scaleMm,
    required List<File> photos,
  }) async {
    if (photos.isEmpty) {
      throw const Reco3dClientException('Au moins une photo est requise');
    }

    final url = baseUri.replace(path: '/jobs');
    final request = http.MultipartRequest('POST', url);
    request.fields['mode'] = mode;
    request.fields['scale_type'] = scaleType;
    if (scaleMm != null && scaleMm > 0) {
      request.fields['scale_mm'] = scaleMm.toString();
    }

    for (final photo in photos) {
      if (!photo.existsSync()) {
        throw Reco3dClientException('Fichier introuvable : ${photo.path}');
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'photos',
          photo.path,
        ),
      );
    }

    try {
      final streamedRes = await _client.send(request).timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode != 202) {
        throw Reco3dClientException('Échec de soumission du job : ${res.body}', res.statusCode);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return Reco3dJobCreated.fromJson(json);
    } catch (e) {
      if (e is Reco3dClientException) rethrow;
      throw Reco3dClientException('Erreur réseau lors de l\'envoi des photos : $e');
    }
  }

  /// Récupère l'état et la progression d'un job.
  Future<Reco3dJobStatus> getJobStatus(Uri baseUri, String jobId) async {
    final url = baseUri.replace(path: '/jobs/$jobId');
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 404) {
        throw Reco3dClientException('Job $jobId introuvable', 404);
      }
      if (res.statusCode != 200) {
        throw Reco3dClientException('Erreur lecture statut', res.statusCode);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return Reco3dJobStatus.fromJson(json);
    } catch (e) {
      if (e is Reco3dClientException) rethrow;
      throw Reco3dClientException('Erreur de communication : $e');
    }
  }

  /// Télécharge le fichier résultat (format 'mesh' pour STL/OBJ ou 'step').
  Future<File> downloadResult(
    Uri baseUri,
    String jobId, {
    String format = 'mesh',
    required File destination,
  }) async {
    final url = baseUri.replace(
      path: '/jobs/$jobId/result',
      queryParameters: {'format': format},
    );
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 120));
      if (res.statusCode != 200) {
        throw Reco3dClientException('Fichier résultat non disponible : ${res.body}', res.statusCode);
      }
      if (!destination.parent.existsSync()) {
        destination.parent.createSync(recursive: true);
      }
      await destination.writeAsBytes(res.bodyBytes);
      return destination;
    } catch (e) {
      if (e is Reco3dClientException) rethrow;
      throw Reco3dClientException('Erreur de téléchargement du résultat 3D : $e');
    }
  }

  /// Télécharge la fiche de provenance officielle du job.
  Future<Reco3dProvenance> getProvenance(Uri baseUri, String jobId) async {
    final url = baseUri.replace(path: '/jobs/$jobId/provenance');
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        throw Reco3dClientException('Provenance non disponible : ${res.body}', res.statusCode);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return Reco3dProvenance.fromJson(json);
    } catch (e) {
      if (e is Reco3dClientException) rethrow;
      throw Reco3dClientException('Erreur récupération provenance : $e');
    }
  }

  /// Scrute l'avancement d'un job jusqu'à achèvement ou échec.
  Future<Reco3dJobStatus> pollUntilDone(
    Uri baseUri,
    String jobId, {
    Duration pollInterval = const Duration(seconds: 1),
    void Function(Reco3dJobStatus status)? onProgress,
  }) async {
    while (true) {
      final status = await getJobStatus(baseUri, jobId);
      if (onProgress != null) {
        onProgress(status);
      }
      if (status.stage == 'done') {
        return status;
      }
      if (status.stage == 'failed') {
        final errorMsg = status.error ?? (status.message.isNotEmpty ? status.message : 'Échec de reconstruction');
        throw Reco3dClientException(errorMsg);
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  void close() {
    _client.close();
  }
}
