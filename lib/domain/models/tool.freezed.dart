// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Tool _$ToolFromJson(Map<String, dynamic> json) {
  return _Tool.fromJson(json);
}

/// @nodoc
mixin _$Tool {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  double get diameter => throw _privateConstructorUsedError;
  double get length => throw _privateConstructorUsedError;
  double get noseRadius => throw _privateConstructorUsedError;
  double get cuttingAngle => throw _privateConstructorUsedError;
  double get life => throw _privateConstructorUsedError;
  double get wear => throw _privateConstructorUsedError;

  /// Serializes this Tool to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Tool
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolCopyWith<Tool> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolCopyWith<$Res> {
  factory $ToolCopyWith(Tool value, $Res Function(Tool) then) =
      _$ToolCopyWithImpl<$Res, Tool>;
  @useResult
  $Res call({
    int id,
    String name,
    double diameter,
    double length,
    double noseRadius,
    double cuttingAngle,
    double life,
    double wear,
  });
}

/// @nodoc
class _$ToolCopyWithImpl<$Res, $Val extends Tool>
    implements $ToolCopyWith<$Res> {
  _$ToolCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Tool
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? diameter = null,
    Object? length = null,
    Object? noseRadius = null,
    Object? cuttingAngle = null,
    Object? life = null,
    Object? wear = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            diameter: null == diameter
                ? _value.diameter
                : diameter // ignore: cast_nullable_to_non_nullable
                      as double,
            length: null == length
                ? _value.length
                : length // ignore: cast_nullable_to_non_nullable
                      as double,
            noseRadius: null == noseRadius
                ? _value.noseRadius
                : noseRadius // ignore: cast_nullable_to_non_nullable
                      as double,
            cuttingAngle: null == cuttingAngle
                ? _value.cuttingAngle
                : cuttingAngle // ignore: cast_nullable_to_non_nullable
                      as double,
            life: null == life
                ? _value.life
                : life // ignore: cast_nullable_to_non_nullable
                      as double,
            wear: null == wear
                ? _value.wear
                : wear // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ToolImplCopyWith<$Res> implements $ToolCopyWith<$Res> {
  factory _$$ToolImplCopyWith(
    _$ToolImpl value,
    $Res Function(_$ToolImpl) then,
  ) = __$$ToolImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    double diameter,
    double length,
    double noseRadius,
    double cuttingAngle,
    double life,
    double wear,
  });
}

/// @nodoc
class __$$ToolImplCopyWithImpl<$Res>
    extends _$ToolCopyWithImpl<$Res, _$ToolImpl>
    implements _$$ToolImplCopyWith<$Res> {
  __$$ToolImplCopyWithImpl(_$ToolImpl _value, $Res Function(_$ToolImpl) _then)
    : super(_value, _then);

  /// Create a copy of Tool
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? diameter = null,
    Object? length = null,
    Object? noseRadius = null,
    Object? cuttingAngle = null,
    Object? life = null,
    Object? wear = null,
  }) {
    return _then(
      _$ToolImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        diameter: null == diameter
            ? _value.diameter
            : diameter // ignore: cast_nullable_to_non_nullable
                  as double,
        length: null == length
            ? _value.length
            : length // ignore: cast_nullable_to_non_nullable
                  as double,
        noseRadius: null == noseRadius
            ? _value.noseRadius
            : noseRadius // ignore: cast_nullable_to_non_nullable
                  as double,
        cuttingAngle: null == cuttingAngle
            ? _value.cuttingAngle
            : cuttingAngle // ignore: cast_nullable_to_non_nullable
                  as double,
        life: null == life
            ? _value.life
            : life // ignore: cast_nullable_to_non_nullable
                  as double,
        wear: null == wear
            ? _value.wear
            : wear // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolImpl implements _Tool {
  const _$ToolImpl({
    required this.id,
    required this.name,
    this.diameter = 0.0,
    this.length = 0.0,
    this.noseRadius = 0.0,
    this.cuttingAngle = 0.0,
    this.life = 0.0,
    this.wear = 0.0,
  });

  factory _$ToolImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  @JsonKey()
  final double diameter;
  @override
  @JsonKey()
  final double length;
  @override
  @JsonKey()
  final double noseRadius;
  @override
  @JsonKey()
  final double cuttingAngle;
  @override
  @JsonKey()
  final double life;
  @override
  @JsonKey()
  final double wear;

  @override
  String toString() {
    return 'Tool(id: $id, name: $name, diameter: $diameter, length: $length, noseRadius: $noseRadius, cuttingAngle: $cuttingAngle, life: $life, wear: $wear)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.diameter, diameter) ||
                other.diameter == diameter) &&
            (identical(other.length, length) || other.length == length) &&
            (identical(other.noseRadius, noseRadius) ||
                other.noseRadius == noseRadius) &&
            (identical(other.cuttingAngle, cuttingAngle) ||
                other.cuttingAngle == cuttingAngle) &&
            (identical(other.life, life) || other.life == life) &&
            (identical(other.wear, wear) || other.wear == wear));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    diameter,
    length,
    noseRadius,
    cuttingAngle,
    life,
    wear,
  );

  /// Create a copy of Tool
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolImplCopyWith<_$ToolImpl> get copyWith =>
      __$$ToolImplCopyWithImpl<_$ToolImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolImplToJson(this);
  }
}

abstract class _Tool implements Tool {
  const factory _Tool({
    required final int id,
    required final String name,
    final double diameter,
    final double length,
    final double noseRadius,
    final double cuttingAngle,
    final double life,
    final double wear,
  }) = _$ToolImpl;

  factory _Tool.fromJson(Map<String, dynamic> json) = _$ToolImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  double get diameter;
  @override
  double get length;
  @override
  double get noseRadius;
  @override
  double get cuttingAngle;
  @override
  double get life;
  @override
  double get wear;

  /// Create a copy of Tool
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolImplCopyWith<_$ToolImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
