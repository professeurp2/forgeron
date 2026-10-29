import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Cache mémoire partagé pour le moteur 3D Three.js (`web/three_viewer.html`),
/// ses scripts (`three.min.js`, `OrbitControls.js`) et le maillage CAO binaire
/// de l'axe A (`assets/A-axis.STL`).
///
/// Évite de relire ~750 Ko depuis `rootBundle` et de refaire les `replaceFirst`
/// sur des chaînes de plusieurs centaines de kilo-octets à chaque montage du
/// visualiseur 3D (changement d'onglet, ouverture d'un panneau IA, etc.).
class ThreeViewerAssetCache {
  ThreeViewerAssetCache._();

  static String? _cachedInlinedHtml;
  static Future<String>? _pendingLoad;

  /// Retourne le HTML complet avec `three.min.js`, `OrbitControls.js` et
  /// `A-axis.STL` (en Base64) injectés en ligne.
  static Future<String> getInlinedHtml() {
    if (_cachedInlinedHtml != null) {
      return Future.value(_cachedInlinedHtml!);
    }
    return _pendingLoad ??= _loadAndAssemble();
  }

  static Future<String> _loadAndAssemble() async {
    final results = await Future.wait<dynamic>([
      rootBundle.loadString('web/three_viewer.html'),
      rootBundle.loadString('web/js/three.min.js'),
      rootBundle.loadString('web/js/OrbitControls.js'),
      _loadStlBase64Safe('assets/A-axis.STL'),
    ]);

    final html = results[0] as String;
    final threeJs = results[1] as String;
    final orbitJs = results[2] as String;
    final aAxisStlB64 = results[3] as String;

    final assembled = html
        .replaceFirst(
          '<script src="js/three.min.js"></script>',
          '<script>$threeJs</script>',
        )
        .replaceFirst(
          '<script src="js/OrbitControls.js"></script>',
          '<script>$orbitJs</script>',
        )
        .replaceFirst(
          '__A_AXIS_STL_BASE64__',
          aAxisStlB64,
        );

    _cachedInlinedHtml = assembled;
    _pendingLoad = null;
    return assembled;
  }

  static Future<String> _loadStlBase64Safe(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return base64Encode(bytes);
    } catch (_) {
      return '';
    }
  }

  /// Sérialise un parcours d'outil `List<List<double>>` sous forme de tableau
  /// 1D plat `[x0, y0, z0, a0, c0, type0, x1, ...]` arrondi au millième.
  ///
  /// Réduit de ~40 % la taille du JSON transmis au WebView et élimine
  /// l'allocation de 30 000 sous-listes intermédiaires.
  static List<double> flattenToolpath(List<List<double>> pts) {
    final flat = List<double>.filled(pts.length * 6, 0.0, growable: false);
    int k = 0;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      flat[k++] = (p[0] * 1000).roundToDouble() / 1000;
      flat[k++] = (p[1] * 1000).roundToDouble() / 1000;
      flat[k++] = (p[2] * 1000).roundToDouble() / 1000;
      flat[k++] = p.length > 3 ? (p[3] * 100).roundToDouble() / 100 : 0.0;
      flat[k++] = p.length > 4 ? (p[4] * 100).roundToDouble() / 100 : 0.0;
      flat[k++] = p.length > 5 ? p[5] : 1.0;
    }
    return flat;
  }
}
