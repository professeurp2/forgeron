import 'dart:async';
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

  /// L'identifiant de CETTE fenêtre, posé une fois au démarrage par
  /// `main.dart` quand le moteur reconnaît une fenêtre détachée (arguments
  /// `["multi_window", windowId, ...]`).
  ///
  /// desktop_multi_window 0.2.1 n'offre aucun moyen de le redemander après
  /// coup — pas de `WindowController.fromCurrentEngine()` (cette méthode
  /// n'existe que dans la réécriture 0.3.x, incompatible, voir
  /// pubspec.yaml) — donc il faut le conserver depuis les arguments de
  /// `main()`, qui sont la seule source.
  static int? _currentWindowId;

  static void bindCurrentWindow(int windowId) {
    _currentWindowId = windowId;
  }

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
    final id = _currentWindowId;
    if (id == null) {
      debugPrint('[Fenêtres] fermeture impossible : identifiant de fenêtre inconnu');
      return;
    }
    try {
      await WindowController.fromWindowId(id).close();
    } catch (e) {
      debugPrint('[Fenêtres] fermeture impossible : $e');
    }
  }

  /// Attend qu'une fenêtre détachée soit VRAIMENT refermée — confirmé par le
  /// moteur natif (`getAllSubWindowIds`, interrogé à intervalles courts), pas
  /// un délai arbitraire. desktop_multi_window 0.2.1 n'expose aucun
  /// événement de cycle de vie des fenêtres (`onWindowsChanged` n'existe que
  /// dans la réécriture 0.3.x, incompatible, voir pubspec.yaml) — un sondage
  /// bref est la seule option.
  ///
  /// Toutes les fenêtres 3D (aperçu STEP, parcours d'outil, et la vue logée
  /// dans la fenêtre principale) partagent un seul environnement WebView2 par
  /// process (voir third_party/webview_windows) pour que plusieurs vues
  /// puissent exister l'une après l'autre sans l'erreur « platform not
  /// supported ». Mais en créer une pendant qu'une autre se détruit encore
  /// fait s'entrechoquer les deux opérations sur ces ressources partagées —
  /// plantage natif dans webview_windows_plugin.dll (constaté sur fichier de
  /// plantage), ou pire, fermeture de l'application entière (constaté aussi).
  /// D'où la règle stricte : une seule fenêtre 3D vivante à la fois, et
  /// personne n'en ouvre une nouvelle sans avoir la confirmation — pas
  /// l'espoir — que la précédente a disparu.
  static Future<void> waitUntilWindowClosed(
    int windowId, {
    Duration timeout = const Duration(seconds: 3),
    Duration pollInterval = const Duration(milliseconds: 120),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (await _stillOpen(windowId)) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future.delayed(pollInterval);
    }
  }

  static Future<bool> _stillOpen(int windowId) async {
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      return ids.contains(windowId);
    } catch (_) {
      // Canal injoignable : on ne peut pas confirmer la fermeture, mais
      // bloquer indéfiniment serait pire — le filet de sécurité (timeout)
      // prendra le relais de toute façon.
      return false;
    }
  }
}
