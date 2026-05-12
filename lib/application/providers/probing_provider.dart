import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_state.dart';
import '../../application/providers/machine_provider.dart';
import '../../data/fluidnc/grbl_parser.dart';

/// États de la Machine à États de Palpage
enum ProbingStep {
  idle,
  movingToStart,
  probing,
  waitingForReport,
  calculating,
  finished,
  error
}

/// Modèle pour le résultat d'un palpage
class ProbingResult {
  final List<double> probePos; // [X, Y, Z, A, C]
  final DateTime timestamp;

  ProbingResult({required this.probePos, required this.timestamp});
}

/// State pour le notifier de palpage
class ProbingState {
  final ProbingStep step;
  final String statusMessage;
  final ProbingResult? lastResult;
  final List<ProbingResult> sequenceResults;

  ProbingState({
    this.step = ProbingStep.idle,
    this.statusMessage = 'Prêt pour le palpage',
    this.lastResult,
    this.sequenceResults = const [],
  });

  ProbingState copyWith({
    ProbingStep? step,
    String? statusMessage,
    ProbingResult? lastResult,
    List<ProbingResult>? sequenceResults,
  }) {
    return ProbingState(
      step: step ?? this.step,
      statusMessage: statusMessage ?? this.statusMessage,
      lastResult: lastResult ?? this.lastResult,
      sequenceResults: sequenceResults ?? this.sequenceResults,
    );
  }
}

/// Service de Palpage Industriel (G38.2).
/// Orchestre les séquences complexes (Centre, Trou, Hauteur).
class ProbingNotifier extends StateNotifier<ProbingState> {
  final Ref _ref;
  StreamSubscription? _messageSub;

  ProbingNotifier(this._ref) : super(ProbingState());

  /// Lance une routine de palpage de centre de trou (4 points)
  Future<void> startHoleCenterRoutine(double diameter, double depth) async {
    state = state.copyWith(step: ProbingStep.movingToStart, statusMessage: 'Début routine centre de trou...', sequenceResults: []);
    
    try {
      final repo = _ref.read(machineRepositoryProvider);
      
      // 1. Point X+
      await _probeDirection('X', diameter / 2 + 5, 1);
      // 2. Retour au centre provisoire et Point X-
      await repo.sendGCode('G90 G0 X${state.sequenceResults.last.probePos[0] - (diameter/2)}');
      await _probeDirection('X', -(diameter / 2 + 5), -1);
      
      final centerX = (state.sequenceResults[0].probePos[0] + state.sequenceResults[1].probePos[0]) / 2;
      await repo.sendGCode('G90 G0 X$centerX');

      // 3. Point Y+
      await _probeDirection('Y', diameter / 2 + 5, 1);
      // 4. Retour au centre provisoire et Point Y-
      await repo.sendGCode('G90 G0 Y${state.sequenceResults.last.probePos[1] - (diameter/2)}');
      await _probeDirection('Y', -(diameter / 2 + 5), -1);

      _calculateCenter();
    } catch (e) {
      state = state.copyWith(step: ProbingStep.error, statusMessage: 'Erreur: $e');
    }
  }

  /// Routine de détection d'angle (X ou Y)
  Future<void> startAngleRoutine(String axis, double distance) async {
    state = state.copyWith(step: ProbingStep.probing, statusMessage: 'Détection d\'angle axe $axis...', sequenceResults: []);
    try {
      // Premier point
      await _probeDirection(axis, 10, 1);
      // Déplacement latéral
      final lateralAxis = axis == 'X' ? 'Y' : 'X';
      await _ref.read(machineRepositoryProvider).sendGCode('G91 G0 $lateralAxis$distance');
      // Deuxième point
      await _probeDirection(axis, 10, 1);

      final r = state.sequenceResults;
      final dPos = axis == 'X' ? r[1].probePos[0] - r[0].probePos[0] : r[1].probePos[1] - r[0].probePos[1];
      final angle = (math.atan2(dPos, distance) * 180 / math.pi);

      state = state.copyWith(
        step: ProbingStep.finished,
        statusMessage: 'Angle détecté: ${angle.toStringAsFixed(3)}°',
      );
    } catch (e) {
      state = state.copyWith(step: ProbingStep.error, statusMessage: 'Erreur angle: $e');
    }
  }

  /// Routine de hauteur d'outil (Z)
  Future<void> startToolZRoutine() async {
    state = state.copyWith(step: ProbingStep.probing, statusMessage: 'Recherche Z tool...');
    try {
      final result = await _probeDirection('Z', -50, -1);
      state = state.copyWith(
        step: ProbingStep.finished,
        statusMessage: 'Z détecté: ${result.probePos[2].toStringAsFixed(3)}',
      );
    } catch (e) {
      state = state.copyWith(step: ProbingStep.error, statusMessage: 'Erreur Z: $e');
    }
  }

  Future<ProbingResult> _probeDirection(String axis, double distance, int direction) async {
    state = state.copyWith(step: ProbingStep.probing, statusMessage: 'Palpage axe $axis...');
    
    final repo = _ref.read(machineRepositoryProvider);
    // On s'assure d'être en G21 (mm) et G91 (relatif)
    await repo.sendGCode('G21 G91 G38.2 $axis$distance F100');
    
    final result = await _waitForProbeReport();
    state = state.copyWith(
      sequenceResults: [...state.sequenceResults, result],
      lastResult: result,
    );

    // Retrait de sécurité (2mm)
    await repo.sendGCode('G91 G0 $axis${-2.0 * direction}');
    return result;
  }

  void _calculateCenter() {
    if (state.sequenceResults.length < 4) return;
    
    final r = state.sequenceResults;
    final centerX = (r[0].probePos[0] + r[1].probePos[0]) / 2;
    final centerY = (r[2].probePos[1] + r[3].probePos[1]) / 2;
    
    state = state.copyWith(
      step: ProbingStep.finished,
      statusMessage: 'Centre trouvé: X=${centerX.toStringAsFixed(3)}, Y=${centerY.toStringAsFixed(3)}',
    );
  }

  Future<ProbingResult> _waitForProbeReport() async {
    final completer = Completer<ProbingResult>();
    
    final sub = _ref.read(machineRepositoryProvider).messageStream.listen((msg) {
      final report = GrblParser.parseProbeReport(msg);
      if (report != null) {
        if (report['success'] == true) {
          completer.complete(ProbingResult(
            probePos: List<double>.from(report['coords']),
            timestamp: DateTime.now(),
          ));
        } else {
          completer.completeError('Contact non établi lors du palpage');
        }
      }
    });

    try {
      // Timeout après 30 secondes de palpage
      return await completer.future.timeout(const Duration(seconds: 30));
    } finally {
      sub.cancel();
    }
  }

  void cancel() {
    _ref.read(machineRepositoryProvider).emergencyStop();
    state = ProbingState(step: ProbingStep.idle, statusMessage: 'Palpage annulé');
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }
}

final probingProvider = StateNotifierProvider<ProbingNotifier, ProbingState>((ref) {
  return ProbingNotifier(ref);
});
