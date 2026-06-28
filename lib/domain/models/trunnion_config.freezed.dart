// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trunnion_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TrunnionConfig _$TrunnionConfigFromJson(Map<String, dynamic> json) {
  return _TrunnionConfig.fromJson(json);
}

/// @nodoc
mixin _$TrunnionConfig {
  // ── Plages angulaires ──────────────────────────────────────────────
  /// Plage de l'axe A (berceau) en degrés. ±90°.
  double get aAxisMaxAngle => throw _privateConstructorUsedError;

  /// Plage de l'axe C (plateau) en degrés. 360° continu.
  double get cAxisMaxAngle =>
      throw _privateConstructorUsedError; // ── Transmission GT2 ───────────────────────────────────────────────
  /// Pas de la courroie GT2 (mm).
  double get gt2Pitch => throw _privateConstructorUsedError;

  /// Nombre de dents de la poulie menante (moteur).
  int get drivingPulleyTeeth => throw _privateConstructorUsedError;

  /// Nombre de dents de la poulie menée (arbre).
  int get drivenPulleyTeeth =>
      throw _privateConstructorUsedError; // ── Moteurs NEMA 17 ────────────────────────────────────────────────
  /// Pas par tour du moteur (1,8° / pas → 200 pas/tour).
  int get motorStepsPerRev => throw _privateConstructorUsedError;

  /// Niveau de microstepping (1/16).
  int get microstepping =>
      throw _privateConstructorUsedError; // ── Efforts de coupe ───────────────────────────────────────────────
  /// Force résultante nominale en mode 5 axes (N).
  double get r5axForce => throw _privateConstructorUsedError;

  /// Force résultante maximale autorisée en 5 axes (N).
  /// Le ForceGuard embarqué bride automatiquement à cette valeur.
  double get rMaxForce => throw _privateConstructorUsedError;

  /// Force résultante nominale en mode 3 axes (N).
  double get r3axForce =>
      throw _privateConstructorUsedError; // ── Géométrie ──────────────────────────────────────────────────────
  /// Distance Z entre le centre de rotation A et la surface du plateau (mm).
  double get pivotToTableOffset => throw _privateConstructorUsedError;

  /// Zone de singularité autour de A = 0° (degrés).
  double get singularityZone =>
      throw _privateConstructorUsedError; // ── Vitesses max ───────────────────────────────────────────────────
  /// Vitesse de rotation max de l'axe A (°/min).
  double get aAxisMaxFeed => throw _privateConstructorUsedError;

  /// Vitesse de rotation max de l'axe C (°/min).
  double get cAxisMaxFeed =>
      throw _privateConstructorUsedError; // ── Courses linéaires (vis T8) ─────────────────────────────────────
  /// Course utile axe X (mm).
  double get travelX => throw _privateConstructorUsedError;

  /// Course utile axe Y (mm).
  double get travelY => throw _privateConstructorUsedError;

  /// Course utile axe Z (mm).
  double get travelZ => throw _privateConstructorUsedError;

  /// Serializes this TrunnionConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TrunnionConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TrunnionConfigCopyWith<TrunnionConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrunnionConfigCopyWith<$Res> {
  factory $TrunnionConfigCopyWith(
    TrunnionConfig value,
    $Res Function(TrunnionConfig) then,
  ) = _$TrunnionConfigCopyWithImpl<$Res, TrunnionConfig>;
  @useResult
  $Res call({
    double aAxisMaxAngle,
    double cAxisMaxAngle,
    double gt2Pitch,
    int drivingPulleyTeeth,
    int drivenPulleyTeeth,
    int motorStepsPerRev,
    int microstepping,
    double r5axForce,
    double rMaxForce,
    double r3axForce,
    double pivotToTableOffset,
    double singularityZone,
    double aAxisMaxFeed,
    double cAxisMaxFeed,
    double travelX,
    double travelY,
    double travelZ,
  });
}

/// @nodoc
class _$TrunnionConfigCopyWithImpl<$Res, $Val extends TrunnionConfig>
    implements $TrunnionConfigCopyWith<$Res> {
  _$TrunnionConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TrunnionConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? aAxisMaxAngle = null,
    Object? cAxisMaxAngle = null,
    Object? gt2Pitch = null,
    Object? drivingPulleyTeeth = null,
    Object? drivenPulleyTeeth = null,
    Object? motorStepsPerRev = null,
    Object? microstepping = null,
    Object? r5axForce = null,
    Object? rMaxForce = null,
    Object? r3axForce = null,
    Object? pivotToTableOffset = null,
    Object? singularityZone = null,
    Object? aAxisMaxFeed = null,
    Object? cAxisMaxFeed = null,
    Object? travelX = null,
    Object? travelY = null,
    Object? travelZ = null,
  }) {
    return _then(
      _value.copyWith(
            aAxisMaxAngle: null == aAxisMaxAngle
                ? _value.aAxisMaxAngle
                : aAxisMaxAngle // ignore: cast_nullable_to_non_nullable
                      as double,
            cAxisMaxAngle: null == cAxisMaxAngle
                ? _value.cAxisMaxAngle
                : cAxisMaxAngle // ignore: cast_nullable_to_non_nullable
                      as double,
            gt2Pitch: null == gt2Pitch
                ? _value.gt2Pitch
                : gt2Pitch // ignore: cast_nullable_to_non_nullable
                      as double,
            drivingPulleyTeeth: null == drivingPulleyTeeth
                ? _value.drivingPulleyTeeth
                : drivingPulleyTeeth // ignore: cast_nullable_to_non_nullable
                      as int,
            drivenPulleyTeeth: null == drivenPulleyTeeth
                ? _value.drivenPulleyTeeth
                : drivenPulleyTeeth // ignore: cast_nullable_to_non_nullable
                      as int,
            motorStepsPerRev: null == motorStepsPerRev
                ? _value.motorStepsPerRev
                : motorStepsPerRev // ignore: cast_nullable_to_non_nullable
                      as int,
            microstepping: null == microstepping
                ? _value.microstepping
                : microstepping // ignore: cast_nullable_to_non_nullable
                      as int,
            r5axForce: null == r5axForce
                ? _value.r5axForce
                : r5axForce // ignore: cast_nullable_to_non_nullable
                      as double,
            rMaxForce: null == rMaxForce
                ? _value.rMaxForce
                : rMaxForce // ignore: cast_nullable_to_non_nullable
                      as double,
            r3axForce: null == r3axForce
                ? _value.r3axForce
                : r3axForce // ignore: cast_nullable_to_non_nullable
                      as double,
            pivotToTableOffset: null == pivotToTableOffset
                ? _value.pivotToTableOffset
                : pivotToTableOffset // ignore: cast_nullable_to_non_nullable
                      as double,
            singularityZone: null == singularityZone
                ? _value.singularityZone
                : singularityZone // ignore: cast_nullable_to_non_nullable
                      as double,
            aAxisMaxFeed: null == aAxisMaxFeed
                ? _value.aAxisMaxFeed
                : aAxisMaxFeed // ignore: cast_nullable_to_non_nullable
                      as double,
            cAxisMaxFeed: null == cAxisMaxFeed
                ? _value.cAxisMaxFeed
                : cAxisMaxFeed // ignore: cast_nullable_to_non_nullable
                      as double,
            travelX: null == travelX
                ? _value.travelX
                : travelX // ignore: cast_nullable_to_non_nullable
                      as double,
            travelY: null == travelY
                ? _value.travelY
                : travelY // ignore: cast_nullable_to_non_nullable
                      as double,
            travelZ: null == travelZ
                ? _value.travelZ
                : travelZ // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TrunnionConfigImplCopyWith<$Res>
    implements $TrunnionConfigCopyWith<$Res> {
  factory _$$TrunnionConfigImplCopyWith(
    _$TrunnionConfigImpl value,
    $Res Function(_$TrunnionConfigImpl) then,
  ) = __$$TrunnionConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double aAxisMaxAngle,
    double cAxisMaxAngle,
    double gt2Pitch,
    int drivingPulleyTeeth,
    int drivenPulleyTeeth,
    int motorStepsPerRev,
    int microstepping,
    double r5axForce,
    double rMaxForce,
    double r3axForce,
    double pivotToTableOffset,
    double singularityZone,
    double aAxisMaxFeed,
    double cAxisMaxFeed,
    double travelX,
    double travelY,
    double travelZ,
  });
}

/// @nodoc
class __$$TrunnionConfigImplCopyWithImpl<$Res>
    extends _$TrunnionConfigCopyWithImpl<$Res, _$TrunnionConfigImpl>
    implements _$$TrunnionConfigImplCopyWith<$Res> {
  __$$TrunnionConfigImplCopyWithImpl(
    _$TrunnionConfigImpl _value,
    $Res Function(_$TrunnionConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TrunnionConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? aAxisMaxAngle = null,
    Object? cAxisMaxAngle = null,
    Object? gt2Pitch = null,
    Object? drivingPulleyTeeth = null,
    Object? drivenPulleyTeeth = null,
    Object? motorStepsPerRev = null,
    Object? microstepping = null,
    Object? r5axForce = null,
    Object? rMaxForce = null,
    Object? r3axForce = null,
    Object? pivotToTableOffset = null,
    Object? singularityZone = null,
    Object? aAxisMaxFeed = null,
    Object? cAxisMaxFeed = null,
    Object? travelX = null,
    Object? travelY = null,
    Object? travelZ = null,
  }) {
    return _then(
      _$TrunnionConfigImpl(
        aAxisMaxAngle: null == aAxisMaxAngle
            ? _value.aAxisMaxAngle
            : aAxisMaxAngle // ignore: cast_nullable_to_non_nullable
                  as double,
        cAxisMaxAngle: null == cAxisMaxAngle
            ? _value.cAxisMaxAngle
            : cAxisMaxAngle // ignore: cast_nullable_to_non_nullable
                  as double,
        gt2Pitch: null == gt2Pitch
            ? _value.gt2Pitch
            : gt2Pitch // ignore: cast_nullable_to_non_nullable
                  as double,
        drivingPulleyTeeth: null == drivingPulleyTeeth
            ? _value.drivingPulleyTeeth
            : drivingPulleyTeeth // ignore: cast_nullable_to_non_nullable
                  as int,
        drivenPulleyTeeth: null == drivenPulleyTeeth
            ? _value.drivenPulleyTeeth
            : drivenPulleyTeeth // ignore: cast_nullable_to_non_nullable
                  as int,
        motorStepsPerRev: null == motorStepsPerRev
            ? _value.motorStepsPerRev
            : motorStepsPerRev // ignore: cast_nullable_to_non_nullable
                  as int,
        microstepping: null == microstepping
            ? _value.microstepping
            : microstepping // ignore: cast_nullable_to_non_nullable
                  as int,
        r5axForce: null == r5axForce
            ? _value.r5axForce
            : r5axForce // ignore: cast_nullable_to_non_nullable
                  as double,
        rMaxForce: null == rMaxForce
            ? _value.rMaxForce
            : rMaxForce // ignore: cast_nullable_to_non_nullable
                  as double,
        r3axForce: null == r3axForce
            ? _value.r3axForce
            : r3axForce // ignore: cast_nullable_to_non_nullable
                  as double,
        pivotToTableOffset: null == pivotToTableOffset
            ? _value.pivotToTableOffset
            : pivotToTableOffset // ignore: cast_nullable_to_non_nullable
                  as double,
        singularityZone: null == singularityZone
            ? _value.singularityZone
            : singularityZone // ignore: cast_nullable_to_non_nullable
                  as double,
        aAxisMaxFeed: null == aAxisMaxFeed
            ? _value.aAxisMaxFeed
            : aAxisMaxFeed // ignore: cast_nullable_to_non_nullable
                  as double,
        cAxisMaxFeed: null == cAxisMaxFeed
            ? _value.cAxisMaxFeed
            : cAxisMaxFeed // ignore: cast_nullable_to_non_nullable
                  as double,
        travelX: null == travelX
            ? _value.travelX
            : travelX // ignore: cast_nullable_to_non_nullable
                  as double,
        travelY: null == travelY
            ? _value.travelY
            : travelY // ignore: cast_nullable_to_non_nullable
                  as double,
        travelZ: null == travelZ
            ? _value.travelZ
            : travelZ // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TrunnionConfigImpl extends _TrunnionConfig {
  const _$TrunnionConfigImpl({
    this.aAxisMaxAngle = 90.0,
    this.cAxisMaxAngle = 360.0,
    this.gt2Pitch = 2.0,
    this.drivingPulleyTeeth = 20,
    this.drivenPulleyTeeth = 120,
    this.motorStepsPerRev = 200,
    this.microstepping = 16,
    this.r5axForce = 30.0,
    this.rMaxForce = 45.6,
    this.r3axForce = 180.0,
    this.pivotToTableOffset = 45.0,
    this.singularityZone = 5.0,
    this.aAxisMaxFeed = 3600.0,
    this.cAxisMaxFeed = 7200.0,
    this.travelX = 200.0,
    this.travelY = 300.0,
    this.travelZ = 150.0,
  }) : super._();

  factory _$TrunnionConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$TrunnionConfigImplFromJson(json);

  // ── Plages angulaires ──────────────────────────────────────────────
  /// Plage de l'axe A (berceau) en degrés. ±90°.
  @override
  @JsonKey()
  final double aAxisMaxAngle;

  /// Plage de l'axe C (plateau) en degrés. 360° continu.
  @override
  @JsonKey()
  final double cAxisMaxAngle;
  // ── Transmission GT2 ───────────────────────────────────────────────
  /// Pas de la courroie GT2 (mm).
  @override
  @JsonKey()
  final double gt2Pitch;

  /// Nombre de dents de la poulie menante (moteur).
  @override
  @JsonKey()
  final int drivingPulleyTeeth;

  /// Nombre de dents de la poulie menée (arbre).
  @override
  @JsonKey()
  final int drivenPulleyTeeth;
  // ── Moteurs NEMA 17 ────────────────────────────────────────────────
  /// Pas par tour du moteur (1,8° / pas → 200 pas/tour).
  @override
  @JsonKey()
  final int motorStepsPerRev;

  /// Niveau de microstepping (1/16).
  @override
  @JsonKey()
  final int microstepping;
  // ── Efforts de coupe ───────────────────────────────────────────────
  /// Force résultante nominale en mode 5 axes (N).
  @override
  @JsonKey()
  final double r5axForce;

  /// Force résultante maximale autorisée en 5 axes (N).
  /// Le ForceGuard embarqué bride automatiquement à cette valeur.
  @override
  @JsonKey()
  final double rMaxForce;

  /// Force résultante nominale en mode 3 axes (N).
  @override
  @JsonKey()
  final double r3axForce;
  // ── Géométrie ──────────────────────────────────────────────────────
  /// Distance Z entre le centre de rotation A et la surface du plateau (mm).
  @override
  @JsonKey()
  final double pivotToTableOffset;

  /// Zone de singularité autour de A = 0° (degrés).
  @override
  @JsonKey()
  final double singularityZone;
  // ── Vitesses max ───────────────────────────────────────────────────
  /// Vitesse de rotation max de l'axe A (°/min).
  @override
  @JsonKey()
  final double aAxisMaxFeed;

  /// Vitesse de rotation max de l'axe C (°/min).
  @override
  @JsonKey()
  final double cAxisMaxFeed;
  // ── Courses linéaires (vis T8) ─────────────────────────────────────
  /// Course utile axe X (mm).
  @override
  @JsonKey()
  final double travelX;

  /// Course utile axe Y (mm).
  @override
  @JsonKey()
  final double travelY;

  /// Course utile axe Z (mm).
  @override
  @JsonKey()
  final double travelZ;

  @override
  String toString() {
    return 'TrunnionConfig(aAxisMaxAngle: $aAxisMaxAngle, cAxisMaxAngle: $cAxisMaxAngle, gt2Pitch: $gt2Pitch, drivingPulleyTeeth: $drivingPulleyTeeth, drivenPulleyTeeth: $drivenPulleyTeeth, motorStepsPerRev: $motorStepsPerRev, microstepping: $microstepping, r5axForce: $r5axForce, rMaxForce: $rMaxForce, r3axForce: $r3axForce, pivotToTableOffset: $pivotToTableOffset, singularityZone: $singularityZone, aAxisMaxFeed: $aAxisMaxFeed, cAxisMaxFeed: $cAxisMaxFeed, travelX: $travelX, travelY: $travelY, travelZ: $travelZ)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrunnionConfigImpl &&
            (identical(other.aAxisMaxAngle, aAxisMaxAngle) ||
                other.aAxisMaxAngle == aAxisMaxAngle) &&
            (identical(other.cAxisMaxAngle, cAxisMaxAngle) ||
                other.cAxisMaxAngle == cAxisMaxAngle) &&
            (identical(other.gt2Pitch, gt2Pitch) ||
                other.gt2Pitch == gt2Pitch) &&
            (identical(other.drivingPulleyTeeth, drivingPulleyTeeth) ||
                other.drivingPulleyTeeth == drivingPulleyTeeth) &&
            (identical(other.drivenPulleyTeeth, drivenPulleyTeeth) ||
                other.drivenPulleyTeeth == drivenPulleyTeeth) &&
            (identical(other.motorStepsPerRev, motorStepsPerRev) ||
                other.motorStepsPerRev == motorStepsPerRev) &&
            (identical(other.microstepping, microstepping) ||
                other.microstepping == microstepping) &&
            (identical(other.r5axForce, r5axForce) ||
                other.r5axForce == r5axForce) &&
            (identical(other.rMaxForce, rMaxForce) ||
                other.rMaxForce == rMaxForce) &&
            (identical(other.r3axForce, r3axForce) ||
                other.r3axForce == r3axForce) &&
            (identical(other.pivotToTableOffset, pivotToTableOffset) ||
                other.pivotToTableOffset == pivotToTableOffset) &&
            (identical(other.singularityZone, singularityZone) ||
                other.singularityZone == singularityZone) &&
            (identical(other.aAxisMaxFeed, aAxisMaxFeed) ||
                other.aAxisMaxFeed == aAxisMaxFeed) &&
            (identical(other.cAxisMaxFeed, cAxisMaxFeed) ||
                other.cAxisMaxFeed == cAxisMaxFeed) &&
            (identical(other.travelX, travelX) || other.travelX == travelX) &&
            (identical(other.travelY, travelY) || other.travelY == travelY) &&
            (identical(other.travelZ, travelZ) || other.travelZ == travelZ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    aAxisMaxAngle,
    cAxisMaxAngle,
    gt2Pitch,
    drivingPulleyTeeth,
    drivenPulleyTeeth,
    motorStepsPerRev,
    microstepping,
    r5axForce,
    rMaxForce,
    r3axForce,
    pivotToTableOffset,
    singularityZone,
    aAxisMaxFeed,
    cAxisMaxFeed,
    travelX,
    travelY,
    travelZ,
  );

  /// Create a copy of TrunnionConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TrunnionConfigImplCopyWith<_$TrunnionConfigImpl> get copyWith =>
      __$$TrunnionConfigImplCopyWithImpl<_$TrunnionConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TrunnionConfigImplToJson(this);
  }
}

abstract class _TrunnionConfig extends TrunnionConfig {
  const factory _TrunnionConfig({
    final double aAxisMaxAngle,
    final double cAxisMaxAngle,
    final double gt2Pitch,
    final int drivingPulleyTeeth,
    final int drivenPulleyTeeth,
    final int motorStepsPerRev,
    final int microstepping,
    final double r5axForce,
    final double rMaxForce,
    final double r3axForce,
    final double pivotToTableOffset,
    final double singularityZone,
    final double aAxisMaxFeed,
    final double cAxisMaxFeed,
    final double travelX,
    final double travelY,
    final double travelZ,
  }) = _$TrunnionConfigImpl;
  const _TrunnionConfig._() : super._();

  factory _TrunnionConfig.fromJson(Map<String, dynamic> json) =
      _$TrunnionConfigImpl.fromJson;

  // ── Plages angulaires ──────────────────────────────────────────────
  /// Plage de l'axe A (berceau) en degrés. ±90°.
  @override
  double get aAxisMaxAngle;

  /// Plage de l'axe C (plateau) en degrés. 360° continu.
  @override
  double get cAxisMaxAngle; // ── Transmission GT2 ───────────────────────────────────────────────
  /// Pas de la courroie GT2 (mm).
  @override
  double get gt2Pitch;

  /// Nombre de dents de la poulie menante (moteur).
  @override
  int get drivingPulleyTeeth;

  /// Nombre de dents de la poulie menée (arbre).
  @override
  int get drivenPulleyTeeth; // ── Moteurs NEMA 17 ────────────────────────────────────────────────
  /// Pas par tour du moteur (1,8° / pas → 200 pas/tour).
  @override
  int get motorStepsPerRev;

  /// Niveau de microstepping (1/16).
  @override
  int get microstepping; // ── Efforts de coupe ───────────────────────────────────────────────
  /// Force résultante nominale en mode 5 axes (N).
  @override
  double get r5axForce;

  /// Force résultante maximale autorisée en 5 axes (N).
  /// Le ForceGuard embarqué bride automatiquement à cette valeur.
  @override
  double get rMaxForce;

  /// Force résultante nominale en mode 3 axes (N).
  @override
  double get r3axForce; // ── Géométrie ──────────────────────────────────────────────────────
  /// Distance Z entre le centre de rotation A et la surface du plateau (mm).
  @override
  double get pivotToTableOffset;

  /// Zone de singularité autour de A = 0° (degrés).
  @override
  double get singularityZone; // ── Vitesses max ───────────────────────────────────────────────────
  /// Vitesse de rotation max de l'axe A (°/min).
  @override
  double get aAxisMaxFeed;

  /// Vitesse de rotation max de l'axe C (°/min).
  @override
  double get cAxisMaxFeed; // ── Courses linéaires (vis T8) ─────────────────────────────────────
  /// Course utile axe X (mm).
  @override
  double get travelX;

  /// Course utile axe Y (mm).
  @override
  double get travelY;

  /// Course utile axe Z (mm).
  @override
  double get travelZ;

  /// Create a copy of TrunnionConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TrunnionConfigImplCopyWith<_$TrunnionConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
