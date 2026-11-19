import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_adapter.dart';
import 'package:forgeron/core/utils/gcode_parser.dart';
import 'package:forgeron/core/utils/gcode_replay.dart';
import 'package:forgeron/core/utils/kinematics_service.dart';
import 'package:vector_math/vector_math_64.dart';

/// Jalon S0 : l'app et le pipeline décrivent le même rejeu. La référence
/// `dome5_continu_replay.csv` sort de `verify5.replay_reference`.
void main() {
  final program = File('test/fixtures/dome5_continu.nc').readAsStringSync();
  final reference = File('test/fixtures/dome5_continu_replay.csv')
      .readAsLinesSync()
      .skip(1)
      .map((l) => l.split(',').map(double.parse).toList())
      .toList();

  test('pointe et durée identiques au rejeu Python, après le chargement de l\'app', () {
    final adapted = GcodeAdapter.adaptForFluidNC(program).gcode;
    final parsed = GCodeParser.parseSync(adapted);
    final kin = KinematicsService.fromProgramHeader(adapted)!;
    final times = GcodeReplay.cumulativeSeconds(
      parsed.toolpath,
      (i) => parsed.modalStates[parsed.toolpathLineIndices[i]]?.feedrate ?? 0.0,
    );

    // Python écarte les blocs sans mouvement et le début (position inconnue) : on
    // aligne sur les blocs qui bougent, en partant de la fin.
    final moving = <int>[
      for (var i = 1; i < parsed.toolpath.length; i++)
        if (GcodeReplay.blockSeconds(parsed.toolpath[i - 1], parsed.toolpath[i], 0) > 0) i,
    ];
    final n = reference.length;
    expect(moving.length, greaterThanOrEqualTo(n));
    final blocks = moving.sublist(moving.length - n);
    var worstTip = 0.0;
    var worstTime = 0.0;
    for (var k = 0; k < n; k++) {
      final p = parsed.toolpath[blocks[k]];
      final tip = kin.forward(Vector3(p[0], p[1], p[2]), p[3], p[4]);
      final ref = reference[k];
      final gap = (tip - Vector3(ref[1], ref[2], ref[3])).length;
      if (gap > worstTip) worstTip = gap;
      final dtApp = times[blocks[k]] - times[blocks[0]];
      final dtPy = ref[4] - reference[0][4];
      if ((dtApp - dtPy).abs() > worstTime) worstTime = (dtApp - dtPy).abs();
    }
    expect(worstTip, lessThan(0.01), reason: 'écart de pointe $worstTip mm');
    expect(worstTime, lessThan(0.5), reason: 'écart de durée $worstTime s');
  });

  test('un rapide est plafonné par l\'axe le plus lent, pas à une vitesse inventée', () {
    // 100 mm en X à 500 mm/min = 12 s.
    final t = GcodeReplay.blockSeconds([0, 0, 0, 0, 0, 0], [100, 0, 0, 0, 0, 0], 0);
    expect(t, closeTo(12.0, 1e-9));
  });

  test('en G1, le F s\'applique à la norme mm + degrés', () {
    // √(3² + 4²) = 5 unités à 100 par minute = 3 s.
    final t = GcodeReplay.blockSeconds([0, 0, 0, 0, 0, 1], [3, 0, 0, 4, 0, 1], 100);
    expect(t, closeTo(3.0, 1e-9));
  });
}
