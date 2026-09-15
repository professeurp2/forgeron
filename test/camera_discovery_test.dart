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
