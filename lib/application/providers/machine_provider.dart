import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import '../../data/fluidnc/fluidnc_connection.dart';
import '../../data/fluidnc/fluidnc_machine_repository.dart';
import '../../data/mock/mock_machine_repository.dart';

// ── Configuration réseau et simulation ──────────────────────────────────────

/// Adresse IP de l'ESP32 FluidNC
final espIpProvider = StateProvider<String>((ref) => '192.168.1.100');
final wsPortProvider = StateProvider<int>((ref) => 80);
final httpPortProvider = StateProvider<int>((ref) => 80);

/// Mode simulation pour tester sans ESP32 physique
final isSimulationModeProvider = StateProvider<bool>((ref) => false);

// ── Repository selection (Réel ou Mock) ─────────────────────────────────────

final machineRepositoryProvider = Provider<MachineRepository>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);

  if (isSim) {
    debugPrint('[MachineProvider] Mode SIMULATION actif');
    return MockMachineRepository();
  }

  final ip = ref.watch(espIpProvider);
  final wsPort = ref.watch(wsPortProvider);
  final wsUrl = 'ws://$ip:$wsPort/';
  debugPrint('[MachineProvider] Mode PRODUCTION → connexion à $wsUrl');
  final conn = FluidNCConnection(wsUrl);
  final repo = FluidNCMachineRepository(conn);

  // Crucial : Arrêter les timers et fermer le socket quand on change de mode
  ref.onDispose(() {
    debugPrint('[MachineProvider] Disposing connection to $wsUrl');
    repo.dispose();
  });

  return repo;
});

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
  final wsPort = prefs.getInt('ws_port') ?? 81;
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

