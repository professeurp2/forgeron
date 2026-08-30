import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'trunnion_visualizer_windows.dart';
import 'trunnion_visualizer_mobile.dart';
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
  final List<double> machineLimits;

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
    this.machineLimits = const [200.0, 300.0, 150.0],
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
