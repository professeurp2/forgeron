import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:typed_data';

class TrunnionVisualizer extends StatefulWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;
  final int activeIndex;
  final bool showVectors;
  final List<double> machineLimits; // [Lx, Ly, Lz]

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
  State<TrunnionVisualizer> createState() => _TrunnionVisualizerState();
}

class _TrunnionVisualizerState extends State<TrunnionVisualizer> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      await _controller.initialize();
      
      // We need to handle the message from JS. 
      // In three_viewer.html, we'll add support for window.chrome.webview.postMessage
      _controller.webMessage.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'viewer_ready') {
            if (mounted) {
              setState(() {
                _isReady = true;
              });
            }
            _sendToolpath();
            _updateMachine();
            _toggleVectors();
            _sendLimits();
          }
        } catch (e) {
          debugPrint('Error parsing web message: $e');
        }
      });

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      // Load the local HTML file and inject scripts for true offline support
      String htmlContent = await rootBundle.loadString('web/three_viewer.html');
      final threeJs = await rootBundle.loadString('web/js/three.min.js');
      final orbitControls = await rootBundle.loadString('web/js/OrbitControls.js');

      // Replace relative script tags with inlined scripts
      htmlContent = htmlContent.replaceFirst(
        '<script src="js/three.min.js"></script>',
        '<script>$threeJs</script>',
      );
      htmlContent = htmlContent.replaceFirst(
        '<script src="js/OrbitControls.js"></script>',
        '<script>$orbitControls</script>',
      );

      await _controller.loadStringContent(htmlContent);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Error initializing webview: $e');
    }
  }

  @override
  void didUpdateWidget(covariant TrunnionVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReady) return;

    if (oldWidget.toolpath != widget.toolpath) {
      _sendToolpath();
    }
    if (oldWidget.showVectors != widget.showVectors) {
      _toggleVectors();
    }
    if (oldWidget.machineLimits != widget.machineLimits) {
      _sendLimits();
    }
    _updateMachine();
  }

  void _sendToolpath() {
    if (widget.toolpath == null || widget.toolpath!.isEmpty) return;

    // WebView2 message size might be limited or prefer JSON. 
    // Float32List is better but JSON is safer for a quick fix.
    final payload = widget.toolpath!.map((p) => [
      p.length > 0 ? p[0] : 0.0,
      p.length > 1 ? p[1] : 0.0,
      p.length > 2 ? p[2] : 0.0,
      p.length > 3 ? p[3] : 0.0,
      p.length > 4 ? p[4] : 0.0,
      p.length > 5 ? p[5] : 1.0,
    ]).toList();

    _controller.postWebMessage(jsonEncode({
      'type': 'load_toolpath',
      'payload': payload,
    }));
  }

  void _updateMachine() {
    _controller.postWebMessage(jsonEncode({
      'type': 'update_machine',
      'payload': {
        'mPos': widget.mPos,
        'activeIndex': widget.activeIndex,
      },
    }));
  }

  void _toggleVectors() {
    _controller.postWebMessage(jsonEncode({
      'type': 'toggle_vectors',
      'payload': widget.showVectors,
    }));
  }

  void _sendLimits() {
    _controller.postWebMessage(jsonEncode({
      'type': 'set_limits',
      'payload': {
        'x': widget.machineLimits[0],
        'y': widget.machineLimits[1],
        'z': widget.machineLimits[2],
      },
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Webview(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}