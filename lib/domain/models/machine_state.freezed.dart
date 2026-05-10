// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MachineState _$MachineStateFromJson(Map<String, dynamic> json) {
  return _MachineState.fromJson(json);
}

/// @nodoc
mixin _$MachineState {
  // --- Statut ---
  MachineStatus get status => throw _privateConstructorUsedError;
  int? get alarmCode =>
      throw _privateConstructorUsedError; // Code numérique de l'alarme ALARM:N
  // --- Positions (X, Y, Z = mm | A, C = degrés) ---
  List<double> get mPos =>
      throw _privateConstructorUsedError; // Machine Position
  List<double> get wPos => throw _privateConstructorUsedError; // Work Position
  List<double> get wco =>
      throw _privateConstructorUsedError; // WCS Offset (WPos = MPos - WCO)
  List<double> get targetPos =>
      throw _privateConstructorUsedError; // Planned/Ghost Position
  double get singularityRisk =>
      throw _privateConstructorUsedError; // 0.0 to 1.0 risk level
  // --- Dynamique ---
  double get feedrate => throw _privateConstructorUsedError; // mm/min
  double get spindleSpeed => throw _privateConstructorUsedError; // RPM
  double get spindleLoad =>
      throw _privateConstructorUsedError; // % ou kW (simulé)
  double get coreTemp => throw _privateConstructorUsedError; // °C
  bool get isRtcpActive => throw _privateConstructorUsedError; // G43.4 status
  // --- Overrides (%) ---
  List<int> get overrides =>
      throw _privateConstructorUsedError; // [Feed, Rapid, Spindle]
  // --- Contexte modal ---
  String get activeWCS => throw _privateConstructorUsedError; // G54..G59.3
  int get activeToolNum => throw _privateConstructorUsedError; // T0..T99
  List<bool> get limitSwitches => throw _privateConstructorUsedError;
  bool get probeTriggered => throw _privateConstructorUsedError;
  bool get emergencyTriggered =>
      throw _privateConstructorUsedError; // --- Progression SD (FluidNC) ---
  double get sdPercent => throw _privateConstructorUsedError;
  String? get sdFilename => throw _privateConstructorUsedError;
  int get activeLineIndex =>
      throw _privateConstructorUsedError; // Index de la ligne G-Code en cours d'exécution
  // --- Buffers FluidNC (Bf:blocks,bytes) ---
  int get plannerBuffer =>
      throw _privateConstructorUsedError; // Blocs disponibles dans la file
  int get rxBuffer => throw _privateConstructorUsedError;

  /// Serializes this MachineState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MachineState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MachineStateCopyWith<MachineState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MachineStateCopyWith<$Res> {
  factory $MachineStateCopyWith(
    MachineState value,
    $Res Function(MachineState) then,
  ) = _$MachineStateCopyWithImpl<$Res, MachineState>;
  @useResult
  $Res call({
    MachineStatus status,
    int? alarmCode,
    List<double> mPos,
    List<double> wPos,
    List<double> wco,
    List<double> targetPos,
    double singularityRisk,
    double feedrate,
    double spindleSpeed,
    double spindleLoad,
    double coreTemp,
    bool isRtcpActive,
    List<int> overrides,
    String activeWCS,
    int activeToolNum,
    List<bool> limitSwitches,
    bool probeTriggered,
    bool emergencyTriggered,
    double sdPercent,
    String? sdFilename,
    int activeLineIndex,
    int plannerBuffer,
    int rxBuffer,
  });
}

/// @nodoc
class _$MachineStateCopyWithImpl<$Res, $Val extends MachineState>
    implements $MachineStateCopyWith<$Res> {
  _$MachineStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MachineState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? alarmCode = freezed,
    Object? mPos = null,
    Object? wPos = null,
    Object? wco = null,
    Object? targetPos = null,
    Object? singularityRisk = null,
    Object? feedrate = null,
    Object? spindleSpeed = null,
    Object? spindleLoad = null,
    Object? coreTemp = null,
    Object? isRtcpActive = null,
    Object? overrides = null,
    Object? activeWCS = null,
    Object? activeToolNum = null,
    Object? limitSwitches = null,
    Object? probeTriggered = null,
    Object? emergencyTriggered = null,
    Object? sdPercent = null,
    Object? sdFilename = freezed,
    Object? activeLineIndex = null,
    Object? plannerBuffer = null,
    Object? rxBuffer = null,
  }) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as MachineStatus,
            alarmCode: freezed == alarmCode
                ? _value.alarmCode
                : alarmCode // ignore: cast_nullable_to_non_nullable
                      as int?,
            mPos: null == mPos
                ? _value.mPos
                : mPos // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            wPos: null == wPos
                ? _value.wPos
                : wPos // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            wco: null == wco
                ? _value.wco
                : wco // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            targetPos: null == targetPos
                ? _value.targetPos
                : targetPos // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            singularityRisk: null == singularityRisk
                ? _value.singularityRisk
                : singularityRisk // ignore: cast_nullable_to_non_nullable
                      as double,
            feedrate: null == feedrate
                ? _value.feedrate
                : feedrate // ignore: cast_nullable_to_non_nullable
                      as double,
            spindleSpeed: null == spindleSpeed
                ? _value.spindleSpeed
                : spindleSpeed // ignore: cast_nullable_to_non_nullable
                      as double,
            spindleLoad: null == spindleLoad
                ? _value.spindleLoad
                : spindleLoad // ignore: cast_nullable_to_non_nullable
                      as double,
            coreTemp: null == coreTemp
                ? _value.coreTemp
                : coreTemp // ignore: cast_nullable_to_non_nullable
                      as double,
            isRtcpActive: null == isRtcpActive
                ? _value.isRtcpActive
                : isRtcpActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            overrides: null == overrides
                ? _value.overrides
                : overrides // ignore: cast_nullable_to_non_nullable
                      as List<int>,
            activeWCS: null == activeWCS
                ? _value.activeWCS
                : activeWCS // ignore: cast_nullable_to_non_nullable
                      as String,
            activeToolNum: null == activeToolNum
                ? _value.activeToolNum
                : activeToolNum // ignore: cast_nullable_to_non_nullable
                      as int,
            limitSwitches: null == limitSwitches
                ? _value.limitSwitches
                : limitSwitches // ignore: cast_nullable_to_non_nullable
                      as List<bool>,
            probeTriggered: null == probeTriggered
                ? _value.probeTriggered
                : probeTriggered // ignore: cast_nullable_to_non_nullable
                      as bool,
            emergencyTriggered: null == emergencyTriggered
                ? _value.emergencyTriggered
                : emergencyTriggered // ignore: cast_nullable_to_non_nullable
                      as bool,
            sdPercent: null == sdPercent
                ? _value.sdPercent
                : sdPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            sdFilename: freezed == sdFilename
                ? _value.sdFilename
                : sdFilename // ignore: cast_nullable_to_non_nullable
                      as String?,
            activeLineIndex: null == activeLineIndex
                ? _value.activeLineIndex
                : activeLineIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            plannerBuffer: null == plannerBuffer
                ? _value.plannerBuffer
                : plannerBuffer // ignore: cast_nullable_to_non_nullable
                      as int,
            rxBuffer: null == rxBuffer
                ? _value.rxBuffer
                : rxBuffer // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MachineStateImplCopyWith<$Res>
    implements $MachineStateCopyWith<$Res> {
  factory _$$MachineStateImplCopyWith(
    _$MachineStateImpl value,
    $Res Function(_$MachineStateImpl) then,
  ) = __$$MachineStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    MachineStatus status,
    int? alarmCode,
    List<double> mPos,
    List<double> wPos,
    List<double> wco,
    List<double> targetPos,
    double singularityRisk,
    double feedrate,
    double spindleSpeed,
    double spindleLoad,
    double coreTemp,
    bool isRtcpActive,
    List<int> overrides,
    String activeWCS,
    int activeToolNum,
    List<bool> limitSwitches,
    bool probeTriggered,
    bool emergencyTriggered,
    double sdPercent,
    String? sdFilename,
    int activeLineIndex,
    int plannerBuffer,
    int rxBuffer,
  });
}

/// @nodoc
class __$$MachineStateImplCopyWithImpl<$Res>
    extends _$MachineStateCopyWithImpl<$Res, _$MachineStateImpl>
    implements _$$MachineStateImplCopyWith<$Res> {
  __$$MachineStateImplCopyWithImpl(
    _$MachineStateImpl _value,
    $Res Function(_$MachineStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MachineState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? alarmCode = freezed,
    Object? mPos = null,
    Object? wPos = null,
    Object? wco = null,
    Object? targetPos = null,
    Object? singularityRisk = null,
    Object? feedrate = null,
    Object? spindleSpeed = null,
    Object? spindleLoad = null,
    Object? coreTemp = null,
    Object? isRtcpActive = null,
    Object? overrides = null,
    Object? activeWCS = null,
    Object? activeToolNum = null,
    Object? limitSwitches = null,
    Object? probeTriggered = null,
    Object? emergencyTriggered = null,
    Object? sdPercent = null,
    Object? sdFilename = freezed,
    Object? activeLineIndex = null,
    Object? plannerBuffer = null,
    Object? rxBuffer = null,
  }) {
    return _then(
      _$MachineStateImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as MachineStatus,
        alarmCode: freezed == alarmCode
            ? _value.alarmCode
            : alarmCode // ignore: cast_nullable_to_non_nullable
                  as int?,
        mPos: null == mPos
            ? _value._mPos
            : mPos // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        wPos: null == wPos
            ? _value._wPos
            : wPos // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        wco: null == wco
            ? _value._wco
            : wco // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        targetPos: null == targetPos
            ? _value._targetPos
            : targetPos // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        singularityRisk: null == singularityRisk
            ? _value.singularityRisk
            : singularityRisk // ignore: cast_nullable_to_non_nullable
                  as double,
        feedrate: null == feedrate
            ? _value.feedrate
            : feedrate // ignore: cast_nullable_to_non_nullable
                  as double,
        spindleSpeed: null == spindleSpeed
            ? _value.spindleSpeed
            : spindleSpeed // ignore: cast_nullable_to_non_nullable
                  as double,
        spindleLoad: null == spindleLoad
            ? _value.spindleLoad
            : spindleLoad // ignore: cast_nullable_to_non_nullable
                  as double,
        coreTemp: null == coreTemp
            ? _value.coreTemp
            : coreTemp // ignore: cast_nullable_to_non_nullable
                  as double,
        isRtcpActive: null == isRtcpActive
            ? _value.isRtcpActive
            : isRtcpActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        overrides: null == overrides
            ? _value._overrides
            : overrides // ignore: cast_nullable_to_non_nullable
                  as List<int>,
        activeWCS: null == activeWCS
            ? _value.activeWCS
            : activeWCS // ignore: cast_nullable_to_non_nullable
                  as String,
        activeToolNum: null == activeToolNum
            ? _value.activeToolNum
            : activeToolNum // ignore: cast_nullable_to_non_nullable
                  as int,
        limitSwitches: null == limitSwitches
            ? _value._limitSwitches
            : limitSwitches // ignore: cast_nullable_to_non_nullable
                  as List<bool>,
        probeTriggered: null == probeTriggered
            ? _value.probeTriggered
            : probeTriggered // ignore: cast_nullable_to_non_nullable
                  as bool,
        emergencyTriggered: null == emergencyTriggered
            ? _value.emergencyTriggered
            : emergencyTriggered // ignore: cast_nullable_to_non_nullable
                  as bool,
        sdPercent: null == sdPercent
            ? _value.sdPercent
            : sdPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        sdFilename: freezed == sdFilename
            ? _value.sdFilename
            : sdFilename // ignore: cast_nullable_to_non_nullable
                  as String?,
        activeLineIndex: null == activeLineIndex
            ? _value.activeLineIndex
            : activeLineIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        plannerBuffer: null == plannerBuffer
            ? _value.plannerBuffer
            : plannerBuffer // ignore: cast_nullable_to_non_nullable
                  as int,
        rxBuffer: null == rxBuffer
            ? _value.rxBuffer
            : rxBuffer // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MachineStateImpl implements _MachineState {
  const _$MachineStateImpl({
    this.status = MachineStatus.offline,
    this.alarmCode,
    final List<double> mPos = const [0.0, 0.0, 0.0, 0.0, 0.0],
    final List<double> wPos = const [0.0, 0.0, 0.0, 0.0, 0.0],
    final List<double> wco = const [0.0, 0.0, 0.0, 0.0, 0.0],
    final List<double> targetPos = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.singularityRisk = 0.0,
    this.feedrate = 0.0,
    this.spindleSpeed = 0.0,
    this.spindleLoad = 0.0,
    this.coreTemp = 40.0,
    this.isRtcpActive = false,
    final List<int> overrides = const [100, 100, 100],
    this.activeWCS = 'G54',
    this.activeToolNum = 0,
    final List<bool> limitSwitches = const [false, false, false, false, false],
    this.probeTriggered = false,
    this.emergencyTriggered = false,
    this.sdPercent = 0.0,
    this.sdFilename,
    this.activeLineIndex = 0,
    this.plannerBuffer = 15,
    this.rxBuffer = 128,
  }) : _mPos = mPos,
       _wPos = wPos,
       _wco = wco,
       _targetPos = targetPos,
       _overrides = overrides,
       _limitSwitches = limitSwitches;

  factory _$MachineStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$MachineStateImplFromJson(json);

  // --- Statut ---
  @override
  @JsonKey()
  final MachineStatus status;
  @override
  final int? alarmCode;
  // Code numérique de l'alarme ALARM:N
  // --- Positions (X, Y, Z = mm | A, C = degrés) ---
  final List<double> _mPos;
  // Code numérique de l'alarme ALARM:N
  // --- Positions (X, Y, Z = mm | A, C = degrés) ---
  @override
  @JsonKey()
  List<double> get mPos {
    if (_mPos is EqualUnmodifiableListView) return _mPos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mPos);
  }

  // Machine Position
  final List<double> _wPos;
  // Machine Position
  @override
  @JsonKey()
  List<double> get wPos {
    if (_wPos is EqualUnmodifiableListView) return _wPos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_wPos);
  }

  // Work Position
  final List<double> _wco;
  // Work Position
  @override
  @JsonKey()
  List<double> get wco {
    if (_wco is EqualUnmodifiableListView) return _wco;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_wco);
  }

  // WCS Offset (WPos = MPos - WCO)
  final List<double> _targetPos;
  // WCS Offset (WPos = MPos - WCO)
  @override
  @JsonKey()
  List<double> get targetPos {
    if (_targetPos is EqualUnmodifiableListView) return _targetPos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetPos);
  }

  // Planned/Ghost Position
  @override
  @JsonKey()
  final double singularityRisk;
  // 0.0 to 1.0 risk level
  // --- Dynamique ---
  @override
  @JsonKey()
  final double feedrate;
  // mm/min
  @override
  @JsonKey()
  final double spindleSpeed;
  // RPM
  @override
  @JsonKey()
  final double spindleLoad;
  // % ou kW (simulé)
  @override
  @JsonKey()
  final double coreTemp;
  // °C
  @override
  @JsonKey()
  final bool isRtcpActive;
  // G43.4 status
  // --- Overrides (%) ---
  final List<int> _overrides;
  // G43.4 status
  // --- Overrides (%) ---
  @override
  @JsonKey()
  List<int> get overrides {
    if (_overrides is EqualUnmodifiableListView) return _overrides;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_overrides);
  }

  // [Feed, Rapid, Spindle]
  // --- Contexte modal ---
  @override
  @JsonKey()
  final String activeWCS;
  // G54..G59.3
  @override
  @JsonKey()
  final int activeToolNum;
  // T0..T99
  final List<bool> _limitSwitches;
  // T0..T99
  @override
  @JsonKey()
  List<bool> get limitSwitches {
    if (_limitSwitches is EqualUnmodifiableListView) return _limitSwitches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_limitSwitches);
  }

  @override
  @JsonKey()
  final bool probeTriggered;
  @override
  @JsonKey()
  final bool emergencyTriggered;
  // --- Progression SD (FluidNC) ---
  @override
  @JsonKey()
  final double sdPercent;
  @override
  final String? sdFilename;
  @override
  @JsonKey()
  final int activeLineIndex;
  // Index de la ligne G-Code en cours d'exécution
  // --- Buffers FluidNC (Bf:blocks,bytes) ---
  @override
  @JsonKey()
  final int plannerBuffer;
  // Blocs disponibles dans la file
  @override
  @JsonKey()
  final int rxBuffer;

  @override
  String toString() {
    return 'MachineState(status: $status, alarmCode: $alarmCode, mPos: $mPos, wPos: $wPos, wco: $wco, targetPos: $targetPos, singularityRisk: $singularityRisk, feedrate: $feedrate, spindleSpeed: $spindleSpeed, spindleLoad: $spindleLoad, coreTemp: $coreTemp, isRtcpActive: $isRtcpActive, overrides: $overrides, activeWCS: $activeWCS, activeToolNum: $activeToolNum, limitSwitches: $limitSwitches, probeTriggered: $probeTriggered, emergencyTriggered: $emergencyTriggered, sdPercent: $sdPercent, sdFilename: $sdFilename, activeLineIndex: $activeLineIndex, plannerBuffer: $plannerBuffer, rxBuffer: $rxBuffer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MachineStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.alarmCode, alarmCode) ||
                other.alarmCode == alarmCode) &&
            const DeepCollectionEquality().equals(other._mPos, _mPos) &&
            const DeepCollectionEquality().equals(other._wPos, _wPos) &&
            const DeepCollectionEquality().equals(other._wco, _wco) &&
            const DeepCollectionEquality().equals(
              other._targetPos,
              _targetPos,
            ) &&
            (identical(other.singularityRisk, singularityRisk) ||
                other.singularityRisk == singularityRisk) &&
            (identical(other.feedrate, feedrate) ||
                other.feedrate == feedrate) &&
            (identical(other.spindleSpeed, spindleSpeed) ||
                other.spindleSpeed == spindleSpeed) &&
            (identical(other.spindleLoad, spindleLoad) ||
                other.spindleLoad == spindleLoad) &&
            (identical(other.coreTemp, coreTemp) ||
                other.coreTemp == coreTemp) &&
            (identical(other.isRtcpActive, isRtcpActive) ||
                other.isRtcpActive == isRtcpActive) &&
            const DeepCollectionEquality().equals(
              other._overrides,
              _overrides,
            ) &&
            (identical(other.activeWCS, activeWCS) ||
                other.activeWCS == activeWCS) &&
            (identical(other.activeToolNum, activeToolNum) ||
                other.activeToolNum == activeToolNum) &&
            const DeepCollectionEquality().equals(
              other._limitSwitches,
              _limitSwitches,
            ) &&
            (identical(other.probeTriggered, probeTriggered) ||
                other.probeTriggered == probeTriggered) &&
            (identical(other.emergencyTriggered, emergencyTriggered) ||
                other.emergencyTriggered == emergencyTriggered) &&
            (identical(other.sdPercent, sdPercent) ||
                other.sdPercent == sdPercent) &&
            (identical(other.sdFilename, sdFilename) ||
                other.sdFilename == sdFilename) &&
            (identical(other.activeLineIndex, activeLineIndex) ||
                other.activeLineIndex == activeLineIndex) &&
            (identical(other.plannerBuffer, plannerBuffer) ||
                other.plannerBuffer == plannerBuffer) &&
            (identical(other.rxBuffer, rxBuffer) ||
                other.rxBuffer == rxBuffer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    status,
    alarmCode,
    const DeepCollectionEquality().hash(_mPos),
    const DeepCollectionEquality().hash(_wPos),
    const DeepCollectionEquality().hash(_wco),
    const DeepCollectionEquality().hash(_targetPos),
    singularityRisk,
    feedrate,
    spindleSpeed,
    spindleLoad,
    coreTemp,
    isRtcpActive,
    const DeepCollectionEquality().hash(_overrides),
    activeWCS,
    activeToolNum,
    const DeepCollectionEquality().hash(_limitSwitches),
    probeTriggered,
    emergencyTriggered,
    sdPercent,
    sdFilename,
    activeLineIndex,
    plannerBuffer,
    rxBuffer,
  ]);

  /// Create a copy of MachineState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MachineStateImplCopyWith<_$MachineStateImpl> get copyWith =>
      __$$MachineStateImplCopyWithImpl<_$MachineStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MachineStateImplToJson(this);
  }
}

abstract class _MachineState implements MachineState {
  const factory _MachineState({
    final MachineStatus status,
    final int? alarmCode,
    final List<double> mPos,
    final List<double> wPos,
    final List<double> wco,
    final List<double> targetPos,
    final double singularityRisk,
    final double feedrate,
    final double spindleSpeed,
    final double spindleLoad,
    final double coreTemp,
    final bool isRtcpActive,
    final List<int> overrides,
    final String activeWCS,
    final int activeToolNum,
    final List<bool> limitSwitches,
    final bool probeTriggered,
    final bool emergencyTriggered,
    final double sdPercent,
    final String? sdFilename,
    final int activeLineIndex,
    final int plannerBuffer,
    final int rxBuffer,
  }) = _$MachineStateImpl;

  factory _MachineState.fromJson(Map<String, dynamic> json) =
      _$MachineStateImpl.fromJson;

  // --- Statut ---
  @override
  MachineStatus get status;
  @override
  int? get alarmCode; // Code numérique de l'alarme ALARM:N
  // --- Positions (X, Y, Z = mm | A, C = degrés) ---
  @override
  List<double> get mPos; // Machine Position
  @override
  List<double> get wPos; // Work Position
  @override
  List<double> get wco; // WCS Offset (WPos = MPos - WCO)
  @override
  List<double> get targetPos; // Planned/Ghost Position
  @override
  double get singularityRisk; // 0.0 to 1.0 risk level
  // --- Dynamique ---
  @override
  double get feedrate; // mm/min
  @override
  double get spindleSpeed; // RPM
  @override
  double get spindleLoad; // % ou kW (simulé)
  @override
  double get coreTemp; // °C
  @override
  bool get isRtcpActive; // G43.4 status
  // --- Overrides (%) ---
  @override
  List<int> get overrides; // [Feed, Rapid, Spindle]
  // --- Contexte modal ---
  @override
  String get activeWCS; // G54..G59.3
  @override
  int get activeToolNum; // T0..T99
  @override
  List<bool> get limitSwitches;
  @override
  bool get probeTriggered;
  @override
  bool get emergencyTriggered; // --- Progression SD (FluidNC) ---
  @override
  double get sdPercent;
  @override
  String? get sdFilename;
  @override
  int get activeLineIndex; // Index de la ligne G-Code en cours d'exécution
  // --- Buffers FluidNC (Bf:blocks,bytes) ---
  @override
  int get plannerBuffer; // Blocs disponibles dans la file
  @override
  int get rxBuffer;

  /// Create a copy of MachineState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MachineStateImplCopyWith<_$MachineStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
