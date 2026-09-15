/// Ce que la scène 3D doit montrer.
///
/// Le visualiseur sert désormais trois usages qui n'ont pas les mêmes besoins :
/// le simulateur de l'atelier (portique + brut + parcours), l'aperçu d'une
/// pièce STEP qu'on vient de charger (la pièce seule, sans machine autour), et
/// l'aperçu du parcours d'outil produit par le pipeline (le parcours, la pièce
/// en fond, pas de portique). Plutôt que de laisser chaque écran cacher des
/// morceaux après coup, chacun déclare la scène qu'il veut.
class ViewerScene {
  /// Le portique : bâti, axes, broche.
  final bool machine;

  /// Le tracé du programme (rouge = rapide, vert = travail).
  final bool toolpath;

  /// Le maillage de la pièce STEP chargée.
  final bool part;

  /// Le brut voxelisé qui se creuse au fil de l'usinage.
  final bool workpiece;

  /// Les boutons flottants de la page (reset / mode / plein écran).
  final bool controls;

  const ViewerScene({
    this.machine = true,
    this.toolpath = true,
    this.part = true,
    this.workpiece = true,
    this.controls = true,
  });

  /// Aperçu d'une pièce seule : rien d'autre à l'écran, la pièce remplit le
  /// cadre.
  static const ViewerScene partOnly = ViewerScene(
    machine: false,
    toolpath: false,
    workpiece: false,
  );

  /// Aperçu d'un parcours d'outil : le tracé SEUL.
  ///
  /// Ni portique, ni brut, ni pièce. Un parcours se lit à ses trajets et à ses
  /// niveaux — rapides en rouge, passes de travail en vert ; un solide posé
  /// dessous les masque exactement là où il faut les voir, puisque le parcours
  /// épouse la surface. La pièce a sa propre fenêtre pour ça.
  static const ViewerScene toolpathOnly = ViewerScene(
    machine: false,
    part: false,
    workpiece: false,
  );

  Map<String, dynamic> toJson() => {
        'machine': machine,
        'toolpath': toolpath,
        'part': part,
        'workpiece': workpiece,
        'controls': controls,
      };

  @override
  bool operator ==(Object other) =>
      other is ViewerScene &&
      other.machine == machine &&
      other.toolpath == toolpath &&
      other.part == part &&
      other.workpiece == workpiece &&
      other.controls == controls;

  @override
  int get hashCode => Object.hash(machine, toolpath, part, workpiece, controls);
}
