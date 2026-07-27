import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/di_providers.dart';

/// Notifier pour le contrôle manuel sécurisé (Jogging).
/// Utilise $J= (Continuous Jog) et \x85 (Jog Cancel).

/// Pas de jog sélectionné sur le pupitre et dashboard (x1 / x10 / x100).
final cncJogMultiplierProvider = StateProvider<int>((ref) => 10);
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
    final multiplier = _ref.read(cncJogMultiplierProvider);
    final distance = multiplier.toDouble() * direction;
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F1000\n';
    // Les commandes $J= doivent bypasser le buffer et aller directement sur le socket
    _ref.read(machineRepositoryProvider).sendRaw(cmd);
  }

  Future<void> jogRotary(String axis, int direction) async {
    final multiplier = _ref.read(cncJogMultiplierProvider);
    final distance = multiplier.toDouble() * direction;
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F3600\n';
    _ref.read(machineRepositoryProvider).sendRaw(cmd);
  }

  /// Arrête immédiatement le mouvement (Jog Cancel real-time command 0x85).
  void stopJog() {
    _ref.read(machineRepositoryProvider).sendRaw('\x85');
    state = state.copyWith(isJogging: false);
  }

  Future<void> homeAll() async => _ref.read(machineRepositoryProvider).home();
  Future<void> homeAxis(String axis) async => _ref.read(machineRepositoryProvider).home([axis]);
}

final secureJogProvider = StateNotifierProvider<JogNotifier, JogState>((ref) {
  return JogNotifier(ref);
});
