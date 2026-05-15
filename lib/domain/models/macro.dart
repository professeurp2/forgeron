import 'package:flutter/material.dart';

class Macro {
  final String name;
  final String gcode;
  final IconData icon;
  final Color color;

  const Macro({
    required this.name,
    required this.gcode,
    required this.icon,
    this.color = Colors.blue,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gcode': gcode,
    'icon': icon.codePoint,
    'color': color.value,
  };

  factory Macro.fromJson(Map<String, dynamic> json) => Macro(
    name: json['name'],
    gcode: json['gcode'],
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    color: Color(json['color']),
  );
}

final defaultMacros = [
  const Macro(
    name: 'PALPAGE CENTRE A',
    icon: Icons.center_focus_strong,
    gcode: 'G91 G38.2 Z-20 F50\nG90 G10 L20 P1 Z0',
    color: Colors.orange,
  ),
  const Macro(
    name: 'CHANGEMENT OUTIL',
    icon: Icons.build,
    gcode: 'G53 G0 Z0\nG53 G0 X0 Y0\nM6 T1',
    color: Colors.purple,
  ),
  const Macro(
    name: 'NETTOYAGE PLATEAU',
    icon: Icons.cleaning_services,
    gcode: 'G0 X100 Y100\nG1 X-100 F2000\nG0 X0 Y0',
    color: Colors.green,
  ),
  const Macro(
    name: 'WARMUP BROCHE',
    icon: Icons.timer,
    gcode: 'S5000 M3\nG4 P10\nS10000\nG4 P10\nS18000\nM5',
    color: Colors.red,
  ),
  const Macro(
    name: 'LANCER LE DEMO',
    icon: Icons.play_circle_filled,
    gcode: 'MOCK_DEMO',
    color: Colors.blue,
  ),
];
