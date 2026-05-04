import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/jog_command.dart';
import '../../domain/repositories/machine_repository.dart';
import 'machine_provider.dart';

// ── État du jog ─────────────────────────────────────────────────────────────

class JogState {
  final double linearStep;   // mm
  final double rotaryStep;   // degrés
  final double linearFeed;   // mm/min
  final double rotaryFeed;   // °/min
  final bool isJogging;

  const JogState({
    this.linearStep = 1.0,
    this.rotaryStep = 5.0,
    this.linearFeed = 1000.0,
    this.rotaryFeed = 200.0,
    this.isJogging = false,
  });

  JogState copyWith({
    double? linearStep,
    double? rotaryStep,
    double? linearFeed,
    double? rotaryFeed,
    bool? isJogging,
  }) {
    return JogState(
      linearStep: linearStep ?? this.linearStep,
      rotaryStep: rotaryStep ?? this.rotaryStep,
      linearFeed: linearFeed ?? this.linearFeed,
      rotaryFeed: rotaryFeed ?? this.rotaryFeed,
      isJogging: isJogging ?? this.isJogging,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class JogNotifier extends StateNotifier<JogState> {
  final MachineRepository _repo;

  JogNotifier(this._repo) : super(const JogState());

  // ── Changer les pas ─────────────────────────────────────────────────────
  void setLinearStep(double step) => state = state.copyWith(linearStep: step);
  void setRotaryStep(double step) => state = state.copyWith(rotaryStep: step);
  void setLinearFeed(double feed) => state = state.copyWith(linearFeed: feed);
  void setRotaryFeed(double feed) => state = state.copyWith(rotaryFeed: feed);

  // ── Jog axes linéaires ───────────────────────────────────────────────────
  Future<void> jogLinear(String axis, double direction) async {
    final distance = state.linearStep * direction;
    state = state.copyWith(isJogging: true);
    await _repo.jog(axis, distance, state.linearFeed);
    state = state.copyWith(isJogging: false);
  }

  // ── Jog axes rotatifs ────────────────────────────────────────────────────
  Future<void> jogRotary(String axis, double direction) async {
    final degrees = state.rotaryStep * direction;
    state = state.copyWith(isJogging: true);
    await _repo.jog(axis, degrees, state.rotaryFeed);
    state = state.copyWith(isJogging: false);
  }

  /// Jog continu : envoyer une grande distance, arrêter sur jogStop()
  Future<void> startContinuousJog(String axis, double direction) async {
    final isRotary = JogCommand.rotaryAxes.contains(axis.toUpperCase());
    final bigDistance = isRotary ? direction * 999.0 : direction * 9999.0;
    final feed = isRotary ? state.rotaryFeed : state.linearFeed;
    state = state.copyWith(isJogging: true);
    await _repo.jog(axis, bigDistance, feed);
  }

  /// Arrêter le jog continu (0x85)
  Future<void> stopJog() async {
    final repo = _repo;
    try {
      await (repo as dynamic).jogCancel();
    } catch (_) {}
    state = state.copyWith(isJogging: false);
  }

  // ── Homing ───────────────────────────────────────────────────────────────
  Future<void> homeAll() => _repo.home([]);

  Future<void> homeTrunnionSequence() async {
    final repo = _repo;
    try {
      await (repo as dynamic).homeTrunnionSequence();
    } catch (_) {
      await _repo.home([]);
    }
  }

  Future<void> homeAxis(String axis) => _repo.home([axis]);
}

// ── Provider ─────────────────────────────────────────────────────────────────

final jogProvider = StateNotifierProvider<JogNotifier, JogState>((ref) {
  final repo = ref.watch(machineRepositoryProvider);
  return JogNotifier(repo);
});
