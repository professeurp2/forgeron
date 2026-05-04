// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gcode_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GCodeFileImpl _$$GCodeFileImplFromJson(Map<String, dynamic> json) =>
    _$GCodeFileImpl(
      name: json['name'] as String,
      size: (json['size'] as num).toInt(),
      lines: (json['lines'] as num?)?.toInt() ?? 0,
      lastModified: json['lastModified'] == null
          ? null
          : DateTime.parse(json['lastModified'] as String),
    );

Map<String, dynamic> _$$GCodeFileImplToJson(_$GCodeFileImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'size': instance.size,
      'lines': instance.lines,
      'lastModified': instance.lastModified?.toIso8601String(),
    };
