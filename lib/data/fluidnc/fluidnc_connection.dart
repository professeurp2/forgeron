import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Gestionnaire de connexion robuste pour FluidNC (Industrial Grade).
/// Gère : 
///  - Exponential Backoff pour la résilience réseau.
///  - Heartbeat (Ping/Pong) via la commande '?' de GRBL.
///  - Backpressure via un compteur d'octets précis (Buffer RX de 128 octets).
class FluidNCConnection {
  final String url;
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final _trafficController = StreamController<String>.broadcast();
  
  bool _isConnected = false;
  int _retryCount = 0;
  Timer? _heartbeatTimer;
  DateTime? _lastResponseTime;

  // Configuration Buffer (Backpressure)
  static const int maxBufferSize = 127;
  int _currentBufferSize = 0;
  final List<int> _sentLengths = [];
  final List<String> _pendingQueue = [];

  FluidNCConnection(this.url);

  Stream<String> get messages => _messageController.stream;
  Stream<bool> get status => _statusController.stream;
  Stream<String> get traffic => _trafficController.stream;
  bool get isConnected => _isConnected;

  /// Tente une connexion avec Exponential Backoff
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final uri = Uri.parse(url);
      debugPrint('Connecting to FluidNC at $url (Attempt ${_retryCount + 1})...');
      
      _channel = WebSocketChannel.connect(uri, protocols: ['arduino']);
      
      // Attendre un premier message ou timeout
      await _channel!.ready;
      
      _onConnected();
    } catch (e) {
      _onConnectionFailed();
    }
  }

  void _onConnected() {
    _isConnected = true;
    _retryCount = 0;
    _statusController.add(true);
    _lastResponseTime = DateTime.now();

    _channel!.stream.listen(
      _handleIncomingMessage,
      onDone: () => _handleDisconnect('Connection closed by host'),
      onError: (e) => _handleDisconnect('Socket error: $e'),
    );

    _startHeartbeat();
  }

  void _onConnectionFailed() {
    _isConnected = false;
    _statusController.add(false);
    
    // Exponential Backoff : 1s, 2s, 4s, 8s... max 30s
    final delay = math.min(math.pow(2, _retryCount).toInt(), 30);
    _retryCount++;
    
    debugPrint('Connection failed. Retrying in ${delay}s...');
    Future.delayed(Duration(seconds: delay), connect);
  }

  void _handleIncomingMessage(dynamic message) {
    final msg = message.toString();
    _lastResponseTime = DateTime.now();
    _trafficController.add('RX: $msg');
    
    // Détection des acquittements pour la gestion du buffer
    if (msg.trim() == 'ok' || msg.startsWith('error:')) {
      if (_sentLengths.isNotEmpty) {
        _currentBufferSize -= _sentLengths.removeAt(0);
        _processQueue(); // Libérer de la place pour les suivantes
      }
    }

    _messageController.add(msg);
  }

  /// Système de Heartbeat pour détecter les "Zombies" (WiFi déconnecté sans fermeture de socket)
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      // Envoyer un '?' pour forcer un retour de statut
      sendRaw('?');

      // Si pas de réponse depuis plus de 5 secondes, on considère la connexion comme perdue
      if (_lastResponseTime != null && 
          DateTime.now().difference(_lastResponseTime!).inSeconds > 5) {
        _handleDisconnect('Heartbeat timeout (Dead connection)');
      }
    });
  }

  /// Envoi sécurisé avec gestion du buffer RX FluidNC (Backpressure)
  void sendGCode(String gcode) {
    final cleanCmd = gcode.endsWith('\n') ? gcode : '$gcode\n';
    _pendingQueue.add(cleanCmd);
    _processQueue();
  }

  void _processQueue() {
    while (_pendingQueue.isNotEmpty) {
      final cmd = _pendingQueue.first;
      final len = cmd.length;

      if (_currentBufferSize + len <= maxBufferSize) {
        _pendingQueue.removeAt(0);
        _currentBufferSize += len;
        _sentLengths.add(len);
        sendRaw(cmd);
      } else {
        break; // Buffer plein, on attend un 'ok'
      }
    }
  }

  /// Envoi brut (pour commandes temps réel comme ?, !, ~)
  void sendRaw(String data) {
    if (_isConnected && _channel != null) {
      _trafficController.add('TX: $data');
      _channel!.sink.add(data);
    }
  }

  void _handleDisconnect(String reason) {
    debugPrint('Disconnected: $reason');
    _isConnected = false;
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _onConnectionFailed();
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}

// Provider Riverpod pour la connexion
final fluidNCConnectionProvider = Provider.family<FluidNCConnection, String>((ref, url) {
  final connection = FluidNCConnection(url);
  ref.onDispose(() => connection.dispose());
  return connection;
});
