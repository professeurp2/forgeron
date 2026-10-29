import '../../core/utils/emergency_intent.dart' show normalizeForIntent;

/// Choisit, pour un message, les outils à déclarer au modèle.
///
/// **Pourquoi.** Les 38 déclarations d'outils pèsent ~4 800 des ~6 800 tokens
/// fixes envoyés à CHAQUE tour (`ARCHITECTURE.md` §1). Pour un modèle de
/// 7 milliards de paramètres, c'est du bruit : plus lent à lire, et plus de
/// chances de se tromper d'outil. Pour « donne-moi l'état », il n'a besoin ni
/// du pipeline STEP ni de l'écriture de fichiers.
///
/// **Principe de prudence.** Le routeur ne peut que RETIRER des outils, jamais
/// en inventer, et dans le doute il n'en retire aucun :
///
/// - un noyau de sécurité est **toujours** présent (arrêt d'urgence, état,
///   pause, reprise, arrêt du programme) ;
/// - un message qui ne ressemble à rien de connu — « oui », « vas-y », une
///   langue non couverte — reçoit **tous** les outils ;
/// - les groupes utilisés au tour précédent restent présents (un « oui » qui
///   répond à une question sur la broche doit pouvoir allumer la broche).
///
/// Le gain est mesuré par Forgeron-Bench (`BENCH_ROUTING=1`) : adopté seulement
/// s'il ne dégrade ni la réussite ni la sécurité.
class ToolRouter {
  const ToolRouter();

  /// Toujours déclarés : de quoi arrêter, regarder, suspendre, reprendre.
  ///
  /// `set_app_language` s'y ajoute pour une raison différente des autres : son
  /// déclencheur est la LANGUE du message, pas un mot qu'il contient. Aucune
  /// liste de mots-clés ne peut l'attraper — un opérateur qui écrit en bambara
  /// n'écrit pas le mot « langue ». Le routeur laisse déjà passer tous les
  /// outils quand il ne reconnaît rien, mais un message en swahili contenant
  /// « sogeza » part dans le groupe « mouvement » et perdrait celui-ci.
  static const core = {
    'emergency_stop',
    'get_machine_state',
    'pause',
    'resume',
    'stop_program',
    'set_app_language',
  };

  static const groups = <String, ToolGroup>{
    'etat': ToolGroup(
      tools: {
        'get_machine_state', 'get_diagnostics', 'get_activity_log',
        'get_wcs_offsets', 'get_axis_kinematics', 'get_config', 'read_settings',
        'search_docs',
      },
      keywords: [
        'doc', 'documentation', 'fiche', 'c est quoi', 'comment', 'm3', 'm5', 'g38',
        'etat', 'statut', 'status', 'state', 'position', 'ou est', 'ou en',
        'alarme', 'alarm', 'temperature', 'diagnostic', 'journal', 'historique',
        'activity', 'log', 'offset', 'decalage', 'course', 'kinematic',
        'cinematique', 'config', 'reglage', 'setting', 'parametre', 'parameter',
        'pas par mm', 'steps', 'vitesse max', 'acceleration', 'combien',
        'quel', 'quelle', 'quels', 'what', 'where', 'how much', 'recemment',
        'recently', 'hali',
      ],
    ),
    'mouvement': ToolGroup(
      tools: {
        'jog_axis', 'goto_position', 'home', 'probe', 'set_work_zero',
        'select_wcs', 'set_wcs_offset', 'unlock_alarm', 'reset',
      },
      keywords: [
        'avance l', 'avance x', 'avance y', 'avance z', 'avance a', 'avance c',
        'recule', 'monte', 'descend', 'deplace', 'bouge', 'va en', 'va a',
        'aller', 'jog', 'move', 'home', 'homing', 'origine', 'zero', 'palpe',
        'probe', 'g54', 'g55', 'g56', 'g57', 'g58', 'g59', 'wcs',
        'systeme de coordonnees', 'coordinate', 'axe', 'axis', 'tourne',
        'rotate', 'degre', 'degree', 'millimetre', 'millimeter', 'deverrouille',
        'unlock', 'reset', 'rapide', 'rapid', 'sogeza', 'mhimili',
      ],
    ),
    'broche': ToolGroup(
      tools: {
        'set_spindle', 'set_coolant', 'set_spindle_override', 'set_feed_override',
      },
      keywords: [
        'broche', 'spindle', 'arrosage', 'coolant', 'refroidissement',
        'override', 'avance a', 'feed', 'vitesse', 'rpm', 'tours', 'm3', 'm4',
        'm5', 'm7', 'm8', 'm9', 'allume', 'eteins', 'demarre la', 'pour cent',
        'percent', '%',
      ],
    ),
    'programme': ToolGroup(
      tools: {
        'run_program', 'run_gcode_program', 'send_gcode', 'get_activity_log',
      },
      keywords: [
        'programme', 'program', 'lance', 'execute', 'run', 'cycle', 'g code',
        'gcode', 'commande', 'envoie', 'send', 'demarre le', 'start the',
      ],
    ),
    'fichiers': ToolGroup(
      tools: {
        'list_workspace_files', 'read_workspace_file', 'write_workspace_file',
        'analyze_gcode',
      },
      keywords: [
        'fichier', 'file', 'dossier', 'espace de travail', 'workspace', 'lis ',
        'lire', 'read', 'analyse', 'analyze', 'compatible', 'liste', 'list',
        ' nc', 'ngc', 'tap', 'sauvegarde', 'ecris', 'write', 'corrige',
      ],
    ),
    'cao': ToolGroup(
      tools: {
        'run_step_pipeline', 'preview_step_file', 'open_toolpath_window',
        'open_gcode_window', 'open_chart_window', 'show_popup',
        'list_workspace_files', 'analyze_gcode',
        'get_reco3d_status', 'start_machine_scan', 'get_scan_job_status',
        'download_scan_result',
        'run_machining_simulation', 'control_simulation',
      },
      keywords: [
        'step', 'stp', 'apercu', 'preview', '3d', 'parcours', 'toolpath',
        'genere', 'generer', 'generate', 'usinage', 'cao', 'cam', 'piece',
        'graphique', 'chart', 'courbe', 'fenetre', 'window',
      ],
    ),
    'simulation': ToolGroup(
      tools: {
        'run_machining_simulation',
        'control_simulation',
        'switch_simulator_camera_tab',
        'analyze_gcode',
      },
      keywords: [
        'simule', 'simuler', 'simulation', 'simulate', 'simulateur', 'simulator',
        'jumeau', 'digital twin', 'viewcube', 'isometric', 'isometrique',
        'brut', 'cuboid', 'cylindre', 'cylinder', 'collision', 'enlevement',
      ],
    ),
    'camera': ToolGroup(
      tools: {'get_camera_snapshot', 'switch_simulator_camera_tab'},
      keywords: [
        'camera', 'photo', 'image', 'zone de coupe', 'montre', 'vois', 'regarde',
        'snapshot', 'cutting area', 'show me',
      ],
    ),
    'scan': ToolGroup(
      tools: {
        'get_reco3d_status',
        'discover_reco3d_server',
        'start_machine_scan',
        'get_scan_job_status',
        'download_scan_result',
        'preview_step_file',
        'show_popup',
      },
      keywords: [
        'scan', 'scanner', 'scan3d', 'numériser', 'numeriser', 'numérisation',
        'numerisation', 'reco3d', 'reconstruction', 'maillage', 'mesh', 'stl',
        'photogrammétrie', 'photogrammetrie', 'meshroom', 'en machine',
        'caméra embarquée', 'camera embarquee', 'plateau rotatif', 'poses',
      ],
    ),
  };

  /// Nom du spécialiste de chaque groupe, montré à l'opérateur pendant qu'il
  /// travaille (console IA). `images` désigne le modèle d'images, qui n'est
  /// pas un groupe d'outils.
  static const labels = <String, String>{
    'etat': 'Surveillance',
    'mouvement': 'Mouvement',
    'broche': 'Broche',
    'programme': 'Programme',
    'fichiers': 'Fichiers',
    'cao': 'FAO',
    'camera': 'Caméra',
    'simulation': 'Simulation',
    'scan': 'Scan 3D',
    'images': 'Images',
  };

  /// Noms d'outils à déclarer pour [text].
  ///
  /// [allTools] : le catalogue complet (le résultat n'en sort jamais).
  /// [recentGroups] : groupes déjà sollicités au tour précédent.
  Routing route({
    required String text,
    required Iterable<String> allTools,
    Set<String> recentGroups = const {},
  }) {
    final all = allTools.toSet();
    final t = ' ${normalizeForIntent(text)} ';

    final matched = <String>{
      for (final e in groups.entries)
        if (e.value.keywords.any((k) => t.contains(_pad(k)))) e.key,
    };

    // Rien de reconnu : on n'ose rien retirer.
    if (matched.isEmpty && recentGroups.isEmpty) {
      return Routing(all, const {}, routed: false);
    }

    final active = {...matched, ...recentGroups};
    final selected = <String>{
      ...core,
      for (final g in active) ...?groups[g]?.tools,
    }.intersection(all);
    return Routing(selected, active, routed: true);
  }

  /// Un mot-clé court (« log », « m3 ») ne doit pas se trouver au milieu d'un
  /// autre mot : on le cherche entouré d'espaces, sauf s'il en contient déjà
  /// ou finit par un espace voulu.
  static String _pad(String k) {
    if (k.startsWith(' ') || k.endsWith(' ') || k.contains(' ')) return k;
    return ' $k';
  }
}

/// Un groupe d'outils et les mots qui l'appellent.
class ToolGroup {
  const ToolGroup({required this.tools, required this.keywords});
  final Set<String> tools;
  final List<String> keywords;
}

/// Résultat du routage.
class Routing {
  const Routing(this.tools, this.groups, {required this.routed});

  /// Outils à déclarer.
  final Set<String> tools;

  /// Groupes retenus (à repasser comme `recentGroups` au tour suivant).
  final Set<String> groups;

  /// Faux quand le routeur n'a rien reconnu et a laissé tous les outils.
  final bool routed;
}
