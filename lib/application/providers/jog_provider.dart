import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/machine_params_provider.dart';

const _jogAxes = ['X', 'Y', 'Z', 'A', 'C'];

/// Résultat de l'évaluation de sécurité d'un jog.
class JogVerdict {
  final bool allowed;
  final String? message;
  final bool warningOnly; // autorisé mais avec avertissement
  const JogVerdict._(this.allowed, this.message, this.warningOnly);
  const JogVerdict.ok() : this._(true, null, false);
  const JogVerdict.warn(String m) : this._(true, m, true);
  const JogVerdict.block(String m) : this._(false, m, false);
}

/// Alerte de jog à présenter à l'opérateur (bloqué = rouge, sinon avertissement).
class JogAlert {
  final String message;
  final bool blocked;
  const JogAlert(this.message, this.blocked);
}

/// Dernière alerte de garde jog (consommée par l'UI pour un snackbar).
final jogGuardMessageProvider = StateProvider<JogAlert?>((ref) => null);

/// Évalue la sécurité d'un jog incrémental de [distance] (signé) sur [axis] :
/// bloque si la cible dépasse la course (max_travel), avertit si une fin de
/// course est déjà active (jog autorisé pour dégager). Garde-fou côté app en
/// complément des soft-limits FluidNC.
JogVerdict evaluateJogSafety(Ref ref, String axis, double distance) {
  final idx = _jogAxes.indexOf(axis.toUpperCase());
  if (idx < 0) return const JogVerdict.ok();
  final s = ref.read(machineRepositoryProvider).currentState;

  // Fin de course déjà active → on autorise (dégagement) mais on avertit.
  if (idx < s.limitSwitches.length && s.limitSwitches[idx]) {
    return JogVerdict.warn(
        'Fin de course $axis active — jog uniquement pour dégager l\'axe.');
  }

  // Dépassement de course, si max_travel connu.
  final kin = ref.read(axisKinematicsProvider).valueOrNull;
  final maxTravel =
      (kin != null && idx < kin.length) ? kin[idx].maxTravel : null;
  if (maxTravel != null && maxTravel > 0) {
    final cur = idx < s.mPos.length ? s.mPos[idx] : 0.0;
    final target = cur + distance;
    if (target.abs() > maxTravel + 1.0) {
      return JogVerdict.block(
          'Jog bloqué : $axis atteindrait ${target.toStringAsFixed(0)} mm, '
          'hors course (max ${maxTravel.toStringAsFixed(0)} mm).');
    }
  }
  return const JogVerdict.ok();
}

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

    // En continu, on n'empêche pas (dépend de la durée d'appui, FluidNC borne
    // via soft-limits) mais on avertit si une fin de course est déjà active.
    final v = evaluateJogSafety(_ref, axis, 500.0 * direction);
    _ref.read(jogGuardMessageProvider.notifier).state =
        v.warningOnly && v.message != null ? JogAlert(v.message!, false) : null;

    state = state.copyWith(isJogging: true);
    final distance = 500.0 * direction;
    final cmd =
        '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feed.toStringAsFixed(0)}';
    _ref.read(machineRepositoryProvider).sendGCode(cmd);
  }

  /// Jog incrémental gardé : bloque hors-course, avertit sur fin de course.
  Future<void> _guardedIncremental(
      String axis, double distance, double feed) async {
    final v = evaluateJogSafety(_ref, axis, distance);
    _ref.read(jogGuardMessageProvider.notifier).state =
        v.message == null ? null : JogAlert(v.message!, !v.allowed);
    if (!v.allowed) return;
    final cmd =
        '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feed.toStringAsFixed(0)}\n';
    // Les $J= bypassent le buffer et vont directement sur le socket.
    _ref.read(machineRepositoryProvider).sendRaw(cmd);
  }

  Future<void> jogLinear(String axis, int direction) async {
    final multiplier = _ref.read(cncJogMultiplierProvider);
    await _guardedIncremental(axis, multiplier.toDouble() * direction, 1000);
  }

  Future<void> jogRotary(String axis, int direction) async {
    final multiplier = _ref.read(cncJogMultiplierProvider);
    await _guardedIncremental(axis, multiplier.toDouble() * direction, 3600);
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
