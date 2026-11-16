import 'dart:io';
import 'dart:typed_data';
import 'package:pasteboard/pasteboard.dart';

/// Image lue depuis le presse-papier système (PNG/JPEG/WebP/BMP).
class ClipboardImageResult {
  final Uint8List bytes;
  final String mimeType;

  const ClipboardImageResult(this.bytes, this.mimeType);
}

/// Lit une image depuis le presse-papier (capture d'écran, image copiée ou
/// fichier image copié dans l'explorateur). Retourne `null` si le presse-papier
/// ne contient pas d'image (afin de laisser le collage texte normal agir).
Future<ClipboardImageResult?> readClipboardImage() async {
  try {
    final imageBytes = await Pasteboard.image;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return ClipboardImageResult(imageBytes, 'image/png');
    }

    final files = await Pasteboard.files();
    for (final path in files) {
      final lower = path.toLowerCase();
      String? mime;
      if (lower.endsWith('.png')) {
        mime = 'image/png';
      } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        mime = 'image/jpeg';
      } else if (lower.endsWith('.webp')) {
        mime = 'image/webp';
      } else if (lower.endsWith('.bmp')) {
        mime = 'image/bmp';
      }
      if (mime != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            return ClipboardImageResult(bytes, mime);
          }
        }
      }
    }
  } catch (_) {
    // Ignore les erreurs presse-papier sur plateformes non supportées.
  }
  return null;
}
