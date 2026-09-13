import 'dart:convert';
import 'dart:io';

/// Exécute `pipeline/step_to_gcode.py` en sous-processus — pas de pont gRPC :
/// l'app desktop et le pipeline Python tournent sur la même machine, un
/// appel de sous-processus suffit pour ce premier branchement. Le pont
/// restera nécessaire le jour où pipeline et app tournent sur des postes
/// différents ; rien ici ne l'empêche.
class StepPipelineService {
  /// Cherche `pipeline/step_to_gcode.py` en remontant depuis le répertoire
  /// courant ET depuis celui de l'exécutable — `flutter run` et l'exe compilé
  /// (`build/windows/x64/runner/Debug/`) n'ont pas le même répertoire courant,
  /// et aucun des deux n'est fixe une fois l'app packagée.
  static Directory? _findPipelineDir() {
    for (final start in {
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    }) {
      var dir = start;
      for (var i = 0; i < 10; i++) {
        final candidate = Directory('${dir.path}${Platform.pathSeparator}pipeline');
        if (File('${candidate.path}${Platform.pathSeparator}step_to_gcode.py').existsSync()) {
          return candidate;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }

  static String? _pythonExecutable(Directory pipelineDir) {
    final candidates = Platform.isWindows
        ? ['.venv312/Scripts/python.exe', '.venv/Scripts/python.exe']
        : ['.venv312/bin/python', '.venv/bin/python'];
    for (final rel in candidates) {
      final path = '${pipelineDir.path}${Platform.pathSeparator}$rel';
      if (File(path.replaceAll('/', Platform.pathSeparator)).existsSync()) return path;
    }
    return null;
  }

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
    final python = _pythonExecutable(pipelineDir);
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
