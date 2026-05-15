import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  final urls = [
    'ws://192.168.137.200:81/',
    'ws://192.168.137.200:80/ws',
    'ws://192.168.137.200:80/',
    'ws://192.168.137.200:8080/'
  ];

  for (final url in urls) {
    try {
      print('Testing \$url ...');
      final c = WebSocketChannel.connect(Uri.parse(url));
      await c.ready.timeout(Duration(seconds: 2));
      print('SUCCESS: \$url');
      c.sink.close();
      return;
    } catch (e) {
      print('FAILED: \$url - \$e');
    }
  }
}
