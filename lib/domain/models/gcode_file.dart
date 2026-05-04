import 'package:freezed_annotation/freezed_annotation.dart';

part 'gcode_file.freezed.dart';
part 'gcode_file.g.dart';

@freezed
class GCodeFile with _$GCodeFile {
  const factory GCodeFile({
    required String name,
    required int size,
    @Default(0) int lines,
    DateTime? lastModified,
  }) = _GCodeFile;

  factory GCodeFile.fromJson(Map<String, dynamic> json) =>
      _$GCodeFileFromJson(json);
}
