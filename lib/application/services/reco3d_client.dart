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
  String toString() =>
      'Reco3dClientException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
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

  /// Recherche automatique du serveur reco3d sur le réseau local (port 8765).
  Future<String?> discoverServer({
    Duration timeout = const Duration(milliseconds: 600),
    int concurrency = 25,
  }) async {
    // 1. Cibles rapides et fiables (mDNS, IP active du PC, hotspot Windows, localhost)
    final fastCandidates = [
      'http://192.168.88.58:8765',
      'http://192.168.88.94:8765',
      'http://DESKTOP-24IDAFU.local:8765',
      'http://desktop-24idafu:8765',
      'http://192.168.137.1:8765',
      'http://127.0.0.1:8765',
      'http://10.0.2.2:8765',
    ];

    for (final url in fastCandidates) {
      try {
        final resp = await _client
            .get(Uri.parse('$url/health'))
            .timeout(const Duration(milliseconds: 600));
        if (resp.statusCode == 200 &&
            (resp.body.contains('"status"') || resp.body.contains('"engines"'))) {
          return url;
        }
      } catch (_) {}
    }

    // 2. Découverte instantanée via Broadcast UDP (port 8766)
    try {
      final udpResult = await _discoverViaUdp();
      if (udpResult != null) return udpResult;
    } catch (_) {}

    // 3. Balayage des sous-réseaux locaux IPv4
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;
          final parts = ip.split('.');
          if (parts.length != 4) continue;
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

          final candidates = <String>[
            'http://$prefix.58:8765',
            'http://$prefix.94:8765',
            'http://$prefix.35:8765',
            'http://$prefix.104:8765',
            'http://$prefix.1:8765',
            'http://$ip:8765',
          ];

          for (int i = 1; i <= 254; i++) {
            final candidate = 'http://$prefix.$i:8765';
            if (!candidates.contains(candidate)) {
              candidates.add(candidate);
            }
          }

          for (int i = 0; i < candidates.length; i += concurrency) {
            final batch = candidates.sublist(i, (i + concurrency).clamp(0, candidates.length));
            final futures = batch.map((url) async {
              try {
                final resp = await _client.get(Uri.parse('$url/health')).timeout(timeout);
                if (resp.statusCode == 200 &&
                    (resp.body.contains('"status"') || resp.body.contains('"engines"'))) {
                  return url;
                }
              } catch (_) {}
              return null;
            });
            final results = await Future.wait(futures);
            for (final res in results) {
              if (res != null) return res;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _discoverViaUdp() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final data = utf8.encode('FORGERON_DISCOVER');
      socket.send(data, InternetAddress('255.255.255.255'), 8766);

      final completer = Completer<String?>();
      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket.receive();
          if (dg != null) {
            final msg = utf8.decode(dg.data, allowMalformed: true);
            if (msg.contains('FORGERON_RECO3D')) {
              if (!completer.isCompleted) {
                completer.complete('http://${dg.address.address}:8765');
              }
            }
          }
        }
      });

      final res = await completer.future.timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      await sub.cancel();
      socket.close();
      return res;
    } catch (_) {
      return null;
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

  /// Démarre un scan EN MACHINE : le serveur commande la rotation des axes
  /// A/C par angles connus et capture via les caméras embarquées (doc §12,
  /// jalon 5). Renvoie un job suivi comme les autres (getJobStatus / pollUntilDone
  /// / downloadResult).
  ///
  /// Le backend `/scan` reste à implémenter côté serveur reco3d : en son absence
  /// le serveur répond 404 et on le signale explicitement plutôt que d'échouer
  /// en silence.
  Future<Reco3dJobCreated> startMachineScan({
    required Uri baseUri,
    required int poses,
    required double aDeg,
    String? cameraUrl,
    bool synthetic = false,
  }) async {
    final url = baseUri.replace(path: '/scan');
    try {
      final res = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'poses': poses,
              'a_deg': aDeg,
              if (cameraUrl != null && cameraUrl.isNotEmpty) 'camera_url': cameraUrl,
              if (synthetic) 'synthetic': true,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        throw const Reco3dClientException(
          'Endpoint /scan absent : le backend de scan en machine (jalon 5) '
          'n\'est pas encore branché sur ce serveur reco3d.',
          404,
        );
      }
      if (res.statusCode != 202) {
        throw Reco3dClientException('Échec du démarrage du scan : ${res.body}', res.statusCode);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return Reco3dJobCreated.fromJson(json);
    } catch (e) {
      if (e is Reco3dClientException) rethrow;
      throw Reco3dClientException('Erreur réseau au démarrage du scan en machine : $e');
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
