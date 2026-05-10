import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class FilePickerService {
  /// Ouvre un sélecteur de fichiers natif Web pour le G-Code
  static Future<String?> pickGCodeContent() async {
    final Completer<String?> completer = Completer();
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.nc,.gcode,.txt';
    
    // Attacher au DOM pour une meilleure compatibilité Chrome
    html.document.body!.append(uploadInput);

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        uploadInput.remove();
        return;
      }
      
      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) {
        completer.complete(reader.result as String?);
        uploadInput.remove();
      });
      reader.onError.listen((e) {
        completer.complete(null);
        uploadInput.remove();
      });
      reader.readAsText(files[0]);
    });
    
    uploadInput.click();
    
    // Fallback cleanup si l'utilisateur annule (difficile à détecter précisément sur Web)
    // Mais on peut au moins nettoyer si on ne reçoit rien après un temps
    Timer(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        uploadInput.remove();
      }
    });

    return completer.future;
  }

  /// Ouvre un sélecteur natif Web pour l'upload réel (retourne bytes et nom)
  static Future<({String name, List<int> bytes})?> pickFileForUpload() async {
    final Completer<({String name, List<int> bytes})?> completer = Completer();
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.nc,.gcode,.gc,.tap,.ngc,.cnc';
    
    html.document.body!.append(uploadInput);

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        uploadInput.remove();
        return;
      }
      
      final file = files[0];
      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) {
        final bytes = reader.result as Uint8List;
        completer.complete((name: file.name, bytes: bytes.toList()));
        uploadInput.remove();
      });
      reader.onError.listen((e) {
        completer.complete(null);
        uploadInput.remove();
      });
      reader.readAsArrayBuffer(file);
    });
    
    uploadInput.click();
    return completer.future;
  }
}
