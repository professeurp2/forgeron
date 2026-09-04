// Générateur de DÔME HÉMISPHÉRIQUE complet (ébauche + finition) — Forgeron.
//
// Programme en deux étapes, un seul outil (fraise BOULE), aucun M6 :
//
//   ÉTAPE 1 — ÉBAUCHE 3 AXES. Dégage la couronne autour du dôme par contours
//   circulaires concentriques, couche par couche. A et C restent à 0 : c'est
//   du 3 axes pur, donc F s'applique bien aux millimètres et l'ébauche va à
//   sa vraie vitesse. Il FAUT dégager jusqu'à `kClearR`, sinon la fraise ne
//   peut pas atteindre l'équateur du dôme à l'étape 2 : à l'équateur la bille
//   occupe de R à R+2ρ, plus la queue de l'outil au-dessus.
//
//   ÉTAPE 2 — FINITION 5 AXES (turn-milling). L'outil reste fixe en X/Y/Z et
//   le plateau C fait un tour par parallèle. Voir gen_sphere_finish.dart pour
//   le détail : compensation du rayon de bille, pas angulaire constant, F en
//   °/min, C absolu croissant.
//
// ── Réglage anti-vibration (2026-09-04) ────────────────────────────────────
//
// Passes divisées par deux (ap 1,0 → 0,5 ; ae 2,0 → 1,0) et trois changements
// de stratégie qui comptent davantage que les passes elles-mêmes :
//
//   • PLONGÉE SUPPRIMÉE. Chaque couche entre désormais en HÉLICE : le premier
//     tour descend de `kAp` réparti sur quatre quarts d'arc (rampe ~0,6°), au
//     lieu d'un `G1 Z` vertical dans la matière pleine. La plongée droite avec
//     une fraise boule est le geste le plus vibrant du programme — le centre
//     de la bille a une vitesse de coupe nulle et racle.
//
//   • AVANCE MONTÉE À 500, PAS BAISSÉE. Réduire F à passes faibles fait
//     tomber l'avance par dent : la fraise cesse de couper et frotte, ce qui
//     chauffe et fait vibrer davantage. On reste donc au plafond ForceGuard.
//     Ce sont ap et ae qui font l'effort, pas F.
//
//   • PLUS DE RETOUR EN Z SÉCURITÉ entre les couches. On se dégage de 1 mm et
//     on rentre vers le rayon de départ suivant au-dessus du fond déjà usiné
//     (le dôme s'élargissant avec la profondeur, ce rayon ne fait que croître,
//     donc le trajet est toujours dans le vide). Économise ~15 min de va-et-
//     vient vertical, et autant de sollicitations de l'axe Z.
//
// ── Deux pièges de GRBL évités ─────────────────────────────────────────────
//
//   • G2 vs G3. En G17, G2 est HORAIRE. Un « G2 X0 Y16 I-16 J0 » partant de
//     (16,0) ne fait pas un quart de tour mais 270° — l'ébauche tourne alors
//     3 fois plus longtemps que prévu. Les quarts sont donc émis en G3.
//
//   • mm et degrés dans le même F. Jamais de mot C dans un bloc d'ébauche, et
//     jamais de mot X/Y/Z dans un bloc de rotation : un bloc qui mélange les
//     deux voit son F réparti sur √(mm² + deg²), ce qui écrase l'avance
//     linéaire d'un facteur ~45.
//
// Lancer : dart run tool/gen_dome.dart
// Sortie : scratch/dome_r20.nc

import 'dart:io';
import 'dart:math' as math;

// ── Pièce ───────────────────────────────────────────────────────────────────

/// Rayon du dôme (mm). Hauteur du dôme = ce rayon.
const kDomeR = 20.0;

/// Côté du brut carré (mm) — sert au contrôle d'enveloppe seulement.
const kStockSide = 65.0;

/// Hauteur du brut (mm).
const kStockH = 50.0;

// ── Outil ───────────────────────────────────────────────────────────────────

/// Diamètre de la fraise BOULE (mm), unique pour l'ébauche et la finition.
const kToolDia = 6.0;

// ── Ébauche ─────────────────────────────────────────────────────────────────

/// Surépaisseur laissée sur le dôme par l'ébauche (mm).
const kStock = 0.5;

/// Profondeur de passe (mm). Faible = peu d'effort axial, peu de vibration.
const kAp = 0.5;

/// Engagement radial entre deux contours (mm). C'est le paramètre qui pilote
/// l'effort de coupe, donc les vibrations.
const kAe = 1.0;

/// Avance d'ébauche (mm/min). Au plafond ForceGuard 5AX : la baisser ferait
/// frotter la fraise au lieu de couper.
const kFeedRough = 500.0;

/// Avance d'approche au contact (mm/min).
const kFeedPlunge = 100.0;

/// Dégagement vertical entre deux couches (mm).
const kApproachGap = 1.0;

// ── Finition ────────────────────────────────────────────────────────────────

/// Pas visé sur la surface entre deux parallèles (mm).
const kStepover = 0.4;

/// Vitesse d'avance visée au POINT DE CONTACT (mm/min).
const kVSurface = 120.0;

/// Plafond d'avance = MachiningMode.fiveAxis.maxFeedrate. Le ForceGuard ne
/// distingue pas les mm/min des °/min : tout F au-dessus serait réécrit en
/// F500 au streaming. On plafonne ici pour que le fichier dise la vérité.
const kFeedCap = 500.0;

/// Avance des liaisons entre deux niveaux de finition (mm/min).
const kFeedLink = 200.0;

// ── Sécurité ────────────────────────────────────────────────────────────────

/// Dégagement au-dessus du sommet, en G54 (mm).
const kZSafe = 20.0;

String f3(double v) {
  final s = v.toStringAsFixed(3);
  return s == '-0.000' ? '0.000' : s;
}

/// Rayon de la surface du dôme à la profondeur [d] sous le sommet.
double domeRadius(double d) =>
    d >= kDomeR ? kDomeR : math.sqrt(2 * kDomeR * d - d * d);

/// Cercle complet plat, en quatre quarts G3, départ et arrivée en (r, 0).
void emitCircle(StringBuffer b, double r) {
  final s = f3(r);
  b
    ..writeln('G3 X0.000 Y$s I-$s J0.000')
    ..writeln('G3 X-$s Y0.000 I0.000 J-$s')
    ..writeln('G3 X0.000 Y-$s I$s J0.000')
    ..writeln('G3 X$s Y0.000 I0.000 J$s');
}

/// Un tour en HÉLICE descendante de [z0] à [z1], au rayon [r]. Remplace la
/// plongée verticale : la descente est étalée sur toute la circonférence.
void emitHelix(StringBuffer b, double r, double z0, double z1) {
  final s = f3(r);
  final dz = (z1 - z0) / 4;
  b
    ..writeln('G3 X0.000 Y$s Z${f3(z0 + dz)} I-$s J0.000')
    ..writeln('G3 X-$s Y0.000 Z${f3(z0 + 2 * dz)} I0.000 J-$s')
    ..writeln('G3 X0.000 Y-$s Z${f3(z0 + 3 * dz)} I$s J0.000')
    ..writeln('G3 X$s Y0.000 Z${f3(z1)} I0.000 J$s');
}

void main() {
  final rho = kToolDia / 2;
  final rOffset = kDomeR + rho; // rayon décrit par le centre de la bille

  // Rayon à dégager : à l'équateur la pointe est à R+ρ et la bille déborde
  // encore de ρ, d'où R+2ρ, plus 2 mm de marge.
  final clearR = kDomeR + 2 * rho + 2.0;
  // Profondeur à dégager : la pointe descend à -(R+ρ) à l'équateur, +2 mm.
  final clearD = rOffset + 2.0;

  var roughMin = 0.0;
  var finishMin = 0.0;

  // ── ÉTAPE 1 : ébauche ─────────────────────────────────────────────────
  final rough = StringBuffer();
  final nLayers = (clearD / kAp).ceil();
  var nCircles = 0;
  var firstLayer = true;

  for (var k = 1; k <= nLayers; k++) {
    final d = math.min(kAp * k, clearD);
    final dPrev = math.min(kAp * (k - 1), clearD);
    // La bille mord jusqu'à ρ en deçà de la pointe : on garde le dôme et sa
    // surépaisseur hors d'atteinte en partant à r_dome(d) + stock + ρ.
    final xMin = domeRadius(d) + kStock + rho;
    if (xMin > clearR) continue;

    rough.writeln('(COUCHE $k/$nLayers - Z${f3(-d)}'
        ' - DE X${f3(xMin)} A X${f3(clearR)})');

    if (firstLayer) {
      // Première entrée : on descend dans le vide jusqu'au plan du brut.
      rough
        ..writeln('G0 X${f3(xMin)} Y0.000')
        ..writeln('G0 Z${f3(kApproachGap)}')
        ..writeln('G1 Z${f3(-dPrev)} F${f3(kFeedPlunge)}');
      firstLayer = false;
    } else {
      // On est à 1 mm au-dessus du fond précédent, au rayon extérieur. Le
      // trajet vers le nouveau rayon de départ passe au-dessus de la zone
      // déjà usinée (xMin croît avec la profondeur).
      rough
        ..writeln('G0 X${f3(xMin)} Y0.000')
        ..writeln('G1 Z${f3(-dPrev)} F${f3(kFeedPlunge)}');
    }
    roughMin += kApproachGap / kFeedPlunge;

    // Entrée en hélice sur un tour, puis un tour plat pour égaliser le fond.
    rough.writeln('F${f3(kFeedRough)}');
    emitHelix(rough, xMin, -dPrev, -d);
    emitCircle(rough, xMin);
    roughMin += 2 * 2 * math.pi * xMin / kFeedRough;
    nCircles += 2;

    // Contours concentriques vers l'extérieur.
    var r = xMin;
    while (r < clearR) {
      r = math.min(r + kAe, clearR);
      rough.writeln('G1 X${f3(r)} Y0.000');
      emitCircle(rough, r);
      roughMin += 2 * math.pi * r / kFeedRough;
      nCircles++;
    }

    // Dégagement minimal : on reste près du fond pour la couche suivante.
    rough.writeln('G0 Z${f3(-d + kApproachGap)}');
  }
  rough.writeln('G0 Z${f3(kZSafe)}');

  // ── ÉTAPE 2 : finition ────────────────────────────────────────────────
  final dThetaTarget = kStepover / kDomeR * 180 / math.pi;
  final nLevels = (90.0 / dThetaTarget).ceil();
  final dTheta = 90.0 / nLevels;
  final stepReal = kDomeR * dTheta * math.pi / 180;
  final crest = stepReal * stepReal / (8 * rho);

  final finish = StringBuffer();
  for (var i = 1; i <= nLevels; i++) {
    final thetaDeg = dTheta * i;
    final t = thetaDeg * math.pi / 180;

    final x = rOffset * math.sin(t);
    final z = rOffset * math.cos(t) - rOffset;
    final rContact = kDomeR * math.sin(t);
    final feed = math.min(kVSurface * 180 / (math.pi * rContact), kFeedCap);
    finishMin += 360.0 / feed;

    finish.writeln('(NIVEAU $i/$nLevels - THETA ${f3(thetaDeg)} DEG'
        ' - RAYON CONTACT ${f3(rContact)})');
    if (i == 1) {
      finish
        ..writeln('G0 X${f3(x)} Y0.000')
        ..writeln('G1 Z${f3(z)} F${f3(kFeedPlunge)}');
    } else {
      finish.writeln('G1 X${f3(x)} Z${f3(z)} F${f3(kFeedLink)}');
    }
    finish.writeln('G1 C${f3(360.0 * i)} F${f3(feed)}');
  }

  // ── Assemblage ────────────────────────────────────────────────────────
  final totalMin = roughMin + finishMin;
  final diag = kStockSide * math.sqrt(2) / 2;

  final b = StringBuffer()
    ..writeln('(FORGERON - DOME HEMISPHERIQUE R${f3(kDomeR)})')
    ..writeln('(BRUT ${f3(kStockSide)} PAR ${f3(kStockSide)}'
        ' HAUTEUR ${f3(kStockH)} - EMBASE CARREE CONSERVEE)')
    ..writeln('(OUTIL UNIQUE : FRAISE BOULE DIAM ${f3(kToolDia)}'
        ' - AUCUN CHANGEMENT EN COURS DE PROGRAMME)')
    ..writeln('(ETAPE 1 EBAUCHE 3 AXES : $nLayers COUCHES,'
        ' $nCircles CONTOURS, AP ${f3(kAp)} AE ${f3(kAe)},'
        ' SUREPAISSEUR ${f3(kStock)})')
    ..writeln('(ENTREE EN HELICE A CHAQUE COUCHE'
        ' - AUCUNE PLONGEE VERTICALE DANS LA MATIERE)')
    ..writeln('(ETAPE 2 FINITION 5 AXES : $nLevels NIVEAUX,'
        ' PAS SURFACE ${f3(stepReal)}, CRETE ${crest.toStringAsFixed(4)})')
    ..writeln('(A RESTE A 0 SUR TOUT LE PROGRAMME - PAS DE RTCP REQUIS)')
    ..writeln('(C ABSOLU CROISSANT JUSQU A ${f3(360.0 * nLevels)} DEG'
        ' = $nLevels TOURS - RIEN NE DOIT ETRE CABLE SUR LE PLATEAU)')
    ..writeln('(DUREE ESTIMEE : ${roughMin.round()} MIN EBAUCHE'
        ' + ${finishMin.round()} MIN FINITION = ${totalMin.round()} MIN)')
    ..writeln('(ZERO PIECE : X ET Y SUR L AXE DU PLATEAU,'
        ' Z SUR LE SOMMET DU BRUT)')
    ..writeln('(ENVELOPPE PIECE : X ET Y PLUS OU MOINS ${f3(clearR)}'
        '  Z DE ${f3(-clearD)} A ${f3(kZSafe)})')
    ..writeln('(LE BRUT BALAYE UN CERCLE DE RAYON ${f3(diag)} MM EN TOURNANT'
        ' - VERIFIER LE DEGAGEMENT DU BERCEAU A)')
    ..writeln('G21 G90 G94 G17 G40')
    ..writeln('G54')
    ..writeln('M5')
    ..writeln('G0 Z${f3(kZSafe)}')
    ..writeln('M3 S1000')
    // Trois tranches d'une seconde plutôt qu'un `G4 P3` : pendant une
    // temporisation la carte n'acquitte rien, et un silence aussi long que
    // le watchdog du streaming passait pour un blocage au démarrage.
    ..writeln('G4 P1 (MONTEE EN REGIME 1 SUR 3)')
    ..writeln('G4 P1 (MONTEE EN REGIME 2 SUR 3)')
    ..writeln('G4 P1 (MONTEE EN REGIME 3 SUR 3)')
    ..writeln('(=== ETAPE 1 : EBAUCHE 3 AXES ===)')
    ..write(rough)
    ..writeln('(=== ETAPE 2 : FINITION DOME - TURN MILLING ===)')
    ..write(finish)
    ..writeln('(DEGAGEMENT)')
    ..writeln('G0 Z${f3(kZSafe)}')
    ..writeln('M5')
    ..writeln('M30');

  Directory('scratch').createSync(recursive: true);
  File('scratch/dome_r20.nc').writeAsStringSync(b.toString());

  stdout
    ..writeln('OK -> scratch/dome_r20.nc')
    ..writeln('EBAUCHE  : $nLayers couches, $nCircles contours,'
        ' ap=${f3(kAp)} ae=${f3(kAe)} F${f3(kFeedRough)},'
        ' degagement R${f3(clearR)} sur ${f3(clearD)} mm'
        '  -> ${roughMin.toStringAsFixed(1)} min')
    ..writeln('FINITION : $nLevels niveaux, dTheta=${f3(dTheta)} deg,'
        ' pas surface=${f3(stepReal)} mm,'
        ' crete=${crest.toStringAsFixed(4)} mm'
        '  -> ${finishMin.toStringAsFixed(1)} min')
    ..writeln('ENVELOPPE: X/Y +/-${f3(clearR)}   Z ${f3(-clearD)}..0.000'
        '   C 0..${f3(360.0 * nLevels)} deg')
    ..writeln('TOTAL    : ${totalMin.toStringAsFixed(1)} min'
        ' (${(totalMin / 60).toStringAsFixed(1)} h)');
}
