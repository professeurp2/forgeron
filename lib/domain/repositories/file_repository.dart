import '../models/gcode_file.dart';

abstract class FileRepository {
  /// Lists all files in a directory.
  Future<List<GCodeFile>> listFiles({String path = '/'});

  /// Reads a file from the machine storage.
  Future<String> readFile(String path);

  /// Uploads a file to the machine storage.
  Future<void> uploadFile(String path, List<int> bytes);

  /// Deletes a file from the machine storage.
  Future<void> deleteFile(String path);
}
