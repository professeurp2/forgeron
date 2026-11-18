import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/domain/repositories/machine_repository.dart';

/// Dépôt machine de test : aucune liaison, aucun timer.
///
/// [sendSucceeds] simule l'état du Wi-Fi — `false` = la commande n'arrive
/// jamais jusqu'à la carte, le cas que l'arrêt d'urgence doit savoir signaler.
class FakeMachineRepository implements MachineRepository {
  FakeMachineRepository({this.sendSucceeds = true, this.current = const MachineState()});

  final bool sendSucceeds;

  /// État que le dépôt rapporte (hors ligne par défaut, comme une vraie
  /// liaison jamais établie).
  MachineState current;

  int emergencyStopCalls = 0;
  int resetCalls = 0;
  final List<String> sentGCode = [];
  final List<String> sentRaw = [];
  final List<String> homeCalls = [];
  final List<(String, double, double)> jogCalls = [];
  int pauseCalls = 0;

  @override
  Future<bool> emergencyStop() async {
    emergencyStopCalls++;
    return sendSucceeds;
  }

  @override
  Future<void> reset() async {
    resetCalls++;
  }

  @override
  Future<void> sendGCode(String gcode) async => sentGCode.add(gcode);

  @override
  void sendRaw(String data) => sentRaw.add(data);

  @override
  Stream<MachineState> get stateStream => const Stream.empty();
  @override
  Stream<String> get messageStream => const Stream.empty();
  @override
  Stream<String> get trafficStream => const Stream.empty();
  @override
  MachineState get currentState => current;
  @override
  Future<void> sendGCodeBatch(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int index)? onProgress,
    void Function(String reason)? onStall,
  }) async {}
  @override
  Future<void> home([List<String> axes = const []]) async => homeCalls.add(axes.join(','));
  @override
  Future<void> jog(String axis, double distance, double feedrate) async =>
      jogCalls.add((axis, distance, feedrate));
  @override
  Future<void> resume() async {}
  @override
  Future<void> pause() async => pauseCalls++;
  @override
  Future<void> setFeedOverride(int percent) async {}
  @override
  Future<void> setSpindleOverride(int percent) async {}
  @override
  void setSimulationSpeed(double speed) {}
  final List<Duration> pollIntervals = [];
  @override
  void setStatusPollInterval(Duration interval) => pollIntervals.add(interval);
  @override
  Future<void> setWcsOffset(String wcs, List<double> offset) async {}
}
