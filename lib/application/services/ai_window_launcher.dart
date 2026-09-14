import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart' show Offset, Size;
import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Fenêtres OS séparées que l'agent IA peut ouvrir lui-même — un graphique,
/// un G-code détaché, un rapport, l'aperçu 3D d'une pièce, un parcours
/// d'outil — chacune relance `main()` avec un second moteur Flutter (voir
/// `lib/main.dart` et `presentation/desktop/`).
///
/// Desktop uniquement : sur mobile/web, `desktop_multi_window` n'a aucune
/// implémentation native, donc [isSupported] doit être vérifié avant tout
/// appel — jamais présumé, l'app tourne aussi sur Android.
class AiWindowLauncher {
  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Au-delà, la charge passe par un fichier temporaire plutôt que par les
  /// arguments de la fenêtre : un maillage de pièce pèse facilement plusieurs
  /// mégaoctets, et les faire transiter par un canal de plateforme au
  /// démarrage d'un moteur Flutter ralentit l'ouverture pour rien.
  static const _inlineLimit = 32 * 1024;

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

  /// Aperçu 3D d'une pièce STEP. [mesh] est le maillage produit par
  /// `pipeline/step_preview.py` (`{vertices, indices}`) ; [info] les quelques
  /// chiffres affichés sous la vue (encombrement, volume, triangles).
  static Future<String> openStepPreview({
    required String title,
    required Map<String, dynamic> mesh,
    Map<String, dynamic> info = const {},
  }) {
    return _open({
      'type': 'step_preview',
      'title': title,
      'mesh': mesh,
      'info': info,
    });
  }

  /// Parcours d'outil en 3D, lu depuis un fichier `.nc` — le chemin, pas le
  /// contenu : la fenêtre le charge elle-même avec le parseur de l'app, donc
  /// avec la même adaptation FluidNC et la même cinématique que l'écran
  /// principal.
  ///
  /// Aucun maillage n'accompagne le parcours : cette fenêtre montre le tracé
  /// SEUL. Une pièce dessinée dessous masquerait les passes exactement là où
  /// il faut les lire, puisque le parcours épouse la surface.
  static Future<String> openToolpath({
    required String title,
    required String gcodePath,
    Map<String, dynamic> info = const {},
  }) {
    return _open({
      'type': 'toolpath',
      'title': title,
      'gcodePath': gcodePath,
      'info': info,
    });
  }

  /// Les fenêtres 3D méritent plus de place qu'un rapport clé/valeur : une
  /// pièce affichée dans 760 × 580 ne se lit pas.
  static const _size3d = Size(1000, 760);
  static const _sizeDefault = Size(760, 580);

  static bool _is3d(Object? type) => type == 'step_preview' || type == 'toolpath';

  static Future<String> _open(Map<String, dynamic> payload) async {
    if (!isSupported) {
      return 'Fenêtres indisponibles sur cette plateforme (desktop uniquement).';
    }
    final controller = await WindowController.create(
      WindowConfiguration(
        arguments: _arguments(payload),
        hiddenAtLaunch: true,
      ),
    );

    // Le cadre, le titre et la position sont posés D'ICI, depuis la fenêtre
    // principale, avant l'affichage.
    //
    // La fenêtre secondaire le faisait elle-même, via `window_manager` — et
    // c'est ce qui fermait l'application entière dès qu'on refermait une
    // fenêtre détachée. `window_manager` s'attache à UNE fenêtre native, celle
    // qu'il trouve à son initialisation ; initialisé dans un second moteur
    // Flutter, il se raccroche à la fenêtre principale et en détourne la
    // procédure. La refermer revenait alors à refermer l'application.
    //
    // `WindowController` est l'API prévue pour ça : elle désigne explicitement
    // la fenêtre visée, et le moteur secondaire n'a plus besoin de connaître
    // le moindre plugin de gestion de fenêtres.
    final size = _is3d(payload['type']) ? _size3d : _sizeDefault;
    try {
      await controller.setFrame(Offset.zero & size);
      await controller.center();
      await controller.setTitle(payload['title'] as String? ?? 'Forgeron');
    } catch (_) {
      // Mise en forme refusée : la fenêtre s'ouvre quand même, à la taille
      // que la plateforme lui donne. Mieux vaut une fenêtre mal cadrée que
      // pas de fenêtre.
    }
    await controller.show();
    return 'Fenêtre "${payload['title']}" ouverte.';
  }

  /// Sérialise la charge, en la déportant dans un fichier temporaire si elle
  /// est volumineuse. La fenêtre lit alors ce fichier au démarrage et le
  /// supprime (voir `AiSubWindowApp`).
  static String _arguments(Map<String, dynamic> payload) {
    final encoded = jsonEncode(payload);
    if (encoded.length <= _inlineLimit) return encoded;
    try {
      final file = _tempFile();
      file.writeAsStringSync(encoded);
      return jsonEncode({
        'type': payload['type'],
        'title': payload['title'],
        'payloadFile': file.path,
      });
    } catch (_) {
      // Disque non inscriptible : mieux vaut une fenêtre lente qu'aucune.
      return encoded;
    }
  }

  static File _tempFile() {
    final dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}forgeron_fenetres',
    )..createSync(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = Random().nextInt(1 << 20).toRadixString(36);
    return File('${dir.path}${Platform.pathSeparator}w_${stamp}_$salt.json');
  }
}
