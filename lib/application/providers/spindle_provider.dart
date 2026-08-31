import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_state.dart';
import 'di_providers.dart';

/// Résultat d'une commande broche (pour un retour visuel à l'opérateur).
class SpindleResult {
  final bool ok;
  final String? message;
  const SpindleResult.ok() : ok = true, message = null;
  const SpindleResult.blocked(this.message) : ok = false;
}

/// Contrôleur de la broche à relais : Marche/Arrêt via `M3`/`M5`.
///
/// La broche est en tout-ou-rien (config FluidNC `Relay:`), donc la vitesse `S`
/// est ignorée : `M3` = marche, `M5` = arrêt. L'état réel est lu depuis le champ
/// accessoire `A:` du rapport GRBL (`MachineState.spindleOn`), pas supposé.
class SpindleController {
  final Ref _ref;
  const SpindleController(this._ref);

  MachineState get _state => _ref.read(machineRepositoryProvider).currentState;

  /// Vitesse envoyée avec `M3`. Une broche à relais s'active seulement pour une
  /// vitesse > 0 (FluidNC : « on for any speed above 0 »), donc `M3` seul (S=0)
  /// ne l'allume JAMAIS. S1000 = 100 % avec le speed_map `0..1000` de la config.
  static const int _onSpeed = 1000;

  /// Démarre la broche (`M3 S1000`). Bloqué hors ligne ou en alarme — on ne
  /// lance jamais la broche sur une machine dont l'état n'est pas sûr.
  Future<SpindleResult> start() async {
    final s = _state;
    if (s.status == MachineStatus.offline) {
      return const SpindleResult.blocked('Machine hors ligne — broche non démarrée.');
    }
    if (s.status == MachineStatus.alarm) {
      return const SpindleResult.blocked('Alarme active — débloque la machine avant de démarrer la broche.');
    }
    await _ref.read(machineRepositoryProvider).sendGCode('M3 S$_onSpeed');
    return const SpindleResult.ok();
  }

  /// Arrête la broche (`M5`). Toujours autorisé quand la machine répond : on
  /// doit pouvoir couper la broche à tout moment.
  Future<SpindleResult> stop() async {
    if (_state.status == MachineStatus.offline) {
      return const SpindleResult.blocked('Machine hors ligne — commande non transmise.');
    }
    await _ref.read(machineRepositoryProvider).sendGCode('M5');
    return const SpindleResult.ok();
  }

  /// Bascule Marche↔Arrêt selon l'état courant de la broche.
  Future<SpindleResult> toggle() async =>
      _state.spindleOn ? stop() : start();
}

final spindleControllerProvider =
    Provider<SpindleController>((ref) => SpindleController(ref));
