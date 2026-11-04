// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reco3d_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Reco3dHealth _$Reco3dHealthFromJson(Map<String, dynamic> json) {
  return _Reco3dHealth.fromJson(json);
}

/// @nodoc
mixin _$Reco3dHealth {
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'gpu_name')
  String? get gpuName => throw _privateConstructorUsedError;
  @JsonKey(name: 'gpu_vram_total_mb')
  int? get gpuVramTotalMb => throw _privateConstructorUsedError;
  @JsonKey(name: 'gpu_vram_free_mb')
  int? get gpuVramFreeMb => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_job_id')
  String? get activeJobId => throw _privateConstructorUsedError;
  @JsonKey(name: 'queue_length', defaultValue: 0)
  int get queueLength => throw _privateConstructorUsedError;
  Map<String, String> get engines => throw _privateConstructorUsedError;

  /// Serializes this Reco3dHealth to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Reco3dHealth
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Reco3dHealthCopyWith<Reco3dHealth> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Reco3dHealthCopyWith<$Res> {
  factory $Reco3dHealthCopyWith(
    Reco3dHealth value,
    $Res Function(Reco3dHealth) then,
  ) = _$Reco3dHealthCopyWithImpl<$Res, Reco3dHealth>;
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'gpu_name') String? gpuName,
    @JsonKey(name: 'gpu_vram_total_mb') int? gpuVramTotalMb,
    @JsonKey(name: 'gpu_vram_free_mb') int? gpuVramFreeMb,
    @JsonKey(name: 'active_job_id') String? activeJobId,
    @JsonKey(name: 'queue_length', defaultValue: 0) int queueLength,
    Map<String, String> engines,
  });
}

/// @nodoc
class _$Reco3dHealthCopyWithImpl<$Res, $Val extends Reco3dHealth>
    implements $Reco3dHealthCopyWith<$Res> {
  _$Reco3dHealthCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Reco3dHealth
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? gpuName = freezed,
    Object? gpuVramTotalMb = freezed,
    Object? gpuVramFreeMb = freezed,
    Object? activeJobId = freezed,
    Object? queueLength = null,
    Object? engines = null,
  }) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            gpuName: freezed == gpuName
                ? _value.gpuName
                : gpuName // ignore: cast_nullable_to_non_nullable
                      as String?,
            gpuVramTotalMb: freezed == gpuVramTotalMb
                ? _value.gpuVramTotalMb
                : gpuVramTotalMb // ignore: cast_nullable_to_non_nullable
                      as int?,
            gpuVramFreeMb: freezed == gpuVramFreeMb
                ? _value.gpuVramFreeMb
                : gpuVramFreeMb // ignore: cast_nullable_to_non_nullable
                      as int?,
            activeJobId: freezed == activeJobId
                ? _value.activeJobId
                : activeJobId // ignore: cast_nullable_to_non_nullable
                      as String?,
            queueLength: null == queueLength
                ? _value.queueLength
                : queueLength // ignore: cast_nullable_to_non_nullable
                      as int,
            engines: null == engines
                ? _value.engines
                : engines // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$Reco3dHealthImplCopyWith<$Res>
    implements $Reco3dHealthCopyWith<$Res> {
  factory _$$Reco3dHealthImplCopyWith(
    _$Reco3dHealthImpl value,
    $Res Function(_$Reco3dHealthImpl) then,
  ) = __$$Reco3dHealthImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'gpu_name') String? gpuName,
    @JsonKey(name: 'gpu_vram_total_mb') int? gpuVramTotalMb,
    @JsonKey(name: 'gpu_vram_free_mb') int? gpuVramFreeMb,
    @JsonKey(name: 'active_job_id') String? activeJobId,
    @JsonKey(name: 'queue_length', defaultValue: 0) int queueLength,
    Map<String, String> engines,
  });
}

/// @nodoc
class __$$Reco3dHealthImplCopyWithImpl<$Res>
    extends _$Reco3dHealthCopyWithImpl<$Res, _$Reco3dHealthImpl>
    implements _$$Reco3dHealthImplCopyWith<$Res> {
  __$$Reco3dHealthImplCopyWithImpl(
    _$Reco3dHealthImpl _value,
    $Res Function(_$Reco3dHealthImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Reco3dHealth
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? gpuName = freezed,
    Object? gpuVramTotalMb = freezed,
    Object? gpuVramFreeMb = freezed,
    Object? activeJobId = freezed,
    Object? queueLength = null,
    Object? engines = null,
  }) {
    return _then(
      _$Reco3dHealthImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        gpuName: freezed == gpuName
            ? _value.gpuName
            : gpuName // ignore: cast_nullable_to_non_nullable
                  as String?,
        gpuVramTotalMb: freezed == gpuVramTotalMb
            ? _value.gpuVramTotalMb
            : gpuVramTotalMb // ignore: cast_nullable_to_non_nullable
                  as int?,
        gpuVramFreeMb: freezed == gpuVramFreeMb
            ? _value.gpuVramFreeMb
            : gpuVramFreeMb // ignore: cast_nullable_to_non_nullable
                  as int?,
        activeJobId: freezed == activeJobId
            ? _value.activeJobId
            : activeJobId // ignore: cast_nullable_to_non_nullable
                  as String?,
        queueLength: null == queueLength
            ? _value.queueLength
            : queueLength // ignore: cast_nullable_to_non_nullable
                  as int,
        engines: null == engines
            ? _value._engines
            : engines // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$Reco3dHealthImpl implements _Reco3dHealth {
  const _$Reco3dHealthImpl({
    required this.status,
    @JsonKey(name: 'gpu_name') this.gpuName,
    @JsonKey(name: 'gpu_vram_total_mb') this.gpuVramTotalMb,
    @JsonKey(name: 'gpu_vram_free_mb') this.gpuVramFreeMb,
    @JsonKey(name: 'active_job_id') this.activeJobId,
    @JsonKey(name: 'queue_length', defaultValue: 0) required this.queueLength,
    final Map<String, String> engines = const <String, String>{},
  }) : _engines = engines;

  factory _$Reco3dHealthImpl.fromJson(Map<String, dynamic> json) =>
      _$$Reco3dHealthImplFromJson(json);

  @override
  final String status;
  @override
  @JsonKey(name: 'gpu_name')
  final String? gpuName;
  @override
  @JsonKey(name: 'gpu_vram_total_mb')
  final int? gpuVramTotalMb;
  @override
  @JsonKey(name: 'gpu_vram_free_mb')
  final int? gpuVramFreeMb;
  @override
  @JsonKey(name: 'active_job_id')
  final String? activeJobId;
  @override
  @JsonKey(name: 'queue_length', defaultValue: 0)
  final int queueLength;
  final Map<String, String> _engines;
  @override
  @JsonKey()
  Map<String, String> get engines {
    if (_engines is EqualUnmodifiableMapView) return _engines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_engines);
  }

  @override
  String toString() {
    return 'Reco3dHealth(status: $status, gpuName: $gpuName, gpuVramTotalMb: $gpuVramTotalMb, gpuVramFreeMb: $gpuVramFreeMb, activeJobId: $activeJobId, queueLength: $queueLength, engines: $engines)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Reco3dHealthImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.gpuName, gpuName) || other.gpuName == gpuName) &&
            (identical(other.gpuVramTotalMb, gpuVramTotalMb) ||
                other.gpuVramTotalMb == gpuVramTotalMb) &&
            (identical(other.gpuVramFreeMb, gpuVramFreeMb) ||
                other.gpuVramFreeMb == gpuVramFreeMb) &&
            (identical(other.activeJobId, activeJobId) ||
                other.activeJobId == activeJobId) &&
            (identical(other.queueLength, queueLength) ||
                other.queueLength == queueLength) &&
            const DeepCollectionEquality().equals(other._engines, _engines));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    gpuName,
    gpuVramTotalMb,
    gpuVramFreeMb,
    activeJobId,
    queueLength,
    const DeepCollectionEquality().hash(_engines),
  );

  /// Create a copy of Reco3dHealth
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Reco3dHealthImplCopyWith<_$Reco3dHealthImpl> get copyWith =>
      __$$Reco3dHealthImplCopyWithImpl<_$Reco3dHealthImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Reco3dHealthImplToJson(this);
  }
}

abstract class _Reco3dHealth implements Reco3dHealth {
  const factory _Reco3dHealth({
    required final String status,
    @JsonKey(name: 'gpu_name') final String? gpuName,
    @JsonKey(name: 'gpu_vram_total_mb') final int? gpuVramTotalMb,
    @JsonKey(name: 'gpu_vram_free_mb') final int? gpuVramFreeMb,
    @JsonKey(name: 'active_job_id') final String? activeJobId,
    @JsonKey(name: 'queue_length', defaultValue: 0)
    required final int queueLength,
    final Map<String, String> engines,
  }) = _$Reco3dHealthImpl;

  factory _Reco3dHealth.fromJson(Map<String, dynamic> json) =
      _$Reco3dHealthImpl.fromJson;

  @override
  String get status;
  @override
  @JsonKey(name: 'gpu_name')
  String? get gpuName;
  @override
  @JsonKey(name: 'gpu_vram_total_mb')
  int? get gpuVramTotalMb;
  @override
  @JsonKey(name: 'gpu_vram_free_mb')
  int? get gpuVramFreeMb;
  @override
  @JsonKey(name: 'active_job_id')
  String? get activeJobId;
  @override
  @JsonKey(name: 'queue_length', defaultValue: 0)
  int get queueLength;
  @override
  Map<String, String> get engines;

  /// Create a copy of Reco3dHealth
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Reco3dHealthImplCopyWith<_$Reco3dHealthImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Reco3dProvenance _$Reco3dProvenanceFromJson(Map<String, dynamic> json) {
  return _Reco3dProvenance.fromJson(json);
}

/// @nodoc
mixin _$Reco3dProvenance {
  String get mode => throw _privateConstructorUsedError;
  String get engine => throw _privateConstructorUsedError;
  @JsonKey(name: 'engine_version')
  String get engineVersion => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_scale_reference', defaultValue: false)
  bool get hasScaleReference => throw _privateConstructorUsedError;
  @JsonKey(name: 'scale_type', defaultValue: 'none')
  String get scaleType => throw _privateConstructorUsedError;
  @JsonKey(name: 'scale_factor')
  double? get scaleFactor => throw _privateConstructorUsedError;
  @JsonKey(name: 'photo_count', defaultValue: 0)
  int get photoCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_approximate', defaultValue: true)
  bool get isApproximate => throw _privateConstructorUsedError;
  @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
  int get unreconstructedHolesCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'facets_count')
  int? get facetsCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  List<String> get notes => throw _privateConstructorUsedError;

  /// Serializes this Reco3dProvenance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Reco3dProvenance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Reco3dProvenanceCopyWith<Reco3dProvenance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Reco3dProvenanceCopyWith<$Res> {
  factory $Reco3dProvenanceCopyWith(
    Reco3dProvenance value,
    $Res Function(Reco3dProvenance) then,
  ) = _$Reco3dProvenanceCopyWithImpl<$Res, Reco3dProvenance>;
  @useResult
  $Res call({
    String mode,
    String engine,
    @JsonKey(name: 'engine_version') String engineVersion,
    @JsonKey(name: 'has_scale_reference', defaultValue: false)
    bool hasScaleReference,
    @JsonKey(name: 'scale_type', defaultValue: 'none') String scaleType,
    @JsonKey(name: 'scale_factor') double? scaleFactor,
    @JsonKey(name: 'photo_count', defaultValue: 0) int photoCount,
    @JsonKey(name: 'is_approximate', defaultValue: true) bool isApproximate,
    @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
    int unreconstructedHolesCount,
    @JsonKey(name: 'facets_count') int? facetsCount,
    @JsonKey(name: 'created_at') String createdAt,
    List<String> notes,
  });
}

/// @nodoc
class _$Reco3dProvenanceCopyWithImpl<$Res, $Val extends Reco3dProvenance>
    implements $Reco3dProvenanceCopyWith<$Res> {
  _$Reco3dProvenanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Reco3dProvenance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = null,
    Object? engine = null,
    Object? engineVersion = null,
    Object? hasScaleReference = null,
    Object? scaleType = null,
    Object? scaleFactor = freezed,
    Object? photoCount = null,
    Object? isApproximate = null,
    Object? unreconstructedHolesCount = null,
    Object? facetsCount = freezed,
    Object? createdAt = null,
    Object? notes = null,
  }) {
    return _then(
      _value.copyWith(
            mode: null == mode
                ? _value.mode
                : mode // ignore: cast_nullable_to_non_nullable
                      as String,
            engine: null == engine
                ? _value.engine
                : engine // ignore: cast_nullable_to_non_nullable
                      as String,
            engineVersion: null == engineVersion
                ? _value.engineVersion
                : engineVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            hasScaleReference: null == hasScaleReference
                ? _value.hasScaleReference
                : hasScaleReference // ignore: cast_nullable_to_non_nullable
                      as bool,
            scaleType: null == scaleType
                ? _value.scaleType
                : scaleType // ignore: cast_nullable_to_non_nullable
                      as String,
            scaleFactor: freezed == scaleFactor
                ? _value.scaleFactor
                : scaleFactor // ignore: cast_nullable_to_non_nullable
                      as double?,
            photoCount: null == photoCount
                ? _value.photoCount
                : photoCount // ignore: cast_nullable_to_non_nullable
                      as int,
            isApproximate: null == isApproximate
                ? _value.isApproximate
                : isApproximate // ignore: cast_nullable_to_non_nullable
                      as bool,
            unreconstructedHolesCount: null == unreconstructedHolesCount
                ? _value.unreconstructedHolesCount
                : unreconstructedHolesCount // ignore: cast_nullable_to_non_nullable
                      as int,
            facetsCount: freezed == facetsCount
                ? _value.facetsCount
                : facetsCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            notes: null == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$Reco3dProvenanceImplCopyWith<$Res>
    implements $Reco3dProvenanceCopyWith<$Res> {
  factory _$$Reco3dProvenanceImplCopyWith(
    _$Reco3dProvenanceImpl value,
    $Res Function(_$Reco3dProvenanceImpl) then,
  ) = __$$Reco3dProvenanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String mode,
    String engine,
    @JsonKey(name: 'engine_version') String engineVersion,
    @JsonKey(name: 'has_scale_reference', defaultValue: false)
    bool hasScaleReference,
    @JsonKey(name: 'scale_type', defaultValue: 'none') String scaleType,
    @JsonKey(name: 'scale_factor') double? scaleFactor,
    @JsonKey(name: 'photo_count', defaultValue: 0) int photoCount,
    @JsonKey(name: 'is_approximate', defaultValue: true) bool isApproximate,
    @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
    int unreconstructedHolesCount,
    @JsonKey(name: 'facets_count') int? facetsCount,
    @JsonKey(name: 'created_at') String createdAt,
    List<String> notes,
  });
}

/// @nodoc
class __$$Reco3dProvenanceImplCopyWithImpl<$Res>
    extends _$Reco3dProvenanceCopyWithImpl<$Res, _$Reco3dProvenanceImpl>
    implements _$$Reco3dProvenanceImplCopyWith<$Res> {
  __$$Reco3dProvenanceImplCopyWithImpl(
    _$Reco3dProvenanceImpl _value,
    $Res Function(_$Reco3dProvenanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Reco3dProvenance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = null,
    Object? engine = null,
    Object? engineVersion = null,
    Object? hasScaleReference = null,
    Object? scaleType = null,
    Object? scaleFactor = freezed,
    Object? photoCount = null,
    Object? isApproximate = null,
    Object? unreconstructedHolesCount = null,
    Object? facetsCount = freezed,
    Object? createdAt = null,
    Object? notes = null,
  }) {
    return _then(
      _$Reco3dProvenanceImpl(
        mode: null == mode
            ? _value.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as String,
        engine: null == engine
            ? _value.engine
            : engine // ignore: cast_nullable_to_non_nullable
                  as String,
        engineVersion: null == engineVersion
            ? _value.engineVersion
            : engineVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        hasScaleReference: null == hasScaleReference
            ? _value.hasScaleReference
            : hasScaleReference // ignore: cast_nullable_to_non_nullable
                  as bool,
        scaleType: null == scaleType
            ? _value.scaleType
            : scaleType // ignore: cast_nullable_to_non_nullable
                  as String,
        scaleFactor: freezed == scaleFactor
            ? _value.scaleFactor
            : scaleFactor // ignore: cast_nullable_to_non_nullable
                  as double?,
        photoCount: null == photoCount
            ? _value.photoCount
            : photoCount // ignore: cast_nullable_to_non_nullable
                  as int,
        isApproximate: null == isApproximate
            ? _value.isApproximate
            : isApproximate // ignore: cast_nullable_to_non_nullable
                  as bool,
        unreconstructedHolesCount: null == unreconstructedHolesCount
            ? _value.unreconstructedHolesCount
            : unreconstructedHolesCount // ignore: cast_nullable_to_non_nullable
                  as int,
        facetsCount: freezed == facetsCount
            ? _value.facetsCount
            : facetsCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        notes: null == notes
            ? _value._notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$Reco3dProvenanceImpl implements _Reco3dProvenance {
  const _$Reco3dProvenanceImpl({
    required this.mode,
    required this.engine,
    @JsonKey(name: 'engine_version') required this.engineVersion,
    @JsonKey(name: 'has_scale_reference', defaultValue: false)
    required this.hasScaleReference,
    @JsonKey(name: 'scale_type', defaultValue: 'none') required this.scaleType,
    @JsonKey(name: 'scale_factor') this.scaleFactor,
    @JsonKey(name: 'photo_count', defaultValue: 0) required this.photoCount,
    @JsonKey(name: 'is_approximate', defaultValue: true)
    required this.isApproximate,
    @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
    required this.unreconstructedHolesCount,
    @JsonKey(name: 'facets_count') this.facetsCount,
    @JsonKey(name: 'created_at') required this.createdAt,
    final List<String> notes = const <String>[],
  }) : _notes = notes;

  factory _$Reco3dProvenanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$Reco3dProvenanceImplFromJson(json);

  @override
  final String mode;
  @override
  final String engine;
  @override
  @JsonKey(name: 'engine_version')
  final String engineVersion;
  @override
  @JsonKey(name: 'has_scale_reference', defaultValue: false)
  final bool hasScaleReference;
  @override
  @JsonKey(name: 'scale_type', defaultValue: 'none')
  final String scaleType;
  @override
  @JsonKey(name: 'scale_factor')
  final double? scaleFactor;
  @override
  @JsonKey(name: 'photo_count', defaultValue: 0)
  final int photoCount;
  @override
  @JsonKey(name: 'is_approximate', defaultValue: true)
  final bool isApproximate;
  @override
  @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
  final int unreconstructedHolesCount;
  @override
  @JsonKey(name: 'facets_count')
  final int? facetsCount;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  final List<String> _notes;
  @override
  @JsonKey()
  List<String> get notes {
    if (_notes is EqualUnmodifiableListView) return _notes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_notes);
  }

  @override
  String toString() {
    return 'Reco3dProvenance(mode: $mode, engine: $engine, engineVersion: $engineVersion, hasScaleReference: $hasScaleReference, scaleType: $scaleType, scaleFactor: $scaleFactor, photoCount: $photoCount, isApproximate: $isApproximate, unreconstructedHolesCount: $unreconstructedHolesCount, facetsCount: $facetsCount, createdAt: $createdAt, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Reco3dProvenanceImpl &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.engine, engine) || other.engine == engine) &&
            (identical(other.engineVersion, engineVersion) ||
                other.engineVersion == engineVersion) &&
            (identical(other.hasScaleReference, hasScaleReference) ||
                other.hasScaleReference == hasScaleReference) &&
            (identical(other.scaleType, scaleType) ||
                other.scaleType == scaleType) &&
            (identical(other.scaleFactor, scaleFactor) ||
                other.scaleFactor == scaleFactor) &&
            (identical(other.photoCount, photoCount) ||
                other.photoCount == photoCount) &&
            (identical(other.isApproximate, isApproximate) ||
                other.isApproximate == isApproximate) &&
            (identical(
                  other.unreconstructedHolesCount,
                  unreconstructedHolesCount,
                ) ||
                other.unreconstructedHolesCount == unreconstructedHolesCount) &&
            (identical(other.facetsCount, facetsCount) ||
                other.facetsCount == facetsCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(other._notes, _notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    mode,
    engine,
    engineVersion,
    hasScaleReference,
    scaleType,
    scaleFactor,
    photoCount,
    isApproximate,
    unreconstructedHolesCount,
    facetsCount,
    createdAt,
    const DeepCollectionEquality().hash(_notes),
  );

  /// Create a copy of Reco3dProvenance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Reco3dProvenanceImplCopyWith<_$Reco3dProvenanceImpl> get copyWith =>
      __$$Reco3dProvenanceImplCopyWithImpl<_$Reco3dProvenanceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$Reco3dProvenanceImplToJson(this);
  }
}

abstract class _Reco3dProvenance implements Reco3dProvenance {
  const factory _Reco3dProvenance({
    required final String mode,
    required final String engine,
    @JsonKey(name: 'engine_version') required final String engineVersion,
    @JsonKey(name: 'has_scale_reference', defaultValue: false)
    required final bool hasScaleReference,
    @JsonKey(name: 'scale_type', defaultValue: 'none')
    required final String scaleType,
    @JsonKey(name: 'scale_factor') final double? scaleFactor,
    @JsonKey(name: 'photo_count', defaultValue: 0)
    required final int photoCount,
    @JsonKey(name: 'is_approximate', defaultValue: true)
    required final bool isApproximate,
    @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
    required final int unreconstructedHolesCount,
    @JsonKey(name: 'facets_count') final int? facetsCount,
    @JsonKey(name: 'created_at') required final String createdAt,
    final List<String> notes,
  }) = _$Reco3dProvenanceImpl;

  factory _Reco3dProvenance.fromJson(Map<String, dynamic> json) =
      _$Reco3dProvenanceImpl.fromJson;

  @override
  String get mode;
  @override
  String get engine;
  @override
  @JsonKey(name: 'engine_version')
  String get engineVersion;
  @override
  @JsonKey(name: 'has_scale_reference', defaultValue: false)
  bool get hasScaleReference;
  @override
  @JsonKey(name: 'scale_type', defaultValue: 'none')
  String get scaleType;
  @override
  @JsonKey(name: 'scale_factor')
  double? get scaleFactor;
  @override
  @JsonKey(name: 'photo_count', defaultValue: 0)
  int get photoCount;
  @override
  @JsonKey(name: 'is_approximate', defaultValue: true)
  bool get isApproximate;
  @override
  @JsonKey(name: 'unreconstructed_holes_count', defaultValue: 0)
  int get unreconstructedHolesCount;
  @override
  @JsonKey(name: 'facets_count')
  int? get facetsCount;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  List<String> get notes;

  /// Create a copy of Reco3dProvenance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Reco3dProvenanceImplCopyWith<_$Reco3dProvenanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Reco3dJobStatus _$Reco3dJobStatusFromJson(Map<String, dynamic> json) {
  return _Reco3dJobStatus.fromJson(json);
}

/// @nodoc
mixin _$Reco3dJobStatus {
  @JsonKey(name: 'job_id')
  String get jobId => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;
  String get stage => throw _privateConstructorUsedError;
  @JsonKey(name: 'progress_percent', defaultValue: 0.0)
  double get progressPercent => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  Reco3dProvenance? get provenance => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_step', defaultValue: false)
  bool get hasStep => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_mesh', defaultValue: false)
  bool get hasMesh => throw _privateConstructorUsedError;

  /// Serializes this Reco3dJobStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Reco3dJobStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Reco3dJobStatusCopyWith<Reco3dJobStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Reco3dJobStatusCopyWith<$Res> {
  factory $Reco3dJobStatusCopyWith(
    Reco3dJobStatus value,
    $Res Function(Reco3dJobStatus) then,
  ) = _$Reco3dJobStatusCopyWithImpl<$Res, Reco3dJobStatus>;
  @useResult
  $Res call({
    @JsonKey(name: 'job_id') String jobId,
    String mode,
    String stage,
    @JsonKey(name: 'progress_percent', defaultValue: 0.0)
    double progressPercent,
    String message,
    String? error,
    Reco3dProvenance? provenance,
    @JsonKey(name: 'has_step', defaultValue: false) bool hasStep,
    @JsonKey(name: 'has_mesh', defaultValue: false) bool hasMesh,
  });

  $Reco3dProvenanceCopyWith<$Res>? get provenance;
}

/// @nodoc
class _$Reco3dJobStatusCopyWithImpl<$Res, $Val extends Reco3dJobStatus>
    implements $Reco3dJobStatusCopyWith<$Res> {
  _$Reco3dJobStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Reco3dJobStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? mode = null,
    Object? stage = null,
    Object? progressPercent = null,
    Object? message = null,
    Object? error = freezed,
    Object? provenance = freezed,
    Object? hasStep = null,
    Object? hasMesh = null,
  }) {
    return _then(
      _value.copyWith(
            jobId: null == jobId
                ? _value.jobId
                : jobId // ignore: cast_nullable_to_non_nullable
                      as String,
            mode: null == mode
                ? _value.mode
                : mode // ignore: cast_nullable_to_non_nullable
                      as String,
            stage: null == stage
                ? _value.stage
                : stage // ignore: cast_nullable_to_non_nullable
                      as String,
            progressPercent: null == progressPercent
                ? _value.progressPercent
                : progressPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            provenance: freezed == provenance
                ? _value.provenance
                : provenance // ignore: cast_nullable_to_non_nullable
                      as Reco3dProvenance?,
            hasStep: null == hasStep
                ? _value.hasStep
                : hasStep // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasMesh: null == hasMesh
                ? _value.hasMesh
                : hasMesh // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of Reco3dJobStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Reco3dProvenanceCopyWith<$Res>? get provenance {
    if (_value.provenance == null) {
      return null;
    }

    return $Reco3dProvenanceCopyWith<$Res>(_value.provenance!, (value) {
      return _then(_value.copyWith(provenance: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$Reco3dJobStatusImplCopyWith<$Res>
    implements $Reco3dJobStatusCopyWith<$Res> {
  factory _$$Reco3dJobStatusImplCopyWith(
    _$Reco3dJobStatusImpl value,
    $Res Function(_$Reco3dJobStatusImpl) then,
  ) = __$$Reco3dJobStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'job_id') String jobId,
    String mode,
    String stage,
    @JsonKey(name: 'progress_percent', defaultValue: 0.0)
    double progressPercent,
    String message,
    String? error,
    Reco3dProvenance? provenance,
    @JsonKey(name: 'has_step', defaultValue: false) bool hasStep,
    @JsonKey(name: 'has_mesh', defaultValue: false) bool hasMesh,
  });

  @override
  $Reco3dProvenanceCopyWith<$Res>? get provenance;
}

/// @nodoc
class __$$Reco3dJobStatusImplCopyWithImpl<$Res>
    extends _$Reco3dJobStatusCopyWithImpl<$Res, _$Reco3dJobStatusImpl>
    implements _$$Reco3dJobStatusImplCopyWith<$Res> {
  __$$Reco3dJobStatusImplCopyWithImpl(
    _$Reco3dJobStatusImpl _value,
    $Res Function(_$Reco3dJobStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Reco3dJobStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? mode = null,
    Object? stage = null,
    Object? progressPercent = null,
    Object? message = null,
    Object? error = freezed,
    Object? provenance = freezed,
    Object? hasStep = null,
    Object? hasMesh = null,
  }) {
    return _then(
      _$Reco3dJobStatusImpl(
        jobId: null == jobId
            ? _value.jobId
            : jobId // ignore: cast_nullable_to_non_nullable
                  as String,
        mode: null == mode
            ? _value.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as String,
        stage: null == stage
            ? _value.stage
            : stage // ignore: cast_nullable_to_non_nullable
                  as String,
        progressPercent: null == progressPercent
            ? _value.progressPercent
            : progressPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        provenance: freezed == provenance
            ? _value.provenance
            : provenance // ignore: cast_nullable_to_non_nullable
                  as Reco3dProvenance?,
        hasStep: null == hasStep
            ? _value.hasStep
            : hasStep // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasMesh: null == hasMesh
            ? _value.hasMesh
            : hasMesh // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$Reco3dJobStatusImpl implements _Reco3dJobStatus {
  const _$Reco3dJobStatusImpl({
    @JsonKey(name: 'job_id') required this.jobId,
    required this.mode,
    required this.stage,
    @JsonKey(name: 'progress_percent', defaultValue: 0.0)
    required this.progressPercent,
    this.message = '',
    this.error,
    this.provenance,
    @JsonKey(name: 'has_step', defaultValue: false) required this.hasStep,
    @JsonKey(name: 'has_mesh', defaultValue: false) required this.hasMesh,
  });

  factory _$Reco3dJobStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$Reco3dJobStatusImplFromJson(json);

  @override
  @JsonKey(name: 'job_id')
  final String jobId;
  @override
  final String mode;
  @override
  final String stage;
  @override
  @JsonKey(name: 'progress_percent', defaultValue: 0.0)
  final double progressPercent;
  @override
  @JsonKey()
  final String message;
  @override
  final String? error;
  @override
  final Reco3dProvenance? provenance;
  @override
  @JsonKey(name: 'has_step', defaultValue: false)
  final bool hasStep;
  @override
  @JsonKey(name: 'has_mesh', defaultValue: false)
  final bool hasMesh;

  @override
  String toString() {
    return 'Reco3dJobStatus(jobId: $jobId, mode: $mode, stage: $stage, progressPercent: $progressPercent, message: $message, error: $error, provenance: $provenance, hasStep: $hasStep, hasMesh: $hasMesh)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Reco3dJobStatusImpl &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.progressPercent, progressPercent) ||
                other.progressPercent == progressPercent) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.provenance, provenance) ||
                other.provenance == provenance) &&
            (identical(other.hasStep, hasStep) || other.hasStep == hasStep) &&
            (identical(other.hasMesh, hasMesh) || other.hasMesh == hasMesh));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    jobId,
    mode,
    stage,
    progressPercent,
    message,
    error,
    provenance,
    hasStep,
    hasMesh,
  );

  /// Create a copy of Reco3dJobStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Reco3dJobStatusImplCopyWith<_$Reco3dJobStatusImpl> get copyWith =>
      __$$Reco3dJobStatusImplCopyWithImpl<_$Reco3dJobStatusImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$Reco3dJobStatusImplToJson(this);
  }
}

abstract class _Reco3dJobStatus implements Reco3dJobStatus {
  const factory _Reco3dJobStatus({
    @JsonKey(name: 'job_id') required final String jobId,
    required final String mode,
    required final String stage,
    @JsonKey(name: 'progress_percent', defaultValue: 0.0)
    required final double progressPercent,
    final String message,
    final String? error,
    final Reco3dProvenance? provenance,
    @JsonKey(name: 'has_step', defaultValue: false) required final bool hasStep,
    @JsonKey(name: 'has_mesh', defaultValue: false) required final bool hasMesh,
  }) = _$Reco3dJobStatusImpl;

  factory _Reco3dJobStatus.fromJson(Map<String, dynamic> json) =
      _$Reco3dJobStatusImpl.fromJson;

  @override
  @JsonKey(name: 'job_id')
  String get jobId;
  @override
  String get mode;
  @override
  String get stage;
  @override
  @JsonKey(name: 'progress_percent', defaultValue: 0.0)
  double get progressPercent;
  @override
  String get message;
  @override
  String? get error;
  @override
  Reco3dProvenance? get provenance;
  @override
  @JsonKey(name: 'has_step', defaultValue: false)
  bool get hasStep;
  @override
  @JsonKey(name: 'has_mesh', defaultValue: false)
  bool get hasMesh;

  /// Create a copy of Reco3dJobStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Reco3dJobStatusImplCopyWith<_$Reco3dJobStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Reco3dJobCreated _$Reco3dJobCreatedFromJson(Map<String, dynamic> json) {
  return _Reco3dJobCreated.fromJson(json);
}

/// @nodoc
mixin _$Reco3dJobCreated {
  @JsonKey(name: 'job_id')
  String get jobId => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;
  @JsonKey(name: 'queue_position', defaultValue: 0)
  int get queuePosition => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;

  /// Serializes this Reco3dJobCreated to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Reco3dJobCreated
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Reco3dJobCreatedCopyWith<Reco3dJobCreated> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Reco3dJobCreatedCopyWith<$Res> {
  factory $Reco3dJobCreatedCopyWith(
    Reco3dJobCreated value,
    $Res Function(Reco3dJobCreated) then,
  ) = _$Reco3dJobCreatedCopyWithImpl<$Res, Reco3dJobCreated>;
  @useResult
  $Res call({
    @JsonKey(name: 'job_id') String jobId,
    String mode,
    @JsonKey(name: 'queue_position', defaultValue: 0) int queuePosition,
    String message,
  });
}

/// @nodoc
class _$Reco3dJobCreatedCopyWithImpl<$Res, $Val extends Reco3dJobCreated>
    implements $Reco3dJobCreatedCopyWith<$Res> {
  _$Reco3dJobCreatedCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Reco3dJobCreated
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? mode = null,
    Object? queuePosition = null,
    Object? message = null,
  }) {
    return _then(
      _value.copyWith(
            jobId: null == jobId
                ? _value.jobId
                : jobId // ignore: cast_nullable_to_non_nullable
                      as String,
            mode: null == mode
                ? _value.mode
                : mode // ignore: cast_nullable_to_non_nullable
                      as String,
            queuePosition: null == queuePosition
                ? _value.queuePosition
                : queuePosition // ignore: cast_nullable_to_non_nullable
                      as int,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$Reco3dJobCreatedImplCopyWith<$Res>
    implements $Reco3dJobCreatedCopyWith<$Res> {
  factory _$$Reco3dJobCreatedImplCopyWith(
    _$Reco3dJobCreatedImpl value,
    $Res Function(_$Reco3dJobCreatedImpl) then,
  ) = __$$Reco3dJobCreatedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'job_id') String jobId,
    String mode,
    @JsonKey(name: 'queue_position', defaultValue: 0) int queuePosition,
    String message,
  });
}

/// @nodoc
class __$$Reco3dJobCreatedImplCopyWithImpl<$Res>
    extends _$Reco3dJobCreatedCopyWithImpl<$Res, _$Reco3dJobCreatedImpl>
    implements _$$Reco3dJobCreatedImplCopyWith<$Res> {
  __$$Reco3dJobCreatedImplCopyWithImpl(
    _$Reco3dJobCreatedImpl _value,
    $Res Function(_$Reco3dJobCreatedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Reco3dJobCreated
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? mode = null,
    Object? queuePosition = null,
    Object? message = null,
  }) {
    return _then(
      _$Reco3dJobCreatedImpl(
        jobId: null == jobId
            ? _value.jobId
            : jobId // ignore: cast_nullable_to_non_nullable
                  as String,
        mode: null == mode
            ? _value.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as String,
        queuePosition: null == queuePosition
            ? _value.queuePosition
            : queuePosition // ignore: cast_nullable_to_non_nullable
                  as int,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$Reco3dJobCreatedImpl implements _Reco3dJobCreated {
  const _$Reco3dJobCreatedImpl({
    @JsonKey(name: 'job_id') required this.jobId,
    required this.mode,
    @JsonKey(name: 'queue_position', defaultValue: 0)
    required this.queuePosition,
    required this.message,
  });

  factory _$Reco3dJobCreatedImpl.fromJson(Map<String, dynamic> json) =>
      _$$Reco3dJobCreatedImplFromJson(json);

  @override
  @JsonKey(name: 'job_id')
  final String jobId;
  @override
  final String mode;
  @override
  @JsonKey(name: 'queue_position', defaultValue: 0)
  final int queuePosition;
  @override
  final String message;

  @override
  String toString() {
    return 'Reco3dJobCreated(jobId: $jobId, mode: $mode, queuePosition: $queuePosition, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Reco3dJobCreatedImpl &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.queuePosition, queuePosition) ||
                other.queuePosition == queuePosition) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, jobId, mode, queuePosition, message);

  /// Create a copy of Reco3dJobCreated
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Reco3dJobCreatedImplCopyWith<_$Reco3dJobCreatedImpl> get copyWith =>
      __$$Reco3dJobCreatedImplCopyWithImpl<_$Reco3dJobCreatedImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$Reco3dJobCreatedImplToJson(this);
  }
}

abstract class _Reco3dJobCreated implements Reco3dJobCreated {
  const factory _Reco3dJobCreated({
    @JsonKey(name: 'job_id') required final String jobId,
    required final String mode,
    @JsonKey(name: 'queue_position', defaultValue: 0)
    required final int queuePosition,
    required final String message,
  }) = _$Reco3dJobCreatedImpl;

  factory _Reco3dJobCreated.fromJson(Map<String, dynamic> json) =
      _$Reco3dJobCreatedImpl.fromJson;

  @override
  @JsonKey(name: 'job_id')
  String get jobId;
  @override
  String get mode;
  @override
  @JsonKey(name: 'queue_position', defaultValue: 0)
  int get queuePosition;
  @override
  String get message;

  /// Create a copy of Reco3dJobCreated
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Reco3dJobCreatedImplCopyWith<_$Reco3dJobCreatedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
