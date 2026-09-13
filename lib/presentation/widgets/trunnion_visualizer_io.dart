import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'trunnion_visualizer_windows.dart';
import 'trunnion_visualizer_mobile.dart';
import 'viewer_scene.dart';
import '../../core/i18n/app_localizations.dart';

/// Aiguilleur du visualiseur 3D pour les plateformes non-web.
///
/// `dart.library.io` est vrai sur **Windows ET Android/iOS** : l'export
/// conditionnel seul ne peut donc pas les distinguer. C'est ce qui envoyait
/// Android sur l'implémentation `webview_windows` — un plugin qui n'existe pas
/// sur Android, d'où un simulateur mort dans l'APK.
///
/// On tranche ici à l'exécution :
///  - Windows      → `webview_windows`
///  - Android/iOS  → `webview_flutter`
class TrunnionVisualizer extends StatelessWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;
  /// Courses X/Y/Z reelles (mm). `null` = inconnues : le viewer ne dessine
  /// alors aucune enveloppe, plutot qu'une boite inventee.
  final List<double>? machineLimits;

  /// Maillage de la pièce chargée (`{vertices: [...], indices: [...]}`, tel
  /// que produit par `pipeline/step_preview.py`). `null` = aucune pièce.
  final Map<String, dynamic>? partMesh;

  /// Ce que la scène montre — voir [ViewerScene].
  final ViewerScene scene;

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
    this.machineLimits,
    this.partMesh,
    this.scene = const ViewerScene(),
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return WindowsTrunnionVisualizer(
        mPos: mPos,
        targetPos: targetPos,
        toolpath: toolpath,
        activeIndex: activeIndex,
        showVectors: showVectors,
        machineLimits: machineLimits,
        partMesh: partMesh,
        scene: scene,
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return MobileTrunnionVisualizer(
        mPos: mPos,
        targetPos: targetPos,
        toolpath: toolpath,
        activeIndex: activeIndex,
        showVectors: showVectors,
        machineLimits: machineLimits,
        partMesh: partMesh,
        scene: scene,
      );
    }

    // Linux / macOS : aucun WebView embarqué n'est câblé pour l'instant.
    return Center(
      child: Text(
        tr('Simulateur 3D non supporté sur cette plateforme'),
        style: TextStyle(fontSize: 11),
      ),
    );
  }
}
