import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/force_guard_service.dart';
import 'package:forgeron/core/utils/gcode_adapter.dart';
import 'package:forgeron/core/utils/gcode_critic.dart';
import 'package:forgeron/core/utils/kinematics_service.dart';
import 'package:forgeron/domain/models/machining_mode.dart';
import 'package:forgeron/domain/models/trunnion_config.dart';
import 'package:vector_math/vector_math_64.dart';

/// Le programme sorti de `pipeline/continuous5.py` doit passer tel quel la chaîne
/// de l'application, et la cinématique Dart doit retrouver la pièce que Python a
/// visée : deux implémentations, une seule machine.
///
/// La fixture est un dôme R=20 sur une base de 28 mm, dessus à Z=0 : pivot à
/// 27,16 mm sous le zéro.
void main() {
  final gcode = File('test/fixtures/dome5_continu.nc').readAsStringSync();

  test('l\'adaptateur ne bloque pas et ne touche pas aux coordonnées', () {
    final r = GcodeAdapter.adaptForFluidNC(gcode);
    expect(r.blocking, isFalse, reason: r.warnings.join('\n'));
    final moves = RegExp(r'^G1 X.* A.* C.*$', multiLine: true);
    expect(moves.allMatches(r.gcode).length, moves.allMatches(gcode).length);
  });

  test('le critique juge le programme exploitable', () {
    final c = const GcodeCritic().review(gcode);
    expect(c.usable, isTrue, reason: c.findings.map((f) => f.message).join('\n'));
  });

  test('sans pivot déclaré, le critique garde sa mesure en repère machine', () {
    final anonymous = gcode.replaceAll('PIVOT A', 'AXE');
    expect(const GcodeCritic().review(anonymous).usable, isFalse);
  });

  test('ForceGuard 5 axes ne réécrit aucune avance', () {
    final guard = ForceGuardService(
      mode: MachiningMode.fiveAxis,
      config: const TrunnionConfig(),
    );
    final alerts = guard.checkFile(gcode.split('\n'));
    expect(alerts, isEmpty, reason: alerts.take(3).join('\n'));
  });

  test('la cinématique Dart replace la pointe sur le dôme', () {
    const d = 27.159916684291606;
    final k = KinematicsService(pivotToTableOffset: d, pivot: Vector3(0, 0, -d));
    final finish = gcode.split('ETAPE 2')[1];
    final line = RegExp(
      r'^G1 X(-?[\d.]+) Y(-?[\d.]+) Z(-?[\d.]+) A(-?[\d.]+) C(-?[\d.]+)',
      multiLine: true,
    );
    const rho = 3.0;
    const offsetR = 20.0 + rho;
    // Le sommet de la sphère est à Z=0 dans le repère pièce : centre à Z=-20.
    var checked = 0;
    for (final m in line.allMatches(finish)) {
      final v = [for (var i = 1; i <= 5; i++) double.parse(m.group(i)!)];
      // Centre de la bille : rho au-dessus de la pointe, sur l'axe vertical.
      final c = k.forward(Vector3(v[0], v[1], v[2] + rho), v[3], v[4]);
      final r = math.sqrt(c.x * c.x + c.y * c.y + (c.z + 20.0) * (c.z + 20.0));
      if (math.sqrt(c.x * c.x + c.y * c.y) > 13.0) continue; // arête de la base
      expect((r - offsetR).abs(), lessThan(0.05), reason: m.group(0));
      checked++;
    }
    expect(checked, greaterThan(100));
  });
}
