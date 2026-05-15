import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  final urls = [
    'ws://192.168.137.200:81/',
    'ws://192.168.137.200:80/ws',
    'ws://192.168.137.200:80/'
  ];

  for (var u in urls) {
    try {
      print('Test ' + u);
      final c = WebSocketChannel.connect(Uri.parse(u));
      await c.ready.timeout(Duration(seconds: 2));
      print('SUCCESS ' + u);
      c.sink.close();
    } catch (e) {
      print('FAIL ' + u + ': ' + e.toString());
    }
  }
}
