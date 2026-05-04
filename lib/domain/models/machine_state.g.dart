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
      feedrate: (json['feedrate'] as num?)?.toDouble() ?? 0.0,
      spindleSpeed: (json['spindleSpeed'] as num?)?.toDouble() ?? 0.0,
      overrides:
          (json['overrides'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [100, 100, 100],
      activeWCS: json['activeWCS'] as String? ?? 'G54',
      activeToolNum: (json['activeToolNum'] as num?)?.toInt() ?? 0,
      limitSwitches:
          (json['limitSwitches'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          const [false, false, false, false, false],
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
      'feedrate': instance.feedrate,
      'spindleSpeed': instance.spindleSpeed,
      'overrides': instance.overrides,
      'activeWCS': instance.activeWCS,
      'activeToolNum': instance.activeToolNum,
      'limitSwitches': instance.limitSwitches,
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
