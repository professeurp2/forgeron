// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trunnion_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TrunnionConfigImpl _$$TrunnionConfigImplFromJson(Map<String, dynamic> json) =>
    _$TrunnionConfigImpl(
      aAxisMaxAngle: (json['aAxisMaxAngle'] as num?)?.toDouble() ?? 90.0,
      cAxisMaxAngle: (json['cAxisMaxAngle'] as num?)?.toDouble() ?? 360.0,
      gt2Pitch: (json['gt2Pitch'] as num?)?.toDouble() ?? 2.0,
      drivingPulleyTeeth: (json['drivingPulleyTeeth'] as num?)?.toInt() ?? 20,
      drivenPulleyTeeth: (json['drivenPulleyTeeth'] as num?)?.toInt() ?? 120,
      motorStepsPerRev: (json['motorStepsPerRev'] as num?)?.toInt() ?? 200,
      microstepping: (json['microstepping'] as num?)?.toInt() ?? 16,
      r5axForce: (json['r5axForce'] as num?)?.toDouble() ?? 30.0,
      rMaxForce: (json['rMaxForce'] as num?)?.toDouble() ?? 45.6,
      r3axForce: (json['r3axForce'] as num?)?.toDouble() ?? 180.0,
      pivotToTableOffset:
          (json['pivotToTableOffset'] as num?)?.toDouble() ?? 8.0,
      singularityZone: (json['singularityZone'] as num?)?.toDouble() ?? 5.0,
      aAxisMaxFeed: (json['aAxisMaxFeed'] as num?)?.toDouble() ?? 3600.0,
      cAxisMaxFeed: (json['cAxisMaxFeed'] as num?)?.toDouble() ?? 7200.0,
      travelX: (json['travelX'] as num?)?.toDouble() ?? 200.0,
      travelY: (json['travelY'] as num?)?.toDouble() ?? 300.0,
      travelZ: (json['travelZ'] as num?)?.toDouble() ?? 150.0,
    );

Map<String, dynamic> _$$TrunnionConfigImplToJson(
  _$TrunnionConfigImpl instance,
) => <String, dynamic>{
  'aAxisMaxAngle': instance.aAxisMaxAngle,
  'cAxisMaxAngle': instance.cAxisMaxAngle,
  'gt2Pitch': instance.gt2Pitch,
  'drivingPulleyTeeth': instance.drivingPulleyTeeth,
  'drivenPulleyTeeth': instance.drivenPulleyTeeth,
  'motorStepsPerRev': instance.motorStepsPerRev,
  'microstepping': instance.microstepping,
  'r5axForce': instance.r5axForce,
  'rMaxForce': instance.rMaxForce,
  'r3axForce': instance.r3axForce,
  'pivotToTableOffset': instance.pivotToTableOffset,
  'singularityZone': instance.singularityZone,
  'aAxisMaxFeed': instance.aAxisMaxFeed,
  'cAxisMaxFeed': instance.cAxisMaxFeed,
  'travelX': instance.travelX,
  'travelY': instance.travelY,
  'travelZ': instance.travelZ,
};
