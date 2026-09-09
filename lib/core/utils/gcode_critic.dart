import 'dart:math' as math;

/// Critique automatique d'un programme G-code, destinée à l'agent IA.
///
/// L'agent ne produit jamais de coordonnées : il confie la génération à une
/// bibliothèque, puis JUGE le résultat. Ce module est ce juge. Il rend un
/// verdict structuré — pas un booléen — pour que l'agent sache quoi changer et
/// relance la génération avec d'autres paramètres.
///
///     STL/STEP → agent → bibliothèque → G-code → CE MODULE
///                  ↑                                 │
///                  └──── remède exploitable ─────────┘
///
/// Il complète [TrajectoryValidator], qui reste le garde-fou bloquant juste
/// avant le streaming : celui-ci travaille sur le parcours déjà interprété et
/// ne vérifie que la course Z et la plage de A. Le critique, lui, lit le texte
/// du programme et mesure ce que la machine en fera réellement.
class GcodeCritic {
  /// Limites machine. Valeurs par défaut = la configuration de production.
  final double maxX, maxY, travelZ, minA, maxA;

  /// Avance maximale admise (ForceGuard 5 axes).
  final double maxFeed;

  /// Au-delà, une rotation est jugée brutale (degrés par millimètre d'avance).
  final double maxDegPerMm;

  /// Durée au-delà de laquelle un programme risque de ne pas aller au bout.
  /// Sur cette machine les redémarrages thermiques surviennent vers 25-35 min.
  final double maxMinutes;

  const GcodeCritic({
    this.maxX = 88.0,
    this.maxY = 150.0,
    this.travelZ = 110.0,
    this.minA = -88.0,
    this.maxA = 90.0,
    this.maxFeed = 500.0,
    this.maxDegPerMm = 90.0,
    this.maxMinutes = 25.0,
  });

  static final _word = <String, RegExp>{
    for (final l in ['X', 'Y', 'Z', 'A', 'C', 'F', 'I', 'J'])
      l: RegExp('$l(-?[0-9]*\\.?[0-9]+)', caseSensitive: false),
  };

  static double? _read(String line, String letter) {
    final m = _word[letter]!.firstMatch(line);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  /// Analyse [gcode] et rend le verdict.
  GcodeCritique review(String gcode) {
    final findings = <CriticFinding>[];
    final lines = gcode.split('\n');

    double x = 0, y = 0, z = 0, a = 0, c = 0, feed = 0;
    double minZ = 0, maxSeenX = 0, maxSeenY = 0, minSeenA = 0, maxSeenA = 0;
    double minutes = 0;
    var moves = 0, mixedBlocks = 0, jerkyBlocks = 0, noFeedBlocks = 0;
    var worstFeedLoss = 1.0;
    int? worstFeedLine;

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].split('(').first.split(';').first.trim();
      if (raw.isEmpty) continue;
      final u = raw.toUpperCase();

      // Temporisation : ni mouvement, ni avance.
      final dwell = RegExp(r'G0?4(?:\s|\b)[^;(]*?\bP\s*([0-9]*\.?[0-9]+)')
          .firstMatch(u);
      if (dwell != null) {
        minutes += (double.tryParse(dwell.group(1)!) ?? 0) / 60.0;
        continue;
      }

      final isRapid = RegExp(r'^G0(?![0-9.])').hasMatch(u);
      final isLinear = RegExp(r'^G1(?![0-9.])').hasMatch(u);
      final isArc = RegExp(r'^G[23](?![0-9.])').hasMatch(u);
      final f = _read(u, 'F');
      if (f != null && f > 0) {
        feed = f;
        if (f > maxFeed) {
          findings.add(CriticFinding(
            code: 'avance_au_dessus_du_plafond',
            severity: CriticSeverity.warning,
            line: i + 1,
            measured: f,
            limit: maxFeed,
            message: 'F${f.toStringAsFixed(0)} dépasse le plafond '
                '${maxFeed.toStringAsFixed(0)} : le ForceGuard le réécrira '
                'pendant le streaming.',
            remedy: 'Émettre F ≤ ${maxFeed.toStringAsFixed(0)}, sinon le '
                'fichier ne décrit pas ce que la machine fera.',
          ));
        }
      }
      if (!isRapid && !isLinear && !isArc) continue;

      final nx = _read(u, 'X') ?? x;
      final ny = _read(u, 'Y') ?? y;
      final nz = _read(u, 'Z') ?? z;
      final na = _read(u, 'A') ?? a;
      final nc = _read(u, 'C') ?? c;

      // Longueur linéaire : arc si I/J présents, segment sinon.
      double linear;
      if (isArc) {
        final si = _read(u, 'I') ?? 0, sj = _read(u, 'J') ?? 0;
        final r = math.sqrt(si * si + sj * sj);
        final cx = x + si, cy = y + sj;
        var sweep = math.atan2(ny - cy, nx - cx) - math.atan2(y - cy, x - cx);
        if (RegExp(r'^G2(?![0-9.])').hasMatch(u)) sweep = -sweep;
        while (sweep <= 0) {
          sweep += 2 * math.pi;
        }
        linear = math.sqrt(math.pow(r * sweep, 2) + math.pow(nz - z, 2));
      } else {
        linear = math.sqrt(math.pow(nx - x, 2) +
            math.pow(ny - y, 2) +
            math.pow(nz - z, 2));
      }
      final angular = math.sqrt(math.pow(na - a, 2) + math.pow(nc - c, 2));

      if (linear > 1e-9 || angular > 1e-9) {
        moves++;

        // ── L'avance est-elle celle qu'on croit ? ─────────────────────────
        // GRBL mesure un bloc sur √(mm² + deg²). Quand les deux sont présents,
        // le F écrit se répartit entre eux : l'avance linéaire réelle vaut
        // F × linéaire / mixte. C'est le piège qui a divisé une avance par 45.
        if (linear > 1e-9 && angular > 1e-9) {
          mixedBlocks++;
          final mixed = math.sqrt(linear * linear + angular * angular);
          final ratio = linear / mixed;
          if (ratio < worstFeedLoss) {
            worstFeedLoss = ratio;
            worstFeedLine = i + 1;
          }
        }

        if (linear > 1e-9 && angular / linear > maxDegPerMm) jerkyBlocks++;
        if (isLinear && feed <= 0) noFeedBlocks++;

        final effective = isRapid ? maxFeed : (feed > 0 ? feed : maxFeed);
        minutes += math.sqrt(linear * linear + angular * angular) / effective;
      }

      x = nx;
      y = ny;
      z = nz;
      a = na;
      c = nc;
      minZ = math.min(minZ, z);
      maxSeenX = math.max(maxSeenX, x.abs());
      maxSeenY = math.max(maxSeenY, y.abs());
      minSeenA = math.min(minSeenA, a);
      maxSeenA = math.max(maxSeenA, a);
    }

    // ── Verdicts ─────────────────────────────────────────────────────────
    if (moves == 0) {
      findings.add(const CriticFinding(
        code: 'aucun_mouvement',
        severity: CriticSeverity.blocking,
        message: 'Le programme ne contient aucun déplacement.',
        remedy: 'La génération a échoué : rien à exécuter.',
      ));
    }

    if (worstFeedLoss < 0.5) {
      findings.add(CriticFinding(
        code: 'avance_ecrasee_par_la_rotation',
        severity: worstFeedLoss < 0.1
            ? CriticSeverity.blocking
            : CriticSeverity.warning,
        line: worstFeedLine,
        measured: worstFeedLoss,
        limit: 0.5,
        message: 'Sur $mixedBlocks bloc(s) mêlant déplacement et rotation, '
            'l\'avance linéaire réelle tombe à '
            '${(worstFeedLoss * 100).toStringAsFixed(1)} % du F écrit '
            '(facteur ${(1 / worstFeedLoss).toStringAsFixed(0)}).',
        remedy: 'Soit séparer les blocs linéaires et rotatifs, soit compenser '
            'F bloc par bloc : F = v × L_mixte / L_linéaire.',
      ));
    }

    if (-minZ > travelZ) {
      findings.add(CriticFinding(
        code: 'course_z_depassee',
        severity: CriticSeverity.blocking,
        measured: -minZ,
        limit: travelZ,
        message: 'Le programme descend à Z${minZ.toStringAsFixed(1)} pour une '
            'course de ${travelZ.toStringAsFixed(0)} mm.',
        remedy: 'Réduire la profondeur, ou remonter le zéro pièce.',
      ));
    }
    if (maxSeenX > maxX / 2) {
      findings.add(CriticFinding(
        code: 'course_x_serree',
        severity: CriticSeverity.warning,
        measured: maxSeenX,
        limit: maxX / 2,
        message: 'Le programme s\'écarte de ±${maxSeenX.toStringAsFixed(1)} mm '
            'en X ; la course totale est de ${maxX.toStringAsFixed(0)} mm.',
        remedy: 'L\'origine doit être posée au milieu de la course X, sinon un '
            'côté sortira.',
      ));
    }
    if (maxSeenY > maxY / 2) {
      findings.add(CriticFinding(
        code: 'course_y_serree',
        severity: CriticSeverity.warning,
        measured: maxSeenY,
        limit: maxY / 2,
        message: 'Le programme s\'écarte de ±${maxSeenY.toStringAsFixed(1)} mm '
            'en Y ; la course totale est de ${maxY.toStringAsFixed(0)} mm.',
        remedy: 'Vérifier la position de l\'origine dans la course Y.',
      ));
    }
    if (maxSeenA > maxA || minSeenA < minA) {
      findings.add(CriticFinding(
        code: 'axe_a_hors_course',
        severity: CriticSeverity.blocking,
        measured: math.max(maxSeenA, -minSeenA),
        limit: math.max(maxA, -minA),
        message: 'L\'axe A va de ${minSeenA.toStringAsFixed(1)} à '
            '${maxSeenA.toStringAsFixed(1)}° pour une course de '
            '${minA.toStringAsFixed(0)} à ${maxA.toStringAsFixed(0)}°.',
        remedy: 'Limiter l\'inclinaison, ou réorienter la pièce sur le plateau.',
      ));
    }
    if (jerkyBlocks > 0) {
      findings.add(CriticFinding(
        code: 'rotations_brutales',
        severity: CriticSeverity.warning,
        measured: jerkyBlocks.toDouble(),
        message: '$jerkyBlocks bloc(s) tournent de plus de '
            '${maxDegPerMm.toStringAsFixed(0)}° par millimètre d\'avance.',
        remedy: 'Densifier le parcours près des pôles, ou lisser les '
            'orientations entre points voisins.',
      ));
    }
    if (noFeedBlocks > 0) {
      findings.add(CriticFinding(
        code: 'avance_non_definie',
        severity: CriticSeverity.blocking,
        measured: noFeedBlocks.toDouble(),
        message: '$noFeedBlocks bloc(s) G1 avant toute définition de F.',
        remedy: 'Émettre un F avant le premier mouvement travaillé.',
      ));
    }
    if (minutes > maxMinutes) {
      findings.add(CriticFinding(
        code: 'duree_superieure_au_temps_avant_redemarrage',
        severity: CriticSeverity.warning,
        measured: minutes,
        limit: maxMinutes,
        message: 'Durée estimée ${minutes.toStringAsFixed(0)} min ; la carte '
            'a redémarré vers ${maxMinutes.toStringAsFixed(0)} min en '
            'environnement non refroidi.',
        remedy: 'Refroidir l\'armoire, ou découper le programme en tranches.',
      ));
    }

    final blocking =
        findings.any((f) => f.severity == CriticSeverity.blocking);
    return GcodeCritique(
      usable: !blocking,
      findings: findings,
      stats: {
        'blocs_de_mouvement': moves,
        'duree_estimee_min': minutes,
        'z_minimal': minZ,
        'ecart_max_x': maxSeenX,
        'ecart_max_y': maxSeenY,
        'a_min_deg': minSeenA,
        'a_max_deg': maxSeenA,
        'blocs_mixtes': mixedBlocks,
        'perte_avance_max': worstFeedLoss,
      },
    );
  }
}

enum CriticSeverity {
  /// Le programme ne doit pas être exécuté en l'état.
  blocking,

  /// Exécutable, mais le résultat ou la durée ne seront pas ceux attendus.
  warning,

  /// Information utile à l'agent, sans conséquence directe.
  info,
}

/// Un défaut relevé, avec de quoi le corriger.
class CriticFinding {
  /// Identifiant stable, pour que l'agent puisse réagir sans analyser le texte.
  final String code;
  final CriticSeverity severity;
  final int? line;
  final double? measured;
  final double? limit;

  /// Ce qui ne va pas, en clair.
  final String message;

  /// Ce qu'il faut changer — c'est cette ligne qui permet à l'agent de
  /// relancer la génération avec d'autres paramètres plutôt que d'abandonner.
  final String? remedy;

  const CriticFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.line,
    this.measured,
    this.limit,
    this.remedy,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'gravite': severity.name,
        if (line != null) 'ligne': line,
        if (measured != null) 'mesure': measured,
        if (limit != null) 'limite': limit,
        'message': message,
        if (remedy != null) 'remede': remedy,
      };
}

/// Verdict complet sur un programme.
class GcodeCritique {
  /// Faux dès qu'un défaut bloquant est présent.
  final bool usable;
  final List<CriticFinding> findings;
  final Map<String, dynamic> stats;

  const GcodeCritique({
    required this.usable,
    required this.findings,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
        'exploitable': usable,
        'defauts': findings.map((f) => f.toJson()).toList(),
        'statistiques': stats,
      };
}
