import 'dart:typed_data';

/// Résolutions utiles de l'OV2640. Les valeurs sont celles de l'énum
/// `framesize_t` du firmware ESP32, passées telles quelles à
/// `/control?var=framesize`.
enum CameraResolution {
  qvga(5, '320x240'),
  vga(8, '640x480'),
  svga(9, '800x600'),
  xga(10, '1024x768'),
  uxga(13, '1600x1200');

  const CameraResolution(this.value, this.label);

  final int value;
  final String label;
}

/// Accès à la caméra de surveillance (ESP32-CAM AI-Thinker + OV2640).
///
/// La caméra est un **second** ESP32, totalement indépendant de celui qui
/// porte FluidNC : elle se contente de rejoindre le point d'accès WiFi de la
/// machine. Aucun appel de cette interface ne touche au contrôleur.
///
/// Règle de conception : une caméra morte, injoignable ou lente ne doit
/// JAMAIS perturber l'usinage. Toutes les méthodes sauf [snapshot] avalent
/// leurs erreurs, et [snapshot] est toujours appelée hors du chemin critique
/// du streaming G-code.
abstract class CameraRepository {
  /// Capture une image fixe (JPEG). Lève en cas d'échec réseau.
  Future<Uint8List> snapshot();

  /// URL du flux MJPEG continu, à donner à un lecteur d'image.
  ///
  /// ⚠️ Sur l'AP de la machine ce flux partage la radio 2,4 GHz avec le
  /// streaming G-code. Il ne doit pas être ouvert pendant une passe : voir
  /// `cameraLiveAllowedProvider`.
  String get streamUrl;

  /// Vrai si la caméra répond. Ne lève jamais.
  Future<bool> ping();

  /// Change la résolution du capteur. Sans effet si la caméra ne répond pas.
  Future<void> setResolution(CameraResolution resolution);

  /// Règle la compression JPEG (10 = meilleure qualité, 63 = plus comprimé).
  ///
  /// C'est le levier de cadence : sur l'AP de la machine, ce qui limite le
  /// nombre d'images par seconde n'est pas le débit mais le **temps d'antenne**
  /// occupé par chaque trame. Comprimer davantage pendant un usinage rend
  /// l'image plus fluide *et* moins gênante pour le contrôleur.
  ///
  /// Retourne `false` si le réglage n'a pas pu être posé, pour que l'appelant
  /// puisse réessayer plutôt que de croire la caméra alignée.
  Future<bool> setQuality(int quality);

  /// Allume/éteint la LED blanche (GPIO4). Tous les firmwares ne l'exposent
  /// pas : l'échec est silencieux.
  Future<void> setFlash(bool on);

  void dispose();
}
