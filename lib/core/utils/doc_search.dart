/// Recherche dans les fiches de connaissance de l'assistant (outil `search_docs`).
///
/// **Pas d'embeddings.** Le corpus tient en quelques centaines de morceaux
/// courts, écrits dans une seule langue : une recherche par mots-clés (BM25) y
/// vaut les vecteurs, sans modèle de 100 Mo à embarquer, hors ligne, et avec un
/// classement qu'on peut expliquer (« la fiche contient ces mots »).
///
/// **Elle préfère se taire.** Aucun résultat sous un score minimal : une fiche à
/// peu près pertinente poussée dans le contexte d'un petit modèle est pire que
/// pas de fiche — il la recopie. L'appelant dit alors « je ne trouve pas ».
library;

import 'dart:math' as math;

import 'command_lexicon.dart' show foldWord;

/// Une fiche : l'unité de recherche ET de citation (`id`).
class DocChunk {
  const DocChunk({
    required this.id,
    required this.title,
    required this.text,
    required this.source,
    this.keywords = const [],
    this.status = 'brouillon',
  });

  final String id;
  final String title;
  final String text;

  /// D'où vient l'information (fichier, référence) — montré à l'opérateur.
  final String source;
  final List<String> keywords;

  /// `brouillon` ou `relu` (même vocabulaire que le lexique).
  final String status;

  factory DocChunk.fromJson(Map<String, dynamic> j) => DocChunk(
        id: '${j['id']}',
        title: '${j['titre'] ?? j['title']}',
        text: '${j['texte'] ?? j['text']}',
        source: '${j['source'] ?? ''}',
        keywords: [
          for (final k in (j['mots_cles'] ?? j['keywords'] ?? const []) as List) '$k',
        ],
        status: '${j['statut'] ?? j['status'] ?? 'brouillon'}',
      );
}

class DocHit {
  const DocHit(this.chunk, this.score);
  final DocChunk chunk;
  final double score;
}

/// Mots vides : français et anglais, plus les mots de question qui ne
/// départagent aucune fiche.
const _stop = {
  'le', 'la', 'les', 'l', 'un', 'une', 'des', 'du', 'de', 'd', 'et', 'ou', 'a',
  'au', 'aux', 'en', 'est', 'sont', 'ce', 'cet', 'cette', 'ces', 'que', 'qu',
  'qui', 'quoi', 'pour', 'par', 'sur', 'dans', 'avec', 'sans', 'il', 'elle',
  'je', 'tu', 'on', 'me', 'te', 'se', 'ne', 'pas', 'plus', 'mon', 'ma', 'mes',
  'ton', 'ta', 'tes', 'son', 'sa', 'ses', 'y', 'c', 's', 'n', 'm', 't',
  'comment', 'pourquoi', 'quel', 'quelle', 'quels', 'quelles', 'faire',
  'peut', 'peux', 'dois', 'faut', 'the', 'is', 'are', 'of', 'to', 'and', 'in',
  'what', 'how', 'why', 'do', 'does', 'it', 'for', 'with',
};

final _tokenRe = RegExp(r'[\$]?[\p{L}\p{N}]+(?:\.[\p{N}]+)?', unicode: true);

/// Mots d'un texte : minuscules, lettres accentuées ou africaines pliées, pluriels
/// retirés. Les codes (`m3`, `$x`, `g38.2`, `130`) sont gardés entiers.
List<String> docTokens(String text) {
  final out = <String>[];
  for (final m in _tokenRe.allMatches(text)) {
    final w = foldWord(m.group(0)!);
    if (w.isEmpty || _stop.contains(w)) continue;
    out.add(_stem(w));
  }
  return out;
}

/// Racinisation minimale : pluriels et féminins courants, rien de plus. Un
/// racineur agressif rapprocherait des mots qui ne veulent pas dire la même chose.
String _stem(String w) {
  if (w.length <= 3 || w.startsWith(r'$') || RegExp(r'\d').hasMatch(w)) return w;
  if (w.endsWith('aux') && w.length > 5) return '${w.substring(0, w.length - 3)}al';
  if (w.endsWith('es') && w.length > 5) return w.substring(0, w.length - 2);
  if (w.endsWith('s') || w.endsWith('x') || w.endsWith('e')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

/// Index BM25 en mémoire.
class DocIndex {
  DocIndex(this.chunks, {this.k1 = 1.4, this.b = 0.6}) {
    var total = 0;
    for (final c in chunks) {
      // Le titre et les mots-clés comptent trois fois : ils disent de quoi parle
      // la fiche, le corps dit ce qu'elle en dit.
      final tokens = [
        ...docTokens(c.title),
        ...docTokens(c.title),
        ...docTokens(c.title),
        for (final k in c.keywords) ...[...docTokens(k), ...docTokens(k)],
        ...docTokens(c.text),
      ];
      _docs.add(tokens);
      total += tokens.length;
      for (final t in tokens.toSet()) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _avg = chunks.isEmpty ? 1 : total / chunks.length;
  }

  final List<DocChunk> chunks;
  final double k1;
  final double b;
  final List<List<String>> _docs = [];
  final Map<String, int> _df = {};
  double _avg = 1;

  /// Score minimal d'une réponse. Mesuré sur le corpus livré (voir les tests) :
  /// sous ce seuil, ce sont des fiches qui partagent un seul mot courant.
  static const minScore = 1.2;

  List<DocHit> search(String query, {int topK = 3}) {
    final terms = docTokens(query);
    if (terms.isEmpty || chunks.isEmpty) return const [];
    final n = chunks.length;
    final hits = <DocHit>[];
    for (var i = 0; i < n; i++) {
      final doc = _docs[i];
      final tf = <String, int>{};
      for (final t in doc) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      var score = 0.0;
      var matched = 0;
      for (final t in terms.toSet()) {
        final f = tf[t];
        if (f == null) continue;
        matched++;
        final df = _df[t] ?? 0;
        final idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
        score += idf * (f * (k1 + 1)) / (f + k1 * (1 - b + b * doc.length / _avg));
      }
      // Deux mots de la question au moins, sauf question d'un seul mot.
      if (matched == 0 || (terms.toSet().length > 1 && matched < 2 && score < minScore * 1.5)) {
        continue;
      }
      if (score >= minScore) hits.add(DocHit(chunks[i], score));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(topK).toList();
  }
}
