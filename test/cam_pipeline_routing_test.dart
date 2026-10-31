import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/cam_pipeline_service.dart';

void main() {
  test('CamPipelineService routes cranial implant STEP without timeout', () async {
    const stepPath =
        'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend.step';
    if (!File(stepPath).existsSync()) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    final report = await CamPipelineService.run(
      stepPath,
      toolDiameter: 6.0,
      ap: 0.5,
      ae: 0.5,
      stepover: 0.5,
    );
    stopwatch.stop();

    expect(report['pipeline'], equals('implant_medical_5x'));
    expect(report['lignes_gcode'], isNotNull);
    expect(report['gcode_path'], isNotNull);
    expect(File(report['gcode_path'] as String).existsSync(), isTrue);

    // Vérifier que le temps d'exécution est bien inférieur au timeout de 120s
    expect(stopwatch.elapsed.inSeconds, lessThan(60));
  });
}
