import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../application/providers/simulation_provider.dart';
import '../../application/providers/theme_provider.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/utils/three_viewer_asset_cache.dart';
import 'viewer_scene.dart';
import 'viewer_theme_payload.dart';
import '../../core/i18n/app_localizations.dart';

/// Visualiseur 3D pour **Windows** (`webview_windows` / WebView2).
class WindowsTrunnionVisualizer extends ConsumerStatefulWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;

  /// Courses X/Y/Z reelles (mm). `null` = inconnues (aucune enveloppe).
  final List<double>? machineLimits;

  /// Maillage de la pièce chargée (`{vertices: [...], indices: [...]}`).
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
          final data = message is String ? jsonDecode(message) : message;
          if (data is Map &&
              (data['type'] == 'viewer_ready' || data['type'] == 'ready')) {
            _markReady();
          }
        } catch (e) {
          debugPrint('[Visualizer] message illisible : $e');
        }
      });

      _loadingSub = _controller.loadingState.listen((s) {
        if (s == LoadingState.navigationCompleted) _markReady();
      });

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      final html = await ThreeViewerAssetCache.getInlinedHtml();
      await _controller.loadStringContent(html);

      if (mounted) setState(() => _isInitialized = true);
    } on PlatformException catch (e) {
      debugPrint('[Visualizer] échec d\'initialisation : $e');
      if (mounted) setState(() => _error = e.message ?? '$e');
    } catch (e) {
      debugPrint('[Visualizer] échec de chargement : $e');
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _markReady() {
    if (_isReady || !mounted) return;
    setState(() => _isReady = true);
    _lastThemeSent = null;
    _sendScene();
    _sendStockConfig(ref.read(simulationProvider));
    _sendMesh();
    _sendToolpath();
    _sendLimits();
    _toggleVectors();
    _updateMachine();
  }

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
    if (!identical(oldWidget.toolpath, widget.toolpath)) _sendToolpath();
    if (oldWidget.showVectors != widget.showVectors) _toggleVectors();
    if (!listEquals(oldWidget.machineLimits, widget.machineLimits)) {
      _sendLimits();
    }
    if (oldWidget.activeIndex != widget.activeIndex ||
        !listEquals(oldWidget.mPos, widget.mPos)) {
      _updateMachine();
    }
  }

  void _sendScene() =>
      _post({'type': 'set_scene', 'payload': widget.scene.toJson()});

  void _sendStockConfig(SimulationState sim) {
    _post({
      'type': 'configure_stock',
      'payload': {
        'shape': sim.stockShape.wire,
        'dimensions': sim.stockDimensions,
        'toolDiameter': sim.toolDiameter,
      },
    });
    _post({'type': 'set_enclosure', 'payload': sim.showEnclosure});
  }

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
    if (tp == null || tp.isEmpty) {
      _post({'type': 'clear_toolpath'});
      return;
    }
    _post({
      'type': 'load_toolpath',
      'payload': ThreeViewerAssetCache.flattenToolpath(tp),
    });
  }

  void _updateMachine([List<double>? overrideMPos, int? overrideIdx]) {
    final sim = ref.read(simulationProvider);
    final useSim = overrideMPos != null ||
        sim.isSimulating ||
        sim.status == SimulationStatus.completed;
    final pos = overrideMPos ?? (useSim ? sim.simulatedMPos : widget.mPos);
    final idx =
        overrideIdx ?? (useSim ? sim.currentToolpathIndex : widget.activeIndex);
    _post({
      'type': 'update_machine',
      'payload': {'mPos': pos, 'activeIndex': idx},
    });
  }

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
    ref.listen<SimulationState>(simulationProvider, (prev, next) {
      if (!_isReady) return;
      if (prev?.stockResetSeq != next.stockResetSeq ||
          prev?.toolDiameter != next.toolDiameter) {
        _sendStockConfig(next);
      }
      if (prev?.showEnclosure != next.showEnclosure) {
        _post({'type': 'set_enclosure', 'payload': next.showEnclosure});
      }
      if (prev?.cameraCommandSeq != next.cameraCommandSeq) {
        _post({'type': 'set_camera_preset', 'payload': next.cameraPreset});
      }
      if (next.isSimulating ||
          next.status == SimulationStatus.completed ||
          (prev?.isSimulating == true && !next.isSimulating)) {
        _updateMachine(next.simulatedMPos, next.currentToolpathIndex);
      }
    });

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            tr('Simulateur 3D indisponible\n{}', [_error]),
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
