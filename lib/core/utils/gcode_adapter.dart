/// Adaptateur de G-code CAM (SolidWorks CAM / Fanuc-ISO) vers un dialecte
/// exécutable par FluidNC/GRBL (Cartesian, 5 axes X/Y/Z/A/C).
///
/// RÔLE : nettoyage/traduction des codes que FluidNC ne comprend pas. Il ne
/// fait PAS de transformation cinématique (5 axes) ni de compensation de rayon
/// d'outil : ça doit venir du post SolidWorks (coords machine + compensation
/// « ordinateur »). L'adaptateur SIGNALE ce qu'il ne peut pas assumer (RTCP
/// G43.4/.5, compensation machine G41/G42) et bloque l'exécution le cas échéant.
///
/// Ce qu'il fait :
///  - supprime numéros de programme/séquence (O…, N…), marqueurs %,
///  - retire la compensation de longueur d'outil (G43/G44 statiques, H, G49),
///  - convertit le changement d'outil M6 → pause M0 (changement manuel),
///  - DÉVELOPPE les cycles fixes de perçage G81/G82/G83 en G0/G1/G4,
///  - préserve les axes rotatifs A et C,
///  - signale/bloque : RTCP (G43.4/.5), compensation rayon machine (G41/G42),
///    cycles fixes non gérés (G84–G89), pouces (G20).
library;

/// Résultat de l'adaptation : le G-code transformé + les avertissements à
/// présenter à l'opérateur. [blocking] = vrai si le code contient des éléments
/// qui empêchent une exécution sûre en l'état (RTCP, compensation rayon machine,
/// cycles fixes non gérés) — à corriger dans le post SolidWorks.
class GcodeAdaptResult {
  final String gcode;
  final List<String> warnings;
  final bool blocking;
  const GcodeAdaptResult({
    required this.gcode,
    required this.warnings,
    required this.blocking,
  });
}

class GcodeAdapter {
  // Cycles fixes de perçage développables (G81 perçage, G82 pointage+tempo,
  // G83 débourrage).
  static final RegExp _drillCycle = RegExp(r'G8[123](?![0-9])');
  // Autres cycles fixes (taraudage/alésage G84–G89) : non développés → bloqués.
  static final RegExp _otherCycle = RegExp(r'G8[456789](?![0-9])');
  // RTCP / TCPC : FluidNC en Cartesian ne sait pas les exécuter.
  static final RegExp _rtcp = RegExp(r'G43\.[45](?![0-9])');
  // Transformation d'orientation 5 axes ACTIVE côté contrôleur — équivalent du
  // RTCP mais en dialecte Siemens (TRAORI/TRANSMIT/TRACYL) ou Heidenhain
  // (M128 = TCPM ON, FUNCTION TCPM). Leur présence signifie que le programme est
  // en REPÈRE PIÈCE : le contrôleur est censé recalculer la position machine à la
  // volée. FluidNC (Cartesian) ne le fait pas → on BLOQUE. Le post doit être
  // reconfiguré pour sortir des COORDONNÉES MACHINE (transformation désactivée).
  static final RegExp _orientTransform = RegExp(
      r'\b(?:TRAORI|TRANSMIT|TRACYL)\b|M128(?![0-9])|FUNCTION\s+TCPM',
      caseSensitive: false);
  // Compensation de rayon d'outil CÔTÉ MACHINE : non supportée par GRBL.
  static final RegExp _cutterComp = RegExp(r'G4[12](?![0-9])');
  static final RegExp _programNumber = RegExp(r'^O\d+');
  static final RegExp _sequence = RegExp(r'^N\d+\s*');
  // Compensation de longueur STATIQUE (G43/G44 sans décimale) + H + G49.
  // On ne touche PAS à G43.1 (dynamique, supporté) ni G43.4/.5 (RTCP, signalé).
  static final RegExp _toolLenComp = RegExp(r'G4[34](?![.\d])|G49(?![0-9])|H\d+');
  static final RegExp _toolChange = RegExp(r'M0?6(?![0-9])');
  static final RegExp _toolWord = RegExp(r'T\d+');
  static final RegExp _inch = RegExp(r'G20(?![0-9])');
  // Retour à la référence machine (G28/G30). DANGEREUX sur cette machine : le
  // zéro machine est à la position des capteurs (Z en bas), donc G28 Z0 ENVOIE
  // l'axe dans son switch → hard limit. On retire ces lignes.
  static final RegExp _referenceReturn = RegExp(r'G(28|30)(?![.\d])');

  static GcodeAdaptResult adaptForFluidNC(String raw) {
    final warnings = <String>[];
    var hasRtcp = false, hasInch = false, hasCutterComp = false;
    var hasOrientTransform = false;
    var strippedProg = 0, strippedComp = 0, convertedM6 = 0, strippedRef = 0;

    // ── Passe 1 : nettoyage ligne par ligne ────────────────────────────────
    final cleaned = <String>[];
    for (final rawLine in raw.split('\n')) {
      final semi = rawLine.indexOf(';');
      var code = (semi >= 0 ? rawLine.substring(0, semi) : rawLine).trim();
      final comment = semi >= 0 ? rawLine.substring(semi) : '';

      if (code == '%') continue;
      if (_programNumber.hasMatch(code)) {
        strippedProg++;
        continue;
      }
      // Retour à la référence machine (G28/G30) → retiré : sur cette machine il
      // enverrait l'axe dans son capteur (zéro machine = position des switches,
      // Z en bas). Le retrait Z en coords pièce qui précède dégage déjà l'outil.
      if (_referenceReturn.hasMatch(code.toUpperCase())) {
        strippedRef++;
        continue;
      }

      final upper0 = code.toUpperCase();
      if (_rtcp.hasMatch(upper0)) hasRtcp = true;
      if (_orientTransform.hasMatch(upper0)) hasOrientTransform = true;
      if (_inch.hasMatch(upper0)) hasInch = true;
      if (_cutterComp.hasMatch(upper0)) hasCutterComp = true;

      code = code.replaceFirst(_sequence, '');

      if (_toolChange.hasMatch(code.toUpperCase())) {
        final t = _toolWord.firstMatch(code.toUpperCase())?.group(0);
        code = code
            .toUpperCase()
            .replaceAll(_toolChange, 'M0')
            .replaceAll(_toolWord, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (code.isEmpty) code = 'M0';
        code = '$code (CHANGEMENT OUTIL${t != null ? ' $t' : ''} - reprendre)';
        convertedM6++;
      } else {
        final before =
            code.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        code = code
            .toUpperCase()
            .replaceAll(_toolLenComp, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (code != before) strippedComp++;
      }

      final rebuilt = (code + (comment.isNotEmpty ? ' $comment' : '')).trim();
      if (rebuilt.isNotEmpty) cleaned.add(rebuilt);
    }

    // ── Passe 2 : développement des cycles fixes ───────────────────────────
    final out = _expandCanned(cleaned, warnings);

    if (strippedProg > 0) {
      warnings.add('$strippedProg numéro(s) de programme (O…/%) supprimé(s).');
    }
    if (strippedRef > 0) {
      warnings.add('$strippedRef retour(s) à la référence machine (G28/G30) '
          'retiré(s) — le zéro machine est à la position des capteurs, donc G28 '
          'y enverrait l\'axe (risque de crash sur le switch).');
    }
    if (strippedComp > 0) {
      warnings.add('$strippedComp compensation(s) de longueur (G43/G49/H) '
          'retirée(s) — assure-toi que la longueur d\'outil est prise via le '
          'Z / le WCS.');
    }
    if (convertedM6 > 0) {
      warnings.add('$convertedM6 changement(s) d\'outil M6 → pause M0 '
          '(changement manuel, puis reprise).');
    }
    if (hasInch) {
      warnings.add('Code en POUCES (G20) détecté — la machine travaille en mm '
          '(G21). Vérifie que c\'est voulu.');
    }
    if (hasCutterComp) {
      warnings.add('⚠️ Compensation de rayon d\'outil CÔTÉ MACHINE (G41/G42) '
          'détectée : FluidNC ne la fait pas. Dans SolidWorks CAM, mets la '
          'compensation sur « Ordinateur » et re-poste. Ne pas exécuter tel quel.');
    }
    if (hasRtcp) {
      warnings.add('⚠️ RTCP (G43.4/G43.5) détecté : FluidNC (Cartesian) ne peut '
          'pas l\'exécuter. Le post doit sortir des coordonnées MACHINE. Ne pas '
          'exécuter tel quel.');
    }
    if (hasOrientTransform) {
      warnings.add('⚠️ Transformation d\'orientation 5 axes active '
          '(TRAORI / TRANSMIT / M128 / FUNCTION TCPM) détectée : le programme est '
          'en REPÈRE PIÈCE (le contrôleur est censé faire le RTCP). FluidNC '
          '(Cartesian) ne le fait pas. Re-poste en sortie COORDONNÉES MACHINE, '
          'transformation désactivée. Ne pas exécuter tel quel.');
    }

    return GcodeAdaptResult(
      gcode: out.join('\n'),
      warnings: warnings,
      blocking: hasRtcp || hasCutterComp || hasOrientTransform,
    );
  }

  // ── Développeur de cycles fixes ──────────────────────────────────────────
  static double? _num(String line, String word) {
    final m = RegExp('$word([-+]?[0-9]*\\.?[0-9]+)').firstMatch(line);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  static List<String> _expandCanned(List<String> lines, List<String> warnings) {
    final out = <String>[];
    double curX = 0, curY = 0, curZ = 0;
    var retractMode = 98; // G98 = retrait vers Z initial ; G99 = vers plan R
    double initialZ = 0; // Z avant le cycle (pour G98)
    String? active; // cycle actif : 'G81'/'G82'/'G83'
    double cZ = 0, cR = 0, cQ = 0, cP = 0, cF = 0;
    var expanded = 0;
    var blockedOther = false;

    for (final line in lines) {
      final u = line.toUpperCase();

      if (RegExp(r'G98(?![0-9])').hasMatch(u)) retractMode = 98;
      if (RegExp(r'G99(?![0-9])').hasMatch(u)) retractMode = 99;

      // G80 : annule le cycle ; on garde un éventuel mouvement Z résiduel.
      if (RegExp(r'G80(?![0-9])').hasMatch(u)) {
        active = null;
        final z = _num(u, 'Z');
        if (z != null) curZ = z;
        final rem = u
            .replaceAll(RegExp(r'G8[01](?![0-9])'), '')
            .replaceAll(RegExp(r'G9[89](?![0-9])'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (rem.isNotEmpty) out.add(rem);
        continue;
      }

      // Cycle de perçage développable.
      if (_drillCycle.hasMatch(u)) {
        active = _drillCycle.firstMatch(u)!.group(0)!.replaceAll(' ', '');
        initialZ = curZ;
        cZ = _num(u, 'Z') ?? cZ;
        cR = _num(u, 'R') ?? cR;
        cQ = _num(u, 'Q') ?? cQ;
        cP = _num(u, 'P') ?? cP;
        cF = _num(u, 'F') ?? cF;
        final x = _num(u, 'X');
        if (x != null) curX = x;
        final y = _num(u, 'Y');
        if (y != null) curY = y;
        out.addAll(_emitCycle(
            active, curX, curY, cZ, cR, cQ, cP, cF, retractMode, initialZ));
        expanded++;
        continue;
      }

      // Cycle non géré (taraudage/alésage) → bloqué.
      if (_otherCycle.hasMatch(u)) {
        blockedOther = true;
        out.add(line);
        continue;
      }

      // Répétition modale : en cycle actif, une ligne de coordonnées seules
      // (X/Y, sans autre G/M) répète le perçage à la nouvelle position.
      if (active != null && !RegExp(r'[GM]\d').hasMatch(u)) {
        final x = _num(u, 'X');
        final y = _num(u, 'Y');
        if (x != null || y != null) {
          if (x != null) curX = x;
          if (y != null) curY = y;
          out.addAll(_emitCycle(
              active, curX, curY, cZ, cR, cQ, cP, cF, retractMode, initialZ));
          expanded++;
          continue;
        }
      }

      // Un mouvement du groupe 1 (G0..G3) annule le mode cycle.
      if (RegExp(r'G0?[0-3](?![0-9])').hasMatch(u)) active = null;

      final x = _num(u, 'X');
      if (x != null) curX = x;
      final y = _num(u, 'Y');
      if (y != null) curY = y;
      final z = _num(u, 'Z');
      if (z != null) curZ = z;
      out.add(line);
    }

    if (expanded > 0) {
      warnings.add('$expanded cycle(s) fixe(s) de perçage développé(s) en G0/G1.');
    }
    if (blockedOther) {
      warnings.add('⚠️ Cycle fixe non géré (taraudage/alésage G84–G89) détecté : '
          'non développé. Utilise un perçage simple ou traite-le à part. Ne pas '
          'exécuter tel quel.');
    }
    return out;
  }

  static String _f(double v) => v.toStringAsFixed(3);

  static List<String> _emitCycle(String cycle, double x, double y, double z,
      double r, double q, double pMs, double f, int retractMode, double initialZ) {
    final s = <String>[];
    final retractZ = retractMode == 99 ? r : initialZ;
    s.add('G0 X${_f(x)} Y${_f(y)}'); // positionnement XY (au Z courant sûr)
    s.add('G0 Z${_f(r)}'); // descente rapide au plan R
    if (cycle == 'G83' && q > 0) {
      const clearance = 0.5; // reprise rapide juste au-dessus du dernier perçage
      var depth = r;
      var first = true;
      while (depth > z) {
        final target = (depth - q) > z ? (depth - q) : z;
        if (!first) s.add('G0 Z${_f(depth + clearance)}');
        s.add('G1 Z${_f(target)} F${_f(f)}');
        depth = target;
        first = false;
        if (depth > z) s.add('G0 Z${_f(r)}'); // débourrage : retrait au plan R
      }
    } else {
      s.add('G1 Z${_f(z)} F${_f(f)}'); // descente d'usinage (G81/G82)
      if (cycle == 'G82' && pMs > 0) {
        s.add('G4 P${_f(pMs / 1000.0)}'); // tempo : ms (Fanuc) → s (GRBL)
      }
    }
    s.add('G0 Z${_f(retractZ)}'); // retrait final
    return s;
  }
}
