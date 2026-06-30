import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

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
