import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// Import conditionnel pour le file_picker
import 'file_picker_web.dart' if (dart.library.io) 'file_picker_desktop.dart';

class FilePickerService {
  static Future<String?> pickGCodeContent() async {
    final bytes = await pickFilesRaw(
      allowedExtensions: ['nc', 'gcode', 'txt'],
    );
    if (bytes != null) {
      return utf8.decode(bytes);
    }
    return null;
  }

  static Future<({String name, List<int> bytes})?> pickFileForUpload() async {
    return await pickFileWithMetadata();
  }

  // ── Dossier de travail (mobile) ───────────────────────────────────────────

  /// Laisse l'utilisateur choisir un dossier du téléphone. Retourne son chemin.
  static Future<String?> pickWorkFolder() => pickDirectoryPath();

  /// Liste les fichiers G-code (.nc/.gcode/.tap/.g/.ngc/.txt) d'un dossier.
  static List<({String name, String path, int size})> listWorkFiles(
          String dir) =>
      listDirectoryGcode(dir);

  static Future<String> readWorkFile(String path) => readFileText(path);

  static Future<void> writeWorkFile(String path, String content) =>
      writeFileText(path, content);
}
