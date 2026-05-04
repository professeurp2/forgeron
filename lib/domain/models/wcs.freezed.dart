// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wcs.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WorkCoordinateSystem _$WorkCoordinateSystemFromJson(Map<String, dynamic> json) {
  return _WorkCoordinateSystem.fromJson(json);
}

/// @nodoc
mixin _$WorkCoordinateSystem {
  String get label => throw _privateConstructorUsedError;
  List<double> get offsets => throw _privateConstructorUsedError;

  /// Serializes this WorkCoordinateSystem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkCoordinateSystem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkCoordinateSystemCopyWith<WorkCoordinateSystem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkCoordinateSystemCopyWith<$Res> {
  factory $WorkCoordinateSystemCopyWith(
    WorkCoordinateSystem value,
    $Res Function(WorkCoordinateSystem) then,
  ) = _$WorkCoordinateSystemCopyWithImpl<$Res, WorkCoordinateSystem>;
  @useResult
  $Res call({String label, List<double> offsets});
}

/// @nodoc
class _$WorkCoordinateSystemCopyWithImpl<
  $Res,
  $Val extends WorkCoordinateSystem
>
    implements $WorkCoordinateSystemCopyWith<$Res> {
  _$WorkCoordinateSystemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkCoordinateSystem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? label = null, Object? offsets = null}) {
    return _then(
      _value.copyWith(
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            offsets: null == offsets
                ? _value.offsets
                : offsets // ignore: cast_nullable_to_non_nullable
                      as List<double>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkCoordinateSystemImplCopyWith<$Res>
    implements $WorkCoordinateSystemCopyWith<$Res> {
  factory _$$WorkCoordinateSystemImplCopyWith(
    _$WorkCoordinateSystemImpl value,
    $Res Function(_$WorkCoordinateSystemImpl) then,
  ) = __$$WorkCoordinateSystemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String label, List<double> offsets});
}

/// @nodoc
class __$$WorkCoordinateSystemImplCopyWithImpl<$Res>
    extends _$WorkCoordinateSystemCopyWithImpl<$Res, _$WorkCoordinateSystemImpl>
    implements _$$WorkCoordinateSystemImplCopyWith<$Res> {
  __$$WorkCoordinateSystemImplCopyWithImpl(
    _$WorkCoordinateSystemImpl _value,
    $Res Function(_$WorkCoordinateSystemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkCoordinateSystem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? label = null, Object? offsets = null}) {
    return _then(
      _$WorkCoordinateSystemImpl(
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        offsets: null == offsets
            ? _value._offsets
            : offsets // ignore: cast_nullable_to_non_nullable
                  as List<double>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkCoordinateSystemImpl implements _WorkCoordinateSystem {
  const _$WorkCoordinateSystemImpl({
    required this.label,
    final List<double> offsets = const [0.0, 0.0, 0.0, 0.0, 0.0],
  }) : _offsets = offsets;

  factory _$WorkCoordinateSystemImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkCoordinateSystemImplFromJson(json);

  @override
  final String label;
  final List<double> _offsets;
  @override
  @JsonKey()
  List<double> get offsets {
    if (_offsets is EqualUnmodifiableListView) return _offsets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_offsets);
  }

  @override
  String toString() {
    return 'WorkCoordinateSystem(label: $label, offsets: $offsets)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkCoordinateSystemImpl &&
            (identical(other.label, label) || other.label == label) &&
            const DeepCollectionEquality().equals(other._offsets, _offsets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    label,
    const DeepCollectionEquality().hash(_offsets),
  );

  /// Create a copy of WorkCoordinateSystem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkCoordinateSystemImplCopyWith<_$WorkCoordinateSystemImpl>
  get copyWith =>
      __$$WorkCoordinateSystemImplCopyWithImpl<_$WorkCoordinateSystemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkCoordinateSystemImplToJson(this);
  }
}

abstract class _WorkCoordinateSystem implements WorkCoordinateSystem {
  const factory _WorkCoordinateSystem({
    required final String label,
    final List<double> offsets,
  }) = _$WorkCoordinateSystemImpl;

  factory _WorkCoordinateSystem.fromJson(Map<String, dynamic> json) =
      _$WorkCoordinateSystemImpl.fromJson;

  @override
  String get label;
  @override
  List<double> get offsets;

  /// Create a copy of WorkCoordinateSystem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkCoordinateSystemImplCopyWith<_$WorkCoordinateSystemImpl>
  get copyWith => throw _privateConstructorUsedError;
}
