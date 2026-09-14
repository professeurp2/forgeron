import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Le canal qui relie une fenêtre détachée à la fenêtre principale.
///
/// Les deux vivent dans des moteurs Flutter distincts : pas de Riverpod
/// partagé, pas de mémoire commune. La seule voie est le canal de méthodes de
/// `desktop_multi_window`, et elle ne transporte que de petits messages.
///
/// C'est pour cela qu'un retour au bercail n'envoie PAS l'aperçu : il envoie
/// seulement lequel montrer. La fenêtre principale possède déjà la pièce et le
/// programme (`aiArtifactsProvider`) — un maillage de plusieurs mégaoctets
/// n'a aucune raison de refaire le voyage.
class AiWindowChannel {
  const AiWindowChannel._();

  /// La fenêtre principale est toujours le moteur 0 (voir `main.dart` : c'est
  /// celle qui démarre sans arguments).
  static const int mainWindowId = 0;

  /// « Remets cet aperçu dans la fenêtre principale. »
  static const String dockViewer = 'dock_viewer';

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Demande à la fenêtre principale d'accueillir l'aperçu [viewer]
  /// (`'step'` ou `'toolpath'`).
  ///
  /// Retourne `false` si la fenêtre principale a refusé — typiquement parce
  /// qu'elle n'a plus la pièce ou le programme en question — ou si le canal
  /// est injoignable. L'appelant NE DOIT PAS se fermer sur un `false` : il
  /// serait le dernier endroit où l'aperçu existe encore.
  static Future<bool> requestDock(String viewer) async {
    if (!isSupported) return false;
    try {
      final accepted = await DesktopMultiWindow.invokeMethod(
        mainWindowId,
        dockViewer,
        viewer,
      );
      return accepted == true;
    } catch (e) {
      // Canal indisponible (plugin absent, fenêtre principale fermée) : on le
      // signale à l'appelant plutôt que de fermer une fenêtre dans le vide.
      debugPrint('[Fenêtres] retour à la fenêtre principale impossible : $e');
      return false;
    }
  }

  /// Referme la fenêtre appelante.
  ///
  /// Passe par `desktop_multi_window`, qui désigne la fenêtre explicitement —
  /// contrairement à un plugin de gestion de fenêtres, qui agit sur celle
  /// qu'il a adoptée à son initialisation. C'est cette différence qui fermait
  /// l'application entière quand on refermait une fenêtre détachée.
  static Future<void> closeThisWindow() async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      await controller.close();
    } catch (e) {
      debugPrint('[Fenêtres] fermeture impossible : $e');
    }
  }
}
