// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wcs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkCoordinateSystemImpl _$$WorkCoordinateSystemImplFromJson(
  Map<String, dynamic> json,
) => _$WorkCoordinateSystemImpl(
  label: json['label'] as String,
  offsets:
      (json['offsets'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
      const [0.0, 0.0, 0.0, 0.0, 0.0],
);

Map<String, dynamic> _$$WorkCoordinateSystemImplToJson(
  _$WorkCoordinateSystemImpl instance,
) => <String, dynamic>{'label': instance.label, 'offsets': instance.offsets};
