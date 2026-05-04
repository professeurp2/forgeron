// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AlarmImpl _$$AlarmImplFromJson(Map<String, dynamic> json) => _$AlarmImpl(
  code: (json['code'] as num).toInt(),
  message: json['message'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  severity: json['severity'] as String? ?? 'error',
);

Map<String, dynamic> _$$AlarmImplToJson(_$AlarmImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'timestamp': instance.timestamp.toIso8601String(),
      'severity': instance.severity,
    };
