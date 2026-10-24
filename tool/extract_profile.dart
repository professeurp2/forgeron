// Rétro-ingénierie du PROFIL d'une pièce de révolution depuis son G-code.
//
// C'est la brique qui permet de partir d'une pièce existante pour en faire une
// nouvelle SANS CAO et SANS toucher au G-code : on remonte du parcours vers la
// géométrie, on modifie la géométrie, puis on régénère un parcours neuf avec
// le générateur — qui recalcule proprement compensation d'outil, avances et
// enveloppe.
//
// Pourquoi ne PAS transformer le G-code directement : mettre un dôme R20 à
// l'échelle 1,25 pour obtenir un R25 donne `k(R+ρ)·sinθ` au lieu de
// `(kR+ρ)·sinθ`. Le rayon de la fraise ne grandit pas avec la pièce : l'écart
// atteint 0,75 mm, et il VARIE avec l'angle, donc rien ne le rattrape.
//
// ── Méthode ────────────────────────────────────────────────────────────────
//
// Le G-code donne la POINTE de l'outil. Pour une fraise boule d'axe vertical
// et de rayon ρ, le centre de la bille est à (X, Z+ρ). La surface usinée est
// l'enveloppe de ces billes, donc l'offset INTÉRIEUR de la courbe des centres,
// à distance ρ :
//
//     profil[i] = centre[i] − ρ · n[i]
//
// où n est la normale unitaire à la courbe des centres, estimée par
// différences finies centrées et orientée vers l'axe. Aucune hypothèse de
// sphère : la méthode vaut pour n'importe quel profil de révolution.
//
// Vérification analytique sur une sphère de rayon R (sommet en Z=0) :
//   pointe  = ((R+ρ)sinθ, (R+ρ)cosθ − (R+ρ))
//   centre  = ((R+ρ)sinθ, (R+ρ)cosθ − R)        → arc de rayon R+ρ en (0,−R)
//   normale = −(sinθ, cosθ)
//   profil  = (R·sinθ, R·cosθ − R)               → la sphère R, exactement.
//
// Lancer : dart run tool/extract_profile.dart <fichier.nc> [diametre_outil]
// Sortie : le profil sur stdout + <fichier>_profil.csv

import 'dart:io';
import 'dart:math' as math;

/// Un point du profil, en coordonnées pièce : rayon depuis l'axe C, hauteur.
class ProfilePoint {
  final double r;
  final double z;
  const ProfilePoint(this.r, this.z);
}

double? _word(String line, String letter) {
  final m = RegExp('$letter(-?[0-9]*\\.?[0-9]+)', caseSensitive: false)
      .firstMatch(line);
  return m == null ? null : double.tryParse(m.group(1)!);
}

/// Points de contact outil/pièce relevés dans les blocs de FINITION.
///
/// L'ébauche est ignorée : elle laisse une surépaisseur et ne décrit donc pas
/// la pièce finie. Seuls comptent les niveaux marqués `(NIVEAU …)`, où l'outil
/// est posé sur la surface définitive.
List<ProfilePoint> extractProfile(List<String> lines, double rho) {
  // ── 1. Relever la pointe de l'outil à chaque niveau de finition ────────
  final tip = <ProfilePoint>[];
  var inFinish = false;
  double? x, z;

  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('(NIVEAU ')) {
      // Un niveau s'achève quand le suivant commence.
      if (inFinish && x != null && z != null) tip.add(ProfilePoint(x, z));
      inFinish = true;
      continue;
    }
    if (!inFinish) continue;
    // Tout autre commentaire de section (typiquement `(DEGAGEMENT)`) clôt la
    // finition : sans ça, le `G0 Z…` de dégagement final était relevé comme un
    // point du profil et produisait une aberration en fin de liste.
    if (line.startsWith('(')) {
      if (x != null && z != null) tip.add(ProfilePoint(x, z));
      inFinish = false;
      x = null;
      z = null;
      continue;
    }

    final code = line.split('(').first.trim().toUpperCase();
    if (!RegExp(r'^G[01](?![0-9.])').hasMatch(code)) continue;
    x = _word(code, 'X') ?? x;
    z = _word(code, 'Z') ?? z;
  }
  if (inFinish && x != null && z != null) tip.add(ProfilePoint(x, z));
  if (tip.length < 3) return const [];

  // ── 2. Centres de bille ────────────────────────────────────────────────
  final centre = [for (final p in tip) ProfilePoint(p.r, p.z + rho)];

  // ── 3. Offset intérieur de ρ le long de la normale ─────────────────────
  final profile = <ProfilePoint>[];
  for (var i = 0; i < centre.length; i++) {
    // Tangente par différences centrées (décentrées aux extrémités).
    final a = centre[i == 0 ? 0 : i - 1];
    final b = centre[i == centre.length - 1 ? i : i + 1];
    var tr = b.r - a.r, tz = b.z - a.z;
    final len = math.sqrt(tr * tr + tz * tz);
    if (len == 0) continue;
    tr /= len;
    tz /= len;

    // Normale = tangente tournée de 90°, orientée vers l'axe (r décroissant).
    var nr = tz, nz = -tr;
    if (nr > 0) {
      nr = -nr;
      nz = -nz;
    }
    profile.add(ProfilePoint(centre[i].r + rho * nr, centre[i].z + rho * nz));
  }
  return profile;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/extract_profile.dart '
        '<fichier.nc> [diametre_outil]');
    exitCode = 64;
    return;
  }
  final path = args[0];
  final toolDia = args.length > 1 ? (double.tryParse(args[1]) ?? 6.0) : 6.0;
  final rho = toolDia / 2;

  final f = File(path);
  if (!f.existsSync()) {
    stderr.writeln('Fichier introuvable : $path');
    exitCode = 66;
    return;
  }

  final profile = extractProfile(f.readAsStringSync().split('\n'), rho);
  if (profile.isEmpty) {
    stderr.writeln('Aucun bloc (NIVEAU …) : ce fichier ne contient pas de '
        'finition de révolution exploitable.');
    exitCode = 65;
    return;
  }

  final csv = StringBuffer('rayon_mm,hauteur_mm\n');
  for (final p in profile) {
    csv.writeln('${p.r.toStringAsFixed(4)},${p.z.toStringAsFixed(4)}');
  }
  final out = path.replaceAll(RegExp(r'\.nc$', caseSensitive: false), '') +
      '_profil.csv';
  File(out).writeAsStringSync(csv.toString());

  stdout
    ..writeln('PROFIL EXTRAIT de $path (fraise boule D$toolDia)')
    ..writeln('${profile.length} points -> $out')
    ..writeln('');
  final step = math.max(1, profile.length ~/ 10);
  stdout.writeln('  rayon      hauteur');
  for (var i = 0; i < profile.length; i += step) {
    stdout.writeln('  ${profile[i].r.toStringAsFixed(3).padLeft(7)}'
        '    ${profile[i].z.toStringAsFixed(3).padLeft(8)}');
  }
  final last = profile.last;
  stdout
    ..writeln('  ${last.r.toStringAsFixed(3).padLeft(7)}'
        '    ${last.z.toStringAsFixed(3).padLeft(8)}   (dernier)')
    ..writeln('')
    ..writeln('hauteur totale : ${(profile.first.z - last.z).abs()
        .toStringAsFixed(3)} mm')
    ..writeln('rayon maximal  : ${profile.map((p) => p.r)
        .reduce(math.max).toStringAsFixed(3)} mm');
}
