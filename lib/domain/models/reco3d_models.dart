import 'package:freezed_annotation/freezed_annotation.dart';

part 'reco3d_models.freezed.dart';
part 'reco3d_models.g.dart';

@freezed
class Reco3dHealth with _$Reco3dHealth {
  const factory Reco3dHealth({
    required String status,
    @JsonKey(name: 'gpu_name') String? gpuName,
    @JsonKey(name: 'gpu_vram_total_mb') int? gpuVramTotalMb,
    @JsonKey(name: 'gpu_vram_free_mb') int? gpuVramFreeMb,
    @JsonKey(name: 'active_job_id') String? activeJobId,
    @JsonKey(name: 'queue_length', defaultValue: 0) required int queueLength,
    @Default(<String, String>{}) Map<String, String> engines,
  }) = _Reco3dHealth;

  factory Reco3dHealth.fromJson(Map<String, dynamic> json) =>
      _$Reco3dHealthFromJson(json);
}

@freezed
class Reco3dProvenance with _$Reco3dProvenance {
  const factory Reco3dProvenance({
    required String mode,
    required String engine,
    @JsonKey(name: 'engine_version') required String engineVersion,
    @JsonKey(name: 'has_scale_reference', defaultValue: false) required bool hasScaleReference,
    @JsonKey(name: 'scale_type', defaultValue: 'none') required String scaleType,
    @JsonKey(name: 'scale_factor') double? scaleFactor,
    @JsonKey(name: 'photo_count', defaultValue: 0) required int photoCount,
    @JsonKey(name: 'is_approximate', defaultValue: true) required bool isApproximate,
    @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0) required int unreconstructedHolesCount,
    @JsonKey(name: 'facets_count') int? facetsCount,
    @JsonKey(name: 'created_at') required String createdAt,
    @Default(<String>[]) List<String> notes,
  }) = _Reco3dProvenance;

  factory Reco3dProvenance.fromJson(Map<String, dynamic> json) =>
      _$Reco3dProvenanceFromJson(json);
}

@freezed
class Reco3dJobStatus with _$Reco3dJobStatus {
  const factory Reco3dJobStatus({
    @JsonKey(name: 'job_id') required String jobId,
    required String mode,
    required String stage,
    @JsonKey(name: 'progress_percent', defaultValue: 0.0) required double progressPercent,
    @Default('') String message,
    String? error,
    Reco3dProvenance? provenance,
    @JsonKey(name: 'has_step', defaultValue: false) required bool hasStep,
    @JsonKey(name: 'has_mesh', defaultValue: false) required bool hasMesh,
  }) = _Reco3dJobStatus;

  factory Reco3dJobStatus.fromJson(Map<String, dynamic> json) =>
      _$Reco3dJobStatusFromJson(json);
}

@freezed
class Reco3dJobCreated with _$Reco3dJobCreated {
  const factory Reco3dJobCreated({
    @JsonKey(name: 'job_id') required String jobId,
    required String mode,
    @JsonKey(name: 'queue_position', defaultValue: 0) required int queuePosition,
    required String message,
  }) = _Reco3dJobCreated;

  factory Reco3dJobCreated.fromJson(Map<String, dynamic> json) =>
      _$Reco3dJobCreatedFromJson(json);
}
