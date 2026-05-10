import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/gcode_parser.dart';

/// State pour la gestion de fichiers G-Code massifs.
/// Stocke les données brutes et expose une "fenêtre" pour l'UI.
class LargeGCodeState {
  final List<String> allLines;
  final List<List<double>> toolpath;
  final int currentLineIndex;
  final bool isLoading;

  LargeGCodeState({
    this.allLines = const [],
    this.toolpath = const [],
    this.currentLineIndex = 0,
    this.isLoading = false,
  });

  /// Retourne une fenêtre de lignes autour de l'index actuel (ex: ±50 lignes)
  List<String> get windowLines {
    if (allLines.isEmpty) return [];
    final start = (currentLineIndex - 50).clamp(0, allLines.length);
    final end = (currentLineIndex + 50).clamp(0, allLines.length);
    return allLines.sublist(start, end);
  }

  LargeGCodeState copyWith({
    List<String>? allLines,
    List<List<double>>? toolpath,
    int? currentLineIndex,
    bool? isLoading,
  }) {
    return LargeGCodeState(
      allLines: allLines ?? this.allLines,
      toolpath: toolpath ?? this.toolpath,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GCodeNotifier extends StateNotifier<LargeGCodeState> {
  GCodeNotifier() : super(LargeGCodeState());

  /// Charge un fichier volumineux via un Isolate pour ne pas bloquer l'UI
  Future<void> loadFile(String content) async {
    state = state.copyWith(isLoading: true);
    
    // Appel du parseur optimisé (Isolate)
    final analyzed = await GCodeParser.parseLargeFile(content);
    
    state = state.copyWith(
      allLines: analyzed.lines,
      toolpath: analyzed.toolpath,
      isLoading: false,
      currentLineIndex: 0,
    );
  }

  void updateCurrentLine(int index) {
    if (index != state.currentLineIndex) {
      state = state.copyWith(currentLineIndex: index);
    }
  }
}

final gcodeProvider = StateNotifierProvider<GCodeNotifier, LargeGCodeState>((ref) {
  return GCodeNotifier();
});

/// Provider dédié à la fenêtre de visualisation (pour éviter les rebuilds massifs)
final gcodeWindowProvider = Provider((ref) {
  return ref.watch(gcodeProvider).windowLines;
});
