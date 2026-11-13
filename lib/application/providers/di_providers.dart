import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/machine_repository.dart';
import '../../data/fluidnc/fluidnc_connection.dart';
import '../../data/fluidnc/fluidnc_serial_connection.dart';
import '../../data/fluidnc/fluidnc_machine_repository.dart';
import '../../data/mock/mock_machine_repository.dart';
import 'machine_provider.dart';

/// Transport actif vers FluidNC (WebSocket Wi-Fi ou Port Série USB).
/// Partagé par [machineRepositoryProvider], [fileRepositoryProvider] et [configRepositoryProvider].
final activeFluidNCConnectionProvider = Provider<FluidNCConnection?>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);
  if (isSim) return null;

  final transport = ref.watch(connectionTransportProvider);
  final FluidNCConnection conn;
  if (transport == ConnectionTransport.usb) {
    final port = ref.watch(serialPortProvider);
    final baud = ref.watch(serialBaudRateProvider);
    conn = FluidNCSerialConnection(port, baudRate: baud);
  } else {
    final ip = ref.watch(espIpProvider);
    final wsPort = ref.watch(wsPortProvider);
    conn = FluidNCConnection('ws://$ip:$wsPort/');
  }

  ref.onDispose(conn.dispose);
  return conn;
});

final machineRepositoryProvider = Provider<MachineRepository>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);

  if (isSim) {
    // Le mock arme un timer périodique de 50 ms dès sa construction : sans
    // onDispose, chaque bascule du mode simulation en laissait un tourner.
    final mock = MockMachineRepository();
    ref.onDispose(mock.dispose);
    return mock;
  }

  final conn = ref.watch(activeFluidNCConnectionProvider)!;
  final repo = FluidNCMachineRepository(conn, ownsConnection: false);

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});
