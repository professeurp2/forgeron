import '../models/machine_state.dart';

abstract class MachineRepository {
  /// Stream of machine states.
  Stream<MachineState> get stateStream;

  /// Stream of raw messages from the machine.
  Stream<String> get messageStream;

  /// Stream of raw network traffic (TX/RX) for diagnostics.
  Stream<String> get trafficStream;

  /// Current machine state.
  MachineState get currentState;

  /// Sends a raw G-code string to the machine.
  Future<void> sendGCode(String gcode);

  /// Sends multiple G-code lines optimized for high-speed streaming.
  Future<void> sendGCodeBatch(List<String> lines);

  /// Triggers an emergency stop.
  Future<void> emergencyStop();

  /// Homes the specified axes. If empty, homes all configured axes.
  Future<void> home([List<String> axes = const []]);

  /// Jogs the machine along an axis.
  Future<void> jog(String axis, double distance, double feedrate);
  
  /// Resumes program execution.
  Future<void> resume();

  /// Pauses program execution.
  Future<void> pause();
  
  /// Resets the machine controller (soft reset).
  Future<void> reset();

  /// Sets the feed rate override percentage (10-200%).
  Future<void> setFeedOverride(int percent);

  /// Sets the spindle speed override percentage (10-200%).
  Future<void> setSpindleOverride(int percent);
}
