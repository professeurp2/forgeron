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
/// Chaque IP candidate est testée par un GET HTTP rapide, et n'est retenue que si
/// sa page d'accueil ou sa réponse à `$I` nomme FluidNC ou GRBL.
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
    Duration timeout = const Duration(milliseconds: 3500),
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
      // Requête directe sur /command?plain=$I (225 octets au lieu de 6,8 Ko sur /)
      // pour éviter la double requête sur les hotspots à forte latence.
      final cmdUri = Uri(
        scheme: 'http',
        host: ip,
        port: port,
        path: '/command',
        queryParameters: {'plain': r'$I'},
      );
      final cmdResp = await _client.get(cmdUri).timeout(_timeout);
      sw.stop();

      final cmdKind = cmdResp.headers['x-forgeron-device']?.toLowerCase();
      final cmdBody = cmdResp.body.toLowerCase();
      if (cmdKind == 'camera' || cmdBody.contains('forgeron-device')) {
        return null;
      }
      if (cmdResp.statusCode < 300) {
        final fw = _firmwareIn(cmdBody) ?? (cmdBody.contains('[ver:') ? 'GRBL' : null);
        if (fw != null) {
          return DiscoveredDevice(
            ip: ip,
            httpPort: port,
            wsPort: 80,
            firmwareInfo: fw,
            responseTime: sw.elapsed,
          );
        }
      }

      // Repli sur GET / si /command n'a pas suffi
      final uri = Uri.parse('http://$ip:$port/');
      final response = await _client.get(uri).timeout(_timeout);
      sw.stop();

      if (response.statusCode < 500) {
        final body = response.body.toLowerCase();
        final deviceKind = response.headers['x-forgeron-device']?.toLowerCase();
        if (deviceKind == 'camera' || body.contains('forgeron-device')) {
          return null;
        }
        final firmware = _firmwareIn(body);
        if (firmware == null) return null;

        return DiscoveredDevice(
          ip: ip,
          httpPort: port,
          wsPort: 80,
          firmwareInfo: firmware,
          responseTime: sw.elapsed,
        );
      }
    } catch (_) {
      // IP non joignable ou timeout — normal pendant un scan
    }
    return null;
  }

  static String? _firmwareIn(String lowerBody) {
    if (lowerBody.contains('fluidnc')) return 'FluidNC';
    if (lowerBody.contains('grbl')) return 'GRBL';
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
      'FORGERON.local',  // mDNS FluidNC (suit automatiquement l'IP DHCP)
      '192.168.137.100', // Hotspot Windows (FluidNC ESP32 par défaut)
      '192.168.137.50',  // Hotspot Windows (ESP32-CAM)
      '192.168.137.1',   // Hotspot Windows Gateway
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

    // Si on a trouvé un appareil en phase 1, on s'arrête sans saturer le hotspot
    if (found.isNotEmpty) {
      _isScanning = false;
      _scanStateController.add(ScanState.found);
      debugPrint('[AutoDiscovery] Scan complete (Phase 1): ${found.length} device(s) found');
      return found;
    }

    // ── Phase 2 : Scan du sous-réseau ──────────────────────────────────
    _scanStateController.add(ScanState.scanning);

    // Déterminer le préfixe du sous-réseau
    final prefix = subnetPrefix ?? await _detectSubnet() ?? '192.168.137';
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
  /// Priorise le sous-réseau du hotspot Windows (192.168.137.x) s'il est actif.
  Future<String?> _detectSubnet() async {
    try {
      if (kIsWeb) return null; // Pas d'accès réseau direct en web

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      String? fallbackPrefix;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Ignorer loopback et link-local
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;
          // Extraire le préfixe /24
          final parts = ip.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            // Si c'est le sous-réseau Hotspot Windows, priorité absolue
            if (prefix == '192.168.137') {
              debugPrint('[AutoDiscovery] Detected hotspot subnet: $prefix.0/24 (via ${iface.name})');
              return prefix;
            }
            fallbackPrefix ??= prefix;
          }
        }
      }
      if (fallbackPrefix != null) {
        debugPrint('[AutoDiscovery] Detected subnet: $fallbackPrefix.0/24');
        return fallbackPrefix;
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
