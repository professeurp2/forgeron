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
  Timer? _retryTimer;
  DateTime? _lastResponseTime;
  bool _disposed = false;

  // Suppression du buffer local car délégué au GCodeStreamingService (Task 3.3)

  FluidNCConnection(this.url);

  Stream<String> get messages => _messageController.stream;
  Stream<bool> get status => _statusController.stream;
  Stream<String> get traffic => _trafficController.stream;
  bool get isConnected => _isConnected;

  /// Tente une connexion avec Exponential Backoff
  Future<void> connect() async {
    if (_isConnected || _disposed) return;

    try {
      final uri = Uri.parse(url);
      debugPrint('[FluidNC] Connecting to $url (Attempt ${_retryCount + 1})...');
      
      // Tentative SANS sous-protocole (plus compatible)
      _channel = WebSocketChannel.connect(uri);
      
      // Timeout de 5 secondes pour le handshake
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('WebSocket handshake timeout after 5s');
        },
      );
      
      _onConnected();
    } catch (e) {
      debugPrint('[FluidNC] Connection failed: $e');
      _onConnectionFailed();
    }
  }

  void _onConnected() {
    _isConnected = true;
    _retryCount = 0;
    _statusController.add(true);
    _lastResponseTime = DateTime.now();
    debugPrint('[FluidNC] ✅ Connected to $url');

    _channel!.stream.listen(
      _handleIncomingMessage,
      onDone: () => _handleDisconnect('Connection closed by host'),
      onError: (e) => _handleDisconnect('Socket error: $e'),
    );

    _startHeartbeat();
  }

  void _onConnectionFailed() {
    if (_disposed) return;
    _isConnected = false;
    _statusController.add(false);

    // Exponential Backoff : 1s, 2s, 4s, 8s, 16s, puis 30s fixe.
    // On plafonne l'exposant à 5 pour éviter l'overflow de double→int
    // (math.pow(2, N).toInt() retourne 0 pour N>1023, ce qui causerait
    // une boucle de reconnexion frénétique épuisant les ports TCP).
    const int kMaxExponent = 5; // 2^5 = 32 > 30 → le min() capte à 30s
    final exponent = math.min(_retryCount, kMaxExponent);
    final delay = math.min(math.pow(2, exponent).toInt(), 30);
    _retryCount++;

    debugPrint('[FluidNC] ⏳ Retrying in ${delay}s... (attempt $_retryCount)');
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed) connect();
    });
  }

  void _handleIncomingMessage(dynamic message) {
    String msg;
    if (message is List<int>) {
      // L'ESP32 FluidNC envoie des frames binaires WebSocket — convertir en UTF-8
      msg = String.fromCharCodes(message).trim();
    } else {
      msg = message.toString().trim();
    }
    
    if (msg.isEmpty) return;
    _lastResponseTime = DateTime.now();
    debugPrint('[FluidNC RX] $msg');
    _trafficController.add('RX: $msg');
    
    // Détection des acquittements déléguée au GCodeStreamingService via le repository.
    _messageController.add(msg);
  }

  /// Système de Heartbeat pour détecter les "Zombies" (WiFi déconnecté sans fermeture de socket)
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isConnected || _disposed) {
        timer.cancel();
        return;
      }

      // Envoyer un '?' pour forcer un retour de statut
      sendRaw('?');

      // Si pas de réponse depuis plus de 10 secondes, on considère la connexion comme perdue
      if (_lastResponseTime != null && 
          DateTime.now().difference(_lastResponseTime!).inSeconds > 10) {
        _handleDisconnect('Heartbeat timeout (Dead connection)');
      }
    });
  }

  /// Envoi sécurisé via le StreamingService (pas de buffer local ici)
  void sendGCode(String gcode) {
    final cleanCmd = gcode.endsWith('\n') ? gcode : '$gcode\n';
    sendRaw(cleanCmd);
  }

  /// Envoi brut (pour commandes temps réel comme ?, !, ~)
  void sendRaw(String data) {
    if (_isConnected && _channel != null) {
      debugPrint('[FluidNC TX] $data');
      _trafficController.add('TX: $data');
      _channel!.sink.add(data);
    }
  }

  void _handleDisconnect(String reason) {
    if (!_isConnected && !_disposed) return; // Déjà déconnecté
    debugPrint('[FluidNC] ❌ Disconnected: $reason');
    _isConnected = false;
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    
    // Les buffers du streaming service seront réinitialisés par le repository.
    
    if (!_disposed) {
      _onConnectionFailed();
    }
  }

  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
    _trafficController.close();
  }
}

// Provider Riverpod pour la connexion
final fluidNCConnectionProvider = Provider.family<FluidNCConnection, String>((ref, url) {
  final connection = FluidNCConnection(url);
  ref.onDispose(() => connection.dispose());
  return connection;
});
