import 'dart:io';

void main() async {
  final urls = [
    'ws://192.168.2.50:80',
    'ws://192.168.2.50:81',
    'ws://192.168.2.50:80/ws',
    'ws://192.168.2.50:81/ws'
  ];

  for (final url in urls) {
    print('\nTesting WebSocket: $url without protocols');
    try {
      final ws = await WebSocket.connect(url).timeout(Duration(seconds: 3));
      print('✅ SUCCESS: Connected to $url without protocols');
      ws.close();
    } catch (e) {
      print('❌ FAILED: $e');
    }

    print('\nTesting WebSocket: $url with protocol [arduino]');
    try {
      final ws = await WebSocket.connect(url, protocols: ['arduino']).timeout(Duration(seconds: 3));
      print('✅ SUCCESS: Connected to $url with protocol [arduino]');
      ws.close();
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }
}
