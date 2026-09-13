import 'dart:convert';
import 'dart:io';

import 'pipeline_locator.dart';

/// Maillage d'aperçu d'un fichier STEP, via `pipeline/step_preview.py`.
///
/// Le pipeline d'usinage lit le STEP pour sa géométrie EXACTE ; ici on veut
/// l'inverse — de quoi dessiner la pièce à l'écran, tout de suite, avant même
/// de savoir si elle est usinable. C'est ce qui manquait au visualiseur : il
/// ne savait afficher qu'un parcours d'outil, donc une pièce chargée mais pas
/// encore traitée n'avait aucune représentation.
///
/// Le résultat est mis en cache à côté du fichier source (`<piece>_apercu.json`)
/// et réutilisé tant que le STEP n'a pas changé : facettiser une pièce chargée
/// coûte quelques secondes, et l'opérateur ouvre souvent l'aperçu plusieurs
/// fois pendant une même session.
class StepPreviewService {
  const StepPreviewService._();

  /// Au-delà, le sous-processus est considéré perdu. Une pièce lourde met
  /// quelques secondes ; une minute veut dire que quelque chose est bloqué.
  static const _timeout = Duration(minutes: 1);

  static Future<StepPreview> run(String stepPath, {bool useCache = true}) async {
    final source = File(stepPath);
    if (!source.existsSync()) {
      throw StepPreviewException('Fichier introuvable : $stepPath');
    }

    final cache = File(_cachePathFor(stepPath));
    if (useCache && _cacheIsFresh(cache, source)) {
      try {
        return StepPreview.fromJson(
          jsonDecode(await cache.readAsString()) as Map<String, dynamic>,
        );
      } catch (_) {
        // Cache illisible (écriture interrompue) : on refacettise.
      }
    }

    final pipelineDir = PipelineLocator.findDir(marker: 'step_preview.py');
    if (pipelineDir == null) {
      throw const StepPreviewException(
        'Dossier pipeline introuvable (step_preview.py). '
        'Cette machine n\'a pas l\'environnement CAO installé.',
      );
    }
    final python = PipelineLocator.python(pipelineDir);
    if (python == null) {
      throw const StepPreviewException(
        'Environnement Python du pipeline STEP introuvable '
        '(pipeline/.venv312) — voir pipeline/requirements-step.txt.',
      );
    }

    final result = await Process.run(
      python,
      ['step_preview.py', stepPath, '-o', cache.path],
      workingDirectory: pipelineDir.path,
    ).timeout(
      _timeout,
      onTimeout: () => throw const StepPreviewException(
        'L\'aperçu a dépassé une minute — pièce trop lourde ou pipeline bloqué.',
      ),
    );

    if (result.exitCode != 0) {
      final out = (result.stdout as String).trim();
      final refus = out
          .split('\n')
          .firstWhere((l) => l.startsWith('REFUS'), orElse: () => '');
      throw StepPreviewException(
        refus.isNotEmpty
            ? refus
            : 'Aperçu impossible (code ${result.exitCode}) : ${result.stderr}',
      );
    }

    if (!cache.existsSync()) {
      throw const StepPreviewException(
        'Le script a réussi mais n\'a produit aucun maillage.',
      );
    }
    return StepPreview.fromJson(
      jsonDecode(await cache.readAsString()) as Map<String, dynamic>,
    );
  }

  static String _cachePathFor(String stepPath) {
    final dot = stepPath.lastIndexOf('.');
    final base = dot > 0 ? stepPath.substring(0, dot) : stepPath;
    return '${base}_apercu.json';
  }

  /// Un cache vaut mieux qu'une refacettisation, mais seulement s'il est plus
  /// récent que le STEP : un ré-export CAO sous le même nom doit se voir.
  static bool _cacheIsFresh(File cache, File source) {
    if (!cache.existsSync()) return false;
    try {
      return !cache.lastModifiedSync().isBefore(source.lastModifiedSync());
    } catch (_) {
      return false;
    }
  }
}

/// Maillage d'aperçu + ce qu'on sait de la pièce. [mesh] part tel quel vers
/// `web/three_viewer.html` (message `load_mesh`), sans reconstruction.
class StepPreview {
  const StepPreview({
    required this.mesh,
    required this.triangles,
    required this.volume,
    required this.size,
  });

  final Map<String, dynamic> mesh;
  final int triangles;

  /// Volume exact de la pièce (mm³) — calculé sur la géométrie analytique,
  /// pas sur les facettes.
  final double volume;

  /// Encombrement X/Y/Z (mm).
  final List<double> size;

  factory StepPreview.fromJson(Map<String, dynamic> json) {
    final bbox = (json['bbox'] as Map?)?.cast<String, dynamic>();
    return StepPreview(
      // Seuls les deux tableaux voyagent : le reste du JSON (volume, bbox,
      // chemin source) est pour l'app, pas pour la page.
      mesh: {
        'vertices': json['vertices'] ?? const <double>[],
        'indices': json['indices'] ?? const <int>[],
      },
      triangles: (json['triangles'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      size: ((bbox?['size'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(growable: false),
    );
  }

  /// « 30.0 × 20.0 × 10.0 mm », ou une chaîne vide si l'encombrement est
  /// inconnu.
  String get sizeLabel => size.length < 3
      ? ''
      : '${size[0].toStringAsFixed(1)} × ${size[1].toStringAsFixed(1)} × '
          '${size[2].toStringAsFixed(1)} mm';
}

class StepPreviewException implements Exception {
  const StepPreviewException(this.message);
  final String message;

  @override
  String toString() => message;
}
