// Générateur de parcours 5 AXES CONTINU (Option A, coords machine) — Forgeron.
//
// Finition d'une calotte sphérique (dôme) en gardant l'outil NORMAL à la
// surface. En spiralant du sommet vers le bord, l'inclinaison A ET la rotation
// C varient simultanément et en continu → vrai 5 axes continu.
//
// Géométrie (repère PIÈCE, dôme de rayon R centré sur l'origine) :
//   point surface  P = R·(sinφ·cosθ, sinφ·sinθ, cosφ)   (φ = angle polaire)
//   normale        n = P/R
// Pour présenter n à l'outil vertical sur une machine table-table A/C, on
// démontre : A = φ  et  C = 90° − θ. Les coords machine viennent de inverseRTCP.
//
// Lancer :  dart run tool/gen_5axes_dome.dart
// Sortie :  scratch/demo_dome_5axes_continu.nc

import 'dart:io';
import 'dart:math';
import 'package:forgeron/core/utils/kinematics_service.dart';
import 'package:vector_math/vector_math_64.dart';

String f3(double v) => v.toStringAsFixed(3);

void main() {
  final k = KinematicsService(pivotToTableOffset: 8, toolLength: 0);

  const R = 15.0; // rayon du dôme (mm)
  const phi0 = 15.0; // angle polaire de départ (évite la singularité A≈0)
  const phi1 = 50.0; // angle polaire de fin (bord du dôme)
  const turns = 3; // nombre de tours de la spirale
  const ptsPerTurn = 72;
  const feed = 600.0; // mm/min (air-cut)
  const nPts = turns * ptsPerTurn;

  // Centre du dôme DÉCALÉ du pivot rotatif : en tournant, la table entraîne ce
  // point → les axes linéaires X/Y/Z doivent suivre → vraie interpolation 5 axes
  // (les 5 axes bougent ensemble, pas seulement A/C).
  final domeCenter = Vector3(20, 0, 5);

  final rows = <List<double>>[]; // [Xm, Ym, Zm, A, C]
  var maxErr = 0.0;
  var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9, minZ = 1e9, maxZ = -1e9;
  var minA = 1e9, maxA = -1e9, minC = 1e9, maxC = -1e9;

  for (var i = 0; i <= nPts; i++) {
    final t = i / nPts;
    final phi = phi0 + (phi1 - phi0) * t; // degrés
    final theta = 2 * pi * turns * t; // radians (enroulement)
    final phiR = phi * pi / 180;
    final p = domeCenter +
        (Vector3(sin(phiR) * cos(theta), sin(phiR) * sin(theta), cos(phiR))
          ..scale(R));
    final a = phi;
    final c = 90.0 - theta * 180 / pi;
    final m = k.inverseRTCP(p, a, c);

    // auto-vérification : forward doit reconstruire le point pièce.
    final err = (k.forward(m, a, c) - p).length;
    if (err > maxErr) maxErr = err;

    rows.add([m.x, m.y, m.z, a, c]);
    minX = min(minX, m.x); maxX = max(maxX, m.x);
    minY = min(minY, m.y); maxY = max(maxY, m.y);
    minZ = min(minZ, m.z); maxZ = max(maxZ, m.z);
    minA = min(minA, a); maxA = max(maxA, a);
    minC = min(minC, c); maxC = max(maxC, c);
  }

  final zSafe = maxZ + 15.0;
  final first = rows.first;
  final last = rows.last;

  final b = StringBuffer()
    ..writeln('(DOME 5 AXES CONTINU - AIR-CUT - genere par Forgeron)')
    ..writeln('(Dome R=$R mm, spirale phi ${f3(phi0)}..${f3(phi1)} deg = A,'
        ' C continu, $turns tours)')
    ..writeln('(COORDS MACHINE - origine programme = PIVOT rotatif A/C)')
    ..writeln('(AIR-CUT: poser G54 au centre de l enveloppe, sans brut,')
    ..writeln('( et REGARDER le mouvement continu A+C sans alarme.)')
    ..writeln('(CUT REEL plus tard: G54 = centre plateau en X/Y, et 8 mm SOUS')
    ..writeln('( le dessus du plateau en Z = axe A. Sinon le dome sort faux.)')
    ..writeln('(Enveloppe machine relative a G54 :)')
    ..writeln('( X ${f3(minX)}..${f3(maxX)}  Y ${f3(minY)}..${f3(maxY)}'
        '  Z ${f3(minZ)}..${f3(maxZ)})')
    ..writeln('( A ${f3(minA)}..${f3(maxA)}  C ${f3(minC)}..${f3(maxC)})')
    ..writeln('G21 G90 G94')
    ..writeln('G54')
    ..writeln('G0 A${f3(first[3])} C${f3(first[4])}')
    ..writeln('G0 X${f3(first[0])} Y${f3(first[1])} Z${f3(zSafe)}')
    ..writeln('G1 Z${f3(first[2])} F$feed');

  for (final r in rows) {
    b.writeln('G1 X${f3(r[0])} Y${f3(r[1])} Z${f3(r[2])} '
        'A${f3(r[3])} C${f3(r[4])} F$feed');
  }

  b
    ..writeln('G0 Z${f3(zSafe)}')
    ..writeln('G0 A0 C0')
    ..writeln('M30');

  File('scratch/demo_dome_5axes_continu.nc').writeAsStringSync(b.toString());

  stdout.writeln('OK -> scratch/demo_dome_5axes_continu.nc');
  stdout.writeln('points=${rows.length}  erreur reconstruction max='
      '${maxErr.toStringAsExponential(2)} mm');
  stdout.writeln('X ${f3(minX)}..${f3(maxX)}  Y ${f3(minY)}..${f3(maxY)}'
      '  Z ${f3(minZ)}..${f3(maxZ)}  (zSafe=${f3(zSafe)})');
  stdout.writeln('A ${f3(minA)}..${f3(maxA)}  C ${f3(minC)}..${f3(maxC)}');
  stdout.writeln('depart A${f3(first[3])} C${f3(first[4])} -> '
      'fin A${f3(last[3])} C${f3(last[4])}');
}
