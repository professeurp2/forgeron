// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machine_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MachineStateImpl _$$MachineStateImplFromJson(Map<String, dynamic> json) =>
    _$MachineStateImpl(
      status:
          $enumDecodeNullable(_$MachineStatusEnumMap, json['status']) ??
          MachineStatus.offline,
      alarmCode: (json['alarmCode'] as num?)?.toInt(),
      mPos:
          (json['mPos'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.0, 0.0, 0.0, 0.0, 0.0],
      wPos:
          (json['wPos'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.0, 0.0, 0.0, 0.0, 0.0],
      wco:
          (json['wco'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.0, 0.0, 0.0, 0.0, 0.0],
      targetPos:
          (json['targetPos'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.0, 0.0, 0.0, 0.0, 0.0],
      singularityRisk: (json['singularityRisk'] as num?)?.toDouble() ?? 0.0,
      feedrate: (json['feedrate'] as num?)?.toDouble() ?? 0.0,
      spindleSpeed: (json['spindleSpeed'] as num?)?.toDouble() ?? 0.0,
      spindleLoad: (json['spindleLoad'] as num?)?.toDouble() ?? 0.0,
      coreTemp: (json['coreTemp'] as num?)?.toDouble() ?? 40.0,
      isRtcpActive: json['isRtcpActive'] as bool? ?? false,
      overrides:
          (json['overrides'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [100, 100, 100],
      activeWCS: json['activeWCS'] as String? ?? 'G54',
      activeToolNum: (json['activeToolNum'] as num?)?.toInt() ?? 0,
      lastMessage: json['lastMessage'] as String?,
      limitSwitches:
          (json['limitSwitches'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          const [false, false, false, false, false],
      probeTriggered: json['probeTriggered'] as bool? ?? false,
      probeResult: json['probeResult'] as Map<String, dynamic>?,
      emergencyTriggered: json['emergencyTriggered'] as bool? ?? false,
      machiningMode:
          $enumDecodeNullable(_$MachiningModeEnumMap, json['machiningMode']) ??
          MachiningMode.threeAxis,
      forceGuardActive: json['forceGuardActive'] as bool? ?? true,
      sdPercent: (json['sdPercent'] as num?)?.toDouble() ?? 0.0,
      sdFilename: json['sdFilename'] as String?,
      activeLineIndex: (json['activeLineIndex'] as num?)?.toInt() ?? 0,
      plannerBuffer: (json['plannerBuffer'] as num?)?.toInt() ?? 15,
      rxBuffer: (json['rxBuffer'] as num?)?.toInt() ?? 128,
    );

Map<String, dynamic> _$$MachineStateImplToJson(_$MachineStateImpl instance) =>
    <String, dynamic>{
      'status': _$MachineStatusEnumMap[instance.status]!,
      'alarmCode': instance.alarmCode,
      'mPos': instance.mPos,
      'wPos': instance.wPos,
      'wco': instance.wco,
      'targetPos': instance.targetPos,
      'singularityRisk': instance.singularityRisk,
      'feedrate': instance.feedrate,
      'spindleSpeed': instance.spindleSpeed,
      'spindleLoad': instance.spindleLoad,
      'coreTemp': instance.coreTemp,
      'isRtcpActive': instance.isRtcpActive,
      'overrides': instance.overrides,
      'activeWCS': instance.activeWCS,
      'activeToolNum': instance.activeToolNum,
      'lastMessage': instance.lastMessage,
      'limitSwitches': instance.limitSwitches,
      'probeTriggered': instance.probeTriggered,
      'probeResult': instance.probeResult,
      'emergencyTriggered': instance.emergencyTriggered,
      'machiningMode': _$MachiningModeEnumMap[instance.machiningMode]!,
      'forceGuardActive': instance.forceGuardActive,
      'sdPercent': instance.sdPercent,
      'sdFilename': instance.sdFilename,
      'activeLineIndex': instance.activeLineIndex,
      'plannerBuffer': instance.plannerBuffer,
      'rxBuffer': instance.rxBuffer,
    };

const _$MachineStatusEnumMap = {
  MachineStatus.idle: 'idle',
  MachineStatus.run: 'run',
  MachineStatus.hold: 'hold',
  MachineStatus.alarm: 'alarm',
  MachineStatus.home: 'home',
  MachineStatus.check: 'check',
  MachineStatus.door: 'door',
  MachineStatus.sleep: 'sleep',
  MachineStatus.offline: 'offline',
};

const _$MachiningModeEnumMap = {
  MachiningMode.fiveAxis: 'fiveAxis',
  MachiningMode.threeAxis: 'threeAxis',
};
