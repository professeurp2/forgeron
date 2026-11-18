import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/gcode_file.dart';
import '../../domain/repositories/file_repository.dart';
import '../../data/fluidnc/fluidnc_http_client.dart';
import '../../data/fluidnc/fluidnc_serial_repositories.dart';
import '../../data/mock/mock_file_repository.dart';
import 'di_providers.dart';
import 'machine_provider.dart';

/// Repository de fichiers — Bascule entre Mock, USB Série et HTTP Wi-Fi
final fileRepositoryProvider = Provider<FileRepository>((ref) {
  final isSim = ref.watch(isSimulationModeProvider);
  if (isSim) {
    return MockFileRepository();
  }
  final transport = ref.watch(connectionTransportProvider);
  if (transport == ConnectionTransport.usb) {
    final conn = ref.watch(activeFluidNCConnectionProvider);
    return FluidNCSerialFileRepository(conn);
  }
  final ip = ref.watch(espIpProvider);
  return FluidNcHttpClient('http://$ip');
});

final fileListProvider = FutureProvider<List<GCodeFile>>((ref) async {
  final repo = ref.watch(fileRepositoryProvider);
  return repo.listFiles();
});
