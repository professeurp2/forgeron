// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MacroImpl _$$MacroImplFromJson(Map<String, dynamic> json) => _$MacroImpl(
  name: json['name'] as String,
  gcode: json['gcode'] as String,
  iconName: json['iconName'] as String,
  colorHex: json['colorHex'] as String? ?? '#2196F3',
);

Map<String, dynamic> _$$MacroImplToJson(_$MacroImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'gcode': instance.gcode,
      'iconName': instance.iconName,
      'colorHex': instance.colorHex,
    };
