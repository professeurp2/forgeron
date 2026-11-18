/// D'où vient un programme G-code que l'agent veut lancer ?
///
/// La règle existe depuis longtemps dans le prompt — « tu n'écris JAMAIS
/// toi-même un programme G-code » — mais une règle de prompt est un souhait :
/// mesuré sur le modèle local, il a déjà écrit 33 lignes avec un cycle `G81`
/// aux paramètres incohérents (ARCHITECTURE.md §1). Ce module en fait une
/// règle : un programme n'est exécutable par l'agent que si chacune de ses
/// lignes de mouvement se retrouve, mot pour mot, dans ce que l'OPÉRATEUR a
/// écrit ou dans ce qu'un OUTIL a rendu (fichier lu, programme généré).
///
/// Volontairement strict et bête : aucune tolérance d'arrondi, aucune
/// « ressemblance ». Une ligne que personne d'autre que le modèle n'a écrite
/// est une ligne inventée.
abstract final class GcodeProvenance {
  static final _comment = RegExp(r'\(.*?\)|;.*$');
  static final _lineNumber = RegExp(r'^N\d+\s*');
  static final _axisWord = RegExp(r'[XYZABCIJKR]\s*[-+]?\d*\.?\d+');
  static final _space = RegExp(r'\s+');

  /// Forme canonique d'une ligne : sans commentaire, sans numéro de ligne,
  /// en majuscules, sans espace. `G1 X10 ; passe` et `n20 g1x10` sont la
  /// même ligne.
  static String normalize(String line) => line
      .replaceAll(_comment, '')
      .trim()
      .toUpperCase()
      .replaceFirst(_lineNumber, '')
      .replaceAll(_space, '');

  /// Une ligne « de mouvement » : elle porte au moins une cote. Ce sont les
  /// seules qui peuvent casser une fraise ; `M3 S1000`, `G21`, `G90` ou `M30`
  /// n'ont pas à être sourcées.
  static bool isMotion(String line) =>
      _axisWord.hasMatch(line.replaceAll(_comment, '').toUpperCase());

  /// Une suite de mots G-code sur une même ligne : `G1 X10 Y0 Z-1 F300`.
  /// Sert à retrouver un bloc au milieu d'autre chose — une phrase de
  /// l'opérateur (« explique-moi G1 X10 Y0 »), ou un résultat d'outil en JSON
  /// (`{"contenu":"G0 X5…"}`).
  static final _wordRun =
      RegExp(r'(?:[GMNTSFXYZABCIJKRPQLHD][ \t]*[-+]?(?:\d+\.?\d*|\.\d+)[ \t]*)+');

  /// Tous les blocs G-code présents dans [sources] (textes de l'opérateur,
  /// résultats d'outils), sous forme canonique. Un résultat d'outil est
  /// souvent du JSON : les `\n` échappés y sont dépliés avant découpage.
  static Set<String> index(Iterable<String> sources) {
    final out = <String>{};
    for (final s in sources) {
      final text = s.replaceAll(r'\n', '\n').replaceAll(r'\r', '');
      for (final raw in text.split('\n')) {
        final line = raw.replaceAll(_comment, '').toUpperCase();
        for (final m in _wordRun.allMatches(line)) {
          final n = normalize(m.group(0)!);
          if (n.isNotEmpty) out.add(n);
        }
      }
    }
    return out;
  }

  /// Lignes de mouvement de [program] introuvables dans [sources], avec leur
  /// numéro (à partir de 1). Liste vide = programme entièrement sourcé.
  static List<(int, String)> unsourced(String program, Iterable<String> sources) {
    final known = index(sources);
    final out = <(int, String)>[];
    final lines = program.replaceAll('\r', '').split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!isMotion(lines[i])) continue;
      if (!known.contains(normalize(lines[i]))) out.add((i + 1, lines[i].trim()));
    }
    return out;
  }

  /// Un texte de l'assistant contient-il un programme que personne d'autre
  /// n'a écrit ? [blocks] sont ses blocs de code G-code.
  static bool hasUnsourcedBlock(Iterable<String> blocks, Iterable<String> sources) {
    final known = index(sources);
    for (final b in blocks) {
      for (final line in b.split('\n')) {
        if (isMotion(line) && !known.contains(normalize(line))) return true;
      }
    }
    return false;
  }
}
