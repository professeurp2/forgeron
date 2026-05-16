import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/config_repository.dart';
import '../../data/fluidnc/fluidnc_config_repository.dart';
import '../../data/mock/mock_config_repository.dart';
import 'machine_provider.dart';

/// Repository de configuration FluidNC — Bascule entre Mock et Réel selon le mode
final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);
  if (isSim) {
    return MockConfigRepository();
  }
  final ip = ref.watch(espIpProvider);
  return FluidNcConfigRepository('http://$ip');
});

final configProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getConfig();
});
