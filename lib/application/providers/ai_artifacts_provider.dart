import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/step_preview_service.dart';

/// Ce que la discussion en cours a produit de VISUALISABLE : la pièce STEP
/// chargée et son maillage d'aperçu, puis le G-code que le pipeline en a tiré.
///
/// Sans cet état, la console n'avait aucun moyen de savoir qu'une pièce était
/// chargée : elle devait deviner en relisant le texte des messages d'outils.
/// Ici, chaque outil déclare ce qu'il vient de produire, et l'écran se
/// contente de l'afficher — et d'en proposer l'ouverture dans une fenêtre 3D.
class AiArtifacts {
  const AiArtifacts({this.step, this.gcode});

  final StepArtifact? step;
  final GcodeArtifact? gcode;

  bool get isEmpty => step == null && gcode == null;

  AiArtifacts copyWith({
    StepArtifact? step,
    GcodeArtifact? gcode,
    bool clearStep = false,
    bool clearGcode = false,
  }) =>
      AiArtifacts(
        step: clearStep ? null : (step ?? this.step),
        gcode: clearGcode ? null : (gcode ?? this.gcode),
      );
}

/// Une pièce STEP chargée. [preview] arrive après coup : facettiser prend
/// quelques secondes, et l'écran doit pouvoir annoncer la pièce tout de suite.
class StepArtifact {
  const StepArtifact({
    required this.path,
    this.preview,
    this.loading = false,
    this.error,
  });

  final String path;
  final StepPreview? preview;
  final bool loading;
  final String? error;

  String get fileName => path.split(RegExp(r'[/\\]')).last;
  bool get hasMesh => preview != null;
}

/// Un programme produit par le pipeline.
class GcodeArtifact {
  const GcodeArtifact({
    required this.path,
    this.pipeline = '',
    this.lines,
    this.operations,
  });

  final String path;

  /// `revolution` ou `freecad_prismatique` — ce que le rapport annonce.
  final String pipeline;
  final int? lines;
  final int? operations;

  String get fileName => path.split(RegExp(r'[/\\]')).last;

  String get pipelineLabel => switch (pipeline) {
        'revolution' => 'pièce de révolution',
        'freecad_prismatique' => 'pièce prismatique (FreeCAD)',
        _ => '',
      };
}

class AiArtifactsNotifier extends StateNotifier<AiArtifacts> {
  AiArtifactsNotifier() : super(const AiArtifacts());

  /// Déclare la pièce chargée et lance la facettisation en arrière-plan.
  ///
  /// Repasser le même chemin ne relance rien si l'aperçu est déjà là : c'est
  /// le cas courant — l'agent mentionne le même fichier à plusieurs tours.
  Future<void> loadStep(String path, {bool force = false}) async {
    final current = state.step;
    if (!force && current?.path == path && (current!.hasMesh || current.loading)) {
      return;
    }
    state = state.copyWith(step: StepArtifact(path: path, loading: true));
    try {
      final preview = await StepPreviewService.run(path, useCache: !force);
      // Une autre pièce a été chargée pendant la facettisation : ce résultat
      // ne concerne plus l'écran, on le laisse tomber.
      if (state.step?.path != path) return;
      state = state.copyWith(step: StepArtifact(path: path, preview: preview));
    } catch (e) {
      if (state.step?.path != path) return;
      state = state.copyWith(step: StepArtifact(path: path, error: '$e'));
    }
  }

  /// Déclare le programme produit par le pipeline, d'après son rapport JSON.
  void setGcodeFromReport(Map<String, dynamic> report) {
    final path = report['gcode_path'] as String?;
    if (path == null) return;
    state = state.copyWith(
      gcode: GcodeArtifact(
        path: path,
        pipeline: report['pipeline'] as String? ?? '',
        lines: (report['lignes_gcode'] as num?)?.toInt(),
        operations: (report['operations'] as List?)?.length,
      ),
    );
  }

  void setGcodePath(String path) =>
      state = state.copyWith(gcode: GcodeArtifact(path: path));

  /// Nouvelle discussion : les aperçus de l'ancienne n'ont plus lieu d'être.
  void clear() => state = const AiArtifacts();
}

final aiArtifactsProvider =
    StateNotifierProvider<AiArtifactsNotifier, AiArtifacts>(
  (ref) => AiArtifactsNotifier(),
);
