import 'step_pipeline_service.dart';
import 'prismatic_pipeline_service.dart';

/// Point d'entrée unique du pipeline CAO -> G-code pour l'agent IA : essaie
/// la révolution (rapide, précision analytique) et ne retombe sur FreeCAD
/// (cas général, phase 5.c) que si la pièce n'en est explicitement pas une —
/// pas sur n'importe quelle erreur, pour ne pas masquer un vrai problème
/// (fichier absent, environnement manquant) derrière une seconde tentative
/// qui échouerait pour une raison sans rapport.
class CamPipelineService {
  static const _refusRevolution = 'pas une pièce de révolution';

  static Future<Map<String, dynamic>> run(
    String stepPath, {
    double toolDiameter = 6.0,
    double ap = 0.5,
    double ae = 1.0,
    double stepover = 0.4,
    double? stockRadius,
  }) async {
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

    final report = await PrismaticPipelineService.run(stepPath);
    return {...report, 'pipeline': 'freecad_prismatique'};
  }
}
