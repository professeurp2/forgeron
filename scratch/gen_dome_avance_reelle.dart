// Générateur de parcours 5 AXES CONTINU — variante AVANCE RÉELLE.
//
// Identique à tool/gen_5axes_dome.dart pour la géométrie ; la SEULE différence
// est le calcul de l'avance F.
//
// POURQUOI — en G94, FluidNC (base grbl) calcule l'avance sur une norme
// euclidienne qui MÉLANGE les mm et les degrés :
//
//     d5 = sqrt(dX² + dY² + dZ² + dA² + dC²)      (les degrés comptés comme mm)
//
// Sur ce dôme, un bloc déplace l'outil de ~1,7 mm pendant que C tourne de 5° :
// les « 5 » écrasent le reste, et un F600 programmé donne ~200 mm/min réels.
// Sur un parcours CAM le rapport rotation/translation varie → l'avance réelle
// devient imprévisible (quasi nulle près des pôles) = broutage puis casse.
//
// CORRECTIF — on sort un F PAR BLOC tel que la vitesse de l'outil SUR LA PIÈCE
// vaille la consigne. La référence est le déplacement dans le repère PIÈCE
// (`dPiece`), pas le déplacement machine : la pièce tourne avec la table, donc
// X/Y/Z machine ne décrivent pas ce que voit la matière.
//
//     dt = dPiece / Vcible        puis        F = d5 / dt
//
// On plafonne ensuite dt par les max_rate de chaque axe : inutile d'écrire un F
// que la machine écrêtera en silence — autant que le fichier dise la vérité.
//
// Lancer :  dart run scratch/gen_dome_avance_reelle.dart
// Sortie :  scratch/demo_dome_5axes_continu_avance.nc

import 'dart:io';
import 'dart:math';
import 'package:forgeron/core/utils/kinematics_service.dart';
import 'package:vector_math/vector_math_64.dart';

String f3(double v) => v.toStringAsFixed(3);
String f1(double v) => v.toStringAsFixed(1);

/// max_rate_mm_per_min de scratch/config_5axes_production.yaml (plafonds du
/// 2026-08-20 : X/Y 1000→500, Z 800→300 suite aux vibrations en bois).
const maxRate = {'X': 500.0, 'Y': 500.0, 'Z': 300.0, 'A': 3600.0, 'C': 3600.0};

void main() {
  final k = KinematicsService(pivotToTableOffset: 8, toolLength: 0);

  const R = 15.0;
  const phi0 = 15.0;
  const phi1 = 50.0;
  const turns = 3;
  const ptsPerTurn = 72;
  const vCible = 600.0; // vitesse outil VOULUE sur la pièce (mm/min)
  const feedPlunge = 200.0; // plongée Z hors matière (< max_rate Z = 300)
  const nPts = turns * ptsPerTurn;
  const aSign = -1;

  final domeCenter = Vector3(20, 0, 5);

  final rows = <List<double>>[]; // [Xm, Ym, Zm, A, C]
  final piece = <Vector3>[]; // point correspondant dans le repère PIÈCE
  var maxErr = 0.0;
  var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9, minZ = 1e9, maxZ = -1e9;
  var minA = 1e9, maxA = -1e9, minC = 1e9, maxC = -1e9;

  for (var i = 0; i <= nPts; i++) {
    final t = i / nPts;
    final phi = phi0 + (phi1 - phi0) * t;
    final theta = 2 * pi * turns * t;
    final phiR = phi * pi / 180;
    final p = domeCenter +
        (Vector3(sin(phiR) * cos(theta), sin(phiR) * sin(theta), cos(phiR))
          ..scale(R));
    final a = phi;
    final c = 90.0 - theta * 180 / pi;
    final m = k.inverseRTCP(p, a, c);

    final err = (k.forward(m, a, c) - p).length;
    if (err > maxErr) maxErr = err;

    rows.add([m.x, m.y, m.z, aSign * a, c]);
    piece.add(p);
    minX = min(minX, m.x); maxX = max(maxX, m.x);
    minY = min(minY, m.y); maxY = max(maxY, m.y);
    minZ = min(minZ, m.z); maxZ = max(maxZ, m.z);
    minA = min(minA, aSign * a); maxA = max(maxA, aSign * a);
    minC = min(minC, c); maxC = max(maxC, c);
  }

  /// F du bloc `i-1 → i`, plus la vitesse pièce réellement obtenue et l'axe
  /// éventuellement limitant.
  ({double feed, double vReel, String? limitant}) feedFor(int i) {
    final p0 = rows[i - 1], p1 = rows[i];
    final d = {
      'X': p1[0] - p0[0],
      'Y': p1[1] - p0[1],
      'Z': p1[2] - p0[2],
      'A': p1[3] - p0[3],
      'C': p1[4] - p0[4],
    };
    final d5 = sqrt(d.values.fold(0.0, (s, v) => s + v * v));
    final dPiece = (piece[i] - piece[i - 1]).length;
    if (d5 == 0 || dPiece == 0) return (feed: vCible, vReel: 0, limitant: null);

    // Durée voulue, puis allongée si un axe dépasserait son max_rate.
    var dt = dPiece / vCible; // minutes
    String? limitant;
    for (final e in d.entries) {
      final dtAxe = e.value.abs() / maxRate[e.key]!;
      if (dtAxe > dt) {
        dt = dtAxe;
        limitant = e.key;
      }
    }
    return (feed: d5 / dt, vReel: dPiece / dt, limitant: limitant);
  }

  final zSafe = maxZ + 15.0;
  final first = rows.first;

  var vMin = 1e9, vMax = -1e9, fMin = 1e9, fMax = -1e9;
  final limitants = <String, int>{};

  final b = StringBuffer()
    ..writeln('(DOME 5 AXES CONTINU - AVANCE REELLE - genere par Forgeron)')
    ..writeln('(Dome R=$R mm, spirale phi ${f3(phi0)}..${f3(phi1)} deg,'
        ' C continu, $turns tours)')
    ..writeln('(F CALCULE PAR BLOC : vise ${f1(vCible)} mm/min a l outil SUR LA')
    ..writeln('( PIECE. En G94 grbl mele mm et degres dans la meme norme, donc')
    ..writeln('( un F constant ne donne PAS une avance constante en 5 axes.)')
    ..writeln('(F est deja plafonne par les max_rate machine : ce qui est ecrit')
    ..writeln('( est ce qui sera execute, sans ecretage silencieux.)')
    ..writeln('(A = signe INVERSE de phi : +A=dos broche sur cette machine.)')
    ..writeln('(COORDS MACHINE - origine programme = PIVOT rotatif A/C)')
    ..writeln('(Enveloppe machine relative a G54 :)')
    ..writeln('( X ${f3(minX)}..${f3(maxX)}  Y ${f3(minY)}..${f3(maxY)}'
        '  Z ${f3(minZ)}..${f3(maxZ)})')
    ..writeln('( A ${f3(minA)}..${f3(maxA)}  C ${f3(minC)}..${f3(maxC)})')
    ..writeln('G21 G90 G94')
    ..writeln('G54')
    ..writeln('G0 A${f3(first[3])} C${f3(first[4])}')
    ..writeln('G0 X${f3(first[0])} Y${f3(first[1])} Z${f3(zSafe)}')
    ..writeln('G1 Z${f3(first[2])} F${f1(feedPlunge)}')
    ..writeln('G1 X${f3(first[0])} Y${f3(first[1])} Z${f3(first[2])} '
        'A${f3(first[3])} C${f3(first[4])} F${f1(feedPlunge)}');

  for (var i = 1; i < rows.length; i++) {
    final r = rows[i];
    final s = feedFor(i);
    vMin = min(vMin, s.vReel); vMax = max(vMax, s.vReel);
    fMin = min(fMin, s.feed); fMax = max(fMax, s.feed);
    if (s.limitant != null) {
      limitants[s.limitant!] = (limitants[s.limitant!] ?? 0) + 1;
    }
    b.writeln('G1 X${f3(r[0])} Y${f3(r[1])} Z${f3(r[2])} '
        'A${f3(r[3])} C${f3(r[4])} F${f1(s.feed)}');
  }

  b
    ..writeln('G0 Z${f3(zSafe)}')
    ..writeln('G0 A0 C0')
    ..writeln('M30');

  File('scratch/demo_dome_5axes_continu_avance.nc').writeAsStringSync(b.toString());

  stdout.writeln('OK -> scratch/demo_dome_5axes_continu_avance.nc');
  stdout.writeln('points=${rows.length}  erreur reconstruction max='
      '${maxErr.toStringAsExponential(2)} mm');
  stdout.writeln('vitesse outil SUR PIECE : ${f1(vMin)}..${f1(vMax)} mm/min'
      '  (consigne ${f1(vCible)})');
  stdout.writeln('F ecrit : ${f1(fMin)}..${f1(fMax)} mm/min');
  stdout.writeln(limitants.isEmpty
      ? 'aucun axe limitant : la consigne est tenue partout'
      : 'axe limitant (max_rate atteint) : $limitants blocs');
}
