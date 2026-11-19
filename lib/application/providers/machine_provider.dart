import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../domain/models/machine_state.dart';
import '../../core/utils/kinematics_service.dart';
import '../../data/fluidnc/fluidnc_serial_connection.dart';
import 'di_providers.dart';
import 'machining_mode_provider.dart' show trunnionConfigProvider;

// ── Configuration réseau, USB et simulation ─────────────────────────────────

const kDefaultWsPort = 80;
const kDefaultSerialBaudRate = 115200;

/// Mode de transport physique vers FluidNC : Wi-Fi (WebSocket/HTTP) ou Câble USB (Série COM).
enum ConnectionTransport { wifi, usb }

/// Transport actif vers la carte FluidNC (USB par défaut sur poste fixe pour
/// éviter toute latence ou micro-coupure Wi-Fi).
final connectionTransportProvider =
    StateProvider<ConnectionTransport>((ref) => ConnectionTransport.usb);

/// Port série USB sélectionné (ex: 'COM5' sur Windows, '/dev/ttyUSB0' sur Linux).
final serialPortProvider = StateProvider<String>((ref) => 'COM5');

/// Débit du port série USB (bauds).
final serialBaudRateProvider =
    StateProvider<int>((ref) => kDefaultSerialBaudRate);

/// Adresse IP de l'ESP32 FluidNC
final espIpProvider = StateProvider<String>((ref) => '192.168.137.100');
final wsPortProvider = StateProvider<int>((ref) => kDefaultWsPort);
final httpPortProvider = StateProvider<int>((ref) => 80);

/// Mode simulation pour tester sans ESP32 physique
final isSimulationModeProvider = StateProvider<bool>((ref) => false);


// ── État machine (Stream temps réel) ────────────────────────────────────────

final machineStateProvider = StreamProvider<MachineState>((ref) {
  final repo = ref.watch(machineRepositoryProvider);
  return repo.stateStream;
});

/// Position machine courante transformée par cinématique directe — position
/// réelle de la pointe d'outil dans le repère pièce, pour le marqueur "ghost"
/// du visualiseur 3D. Sans cette transformation, le marqueur dérive du tracé
/// (lui-même corrigé, voir [renderToolpathProvider] dans gcode_provider.dart)
/// dès que les axes rotatifs A/C ne sont pas à zéro.
final renderMPosProvider = Provider<List<double>>((ref) {
  final mPos =
      ref.watch(machineStateProvider).valueOrNull?.mPos ?? const [0.0, 0.0, 0.0, 0.0, 0.0];
  final config = ref.watch(trunnionConfigProvider);
  final kinematics = KinematicsService(pivotToTableOffset: config.pivotToTableOffset);
  final tip = kinematics.forward(Vector3(mPos[0], mPos[1], mPos[2]), mPos[3], mPos[4]);
  return [tip.x, tip.y, tip.z, mPos[3], mPos[4]];
});

// ── Persistance réseau ───────────────────────────────────────────────────────

Future<void> saveEspIp(WidgetRef ref, String ip) async {
  ref.read(espIpProvider.notifier).state = ip;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('esp_ip', ip);
}

Future<String> loadSavedIp() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('esp_ip') ?? '192.168.137.100';
}

Future<void> loadNetworkPreferences(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ip = prefs.getString('esp_ip') ?? '192.168.137.100';
  final wsPort = prefs.getInt('ws_port') ?? kDefaultWsPort;
  final savedTransport = prefs.getString('connection_transport');
  var serialPort = prefs.getString('serial_port') ?? 'COM5';
  final baud = prefs.getInt('serial_baud') ?? kDefaultSerialBaudRate;

  // Si un port série USB (CP210x / CH340 / ESP32) est branché sur le PC,
  // privilégier automatiquement l'USB et sélectionner le bon port COM.
  final ports = FluidNCSerialConnection.listAvailablePorts();
  final usbPort = ports.where((p) {
    final d = '${p.description ?? ''} ${p.manufacturer ?? ''}'.toLowerCase();
    return d.contains('cp210') ||
        d.contains('ch340') ||
        d.contains('silicon labs') ||
        d.contains('usb') ||
        d.contains('uart') ||
        d.contains('serial');
  }).firstOrNull;

  ConnectionTransport transport;
  if (usbPort != null) {
    transport = ConnectionTransport.usb;
    if (!ports.any((p) => p.name == serialPort)) {
      serialPort = usbPort.name;
    }
  } else {
    transport = savedTransport == 'wifi'
        ? ConnectionTransport.wifi
        : ConnectionTransport.usb;
  }

  ref.read(espIpProvider.notifier).state = ip;
  ref.read(wsPortProvider.notifier).state = wsPort;
  ref.read(connectionTransportProvider.notifier).state = transport;
  ref.read(serialPortProvider.notifier).state = serialPort;
  ref.read(serialBaudRateProvider.notifier).state = baud;
}

Future<void> saveNetworkPreferences(
    WidgetRef ref, String ip, int wsPort) async {
  ref.read(connectionTransportProvider.notifier).state =
      ConnectionTransport.wifi;
  ref.read(espIpProvider.notifier).state = ip;
  ref.read(wsPortProvider.notifier).state = wsPort;
  await persistNetworkSettings(ip, wsPort);
}

Future<void> saveUsbPreferences(
    WidgetRef ref, String portName, int baudRate) async {
  ref.read(connectionTransportProvider.notifier).state =
      ConnectionTransport.usb;
  ref.read(serialPortProvider.notifier).state = portName;
  ref.read(serialBaudRateProvider.notifier).state = baudRate;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('connection_transport', 'usb');
  await prefs.setString('serial_port', portName);
  await prefs.setInt('serial_baud', baudRate);
}

/// Persiste les paramètres réseau sans nécessiter un WidgetRef.
/// Utilisé par les providers internes (ex: auto-discovery).
Future<void> persistNetworkSettings(String ip, int wsPort) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('connection_transport', 'wifi');
  await prefs.setString('esp_ip', ip);
  await prefs.setInt('ws_port', wsPort);
}
