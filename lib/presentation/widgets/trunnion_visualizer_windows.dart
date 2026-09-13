import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../application/providers/theme_provider.dart';
import '../../core/theme/forgeron_colors.dart';
import 'viewer_scene.dart';
import 'viewer_theme_payload.dart';

/// Visualiseur 3D pour **Windows** (`webview_windows` / WebView2).
///
/// Historique du bug corrigé ici : la page `three_viewer.html` annonçait sa
/// disponibilité par `window.ForgeronChannel`, le canal JS de
/// `webview_flutter` (Android/iOS). Cet objet n'existe pas sous WebView2 —
/// l'annonce ne partait donc jamais, `_isReady` restait faux, et comme
/// TOUT l'envoi (thème, parcours, position, courses) était conditionné à ce
/// signal, la scène restait une page noire et vide. La page annonce désormais
/// aussi via `window.chrome.webview` ; et par sécurité on considère également
/// la fin de navigation comme un signal de disponibilité.
///
/// Deuxième correction : le sens Dart → page passe par `executeScript`, qui
/// appelle directement `window.handleMessage(...)` — exactement ce que fait la
/// version Android/iOS, qui marche. `postWebMessage` visait `window`, alors
/// que WebView2 délivre ses messages sur `window.chrome.webview` : les
/// messages partaient dans le vide.
class WindowsTrunnionVisualizer extends ConsumerStatefulWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;

  /// Courses X/Y/Z reelles (mm). `null` = inconnues (aucune enveloppe).
  final List<double>? machineLimits;

  /// Maillage de la pièce chargée (`{vertices: [...], indices: [...]}`, tel
  /// que produit par `pipeline/step_preview.py`). `null` = aucune pièce.
  final Map<String, dynamic>? partMesh;

  /// Ce que la scène montre — voir [ViewerScene].
  final ViewerScene scene;

  const WindowsTrunnionVisualizer({
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
  ConsumerState<WindowsTrunnionVisualizer> createState() =>
      _WindowsTrunnionVisualizerState();
}

class _WindowsTrunnionVisualizerState
    extends ConsumerState<WindowsTrunnionVisualizer> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  bool _isReady = false;
  String? _error;

  /// Dernière palette envoyée : `build` est appelé à chaque image, il ne faut
  /// pas re-pousser le même thème en boucle dans la WebView.
  String? _lastThemeSent;

  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<LoadingState>? _loadingSub;

  @override
  void initState() {
    super.initState();
    unawaited(_initPlatformState());
  }

  Future<void> _initPlatformState() async {
    try {
      await _controller.initialize();

      _messageSub = _controller.webMessage.listen((message) {
        try {
          // Selon la version du plugin, la charge arrive déjà décodée ou
          // encore sous forme de texte JSON : on accepte les deux.
          final data = message is String ? jsonDecode(message) : message;
          if (data is Map && data['type'] == 'viewer_ready') _markReady();
        } catch (e) {
          debugPrint('[Visualizer] message illisible : $e');
        }
      });

      // Filet : si l'annonce de la page n'arrive pas (pont bloqué, page
      // servie autrement), la fin de navigation suffit — le script inline
      // s'exécute pendant l'analyse du document, donc `handleMessage` existe
      // déjà à ce moment-là.
      _loadingSub = _controller.loadingState.listen((s) {
        if (s == LoadingState.navigationCompleted) _markReady();
      });

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      await _controller.loadStringContent(await _viewerHtml());

      if (mounted) setState(() => _isInitialized = true);
    } on PlatformException catch (e) {
      debugPrint('[Visualizer] échec d\'initialisation : $e');
      if (mounted) setState(() => _error = e.message ?? '$e');
    } catch (e) {
      debugPrint('[Visualizer] échec de chargement : $e');
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// La page et ses deux scripts sont **inlinés** : aucune requête réseau, le
  /// visualiseur fonctionne hors ligne (atelier sans Internet).
  Future<String> _viewerHtml() async {
    var html = await rootBundle.loadString('web/three_viewer.html');
    final three = await rootBundle.loadString('web/js/three.min.js');
    final orbit = await rootBundle.loadString('web/js/OrbitControls.js');
    html = html.replaceFirst(
      '<script src="js/three.min.js"></script>',
      '<script>$three</script>',
    );
    html = html.replaceFirst(
      '<script src="js/OrbitControls.js"></script>',
      '<script>$orbit</script>',
    );
    return html;
  }

  /// Premier signal de disponibilité reçu : on pousse tout l'état d'un coup.
  /// Les annonces suivantes (la page en répète quelques-unes) sont ignorées.
  void _markReady() {
    if (_isReady || !mounted) return;
    setState(() => _isReady = true);
    _sendScene();
    _sendMesh();
    _sendToolpath();
    _sendLimits();
    _toggleVectors();
    _updateMachine();
    _lastThemeSent = null; // force le renvoi du thème au prochain build
  }

  /// Dart → page : la page expose `handleMessage(data)` au scope global.
  void _post(Map<String, dynamic> data) {
    if (!_isReady) return;
    unawaited(
      _controller
          .executeScript('window.handleMessage(${jsonEncode(data)})')
          .catchError((Object e) {
        debugPrint('[Visualizer] envoi refusé (${data['type']}) : $e');
        return null;
      }),
    );
  }

  @override
  void didUpdateWidget(covariant WindowsTrunnionVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReady) return;

    if (oldWidget.scene != widget.scene) _sendScene();
    if (!identical(oldWidget.partMesh, widget.partMesh)) _sendMesh();
    if (oldWidget.toolpath != widget.toolpath) _sendToolpath();
    if (oldWidget.showVectors != widget.showVectors) _toggleVectors();
    if (oldWidget.machineLimits != widget.machineLimits) _sendLimits();
    _updateMachine();
  }

  void _sendScene() => _post({'type': 'set_scene', 'payload': widget.scene.toJson()});

  void _sendMesh() {
    final mesh = widget.partMesh;
    if (mesh == null) {
      _post({'type': 'clear_mesh'});
      return;
    }
    _post({'type': 'load_mesh', 'payload': mesh});
  }

  void _sendToolpath() {
    final tp = widget.toolpath;
    if (tp == null || tp.isEmpty) return;
    _post({'type': 'load_toolpath', 'payload': _toolpathPayload(tp)});
  }

  void _updateMachine() => _post({
        'type': 'update_machine',
        'payload': {'mPos': widget.mPos, 'activeIndex': widget.activeIndex},
      });

  void _toggleVectors() =>
      _post({'type': 'toggle_vectors', 'payload': widget.showVectors});

  void _sendLimits() {
    final l = widget.machineLimits;
    _post({
      'type': 'set_limits',
      'payload': l == null ? null : {'x': l[0], 'y': l[1], 'z': l[2]},
    });
  }

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
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = isDarkTheme(context, ref.watch(themeModeProvider));
    if (_isReady) {
      final payload = jsonEncode(viewerThemePayload(context.fc, isDark));
      if (payload != _lastThemeSent) {
        _lastThemeSent = payload;
        _post({'type': 'set_theme', 'payload': jsonDecode(payload)});
      }
    }

    return Webview(_controller);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _loadingSub?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

/// Met le parcours à plat, en six colonnes par point (x, y, z, a, c, type) :
/// le format que `loadToolpath` attend côté page. Partagé mot pour mot avec la
/// version Android/iOS.
List<List<double>> _toolpathPayload(List<List<double>> toolpath) {
  return [
    for (final p in toolpath)
      [
        p.isNotEmpty ? p[0] : 0.0,
        p.length > 1 ? p[1] : 0.0,
        p.length > 2 ? p[2] : 0.0,
        p.length > 3 ? p[3] : 0.0,
        p.length > 4 ? p[4] : 0.0,
        p.length > 5 ? p[5] : 1.0,
      ],
  ];
}
