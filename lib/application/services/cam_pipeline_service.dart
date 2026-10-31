import 'medical_implant_service.dart';
import 'step_pipeline_service.dart';
import 'prismatic_pipeline_service.dart';

/// Point d'entrée unique du pipeline CAO -> G-code pour l'agent IA :
/// - si le fichier est un maillage `.stl` (implant médical sur mesure issu de
///   DICOM ou d'un scan 3D), délègue directement à [MedicalImplantService] ;
/// - sinon (`.step` / `.stp`), essaie la révolution (rapide, précision
///   analytique) et ne retombe sur FreeCAD (cas général, phase 5.c) que si la
///   pièce n'en est explicitement pas une.
class CamPipelineService {
  static const _refusRevolution = 'pas une pièce de révolution';

  static Future<Map<String, dynamic>> run(
    String stepPath, {
    double toolDiameter = 6.0,
    double ap = 0.2,
    double ae = 0.5,
    double stepover = 0.4,
    double? stockRadius,
  }) async {
    if (stepPath.toLowerCase().endsWith('.stl')) {
      final res = await MedicalImplantService.run(
        stepPath,
        toolDiameter: toolDiameter,
        ap: ap,
        ae: ae,
        stepover: stepover,
      );
      return res.report;
    }

    try {
      final report = await StepPipelineService.run(
        stepPath,
        toolDia: toolDiameter,
        ap: ap,
        ae: ae,
        stepover: stepover,
        stockRadius: stockRadius,
      );
      return {...report, 'pipeline': 'revolution'};
    } on StepPipelineException catch (e) {
      if (!e.toString().contains(_refusRevolution)) rethrow;
    }

    // Mêmes conditions de coupe que le pipeline de révolution : c'est la même
    // machine, la même broche et le même plafond vibratoire — seule la
    // stratégie de parcours change.
    final report = await PrismaticPipelineService.run(
      stepPath,
      toolDiameter: toolDiameter,
      ap: ap,
      ae: ae,
    );
    return {...report, 'pipeline': 'freecad_prismatique'};
  }
}
