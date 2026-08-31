import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/repositories/camera_repository.dart';

/// Implémentation pour le firmware `CameraWebServer` standard de l'ESP32-CAM
/// AI-Thinker (celui livré dans les exemples du core ESP32 Arduino).
///
/// Endpoints exposés par ce croquis :
///   GET /capture              -> une image JPEG            (port 80)
///   GET /status               -> réglages capteur en JSON  (port 80)
///   GET /control?var=X&val=Y  -> modifie un réglage        (port 80)
///   GET /stream               -> flux MJPEG                (port **81**)
///
/// Le flux vit bien sur un port différent du reste : c'est une particularité
/// du croquis d'origine, pas une erreur de configuration.
class Esp32CamRepository implements CameraRepository {
  Esp32CamRepository(
    this.host, {
    this.httpPort = 80,
    this.streamPort = 81,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String host;
  final int httpPort;
  final int streamPort;
  final http.Client _client;

  String get _base => 'http://$host:$httpPort';

  @override
  String get streamUrl => 'http://$host:$streamPort/stream';

  // ── Capture ───────────────────────────────────────────────────────────────

  @override
  Future<Uint8List> snapshot() async {
    // Anti-cache : sans ce paramètre certains clients HTTP resservent la même
    // image, ce qui est le pire des comportements pour une surveillance.
    final uri = Uri.parse(
      '$_base/capture?_cb=${DateTime.now().microsecondsSinceEpoch}',
    );

    final response = await _client.get(uri).timeout(
          // L'ESP32-CAM peut mettre plusieurs secondes en UXGA, surtout si
          // l'AP est occupé par le streaming G-code.
          const Duration(seconds: 8),
        );

    if (response.statusCode != 200) {
      throw Exception('Capture caméra échouée : HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.isEmpty) {
      throw Exception('Capture caméra vide (caméra mal initialisée ?)');
    }
    return response.bodyBytes;
  }

  // ── Disponibilité ─────────────────────────────────────────────────────────

  /// Identification **positive** : ne suffit pas qu'un appareil réponde, il
  /// doit prouver qu'il est bien la caméra.
  ///
  /// Le contrôleur FluidNC répond lui aussi en HTTP sur le port 80. Se
  /// contenter d'un « 200 OK » exposerait au scénario inverse de celui que
  /// filtre [AutoDiscoveryService] : l'application prendrait le contrôleur
  /// pour une caméra et lui enverrait des requêtes de capture en boucle
  /// pendant un usinage.
  ///
  /// Deux preuves acceptées, car le firmware caméra a existé sans l'en-tête :
  ///   - l'en-tête `X-Forgeron-Device: camera` (firmware courant) ;
  ///   - un `/status` à la forme caméra, que FluidNC ne produit pas.
  @override
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(Uri.parse('$_base/status'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return false;

      final kind = response.headers['x-forgeron-device']?.toLowerCase();
      if (kind == 'camera') return true;

      return response.body.contains('framesize');
    } catch (_) {
      return false;
    }
  }

  // ── Réglages ──────────────────────────────────────────────────────────────

  @override
  Future<void> setResolution(CameraResolution resolution) =>
      _control('framesize', resolution.value);

  @override
  Future<bool> setQuality(int quality) =>
      _control('quality', quality.clamp(10, 63));

  @override
  Future<void> setFlash(bool on) => _control('led_intensity', on ? 255 : 0);

  /// Un réglage raté n'est jamais bloquant : on veut au pire une image moche,
  /// pas une exception qui remonte dans l'UI pendant un usinage. L'échec est
  /// donc *retourné*, jamais levé — à l'appelant de décider s'il réessaie.
  Future<bool> _control(String variable, int value) async {
    try {
      final response = await _client
          .get(Uri.parse('$_base/control?var=$variable&val=$value'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() => _client.close();
}
