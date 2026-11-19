import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forgeron/application/services/auto_discovery_service.dart';
import 'package:forgeron/data/camera/esp32cam_repository.dart';

/// La caméra de surveillance et le contrôleur FluidNC répondent tous les deux
/// en HTTP sur le port 80, sur le même réseau. Les confondre est le pire
/// scénario du sous-système : le scan d'ouverture s'auto-connecte au premier
/// appareil trouvé, et l'opérateur croirait sa machine connectée alors que
/// l'application parle à un appareil sans moteurs.
///
/// Ces tests verrouillent la séparation dans les deux sens.
void main() {
  http.Client clientReturning(String body, {Map<String, String>? headers}) {
    return MockClient((_) async => http.Response(body, 200, headers: headers ?? const {}));
  }

  group('AutoDiscoveryService — la caméra n\'est jamais un contrôleur', () {
    test('rejette un appareil qui s\'annonce caméra par en-tête', () async {
      final service = AutoDiscoveryService(
        client: clientReturning('<html>peu importe</html>',
            headers: {'x-forgeron-device': 'camera'}),
      );

      expect(await service.probeIp('192.168.0.50'), isNull);
    });

    test('rejette aussi via le marqueur de la page, sans en-tête', () async {
      final service = AutoDiscoveryService(
        client: clientReturning(
            '<!doctype html><meta name=forgeron-device content=camera>'
            '<h3>Forgeron — camera d\'usinage</h3>'),
      );

      expect(await service.probeIp('192.168.0.50'), isNull);
    });

    test('accepte bien un vrai FluidNC', () async {
      final service = AutoDiscoveryService(
        client: clientReturning('<html><title>FluidNC Web UI</title></html>'),
      );

      final device = await service.probeIp('192.168.0.1');
      expect(device, isNotNull);
      expect(device!.firmwareInfo, 'FluidNC');
    });
  });

  group('AutoDiscoveryService — répondre en HTTP ne fait pas un contrôleur', () {
    /// La page d'accueil, et ce que l'appareil répond à `/command?plain=$I`.
    http.Client device(String home, {String? command}) {
      return MockClient((request) async {
        if (request.url.path == '/command') {
          expect(request.url.queryParameters['plain'], r'$I');
          return command == null
              ? http.Response('Not found', 404)
              : http.Response(command, 200);
        }
        return http.Response(home, 200);
      });
    }

    test('refuse le portail captif d\'une box', () async {
      final service = AutoDiscoveryService(
        client: device('<title>Error 302: Hotspot redirect</title>'),
      );
      expect(await service.probeIp('192.168.88.1'), isNull);
    });

    test('refuse un appareil qui répond 200 à tout sans se nommer', () async {
      const page = '<html>Administration du routeur</html>';
      final service = AutoDiscoveryService(client: device(page, command: page));
      expect(await service.probeIp('192.168.88.1'), isNull);
    });

    test('le mot esp32 ou webui ne suffit plus', () async {
      final service = AutoDiscoveryService(client: device('<html>ESP32 WebUI</html>'));
      expect(await service.probeIp('192.168.1.40'), isNull);
    });

    test('accepte une interface muette qui répond FluidNC à \$I', () async {
      final service = AutoDiscoveryService(
        client: device(
          '<html><script src=app.js></script></html>',
          command: '[VER:3.9 FluidNC v3.9.5:]\n[OPT:VNMH]\nok\n',
        ),
      );
      final found = await service.probeIp('192.168.0.1');
      expect(found?.firmwareInfo, 'FluidNC');
    });

    test('un réseau muet à \$I ne bloque pas le refus', () async {
      final service = AutoDiscoveryService(
        client: MockClient((request) async => request.url.path == '/command'
            ? throw Exception('coupé')
            : http.Response('<html></html>', 200)),
      );
      expect(await service.probeIp('192.168.1.40'), isNull);
    });
  });

  group('Esp32CamRepository — le contrôleur n\'est jamais une caméra', () {
    test('un 200 seul ne suffit pas à identifier une caméra', () async {
      // Exactement ce que renverrait un appareil quelconque du réseau : sans
      // preuve, on refuse.
      final repo = Esp32CamRepository('192.168.0.1',
          client: clientReturning('<html>FluidNC</html>'));

      expect(await repo.ping(), isFalse);
    });

    test('reconnaît la caméra à son en-tête', () async {
      final repo = Esp32CamRepository('192.168.0.50',
          client: clientReturning('{}',
              headers: {'x-forgeron-device': 'camera'}));

      expect(await repo.ping(), isTrue);
    });

    test('reconnaît un firmware ancien à la forme de son /status', () async {
      // Le premier firmware flashé ne posait pas encore l'en-tête : la forme
      // du JSON reste une preuve suffisante, FluidNC n'en produit pas de tel.
      final repo = Esp32CamRepository('192.168.0.50',
          client: clientReturning(
              '{"framesize":8,"quality":12,"led_intensity":0,"rssi":-65}'));

      expect(await repo.ping(), isTrue);
    });

    test('une caméra injoignable ne lève pas', () async {
      final repo = Esp32CamRepository('192.168.0.50',
          client: MockClient((_) async => throw Exception('pas de route')));

      expect(await repo.ping(), isFalse);
    });
  });
}
