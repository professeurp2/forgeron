import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../core/utils/gcode_parser.dart';
import '../../core/utils/gcode_adapter.dart';
import '../../core/utils/gcode_tool_extractor.dart';
import '../../core/utils/kinematics_service.dart';
import 'machining_mode_provider.dart' show trunnionConfigProvider;

/// State pour la gestion de fichiers G-Code massifs.
/// Stocke les données brutes et expose une "fenêtre" pour l'UI.
class LargeGCodeState {
  final List<String> allLines;
  final List<List<double>> toolpath;
  final List<int> toolpathLineIndices;
  final Map<int, GCodeModalState> modalStates;
  final int currentLineIndex;
  final bool isLoading;

  /// Avertissements de l'adaptateur G-code (codes CAM traduits/retirés) et
  /// blocage éventuel (RTCP, compensation rayon machine, cycle non géré →
  /// à corriger dans le post avant exécution). Le G-code stocké est déjà adapté.
  final List<String> adaptWarnings;
  final bool adaptBlocking;

  /// Outils appelés par le programme, extraits du fichier **d'origine**.
  final List<ProgramTool> tools;

  LargeGCodeState({
    this.allLines = const [],
    this.toolpath = const [],
    this.toolpathLineIndices = const [],
    this.modalStates = const {},
    this.currentLineIndex = 0,
    this.isLoading = false,
    this.adaptWarnings = const [],
    this.adaptBlocking = false,
    this.tools = const [],
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
  ///
  /// Utilise une recherche dichotomique O(log N) car [toolpathLineIndices] est
  /// strictement croissant par construction (15 comparaisons au lieu de 30 000).
  int resolveToolpathIndex(int rawLineIndex) {
    if (toolpathLineIndices.isEmpty) return 0;
    int lo = 0;
    int hi = toolpathLineIndices.length - 1;
    int result = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >>> 1;
      if (toolpathLineIndices[mid] <= rawLineIndex) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  LargeGCodeState copyWith({
    List<String>? allLines,
    List<List<double>>? toolpath,
    List<int>? toolpathLineIndices,
    Map<int, GCodeModalState>? modalStates,
    int? currentLineIndex,
    bool? isLoading,
    List<String>? adaptWarnings,
    bool? adaptBlocking,
    List<ProgramTool>? tools,
  }) {
    return LargeGCodeState(
      allLines: allLines ?? this.allLines,
      toolpath: toolpath ?? this.toolpath,
      toolpathLineIndices: toolpathLineIndices ?? this.toolpathLineIndices,
      modalStates: modalStates ?? this.modalStates,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      isLoading: isLoading ?? this.isLoading,
      adaptWarnings: adaptWarnings ?? this.adaptWarnings,
      adaptBlocking: adaptBlocking ?? this.adaptBlocking,
      tools: tools ?? this.tools,
    );
  }
}

class _FullGCodePayload {
  final List<ProgramTool> tools;
  final GcodeAdaptResult adapt;
  final AnalyzedGCode analyzed;

  const _FullGCodePayload({
    required this.tools,
    required this.adapt,
    required this.analyzed,
  });
}

final RegExp _crlfSplit = RegExp(r'\r?\n');

_FullGCodePayload _processFullGCodeSync(String content) {
  final tools = GCodeToolExtractor.extract(content.split(_crlfSplit));
  final adapt = GcodeAdapter.adaptForFluidNC(content);
  final analyzed = GCodeParser.parseSync(adapt.gcode);
  return _FullGCodePayload(
    tools: tools,
    adapt: adapt,
    analyzed: analyzed,
  );
}

class GCodeNotifier extends StateNotifier<LargeGCodeState> {
  GCodeNotifier() : super(LargeGCodeState());

  /// Charge un fichier volumineux via un Isolate unifié pour ne jamais bloquer
  /// le thread UI (extraction d'outils + adaptation FluidNC + parsing 5 axes).
  Future<void> loadFile(String content) async {
    state = state.copyWith(isLoading: true);

    final payload = content.length > 4096
        ? await compute(_processFullGCodeSync, content)
        : _processFullGCodeSync(content);

    state = state.copyWith(
      allLines: payload.analyzed.lines,
      toolpath: payload.analyzed.toolpath,
      toolpathLineIndices: payload.analyzed.toolpathLineIndices,
      modalStates: payload.analyzed.modalStates,
      isLoading: false,
      currentLineIndex: 0,
      adaptWarnings: payload.adapt.warnings,
      adaptBlocking: payload.adapt.blocking,
      tools: payload.tools,
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

/// Toolpath préparé pour le RENDU 3D.
///
/// N'observe que `gcodeProvider.select((s) => s.toolpath)` pour éviter de
/// recalculer la cinématique directe sur 30 000 points à chaque changement de
/// `currentLineIndex`.
final renderToolpathProvider = Provider<List<List<double>>>((ref) {
  final raw = ref.watch(gcodeProvider.select((s) => s.toolpath));
  if (raw.isEmpty) return raw;

  final usesRotary = raw.any((p) => p[3] != 0.0 || p[4] != 0.0);
  if (!usesRotary) return raw;

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
  ref.watch(gcodeScrollControllerProvider);
});
