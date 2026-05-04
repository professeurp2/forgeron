// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gpio_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GpioStateImpl _$$GpioStateImplFromJson(Map<String, dynamic> json) =>
    _$GpioStateImpl(
      pin: (json['pin'] as num).toInt(),
      label: json['label'] as String,
      isTriggered: json['isTriggered'] as bool? ?? false,
    );

Map<String, dynamic> _$$GpioStateImplToJson(_$GpioStateImpl instance) =>
    <String, dynamic>{
      'pin': instance.pin,
      'label': instance.label,
      'isTriggered': instance.isTriggered,
    };
