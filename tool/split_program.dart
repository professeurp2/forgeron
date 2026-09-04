// Découpe un programme généré (dôme, sphère) en TRANCHES autonomes — Forgeron.
//
// Pourquoi : la carte ESP32 redémarre après 25 à 35 minutes d'exécution
// continue (constaté deux fois, broche débranchée, `mPos` remis à zéro et
// machine en alarme). Tant que la cause n'est pas traitée, un programme de
// 3 h 35 ne passera jamais d'un seul bloc.
//
// Ce n'est donc PAS une solution, c'est un contournement : chaque tranche dure
// moins longtemps que le temps moyen avant redémarrage, si bien qu'un reboot
// ne coûte que la tranche en cours au lieu de tout l'usinage. Les offsets G54
// survivant en EEPROM, la reprise ne demande qu'un homing.
//
// Chaque tranche est un programme COMPLET et autonome :
//   - le préambule d'origine (unités, plan, WCS, broche, montée en régime) ;
//   - une remontée en Z de sécurité AVANT la première approche, puisqu'on ne
//     peut plus supposer que l'outil est là où la tranche précédente l'a
//     laissé ;
//   - les couches/niveaux de la tranche ;
//   - le dégagement, l'arrêt broche et la fin de programme.
//
// La découpe tombe uniquement sur les marqueurs `(COUCHE n/N)` et
// `(NIVEAU n/N)` émis par les générateurs : jamais au milieu d'un contour, et
// jamais entre une descente en Z et le tour qui la suit.
//
// Lancer : dart run tool/split_program.dart <fichier.nc> [minutes_par_tranche]
// Exemple : dart run tool/split_program.dart scratch/dome_r20.nc 20

import 'dart:io';
import 'dart:math' as math;

/// Budget par défaut, en minutes. 20 min laisse une marge sous les ~24 min du
/// redémarrage le plus précoce observé.
const kDefaultMinutes = 20.0;

/// Vitesse retenue pour estimer la durée des rapides (mm/min). C'est le
/// `max_rate` de X/Y dans la config ; l'estimation n'a pas besoin d'être
/// exacte, seulement de ne pas sous-évaluer les tranches.
const kRapidRate = 500.0;

/// Marqueurs de début de bloc sécable, tels que les générateurs les écrivent.
final _blockMark = RegExp(r'^\((?:COUCHE|NIVEAU) ');

double? _word(String line, String letter) {
  final m = RegExp('$letter(-?[0-9]*\\.?[0-9]+)', caseSensitive: false)
      .firstMatch(line);
  return m == null ? null : double.tryParse(m.group(1)!);
}

/// Position courante en X/Y/Z/C, suivie ligne à ligne pour estimer les durées.
class _Cursor {
  double x = 0, y = 0, z = 0, c = 0, feed = 500;
}

/// Durée de [line] en minutes, en faisant avancer [cur].
double _durationOf(String line, _Cursor cur) {
  final code = line.split('(').first.trim().toUpperCase();
  if (code.isEmpty) return 0;

  // Temporisation : elle compte pour sa valeur, pas pour un déplacement.
  final dwell = RegExp(r'G0?4(?:\s|\b)[^;(]*?\bP\s*([0-9]*\.?[0-9]+)')
      .firstMatch(code);
  if (dwell != null) return (double.tryParse(dwell.group(1)!) ?? 0) / 60.0;

  final f = _word(code, 'F');
  if (f != null && f > 0) cur.feed = f;

  final isRapid = RegExp(r'^G0(?![0-9.])').hasMatch(code);
  final isLinear = RegExp(r'^G1(?![0-9.])').hasMatch(code);
  final isArc = RegExp(r'^G[23](?![0-9.])').hasMatch(code);
  if (!isRapid && !isLinear && !isArc) return 0;

  final nx = _word(code, 'X') ?? cur.x;
  final ny = _word(code, 'Y') ?? cur.y;
  final nz = _word(code, 'Z') ?? cur.z;
  final nc = _word(code, 'C') ?? cur.c;

  double distance;
  if (isArc) {
    // Longueur d'arc : rayon × angle balayé autour du centre (I, J).
    final i = _word(code, 'I') ?? 0, j = _word(code, 'J') ?? 0;
    final cx = cur.x + i, cy = cur.y + j;
    final r = math.sqrt(i * i + j * j);
    var a0 = math.atan2(cur.y - cy, cur.x - cx);
    var a1 = math.atan2(ny - cy, nx - cx);
    var sweep = RegExp(r'^G2(?![0-9.])').hasMatch(code)
        ? a0 - a1 // horaire
        : a1 - a0; // anti-horaire
    while (sweep <= 0) {
      sweep += 2 * math.pi;
    }
    final planar = r * sweep;
    final dz = nz - cur.z;
    distance = math.sqrt(planar * planar + dz * dz);
  } else {
    final dx = nx - cur.x, dy = ny - cur.y, dz = nz - cur.z, dc = nc - cur.c;
    // Norme mixte de GRBL : les degrés entrent dans la même racine que les
    // millimètres. C'est aussi ce qui rend un F partagé entre les deux si
    // trompeur — voir les générateurs.
    distance = math.sqrt(dx * dx + dy * dy + dz * dz + dc * dc);
  }

  cur
    ..x = nx
    ..y = ny
    ..z = nz
    ..c = nc;

  final rate = isRapid ? kRapidRate : cur.feed;
  return rate <= 0 ? 0 : distance / rate;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/split_program.dart '
        '<fichier.nc> [minutes_par_tranche]');
    exitCode = 64;
    return;
  }
  final path = args[0];
  final budget = args.length > 1
      ? (double.tryParse(args[1]) ?? kDefaultMinutes)
      : kDefaultMinutes;

  final src = File(path);
  if (!src.existsSync()) {
    stderr.writeln('Fichier introuvable : $path');
    exitCode = 66;
    return;
  }

  final lines = src.readAsStringSync().split('\n');

  // ── Découpage en préambule / blocs / postambule ────────────────────────
  final firstBlock = lines.indexWhere((l) => _blockMark.hasMatch(l.trim()));
  if (firstBlock < 0) {
    stderr.writeln('Aucun marqueur (COUCHE …) ou (NIVEAU …) : '
        'ce fichier ne vient pas des générateurs Forgeron, découpe annulée.');
    exitCode = 65;
    return;
  }

  final preamble = lines.sublist(0, firstBlock);

  // Le postambule commence au dégagement final.
  var lastBlockEnd = lines.length;
  for (var i = lines.length - 1; i > firstBlock; i--) {
    if (lines[i].trim().toUpperCase().startsWith('M30') ||
        lines[i].trim() == '(DEGAGEMENT)') {
      lastBlockEnd = math.min(lastBlockEnd, i);
    }
  }
  final postamble = lines.sublist(lastBlockEnd);

  final blocks = <List<String>>[];
  var current = <String>[];
  for (final l in lines.sublist(firstBlock, lastBlockEnd)) {
    if (_blockMark.hasMatch(l.trim()) && current.isNotEmpty) {
      blocks.add(current);
      current = <String>[];
    }
    current.add(l);
  }
  if (current.isNotEmpty) blocks.add(current);

  // ── Durées, puis regroupement en tranches ──────────────────────────────
  final cur = _Cursor();
  for (final l in preamble) {
    _durationOf(l, cur);
  }
  final durations = <double>[];
  for (final b in blocks) {
    var t = 0.0;
    for (final l in b) {
      t += _durationOf(l, cur);
    }
    durations.add(t);
  }

  final parts = <List<int>>[];
  var partBlocks = <int>[];
  var partTime = 0.0;
  for (var i = 0; i < blocks.length; i++) {
    // Un bloc plus long que le budget forme sa propre tranche : on ne coupe
    // jamais à l'intérieur.
    if (partBlocks.isNotEmpty && partTime + durations[i] > budget) {
      parts.add(partBlocks);
      partBlocks = <int>[];
      partTime = 0;
    }
    partBlocks.add(i);
    partTime += durations[i];
  }
  if (partBlocks.isNotEmpty) parts.add(partBlocks);

  // Z de sécurité : repris du préambule, qui contient le `G0 Z…` d'entrée.
  var zSafe = 20.0;
  for (final l in preamble) {
    final code = l.split('(').first.trim().toUpperCase();
    if (RegExp(r'^G0(?![0-9.])').hasMatch(code)) {
      final z = _word(code, 'Z');
      if (z != null && z > zSafe) zSafe = z;
    }
  }
  String f3(double v) => v.toStringAsFixed(3);

  // ── Écriture ───────────────────────────────────────────────────────────
  final base = path.replaceAll(RegExp(r'\.nc$', caseSensitive: false), '');
  final produced = <String>[];
  for (var p = 0; p < parts.length; p++) {
    final idx = parts[p];
    final t = idx.fold<double>(0, (s, i) => s + durations[i]);
    final out = StringBuffer()
      ..writeln('(TRANCHE ${p + 1} SUR ${parts.length}'
          ' - BLOCS ${idx.first + 1} A ${idx.last + 1}'
          ' - DUREE ESTIMEE ${t.round()} MIN)')
      ..writeln('(DECOUPE POUR CONTOURNER LES REDEMARRAGES DE LA CARTE :'
          ' LANCER LES TRANCHES DANS L ORDRE.)')
      ..writeln('(APRES UN REDEMARRAGE : REFAIRE LE HOMING,'
          ' PUIS RELANCER CETTE TRANCHE DEPUIS LE DEBUT.)');
    for (final l in preamble) {
      out.writeln(l);
    }
    // On ne sait pas où l'outil a été laissé : on remonte avant d'approcher.
    out.writeln('G0 Z${f3(zSafe)} (SECURITE REPRISE DE TRANCHE)');
    for (final i in idx) {
      for (final l in blocks[i]) {
        out.writeln(l);
      }
    }
    for (final l in postamble) {
      out.writeln(l);
    }

    final name = '${base}_p${p + 1}.nc';
    File(name).writeAsStringSync(out.toString());
    produced.add(name);
    stdout.writeln('  ${name.padRight(38)} '
        'blocs ${idx.first + 1}-${idx.last + 1}'.padRight(20) +
        '~${t.round()} min');
  }

  final total = durations.fold<double>(0, (s, d) => s + d);
  stdout
    ..writeln('---')
    ..writeln('${blocks.length} blocs -> ${produced.length} tranches '
        'de ${budget.round()} min max')
    ..writeln('duree totale estimee : ${total.round()} min '
        '(${(total / 60).toStringAsFixed(1)} h)');
}
