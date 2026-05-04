import 'package:freezed_annotation/freezed_annotation.dart';

part 'machine_state.freezed.dart';
part 'machine_state.g.dart';

enum MachineStatus {
  idle,
  run,
  hold,
  alarm,
  home,
  check,
  door,
  sleep,
  offline,
}

/// État complet de la machine CNC 5-axes Trunnion (X, Y, Z, A, C)
/// Conforme au protocole GRBL/FluidNC v1.1
@freezed
class MachineState with _$MachineState {
  const factory MachineState({
    // --- Statut ---
    @Default(MachineStatus.offline) MachineStatus status,
    int? alarmCode, // Code numérique de l'alarme ALARM:N

    // --- Positions (X, Y, Z = mm | A, C = degrés) ---
    @Default([0.0, 0.0, 0.0, 0.0, 0.0]) List<double> mPos, // Machine Position
    @Default([0.0, 0.0, 0.0, 0.0, 0.0]) List<double> wPos, // Work Position
    @Default([0.0, 0.0, 0.0, 0.0, 0.0]) List<double> wco,  // WCS Offset (WPos = MPos - WCO)

    // --- Dynamique ---
    @Default(0.0) double feedrate,      // mm/min
    @Default(0.0) double spindleSpeed,  // RPM

    // --- Overrides (%) ---
    @Default([100, 100, 100]) List<int> overrides, // [Feed, Rapid, Spindle]

    // --- Contexte modal ---
    @Default('G54') String activeWCS,     // G54..G59.3
    @Default(0) int activeToolNum,        // T0..T99

    // --- Fins de course (X, Y, Z, A, C) ---
    @Default([false, false, false, false, false]) List<bool> limitSwitches,

    // --- Buffers FluidNC (Bf:blocks,bytes) ---
    @Default(15) int plannerBuffer,  // Blocs disponibles dans la file
    @Default(128) int rxBuffer,      // Octets disponibles dans le buffer RX

  }) = _MachineState;

  factory MachineState.fromJson(Map<String, dynamic> json) =>
      _$MachineStateFromJson(json);
}
