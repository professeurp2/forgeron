/// Traduction des codes d'alarme GRBL / FluidNC en cause et conduite à tenir.
///
/// L'application n'affichait que le numéro (« code 1 »), ce qui oblige
/// l'opérateur à aller chercher ailleurs ce que la machine vient de lui dire,
/// au moment précis où elle est verrouillée.
///
/// Ne sont catalogués que les codes **1 à 10**, ceux de GRBL 1.1 que FluidNC
/// reprend à l'identique. Au-delà, FluidNC ajoute des codes qui varient selon
/// la version du firmware : plutôt que d'en deviner le sens, un code inconnu
/// est affiché comme tel. Une cause d'alarme inventée enverrait l'opérateur
/// dans la mauvaise direction sur une machine déjà en défaut.
library;

class AlarmInfo {
  const AlarmInfo({
    required this.code,
    required this.title,
    required this.cause,
    required this.action,
    this.positionLost = false,
    this.unlockable = false,
  });

  final int code;

  /// Formulation courte, pour un bandeau.
  final String title;

  /// Ce qui s'est passé.
  final String cause;

  /// Ce que l'opérateur doit faire.
  final String action;

  /// La position machine n'est plus fiable : une prise d'origine est requise
  /// avant tout mouvement programmé. C'est l'information la plus importante —
  /// reprendre un usinage sur une position fausse casse la pièce ou l'outil.
  final bool positionLost;

  /// L'alarme peut être levée sans risque par un simple déverrouillage (`$X`).
  final bool unlockable;

  /// Code non répertorié : on annonce le numéro sans inventer de cause.
  factory AlarmInfo.unknown(int code) => AlarmInfo(
        code: code,
        title: 'Alarme $code',
        cause: 'Ce code n\'est pas répertorié dans l\'application. '
            'Il est propre à ta version de FluidNC.',
        action: 'Consulte la console pour le message complet du contrôleur '
            'avant de déverrouiller.',
      );
}

class GrblAlarmCatalog {
  static const _catalog = <int, AlarmInfo>{
    1: AlarmInfo(
      code: 1,
      title: 'Fin de course matérielle',
      cause: 'Un capteur de fin de course a été touché pendant un mouvement. '
          'La machine s\'est arrêtée net.',
      action: 'Dégage l\'axe concerné, puis refais une prise d\'origine.',
      positionLost: true,
    ),
    2: AlarmInfo(
      code: 2,
      title: 'Dépassement de course programmé',
      cause: 'Le G-code demandait un déplacement au-delà de la course '
          'déclarée de la machine. Le mouvement a été refusé avant d\'être '
          'exécuté.',
      action: 'La position reste valide. Déverrouille, puis corrige l\'origine '
          'pièce ou le programme — c\'est presque toujours un zéro pièce mal '
          'posé.',
      unlockable: true,
    ),
    3: AlarmInfo(
      code: 3,
      title: 'Réinitialisation en mouvement',
      cause: 'Un reset est survenu alors que la machine bougeait. Elle a été '
          'stoppée sans décélération.',
      action: 'Refais une prise d\'origine : la position réelle ne correspond '
          'plus à celle que le contrôleur croit avoir.',
      positionLost: true,
    ),
    4: AlarmInfo(
      code: 4,
      title: 'Palpeur — état initial inattendu',
      cause: 'Le palpeur était déjà en contact avant le début du cycle.',
      action: 'Vérifie le câblage du palpeur et qu\'il est bien dégagé, puis '
          'relance le cycle.',
      unlockable: true,
    ),
    5: AlarmInfo(
      code: 5,
      title: 'Palpeur — pas de contact',
      cause: 'Le palpeur n\'a rien touché sur toute la distance programmée.',
      action: 'Rapproche le palpeur de la pièce ou augmente la distance de '
          'recherche.',
      unlockable: true,
    ),
    6: AlarmInfo(
      code: 6,
      title: 'Prise d\'origine interrompue',
      cause: 'Un reset est survenu pendant le cycle de prise d\'origine.',
      action: 'Relance la prise d\'origine complète.',
      positionLost: true,
    ),
    7: AlarmInfo(
      code: 7,
      title: 'Prise d\'origine — porte ouverte',
      cause: 'La sécurité de porte s\'est déclenchée pendant la prise '
          'd\'origine.',
      action: 'Referme la porte et relance la prise d\'origine.',
      positionLost: true,
    ),
    8: AlarmInfo(
      code: 8,
      title: 'Prise d\'origine — dégagement impossible',
      cause: 'Après avoir touché le capteur, l\'axe n\'a pas réussi à s\'en '
          'dégager : le capteur reste actif.',
      action: 'Augmente la distance de dégagement (pull-off) dans la config, '
          'ou vérifie le capteur — un contact collé donne ce défaut.',
      positionLost: true,
    ),
    9: AlarmInfo(
      code: 9,
      title: 'Prise d\'origine — capteur introuvable',
      cause: 'L\'axe a parcouru toute la distance de recherche sans jamais '
          'trouver son capteur.',
      action: 'Vérifie le câblage et le sens de déplacement de l\'axe, ou '
          'augmente la course de recherche. Un axe qui part du mauvais côté '
          'donne exactement ce défaut.',
      positionLost: true,
    ),
    10: AlarmInfo(
      code: 10,
      title: 'Prise d\'origine — second capteur introuvable',
      cause: 'Sur un axe à double moteur, le second capteur n\'a pas été '
          'trouvé pour l\'équerrage.',
      action: 'Vérifie le câblage du second capteur de cet axe.',
      positionLost: true,
    ),
  };

  /// Retourne la fiche du code, ou une fiche « non répertorié » explicite.
  /// `null` seulement si aucun code n'a été rapporté.
  static AlarmInfo? lookup(int? code) {
    if (code == null) return null;
    return _catalog[code] ?? AlarmInfo.unknown(code);
  }

  /// Vrai si le code est connu de l'application.
  static bool isKnown(int? code) => code != null && _catalog.containsKey(code);
}
