import 'package:freezed_annotation/freezed_annotation.dart';

part 'wcs.freezed.dart';
part 'wcs.g.dart';

@freezed
class WorkCoordinateSystem with _$WorkCoordinateSystem {
  const factory WorkCoordinateSystem({
    required String label,
    @Default([0.0, 0.0, 0.0, 0.0, 0.0]) List<double> offsets,
  }) = _WorkCoordinateSystem;

  factory WorkCoordinateSystem.fromJson(Map<String, dynamic> json) =>
      _$WorkCoordinateSystemFromJson(json);
}
