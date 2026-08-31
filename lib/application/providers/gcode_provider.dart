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
  final int currentLineIndex;
  final bool isLoading;

  /// Avertissements de l'adaptateur G-code (codes CAM traduits/retirés) et
  /// blocage éventuel (RTCP, compensation rayon machine, cycle non géré →
  /// à corriger dans le post avant exécution). Le G-code stocké est déjà adapté.
  final List<String> adaptWarnings;
  final bool adaptBlocking;

  /// Outils appelés par le programme, extraits du fichier **d'origine**.
  ///
  /// Calculés à l'ouverture et conservés, car [allLines] contient le G-code
  /// ADAPTÉ : l'adaptateur y a converti chaque `T.. M6` en pause `M0`, si bien
  /// que ni le mot `T` ni le `M6` n'y subsistent. Chercher les outils dans
  /// [allLines] ne trouve donc jamais rien.
  ///
  /// On stocke le résultat plutôt qu'une seconde copie du fichier : la liste
  /// est minuscule, le fichier peut peser plusieurs mégaoctets.
  final List<ProgramTool> tools;

  LargeGCodeState({
    this.allLines = const [],
    this.toolpath = const [],
    this.toolpathLineIndices = const [],
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
    List<String>? adaptWarnings,
    bool? adaptBlocking,
    List<ProgramTool>? tools,
  }) {
    return LargeGCodeState(
      allLines: allLines ?? this.allLines,
      toolpath: toolpath ?? this.toolpath,
      toolpathLineIndices: toolpathLineIndices ?? this.toolpathLineIndices,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      isLoading: isLoading ?? this.isLoading,
      adaptWarnings: adaptWarnings ?? this.adaptWarnings,
      adaptBlocking: adaptBlocking ?? this.adaptBlocking,
      tools: tools ?? this.tools,
    );
  }
}

class GCodeNotifier extends StateNotifier<LargeGCodeState> {
  GCodeNotifier() : super(LargeGCodeState());

  /// Charge un fichier volumineux via un Isolate pour ne pas bloquer l'UI.
  ///
  /// Le contenu passe d'abord par [GcodeAdapter] : les codes CAM incompatibles
  /// (cycles fixes, G43/H, M6, O/N…) sont traduits pour FluidNC. Le G-code
  /// STOCKÉ et exécuté est la version adaptée. Les avertissements et le flag de
  /// blocage sont exposés à l'UI/l'agent. Un G-code déjà propre traverse sans
  /// changement (adaptateur no-op).
  Future<void> loadFile(String content) async {
    state = state.copyWith(isLoading: true);

    // AVANT adaptation : c'est le fichier d'origine qui porte les `T.. M6` et
    // les commentaires descriptifs du post-processeur.
    // Découpage tolérant au CRLF : les sorties de post sous Windows en sont
    // pleines, et un `\r` traînant en fin de ligne fausserait les motifs.
    final tools =
        GCodeToolExtractor.extract(content.split(RegExp(r'\r?\n')));

    final adapt = GcodeAdapter.adaptForFluidNC(content);

    // Le parseur travaille sur le G-code ADAPTÉ (celui qui sera exécuté).
    final analyzed = await GCodeParser.parseLargeFile(adapt.gcode);

    state = state.copyWith(
      allLines: analyzed.lines,
      toolpath: analyzed.toolpath,
      toolpathLineIndices: analyzed.toolpathLineIndices,
      isLoading: false,
      currentLineIndex: 0,
      adaptWarnings: adapt.warnings,
      adaptBlocking: adapt.blocking,
      tools: tools,
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
/// Deux cas :
///  - **Programme SANS axes rotatifs** (A/C toujours nuls : 3 axes, gravure,
///    ébauche…) : les coordonnées sont déjà dans le repère pièce du CAM → on
///    les affiche TELLES QUELLES. Y appliquer la cinématique table-table
///    ajouterait un décalage parasite (offset table) → tracé décalé du modèle.
///  - **Programme AVEC inclinaison/rotation** (3+2 ou coords machine RTCP) : on
///    applique la cinématique directe pour retrouver la position réelle de la
///    pointe d'outil dans le repère pièce (sinon le tracé est faux dès qu'A/C
///    bougent).
final renderToolpathProvider = Provider<List<List<double>>>((ref) {
  final raw = ref.watch(gcodeProvider).toolpath;
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
  final controller = ref.watch(gcodeScrollControllerProvider);
  // On écoute l'index de ligne actuel depuis le machine state
  // et on déclenche un scroll doux.
});
