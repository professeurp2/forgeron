import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FluidNCConnection {
  final String url;
  WebSocketChannel? _channel;
  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  Timer? _reconnectTimer;

  FluidNCConnection(this.url);

  Stream<String> get messages => _messageController.stream;
  Stream<bool> get status => _statusController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    if (_isConnected) return;
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _isConnected = true;
      _statusController.add(true);
      _reconnectTimer?.cancel();

      _channel!.stream.listen(
        (message) {
          _messageController.add(message.toString());
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket Connection Error: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _statusController.add(false);
    _channel?.sink.close();
    
    // Auto-reconnect after 3 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  void send(String data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(data);
    } else {
      debugPrint('Cannot send data, WebSocket is disconnected');
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _isConnected = false;
    _statusController.add(false);
    _channel?.sink.close();
  }
}
