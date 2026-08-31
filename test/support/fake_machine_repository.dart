import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/domain/repositories/machine_repository.dart';

/// Dépôt machine de test : aucune liaison, aucun timer.
///
/// [sendSucceeds] simule l'état du Wi-Fi — `false` = la commande n'arrive
/// jamais jusqu'à la carte, le cas que l'arrêt d'urgence doit savoir signaler.
class FakeMachineRepository implements MachineRepository {
  FakeMachineRepository({this.sendSucceeds = true});

  final bool sendSucceeds;

  int emergencyStopCalls = 0;
  int resetCalls = 0;
  final List<String> sentGCode = [];
  final List<String> sentRaw = [];

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
  MachineState get currentState => const MachineState();
  @override
  Future<void> sendGCodeBatch(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int index)? onProgress,
    void Function(String reason)? onStall,
  }) async {}
  @override
  Future<void> home([List<String> axes = const []]) async {}
  @override
  Future<void> jog(String axis, double distance, double feedrate) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setFeedOverride(int percent) async {}
  @override
  Future<void> setSpindleOverride(int percent) async {}
  @override
  void setSimulationSpeed(double speed) {}
  @override
  Future<void> setWcsOffset(String wcs, List<double> offset) async {}
}
