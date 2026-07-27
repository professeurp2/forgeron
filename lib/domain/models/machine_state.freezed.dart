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
  String? get lastMessage =>
      throw _privateConstructorUsedError; // Message GRBL [MSG:...]
  // --- Offsets WCS (G54..G59), lus via la réponse $# ---
  Map<String, List<double>> get wcsOffsets =>
      throw _privateConstructorUsedError;
  List<bool> get limitSwitches => throw _privateConstructorUsedError;
  bool get probeTriggered => throw _privateConstructorUsedError;
  Map<String, dynamic>? get probeResult =>
      throw _privateConstructorUsedError; // Résultat du dernier PRB
  bool get emergencyTriggered =>
      throw _privateConstructorUsedError; // --- Mode d'usinage (PFE §3.4) ---
  MachiningMode get machiningMode => throw _privateConstructorUsedError;
  bool get forceGuardActive =>
      throw _privateConstructorUsedError; // Bridage ForceGuard actif
  // --- Progression SD (FluidNC) ---
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
    String? lastMessage,
    Map<String, List<double>> wcsOffsets,
    List<bool> limitSwitches,
    bool probeTriggered,
    Map<String, dynamic>? probeResult,
    bool emergencyTriggered,
    MachiningMode machiningMode,
    bool forceGuardActive,
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
    Object? lastMessage = freezed,
    Object? wcsOffsets = null,
    Object? limitSwitches = null,
    Object? probeTriggered = null,
    Object? probeResult = freezed,
    Object? emergencyTriggered = null,
    Object? machiningMode = null,
    Object? forceGuardActive = null,
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
            lastMessage: freezed == lastMessage
                ? _value.lastMessage
                : lastMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            wcsOffsets: null == wcsOffsets
                ? _value.wcsOffsets
                : wcsOffsets // ignore: cast_nullable_to_non_nullable
                      as Map<String, List<double>>,
            limitSwitches: null == limitSwitches
                ? _value.limitSwitches
                : limitSwitches // ignore: cast_nullable_to_non_nullable
                      as List<bool>,
            probeTriggered: null == probeTriggered
                ? _value.probeTriggered
                : probeTriggered // ignore: cast_nullable_to_non_nullable
                      as bool,
            probeResult: freezed == probeResult
                ? _value.probeResult
                : probeResult // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            emergencyTriggered: null == emergencyTriggered
                ? _value.emergencyTriggered
                : emergencyTriggered // ignore: cast_nullable_to_non_nullable
                      as bool,
            machiningMode: null == machiningMode
                ? _value.machiningMode
                : machiningMode // ignore: cast_nullable_to_non_nullable
                      as MachiningMode,
            forceGuardActive: null == forceGuardActive
                ? _value.forceGuardActive
                : forceGuardActive // ignore: cast_nullable_to_non_nullable
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
    String? lastMessage,
    Map<String, List<double>> wcsOffsets,
    List<bool> limitSwitches,
    bool probeTriggered,
    Map<String, dynamic>? probeResult,
    bool emergencyTriggered,
    MachiningMode machiningMode,
    bool forceGuardActive,
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
    Object? lastMessage = freezed,
    Object? wcsOffsets = null,
    Object? limitSwitches = null,
    Object? probeTriggered = null,
    Object? probeResult = freezed,
    Object? emergencyTriggered = null,
    Object? machiningMode = null,
    Object? forceGuardActive = null,
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
        lastMessage: freezed == lastMessage
            ? _value.lastMessage
            : lastMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        wcsOffsets: null == wcsOffsets
            ? _value._wcsOffsets
            : wcsOffsets // ignore: cast_nullable_to_non_nullable
                  as Map<String, List<double>>,
        limitSwitches: null == limitSwitches
            ? _value._limitSwitches
            : limitSwitches // ignore: cast_nullable_to_non_nullable
                  as List<bool>,
        probeTriggered: null == probeTriggered
            ? _value.probeTriggered
            : probeTriggered // ignore: cast_nullable_to_non_nullable
                  as bool,
        probeResult: freezed == probeResult
            ? _value._probeResult
            : probeResult // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        emergencyTriggered: null == emergencyTriggered
            ? _value.emergencyTriggered
            : emergencyTriggered // ignore: cast_nullable_to_non_nullable
                  as bool,
        machiningMode: null == machiningMode
            ? _value.machiningMode
            : machiningMode // ignore: cast_nullable_to_non_nullable
                  as MachiningMode,
        forceGuardActive: null == forceGuardActive
            ? _value.forceGuardActive
            : forceGuardActive // ignore: cast_nullable_to_non_nullable
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
    this.lastMessage,
    final Map<String, List<double>> wcsOffsets = const {},
    final List<bool> limitSwitches = const [false, false, false, false, false],
    this.probeTriggered = false,
    final Map<String, dynamic>? probeResult,
    this.emergencyTriggered = false,
    this.machiningMode = MachiningMode.threeAxis,
    this.forceGuardActive = true,
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
       _wcsOffsets = wcsOffsets,
       _limitSwitches = limitSwitches,
       _probeResult = probeResult;

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
  @override
  final String? lastMessage;
  // Message GRBL [MSG:...]
  // --- Offsets WCS (G54..G59), lus via la réponse $# ---
  final Map<String, List<double>> _wcsOffsets;
  // Message GRBL [MSG:...]
  // --- Offsets WCS (G54..G59), lus via la réponse $# ---
  @override
  @JsonKey()
  Map<String, List<double>> get wcsOffsets {
    if (_wcsOffsets is EqualUnmodifiableMapView) return _wcsOffsets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_wcsOffsets);
  }

  final List<bool> _limitSwitches;
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
  final Map<String, dynamic>? _probeResult;
  @override
  Map<String, dynamic>? get probeResult {
    final value = _probeResult;
    if (value == null) return null;
    if (_probeResult is EqualUnmodifiableMapView) return _probeResult;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  // Résultat du dernier PRB
  @override
  @JsonKey()
  final bool emergencyTriggered;
  // --- Mode d'usinage (PFE §3.4) ---
  @override
  @JsonKey()
  final MachiningMode machiningMode;
  @override
  @JsonKey()
  final bool forceGuardActive;
  // Bridage ForceGuard actif
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
    return 'MachineState(status: $status, alarmCode: $alarmCode, mPos: $mPos, wPos: $wPos, wco: $wco, targetPos: $targetPos, singularityRisk: $singularityRisk, feedrate: $feedrate, spindleSpeed: $spindleSpeed, spindleLoad: $spindleLoad, coreTemp: $coreTemp, isRtcpActive: $isRtcpActive, overrides: $overrides, activeWCS: $activeWCS, activeToolNum: $activeToolNum, lastMessage: $lastMessage, wcsOffsets: $wcsOffsets, limitSwitches: $limitSwitches, probeTriggered: $probeTriggered, probeResult: $probeResult, emergencyTriggered: $emergencyTriggered, machiningMode: $machiningMode, forceGuardActive: $forceGuardActive, sdPercent: $sdPercent, sdFilename: $sdFilename, activeLineIndex: $activeLineIndex, plannerBuffer: $plannerBuffer, rxBuffer: $rxBuffer)';
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
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            const DeepCollectionEquality().equals(
              other._wcsOffsets,
              _wcsOffsets,
            ) &&
            const DeepCollectionEquality().equals(
              other._limitSwitches,
              _limitSwitches,
            ) &&
            (identical(other.probeTriggered, probeTriggered) ||
                other.probeTriggered == probeTriggered) &&
            const DeepCollectionEquality().equals(
              other._probeResult,
              _probeResult,
            ) &&
            (identical(other.emergencyTriggered, emergencyTriggered) ||
                other.emergencyTriggered == emergencyTriggered) &&
            (identical(other.machiningMode, machiningMode) ||
                other.machiningMode == machiningMode) &&
            (identical(other.forceGuardActive, forceGuardActive) ||
                other.forceGuardActive == forceGuardActive) &&
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
    lastMessage,
    const DeepCollectionEquality().hash(_wcsOffsets),
    const DeepCollectionEquality().hash(_limitSwitches),
    probeTriggered,
    const DeepCollectionEquality().hash(_probeResult),
    emergencyTriggered,
    machiningMode,
    forceGuardActive,
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
    final String? lastMessage,
    final Map<String, List<double>> wcsOffsets,
    final List<bool> limitSwitches,
    final bool probeTriggered,
    final Map<String, dynamic>? probeResult,
    final bool emergencyTriggered,
    final MachiningMode machiningMode,
    final bool forceGuardActive,
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
  String? get lastMessage; // Message GRBL [MSG:...]
  // --- Offsets WCS (G54..G59), lus via la réponse $# ---
  @override
  Map<String, List<double>> get wcsOffsets;
  @override
  List<bool> get limitSwitches;
  @override
  bool get probeTriggered;
  @override
  Map<String, dynamic>? get probeResult; // Résultat du dernier PRB
  @override
  bool get emergencyTriggered; // --- Mode d'usinage (PFE §3.4) ---
  @override
  MachiningMode get machiningMode;
  @override
  bool get forceGuardActive; // Bridage ForceGuard actif
  // --- Progression SD (FluidNC) ---
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
