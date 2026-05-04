import 'package:freezed_annotation/freezed_annotation.dart';

part 'tool.freezed.dart';
part 'tool.g.dart';

@freezed
class Tool with _$Tool {
  const factory Tool({
    required int id,
    required String name,
    @Default(0.0) double diameter,
    @Default(0.0) double length,
    @Default(0.0) double noseRadius,
    @Default(0.0) double cuttingAngle,
    @Default(0.0) double life,
    @Default(0.0) double wear,
  }) = _Tool;

  factory Tool.fromJson(Map<String, dynamic> json) => _$ToolFromJson(json);
}
