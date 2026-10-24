/// Reconnaissance déterministe d'un ordre d'arrêt d'urgence tapé ou dicté dans
/// le chat de l'agent.
///
/// **Pourquoi hors du modèle.** Un arrêt d'urgence qui transite par un
/// microcontrôleur n'en est pas un (voir `hardware/README.md`) ; il en va de
/// même d'un arrêt qui transite par un modèle de langage. Mesuré sur le modèle
/// local : « Arrête tout, c'est urgent ! » a rendu une réponse **vide** — ni
/// outil, ni texte. Devant une machine qui tourne, le chemin de sécurité ne
/// peut pas dépendre d'un tirage probabiliste, d'un serveur joignable ou d'une
/// langue bien comprise.
///
/// **Grammaire fermée, volontairement étroite.** Le message entier doit être
/// l'ordre — pas une question, pas une phrase qui contient le mot « arrêt ».
/// Se tromper dans un sens (arrêter à tort) coûte une pièce ; dans l'autre
/// (ne pas arrêter), pire. Mais arrêter dès qu'on lit « arrêt d'urgence » dans
/// une question (« pourquoi l'arrêt d'urgence… ? ») rendrait l'assistant
/// inutilisable : d'où le message **entier**, sans point d'interrogation, de
/// six mots au plus.
///
/// Français et anglais sont couverts et testés. Le swahili et l'amharique le
/// sont à titre indicatif : **relecture par un locuteur natif requise** avant
/// de s'y fier (voir `tool/eval/README.md`, statut `non_valide`).
library;

const _maxWords = 6;

final _accents = <String, String>{
  'à': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i',
  'ô': 'o', 'ö': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'œ': 'oe',
};

final _accentPattern = RegExp('[${_accents.keys.join()}]');
final _nonWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _spaces = RegExp(r'\s+');

/// Minuscules, sans accents latins, ponctuation et apostrophes remplacées par
/// des espaces. Les lettres non latines (amharique…) sont conservées.
String normalizeForIntent(String raw) {
  final lower = raw.toLowerCase().replaceAllMapped(
      _accentPattern, (m) => _accents[m.group(0)] ?? m.group(0)!);
  return lower.replaceAll(_nonWord, ' ').replaceAll(_spaces, ' ').trim();
}

// Mots qui peuvent précéder ou suivre l'ordre sans le changer.
const _fillerFr = r'(?:vite|svp|s il te plait|s il vous plait|maintenant|'
    r'immediatement|tout de suite|c est urgent|urgent|urgence)';

final List<RegExp> _orders = [
  // Français.
  RegExp('^(?:$_fillerFr\\s+)*(?:'
      'arret\\s+d\\s*urgence|arret\\s+urgence|'
      '(?:arrete|stoppe|stop)(?:\\s+(?:tout|la machine))?|'
      'au secours'
      ')(?:\\s+$_fillerFr)*\$'),
  RegExp(r'^urgence$'),
  // Anglais.
  RegExp(
      r'^(?:please\s+)?(?:'
      r'(?:emergency|e)\s*stop|estop|'
      r'(?:stop|halt)(?:\s+(?:everything|all|the machine))?|'
      r'kill\s+(?:it|everything)'
      r')(?:\s+(?:now|right now|immediately|please))*$'),
  // Swahili — à relire par un locuteur natif.
  RegExp(r'^simamisha(?:\s+kila\s+kitu)?(?:\s+sasa\s+hivi)?$'),
  // Amharique — à relire par un locuteur natif.
  RegExp(r'^(?:ሁሉንም\s+)?አቁም(?:\s+አሁኑኑ)?$'),
];

/// Vrai si [raw], pris en entier, est un ordre d'arrêt d'urgence.
bool isEmergencyStopRequest(String raw) {
  if (raw.contains('?') || raw.contains('？') || raw.contains('؟')) return false;
  final t = normalizeForIntent(raw);
  if (t.isEmpty || t.split(' ').length > _maxWords) return false;
  return _orders.any((p) => p.hasMatch(t));
}
