import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/gcode_file.dart';

/// Modèle pour une ligne de G-Code analysée
class AnalyzedGCode {
  final List<String> lines;
  final List<List<double>> toolpath;
  final Map<int, GCodeModalState> modalStates;

  AnalyzedGCode({required this.lines, required this.toolpath, required this.modalStates});
}

/// État modal d'une ligne spécifique
class GCodeModalState {
  final String wcs; // G54-G59
  final bool isRelative; // G90/G91
  final bool isInches; // G20/G21
  final double feedrate;
  final double spindleSpeed;

  GCodeModalState({
    this.wcs = 'G54',
    this.isRelative = false,
    this.isInches = false,
    this.feedrate = 0,
    this.spindleSpeed = 0,
  });
}

/// Parseur G-Code Industriel haute performance.
/// Conçu pour être exécuté dans un Isolate via [compute].
class GCodeParser {
  static Future<AnalyzedGCode> parseLargeFile(String content) async {
    return compute(_parseInternal, content);
  }

  static AnalyzedGCode _parseInternal(String content) {
    final lines = content.split('\n');
    final List<List<double>> toolpath = [];
    final Map<int, GCodeModalState> modalStates = {};

    double lastX = 0, lastY = 0, lastZ = 0, lastA = 0, lastC = 0;
    double lastType = 1.0; // 0: G0, 1: G1/G2/G3
    GCodeModalState currentModal = GCodeModalState();

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].toUpperCase().split(';')[0].trim();
      if (line.isEmpty) continue;

      // --- Extraction de l'état modal ---
      if (line.contains('G54')) currentModal = _updateModal(currentModal, wcs: 'G54');
      if (line.contains('G55')) currentModal = _updateModal(currentModal, wcs: 'G55');
      if (line.contains('G90')) currentModal = _updateModal(currentModal, relative: false);
      if (line.contains('G91')) currentModal = _updateModal(currentModal, relative: true);
      if (line.contains('G20')) currentModal = _updateModal(currentModal, inches: true);
      if (line.contains('G21')) currentModal = _updateModal(currentModal, inches: false);

      modalStates[i] = currentModal;

      // --- Extraction du type de mouvement ---
      if (line.startsWith('G0 ') || line == 'G0') lastType = 0.0;
      else if (line.startsWith('G1 ') || line == 'G1' || line.startsWith('G2 ') || line.startsWith('G3 ')) lastType = 1.0;

      // --- Extraction des coordonnées pour le toolpath ---
      if (line.startsWith('G0') || line.startsWith('G1') || line.startsWith('G2') || line.startsWith('G3') || line.contains('X') || line.contains('Y') || line.contains('Z')) {
        final x = _extractCoord(line, 'X', lastX);
        final y = _extractCoord(line, 'Y', lastY);
        final z = _extractCoord(line, 'Z', lastZ);
        final a = _extractCoord(line, 'A', lastA);
        final c = _extractCoord(line, 'C', lastC);

        toolpath.add([x, y, z, a, c, lastType]);
        
        lastX = x; lastY = y; lastZ = z; lastA = a; lastC = c;
      }
    }

    return AnalyzedGCode(lines: lines, toolpath: toolpath, modalStates: modalStates);
  }

  static double _extractCoord(String line, String axis, double lastVal) {
    final reg = RegExp('$axis([-+]?[0-9]*\\.?[0-9]+)');
    final match = reg.firstMatch(line);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? lastVal;
    }
    return lastVal;
  }

  static GCodeModalState _updateModal(GCodeModalState current, {String? wcs, bool? relative, bool? inches}) {
    return GCodeModalState(
      wcs: wcs ?? current.wcs,
      isRelative: relative ?? current.isRelative,
      isInches: inches ?? current.isInches,
      feedrate: current.feedrate,
      spindleSpeed: current.spindleSpeed,
    );
  }
}
