import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../application/providers/theme_provider.dart';

/// Visualiseur 3D pour **Android / iOS** (`webview_flutter`).
///
/// Auparavant, ces plateformes tombaient sur l'implémentation `webview_windows`
/// (via `dart.library.io`, vrai sur Windows *et* Android) : le plugin n'existe
/// pas sur Android, donc le simulateur était mort dans l'APK.
///
/// Même mécanisme que la version Windows : le HTML est chargé depuis le bundle
/// et three.js y est **inliné**, pour un fonctionnement 100 % hors ligne.
class MobileTrunnionVisualizer extends ConsumerStatefulWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;
  final List<double> machineLimits;

  const MobileTrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
    this.machineLimits = const [200.0, 300.0, 150.0],
  });

  @override
  ConsumerState<MobileTrunnionVisualizer> createState() =>
      _MobileTrunnionVisualizerState();
}

class _MobileTrunnionVisualizerState
    extends ConsumerState<MobileTrunnionVisualizer> {
  late final WebViewController _controller;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      // Canal JS → Dart : la page signale qu'elle est prête.
      ..addJavaScriptChannel(
        'ForgeronChannel',
        onMessageReceived: (msg) {
          try {
            final data = jsonDecode(msg.message);
            if (data['type'] == 'viewer_ready') {
              if (mounted) setState(() => _isReady = true);
              _sendToolpath();
              _updateMachine();
              _toggleVectors();
              _sendLimits();
            }
          } catch (e) {
            debugPrint('[Visualizer] message illisible : $e');
          }
        },
      );
    _loadViewer();
  }

  Future<void> _loadViewer() async {
    try {
      String html = await rootBundle.loadString('web/three_viewer.html');
      final three = await rootBundle.loadString('web/js/three.min.js');
      final orbit = await rootBundle.loadString('web/js/OrbitControls.js');

      // Inline des scripts : pas de requête réseau, fonctionne hors ligne.
      html = html.replaceFirst(
        '<script src="js/three.min.js"></script>',
        '<script>$three</script>',
      );
      html = html.replaceFirst(
        '<script src="js/OrbitControls.js"></script>',
        '<script>$orbit</script>',
      );

      await _controller.loadHtmlString(html);
    } catch (e) {
      debugPrint('[Visualizer] échec du chargement : $e');
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Dart → JS : la page expose `handleMessage(data)` au scope global.
  void _post(Map<String, dynamic> data) {
    if (!_isReady) return;
    _controller.runJavaScript('handleMessage(${jsonEncode(data)})');
  }

  @override
  void didUpdateWidget(covariant MobileTrunnionVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReady) return;

    if (oldWidget.toolpath != widget.toolpath) _sendToolpath();
    if (oldWidget.showVectors != widget.showVectors) _toggleVectors();
    if (oldWidget.machineLimits != widget.machineLimits) _sendLimits();
    _updateMachine();
  }

  void _sendToolpath() {
    final tp = widget.toolpath;
    if (tp == null || tp.isEmpty) return;
    final payload = tp
        .map((p) => [
              p.length > 0 ? p[0] : 0.0,
              p.length > 1 ? p[1] : 0.0,
              p.length > 2 ? p[2] : 0.0,
              p.length > 3 ? p[3] : 0.0,
              p.length > 4 ? p[4] : 0.0,
              p.length > 5 ? p[5] : 1.0,
            ])
        .toList();
    _post({'type': 'load_toolpath', 'payload': payload});
  }

  void _updateMachine() => _post({
        'type': 'update_machine',
        'payload': {'mPos': widget.mPos, 'activeIndex': widget.activeIndex},
      });

  void _toggleVectors() =>
      _post({'type': 'toggle_vectors', 'payload': widget.showVectors});

  void _sendLimits() => _post({
        'type': 'set_limits',
        'payload': {
          'x': widget.machineLimits[0],
          'y': widget.machineLimits[1],
          'z': widget.machineLimits[2],
        },
      });

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Simulateur 3D indisponible\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }

    final isDark = isDarkTheme(context, ref.watch(themeModeProvider));
    if (_isReady) {
      _post({
        'type': 'set_theme',
        'payload': {'isDark': isDark},
      });
    }

    return WebViewWidget(controller: _controller);
  }
}
