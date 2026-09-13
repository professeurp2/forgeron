import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Fenêtres OS séparées que l'agent IA peut ouvrir lui-même — un graphique,
/// un G-code détaché, un rapport — chacune relance `main()` avec un second
/// moteur Flutter (voir `lib/main.dart` et `presentation/desktop/`).
///
/// Desktop uniquement : sur mobile/web, `desktop_multi_window` n'a aucune
/// implémentation native, donc [isSupported] doit être vérifié avant tout
/// appel — jamais présumé, l'app tourne aussi sur Android.
class AiWindowLauncher {
  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static Future<String> openChart({
    required String title,
    required List<String> labels,
    required List<double> values,
    String unit = '',
  }) {
    return _open({
      'type': 'chart',
      'title': title,
      'labels': labels,
      'values': values,
      'unit': unit,
    });
  }

  static Future<String> openGcode({
    required String title,
    required String content,
  }) {
    return _open({'type': 'gcode', 'title': title, 'content': content});
  }

  static Future<String> openReport({
    required String title,
    required Map<String, dynamic> fields,
  }) {
    return _open({'type': 'report', 'title': title, 'fields': fields});
  }

  static Future<String> _open(Map<String, dynamic> payload) async {
    if (!isSupported) {
      return 'Fenêtres indisponibles sur cette plateforme (desktop uniquement).';
    }
    final controller = await WindowController.create(
      WindowConfiguration(arguments: jsonEncode(payload), hiddenAtLaunch: true),
    );
    await controller.show();
    return 'Fenêtre "${payload['title']}" ouverte.';
  }
}
