import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/reco3d_models.dart';
import '../services/reco3d_client.dart';

/// URL par défaut du service de calcul reco3d sur le PC local.
const kDefaultReco3dUrl = 'http://192.168.0.10:8765';

final reco3dServerUrlProvider = StateProvider<String>((ref) => kDefaultReco3dUrl);

final reco3dClientProvider = Provider<Reco3dClient>((ref) {
  final client = Reco3dClient();
  ref.onDispose(client.close);
  return client;
});

final reco3dHealthProvider = FutureProvider.autoDispose<Reco3dHealth>((ref) async {
  final client = ref.watch(reco3dClientProvider);
  final rawUrl = ref.watch(reco3dServerUrlProvider);
  final uri = Uri.parse(rawUrl);
  return client.checkHealth(uri);
});

class Reco3dScanState {
  const Reco3dScanState({
    this.isScanning = false,
    this.stage = '',
    this.progressPercent = 0.0,
    this.message = '',
    this.errorMessage,
    this.activeJobId,
    this.downloadedMeshFile,
    this.downloadedStepFile,
    this.provenance,
  });

  final bool isScanning;
  final String stage;
  final double progressPercent;
  final String message;
  final String? errorMessage;
  final String? activeJobId;
  final File? downloadedMeshFile;
  final File? downloadedStepFile;
  final Reco3dProvenance? provenance;

  bool get isDone => stage == 'done' && downloadedMeshFile != null;
  bool get hasError => errorMessage != null;

  Reco3dScanState copyWith({
    bool? isScanning,
    String? stage,
    double? progressPercent,
    String? message,
    String? errorMessage,
    String? activeJobId,
    File? downloadedMeshFile,
    File? downloadedStepFile,
    Reco3dProvenance? provenance,
  }) {
    return Reco3dScanState(
      isScanning: isScanning ?? this.isScanning,
      stage: stage ?? this.stage,
      progressPercent: progressPercent ?? this.progressPercent,
      message: message ?? this.message,
      errorMessage: errorMessage,
      activeJobId: activeJobId ?? this.activeJobId,
      downloadedMeshFile: downloadedMeshFile ?? this.downloadedMeshFile,
      downloadedStepFile: downloadedStepFile ?? this.downloadedStepFile,
      provenance: provenance ?? this.provenance,
    );
  }
}

class Reco3dScanNotifier extends StateNotifier<Reco3dScanState> {
  Reco3dScanNotifier(this._ref) : super(const Reco3dScanState());

  final Ref _ref;

  void reset() {
    state = const Reco3dScanState();
  }

  /// Déclenche la chaîne complète : envoi des photos -> attente GPU -> téléchargement du maillage natif et de la provenance.
  Future<void> submitAndProcess({
    required List<File> photos,
    required String mode, // 'photo' ou 'gen'
    String scaleType = 'none',
    double? scaleMm,
    required Directory storageDir,
  }) async {
    final client = _ref.read(reco3dClientProvider);
    final rawUrl = _ref.read(reco3dServerUrlProvider);
    final uri = Uri.parse(rawUrl);

    state = state.copyWith(
      isScanning: true,
      stage: 'uploading',
      progressPercent: 5.0,
      message: 'Téléversement de ${photos.length} photos vers le poste de calcul...',
      errorMessage: null,
    );

    try {
      final jobCreated = await client.createJob(
        baseUri: uri,
        mode: mode,
        scaleType: scaleType,
        scaleMm: scaleMm,
        photos: photos,
      );

      state = state.copyWith(
        activeJobId: jobCreated.jobId,
        stage: 'queued',
        progressPercent: 10.0,
        message: jobCreated.message,
      );

      final finalStatus = await client.pollUntilDone(
        uri,
        jobCreated.jobId,
        pollInterval: const Duration(milliseconds: 800),
        onProgress: (status) {
          state = state.copyWith(
            stage: status.stage,
            progressPercent: status.progressPercent,
            message: status.message,
          );
        },
      );

      // Récupération de la fiche de provenance
      Reco3dProvenance? prov;
      try {
        prov = await client.getProvenance(uri, jobCreated.jobId);
      } catch (_) {
        prov = finalStatus.provenance;
      }

      // Téléchargement du maillage natif (flux de fabrication direct validé au Jalon 0)
      final destMesh = File('${storageDir.path}/${jobCreated.jobId}.stl');
      await client.downloadResult(uri, jobCreated.jobId, format: 'mesh', destination: destMesh);

      // Téléchargement optionnel du STEP s'il est produit
      File? destStep;
      if (finalStatus.hasStep) {
        try {
          destStep = File('${storageDir.path}/${jobCreated.jobId}.step');
          await client.downloadResult(uri, jobCreated.jobId, format: 'step', destination: destStep);
        } catch (_) {}
      }

      state = state.copyWith(
        isScanning: false,
        stage: 'done',
        progressPercent: 100.0,
        message: 'Scan 3D finalisé avec succès.',
        downloadedMeshFile: destMesh,
        downloadedStepFile: destStep,
        provenance: prov,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        stage: 'failed',
        errorMessage: e.toString(),
        message: 'Erreur lors du scan 3D',
      );
    }
  }
}

final reco3dScanProvider =
    StateNotifierProvider.autoDispose<Reco3dScanNotifier, Reco3dScanState>(
  (ref) => Reco3dScanNotifier(ref),
);
