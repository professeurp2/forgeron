import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

Future<Uint8List?> pickFilesRaw({List<String>? allowedExtensions}) async {
  final result = await FilePicker.platform.pickFiles(
    type: allowedExtensions != null ? FileType.custom : FileType.any,
    allowedExtensions: allowedExtensions,
    withData: true,
  );
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    if (file.bytes != null) {
      return file.bytes;
    }
    if (file.path != null) {
      return File(file.path!).readAsBytesSync();
    }
  }
  return null;
}

Future<({String name, List<int> bytes})?> pickFileWithMetadata() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    final String name = file.name;
    List<int>? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = File(file.path!).readAsBytesSync();
    }
    return (name: name, bytes: bytes ?? []);
  }
  return null;
}

// ── Dossier de travail (fichiers G-code réels du téléphone) ─────────────────

const _gcodeExts = ['.nc', '.gcode', '.tap', '.g', '.ngc', '.txt'];

/// Ouvre le sélecteur de dossier et retourne un **vrai chemin filesystem**.
///
/// Sur Android, `getDirectoryPath` renvoie une URI SAF `content://…` que
/// `dart:io` ne sait pas lire : on demande d'abord l'accès « tous les fichiers »
/// (Android 11+), puis on convertit l'URI de l'arbre SAF en chemin réel
/// (`/storage/emulated/0/…`) que `Directory.listSync()` peut parcourir.
Future<String?> pickDirectoryPath() async {
  if (Platform.isAndroid) {
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }
  final picked = await FilePicker.platform.getDirectoryPath();
  if (picked == null) return null;
  return _resolveTreeUri(picked);
}

/// Convertit une URI d'arbre SAF Android en chemin filesystem réel.
/// Ex : `content://com.android.externalstorage.documents/tree/primary%3ADownload`
///   →  `/storage/emulated/0/Download`
String? _resolveTreeUri(String p) {
  if (!p.startsWith('content://')) return p; // déjà un vrai chemin
  final decoded = Uri.decodeFull(p);
  final treeIdx = decoded.indexOf('/tree/');
  if (treeIdx == -1) return null;
  var docId = decoded.substring(treeIdx + 6);
  final docSuffix = docId.indexOf('/document/');
  if (docSuffix != -1) docId = docId.substring(0, docSuffix);
  final sep = docId.indexOf(':');
  if (sep == -1) return null;
  final volume = docId.substring(0, sep);
  final rel = docId.substring(sep + 1);
  if (volume == 'primary') {
    return '/storage/emulated/0/$rel'.replaceAll(RegExp(r'/+$'), '');
  }
  // Carte SD / volume externe : /storage/<UUID>/<rel>
  return '/storage/$volume/$rel'.replaceAll(RegExp(r'/+$'), '');
}

List<({String name, String path, int size})> listDirectoryGcode(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  final out = <({String name, String path, int size})>[];
  for (final e in d.listSync()) {
    if (e is! File) continue;
    final name = e.uri.pathSegments.isEmpty ? e.path : e.uri.pathSegments.last;
    final lower = name.toLowerCase();
    if (_gcodeExts.any(lower.endsWith)) {
      out.add((name: name, path: e.path, size: e.lengthSync()));
    }
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

Future<String> readFileText(String path) => File(path).readAsString();

Future<void> writeFileText(String path, String content) =>
    File(path).writeAsString(content);
