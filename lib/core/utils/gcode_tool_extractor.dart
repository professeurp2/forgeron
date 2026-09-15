/// Extraction des outils réellement utilisés par le programme chargé.
///
/// Rien n'est inventé ici : tout provient du G-code. Le fichier porte toujours
/// le **numéro** d'outil (`T3 M6`), et les post-processeurs y ajoutent en
/// général un commentaire descriptif juste avant le changement. Celui de
/// SolidWorks CAM produit par exemple :
///
/// ```
///   N3 ( Fraisage d'ébauche1 )     <- opération
///   N4 (6MM CRB 2FL 19 LOC)        <- descriptif outil
///   N5 T01 M06                     <- le changement
///   N6 S12000 M03                  <- la vitesse associée
/// ```
///
/// Quand le commentaire est absent, l'outil est retourné avec son seul numéro
/// et [description] à `null`. L'UI doit alors afficher « descriptif absent du
/// programme » — jamais une caractéristique par défaut : sur une machine, une
/// donnée d'outil inventée est pire qu'une donnée manquante.
library;

/// Forme de l'outil, déduite du descriptif. Sert à choisir la photo.
enum ToolShape {
  flatEndMill('assets/images/tools/flat_endmill.png', 'Fraise deux tailles'),
  ballNose('assets/images/tools/ball_nose_endmill.png', 'Fraise hémisphérique'),
  drill('assets/images/tools/drill.png', 'Foret'),
  vBit('assets/images/tools/v_bit.png', 'Graveur V'),
  unknown('assets/images/tools/flat_endmill.png', 'Type indéterminé');

  const ToolShape(this.asset, this.label);

  final String asset;
  final String label;
}

/// Un outil appelé par le programme.
class ProgramTool {
  const ProgramTool({
    required this.number,
    required this.changeLines,
    this.description,
    this.operation,
    this.diameterMm,
    this.flutes,
    this.cuttingLengthMm,
    this.material,
    this.spindleSpeed,
    this.shape = ToolShape.unknown,
  });

  /// Numéro d'outil (`T01` -> 1). Toujours connu : c'est la seule donnée que
  /// le G-code garantit.
  final int number;

  /// Index (base 0) des lignes où cet outil est appelé. Un même outil peut
  /// revenir plusieurs fois dans un programme.
  final List<int> changeLines;

  /// Commentaire descriptif brut, tel qu'écrit par le post. `null` si absent.
  final String? description;

  /// Nom de l'opération qui suit (ex. « Fraisage d'ébauche1 »).
  final String? operation;

  final double? diameterMm;
  final int? flutes;

  /// Longueur de coupe (LOC — *length of cut*), en mm.
  final double? cuttingLengthMm;

  /// Matière de l'outil telle qu'annoncée (carbure, HSS…).
  final String? material;

  /// Vitesse de broche demandée après le changement (mot `S`).
  ///
  /// ⚠️ À afficher comme une **demande du programme**, pas comme une vitesse
  /// réelle : sur une broche pilotée en tout-ou-rien, ce nombre est ignoré par
  /// le contrôleur.
  final int? spindleSpeed;

  final ToolShape shape;

  /// Vrai si le programme n'a livré que le numéro.
  bool get isBare => description == null && diameterMm == null;

  /// Première ligne où l'outil est appelé.
  int get firstChangeLine => changeLines.isEmpty ? -1 : changeLines.first;
}

/// Analyse un programme et retourne les outils qu'il utilise, dans l'ordre de
/// première apparition.
class GCodeToolExtractor {
  /// Nombre de lignes de commentaire remontées avant un `T.. M6` pour y
  /// chercher le descriptif. Les posts intercalent parfois une ligne de
  /// numérotation ou un commentaire d'opération.
  static const _lookBack = 6;

  /// Nombre de lignes descendues après un `T.. M6` pour trouver le mot `S`.
  static const _lookAhead = 6;

  static List<ProgramTool> extract(List<String> lines) {
    final found = <int, _Accumulator>{};

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final code = _stripComments(raw);

      // Un changement d'outil, c'est un mot T ET un M6 sur la même ligne, ou un
      // T seul suivi de près par un M6. On exige le M6 : un `T` sans changement
      // (pré-sélection sur certaines machines) ne doit pas créer d'entrée.
      final toolNum = _toolNumber(code);
      if (toolNum == null) continue;
      if (!_hasToolChange(code) && !_hasToolChangeNear(lines, i)) continue;

      final acc = found.putIfAbsent(toolNum, () => _Accumulator(toolNum));
      acc.changeLines.add(i);

      // Le descriptif est cherché une seule fois : les rappels ultérieurs du
      // même outil ne réécrivent pas ce qu'on a trouvé au premier passage.
      if (!acc.described) {
        final comments = _commentsBefore(lines, i);
        if (comments.isNotEmpty) {
          // Le commentaire le PLUS PROCHE du changement est le descriptif
          // outil ; celui d'avant, quand il existe, nomme l'opération.
          acc.description = comments.last;
          if (comments.length >= 2) acc.operation = comments[comments.length - 2];
          acc.described = true;
        }
      }

      acc.spindleSpeed ??= _spindleAfter(lines, i);
    }

    final tools = found.values.map((a) => a.build()).toList()
      ..sort((a, b) => a.firstChangeLine.compareTo(b.firstChangeLine));

    // Certains programmes ne décrivent pas l'outil à côté du changement mais
    // dans l'en-tête du fichier : `(TOOL: BALL END MILL 6MM)`. On n'y recourt
    // que pour un programme mono-outil : au-delà, rien ne permet de dire à quel
    // outil se rapporte l'en-tête, et attribuer au hasard serait pire que de
    // laisser l'outil nu.
    if (tools.length == 1 && tools.first.isBare) {
      final header = _headerToolComment(lines);
      if (header != null) {
        return [_describe(tools.first, header)];
      }
    }
    return tools;
  }

  /// Cherche dans l'en-tête un commentaire se rapportant explicitement à
  /// l'outil (`TOOL:` / `OUTIL:`). Un titre ou un nom de machine ne compte pas.
  static String? _headerToolComment(List<String> lines) {
    final limit = lines.length < 40 ? lines.length : 40;
    for (var i = 0; i < limit; i++) {
      for (final c in _commentsIn(lines[i])) {
        final m = RegExp(r'^(?:TOOL|OUTIL)\s*:\s*(.+)$', caseSensitive: false)
            .firstMatch(c.trim());
        if (m != null) return m.group(1)!.trim();
      }
    }
    return null;
  }

  static ProgramTool _describe(ProgramTool t, String description) => ProgramTool(
        number: t.number,
        changeLines: t.changeLines,
        description: description,
        operation: t.operation,
        diameterMm: ToolDescriptionParser.diameter(description),
        flutes: ToolDescriptionParser.flutes(description),
        cuttingLengthMm: ToolDescriptionParser.cuttingLength(description),
        material: ToolDescriptionParser.material(description),
        spindleSpeed: t.spindleSpeed,
        shape: ToolDescriptionParser.shape(description),
      );

  // ── Découpage ──────────────────────────────────────────────────────────────

  /// Retire les commentaires pour ne laisser que du code exécutable.
  ///
  /// Indispensable avant de chercher un mot `T` : un commentaire du genre
  /// « ( TERMINER LA PASSE ) » contient un T qui serait pris pour un outil.
  static String _stripComments(String line) {
    final withoutParens = line.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final semi = withoutParens.indexOf(';');
    final code = semi >= 0 ? withoutParens.substring(0, semi) : withoutParens;
    return code.toUpperCase();
  }

  /// Contenu des commentaires d'une ligne, nettoyé.
  static List<String> _commentsIn(String line) {
    final out = <String>[];
    for (final m in RegExp(r'\(([^)]*)\)').allMatches(line)) {
      final text = m.group(1)!.trim();
      if (text.isNotEmpty) out.add(text);
    }
    final semi = line.indexOf(';');
    if (semi >= 0) {
      final text = line.substring(semi + 1).trim();
      if (text.isNotEmpty) out.add(text);
    }
    return out;
  }

  static int? _toolNumber(String code) {
    // `T01`, `T1`. Précédé d'un début de ligne ou d'un séparateur, pour ne pas
    // attraper le T d'un autre mot.
    final m = RegExp(r'(?:^|[^A-Z0-9])T0*(\d+)').firstMatch(code);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static bool _hasToolChange(String code) =>
      RegExp(r'(?:^|[^A-Z0-9])M0*6(?:[^0-9]|$)').hasMatch(code);

  /// Certains posts écrivent le `T` et le `M6` sur deux lignes consécutives.
  static bool _hasToolChangeNear(List<String> lines, int i) {
    for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
      final code = _stripComments(lines[j]);
      if (_toolNumber(code) != null) return false; // autre outil : on s'arrête
      if (_hasToolChange(code)) return true;
    }
    return false;
  }

  /// Commentaires des lignes précédant immédiatement le changement d'outil.
  static List<String> _commentsBefore(List<String> lines, int i) {
    final out = <String>[];
    // La ligne du changement elle-même peut porter le descriptif.
    out.addAll(_commentsIn(lines[i]));

    for (var j = i - 1; j >= 0 && j >= i - _lookBack; j--) {
      final comments = _commentsIn(lines[j]);
      final code = _stripComments(lines[j]).trim();

      if (comments.isEmpty) {
        // Ligne de code réelle : on a quitté l'en-tête du bloc, inutile de
        // remonter plus haut. Une ligne vide ou une simple numérotation (N12)
        // ne compte pas comme telle.
        if (code.isNotEmpty && !RegExp(r'^N\d+$').hasMatch(code)) break;
        continue;
      }
      out.insertAll(0, comments);
    }
    return out;
  }

  static int? _spindleAfter(List<String> lines, int i) {
    for (var j = i; j < lines.length && j <= i + _lookAhead; j++) {
      final code = _stripComments(lines[j]);
      final m = RegExp(r'(?:^|[^A-Z0-9])S(\d+)').firstMatch(code);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    return null;
  }
}

/// Accumule ce qu'on apprend d'un outil au fil du programme.
class _Accumulator {
  _Accumulator(this.number);

  final int number;
  final List<int> changeLines = [];
  String? description;
  String? operation;
  int? spindleSpeed;
  bool described = false;

  ProgramTool build() {
    final d = description;
    return ProgramTool(
      number: number,
      changeLines: List.unmodifiable(changeLines),
      description: d,
      operation: operation,
      diameterMm: d == null ? null : ToolDescriptionParser.diameter(d),
      flutes: d == null ? null : ToolDescriptionParser.flutes(d),
      cuttingLengthMm: d == null ? null : ToolDescriptionParser.cuttingLength(d),
      material: d == null ? null : ToolDescriptionParser.material(d),
      spindleSpeed: spindleSpeed,
      shape: d == null ? ToolShape.unknown : ToolDescriptionParser.shape(d),
    );
  }
}

/// Lecture des caractéristiques dans un descriptif de post-processeur.
///
/// Chaque extraction retourne `null` quand elle ne trouve pas : aucune valeur
/// par défaut n'est fabriquée.
class ToolDescriptionParser {
  /// Ø en mm. Reconnaît `6MM`, `D=6.`, `Ø6`, `DIA 6`.
  static double? diameter(String description) {
    final s = description.toUpperCase().replaceAll(',', '.');
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*MM\b'),
      RegExp(r'\bD\s*=\s*(\d+(?:\.\d+)?)'),
      RegExp(r'[ØO]\s*(\d+(?:\.\d+)?)'),
      RegExp(r'\bDIA\.?\s*(\d+(?:\.\d+)?)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(s);
      if (m != null) return double.tryParse(m.group(1)!);
    }
    return null;
  }

  /// Nombre de tailles (`2FL`, `4 FLUTE`).
  static int? flutes(String description) {
    final m = RegExp(r'(\d+)\s*FL(?:UTE)?S?\b')
        .firstMatch(description.toUpperCase());
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Longueur de coupe (`19 LOC`).
  static double? cuttingLength(String description) {
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*LOC\b')
        .firstMatch(description.toUpperCase());
    return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  static String? material(String description) {
    final s = description.toUpperCase();
    if (RegExp(r'\bCRB\b|\bCARB').hasMatch(s)) return 'Carbure';
    if (RegExp(r'\bHSS\b').hasMatch(s)) return 'HSS';
    if (RegExp(r'\bCOB\b|\bHSCO\b').hasMatch(s)) return 'Cobalt';
    return null;
  }

  /// Forme de l'outil. L'ordre des tests compte : « BALL END MILL » contient
  /// « MILL », et « 2FL » contient « FL » — les formes spécifiques doivent
  /// donc être reconnues avant la fraise plate, qui sert de cas général.
  static ToolShape shape(String description) {
    final s = description.toUpperCase();

    if (RegExp(r'\bBALL\b|HEMISPH|HÉMISPH|\bBOULE\b|SPHER|\bBN\b').hasMatch(s)) {
      return ToolShape.ballNose;
    }
    if (RegExp(r'\bV[- ]?BIT\b|CHAMFER|CHANFREIN|GRAVEUR|ENGRAV|\bVEE\b')
        .hasMatch(s)) {
      return ToolShape.vBit;
    }
    if (RegExp(r'\bDRILL\b|\bFORET\b|CENTER\s?DRILL|POINTAGE|\bPERC|\bTARAUD|\bTAP\b')
        .hasMatch(s)) {
      return ToolShape.drill;
    }
    // Pas de `\b` devant FL : dans « 2FL » le chiffre et le F sont tous deux
    // des caracteres de mot, il n'y a donc aucune frontiere entre eux.
    if (RegExp(r'FL(?:UTE)?S?\b|END\s?MILL|ENDMILL|\bFRAISE\b|\bMILL\b|\bEM\b')
        .hasMatch(s)) {
      return ToolShape.flatEndMill;
    }
    return ToolShape.unknown;
  }
}
