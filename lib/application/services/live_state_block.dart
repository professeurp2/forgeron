import 'dart:convert';

/// Bloc « état actuel de la machine » ajouté au prompt système à CHAQUE tour.
///
/// **Pourquoi.** Mesuré par Forgeron-Bench sur le modèle local : quand
/// l'historique contient une lecture d'état plus ancienne, le modèle la
/// recopie au lieu de rappeler l'outil dans **10 essais sur 15** (réussite de
/// 33 %). Il annonce alors une position qui n'est plus la bonne — le danger
/// que la règle « jamais de données inventées » vise. Une consigne dans le
/// prompt n'y suffit pas (elle y figurait déjà).
///
/// **Principe.** Le prompt système est reconstruit à chaque appel au modèle :
/// y mettre l'état courant le rend frais *par construction*, sans compter sur
/// le bon vouloir du modèle. Hors ligne, le bloc dit qu'il n'y a AUCUNE
/// lecture — jamais des zéros présentés comme une position.
String liveStateBlock({
  required Map<String, dynamic>? state,
  required bool offline,
  required DateTime now,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hms = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';

  if (offline || state == null) {
    return '=== ÉTAT ACTUEL DE LA MACHINE ($hms) ===\n'
        'Machine HORS LIGNE : aucune lecture disponible. N\'annonce AUCUNE '
        'position ni aucun état de la machine.';
  }
  return '=== ÉTAT ACTUEL DE LA MACHINE (lu à $hms) ===\n'
      'C\'est la SEULE lecture à jour. Toute position ou tout état lu plus '
      'haut dans la discussion est PÉRIMÉ : pour répondre sur l\'état présent, '
      'sers-toi de ces valeurs ou rappelle get_machine_state.\n'
      '${jsonEncode(state)}';
}
