// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gcode_file.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GCodeFile _$GCodeFileFromJson(Map<String, dynamic> json) {
  return _GCodeFile.fromJson(json);
}

/// @nodoc
mixin _$GCodeFile {
  String get name => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;
  int get lines => throw _privateConstructorUsedError;
  DateTime? get lastModified => throw _privateConstructorUsedError;

  /// Serializes this GCodeFile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GCodeFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GCodeFileCopyWith<GCodeFile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GCodeFileCopyWith<$Res> {
  factory $GCodeFileCopyWith(GCodeFile value, $Res Function(GCodeFile) then) =
      _$GCodeFileCopyWithImpl<$Res, GCodeFile>;
  @useResult
  $Res call({String name, int size, int lines, DateTime? lastModified});
}

/// @nodoc
class _$GCodeFileCopyWithImpl<$Res, $Val extends GCodeFile>
    implements $GCodeFileCopyWith<$Res> {
  _$GCodeFileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GCodeFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? size = null,
    Object? lines = null,
    Object? lastModified = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
            lines: null == lines
                ? _value.lines
                : lines // ignore: cast_nullable_to_non_nullable
                      as int,
            lastModified: freezed == lastModified
                ? _value.lastModified
                : lastModified // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GCodeFileImplCopyWith<$Res>
    implements $GCodeFileCopyWith<$Res> {
  factory _$$GCodeFileImplCopyWith(
    _$GCodeFileImpl value,
    $Res Function(_$GCodeFileImpl) then,
  ) = __$$GCodeFileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, int size, int lines, DateTime? lastModified});
}

/// @nodoc
class __$$GCodeFileImplCopyWithImpl<$Res>
    extends _$GCodeFileCopyWithImpl<$Res, _$GCodeFileImpl>
    implements _$$GCodeFileImplCopyWith<$Res> {
  __$$GCodeFileImplCopyWithImpl(
    _$GCodeFileImpl _value,
    $Res Function(_$GCodeFileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GCodeFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? size = null,
    Object? lines = null,
    Object? lastModified = freezed,
  }) {
    return _then(
      _$GCodeFileImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
        lines: null == lines
            ? _value.lines
            : lines // ignore: cast_nullable_to_non_nullable
                  as int,
        lastModified: freezed == lastModified
            ? _value.lastModified
            : lastModified // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GCodeFileImpl implements _GCodeFile {
  const _$GCodeFileImpl({
    required this.name,
    required this.size,
    this.lines = 0,
    this.lastModified,
  });

  factory _$GCodeFileImpl.fromJson(Map<String, dynamic> json) =>
      _$$GCodeFileImplFromJson(json);

  @override
  final String name;
  @override
  final int size;
  @override
  @JsonKey()
  final int lines;
  @override
  final DateTime? lastModified;

  @override
  String toString() {
    return 'GCodeFile(name: $name, size: $size, lines: $lines, lastModified: $lastModified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GCodeFileImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.lines, lines) || other.lines == lines) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, size, lines, lastModified);

  /// Create a copy of GCodeFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GCodeFileImplCopyWith<_$GCodeFileImpl> get copyWith =>
      __$$GCodeFileImplCopyWithImpl<_$GCodeFileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GCodeFileImplToJson(this);
  }
}

abstract class _GCodeFile implements GCodeFile {
  const factory _GCodeFile({
    required final String name,
    required final int size,
    final int lines,
    final DateTime? lastModified,
  }) = _$GCodeFileImpl;

  factory _GCodeFile.fromJson(Map<String, dynamic> json) =
      _$GCodeFileImpl.fromJson;

  @override
  String get name;
  @override
  int get size;
  @override
  int get lines;
  @override
  DateTime? get lastModified;

  /// Create a copy of GCodeFile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GCodeFileImplCopyWith<_$GCodeFileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
