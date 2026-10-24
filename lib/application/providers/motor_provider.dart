import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_state.dart';
import 'di_providers.dart';

/// Résultat d'une commande moteurs (pour un retour visuel à l'opérateur).
class MotorResult {
  final bool ok;
  final String? message;
  const MotorResult.ok() : ok = true, message = null;
  const MotorResult.blocked(this.message) : ok = false;
}

/// Contrôleur d'alimentation des moteurs pas-à-pas.
///
/// Agit sur le **pin ENA commun** (`shared_stepper_disable_pin: gpio.22`) qui
/// active/désactive les 5 drivers TB6600 en même temps. FluidNC expose la
/// commande `$MD` (Motors Disable) pour relâcher le couple.
class MotorController {
  final Ref _ref;
  const MotorController(this._ref);

  MachineState get _state => _ref.read(machineRepositoryProvider).currentState;

  /// Désactive TOUS les moteurs via `$MD` → les axes tournent librement à la
  /// main. ⚠️ Le couple de maintien de Z est relâché : la broche peut tomber.
  /// N'importe quel jog / homing / mouvement G-code réactive les moteurs.
  Future<MotorResult> disableAll() async {
    if (_state.status == MachineStatus.offline) {
      return const MotorResult.blocked('Machine hors ligne — commande non transmise.');
    }
    _ref.read(machineRepositoryProvider).sendRaw('\$MD\n');
    return const MotorResult.ok();
  }

  /// Désactive un seul axe via `$MD=<axe>` (ex. `$MD=X`).
  Future<MotorResult> disableAxis(String axis) async {
    if (_state.status == MachineStatus.offline) {
      return const MotorResult.blocked('Machine hors ligne — commande non transmise.');
    }
    _ref.read(machineRepositoryProvider).sendRaw('\$MD=${axis.toUpperCase()}\n');
    return const MotorResult.ok();
  }
}

final motorControllerProvider =
    Provider<MotorController>((ref) => MotorController(ref));
