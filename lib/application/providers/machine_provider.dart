import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/machine_state.dart';
import 'di_providers.dart';

// ── Configuration réseau et simulation ──────────────────────────────────────

const kDefaultWsPort = 80;

/// Adresse IP de l'ESP32 FluidNC
final espIpProvider = StateProvider<String>((ref) => '192.168.1.100');
final wsPortProvider = StateProvider<int>((ref) => kDefaultWsPort);
final httpPortProvider = StateProvider<int>((ref) => 80);

/// Mode simulation pour tester sans ESP32 physique
final isSimulationModeProvider = StateProvider<bool>((ref) => false);


// ── État machine (Stream temps réel) ────────────────────────────────────────

final machineStateProvider = StreamProvider<MachineState>((ref) {
  final repo = ref.watch(machineRepositoryProvider);
  return repo.stateStream;
});

// ── Persistance réseau ───────────────────────────────────────────────────────

Future<void> saveEspIp(WidgetRef ref, String ip) async {
  ref.read(espIpProvider.notifier).state = ip;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('esp_ip', ip);
}

Future<String> loadSavedIp() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('esp_ip') ?? '192.168.1.100';
}

Future<void> loadNetworkPreferences(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ip = prefs.getString('esp_ip') ?? '192.168.1.100';
  final wsPort = prefs.getInt('ws_port') ?? kDefaultWsPort;
  ref.read(espIpProvider.notifier).state = ip;
  ref.read(wsPortProvider.notifier).state = wsPort;
}

Future<void> saveNetworkPreferences(
    WidgetRef ref, String ip, int wsPort) async {
  ref.read(espIpProvider.notifier).state = ip;
  ref.read(wsPortProvider.notifier).state = wsPort;
  await persistNetworkSettings(ip, wsPort);
}

/// Persiste les paramètres réseau sans nécessiter un WidgetRef.
/// Utilisé par les providers internes (ex: auto-discovery).
Future<void> persistNetworkSettings(String ip, int wsPort) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('esp_ip', ip);
  await prefs.setInt('ws_port', wsPort);
}
