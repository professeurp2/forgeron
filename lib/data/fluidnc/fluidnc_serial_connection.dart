import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'fluidnc_connection.dart';

/// Métadonnées légères d'un port série détecté sur le système.
class SerialPortInfo {
  final String name;
  final String? description;
  final String? manufacturer;

  const SerialPortInfo({
    required this.name,
    this.description,
    this.manufacturer,
  });

  String get displayLabel {
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) return '$name — $desc';
    return name;
  }
}

/// Transport série USB (UART / CDC) implémentant l'interface [FluidNCConnection].
///
/// Permet de piloter FluidNC directement par câble USB (ex: COM5 à 115200 bauds)
/// avec la même sémantique que le WebSocket :
///  - Découpage ligne par ligne (`\n`) des paquets USB fragmentés.
///  - Heartbeat `?` temps réel et détection de déconnexion.
///  - Reconnexion automatique avec backoff exponentiel si le câble est rebranché.
class FluidNCSerialConnection implements FluidNCConnection {
  final String portName;
  final int baudRate;

  @override
  String get url => 'usb://$portName@$baudRate';

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSub;

  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final _trafficController = StreamController<String>.broadcast();
  final StringBuffer _lineBuffer = StringBuffer();

  bool _isConnected = false;
  bool _connecting = false;
  int _retryCount = 0;
  Timer? _heartbeatTimer;
  Timer? _retryTimer;
  DateTime? _lastResponseTime;
  bool _disposed = false;
  Duration _heartbeatPeriod = const Duration(seconds: 2);

  FluidNCSerialConnection(this.portName, {this.baudRate = 115200});

  @override
  Stream<String> get messages => _messageController.stream;

  @override
  Stream<bool> get status => _statusController.stream;

  @override
  Stream<String> get traffic => _trafficController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Duration get heartbeatPeriod => _heartbeatPeriod;

  /// Liste les ports série disponibles sans laisser aucun handle ouvert.
  static List<SerialPortInfo> listAvailablePorts() {
    try {
      final names = SerialPort.availablePorts;
      return names.map((name) {
        String? desc;
        String? mfg;
        SerialPort? sp;
        try {
          sp = SerialPort(name);
          desc = sp.description;
          mfg = sp.manufacturer;
        } catch (_) {
        } finally {
          try {
            sp?.dispose();
          } catch (_) {}
        }
        return SerialPortInfo(name: name, description: desc, manufacturer: mfg);
      }).toList();
    } catch (e) {
      debugPrint('[FORGERON USB] Erreur énumération ports: $e');
      return const [];
    }
  }

  /// Teste brièvement un port série libre en envoyant `$I` et `?`.
  /// Retourne une description du firmware si FluidNC/GRBL répond, ou `null`.
  static Future<String?> probePort(
    String portName, {
    int baudRate = 115200,
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    SerialPort? port;
    SerialPortReader? reader;
    StreamSubscription<Uint8List>? sub;
    try {
      port = SerialPort(portName);
      if (!port.openReadWrite()) {
        return null;
      }
      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);
      port.config = cfg;
      cfg.dispose();

      final completer = Completer<String?>();
      final buf = StringBuffer();
      reader = SerialPortReader(port);
      sub = reader.stream.listen(
        (bytes) {
          buf.write(utf8.decode(bytes, allowMalformed: true));
          final text = buf.toString();
          if (text.contains('[VER:') ||
              text.contains('FluidNC') ||
              text.contains('Grbl') ||
              text.contains('<')) {
            if (!completer.isCompleted) {
              final line = text
                  .split(RegExp(r'[\r\n]+'))
                  .firstWhere(
                    (l) =>
                        l.contains('[VER:') ||
                        l.contains('FluidNC') ||
                        l.contains('Grbl') ||
                        l.startsWith('<'),
                    orElse: () => 'FluidNC USB',
                  );
              completer.complete(line.trim());
            }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      port.write(Uint8List.fromList(utf8.encode('\$I\n?\n')));
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      await sub?.cancel();
      try {
        reader?.close();
      } catch (_) {}
      try {
        if (port != null && port.isOpen) port.close();
        port?.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> connect() async {
    if (_isConnected || _connecting || _disposed) return;
    _connecting = true;

    try {
      debugPrint('[FORGERON USB] Connecting to $portName @ $baudRate...');
      final port = SerialPort(portName);
      if (!port.openReadWrite()) {
        final err = SerialPort.lastError;
        port.dispose();
        throw Exception('Impossible d\'ouvrir $portName (${err?.message ?? "occupé ou absent"})');
      }

      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);
      port.config = cfg;
      cfg.dispose();

      _port = port;
      _onConnected();
    } catch (e) {
      debugPrint('[FORGERON USB] Connection failed: $e');
      _onConnectionFailed();
    } finally {
      _connecting = false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    _retryCount = 0;
    _lineBuffer.clear();
    _statusController.add(true);
    _lastResponseTime = DateTime.now();
    debugPrint('[FORGERON USB] ✅ Connected to $portName @ $baudRate');

    final reader = SerialPortReader(_port!);
    _reader = reader;
    _readerSub = reader.stream.listen(
      _handleIncomingBytes,
      onDone: () => _handleDisconnect('Port série fermé'),
      onError: (e) => _handleDisconnect('Erreur série: $e'),
    );

    _startHeartbeat();
  }

  void _handleIncomingBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _lastResponseTime = DateTime.now();
    final chunk = utf8.decode(bytes, allowMalformed: true);
    _lineBuffer.write(chunk);

    final content = _lineBuffer.toString();
    final lastNewline = content.lastIndexOf('\n');
    if (lastNewline == -1) return;

    final completePart = content.substring(0, lastNewline);
    final remainder = content.substring(lastNewline + 1);
    _lineBuffer
      ..clear()
      ..write(remainder);

    for (final rawLine in completePart.split('\n')) {
      final line = rawLine.replaceAll('\r', '').trim();
      if (line.isEmpty) continue;
      debugPrint('[FORGERON USB RX] $line');
      _trafficController.add('RX: $line');
      _messageController.add(line);
    }
  }

  void _onConnectionFailed() {
    if (_disposed) return;
    _isConnected = false;
    _statusController.add(false);

    const int kMaxExponent = 5;
    final exponent = math.min(_retryCount, kMaxExponent);
    final delay = math.min(math.pow(2, exponent).toInt(), 30);
    _retryCount++;

    debugPrint('[FORGERON USB] ⏳ Retrying $portName in ${delay}s... (attempt $_retryCount)');
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed) connect();
    });
  }

  @override
  void setHeartbeatPeriod(Duration period) {
    if (period == _heartbeatPeriod) return;
    _heartbeatPeriod = period;
    if (_isConnected && !_disposed) _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatPeriod, (timer) {
      if (!_isConnected || _disposed) {
        timer.cancel();
        return;
      }

      sendRaw('?');

      if (_lastResponseTime != null &&
          DateTime.now().difference(_lastResponseTime!).inSeconds > 20) {
        _handleDisconnect('Heartbeat timeout (USB non réactif)');
      }
    });
  }

  @override
  bool sendGCode(String gcode) {
    final cleanCmd = gcode.endsWith('\n') ? gcode : '$gcode\n';
    return sendRaw(cleanCmd);
  }

  @override
  bool sendRaw(String data) {
    if (_isConnected && _port != null && _port!.isOpen) {
      try {
        debugPrint('[FORGERON USB TX] $data');
        _trafficController.add('TX: $data');
        final bytes = Uint8List.fromList(utf8.encode(data));
        final written = _port!.write(bytes);
        if (written < 0) {
          _handleDisconnect('Échec d\'écriture USB');
          return false;
        }
        return true;
      } catch (e) {
        _handleDisconnect('Erreur écriture USB: $e');
        return false;
      }
    }
    debugPrint('[FORGERON USB] ⚠️ TX IGNORÉ (liaison coupée) : $data');
    _trafficController.add('TX ÉCHEC (hors ligne) : $data');
    return false;
  }

  void _handleDisconnect(String reason) {
    if (!_isConnected && !_disposed) return;
    debugPrint('[FORGERON USB] ❌ Disconnected: $reason');
    _isConnected = false;
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _closePort();

    if (!_disposed) {
      _onConnectionFailed();
    }
  }

  void _closePort() {
    _readerSub?.cancel();
    _readerSub = null;
    try {
      _reader?.close();
    } catch (_) {}
    _reader = null;
    try {
      if (_port != null && _port!.isOpen) {
        _port!.close();
      }
      _port?.dispose();
    } catch (_) {}
    _port = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    _closePort();
    _messageController.close();
    _statusController.close();
    _trafficController.close();
  }
}
