import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/machine_repository.dart';
import '../../data/fluidnc/fluidnc_connection.dart';
import '../../data/fluidnc/fluidnc_machine_repository.dart';
import '../../data/mock/mock_machine_repository.dart';
import 'machine_provider.dart';
import '../../application/providers/di_providers.dart';

final machineRepositoryProvider = Provider<MachineRepository>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);

  if (isSim) {
    // Le mock arme un timer périodique de 50 ms dès sa construction : sans
    // onDispose, chaque bascule du mode simulation en laissait un tourner.
    final mock = MockMachineRepository();
    ref.onDispose(mock.dispose);
    return mock;
  }

  final ip = ref.watch(espIpProvider);
  final wsPort = ref.watch(wsPortProvider);
  final wsUrl = 'ws://$ip:$wsPort/';
  
  final conn = FluidNCConnection(wsUrl);
  final repo = FluidNCMachineRepository(conn);

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});
