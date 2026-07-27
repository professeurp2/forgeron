import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../core/utils/gcode_parser.dart';
import '../../core/utils/kinematics_service.dart';
import 'machining_mode_provider.dart' show trunnionConfigProvider;

/// State pour la gestion de fichiers G-Code massifs.
/// Stocke les données brutes et expose une "fenêtre" pour l'UI.
class LargeGCodeState {
  final List<String> allLines;
  final List<List<double>> toolpath;
  final List<int> toolpathLineIndices;
  final int currentLineIndex;
  final bool isLoading;

  LargeGCodeState({
    this.allLines = const [],
    this.toolpath = const [],
    this.toolpathLineIndices = const [],
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

  /// Traduit un index de LIGNE BRUTE (ex: `MachineState.activeLineIndex`,
  /// utilisé par le streaming) en index dans [toolpath] — qui ne contient
  /// qu'un point par ligne de mouvement. Renvoie l'index du dernier point de
  /// mouvement à ou avant [rawLineIndex] (0 si aucun).
  int resolveToolpathIndex(int rawLineIndex) {
    if (toolpathLineIndices.isEmpty) return 0;
    int result = 0;
    for (int j = 0; j < toolpathLineIndices.length; j++) {
      if (toolpathLineIndices[j] <= rawLineIndex) {
        result = j;
      } else {
        break;
      }
    }
    return result;
  }

  LargeGCodeState copyWith({
    List<String>? allLines,
    List<List<double>>? toolpath,
    List<int>? toolpathLineIndices,
    int? currentLineIndex,
    bool? isLoading,
  }) {
    return LargeGCodeState(
      allLines: allLines ?? this.allLines,
      toolpath: toolpath ?? this.toolpath,
      toolpathLineIndices: toolpathLineIndices ?? this.toolpathLineIndices,
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
      toolpathLineIndices: analyzed.toolpathLineIndices,
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

/// Toolpath transformé par cinématique directe, pour le RENDU 3D uniquement.
///
/// [gcodeProvider.toolpath] contient les coordonnées MACHINE brutes (X,Y,Z
/// programmés) — nécessaires telles quelles à [TrajectoryValidator] et au
/// streaming. Le visualiseur, lui, doit afficher la position réelle de la
/// pointe d'outil dans le repère pièce, qui dépend de l'inclinaison/rotation
/// de la table (axes A/C) : sans cette transformation, le tracé 3D est faux
/// dès qu'un programme utilise les axes rotatifs.
final renderToolpathProvider = Provider<List<List<double>>>((ref) {
  final raw = ref.watch(gcodeProvider).toolpath;
  if (raw.isEmpty) return raw;

  final config = ref.watch(trunnionConfigProvider);
  final kinematics =
      KinematicsService(pivotToTableOffset: config.pivotToTableOffset);

  return [
    for (final p in raw)
      _transformPoint(kinematics, p),
  ];
});

List<double> _transformPoint(KinematicsService kinematics, List<double> p) {
  final tip = kinematics.forward(Vector3(p[0], p[1], p[2]), p[3], p[4]);
  return [tip.x, tip.y, tip.z, p[3], p[4], p[5]];
}

// --- PROVIDERS OPTIMISÉS ---

final analyzedGCodeProvider = StateProvider<AnalyzedGCode?>((ref) => null);

final gcodeScrollControllerProvider = Provider((ref) => ScrollController());

/// Provider pour synchroniser le scroll sans rebuild massif
final autoScrollProvider = Provider.autoDispose((ref) {
  final controller = ref.watch(gcodeScrollControllerProvider);
  // On écoute l'index de ligne actuel depuis le machine state
  // et on déclenche un scroll doux.
});
