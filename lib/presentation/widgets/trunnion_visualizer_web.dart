import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrunnionVisualizer extends StatefulWidget {
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
  State<TrunnionVisualizer> createState() => _TrunnionVisualizerState();
}

class _TrunnionVisualizerState extends State<TrunnionVisualizer> {
  late html.IFrameElement _iframeElement;
  late String _viewId;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'three-js-visualizer-${UniqueKey().toString()}';
    
    _iframeElement = html.IFrameElement()
      ..src = 'three_viewer.html'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iframeElement,
    );

    html.window.onMessage.listen((event) {
      if (event.data['type'] == 'viewer_ready') {
        setState(() => _isReady = true);
        _sendToolpath();
        _updateMachine();
        _toggleVectors();
        _sendLimits();
      }
    });
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

  void _sendMessage(dynamic data) {
    _iframeElement.contentWindow?.postMessage(data, '*');
  }

  void _sendToolpath() {
    if (widget.toolpath == null || widget.toolpath!.isEmpty) return;

    // Flatten toolpath for efficient transfer to WebGL
    final flatList = Float32List(widget.toolpath!.length * 6);
    int idx = 0;
    for (final p in widget.toolpath!) {
      flatList[idx++] = p.length > 0 ? p[0] : 0;
      flatList[idx++] = p.length > 1 ? p[1] : 0;
      flatList[idx++] = p.length > 2 ? p[2] : 0;
      flatList[idx++] = p.length > 3 ? p[3] : 0;
      flatList[idx++] = p.length > 4 ? p[4] : 0;
      flatList[idx++] = p.length > 5 ? p[5] : 1.0; 
    }

    _sendMessage({
      'type': 'load_toolpath',
      'payload': flatList,
    });
  }

  void _updateMachine() {
    _sendMessage({
      'type': 'update_machine',
      'payload': {
        'mPos': widget.mPos,
        'activeIndex': widget.activeIndex,
      },
    });
  }

  void _toggleVectors() {
    _sendMessage({
      'type': 'toggle_vectors',
      'payload': widget.showVectors,
    });
  }

  void _sendLimits() {
    _sendMessage({
      'type': 'set_limits',
      'payload': {
        'x': widget.machineLimits[0],
        'y': widget.machineLimits[1],
        'z': widget.machineLimits[2],
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}