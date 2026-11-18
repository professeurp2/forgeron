import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/gcode_replay.dart';
import '../../domain/models/machine_state.dart';
import 'di_providers.dart';
import 'gcode_provider.dart';
import 'machine_provider.dart';

/// État d'exécution du simulateur d'usinage 5 axes.
enum SimulationStatus {
  idle,
  playing,
  paused,
  completed,

  /// **Jumeau** : le simulateur ne joue plus un parcours estimé, il suit la
  /// carte ESP32 réelle — position, ligne acquittée, matière enlevée — à
  /// chaque rapport d'état. Rien n'est calculé à l'avance : ce qui est montré
  /// est ce que la carte a dit.
  live,
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

  // ── Jumeau (status == live) ───────────────────────────────────────────────

  /// Statut de la carte au dernier rapport (`run`, `hold`, `idle`…), `null`
  /// hors mode jumeau.
  final String? liveMachineStatus;

  /// Écart (mm, XYZ) entre la position réelle et le point du parcours attendu
  /// à la ligne acquittée ; `null` si pas mesurable (pas de parcours, machine
  /// à l'arrêt).
  final double? liveDeviationMm;

  /// Nombre de rapports de la carte reçus depuis le début du suivi.
  final int liveReports;

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
    this.liveMachineStatus,
    this.liveDeviationMm,
    this.liveReports = 0,
  });

  bool get isSimulating =>
      status == SimulationStatus.playing || status == SimulationStatus.paused;

  bool get isLive => status == SimulationStatus.live;

  /// Le simulateur pilote-t-il le visualiseur 3D (positions et brut) ? Vrai
  /// en lecture, en pause, à la fin d'une lecture, et en jumeau.
  bool get drivesViewer =>
      isSimulating || isLive || status == SimulationStatus.completed;

  int get collisionCount =>
      issues.where((e) => e.severity == 'danger').length;

  int get warningCount =>
      issues.where((e) => e.severity == 'warning' || e.severity == 'ecart').length;

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
    String? liveMachineStatus,
    bool clearLive = false,
    double? liveDeviationMm,
    bool clearLiveDeviation = false,
    int? liveReports,
  }) {
    return SimulationState(
      liveMachineStatus: clearLive ? null : (liveMachineStatus ?? this.liveMachineStatus),
      liveDeviationMm: clearLive || clearLiveDeviation ? null : (liveDeviationMm ?? this.liveDeviationMm),
      liveReports: clearLive ? 0 : (liveReports ?? this.liveReports),
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
    if (!state.isLive) _rebuildTimeline();
    return {
      'ok': true,
      'status': state.status.name,
      'mode': state.isLive ? 'jumeau' : 'simulation',
      if (state.isLive)
        'jumeau': {
          'statut_machine': state.liveMachineStatus,
          'ligne_reelle': state.currentRawLineIndex + 1,
          'rapports': state.liveReports,
          'ecart_mm': state.liveDeviationMm == null
              ? null
              : (state.liveDeviationMm! * 100).round() / 100.0,
        },
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
      final linearDist = math.sqrt(dx * dx + dy * dy + dz * dz);
      final isRapid = cur[5] == 0.0;

      final rawLine = i < indices.length ? indices[i] : 0;
      totalSec += GcodeReplay.blockSeconds(
        prev,
        cur,
        modals[rawLine]?.feedrate ?? 0.0,
      );
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

  // ── Jumeau : suivre la carte réelle ───────────────────────────────────────

  ProviderSubscription<AsyncValue<MachineState>>? _liveSub;
  DateTime? _liveStartedAt;

  /// Au-delà, la position réelle est dite « à l'écart » du parcours : un
  /// décalage d'origine, une ligne sautée, ou un pas perdu. 2 mm, c'est plus
  /// que le pas d'interpolation d'un rapport de statut à l'avance maximale
  /// (F1500 → 6 mm en 250 ms) divisé par… non : c'est volontairement large,
  /// car entre deux rapports l'outil a avancé sur le segment suivant.
  static const double liveDeviationToleranceMm = 2.0;

  /// Le simulateur suit désormais la carte : la lecture estimée est arrêtée,
  /// le brut est remis à neuf, et chaque rapport d'état de la carte déplace
  /// l'outil du jumeau et enlève la matière au point RÉEL.
  void followMachine() {
    _timer?.cancel();
    _timer = null;
    _liveSub?.close();
    _liveStartedAt = DateTime.now();
    final pts = _ref.read(gcodeProvider).toolpath;
    state = state.copyWith(
      status: SimulationStatus.live,
      activeTab: ConsoleRightTab.simulator,
      progressPct: 0.0,
      currentToolpathIndex: 0,
      currentRawLineIndex: 0,
      elapsedSeconds: 0.0,
      stockResetSeq: state.stockResetSeq + 1,
      issues: state.issues.where((i) => i.severity != 'ecart').toList(),
      clearLive: true,
      simulatedMPos: _ref.read(renderMPosProvider),
    );
    // Un parcours chargé sert de référence ; sans parcours, on suit quand
    // même la position (jog, homing).
    if (pts.isNotEmpty && _cumulativeTimesSec.isEmpty) _rebuildTimeline();
    _ref.read(machineRepositoryProvider).setStatusPollInterval(const Duration(milliseconds: 250));
    _liveSub = _ref.listen<AsyncValue<MachineState>>(
      machineStateProvider,
      (_, next) {
        final s = next.valueOrNull;
        if (s != null) _onLiveState(s);
      },
      fireImmediately: true,
    );
  }

  /// Arrête le suivi de la carte (le brut garde la matière enlevée).
  void stopFollowing() {
    _liveSub?.close();
    _liveSub = null;
    if (!state.isLive) return;
    _ref.read(machineRepositoryProvider).setStatusPollInterval(const Duration(seconds: 2));
    state = state.copyWith(status: SimulationStatus.idle, clearLive: true);
  }

  void _onLiveState(MachineState s) {
    if (!state.isLive) return;
    final gcode = _ref.read(gcodeProvider);
    final total = gcode.allLines.length;
    final rawLine = s.activeLineIndex;
    final idx = gcode.resolveToolpathIndex(rawLine);
    final pct = total <= 0 ? 0.0 : (rawLine / total * 100.0).clamp(0.0, 100.0);

    // Écart parcours ↔ réel, seulement quand la carte exécute le programme :
    // à l'arrêt ou en jog, la position n'a aucune raison d'être sur le parcours.
    double? deviation;
    var issues = state.issues;
    if (s.status == MachineStatus.run && idx < gcode.toolpath.length && gcode.toolpath.isNotEmpty) {
      final expected = gcode.toolpath[idx];
      final dx = s.wPos[0] - expected[0];
      final dy = s.wPos[1] - expected[1];
      final dz = s.wPos[2] - expected[2];
      deviation = math.sqrt(dx * dx + dy * dy + dz * dz);
      final others = issues.where((i) => i.severity != 'ecart').toList();
      if (deviation > liveDeviationToleranceMm) {
        others.add(SimulationIssue(
          lineIndex: rawLine,
          toolpathIndex: idx,
          severity: 'ecart',
          message: 'Écart de ${deviation.toStringAsFixed(2)} mm entre la position réelle '
              'et le parcours à la ligne ${rawLine + 1}.',
        ));
      }
      issues = others;
    }

    state = state.copyWith(
      progressPct: pct,
      currentToolpathIndex: idx,
      currentRawLineIndex: rawLine,
      simulatedMPos: _ref.read(renderMPosProvider),
      elapsedSeconds: _liveStartedAt == null
          ? 0.0
          : DateTime.now().difference(_liveStartedAt!).inMilliseconds / 1000.0,
      liveMachineStatus: s.status.name,
      liveDeviationMm: deviation,
      clearLiveDeviation: deviation == null,
      liveReports: state.liveReports + 1,
      issues: issues,
    );
    _ref.read(gcodeProvider.notifier).updateCurrentLine(rawLine);
  }

  /// Démarre ou reprend la simulation temporelle.
  void play({double? speedMultiplier}) {
    if (state.isLive) stopFollowing();
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
    if (state.isLive) stopFollowing();
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
    _liveSub?.close();
    super.dispose();
  }
}

final simulationProvider =
    StateNotifierProvider<SimulationController, SimulationState>(
  (ref) => SimulationController(ref),
);
