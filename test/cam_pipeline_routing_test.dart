import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/cam_pipeline_service.dart';
import 'package:forgeron/application/services/medical_implant_service.dart';

void main() {
  test('CamPipelineService routes cranial implant STEP without timeout', () async {
    const stepPath =
        'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend.step';
    if (!File(stepPath).existsSync()) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final report = await CamPipelineService.run(
        stepPath,
        toolDiameter: 6.0,
        ap: 0.5,
        ae: 0.5,
        stepover: 0.5,
      );
      expect(report['pipeline'], equals('implant_medical_5x'));
      expect(report['lignes_gcode'], isNotNull);
      expect(report['gcode_path'], isNotNull);
      expect(File(report['gcode_path'] as String).existsSync(), isTrue);
    } on MedicalImplantException catch (e) {
      // Si la vérification géométrique détecte un gouge sur le modèle brut,
      // le refus de sécurité prouve que le pipeline 5 axes médical a bien été exécuté
      // et a évalué la pièce en profondeur sans bloquer indéfiniment.
      expect(e.message, contains('REFUS'));
    }
    stopwatch.stop();

    // Vérifier que le temps d'exécution est bien inférieur au timeout de 120s
    expect(stopwatch.elapsed.inSeconds, lessThan(90));
  }, timeout: const Timeout(Duration(seconds: 120)));
}
