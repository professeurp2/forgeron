import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';

/// Notifier pour le contrôle manuel sécurisé (Jogging).
/// Utilise $J= (Continuous Jog) et \x85 (Jog Cancel).
class JogState {
  final double linearStep;
  final double rotaryStep;
  final bool isJogging;

  JogState({this.linearStep = 10.0, this.rotaryStep = 5.0, this.isJogging = false});

  JogState copyWith({double? linearStep, double? rotaryStep, bool? isJogging}) {
    return JogState(
      linearStep: linearStep ?? this.linearStep,
      rotaryStep: rotaryStep ?? this.rotaryStep,
      isJogging: isJogging ?? this.isJogging,
    );
  }
}

class JogNotifier extends StateNotifier<JogState> {
  final Ref _ref;

  JogNotifier(this._ref) : super(JogState());

  void setLinearStep(double step) => state = state.copyWith(linearStep: step);
  void setRotaryStep(double step) => state = state.copyWith(rotaryStep: step);

  /// Déclenche un mouvement continu sur un axe.
  void startContinuousJog(String axis, int direction, {double feed = 1000.0}) {
    if (state.isJogging) return; 
    
    state = state.copyWith(isJogging: true);
    final distance = 500.0 * direction;
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feed.toStringAsFixed(0)}';
    _ref.read(machineRepositoryProvider).sendGCode(cmd);
  }

  /// Déclenche un mouvement par pas (Incremental Jog).
  Future<void> jogLinear(String axis, int direction) async {
    final distance = state.linearStep * direction;
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F1000';
    await _ref.read(machineRepositoryProvider).sendGCode(cmd);
  }

  Future<void> jogRotary(String axis, int direction) async {
    final distance = state.rotaryStep * direction;
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F3600';
    await _ref.read(machineRepositoryProvider).sendGCode(cmd);
  }

  /// Arrête immédiatement le mouvement.
  void stopJog() {
    _ref.read(machineRepositoryProvider).jog('', 0, 0); 
    state = state.copyWith(isJogging: false);
  }

  Future<void> homeAll() async => _ref.read(machineRepositoryProvider).home();
  Future<void> homeAxis(String axis) async => _ref.read(machineRepositoryProvider).home([axis]);
}

final secureJogProvider = StateNotifierProvider<JogNotifier, JogState>((ref) {
  return JogNotifier(ref);
});
