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

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
    this.activeIndex = 0,
    this.showVectors = false,
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
      ..style.height = '100%';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iframeElement,
    );

    html.window.onMessage.listen((event) {
      // Use dynamic to avoid Map casting issues with JS interop
      final data = event.data;
      if (data != null && data.toString().contains('viewer_ready')) {
        _isReady = true;
        _sendToolpath();
        _updateMachine();
        _toggleVectors();
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
    _updateMachine();
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

    _iframeElement.contentWindow?.postMessage({
      'type': 'load_toolpath',
      'payload': flatList,
    }, '*');
  }

  void _updateMachine() {
    _iframeElement.contentWindow?.postMessage({
      'type': 'update_machine',
      'payload': {
        'mPos': widget.mPos,
        'activeIndex': widget.activeIndex,
      },
    }, '*');
  }

  void _toggleVectors() {
    _iframeElement.contentWindow?.postMessage({
      'type': 'toggle_vectors',
      'payload': widget.showVectors,
    }, '*');
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
