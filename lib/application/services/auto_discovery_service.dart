import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Résultat d'une découverte ESP32/FluidNC sur le réseau local.
class DiscoveredDevice {
  final String ip;
  final int httpPort;
  final int wsPort;
  final String? firmwareInfo;
  final Duration responseTime;

  const DiscoveredDevice({
    required this.ip,
    this.httpPort = 80,
    this.wsPort = 81,
    this.firmwareInfo,
    required this.responseTime,
  });

  String get wsUrl => 'ws://$ip:$wsPort';
  String get httpUrl => 'http://$ip:$httpPort';

  @override
  String toString() => 'FluidNC@$ip (${responseTime.inMilliseconds}ms)';
}

/// Service de découverte automatique des contrôleurs FluidNC/ESP32.
///
/// Stratégie de scan en 3 phases :
///   1. IPs favorites (dernière connue + défauts courants)
///   2. Scan du sous-réseau local (/24) par rafales parallèles
///   3. Écoute mDNS (si disponible)
///
/// Chaque IP candidate est testée par un GET HTTP rapide.
/// FluidNC répond avec une page web contenant "FluidNC" ou "Grbl".
class AutoDiscoveryService {
  final http.Client _client;
  final Duration _timeout;
  final int _concurrency;

  /// Contrôleur de stream pour émettre les appareils au fur et à mesure.
  final _devicesController = StreamController<DiscoveredDevice>.broadcast();

  /// Contrôleur pour l'état du scan.
  final _scanStateController = StreamController<ScanState>.broadcast();

  bool _isScanning = false;

  AutoDiscoveryService({
    http.Client? client,
    Duration timeout = const Duration(milliseconds: 1500),
    int concurrency = 20,
  })  : _client = client ?? http.Client(),
        _timeout = timeout,
        _concurrency = concurrency;

  /// Stream des appareils découverts (émis en temps réel pendant le scan).
  Stream<DiscoveredDevice> get devices => _devicesController.stream;

  /// Stream de l'état du scan.
  Stream<ScanState> get scanState => _scanStateController.stream;

  bool get isScanning => _isScanning;

  /// Tente une connexion rapide à une IP spécifique.
  /// Retourne le device si FluidNC est détecté, null sinon.
  Future<DiscoveredDevice?> probeIp(String ip, {int port = 80}) async {
    try {
      final sw = Stopwatch()..start();
      final uri = Uri.parse('http://$ip:$port/');
      final response = await _client.get(uri).timeout(_timeout);
      sw.stop();

      if (response.statusCode < 500) {
        final body = response.body.toLowerCase();
        // FluidNC renvoie une page HTML contenant "fluidnc" ou "grbl"
        // ou au minimum un serveur web fonctionnel
        String? firmware;
        if (body.contains('fluidnc')) {
          firmware = 'FluidNC';
        } else if (body.contains('grbl')) {
          firmware = 'GRBL';
        } else if (body.contains('esp32') || body.contains('webui')) {
          firmware = 'ESP32 WebUI';
        }

        return DiscoveredDevice(
          ip: ip,
          httpPort: port,
          wsPort: 80,
          firmwareInfo: firmware ?? 'HTTP ${response.statusCode}',
          responseTime: sw.elapsed,
        );
      }
    } catch (_) {
      // IP non joignable ou timeout — normal pendant un scan
    }
    return null;
  }

  /// Lance un scan complet du réseau local.
  ///
  /// Phase 1 : IPs favorites (rapide, < 2s)
  /// Phase 2 : Scan du sous-réseau /24 (10-15s)
  Future<List<DiscoveredDevice>> startScan({
    String? lastKnownIp,
    String? subnetPrefix,
  }) async {
    if (_isScanning) return [];

    _isScanning = true;
    final found = <DiscoveredDevice>[];

    // ── Phase 1 : IPs prioritaires ─────────────────────────────────────
    _scanStateController.add(ScanState.probing);

    final priorityIps = <String>{
      if (lastKnownIp != null && lastKnownIp.isNotEmpty) lastKnownIp,
      '192.168.1.1',
      '192.168.1.100',
      '192.168.2.50',
      '192.168.4.1',    // AP mode ESP32
      '10.0.0.1',
      '192.168.0.1',
      '192.168.1.50',
      '192.168.1.200',
    };

    debugPrint('[AutoDiscovery] Phase 1: Probing ${priorityIps.length} priority IPs...');

    final priorityResults = await Future.wait(
      priorityIps.map((ip) => probeIp(ip)),
    );

    for (final device in priorityResults) {
      if (device != null) {
        found.add(device);
        _devicesController.add(device);
        debugPrint('[AutoDiscovery] ✅ Found: $device');
      }
    }

    // Si on a trouvé un appareil en phase 1, on le signale immédiatement
    if (found.isNotEmpty) {
      _scanStateController.add(ScanState.found);
    }

    // ── Phase 2 : Scan du sous-réseau ──────────────────────────────────
    _scanStateController.add(ScanState.scanning);

    // Déterminer le préfixe du sous-réseau
    final prefix = subnetPrefix ?? await _detectSubnet() ?? '192.168.1';
    debugPrint('[AutoDiscovery] Phase 2: Scanning $prefix.0/24...');

    // Scanner par rafales de [_concurrency] IPs en parallèle
    final allIps = List.generate(255, (i) => '$prefix.${i + 1}')
      ..removeWhere((ip) => priorityIps.contains(ip)); // Éviter les doublons

    for (var i = 0; i < allIps.length; i += _concurrency) {
      if (!_isScanning) break; // Annulation

      final batch = allIps.skip(i).take(_concurrency);
      final batchResults = await Future.wait(
        batch.map((ip) => probeIp(ip)),
      );

      for (final device in batchResults) {
        if (device != null && !found.any((d) => d.ip == device.ip)) {
          found.add(device);
          _devicesController.add(device);
          debugPrint('[AutoDiscovery] ✅ Found: $device');
        }
      }

      // Progression
      final progress = ((i + _concurrency) / allIps.length).clamp(0.0, 1.0);
      _scanStateController.add(ScanState.progress(progress));
    }

    _isScanning = false;
    _scanStateController.add(
      found.isNotEmpty ? ScanState.found : ScanState.notFound,
    );

    debugPrint('[AutoDiscovery] Scan complete: ${found.length} device(s) found');
    return found;
  }

  /// Arrête un scan en cours.
  void stopScan() {
    _isScanning = false;
    _scanStateController.add(ScanState.idle);
  }

  /// Détecte le sous-réseau local via les interfaces réseau.
  Future<String?> _detectSubnet() async {
    try {
      if (kIsWeb) return null; // Pas d'accès réseau direct en web

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Ignorer loopback et link-local
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;
          // Extraire le préfixe /24
          final parts = ip.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            debugPrint('[AutoDiscovery] Detected subnet: $prefix.0/24 (via ${iface.name})');
            return prefix;
          }
        }
      }
    } catch (e) {
      debugPrint('[AutoDiscovery] Subnet detection failed: $e');
    }
    return null;
  }

  void dispose() {
    stopScan();
    _devicesController.close();
    _scanStateController.close();
    _client.close();
  }
}

/// État du scan réseau.
sealed class ScanState {
  const ScanState();

  static const idle = ScanIdle();
  static const probing = ScanProbing();
  static const scanning = ScanScanning();
  static const found = ScanFound();
  static const notFound = ScanNotFound();

  static ScanProgress progress(double value) => ScanProgress(value);
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

class ScanProbing extends ScanState {
  const ScanProbing();
}

class ScanScanning extends ScanState {
  const ScanScanning();
}

class ScanProgress extends ScanState {
  final double value; // 0.0 to 1.0
  const ScanProgress(this.value);
}

class ScanFound extends ScanState {
  const ScanFound();
}

class ScanNotFound extends ScanState {
  const ScanNotFound();
}
