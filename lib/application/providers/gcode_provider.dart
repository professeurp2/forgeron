import 'package:flutter_riverpod/flutter_riverpod.dart';

class GCodeLine {
  final int number;
  final String content;
  final bool isCurrent;

  const GCodeLine({required this.number, required this.content, this.isCurrent = false});
}

final activeGCodeProvider = StateProvider<List<GCodeLine>>((ref) => [
  const GCodeLine(number: 1, content: 'G90 G21 G17'),
  const GCodeLine(number: 2, content: 'G54'),
  const GCodeLine(number: 3, content: 'M3 S12000'),
  const GCodeLine(number: 4, content: 'G0 X10 Y20 Z5', isCurrent: true),
  const GCodeLine(number: 5, content: 'G1 Z-1 F200'),
  const GCodeLine(number: 6, content: 'G1 X50 Y20 F800'),
  const GCodeLine(number: 7, content: 'G1 X50 Y50'),
  const GCodeLine(number: 8, content: 'G1 X10 Y50'),
  const GCodeLine(number: 9, content: 'G1 X10 Y20'),
  const GCodeLine(number: 10, content: 'G0 Z10'),
  const GCodeLine(number: 11, content: 'M5'),
  const GCodeLine(number: 12, content: 'M30'),
]);

final currentGCodeLineIndexProvider = StateProvider<int>((ref) => 3); // Index 0-based
