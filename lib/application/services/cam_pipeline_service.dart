import 'medical_implant_service.dart';
import 'step_pipeline_service.dart';
import 'prismatic_pipeline_service.dart';

/// Point d'entrée unique du pipeline CAO -> G-code pour l'agent IA :
/// - Si le fichier est un maillage `.stl` ou un modèle d'implant/guide médical
///   (STEP ou STL), délègue directement au pipeline 5 axes continu médical [MedicalImplantService] ;
/// - Sinon (`.step` / `.stp`), tente d'abord la révolution (rapide, analytique) ;
/// - Si la pièce n'est pas de révolution, bascule sur FreeCAD prismatique (poches, perçages) ;
/// - En repli universel pour les formes gauches/libres, utilise le surfaçage 5 axes continu.
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
    final lower = stepPath.toLowerCase();
    final isStl = lower.endsWith('.stl');
    final isMedicalKeyword = lower.contains('implant') ||
        lower.contains('cranial') ||
        lower.contains('cranien') ||
        lower.contains('guide') ||
        lower.contains('mandib') ||
        lower.contains('medical') ||
        lower.contains('ortho') ||
        lower.contains('prothes') ||
        lower.contains('dent') ||
        lower.contains('patient') ||
        lower.contains('plate') ||
        lower.contains('rend');

    // 1. Détection médicale prioritaire : implant crânien, guide, STL ou reconstruction 3D
    if (isStl || isMedicalKeyword) {
      final res = await MedicalImplantService.run(
        stepPath,
        toolDiameter: toolDiameter,
        ap: ap,
        ae: ae,
        stepover: stepover,
      );
      return {...res.report, 'pipeline': 'implant_medical_5x'};
    }

    // 2. Pièces de révolution tournées (axes cylindriques/coniques simples)
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
    } catch (_) {
      // Si la pièce n'est pas de révolution (refus motivé, timeout ou géométrie complexe),
      // bascule automatique vers le fraisage prismatique ou le surfaçage 5 axes.
    }

    // 3. Pièces mécaniques prismatiques (poches, perçages FreeCAD)
    try {
      final report = await PrismaticPipelineService.run(
        stepPath,
        toolDiameter: toolDiameter,
        ap: ap,
        ae: ae,
      );
      return {...report, 'pipeline': 'freecad_prismatique'};
    } catch (_) {
      // FreeCAD ne gère pas les surfaces organiques ou les formes gauches
    }

    // 4. Repli universel : surfaçage continu 5 axes (Drop-Cutter + cinématique trunnion)
    final res = await MedicalImplantService.run(
      stepPath,
      toolDiameter: toolDiameter,
      ap: ap,
      ae: ae,
      stepover: stepover,
    );
    return {...res.report, 'pipeline': 'surface_5x'};
  }
}
