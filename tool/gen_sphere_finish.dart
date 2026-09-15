// Générateur de FINITION SPHÉRIQUE par turn-milling — Forgeron.
//
// Étape 2 d'un usinage de sphère : le brut est déjà ébauché en cylindre par
// l'étape 1. L'outil reste FIXE en X/Y/Z pendant que le plateau C fait un tour
// complet → un parallèle de la sphère par niveau. A reste à 0, donc seule la
// moitié HAUTE est usinée (jusqu'à l'équateur) : au-delà il faut basculer A,
// avec la compensation Y/Z du pivot (voir DOCS_5axes_continu_post_CAM.md).
//
// Corrige trois défauts du parcours écrit à la main :
//
//  1. GÉOMÉTRIE. Les rayons sont recalculés sur la vraie sphère, ET compensés
//     du rayon de la fraise BOULE. L'outil étant vertical, sa pointe ne touche
//     la surface qu'au sommet ; ailleurs le contact se fait sur le flanc de la
//     bille. Programmer le point de contact (ce que faisait l'ancien fichier)
//     donne une pièce fausse de plus de 2 mm à mi-hauteur.
//         centre bille = C_sphère + (R+ρ)·n      (n = normale, angle θ)
//         pointe outil = centre bille − (0,0,ρ)  (axe outil vertical)
//     d'où  X = (R+ρ)·sinθ   et   Z = (R+ρ)·cosθ − R − ρ.
//
//     L'échantillonnage est à pas ANGULAIRE constant, pas à pas Z constant :
//     à pas Z constant les passes sont espacées de 1,5 mm près du sommet et
//     de 8 µm à l'équateur — l'inverse de ce qu'il faut.
//
//  2. AVANCE. Une seule source de balayage (C360, sans arc XY redondant) et F
//     calculé en °/min pour une vitesse de surface constante. GRBL met les mm
//     et les degrés dans la même racine carrée : un « G2 <arc> C360 F120 »
//     passe 99,99 % de son temps en rotation et n'avance qu'à 2,6 mm/min.
//         F = v_surface × 180 / (π × r_contact)
//
//  3. ENCHAÎNEMENT. C absolu croissant (360, 720, 1080…) au lieu de repartir
//     de C0 à chaque niveau : plus de rembobinage d'un tour à vide entre deux
//     paliers, et plus d'inversion de sens sur la courroie (donc plus de jeu
//     repris à chaque palier).
//
// Lancer : dart run tool/gen_sphere_finish.dart
// Sortie : scratch/sphere_r15_finition.nc

import 'dart:io';
import 'dart:math' as math;

// ── Paramètres pièce / outil ────────────────────────────────────────────────

/// Rayon de la sphère (mm).
const kSphereR = 15.0;

/// Diamètre de la fraise BOULE (mm). C'est LE paramètre qui décide de la
/// justesse de la pièce : une valeur fausse décale tout le profil.
const kToolDia = 6.0;

/// Pas visé sur la surface entre deux parallèles (mm).
const kStepover = 0.5;

/// Angle polaire de fin : 90° = l'équateur, limite atteignable avec A=0.
const kThetaMax = 90.0;

// ── Paramètres de coupe ─────────────────────────────────────────────────────

/// Vitesse d'avance visée AU POINT DE CONTACT (mm/min).
const kVSurface = 120.0;

/// Plafond d'avance. 500 = la limite que le ForceGuard applique en mode 5AX
/// (MachiningMode.fiveAxis.maxFeedrate). Il ne distingue pas les mm/min des
/// °/min : tout F au-dessus serait réécrit en F500 pendant le streaming. On
/// plafonne donc ici pour que le fichier dise ce que la machine fera vraiment.
const kFeedCap = 500.0;

/// Avance des liaisons entre deux niveaux (mm/min).
const kFeedLink = 200.0;

/// Avance de plongée initiale (mm/min). Z est plafonné à 300 par la config.
const kFeedPlunge = 100.0;

/// Dégagement au-dessus du sommet, en coordonnées G54 (mm).
const kZSafe = 20.0;

String f3(double v) {
  final s = v.toStringAsFixed(3);
  return s == '-0.000' ? '0.000' : s;
}

void main() {
  final rho = kToolDia / 2;
  final rOffset = kSphereR + rho; // rayon du centre de la bille

  // Pas angulaire : on part du pas de surface visé, puis on arrondit au nombre
  // entier de niveaux qui couvre exactement 0..thetaMax.
  final dThetaTarget = kStepover / kSphereR * 180 / math.pi;
  final nLevels = (kThetaMax / dThetaTarget).ceil();
  final dTheta = kThetaMax / nLevels;
  final stepReal = kSphereR * dTheta * math.pi / 180;
  final crest = stepReal * stepReal / (8 * rho);

  var totalMin = 0.0;

  // On génère d'abord les niveaux pour pouvoir annoncer la durée en en-tête.
  final body = StringBuffer();
  for (var i = 1; i <= nLevels; i++) {
    final thetaDeg = dTheta * i;
    final t = thetaDeg * math.pi / 180;

    // Pointe de l'outil (compensation bille incluse).
    final x = rOffset * math.sin(t);
    final z = rOffset * math.cos(t) - rOffset;

    // Rayon du POINT DE CONTACT : c'est lui qui fixe la vitesse de surface.
    final rContact = kSphereR * math.sin(t);
    final feed = math.min(kVSurface * 180 / (math.pi * rContact), kFeedCap);

    final c = 360.0 * i;
    totalMin += 360.0 / feed;

    body.writeln('(NIVEAU $i/$nLevels - THETA ${f3(thetaDeg)} DEG'
        ' - RAYON CONTACT ${f3(rContact)})');
    if (i == 1) {
      body
        ..writeln('G0 X${f3(x)} Y0.000')
        ..writeln('G1 Z${f3(z)} F${f3(kFeedPlunge)}');
    } else {
      // Liaison en G1 : le segment droit entre deux parallèles est une corde
      // qui passe sous la surface finie. À ce pas angulaire l'écart est de
      // ~2 µm, mais on ne le parcourt pas en rapide pour autant.
      body.writeln('G1 X${f3(x)} Z${f3(z)} F${f3(kFeedLink)}');
    }
    body.writeln('G1 C${f3(c)} F${f3(feed)}');
  }

  final b = StringBuffer()
    ..writeln('(FORGERON - FINITION SPHERIQUE R${f3(kSphereR)}'
        ' - TURN-MILLING C CONTINU)')
    ..writeln('(ETAPE 2 : LE BRUT DOIT DEJA ETRE EBAUCHE EN CYLINDRE'
        ' PAR L ETAPE 1)')
    ..writeln('(OUTIL : FRAISE BOULE DIAM ${f3(kToolDia)}'
        ' - COMPENSATION DE RAYON INCLUSE)')
    ..writeln('(A RESTE A 0 : MOITIE HAUTE JUSQU A L EQUATEUR SEULEMENT.)')
    ..writeln('(LA MOITIE BASSE EXIGE DE BASCULER A + COMPENSER Y/Z DU PIVOT.)')
    ..writeln('(NIVEAUX : $nLevels - PAS SURFACE ${f3(stepReal)} MM'
        ' - CRETE THEORIQUE ${crest.toStringAsFixed(4)} MM)')
    ..writeln('(AVANCE CONTACT VISEE ${f3(kVSurface)} MM/MIN'
        ' - PLAFOND F${f3(kFeedCap)} = FORCEGUARD 5AX)')
    ..writeln('(C ABSOLU CROISSANT JUSQU A ${f3(360.0 * nLevels)} DEG'
        ' = $nLevels TOURS.)')
    ..writeln('(RIEN NE DOIT ETRE CABLE SUR LE PLATEAU.)')
    ..writeln('(DUREE ESTIMEE : ${totalMin.round()} MIN)')
    ..writeln('(ZERO PIECE : X ET Y SUR L AXE DU PLATEAU,'
        ' Z SUR LE SOMMET DU BRUT.)')
    ..writeln('(ENVELOPPE PIECE : X DE 0.000 A ${f3(rOffset)}'
        '  Z DE ${f3(-rOffset)} A ${f3(kZSafe)}  Y CONSTANT 0.)')
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
    ..write(body)
    ..writeln('(DEGAGEMENT)')
    ..writeln('G0 Z${f3(kZSafe)}')
    ..writeln('M5')
    ..writeln('M30');

  Directory('scratch').createSync(recursive: true);
  File('scratch/sphere_r15_finition.nc').writeAsStringSync(b.toString());

  stdout
    ..writeln('OK -> scratch/sphere_r15_finition.nc')
    ..writeln('niveaux=$nLevels  dTheta=${f3(dTheta)} deg'
        '  pas surface=${f3(stepReal)} mm')
    ..writeln('crete theorique=${crest.toStringAsFixed(4)} mm')
    ..writeln('X 0.000..${f3(rOffset)}   Z ${f3(-rOffset)}..0.000'
        '   C 0..${f3(360.0 * nLevels)} deg')
    ..writeln('duree estimee=${totalMin.toStringAsFixed(1)} min');
}
