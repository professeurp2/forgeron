import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/medical_material.dart';
import '../services/medical_implant_service.dart';
import 'activity_log_provider.dart';
import 'ai_artifacts_provider.dart';
import 'gcode_provider.dart';

class MedicalImplantState {
  const MedicalImplantState({
    this.stlFile,
    this.material = MedicalMaterialId.peek,
    this.implantType = MedicalImplantType.cranialPlate,
    this.lotId = 'LOT-MED-2026-01',
    this.patientRef = 'CAS-ANONYME-01',
    this.targetLengthMm,
    this.fiveAxis = true,
    this.provenanceApproximate = false,
    this.isGenerating = false,
    this.errorMessage,
    this.result,
  });

  final File? stlFile;
  final MedicalMaterialId material;
  final MedicalImplantType implantType;
  final String lotId;
  final String patientRef;
  final double? targetLengthMm;
  final bool fiveAxis;
  final bool provenanceApproximate;
  final bool isGenerating;
  final String? errorMessage;
  final MedicalImplantResult? result;

  MedicalMaterialSpec get materialSpec => material.spec;

  /// Indique si un garde-fou bloque immédiatement la configuration courante
  /// (métal hors capacité machine ou scan approximatif sans cote pour un implant).
  String? get guardrailBlocker {
    try {
      MedicalImplantService.validateGuardrails(
        material: material,
        implantType: implantType,
        provenanceApproximate: provenanceApproximate,
        targetLengthMm: targetLengthMm,
      );
      return null;
    } on MedicalImplantException catch (e) {
      return e.message;
    }
  }

  MedicalImplantState copyWith({
    File? stlFile,
    MedicalMaterialId? material,
    MedicalImplantType? implantType,
    String? lotId,
    String? patientRef,
    double? targetLengthMm,
    bool clearTargetLength = false,
    bool? fiveAxis,
    bool? provenanceApproximate,
    bool? isGenerating,
    String? errorMessage,
    bool clearError = false,
    MedicalImplantResult? result,
    bool clearResult = false,
  }) {
    return MedicalImplantState(
      stlFile: stlFile ?? this.stlFile,
      material: material ?? this.material,
      implantType: implantType ?? this.implantType,
      lotId: lotId ?? this.lotId,
      patientRef: patientRef ?? this.patientRef,
      targetLengthMm:
          clearTargetLength ? null : (targetLengthMm ?? this.targetLengthMm),
      fiveAxis: fiveAxis ?? this.fiveAxis,
      provenanceApproximate:
          provenanceApproximate ?? this.provenanceApproximate,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class MedicalImplantNotifier extends StateNotifier<MedicalImplantState> {
  MedicalImplantNotifier(this._ref) : super(const MedicalImplantState());

  final Ref _ref;

  void selectStlFile(File file, {required bool provenanceApproximate}) {
    state = state.copyWith(
      stlFile: file,
      provenanceApproximate: provenanceApproximate,
      clearError: true,
      clearResult: true,
    );
  }

  void setMaterial(MedicalMaterialId material) {
    state = state.copyWith(
      material: material,
      clearError: true,
      clearResult: true,
    );
  }

  void setImplantType(MedicalImplantType implantType) {
    state = state.copyWith(
      implantType: implantType,
      clearError: true,
      clearResult: true,
    );
  }

  void setLotInfo({String? lotId, String? patientRef}) {
    state = state.copyWith(
      lotId: lotId,
      patientRef: patientRef,
    );
  }

  void setTargetLengthMm(double? value) {
    if (value == null || value <= 0) {
      state = state.copyWith(clearTargetLength: true, clearError: true);
    } else {
      state = state.copyWith(targetLengthMm: value, clearError: true);
    }
  }

  void setFiveAxis(bool value) {
    state = state.copyWith(fiveAxis: value, clearError: true, clearResult: true);
  }

  Future<MedicalImplantResult?> generateProgram({
    File? overrideStlFile,
    bool? overrideProvenanceApproximate,
  }) async {
    final targetFile = overrideStlFile ?? state.stlFile;
    final approx = overrideProvenanceApproximate ?? state.provenanceApproximate;
    if (targetFile == null) {
      state = state.copyWith(
        errorMessage: 'Veuillez sélectionner ou scanner un fichier STL médical.',
      );
      return null;
    }

    state = state.copyWith(
      stlFile: targetFile,
      provenanceApproximate: approx,
      isGenerating: true,
      clearError: true,
    );

    try {
      final res = await MedicalImplantService.run(
        targetFile.path,
        material: state.material,
        implantType: state.implantType,
        targetLengthMm: state.targetLengthMm,
        lotId: state.lotId,
        patientRef: state.patientRef,
        fiveAxis: state.fiveAxis,
        provenanceApproximate: approx,
      );

      // Déclarer les artefacts 3D (maillage STL préparé + parcours G-code)
      final artifacts = _ref.read(aiArtifactsProvider.notifier);
      artifacts.setGcodeFromReport(res.report);
      await artifacts.loadStep(targetFile.path, force: true);

      // Charger le programme dans le contrôleur G-code de la machine
      final gcodeContent = await File(res.gcodePath).readAsString();
      await _ref.read(gcodeProvider.notifier).loadFile(gcodeContent);

      // Journaliser dans le journal d'activité machine
      _ref.read(activityLogProvider.notifier).log(
            'Lot médical ${res.dossier.lotId} (${res.dossier.material.id.wire.toUpperCase()}) '
            'généré : ${res.dossier.gcodeLines} lignes, ${res.dossier.durationTotalMin.toStringAsFixed(1)} min',
          );

      state = state.copyWith(
        isGenerating: false,
        result: res,
      );
      return res;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }
}

final medicalImplantProvider =
    StateNotifierProvider<MedicalImplantNotifier, MedicalImplantState>(
  (ref) => MedicalImplantNotifier(ref),
);

