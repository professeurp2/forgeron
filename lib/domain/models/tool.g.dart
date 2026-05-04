// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ToolImpl _$$ToolImplFromJson(Map<String, dynamic> json) => _$ToolImpl(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  diameter: (json['diameter'] as num?)?.toDouble() ?? 0.0,
  length: (json['length'] as num?)?.toDouble() ?? 0.0,
  noseRadius: (json['noseRadius'] as num?)?.toDouble() ?? 0.0,
  cuttingAngle: (json['cuttingAngle'] as num?)?.toDouble() ?? 0.0,
  life: (json['life'] as num?)?.toDouble() ?? 0.0,
  wear: (json['wear'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$$ToolImplToJson(_$ToolImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'diameter': instance.diameter,
      'length': instance.length,
      'noseRadius': instance.noseRadius,
      'cuttingAngle': instance.cuttingAngle,
      'life': instance.life,
      'wear': instance.wear,
    };
