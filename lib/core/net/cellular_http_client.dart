import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Client HTTP qui force la requête sur le réseau **cellulaire** (4G/5G) via un
/// pont natif Android, pendant que le WiFi reste dédié à l'ESP32/FluidNC.
///
/// Cas d'usage : le téléphone est joint à l'AP WiFi de l'ESP32 (sans Internet).
/// Les appels de l'IA passeraient dans le vide → on les redirige par les
/// données mobiles au niveau socket (côté natif, cf. MainActivity.kt).
///
/// Hors Android (Windows, web, tests), délègue à un [http.Client] standard :
/// le comportement est alors identique à avant.
class CellularHttpClient extends http.BaseClient {
  static const MethodChannel _channel = MethodChannel('forgeron/cellular');

  final http.Client _fallback;

  CellularHttpClient({http.Client? fallback})
      : _fallback = fallback ?? http.Client();

  bool get _useNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_useNative) return _fallback.send(request);

    final bodyBytes = await request.finalize().toBytes();
    // La charge utile de l'IA est du JSON UTF-8 → transport en texte.
    final bodyText = bodyBytes.isEmpty ? null : utf8.decode(bodyBytes);

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'httpRequest',
        {
          'method': request.method,
          'url': request.url.toString(),
          'headers': request.headers,
          'body': bodyText,
          'timeoutMs': 60000,
        },
      );

      if (res == null) {
        throw const CellularNetworkException('Réponse native vide.');
      }
      final status = (res['statusCode'] as num).toInt();
      final respBody = (res['body'] as String?) ?? '';
      final bytes = utf8.encode(respBody);

      return http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        status,
        contentLength: bytes.length,
        request: request,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    } on MissingPluginException {
      // Canal absent (ancien build sans la partie native) → repli WiFi.
      return _fallback.send(request);
    } on PlatformException catch (e) {
      throw CellularNetworkException(_friendlyMessage(e));
    }
  }

  String _friendlyMessage(PlatformException e) {
    final msg = e.message ?? '';
    switch (e.code) {
      case 'cellular_unavailable':
        return 'Pas de données mobiles. Active la 4G/5G (et garde-les allumées '
            'en plus du WiFi de l\'ESP32) pour que l\'IA fonctionne.';
      case 'http_error':
        // DNS pas encore prêt : la 4G vient de monter, résolution impossible.
        if (msg.contains('resolve host') ||
            msg.contains('No address associated') ||
            msg.contains('UnknownHost')) {
          return 'Réseau mobile pas encore prêt (DNS). Nouvelle tentative '
              'automatique dans un instant…';
        }
        if (msg.contains('timed out') || msg.contains('timeout')) {
          return 'Le service IA met trop de temps à répondre. Nouvelle tentative '
              'automatique dès que possible…';
        }
        return 'Échec réseau cellulaire : $msg';
      default:
        return msg.isEmpty ? 'Erreur réseau cellulaire (${e.code}).' : msg;
    }
  }

  @override
  void close() {
    _fallback.close();
    super.close();
  }
}

/// Erreur remontée quand la requête IA n'a pas pu passer par la 4G/5G.
class CellularNetworkException implements Exception {
  final String message;
  const CellularNetworkException(this.message);
  @override
  String toString() => message;
}

/// Flux SSE (streamGenerateContent) routé sur la 4G/5G via un EventChannel natif.
class CellularSse {
  static const EventChannel _streamChannel =
      EventChannel('forgeron/cellular_stream');

  /// Disponible uniquement sur Android (le pont natif y expose l'EventChannel).
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Émet chaque payload JSON d'une ligne `data:` du flux SSE. Termine à la fin
  /// du flux ; propage une erreur de plateforme en cas d'échec réseau/HTTP.
  static Stream<String> stream({
    required String url,
    required Map<String, String> headers,
    required String body,
    int timeoutMs = 120000,
  }) {
    return _streamChannel.receiveBroadcastStream({
      'method': 'POST',
      'url': url,
      'headers': headers,
      'body': body,
      'timeoutMs': timeoutMs,
    }).map((e) => e as String);
  }
}

/// Sonde l'état du réseau cellulaire, indépendamment d'une requête.
class CellularNetwork {
  static const MethodChannel _channel = MethodChannel('forgeron/cellular');

  /// `true` si les données mobiles (4G/5G) sont disponibles pour router l'IA.
  ///
  /// Hors Android (Windows, web) : retourne `true` (aucune contrainte de
  /// réseau cellulaire, on ne bloque pas l'envoi). En cas de canal absent
  /// (ancien build), retourne aussi `true` pour ne pas empêcher l'usage.
  static Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('isCellularAvailable');
      return ok ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
