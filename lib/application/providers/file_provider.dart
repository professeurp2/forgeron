import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/gcode_file.dart';
import '../../domain/repositories/file_repository.dart';
import '../../data/fluidnc/fluidnc_http_client.dart';
import 'machine_provider.dart';

/// Repository de fichiers — toujours HTTP réel (production)
final fileRepositoryProvider = Provider<FileRepository>((ref) {
  final ip = ref.watch(espIpProvider);
  return FluidNcHttpClient('http://$ip');
});

final fileListProvider = FutureProvider<List<GCodeFile>>((ref) async {
  final repo = ref.watch(fileRepositoryProvider);
  return repo.listFiles();
});
