// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'macro.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Macro _$MacroFromJson(Map<String, dynamic> json) {
  return _Macro.fromJson(json);
}

/// @nodoc
mixin _$Macro {
  String get name => throw _privateConstructorUsedError;
  String get gcode => throw _privateConstructorUsedError;
  String get iconName => throw _privateConstructorUsedError;
  String get colorHex => throw _privateConstructorUsedError;

  /// Serializes this Macro to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Macro
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MacroCopyWith<Macro> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MacroCopyWith<$Res> {
  factory $MacroCopyWith(Macro value, $Res Function(Macro) then) =
      _$MacroCopyWithImpl<$Res, Macro>;
  @useResult
  $Res call({String name, String gcode, String iconName, String colorHex});
}

/// @nodoc
class _$MacroCopyWithImpl<$Res, $Val extends Macro>
    implements $MacroCopyWith<$Res> {
  _$MacroCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Macro
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? gcode = null,
    Object? iconName = null,
    Object? colorHex = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            gcode: null == gcode
                ? _value.gcode
                : gcode // ignore: cast_nullable_to_non_nullable
                      as String,
            iconName: null == iconName
                ? _value.iconName
                : iconName // ignore: cast_nullable_to_non_nullable
                      as String,
            colorHex: null == colorHex
                ? _value.colorHex
                : colorHex // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MacroImplCopyWith<$Res> implements $MacroCopyWith<$Res> {
  factory _$$MacroImplCopyWith(
    _$MacroImpl value,
    $Res Function(_$MacroImpl) then,
  ) = __$$MacroImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String gcode, String iconName, String colorHex});
}

/// @nodoc
class __$$MacroImplCopyWithImpl<$Res>
    extends _$MacroCopyWithImpl<$Res, _$MacroImpl>
    implements _$$MacroImplCopyWith<$Res> {
  __$$MacroImplCopyWithImpl(
    _$MacroImpl _value,
    $Res Function(_$MacroImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Macro
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? gcode = null,
    Object? iconName = null,
    Object? colorHex = null,
  }) {
    return _then(
      _$MacroImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        gcode: null == gcode
            ? _value.gcode
            : gcode // ignore: cast_nullable_to_non_nullable
                  as String,
        iconName: null == iconName
            ? _value.iconName
            : iconName // ignore: cast_nullable_to_non_nullable
                  as String,
        colorHex: null == colorHex
            ? _value.colorHex
            : colorHex // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MacroImpl implements _Macro {
  const _$MacroImpl({
    required this.name,
    required this.gcode,
    required this.iconName,
    this.colorHex = '#2196F3',
  });

  factory _$MacroImpl.fromJson(Map<String, dynamic> json) =>
      _$$MacroImplFromJson(json);

  @override
  final String name;
  @override
  final String gcode;
  @override
  final String iconName;
  @override
  @JsonKey()
  final String colorHex;

  @override
  String toString() {
    return 'Macro(name: $name, gcode: $gcode, iconName: $iconName, colorHex: $colorHex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MacroImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.gcode, gcode) || other.gcode == gcode) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            (identical(other.colorHex, colorHex) ||
                other.colorHex == colorHex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, gcode, iconName, colorHex);

  /// Create a copy of Macro
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MacroImplCopyWith<_$MacroImpl> get copyWith =>
      __$$MacroImplCopyWithImpl<_$MacroImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MacroImplToJson(this);
  }
}

abstract class _Macro implements Macro {
  const factory _Macro({
    required final String name,
    required final String gcode,
    required final String iconName,
    final String colorHex,
  }) = _$MacroImpl;

  factory _Macro.fromJson(Map<String, dynamic> json) = _$MacroImpl.fromJson;

  @override
  String get name;
  @override
  String get gcode;
  @override
  String get iconName;
  @override
  String get colorHex;

  /// Create a copy of Macro
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MacroImplCopyWith<_$MacroImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
