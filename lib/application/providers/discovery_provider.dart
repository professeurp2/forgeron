import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_discovery_service.dart';
import 'machine_provider.dart';

/// Provider du service de découverte (singleton).
final autoDiscoveryServiceProvider = Provider<AutoDiscoveryService>((ref) {
  final service = AutoDiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// État de la découverte exposé à l'UI.
class DiscoveryState {
  final List<DiscoveredDevice> devices;
  final bool isScanning;
  final double progress;
  final String? statusMessage;

  const DiscoveryState({
    this.devices = const [],
    this.isScanning = false,
    this.progress = 0.0,
    this.statusMessage,
  });

  DiscoveryState copyWith({
    List<DiscoveredDevice>? devices,
    bool? isScanning,
    double? progress,
    String? statusMessage,
  }) =>
      DiscoveryState(
        devices: devices ?? this.devices,
        isScanning: isScanning ?? this.isScanning,
        progress: progress ?? this.progress,
        statusMessage: statusMessage ?? this.statusMessage,
      );
}

/// Notifier pour gérer le cycle de vie du scan.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final AutoDiscoveryService _service;
  final Ref _ref;
  StreamSubscription<DiscoveredDevice>? _devicesSub;
  StreamSubscription<ScanState>? _stateSub;

  DiscoveryNotifier(this._service, this._ref) : super(const DiscoveryState()) {
    // Écouter les appareils découverts
    _devicesSub = _service.devices.listen((device) {
      final current = List<DiscoveredDevice>.from(state.devices);
      if (!current.any((d) => d.ip == device.ip)) {
        current.add(device);
        state = state.copyWith(devices: current);
      }
    });

    // Écouter l'état du scan
    _stateSub = _service.scanState.listen((scanState) {
      switch (scanState) {
        case ScanIdle():
          state = state.copyWith(
            isScanning: false,
            statusMessage: null,
          );
        case ScanProbing():
          state = state.copyWith(
            isScanning: true,
            statusMessage: 'Vérification des IPs connues...',
            progress: 0.0,
          );
        case ScanScanning():
          state = state.copyWith(
            statusMessage: 'Scan du réseau local...',
          );
        case ScanProgress(:final value):
          state = state.copyWith(progress: value);
        case ScanFound():
          state = state.copyWith(
            isScanning: false,
            statusMessage: '${state.devices.length} appareil(s) trouvé(s)',
          );
        case ScanNotFound():
          state = state.copyWith(
            isScanning: false,
            statusMessage: 'Aucun appareil FluidNC trouvé',
          );
      }
    });
  }

  /// Lance le scan réseau.
  Future<void> scan() async {
    state = state.copyWith(
      devices: [],
      isScanning: true,
      progress: 0.0,
      statusMessage: 'Démarrage du scan...',
    );

    final lastIp = await loadSavedIp();
    await _service.startScan(lastKnownIp: lastIp);
  }

  /// Arrête le scan.
  void stop() {
    _service.stopScan();
  }

  /// Sélectionne un appareil découvert et configure la connexion.
  Future<void> selectDevice(DiscoveredDevice device) async {
    _ref.read(espIpProvider.notifier).state = device.ip;
    _ref.read(wsPortProvider.notifier).state = device.wsPort;
    _ref.read(isSimulationModeProvider.notifier).state = false;

    // Persister le choix
    await persistNetworkSettings(device.ip, device.wsPort);
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}

/// Provider exposant l'état de la découverte à l'UI.
final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  final service = ref.watch(autoDiscoveryServiceProvider);
  return DiscoveryNotifier(service, ref);
});
