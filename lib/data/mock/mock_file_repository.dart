import '../../domain/models/gcode_file.dart';
import '../../domain/repositories/file_repository.dart';

class MockFileRepository implements FileRepository {
  final List<GCodeFile> _files = [
    GCodeFile(name: 'projet_moule_v2.nc', size: 1048576, lines: 15200, lastModified: DateTime(2024, 3, 14, 15, 30)),
    GCodeFile(name: 'surfacage_brut.nc', size: 20480, lines: 350, lastModified: DateTime(2024, 3, 15, 8, 45)),
    GCodeFile(name: 'percages_m5.nc', size: 8192, lines: 120, lastModified: DateTime(2024, 3, 15, 9, 10)),
    GCodeFile(name: 'contour_finition.nc', size: 512000, lines: 8400, lastModified: DateTime(2024, 3, 15, 11, 20)),
    GCodeFile(name: 'test_5axes.nc', size: 153600, lines: 2100, lastModified: DateTime(2024, 3, 12, 14, 00)),
  ];

  @override
  Future<List<GCodeFile>> listFiles({String path = '/'}) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network latency
    return _files;
  }

  @override
  Future<String> readFile(String path) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'G90\nG21\nG54\nS12000 M3\nG0 X0 Y0 Z10\nG1 Z-5 F500\n...'; // Mock content
  }

  @override
  Future<void> uploadFile(String path, List<int> bytes) async {
    await Future.delayed(const Duration(seconds: 1));
    _files.add(GCodeFile(name: path.split('/').last, size: bytes.length, lines: bytes.length ~/ 20, lastModified: DateTime.now()));
  }

  @override
  Future<void> deleteFile(String path) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _files.removeWhere((file) => file.name == path.split('/').last);
  }
}
