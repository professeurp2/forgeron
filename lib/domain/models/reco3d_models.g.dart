// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reco3d_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$Reco3dHealthImpl _$$Reco3dHealthImplFromJson(Map<String, dynamic> json) =>
    _$Reco3dHealthImpl(
      status: json['status'] as String,
      gpuName: json['gpu_name'] as String?,
      gpuVramTotalMb: (json['gpu_vram_total_mb'] as num?)?.toInt(),
      gpuVramFreeMb: (json['gpu_vram_free_mb'] as num?)?.toInt(),
      activeJobId: json['active_job_id'] as String?,
      queueLength: (json['queue_length'] as num?)?.toInt() ?? 0,
      engines:
          (json['engines'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const <String, String>{},
    );

Map<String, dynamic> _$$Reco3dHealthImplToJson(_$Reco3dHealthImpl instance) =>
    <String, dynamic>{
      'status': instance.status,
      'gpu_name': instance.gpuName,
      'gpu_vram_total_mb': instance.gpuVramTotalMb,
      'gpu_vram_free_mb': instance.gpuVramFreeMb,
      'active_job_id': instance.activeJobId,
      'queue_length': instance.queueLength,
      'engines': instance.engines,
    };

_$Reco3dProvenanceImpl _$$Reco3dProvenanceImplFromJson(
  Map<String, dynamic> json,
) => _$Reco3dProvenanceImpl(
  mode: json['mode'] as String,
  engine: json['engine'] as String,
  engineVersion: json['engine_version'] as String,
  hasScaleReference: json['has_scale_reference'] as bool? ?? false,
  scaleType: json['scale_type'] as String? ?? 'none',
  scaleFactor: (json['scale_factor'] as num?)?.toDouble(),
  photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
  isApproximate: json['is_approximate'] as bool? ?? true,
  unreconstructedHolesCount:
      (json['unreconstructed_holes_count'] as num?)?.toInt() ?? 0,
  facetsCount: (json['facets_count'] as num?)?.toInt(),
  createdAt: json['created_at'] as String,
  notes:
      (json['notes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$$Reco3dProvenanceImplToJson(
  _$Reco3dProvenanceImpl instance,
) => <String, dynamic>{
  'mode': instance.mode,
  'engine': instance.engine,
  'engine_version': instance.engineVersion,
  'has_scale_reference': instance.hasScaleReference,
  'scale_type': instance.scaleType,
  'scale_factor': instance.scaleFactor,
  'photo_count': instance.photoCount,
  'is_approximate': instance.isApproximate,
  'unreconstructed_holes_count': instance.unreconstructedHolesCount,
  'facets_count': instance.facetsCount,
  'created_at': instance.createdAt,
  'notes': instance.notes,
};

_$Reco3dJobStatusImpl _$$Reco3dJobStatusImplFromJson(
  Map<String, dynamic> json,
) => _$Reco3dJobStatusImpl(
  jobId: json['job_id'] as String,
  mode: json['mode'] as String,
  stage: json['stage'] as String,
  progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
  message: json['message'] as String? ?? '',
  error: json['error'] as String?,
  provenance: json['provenance'] == null
      ? null
      : Reco3dProvenance.fromJson(json['provenance'] as Map<String, dynamic>),
  hasStep: json['has_step'] as bool? ?? false,
  hasMesh: json['has_mesh'] as bool? ?? false,
);

Map<String, dynamic> _$$Reco3dJobStatusImplToJson(
  _$Reco3dJobStatusImpl instance,
) => <String, dynamic>{
  'job_id': instance.jobId,
  'mode': instance.mode,
  'stage': instance.stage,
  'progress_percent': instance.progressPercent,
  'message': instance.message,
  'error': instance.error,
  'provenance': instance.provenance,
  'has_step': instance.hasStep,
  'has_mesh': instance.hasMesh,
};

_$Reco3dJobCreatedImpl _$$Reco3dJobCreatedImplFromJson(
  Map<String, dynamic> json,
) => _$Reco3dJobCreatedImpl(
  jobId: json['job_id'] as String,
  mode: json['mode'] as String,
  queuePosition: (json['queue_position'] as num?)?.toInt() ?? 0,
  message: json['message'] as String,
);

Map<String, dynamic> _$$Reco3dJobCreatedImplToJson(
  _$Reco3dJobCreatedImpl instance,
) => <String, dynamic>{
  'job_id': instance.jobId,
  'mode': instance.mode,
  'queue_position': instance.queuePosition,
  'message': instance.message,
};
