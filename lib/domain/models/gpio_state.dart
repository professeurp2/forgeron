import 'package:freezed_annotation/freezed_annotation.dart';

part 'gpio_state.freezed.dart';
part 'gpio_state.g.dart';

@freezed
class GpioState with _$GpioState {
  const factory GpioState({
    required int pin,
    required String label,
    @Default(false) bool isTriggered,
  }) = _GpioState;

  factory GpioState.fromJson(Map<String, dynamic> json) =>
      _$GpioStateFromJson(json);
}
