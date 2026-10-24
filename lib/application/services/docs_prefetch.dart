import 'dart:convert';

import '../../core/utils/command_lexicon.dart' show foldWord;
import '../../core/utils/doc_search.dart';

/// Récupération AVANT la réponse : pour une question de connaissance,
/// l'application cherche elle-même dans les fiches et met le résultat dans le
/// prompt, au lieu d'espérer que le modèle pense à appeler `search_docs`.
///
/// **Pourquoi.** Mesuré (banc DOC, forgeron-qwen, 5 répétitions) : même avec une
/// consigne placée en fin de prompt, le modèle local n'appelait l'outil que 1 à 3
/// fois sur 5 sur certaines questions — et inventait alors une procédure
/// d'entretien en pilotant la broche. Un petit modèle suit mal « décide si tu dois
/// chercher » ; il suit bien « voici les fiches ». L'outil `search_docs` reste
/// disponible pour les questions de suivi.
///
/// L'ordre vient d'abord du lexique : seule une QUESTION arrive ici.
const _questionMarkers = [
  'comment', 'pourquoi', 'c est quoi', 'qu est ce', 'quel', 'quelle', 'quels',
  'a quoi sert', 'que signifie', 'ca veut dire', 'explique', 'expliquer',
  'difference', 'peut on', 'est ce que', 'what', 'why', 'how', 'which',
  'explain', 'does', 'meaning', 'alarme', 'alarm', 'code erreur',
];

/// Le message demande-t-il une information, plutôt qu'une action ?
bool looksLikeKnowledgeQuestion(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  if (t.contains('?') || t.contains('？')) return true;
  final folded = t
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .map(foldWord)
      .where((w) => w.isNotEmpty)
      .join(' ');
  return _questionMarkers.any((m) => ' $folded '.contains(' $m '));
}

/// Mots qui disent qu'une question porte sur la machine ou son atelier. Sans
/// fiche trouvée, seule une question de ce domaine reçoit le constat « aucune
/// fiche » : « comment vas-tu ? » n'a pas à se faire répondre qu'il manque une
/// fiche.
const _domainTerms = [
  'broche', 'spindle', 'axe', 'axis', 'alarme', 'alarm', 'gcode', 'g code',
  'm code', 'homing', 'home', 'fin de course', 'limit', 'carte', 'esp32',
  'tb6600', 'moteur', 'motor', 'vis', 'huile', 'entretien', 'maintenance',
  'procedure', 'cablage', 'relais', 'alimentation', 'fluidnc', 'grbl',
  'origine', 'wcs', 'palpeur', 'probe', 'arrosage', 'coolant', 'urgence',
  'reglage', 'setting', 'securite', 'outil', 'fraise', 'usinage',
];

bool _mentionsDomain(String text) {
  final folded = text
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .map(foldWord)
      .where((w) => w.isNotEmpty)
      .join(' ');
  return _domainTerms.any((t) => ' $folded '.contains(' $t '));
}

/// Le bloc dit-il « aucune fiche » ?
bool isNoFicheBlock(String? block) =>
    block != null && block.startsWith('=== AUCUNE FICHE');

const kNoFicheSentence = 'Je ne trouve pas cette information dans mes fiches.';

/// Après une recherche (fiches trouvées ou non), un refus du modèle reste un refus :
/// quand sa réponse commence par la phrase de refus et ne CITE aucune fiche du bloc,
/// elle est ramenée à cette phrase. Mesuré : le modèle écrit la phrase puis enchaîne
/// « Cependant… » avec une procédure tirée de sa mémoire (une huile de broche, en
/// pilotant la broche). Une réponse qui cite une fiche est gardée entière ; une
/// réponse qui ne commence pas par le refus est laissée telle quelle.
String enforceNoFicheReply(String text, {String? block}) {
  final t = text.trimLeft();
  if (!foldWord(t).startsWith(foldWord(kNoFicheSentence).substring(0, 33))) return text;
  for (final m in RegExp(r'^\[([a-z0-9-]+)\]', multiLine: true).allMatches(block ?? '')) {
    if (t.contains(m.group(1)!)) return text;
  }
  final end = t.indexOf('.');
  return end < 0 ? t : t.substring(0, end + 1);
}

/// Bloc à ajouter au prompt pour ce message, ou `null` si ce n'est pas une
/// question. Trois fiches au plus, extraits bornés : le contexte d'un modèle
/// local est fini.
String? docsBlock(String text, DocIndex index, {int topK = 3, int maxChars = 1600}) {
  if (!looksLikeKnowledgeQuestion(text)) return null;
  final hits = index.search(text, topK: topK);
  if (hits.isEmpty) {
    if (!_mentionsDomain(text)) return null;
    return '=== AUCUNE FICHE NE CORRESPOND À CETTE QUESTION ===\n'
        'Ta réponse tient en UNE phrase : « Je ne trouve pas cette information '
        'dans mes fiches. » (dans la langue de l\'opérateur). Ne la fais suivre '
        'd\'aucune explication, d\'aucun « cependant », d\'aucune procédure ni valeur '
        'de ta mémoire, et ne touche pas à la machine.';
  }
  final b = StringBuffer(
      '=== FICHES TROUVÉES POUR CETTE QUESTION ===\n'
      'Réponds UNIQUEMENT avec ce que disent ces fiches et termine par l\'identifiant '
      'de la fiche utilisée, entre parenthèses, par exemple (alarme-9). Si elles ne répondent pas à la '
      'question, dis « Je ne trouve pas cette information dans mes fiches. ». '
      'Une question n\'est pas un ordre : ne déclenche aucun outil qui agit sur '
      'la machine.\n');
  var budget = maxChars;
  for (final h in hits) {
    final c = h.chunk;
    var text = c.text;
    if (text.length > budget) {
      if (budget < 200) break;
      text = '${text.substring(0, budget)}…';
    }
    budget -= text.length;
    b.writeln('\n[${c.id}] ${c.title}\n$text\n(source : ${c.source})');
  }
  return b.toString().trimRight();
}

/// Résultat JSON de l'outil `search_docs` : le même texte pour l'application et pour
/// le banc, qui ne doit pas mesurer une copie.
String searchDocsResult(DocIndex index, String query) {
  final hits = index.search(query);
  if (hits.isEmpty) {
    return jsonEncode({
      'resultats': <Object>[],
      'note': 'Aucune fiche ne correspond. Dis que tu ne trouves pas cette '
          'information, en une phrase, sans rien ajouter ; n\'invente rien.',
    });
  }
  var budget = 1800; // le contexte d\'un modèle local est fini
  final results = <Map<String, Object>>[];
  for (final h in hits) {
    final text = h.chunk.text.length > 600 ? '${h.chunk.text.substring(0, 600)}…' : h.chunk.text;
    if (budget - text.length < 0 && results.isNotEmpty) break;
    budget -= text.length;
    results.add({
      'id': h.chunk.id,
      'titre': h.chunk.title,
      'source': h.chunk.source,
      'statut': h.chunk.status,
      'extrait': text,
    });
  }
  return jsonEncode({'resultats': results});
}
