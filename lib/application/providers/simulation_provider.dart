import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gcode_provider.dart';

/// État d'exécution du simulateur d'usinage 5 axes.
enum SimulationStatus {
  idle,
  playing,
  paused,
  completed,
}

/// Forme du brut pré-usinage (comme dans l'interface Acteris : Cuboids / Cylinders).
enum StockShape {
  cylinder,
  cuboid;

  String get label => switch (this) {
        StockShape.cylinder => 'Cylindrique (Barreau)',
        StockShape.cuboid => 'Cuboïde (Bloc)',
      };

  String get wire => name;

  static StockShape fromString(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.startsWith('cub') || s.contains('bloc') || s.contains('rect')) {
      return StockShape.cuboid;
    }
    return StockShape.cylinder;
  }
}

/// Onglet actif dans le panneau droit de la console (style Acteris : Simulator | Camera).
enum ConsoleRightTab {
  simulator,
  camera,
}

/// Vues caméra CAO prédéfinies (ViewCube 3D).
class CameraPreset {
  static const String isometric = 'ISOMETRIC';
  static const String top = 'TOP';
  static const String front = 'FRONT';
  static const String right = 'RIGHT';
  static const String left = 'LEFT';
  static const String back = 'BACK';

  static const List<String> values = [
    isometric,
    top,
    front,
    right,
    left,
    back,
  ];
}

/// Anomalie ou collision détectée lors de l'analyse/simulation du parcours.
class SimulationIssue {
  final int lineIndex;
  final int toolpathIndex;
  final String severity; // 'danger' | 'warning'
  final String message;

  const SimulationIssue({
    required this.lineIndex,
    required this.toolpathIndex,
    required this.severity,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'line': lineIndex + 1,
        'toolpathPoint': toolpathIndex,
        'severity': severity,
        'message': message,
      };
}

class SimulationState {
  final SimulationStatus status;
  final double speedMultiplier;
  final double progressPct; // 0.0 .. 100.0
  final int currentToolpathIndex;
  final int currentRawLineIndex;
  final List<double> simulatedMPos; // [X, Y, Z, A, C]
  final double elapsedSeconds;
  final double estimatedTotalSeconds;
  final double totalCuttingMm;
  final double totalRapidMm;

  // Paramètres du Job / Brut (Style Acteris Summary)
  final String jobName;
  final int batchSize;
  final StockShape stockShape;
  final List<double> stockDimensions; // [X, Y, Z] en mm (ou [D, D, H] pour cylindre)
  final double toolDiameter;
  final bool showEnclosure;

  // Caméra & Panneau actif
  final ConsoleRightTab activeTab;
  final String cameraPreset;
  final int cameraCommandSeq;
  final int stockResetSeq;

  // Diagnostics de simulation
  final List<SimulationIssue> issues;

  const SimulationState({
    this.status = SimulationStatus.idle,
    this.speedMultiplier = 10.0,
    this.progressPct = 0.0,
    this.currentToolpathIndex = 0,
    this.currentRawLineIndex = 0,
    this.simulatedMPos = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.elapsedSeconds = 0.0,
    this.estimatedTotalSeconds = 0.0,
    this.totalCuttingMm = 0.0,
    this.totalRapidMm = 0.0,
    this.jobName = 'Job_CNC_5X',
    this.batchSize = 1,
    this.stockShape = StockShape.cylinder,
    this.stockDimensions = const [40.0, 40.0, 25.0],
    this.toolDiameter = 6.0,
    this.showEnclosure = true,
    this.activeTab = ConsoleRightTab.simulator,
    this.cameraPreset = CameraPreset.isometric,
    this.cameraCommandSeq = 0,
    this.stockResetSeq = 0,
    this.issues = const [],
  });

  bool get isSimulating =>
      status == SimulationStatus.playing || status == SimulationStatus.paused;

  int get collisionCount =>
      issues.where((e) => e.severity == 'danger').length;

  int get warningCount =>
      issues.where((e) => e.severity == 'warning').length;

  String get dimensionsLabel =>
      '${stockDimensions[0].toStringAsFixed(0)} × '
      '${stockDimensions[1].toStringAsFixed(0)} × '
      '${stockDimensions[2].toStringAsFixed(0)} mm';

  SimulationState copyWith({
    SimulationStatus? status,
    double? speedMultiplier,
    double? progressPct,
    int? currentToolpathIndex,
    int? currentRawLineIndex,
    List<double>? simulatedMPos,
    double? elapsedSeconds,
    double? estimatedTotalSeconds,
    double? totalCuttingMm,
    double? totalRapidMm,
    String? jobName,
    int? batchSize,
    StockShape? stockShape,
    List<double>? stockDimensions,
    double? toolDiameter,
    bool? showEnclosure,
    ConsoleRightTab? activeTab,
    String? cameraPreset,
    int? cameraCommandSeq,
    int? stockResetSeq,
    List<SimulationIssue>? issues,
  }) {
    return SimulationState(
      status: status ?? this.status,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      progressPct: progressPct ?? this.progressPct,
      currentToolpathIndex: currentToolpathIndex ?? this.currentToolpathIndex,
      currentRawLineIndex: currentRawLineIndex ?? this.currentRawLineIndex,
      simulatedMPos: simulatedMPos ?? this.simulatedMPos,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      estimatedTotalSeconds:
          estimatedTotalSeconds ?? this.estimatedTotalSeconds,
      totalCuttingMm: totalCuttingMm ?? this.totalCuttingMm,
      totalRapidMm: totalRapidMm ?? this.totalRapidMm,
      jobName: jobName ?? this.jobName,
      batchSize: batchSize ?? this.batchSize,
      stockShape: stockShape ?? this.stockShape,
      stockDimensions: stockDimensions ?? this.stockDimensions,
      toolDiameter: toolDiameter ?? this.toolDiameter,
      showEnclosure: showEnclosure ?? this.showEnclosure,
      activeTab: activeTab ?? this.activeTab,
      cameraPreset: cameraPreset ?? this.cameraPreset,
      cameraCommandSeq: cameraCommandSeq ?? this.cameraCommandSeq,
      stockResetSeq: stockResetSeq ?? this.stockResetSeq,
      issues: issues ?? this.issues,
    );
  }
}

class SimulationController extends StateNotifier<SimulationState> {
  final Ref _ref;
  Timer? _timer;
  List<double> _cumulativeTimesSec = const [];
  double _cursorSec = 0.0;

  SimulationController(this._ref) : super(const SimulationState()) {
    // Recalcule automatiquement les métriques dès qu'un nouveau parcours est chargé.
    _ref.listen<List<List<double>>>(
      gcodeProvider.select((s) => s.toolpath),
      (prev, next) {
        _rebuildTimeline();
      },
    );
  }

  /// Analyse le parcours G-code courant, construit la table temporelle de
  /// chaque segment et détecte les collisions G0 dans le brut et hors-courses.
  Map<String, dynamic> analyzeCurrentProgram() {
    _rebuildTimeline();
    return {
      'ok': true,
      'status': state.status.name,
      'jobName': state.jobName,
      'batchSize': state.batchSize,
      'stockShape': state.stockShape.wire,
      'stockDimensionsMm': state.stockDimensions,
      'toolDiameterMm': state.toolDiameter,
      'estimatedDurationSec': state.estimatedTotalSeconds.round(),
      'estimatedDurationFormatted': formatDuration(state.estimatedTotalSeconds),
      'totalCuttingMm': (state.totalCuttingMm * 10).round() / 10.0,
      'totalRapidMm': (state.totalRapidMm * 10).round() / 10.0,
      'collisions': state.collisionCount,
      'warnings': state.warningCount,
      'issues': state.issues.take(10).map((e) => e.toJson()).toList(),
    };
  }

  void _rebuildTimeline() {
    final gcode = _ref.read(gcodeProvider);
    final pts = gcode.toolpath;
    final indices = gcode.toolpathLineIndices;
    final modals = gcode.modalStates;

    if (pts.isEmpty) {
      _cumulativeTimesSec = const [];
      _cursorSec = 0.0;
      state = state.copyWith(
        status: SimulationStatus.idle,
        progressPct: 0.0,
        currentToolpathIndex: 0,
        currentRawLineIndex: 0,
        elapsedSeconds: 0.0,
        estimatedTotalSeconds: 0.0,
        totalCuttingMm: 0.0,
        totalRapidMm: 0.0,
        issues: const [],
      );
      return;
    }

    final cumTimes = List<double>.filled(pts.length, 0.0);
    double totalSec = 0.0;
    double cutMm = 0.0;
    double rapidMm = 0.0;
    final issues = <SimulationIssue>[];

    final halfX = state.stockDimensions[0] / 2.0;
    final halfY = state.stockDimensions[1] / 2.0;
    final stockH = state.stockDimensions[2];
    final stockR = state.stockDimensions[0] / 2.0;

    List<double> prev = pts.first;
    for (int i = 1; i < pts.length; i++) {
      final cur = pts[i];
      final dx = cur[0] - prev[0];
      final dy = cur[1] - prev[1];
      final dz = cur[2] - prev[2];
      final da = (cur[3] - prev[3]).abs();
      final dc = (cur[4] - prev[4]).abs();
      final linearDist = math.sqrt(dx * dx + dy * dy + dz * dz);
      // Distance équivalente incluant la rotation A/C pour les passes purement rotatives
      final effDist = math.max(linearDist, (da + dc * 0.25) * 0.35);
      final isRapid = cur[5] == 0.0;

      final rawLine = i < indices.length ? indices[i] : 0;
      final modalFeed = modals[rawLine]?.feedrate ?? 0.0;
      final feedMmPerMin = isRapid
          ? 1500.0
          : (modalFeed > 1.0 ? modalFeed : 240.0);

      final segSec = effDist > 1e-5
          ? (effDist / (feedMmPerMin / 60.0)).clamp(0.002, 30.0)
          : 0.002;
      totalSec += segSec;
      cumTimes[i] = totalSec;

      if (isRapid) {
        rapidMm += linearDist;
        // Détection de collision rapide G0 sous la surface supérieure du brut
        // (lorsque Z descend dans le volume du brut en mouvement rapide G0).
        if (cur[2] < stockH - 1.5 && cur[2] < prev[2] && issues.length < 25) {
          final insideXY = state.stockShape == StockShape.cylinder
              ? (cur[0] * cur[0] + cur[1] * cur[1]) < (stockR * stockR * 0.92)
              : (cur[0].abs() < halfX * 0.95 && cur[1].abs() < halfY * 0.95);
          if (insideXY && cur[2] < 0.0) {
            issues.add(SimulationIssue(
              lineIndex: rawLine,
              toolpathIndex: i,
              severity: 'danger',
              message:
                  'Plongée rapide G0 détectée dans le brut à Z=${cur[2].toStringAsFixed(2)} mm (ligne ${rawLine + 1}).',
            ));
          }
        }
      } else {
        cutMm += linearDist;
      }

      // Vérification de la course de l'axe A [-88°, +90°]
      if ((cur[3] < -88.0 || cur[3] > 90.0) && issues.length < 25) {
        issues.add(SimulationIssue(
          lineIndex: rawLine,
          toolpathIndex: i,
          severity: 'danger',
          message:
              'Axe A hors limites (${cur[3].toStringAsFixed(1)}° ∉ [-88°, +90°]) à la ligne ${rawLine + 1}.',
        ));
      }

      prev = cur;
    }

    _cumulativeTimesSec = cumTimes;
    state = state.copyWith(
      estimatedTotalSeconds: totalSec,
      totalCuttingMm: cutMm,
      totalRapidMm: rapidMm,
      issues: issues,
      simulatedMPos: [
        pts.first[0],
        pts.first[1],
        pts.first[2],
        pts.first[3],
        pts.first[4],
      ],
    );
  }

  /// Configure les paramètres du Job / Brut (depuis l'UI Summary ou l'Agent IA).
  void configureJob({
    String? jobName,
    int? batchSize,
    StockShape? stockShape,
    List<double>? stockDimensions,
    double? toolDiameter,
    bool? showEnclosure,
    double? speedMultiplier,
    String? cameraPreset,
  }) {
    final nextCameraSeq = cameraPreset != null
        ? state.cameraCommandSeq + 1
        : state.cameraCommandSeq;
    final nextStockSeq = (stockShape != null || stockDimensions != null)
        ? state.stockResetSeq + 1
        : state.stockResetSeq;

    state = state.copyWith(
      jobName: jobName,
      batchSize: batchSize,
      stockShape: stockShape,
      stockDimensions: stockDimensions,
      toolDiameter: toolDiameter,
      showEnclosure: showEnclosure,
      speedMultiplier: speedMultiplier,
      cameraPreset: cameraPreset,
      cameraCommandSeq: nextCameraSeq,
      stockResetSeq: nextStockSeq,
    );
    _rebuildTimeline();
  }

  void setActiveTab(ConsoleRightTab tab) {
    if (state.activeTab != tab) {
      state = state.copyWith(activeTab: tab);
    }
  }

  void setCameraPreset(String preset) {
    final upper = preset.toUpperCase();
    state = state.copyWith(
      cameraPreset: upper,
      cameraCommandSeq: state.cameraCommandSeq + 1,
    );
  }

  void toggleEnclosure() {
    state = state.copyWith(showEnclosure: !state.showEnclosure);
  }

  void setSpeed(double multiplier) {
    state = state.copyWith(speedMultiplier: multiplier.clamp(0.25, 100.0));
  }

  /// Démarre ou reprend la simulation temporelle.
  void play({double? speedMultiplier}) {
    if (_cumulativeTimesSec.isEmpty) {
      _rebuildTimeline();
    }
    if (_cumulativeTimesSec.isEmpty) return;

    if (speedMultiplier != null) {
      state = state.copyWith(speedMultiplier: speedMultiplier.clamp(0.25, 100.0));
    }

    // Si la simulation était terminée, on repart du début et on réinitialise le brut.
    if (state.status == SimulationStatus.completed ||
        _cursorSec >= state.estimatedTotalSeconds) {
      _cursorSec = 0.0;
      state = state.copyWith(
        stockResetSeq: state.stockResetSeq + 1,
        progressPct: 0.0,
        currentToolpathIndex: 0,
        currentRawLineIndex: 0,
        elapsedSeconds: 0.0,
      );
    }

    state = state.copyWith(
      status: SimulationStatus.playing,
      activeTab: ConsoleRightTab.simulator,
    );

    _timer?.cancel();
    const tickMs = 33; // ~30 FPS côté Riverpod, lissé à 60 FPS dans Three.js
    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      _onTick(tickMs / 1000.0);
    });
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    if (state.status == SimulationStatus.playing) {
      state = state.copyWith(status: SimulationStatus.paused);
    }
  }

  void togglePlayPause() {
    if (state.status == SimulationStatus.playing) {
      pause();
    } else {
      play();
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _cursorSec = 0.0;
    final pts = _ref.read(gcodeProvider).toolpath;
    final initialPos = pts.isNotEmpty
        ? <double>[pts.first[0], pts.first[1], pts.first[2], pts.first[3], pts.first[4]]
        : const <double>[0.0, 0.0, 0.0, 0.0, 0.0];

    state = state.copyWith(
      status: SimulationStatus.idle,
      progressPct: 0.0,
      currentToolpathIndex: 0,
      currentRawLineIndex: 0,
      elapsedSeconds: 0.0,
      simulatedMPos: initialPos,
      stockResetSeq: state.stockResetSeq + 1,
    );
    _ref.read(gcodeProvider.notifier).updateCurrentLine(0);
  }

  /// Déplace le curseur de simulation à un pourcentage donné (0..100%).
  void seekPercent(double pct) {
    if (_cumulativeTimesSec.isEmpty) {
      _rebuildTimeline();
    }
    if (_cumulativeTimesSec.isEmpty) return;

    final clamped = pct.clamp(0.0, 100.0);
    _cursorSec = (clamped / 100.0) * state.estimatedTotalSeconds;
    _applyCursorPosition(
      overrideStatus: state.status == SimulationStatus.idle
          ? SimulationStatus.paused
          : state.status,
    );
  }

  void _onTick(double dtSec) {
    final total = state.estimatedTotalSeconds;
    if (total <= 0 || _cumulativeTimesSec.isEmpty) {
      pause();
      return;
    }

    // Vitesse adaptative : même à ×1, un programme de 2 heures est ramené à
    // une cadence visuelle fluide si l'utilisateur choisit ≥ ×10.
    _cursorSec += dtSec * state.speedMultiplier;
    if (_cursorSec >= total) {
      _cursorSec = total;
      _timer?.cancel();
      _timer = null;
      _applyCursorPosition(overrideStatus: SimulationStatus.completed);
      return;
    }

    _applyCursorPosition();
  }

  void _applyCursorPosition({SimulationStatus? overrideStatus}) {
    final gcode = _ref.read(gcodeProvider);
    final pts = gcode.toolpath;
    final indices = gcode.toolpathLineIndices;
    if (pts.isEmpty || _cumulativeTimesSec.isEmpty) return;

    // Recherche dichotomique O(log N) dans _cumulativeTimesSec
    int lo = 0;
    int hi = _cumulativeTimesSec.length - 1;
    int segIdx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >>> 1;
      if (_cumulativeTimesSec[mid] <= _cursorSec) {
        segIdx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    List<double> interpPos;
    if (segIdx >= pts.length - 1) {
      final last = pts.last;
      interpPos = [last[0], last[1], last[2], last[3], last[4]];
    } else {
      final t0 = _cumulativeTimesSec[segIdx];
      final t1 = _cumulativeTimesSec[segIdx + 1];
      final span = t1 - t0;
      final alpha = span > 1e-6 ? ((_cursorSec - t0) / span).clamp(0.0, 1.0) : 1.0;
      final a = pts[segIdx];
      final b = pts[segIdx + 1];
      interpPos = [
        a[0] + (b[0] - a[0]) * alpha,
        a[1] + (b[1] - a[1]) * alpha,
        a[2] + (b[2] - a[2]) * alpha,
        a[3] + (b[3] - a[3]) * alpha,
        a[4] + (b[4] - a[4]) * alpha,
      ];
    }

    final rawLine = segIdx < indices.length ? indices[segIdx] : 0;
    final total = state.estimatedTotalSeconds;
    final pct = total > 0 ? ((_cursorSec / total) * 100.0).clamp(0.0, 100.0) : 0.0;

    state = state.copyWith(
      status: overrideStatus ?? state.status,
      progressPct: pct,
      currentToolpathIndex: segIdx,
      currentRawLineIndex: rawLine,
      elapsedSeconds: _cursorSec,
      simulatedMPos: interpPos,
    );

    _ref.read(gcodeProvider.notifier).updateCurrentLine(rawLine);
  }

  static String formatDuration(double totalSeconds) {
    if (totalSeconds <= 0 || totalSeconds.isNaN || totalSeconds.isInfinite) {
      return '00:00';
    }
    final sec = totalSeconds.round();
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final simulationProvider =
    StateNotifierProvider<SimulationController, SimulationState>(
  (ref) => SimulationController(ref),
);
