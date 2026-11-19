import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Résultat d'une capture visuelle effectuée pour l'agent IA (rendu WebGL 3D
/// Three.js, écran Flutter via [RepaintBoundary], ou caméra ESP32-CAM).
class ViewerSnapshotResult {
  const ViewerSnapshotResult({
    required this.pngBytes,
    required this.source,
    this.width,
    this.height,
    this.metrics = const {},
  });

  final Uint8List pngBytes;

  /// `'webgl_3d'` | `'flutter_screen'` | `'esp32_camera'`.
  final String source;
  final int? width;
  final int? height;

  /// Télémesures exactes extraites de la scène 3D au moment du rendu
  /// (pourcentage de brut voxelisé usiné, couches visibles, angle caméra, etc.).
  final Map<String, dynamic> metrics;
}

/// Poignée enregistrée par chaque instance active du visualiseur 3D
/// (`WindowsTrunnionVisualizer`, `MobileTrunnionVisualizer`, ou doublure de test).
class ViewerSnapshotHandle {
  const ViewerSnapshotHandle({
    required this.id,
    required this.describeScene,
    required this.capture,
  });

  final String id;

  /// Retourne l'état courant des calques (`machine`, `toolpath`, `part`, `workpiece`).
  final Map<String, dynamic> Function() describeScene;

  /// Déclenche un rendu immédiat dans le moteur 3D et retourne l'image PNG.
  final Future<ViewerSnapshotResult?> Function({
    String? cameraPreset,
    Map<String, dynamic>? temporaryScene,
    String? hudBanner,
  }) capture;
}

/// Service centralisant la capture d'écran du jumeau numérique 3D, du parcours
/// d'outil, de l'aperçu CAO et de l'interface Flutter.
///
/// Pourquoi un pont dédié vers Three.js en plus d'un [RepaintBoundary] Flutter :
/// sur Windows, `webview_windows` (WebView2) compose sa surface DirectComposition
/// hors de l'arbre Skia/Impeller de Flutter — `RenderRepaintBoundary.toImage()`
/// ne verrait qu'un rectangle vide à l'emplacement du simulateur 3D. Le pont
/// demande directement au `WebGLRenderer` de dessiner la scène sur un canevas
/// 2D hors-écran (avec fond studio et bandeau télémétrique) et récupère le PNG.
class ViewerSnapshotService {
  final GlobalKey screenRepaintBoundaryKey =
      GlobalKey(debugLabel: 'forgeronScreenRepaintBoundary');

  final Map<String, ViewerSnapshotHandle> _handles = {};

  void register(ViewerSnapshotHandle handle) {
    // Réinsère en fin de Map pour garder le visualiseur le plus récemment monté
    // en priorité (ex: panneau d'aperçu ouvert dans la console IA).
    _handles.remove(handle.id);
    _handles[handle.id] = handle;
  }

  void unregister(String id) {
    _handles.remove(id);
  }

  bool get has3dHandle => _handles.isNotEmpty;
  int get handleCount => _handles.length;

  /// Sélectionne le visualiseur 3D le mieux adapté à la cible demandée.
  ViewerSnapshotHandle? selectHandle(String target) {
    if (_handles.isEmpty) return null;
    final candidates = _handles.values.toList().reversed.toList();

    bool flag(ViewerSnapshotHandle h, String key) =>
        h.describeScene()[key] == true;

    switch (target) {
      case 'simulator':
        for (final h in candidates) {
          if (flag(h, 'machine')) return h;
        }
        return candidates.first;
      case 'toolpath':
        for (final h in candidates) {
          if (flag(h, 'toolpath') && !flag(h, 'machine')) return h;
        }
        for (final h in candidates) {
          if (flag(h, 'toolpath')) return h;
        }
        return candidates.first;
      case 'part':
        for (final h in candidates) {
          if (flag(h, 'part') && !flag(h, 'machine')) return h;
        }
        for (final h in candidates) {
          if (flag(h, 'part')) return h;
        }
        return candidates.first;
      default:
        return candidates.first;
    }
  }

  /// Capture une image PNG depuis le moteur WebGL Three.js actif.
  Future<ViewerSnapshotResult?> capture3d({
    required String target,
    String? cameraPreset,
    Map<String, dynamic>? temporaryScene,
    String? hudBanner,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final handle = selectHandle(target);
    if (handle == null) return null;
    try {
      return await handle
          .capture(
            cameraPreset: cameraPreset,
            temporaryScene: temporaryScene,
            hudBanner: hudBanner,
          )
          .timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Capture l'interface Flutter complète (ou le panneau courant) via
  /// [screenRepaintBoundaryKey]. Sert à la fois pour `target == 'screen'` et
  /// comme repli si aucun WebView 3D n'est monté.
  Future<ViewerSnapshotResult?> captureScreen({
    double pixelRatio = 1.25,
  }) async {
    try {
      final ctx = screenRepaintBoundaryKey.currentContext;
      if (ctx == null) return null;
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      // Si un frame est en attente de peinture en mode test/debug, attend la fin
      // du frame courant avant de lire la couche raster.
      if (renderObject.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      final int w = image.width;
      final int h = image.height;
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      return ViewerSnapshotResult(
        pngBytes: bytes,
        source: 'flutter_screen',
        width: w,
        height: h,
        metrics: {
          'width': w,
          'height': h,
          'pixelRatio': pixelRatio,
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// Décode une URL `data:image/png;base64,...` renvoyée par `canvas.toDataURL`.
  static Uint8List? decodeDataUrlPng(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final comma = dataUrl.indexOf(',');
    final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}

final viewerSnapshotServiceProvider = Provider<ViewerSnapshotService>((ref) {
  return ViewerSnapshotService();
});

