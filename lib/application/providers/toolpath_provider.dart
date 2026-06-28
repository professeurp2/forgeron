import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToolpathNotifier extends StateNotifier<List<List<double>>> {
  ToolpathNotifier() : super([]);
  
  void addPoint(List<double> pos) {
    if (state.isEmpty || (state.last[0] - pos[0]).abs() > 0.5 || (state.last[1] - pos[1]).abs() > 0.5) {
      state = [...state, pos];
    }
  }
  
  void clear() => state = [];
}

final toolpathProvider = StateNotifierProvider<ToolpathNotifier, List<List<double>>>((ref) => ToolpathNotifier());
