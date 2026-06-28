import 'package:freezed_annotation/freezed_annotation.dart';

part 'macro.freezed.dart';
part 'macro.g.dart';

@freezed
class Macro with _$Macro {
  const factory Macro({
    required String name,
    required String gcode,
    required String iconName,
    @Default('#2196F3') String colorHex,
  }) = _Macro;

  factory Macro.fromJson(Map<String, dynamic> json) => _$MacroFromJson(json);
}

final defaultMacros = [
  const Macro(
    name: 'PALPAGE CENTRE A',
    iconName: 'center_focus_strong',
    gcode: 'G91 G38.2 Z-20 F50\nG90 G10 L20 P1 Z0',
    colorHex: '#FF9800',
  ),
  const Macro(
    name: 'CHANGEMENT OUTIL',
    iconName: 'build',
    gcode: 'G53 G0 Z0\nG53 G0 X0 Y0\nM6 T1',
    colorHex: '#9C27B0',
  ),
  const Macro(
    name: 'NETTOYAGE PLATEAU',
    iconName: 'cleaning_services',
    gcode: 'G0 X100 Y100\nG1 X-100 F2000\nG0 X0 Y0',
    colorHex: '#4CAF50',
  ),
  const Macro(
    name: 'WARMUP BROCHE',
    iconName: 'timer',
    gcode: 'S5000 M3\nG4 P10\nS10000\nG4 P10\nS18000\nM5',
    colorHex: '#F44336',
  ),
  const Macro(
    name: 'EXECUTER G-CODE',
    iconName: 'play_circle_filled',
    gcode: 'EXEC_LOADED_GCODE',
    colorHex: '#2196F3',
  ),
];
