import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/utils/gcode_critic.dart';
import '../../domain/models/medical_material.dart';
import 'pipeline_locator.dart';

/// Résultat complet d'une préparation et génération d'implant médical.
class MedicalImplantResult {
  const MedicalImplantResult({
    required this.report,
    required this.dossier,
    required this.critique,
    required this.gcodePath,
    required this.previewJsonPath,
    required this.dossierJsonPath,
  });

  final Map<String, dynamic> report;
  final MedicalDossier dossier;
  final GcodeCritique critique;
  final String gcodePath;
  final String previewJsonPath;
  final String dossierJsonPath;
}

/// Exécute `pipeline/medical_implant.py` pour transformer un maillage `.stl`
/// (issu d'une segmentation DICOM ou d'un scan 3D) ou un modèle CAO `.step`
/// en un programme G-code d'usinage médical (ébauche 3 axes + finition 5 axes continu)
/// accompagné de son dossier de traçabilité ISO 13485.
class MedicalImplantService {
  const MedicalImplantService._();

  static Directory? _findPipelineDir() =>
      PipelineLocator.findDir(marker: 'medical_implant.py');

  /// Vérifie de façon purement déterministe si [material] et la provenance sont
  /// autorisés sur la machine Forgeron, avant même de lancer Python.
  static void validateGuardrails({
    required MedicalMaterialId material,
    required MedicalImplantType implantType,
    required bool provenanceApproximate,
    double? targetLengthMm,
  }) {
    final spec = material.spec;
    if (!spec.machinable) {
      throw MedicalImplantException(
        'REFUS : ${spec.name} (${spec.standard}) — ${spec.refusalReason}',
      );
    }
    if (provenanceApproximate &&
        implantType != MedicalImplantType.anatomicalModel &&
        (targetLengthMm == null || targetLengthMm <= 0)) {
      throw const MedicalImplantException(
        'REFUS : Ce modèle 3D provient d\'une reconstruction approximative sans '
        'mire métrique certifiée. Pour usiner un implant ou un guide chirurgical, '
        'indiquez une longueur cible exacte (en mm) ou choisissez « Modèle '
        'anatomique pré-opératoire ».',
      );
    }
  }

  static Future<MedicalImplantResult> run(
    String stlPath, {
    MedicalMaterialId material = MedicalMaterialId.peek,
    MedicalImplantType implantType = MedicalImplantType.cranialPlate,
    double toolDiameter = 6.0,
    double? ap,
    double? ae,
    double? stepover,
    double? targetLengthMm,
    double? stepDeflection,
    String lotId = 'LOT-MED-AUTO',
    String patientRef = 'PAT-ANONYME',
    bool fiveAxis = true,
    bool autoOrient = true,
    bool autoFit = true,
    bool provenanceApproximate = false,
  }) async {
    validateGuardrails(
      material: material,
      implantType: implantType,
      provenanceApproximate: provenanceApproximate,
      targetLengthMm: targetLengthMm,
    );

    final modelFile = File(stlPath);
    if (!modelFile.existsSync()) {
      throw MedicalImplantException('Fichier 3D introuvable : $stlPath');
    }
    final lower = stlPath.toLowerCase();
    if (!lower.endsWith('.stl') && !lower.endsWith('.step') && !lower.endsWith('.stp')) {
      throw MedicalImplantException(
        'Format 3D non pris en charge ($stlPath). Formats acceptés : .stl (maillage) et .step/.stp (CAO B-Rep).',
      );
    }

    final pipelineDir = _findPipelineDir();
    if (pipelineDir == null) {
      throw const MedicalImplantException(
        'Dossier pipeline introuvable (medical_implant.py). '
        'Cette machine n\'a pas l\'environnement CAO installé.',
      );
    }
    final python = PipelineLocator.python(pipelineDir);
    if (python == null) {
      throw const MedicalImplantException(
        'Environnement Python du pipeline introuvable (pipeline/.venv312 ou .venv).',
      );
    }

    final absStlPath = modelFile.absolute.path;
    final args = <String>[
      'medical_implant.py',
      absStlPath,
      '--materiau',
      material.wire,
      '--type-implant',
      implantType.wire,
      '--outil',
      '$toolDiameter',
      '--lot',
      lotId.trim().isEmpty ? 'LOT-MED-AUTO' : lotId.trim(),
      '--patient',
      patientRef.trim().isEmpty ? 'PAT-ANONYME' : patientRef.trim(),
      if (ap != null) ...['--ap', '$ap'],
      if (ae != null) ...['--ae', '$ae'],
      if (stepover != null) ...['--stepover', '$stepover'],
      if (targetLengthMm != null && targetLengthMm > 0) ...[
        '--longueur-cible',
        '$targetLengthMm',
      ],
      if (stepDeflection != null && stepDeflection > 0) ...[
        '--deflection',
        '$stepDeflection',
      ],
      if (!fiveAxis) '--trois-axes',
      if (!autoOrient) '--sans-reorientation',
      if (!autoFit) '--sans-auto-fit',
      if (provenanceApproximate) '--provenance-approx',
    ];

    final ProcessResult proc;
    try {
      proc = await Process.run(
        python,
        args,
        workingDirectory: pipelineDir.path,
      ).timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw const MedicalImplantException(
        'Délai dépassé (120 s) lors de la génération du parcours d\'implant médical.',
      );
    }

    if (proc.exitCode != 0) {
      final stdoutText = (proc.stdout as String).trim();
      final refus = stdoutText
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.startsWith('REFUS'), orElse: () => '');
      throw MedicalImplantException(
        refus.isNotEmpty
            ? refus
            : 'Échec du pipeline médical (code ${proc.exitCode}) : ${proc.stderr}',
      );
    }

    final base = absStlPath.contains('.')
        ? absStlPath.substring(0, absStlPath.lastIndexOf('.'))
        : absStlPath;
    final reportFile = File('${base}_rapport.json');
    final dossierFile = File('${base}_dossier_medical.json');
    if (!reportFile.existsSync() || !dossierFile.existsSync()) {
      throw const MedicalImplantException(
        'Le pipeline médical a terminé sans produire son rapport ou son dossier ISO 13485.',
      );
    }

    final report =
        jsonDecode(await reportFile.readAsString()) as Map<String, dynamic>;
    final dossierJson =
        jsonDecode(await dossierFile.readAsString()) as Map<String, dynamic>;
    final dossier = MedicalDossier.fromJson(dossierJson);

    final gcodePath = (report['gcode_path'] as String?) ?? '${base}_implant.nc';
    final gcodeContent = await File(gcodePath).readAsString();
    final critique = const GcodeCritic(medicalMode: true).review(gcodeContent);

    return MedicalImplantResult(
      report: {
        ...report,
        'critique_medicale': critique.toJson(),
      },
      dossier: dossier,
      critique: critique,
      gcodePath: gcodePath,
      previewJsonPath: (report['preview_json_path'] as String?) ?? '${base}_apercu.json',
      dossierJsonPath: dossierFile.path,
    );
  }
}

class MedicalImplantException implements Exception {
  const MedicalImplantException(this.message);
  final String message;

  @override
  String toString() => message;
}
