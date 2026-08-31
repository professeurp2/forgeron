import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/gcode_tool_extractor.dart';
import 'gcode_provider.dart';
import 'machine_provider.dart';

/// Outils réellement appelés par le programme chargé.
///
/// Seule source de vérité de l'écran outils : il n'existe pas de table d'outils
/// saisie à la main dans l'application. Programme non chargé = liste vide, et
/// l'écran doit le dire au lieu d'afficher un catalogue.
/// Les outils sont extraits a l'OUVERTURE du fichier, sur son contenu
/// d'origine, et conserves dans l'etat du programme.
///
/// Ils ne peuvent pas etre recalcules depuis `allLines` : celui-ci contient le
/// G-code ADAPTE, ou chaque `T.. M6` a ete remplace par une pause `M0`. Ni le
/// mot `T` ni le `M6` n'y subsistent.
final programToolsProvider =
    Provider<List<ProgramTool>>((ref) => ref.watch(gcodeProvider).tools);

/// Outil actuellement monté, d'après le contrôleur.
///
/// `activeToolNum` vient de FluidNC, qui l'a mis à jour en exécutant le `T.. M6`
/// du programme. C'est donc l'outil que la machine *croit* avoir — et pendant
/// une pause de changement, celui que l'opérateur doit installer.
///
/// `null` si le numéro annoncé n'apparaît pas dans le programme : mieux vaut
/// n'afficher aucune caractéristique qu'en afficher de fausses.
final activeProgramToolProvider = Provider<ProgramTool?>((ref) {
  final num = ref.watch(machineStateProvider).valueOrNull?.activeToolNum ?? 0;
  if (num <= 0) return null;

  for (final t in ref.watch(programToolsProvider)) {
    if (t.number == num) return t;
  }
  return null;
});

/// Numéro d'outil annoncé par le contrôleur, même quand le programme ne le
/// décrit pas. Sert à afficher « T7 — descriptif absent du programme ».
final activeToolNumberProvider = Provider<int>((ref) =>
    ref.watch(machineStateProvider).valueOrNull?.activeToolNum ?? 0);
