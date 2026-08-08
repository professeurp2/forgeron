import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Modèle pour une ligne de G-Code analysée
class AnalyzedGCode {
  final List<String> lines;
  final List<List<double>> toolpath;
  final Map<int, GCodeModalState> modalStates;

  /// Pour chaque point de [toolpath], l'index de la ligne brute (dans
  /// [lines]) qui l'a produit. Nécessaire car [toolpath] ne contient qu'un
  /// point par ligne de MOUVEMENT — les lignes vides/commentaires/M-codes
  /// n'y figurent pas, donc `toolpath.length` < `lines.length` en général et
  /// on ne peut pas indexer l'un avec l'index de l'autre directement.
  final List<int> toolpathLineIndices;

  AnalyzedGCode({
    required this.lines,
    required this.toolpath,
    required this.modalStates,
    this.toolpathLineIndices = const [],
  });
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

  // Mot de mouvement G0/G1/G2/G3 en tant que MOT ENTIER : le `(?![0-9])` évite
  // que G17/G21/G28… soient pris pour G1/G2 (bug de préfixe).
  static final RegExp _motionWord = RegExp(r'G0*([0-3])(?![0-9])');
  // Présence d'un axe avec une valeur (pour savoir si la ligne bouge).
  static final RegExp _hasAxis = RegExp(r'[XYZAC]\s*[-+]?\.?[0-9]');
  static final RegExp _parenComment = RegExp(r'\([^)]*\)');

  static AnalyzedGCode _parseInternal(String content) {
    final lines = content.split('\n');
    final List<List<double>> toolpath = [];
    final List<int> toolpathLineIndices = [];
    final Map<int, GCodeModalState> modalStates = {};

    double lastX = 0, lastY = 0, lastZ = 0, lastA = 0, lastC = 0;
    int motion = 0; // groupe modal de mouvement : 0=G0, 1=G1, 2=G2, 3=G3
    int plane = 17; // plan actif : 17=XY, 18=ZX, 19=YZ
    GCodeModalState currentModal = GCodeModalState();

    for (int i = 0; i < lines.length; i++) {
      // Retire les commentaires ( ... ) ET ; ... avant toute analyse : sinon un
      // « X » dans un commentaire (« 10MM X 90DEG ») créerait un point fantôme.
      String line = lines[i]
          .toUpperCase()
          .replaceAll(_parenComment, ' ')
          .split(';')[0]
          .trim();
      if (line.isEmpty) continue;

      // --- État modal ---
      if (line.contains('G54')) currentModal = _updateModal(currentModal, wcs: 'G54');
      if (line.contains('G55')) currentModal = _updateModal(currentModal, wcs: 'G55');
      if (line.contains('G90')) currentModal = _updateModal(currentModal, relative: false);
      if (line.contains('G91')) currentModal = _updateModal(currentModal, relative: true);
      if (line.contains('G20')) currentModal = _updateModal(currentModal, inches: true);
      if (line.contains('G21')) currentModal = _updateModal(currentModal, inches: false);
      if (line.contains('G17')) plane = 17;
      if (line.contains('G18')) plane = 18;
      if (line.contains('G19')) plane = 19;
      modalStates[i] = currentModal;

      // --- Mode de mouvement (modal) ---
      final mm = _motionWord.firstMatch(line);
      if (mm != null) motion = int.parse(mm.group(1)!);

      // Pas de mouvement si aucun axe présent sur la ligne.
      if (!_hasAxis.hasMatch(line)) continue;

      final x = _extractCoord(line, 'X', lastX, currentModal, isLinear: true);
      final y = _extractCoord(line, 'Y', lastY, currentModal, isLinear: true);
      final z = _extractCoord(line, 'Z', lastZ, currentModal, isLinear: true);
      final a = _extractCoord(line, 'A', lastA, currentModal, isLinear: false);
      final c = _extractCoord(line, 'C', lastC, currentModal, isLinear: false);
      final type = motion == 0 ? 0.0 : 1.0;

      if (motion == 2 || motion == 3) {
        // Arc G2 (horaire) / G3 (anti-horaire) : on INTERPOLE la courbe en
        // plusieurs segments, sinon un arc s'affiche comme une corde droite.
        _emitArc(
          toolpath, toolpathLineIndices, i, plane, motion,
          lastX, lastY, lastZ, x, y, z, a, c,
          _offset(line, 'I', currentModal),
          _offset(line, 'J', currentModal),
          _offset(line, 'K', currentModal),
          _offset(line, 'R', currentModal),
        );
      } else {
        toolpath.add([x, y, z, a, c, type]);
        toolpathLineIndices.add(i);
      }

      lastX = x; lastY = y; lastZ = z; lastA = a; lastC = c;
    }

    return AnalyzedGCode(
      lines: lines,
      toolpath: toolpath,
      modalStates: modalStates,
      toolpathLineIndices: toolpathLineIndices,
    );
  }

  /// Offset d'arc (I/J/K) ou rayon (R) présent sur la ligne, converti en mm si
  /// pouces. `null` si absent.
  static double? _offset(String line, String axis, GCodeModalState modal) {
    final m = RegExp('$axis([-+]?[0-9]*\\.?[0-9]+)').firstMatch(line);
    if (m == null) return null;
    var v = double.tryParse(m.group(1)!) ?? 0.0;
    if (modal.isInches) v *= 25.4;
    return v;
  }

  /// Interpole un arc en segments (~10°/segment) et ajoute les points au
  /// toolpath. Gère les plans G17/G18/G19, les hélices (interpolation linéaire
  /// du 3ᵉ axe), le format centre (I/J/K) et le format rayon (R).
  static void _emitArc(
    List<List<double>> toolpath,
    List<int> indices,
    int lineIndex,
    int plane,
    int motion,
    double sx, double sy, double sz,
    double ex, double ey, double ez,
    double a, double c,
    double? iOff, double? jOff, double? kOff, double? rOff,
  ) {
    // Indices des axes selon le plan : (u, v) = plan de l'arc, w = axe hélice.
    late int u, v, w;
    late double offU, offV;
    switch (plane) {
      case 18: // ZX
        u = 2; v = 0; w = 1; offU = kOff ?? 0; offV = iOff ?? 0;
        break;
      case 19: // YZ
        u = 1; v = 2; w = 0; offU = jOff ?? 0; offV = kOff ?? 0;
        break;
      default: // 17 : XY
        u = 0; v = 1; w = 2; offU = iOff ?? 0; offV = jOff ?? 0;
    }
    final start = [sx, sy, sz];
    final end = [ex, ey, ez];

    double cu, cv;
    if (iOff == null && jOff == null && kOff == null && rOff != null) {
      // Format RAYON : centre calculé (formule type grbl).
      final xd = end[u] - start[u];
      final yd = end[v] - start[v];
      final r = rOff.abs();
      final disc = 4 * r * r - xd * xd - yd * yd;
      if (disc < 0) {
        // rayon trop petit → on relie en droite pour ne pas planter.
        toolpath.add([ex, ey, ez, a, c, 1.0]);
        indices.add(lineIndex);
        return;
      }
      var h = math.sqrt(disc) / math.sqrt(xd * xd + yd * yd);
      if (motion == 2) h = -h; // G2 horaire
      if (rOff < 0) h = -h; // R<0 → arc majeur
      cu = start[u] + 0.5 * (xd - yd * h);
      cv = start[v] + 0.5 * (yd + xd * h);
    } else {
      cu = start[u] + offU;
      cv = start[v] + offV;
    }

    final radius = math.sqrt(
        math.pow(start[u] - cu, 2) + math.pow(start[v] - cv, 2));
    final sa = math.atan2(start[v] - cv, start[u] - cu);
    final ea = math.atan2(end[v] - cv, end[u] - cu);

    double sweep;
    if (motion == 3) {
      sweep = ea - sa;
      while (sweep <= 1e-9) {
        sweep += 2 * math.pi;
      }
    } else {
      sweep = ea - sa;
      while (sweep >= -1e-9) {
        sweep -= 2 * math.pi;
      }
    }

    final nseg = math.max(2, (sweep.abs() / (math.pi / 18)).ceil());
    final startW = start[w], endW = end[w];
    for (int s = 1; s <= nseg; s++) {
      final t = s / nseg;
      final ang = sa + sweep * t;
      final pt = List<double>.filled(3, 0);
      pt[u] = cu + radius * math.cos(ang);
      pt[v] = cv + radius * math.sin(ang);
      pt[w] = startW + (endW - startW) * t;
      toolpath.add([pt[0], pt[1], pt[2], a, c, 1.0]);
      indices.add(lineIndex);
    }
  }

  /// Extrait la coordonnée d'un axe en tenant compte du mode courant :
  ///  - G91 (relatif) : la valeur lue est un delta ajouté à [lastVal].
  ///  - G20 (pouces) : conversion en mm pour les axes linéaires uniquement.
  /// Si l'axe est absent de la ligne, la position ne change pas (delta nul
  /// en relatif, valeur inchangée en absolu).
  static double _extractCoord(
    String line,
    String axis,
    double lastVal,
    GCodeModalState modal, {
    required bool isLinear,
  }) {
    final reg = RegExp('$axis([-+]?[0-9]*\\.?[0-9]+)');
    final match = reg.firstMatch(line);
    if (match == null) return lastVal;

    double value = double.tryParse(match.group(1)!) ?? 0.0;
    if (isLinear && modal.isInches) value *= 25.4;

    return modal.isRelative ? lastVal + value : value;
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
