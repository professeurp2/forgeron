import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_state.dart';
import '../../application/providers/machine_provider.dart';
import '../../data/fluidnc/grbl_parser.dart';
import '../../application/providers/di_providers.dart';

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

  /// Point calculé (repère machine) proposé pour un zérotage WCS (G10 L20),
  /// en attente de confirmation utilisateur. Null si rien à zérer.
  final double? pendingZeroX;
  final double? pendingZeroY;
  final double? pendingZeroZ;

  ProbingState({
    this.step = ProbingStep.idle,
    this.statusMessage = 'Prêt pour le palpage',
    this.lastResult,
    this.sequenceResults = const [],
    this.pendingZeroX,
    this.pendingZeroY,
    this.pendingZeroZ,
  });

  bool get hasPendingZero =>
      pendingZeroX != null || pendingZeroY != null || pendingZeroZ != null;

  ProbingState copyWith({
    ProbingStep? step,
    String? statusMessage,
    ProbingResult? lastResult,
    List<ProbingResult>? sequenceResults,
    double? pendingZeroX,
    double? pendingZeroY,
    double? pendingZeroZ,
    bool clearPendingZero = false,
  }) {
    return ProbingState(
      step: step ?? this.step,
      statusMessage: statusMessage ?? this.statusMessage,
      lastResult: lastResult ?? this.lastResult,
      sequenceResults: sequenceResults ?? this.sequenceResults,
      pendingZeroX:
          clearPendingZero ? null : (pendingZeroX ?? this.pendingZeroX),
      pendingZeroY:
          clearPendingZero ? null : (pendingZeroY ?? this.pendingZeroY),
      pendingZeroZ:
          clearPendingZero ? null : (pendingZeroZ ?? this.pendingZeroZ),
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
        pendingZeroZ: result.probePos[2],
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
      pendingZeroX: centerX,
      pendingZeroY: centerY,
    );
  }

  static const Map<String, int> _wcsToP = {
    'G54': 1, 'G55': 2, 'G56': 3, 'G57': 4, 'G58': 5, 'G59': 6,
  };

  /// Déplace la machine au point calculé (centre/hauteur détectés) puis
  /// applique un vrai zérotage WCS (`G10 L20`) à cette position — à n'appeler
  /// qu'après confirmation explicite de l'utilisateur, car ça redéfinit
  /// l'origine pièce active.
  Future<void> confirmZeroWcs(String wcs) async {
    if (!state.hasPendingZero) return;
    final p = _wcsToP[wcs.toUpperCase()];
    if (p == null) return;

    final repo = _ref.read(machineRepositoryProvider);
    final moveParts = <String>[];
    final zeroParts = <String>[];
    if (state.pendingZeroX != null) {
      moveParts.add('X${state.pendingZeroX!.toStringAsFixed(3)}');
      zeroParts.add('X0');
    }
    if (state.pendingZeroY != null) {
      moveParts.add('Y${state.pendingZeroY!.toStringAsFixed(3)}');
      zeroParts.add('Y0');
    }
    if (state.pendingZeroZ != null) {
      moveParts.add('Z${state.pendingZeroZ!.toStringAsFixed(3)}');
      zeroParts.add('Z0');
    }

    await repo.sendGCode('G90 G0 ${moveParts.join(' ')}');
    await repo.sendGCode('G10 L20 P$p ${zeroParts.join(' ')}');
    repo.sendRaw('\$#\n'); // Rafraîchit la table d'offsets affichée.

    state = state.copyWith(
      statusMessage: 'WCS $wcs zéré à la position palpée.',
      clearPendingZero: true,
    );
  }

  /// Annule la proposition de zérotage sans envoyer de commande.
  void dismissPendingZero() {
    state = state.copyWith(clearPendingZero: true);
  }

  Future<ProbingResult> _waitForProbeReport() async {
    final completer = Completer<ProbingResult>();
    
    _messageSub = _ref.read(machineRepositoryProvider).messageStream.listen((msg) {
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
      _messageSub?.cancel();
      _messageSub = null;
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
