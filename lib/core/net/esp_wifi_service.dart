import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Connexion assistée à l'AP WiFi de l'ESP32 depuis l'app (pont natif Android,
/// `WifiNetworkSpecifier`). Android affiche un dialogue d'approbation la
/// première fois ; ensuite l'app rejoint l'AP et s'y reconnecte automatiquement
/// (utile après un reboot de l'ESP32). No-op hors Android.
class EspWifiService {
  static const MethodChannel _channel = MethodChannel('forgeron/wifi');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Tente de rejoindre l'AP [ssid] (mot de passe [password], vide = ouvert).
  /// Retourne `true` si connecté. Message d'erreur via [EspWifiException].
  static Future<bool> connect(String ssid, String password) async {
    if (!isSupported) {
      throw const EspWifiException(
          'Connexion assistée disponible uniquement sur Android 10+.');
    }
    try {
      final ok = await _channel.invokeMethod<bool>('connect', {
        'ssid': ssid,
        'password': password,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      throw EspWifiException(_friendly(e));
    }
  }

  /// Se détache de l'AP (libère le binding réseau du process).
  static Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
  }

  static String _friendly(PlatformException e) {
    switch (e.code) {
      case 'unavailable':
        return 'Connexion refusée ou AP introuvable. Vérifie que l\'ESP32 est '
            'allumé et le SSID/mot de passe corrects.';
      case 'unsupported':
        return 'Android 10+ requis pour la connexion assistée.';
      default:
        return e.message ?? 'Échec de connexion WiFi (${e.code}).';
    }
  }
}

class EspWifiException implements Exception {
  final String message;
  const EspWifiException(this.message);
  @override
  String toString() => message;
}
