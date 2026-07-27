import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../domain/models/machine_state.dart';
import '../../core/utils/kinematics_service.dart';
import 'di_providers.dart';
import 'machining_mode_provider.dart' show trunnionConfigProvider;

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
