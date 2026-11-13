import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/gcode_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/simulation_provider.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/data/fluidnc/fluidnc_machine_repository.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Le jumeau : le simulateur ne joue plus une estimation, il suit la carte.
///
/// Ce que ces tests verrouillent : en mode jumeau, chaque rapport d'état de
/// la carte devient la position, la ligne et l'avancement du simulateur ;
/// un écart entre la position réelle et le parcours est MESURÉ et signalé ;
/// la lecture hors ligne et le jumeau s'excluent ; et l'outil de l'agent IA
/// sait l'enclencher — mais refuse carte hors ligne.
const _program = 'G21 G90\nG0 X0 Y0 Z5\nG1 X10 Y0 Z-1 F300\nG1 X20 Y0 Z-1\nG1 X20 Y10 Z-1\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<MachineState> states;
  late FakeMachineRepository repo;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    states = StreamController<MachineState>.broadcast();
    repo = FakeMachineRepository(current: const MachineState(status: MachineStatus.idle));
    c = ProviderContainer(overrides: [
      machineRepositoryProvider.overrideWithValue(repo),
      machineStateProvider.overrideWith((ref) => states.stream),
    ]);
    addTearDown(() {
      c.dispose();
      states.close();
    });
    await c.read(gcodeProvider.notifier).loadFile(_program);
    expect(c.read(gcodeProvider).toolpath, isNotEmpty, reason: 'le programme doit donner un parcours');
  });

  Future<void> emit(MachineState s) async {
    states.add(s);
    await Future<void>.delayed(Duration.zero);
  }

  SimulationController ctl() => c.read(simulationProvider.notifier);
  SimulationState sim() => c.read(simulationProvider);

  test('suivre la carte : position, ligne et avancement viennent des rapports', () async {
    ctl().followMachine();
    expect(sim().isLive, isTrue);
    expect(sim().drivesViewer, isTrue);
    expect(repo.pollIntervals, [const Duration(milliseconds: 250)],
        reason: 'le jumeau demande des rapports rapprochés');

    final total = c.read(gcodeProvider).allLines.length;
    await emit(const MachineState(
      status: MachineStatus.run,
      mPos: [10, 0, -1, 0, 0],
      wPos: [10, 0, -1, 0, 0],
      activeLineIndex: 2,
    ));

    final s = sim();
    expect(s.liveMachineStatus, 'run');
    expect(s.currentRawLineIndex, 2);
    expect(s.progressPct, closeTo(2 / total * 100, 0.01));
    expect(s.liveReports, greaterThanOrEqualTo(1));
    expect(c.read(gcodeProvider).currentLineIndex, 2, reason: 'l\'éditeur suit la ligne réelle');
    // Position réelle sur le parcours : pas d'écart signalé.
    expect(s.liveDeviationMm, isNotNull);
    expect(s.liveDeviationMm!, lessThan(SimulationController.liveDeviationToleranceMm));
    expect(s.issues.where((i) => i.severity == 'ecart'), isEmpty);
  });

  test('un écart réel avec le parcours est mesuré et signalé, jamais inventé', () async {
    ctl().followMachine();
    await emit(const MachineState(
      status: MachineStatus.run,
      mPos: [10, 7, -1, 0, 0],
      wPos: [10, 7, -1, 0, 0],
      activeLineIndex: 2,
    ));
    final s = sim();
    expect(s.liveDeviationMm, closeTo(7, 0.01));
    final ecarts = s.issues.where((i) => i.severity == 'ecart').toList();
    expect(ecarts, hasLength(1));
    expect(ecarts.single.message, contains('7.00 mm'));
    expect(ecarts.single.message, contains('ligne 3'));
    expect(s.warningCount, 1);

    // La machine revient sur le parcours : l'écart disparaît (un seul à la fois).
    await emit(const MachineState(
      status: MachineStatus.run,
      mPos: [20, 0, -1, 0, 0],
      wPos: [20, 0, -1, 0, 0],
      activeLineIndex: 3,
    ));
    expect(sim().issues.where((i) => i.severity == 'ecart'), isEmpty);

    // À l'arrêt, la position n'a aucune raison d'être sur le parcours : pas
    // de mesure.
    await emit(const MachineState(status: MachineStatus.idle, wPos: [0, 0, 50, 0, 0]));
    expect(sim().liveDeviationMm, isNull);
    expect(sim().liveMachineStatus, 'idle');
  });

  test('la lecture hors ligne et le jumeau s\'excluent', () async {
    ctl().followMachine();
    ctl().play();
    expect(sim().isLive, isFalse);
    expect(sim().status, SimulationStatus.playing);
    expect(repo.pollIntervals.last, const Duration(seconds: 2), reason: 'cadence rendue au repos');
    ctl().pause();

    ctl().followMachine();
    expect(sim().status, SimulationStatus.live);
    ctl().stopFollowing();
    expect(sim().status, SimulationStatus.idle);
    expect(sim().liveMachineStatus, isNull);
    // Un rapport reçu après l'arrêt du suivi ne touche plus au simulateur.
    await emit(const MachineState(status: MachineStatus.run, activeLineIndex: 4));
    expect(sim().currentRawLineIndex, 0);
  });

  test('l\'outil de l\'agent : follow_machine / stop_follow, et refus carte hors ligne', () async {
    final tool = AiToolCatalog.byName('control_simulation')!;
    final ref = c.read(Provider((r) => r));

    final on = jsonDecode(await tool.execute({'action': 'follow_machine'}, ref)) as Map;
    expect(on['ok'], isTrue);
    expect(on['mode'], 'jumeau');
    expect(on['status'], 'live');
    expect(on['jumeau'], isA<Map>());

    final off = jsonDecode(await tool.execute({'action': 'stop_follow'}, ref)) as Map;
    expect(off['mode'], 'simulation');
    expect(off['status'], 'idle');

    repo.current = const MachineState(status: MachineStatus.offline);
    final refused = jsonDecode(await tool.execute({'action': 'follow_machine'}, ref)) as Map;
    expect(refused['ok'], isFalse);
    expect('${refused['raison']}', contains('hors ligne'));
    expect(sim().isLive, isFalse);
  });

  test('le rapport d\'analyse dit le mode et l\'écart', () async {
    ctl().followMachine();
    await emit(const MachineState(
      status: MachineStatus.run,
      wPos: [10, 0, -1, 0, 0],
      activeLineIndex: 2,
    ));
    final r = ctl().analyzeCurrentProgram();
    expect(r['mode'], 'jumeau');
    expect((r['jumeau'] as Map)['ligne_reelle'], 3);
    expect((r['jumeau'] as Map)['statut_machine'], 'run');
  });

  test('cadence des rapports : rapide dès que des axes peuvent bouger', () {
    expect(FluidNCMachineRepository.pollIntervalFor(MachineStatus.run), FluidNCMachineRepository.fastPoll);
    expect(FluidNCMachineRepository.pollIntervalFor(MachineStatus.home), FluidNCMachineRepository.fastPoll);
    expect(FluidNCMachineRepository.pollIntervalFor(MachineStatus.hold), FluidNCMachineRepository.fastPoll);
    expect(FluidNCMachineRepository.pollIntervalFor(MachineStatus.idle), FluidNCMachineRepository.idlePoll);
    expect(FluidNCMachineRepository.pollIntervalFor(MachineStatus.alarm), FluidNCMachineRepository.idlePoll);
    expect(FluidNCMachineRepository.pollIntervalFor(MachineStatus.offline), FluidNCMachineRepository.idlePoll);
  });
}
