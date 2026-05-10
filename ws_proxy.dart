import 'dart:io';

void main() async {
  final espIp = '192.168.2.50';
  final espPort = 80;
  final localPort = 8081;

  print('Starting WebSocket Proxy on ws://127.0.0.1:$localPort -> ws://$espIp:$espPort');

  final server = await HttpServer.bind('127.0.0.1', localPort);
  print('Proxy listening...');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final localWs = await WebSocketTransformer.upgrade(request);
        print('Client connected to proxy!');

        // Connect to ESP32 without Origin header
        final espWs = await WebSocket.connect('ws://$espIp:$espPort', protocols: ['arduino']);
        print('Proxy connected to ESP32!');

        // Forward ESP32 -> Client
        espWs.listen(
          (data) => localWs.add(data),
          onDone: () {
            print('ESP32 closed connection');
            localWs.close();
          },
          onError: (e) => print('ESP32 Error: $e'),
        );

        // Forward Client -> ESP32
        localWs.listen(
          (data) => espWs.add(data),
          onDone: () {
            print('Client closed connection');
            espWs.close();
          },
          onError: (e) => print('Client Error: $e'),
        );
      } catch (e) {
        print('Proxy Error: $e');
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      }
    } else {
      // CORS for HTTP
      request.response
        ..headers.add('Access-Control-Allow-Origin', '*')
        ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        ..headers.add('Access-Control-Allow-Headers', '*')
        ..statusCode = HttpStatus.ok
        ..close();
    }
  }
}
