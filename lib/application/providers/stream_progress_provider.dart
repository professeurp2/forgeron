import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'streaming_provider.dart';
import 'gcode_provider.dart';
import 'di_providers.dart';

/// Avancement de l'exécution d'un programme G-code : ligne courante, %, temps
/// écoulé et estimation du temps restant. Alimenté par [streamingProvider]
/// (actif/inactif) et `MachineState.activeLineIndex` (ligne acquittée).
class StreamProgress {
  final bool active;
  final int currentLine; // index brut de la dernière ligne acquittée
  final int totalLines;
  final Duration elapsed;

  const StreamProgress({
    this.active = false,
    this.currentLine = 0,
    this.totalLines = 0,
    this.elapsed = Duration.zero,
  });

  double get fraction =>
      totalLines <= 0 ? 0.0 : (currentLine / totalLines).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  /// Estimation du temps restant (extrapolation linéaire sur l'avancement).
  Duration? get eta {
    final f = fraction;
    if (!active || f <= 0.02 || elapsed.inMilliseconds <= 0) return null;
    final totalMs = elapsed.inMilliseconds / f;
    final remMs = (totalMs - elapsed.inMilliseconds).round();
    return Duration(milliseconds: remMs < 0 ? 0 : remMs);
  }
}

class StreamProgressNotifier extends StateNotifier<StreamProgress> {
  final Ref _ref;
  Timer? _tick;
  DateTime? _startedAt;

  StreamProgressNotifier(this._ref) : super(const StreamProgress()) {
    _ref.listen<bool>(streamingProvider, (prev, next) {
      if (next && (prev == null || prev == false)) {
        _start();
      } else if (!next) {
        _stop();
      }
    }, fireImmediately: true);
  }

  void _start() {
    _startedAt = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => _emit(true));
    _emit(true);
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
    _emit(false);
  }

  void _emit(bool active) {
    final gc = _ref.read(gcodeProvider);
    final line = _ref.read(machineRepositoryProvider).currentState.activeLineIndex;
    final elapsed =
        _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;
    state = StreamProgress(
      active: active,
      currentLine: line,
      totalLines: gc.allLines.length,
      elapsed: elapsed,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

final streamProgressProvider =
    StateNotifierProvider<StreamProgressNotifier, StreamProgress>(
        (ref) => StreamProgressNotifier(ref));

/// Formate une durée en `m:ss` ou `h:mm:ss`.
String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '$m:${two(s)}';
}
