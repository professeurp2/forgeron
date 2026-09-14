import 'dart:convert';
import 'dart:io';

import 'pipeline_locator.dart';

/// Exécute `pipeline/prismatic_to_gcode.py` — le pendant prismatique de
/// [StepPipelineService], phase 5.c du PLAN-IA (FreeCAD CAM, cas général).
///
/// Contrairement au pipeline de révolution, ce script ne tourne PAS dans
/// `pipeline/.venv312` : il s'exécute DANS l'interpréteur que FreeCAD
/// embarque (`freecadcmd.exe`), le seul moyen d'obtenir les modules
/// FreeCAD/Part/Path sans faire correspondre un venv à une version de
/// FreeCAD précise (voir pipeline/freecad/ et prismatic_to_gcode.py).
class PrismaticPipelineService {
  static Directory? _findPipelineDir() =>
      PipelineLocator.findDir(marker: 'prismatic_to_gcode.py');

  /// `pipeline/freecad/FreeCAD_<version>-Windows-x86_64-py311/bin/freecadcmd.exe`
  /// — le nom du dossier porte la version, donc une recherche plutôt qu'un
  /// chemin figé : elle survit à une mise à jour de FreeCAD.
  static File? _freecadcmd(Directory pipelineDir) {
    final freecadDir = Directory('${pipelineDir.path}${Platform.pathSeparator}freecad');
    if (!freecadDir.existsSync()) return null;
    for (final entry in freecadDir.listSync()) {
      if (entry is! Directory) continue;
      final exe = File('${entry.path}${Platform.pathSeparator}bin${Platform.pathSeparator}'
          '${Platform.isWindows ? 'freecadcmd.exe' : 'freecadcmd'}');
      if (exe.existsSync()) return exe;
    }
    return null;
  }

  /// Lance le pipeline prismatique sur [stepPath]. Retourne le rapport
  /// (opérations, faces de poche détectées, perçages, chemin du G-code, et
  /// le détail des réglages appliqués à FreeCAD).
  ///
  /// Les conditions de coupe ne sont PAS facultatives ici. Laissées aux
  /// défauts de FreeCAD, elles décrivent une fraiseuse ordinaire : profondeur
  /// de passe au millimètre, recouvrement de poche à 100 % du diamètre, et un
  /// outil dont le diamètre n'est pas celui monté sur la broche — donc un
  /// contour décalé sur toute la pièce. Les valeurs par défaut ci-dessous
  /// sont celles de `gen_revolution.CutParams`, plafonnées par la vibration.
  static Future<Map<String, dynamic>> run(
    String stepPath, {
    double toolDiameter = 6.0,
    double ap = 0.2,
    double ae = 0.5,
    double feed = 500.0,
    double plunge = 100.0,
    int spindle = 1000,
    double peck = 1.0,
  }) async {
    final pipelineDir = _findPipelineDir();
    if (pipelineDir == null) {
      throw const PrismaticPipelineException(
        'Dossier pipeline introuvable (prismatic_to_gcode.py).',
      );
    }
    final freecadcmd = _freecadcmd(pipelineDir);
    if (freecadcmd == null) {
      throw const PrismaticPipelineException(
        'FreeCAD introuvable sous pipeline/freecad/ — voir le commit qui l\'a ajouté.',
      );
    }
    if (!File(stepPath).existsSync()) {
      throw PrismaticPipelineException('Fichier introuvable : $stepPath');
    }

    final base = stepPath.contains('.') ? stepPath.substring(0, stepPath.lastIndexOf('.')) : stepPath;
    final outPath = '${base}_freecad.nc';

    final result = await Process.run(
      freecadcmd.path,
      [
        '${pipelineDir.path}${Platform.pathSeparator}prismatic_to_gcode.py',
        stepPath,
        outPath,
        '--outil', '$toolDiameter',
        '--ap', '$ap',
        '--ae', '$ae',
        '--avance', '$feed',
        '--plongee', '$plunge',
        '--broche', '$spindle',
        '--debourrage', '$peck',
      ],
    );

    if (result.exitCode != 0) {
      final stdoutText = (result.stdout as String).trim();
      final refus = stdoutText
          .split('\n')
          .firstWhere((l) => l.startsWith('REFUS'), orElse: () => '');
      throw PrismaticPipelineException(
        refus.isNotEmpty
            ? refus
            : 'Échec du pipeline FreeCAD (code ${result.exitCode}) : ${result.stderr}',
      );
    }

    final reportFile = File('${outPath.substring(0, outPath.lastIndexOf('.'))}_rapport.json');
    if (!reportFile.existsSync()) {
      throw const PrismaticPipelineException('FreeCAD a réussi mais n\'a produit aucun rapport.');
    }
    return jsonDecode(await reportFile.readAsString()) as Map<String, dynamic>;
  }
}

class PrismaticPipelineException implements Exception {
  const PrismaticPipelineException(this.message);
  final String message;

  @override
  String toString() => message;
}
