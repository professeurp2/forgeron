/// Traduction des codes d'alarme GRBL / FluidNC en cause et conduite à tenir.
///
/// L'application n'affichait que le numéro (« code 1 »), ce qui oblige
/// l'opérateur à aller chercher ailleurs ce que la machine vient de lui dire,
/// au moment précis où elle est verrouillée.
///
/// Codes tirés de l'énumération `ExecAlarm` de FluidNC (`FluidNC/src/Alarm.h`),
/// qui porte des valeurs numériques explicites — 0 à 18.
///
/// ⚠️ FluidNC **diverge de GRBL 1.1 à partir du code 10** : là où GRBL met
/// « échec d'équerrage sur axe double », FluidNC met `SpindleControl`. Se fier
/// aux tables GRBL qui circulent en ligne donne donc une cause fausse sur cette
/// machine — exactement le genre d'erreur qui envoie chercher au mauvais
/// endroit une machine déjà en défaut.
///
/// Un code hors énumération est affiché comme non répertorié plutôt que deviné.
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
    // ── À partir d'ici, la numérotation est propre à FluidNC ─────────────
    10: AlarmInfo(
      code: 10,
      title: 'Broche — défaut de commande',
      cause: 'Le contrôleur n\'a pas pu confirmer l\'état demandé de la broche.',
      action: 'Vérifie l\'alimentation et le câblage de la broche. Sur une '
          'commande par relais, vérifie que le module commute réellement — une '
          'alimentation trop faible donne ce défaut.',
      unlockable: true,
    ),
    11: AlarmInfo(
      code: 11,
      title: 'Entrée déjà active au démarrage',
      cause: 'Un capteur (fin de course, porte, arrêt) était déjà actif à la '
          'mise sous tension.',
      action: 'Dégage l\'axe posé sur son capteur avant de démarrer. Si aucun '
          'capteur n\'est touché, c\'est le câblage : un contact NF mal raccordé '
          'donne ce défaut en permanence.',
      unlockable: true,
    ),
    12: AlarmInfo(
      code: 12,
      title: 'Capteur ambigu pendant la prise d\'origine',
      cause: 'Plusieurs axes partagent un capteur et le contrôleur ne peut pas '
          'déterminer lequel est concerné.',
      action: 'Dégage les axes concernés, puis relance la prise d\'origine axe '
          'par axe.',
      positionLost: true,
    ),
    13: AlarmInfo(
      code: 13,
      title: 'Arrêt brutal',
      cause: 'Le mouvement a été interrompu net, sans décélération.',
      action: 'Refais une prise d\'origine avant tout usinage.',
      positionLost: true,
    ),
    14: AlarmInfo(
      code: 14,
      title: 'Origine machine non prise',
      cause: 'Un mouvement exigeant une position machine connue a été demandé '
          'avant toute prise d\'origine.',
      action: 'Lance la prise d\'origine.',
      positionLost: true,
    ),
    15: AlarmInfo(
      code: 15,
      title: 'Démarrage — prise d\'origine requise',
      cause: 'La machine démarre en alarme parce que la configuration exige une '
          'prise d\'origine. C\'est le comportement normal à la mise sous '
          'tension, pas un défaut.',
      action: 'Lance la prise d\'origine.',
      positionLost: true,
    ),
    16: AlarmInfo(
      code: 16,
      title: 'Expandeur d\'E/S réinitialisé',
      cause: 'Un circuit d\'extension d\'entrées/sorties a redémarré : l\'état de '
          'ses broches n\'est plus fiable.',
      action: 'Coupe et remets l\'alimentation. Si cela se répète, cherche un '
          'problème d\'alimentation ou des parasites sur le bus.',
    ),
    17: AlarmInfo(
      code: 17,
      title: 'Erreur G-code bloquante',
      cause: 'Une erreur dans le programme a mis la machine en alarme.',
      action: 'Lis la console : le contrôleur y a écrit l\'erreur exacte et la '
          'ligne fautive.',
      unlockable: true,
    ),
    18: AlarmInfo(
      code: 18,
      title: 'Fin de course pendant le palpage',
      cause: 'Un capteur de fin de course a été touché pendant un cycle de '
          'palpage.',
      action: 'Dégage l\'axe, puis refais une prise d\'origine avant de reprendre '
          'le palpage.',
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
