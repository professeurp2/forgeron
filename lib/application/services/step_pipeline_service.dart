import 'dart:convert';
import 'dart:io';

import 'pipeline_locator.dart';

/// Exécute `pipeline/step_to_gcode.py` en sous-processus — pas de pont gRPC :
/// l'app desktop et le pipeline Python tournent sur la même machine, un
/// appel de sous-processus suffit pour ce premier branchement. Le pont
/// restera nécessaire le jour où pipeline et app tournent sur des postes
/// différents ; rien ici ne l'empêche.
class StepPipelineService {
  static Directory? _findPipelineDir() =>
      PipelineLocator.findDir(marker: 'step_to_gcode.py');

  /// Lance le pipeline complet sur [stepPath]. Retourne le rapport (mêmes
  /// clés que `gen_revolution.generate`, plus `gcode_path`/`profile_csv_path`)
  /// en cas de succès ; lève [StepPipelineException] sinon — refus motivé
  /// (pièce non reconnue comme une révolution) ou erreur d'environnement.
  static Future<Map<String, dynamic>> run(
    String stepPath, {
    double toolDia = 6.0,
    double ap = 0.5,
    double ae = 1.0,
    double stepover = 0.4,
  }) async {
    final pipelineDir = _findPipelineDir();
    if (pipelineDir == null) {
      throw const StepPipelineException(
        'Dossier pipeline introuvable (step_to_gcode.py). '
        'Cette machine n\'a pas l\'environnement CAO installé.',
      );
    }
    final python = PipelineLocator.python(pipelineDir);
    if (python == null) {
      throw const StepPipelineException(
        'Environnement Python du pipeline STEP introuvable '
        '(pipeline/.venv312) — voir pipeline/requirements-step.txt.',
      );
    }
    if (!File(stepPath).existsSync()) {
      throw StepPipelineException('Fichier introuvable : $stepPath');
    }

    final result = await Process.run(
      python,
      [
        'step_to_gcode.py',
        stepPath,
        '--outil', '$toolDia',
        '--ap', '$ap',
        '--ae', '$ae',
        '--stepover', '$stepover',
      ],
      workingDirectory: pipelineDir.path,
    );

    if (result.exitCode != 0) {
      final stdoutText = (result.stdout as String).trim();
      final refus = stdoutText
          .split('\n')
          .firstWhere((l) => l.startsWith('REFUS'), orElse: () => '');
      throw StepPipelineException(
        refus.isNotEmpty ? refus : 'Échec du pipeline (code ${result.exitCode}) : ${result.stderr}',
      );
    }

    final base = stepPath.contains('.') ? stepPath.substring(0, stepPath.lastIndexOf('.')) : stepPath;
    final reportFile = File('${base}_rapport.json');
    if (!reportFile.existsSync()) {
      throw const StepPipelineException('Le pipeline a réussi mais n\'a produit aucun rapport.');
    }
    return jsonDecode(await reportFile.readAsString()) as Map<String, dynamic>;
  }
}

class StepPipelineException implements Exception {
  const StepPipelineException(this.message);
  final String message;

  @override
  String toString() => message;
}
