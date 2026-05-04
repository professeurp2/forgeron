// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpio_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GpioState _$GpioStateFromJson(Map<String, dynamic> json) {
  return _GpioState.fromJson(json);
}

/// @nodoc
mixin _$GpioState {
  int get pin => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  bool get isTriggered => throw _privateConstructorUsedError;

  /// Serializes this GpioState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GpioState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GpioStateCopyWith<GpioState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GpioStateCopyWith<$Res> {
  factory $GpioStateCopyWith(GpioState value, $Res Function(GpioState) then) =
      _$GpioStateCopyWithImpl<$Res, GpioState>;
  @useResult
  $Res call({int pin, String label, bool isTriggered});
}

/// @nodoc
class _$GpioStateCopyWithImpl<$Res, $Val extends GpioState>
    implements $GpioStateCopyWith<$Res> {
  _$GpioStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GpioState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pin = null,
    Object? label = null,
    Object? isTriggered = null,
  }) {
    return _then(
      _value.copyWith(
            pin: null == pin
                ? _value.pin
                : pin // ignore: cast_nullable_to_non_nullable
                      as int,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            isTriggered: null == isTriggered
                ? _value.isTriggered
                : isTriggered // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GpioStateImplCopyWith<$Res>
    implements $GpioStateCopyWith<$Res> {
  factory _$$GpioStateImplCopyWith(
    _$GpioStateImpl value,
    $Res Function(_$GpioStateImpl) then,
  ) = __$$GpioStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int pin, String label, bool isTriggered});
}

/// @nodoc
class __$$GpioStateImplCopyWithImpl<$Res>
    extends _$GpioStateCopyWithImpl<$Res, _$GpioStateImpl>
    implements _$$GpioStateImplCopyWith<$Res> {
  __$$GpioStateImplCopyWithImpl(
    _$GpioStateImpl _value,
    $Res Function(_$GpioStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GpioState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pin = null,
    Object? label = null,
    Object? isTriggered = null,
  }) {
    return _then(
      _$GpioStateImpl(
        pin: null == pin
            ? _value.pin
            : pin // ignore: cast_nullable_to_non_nullable
                  as int,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        isTriggered: null == isTriggered
            ? _value.isTriggered
            : isTriggered // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GpioStateImpl implements _GpioState {
  const _$GpioStateImpl({
    required this.pin,
    required this.label,
    this.isTriggered = false,
  });

  factory _$GpioStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$GpioStateImplFromJson(json);

  @override
  final int pin;
  @override
  final String label;
  @override
  @JsonKey()
  final bool isTriggered;

  @override
  String toString() {
    return 'GpioState(pin: $pin, label: $label, isTriggered: $isTriggered)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GpioStateImpl &&
            (identical(other.pin, pin) || other.pin == pin) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.isTriggered, isTriggered) ||
                other.isTriggered == isTriggered));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, pin, label, isTriggered);

  /// Create a copy of GpioState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GpioStateImplCopyWith<_$GpioStateImpl> get copyWith =>
      __$$GpioStateImplCopyWithImpl<_$GpioStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GpioStateImplToJson(this);
  }
}

abstract class _GpioState implements GpioState {
  const factory _GpioState({
    required final int pin,
    required final String label,
    final bool isTriggered,
  }) = _$GpioStateImpl;

  factory _GpioState.fromJson(Map<String, dynamic> json) =
      _$GpioStateImpl.fromJson;

  @override
  int get pin;
  @override
  String get label;
  @override
  bool get isTriggered;

  /// Create a copy of GpioState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GpioStateImplCopyWith<_$GpioStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
