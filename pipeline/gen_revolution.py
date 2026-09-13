"""Génère le G-code d'une pièce de RÉVOLUTION à partir de son profil.

C'est le maillon qui ferme la chaîne du PLAN-IA :

    STL  ─┐                                    ┌─→ ébauche 3 axes
          ├─→ profil (r, z) ─→ CE MODULE ──────┤
  G-code ─┘                                    └─→ finition 5 axes

Le profil peut venir de `mesh_profile.py` (un STL) ou de
`tool/extract_profile.dart` (un G-code existant) : même format, deux points
d'entrée. Aucune formule de sphère ici — la forme est celle du profil fourni,
quelle qu'elle soit.

── Compensation d'outil ────────────────────────────────────────────────────

L'outil est une fraise BOULE d'axe vertical. Sa pointe ne touche la surface
qu'aux endroits où la normale est verticale ; ailleurs le contact se fait sur
le flanc de la bille. Pour un point de contact P de normale extérieure n :

    centre bille = P + ρ·n
    pointe outil = centre bille − (0, ρ)

Programmer P directement — l'erreur du parcours écrit à la main avant ce
module — donne une pièce fausse de plus de 2 mm à mi-hauteur sur un dôme R20.

── Avance ──────────────────────────────────────────────────────────────────

GRBL met les millimètres et les degrés dans la même racine carrée. Un bloc qui
mêle un mot linéaire et un mot rotatif voit son F réparti entre les deux :
sur un `G2 <arc> C360 F120`, l'avance linéaire réelle tombe à 2,6 mm/min. Ce
module n'émet donc JAMAIS un tel bloc, et calcule F en °/min pour la rotation :

    F = v_surface × 180 / (π × r_contact)
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np


# ── Paramètres de coupe ─────────────────────────────────────────────────────


@dataclass(frozen=True)
class CutParams:
    """Conditions de coupe. Les valeurs par défaut sont celles qui ont produit
    le dôme R20 sans vibration, en 3 h 35 — mesurées, pas supposées."""

    tool_dia: float = 6.0       # fraise boule (mm)
    stock: float = 0.5          # surépaisseur laissée par l'ébauche (mm)
    ap: float = 0.5             # profondeur de passe (mm)
    ae: float = 1.0             # engagement radial (mm)
    feed_rough: float = 500.0   # avance d'ébauche (mm/min)
    feed_plunge: float = 100.0  # approche au contact (mm/min)
    feed_link: float = 200.0    # liaisons entre niveaux (mm/min)
    v_surface: float = 120.0    # vitesse visée au point de contact (mm/min)
    feed_cap: float = 500.0     # plafond ForceGuard en mode 5 axes
    stepover: float = 0.4       # pas visé sur la surface (mm)
    z_safe: float = 20.0        # dégagement au-dessus de la pièce (mm)
    approach_gap: float = 1.0   # dégagement entre couches (mm)
    spindle: int = 1000         # S de la broche (relais tout-ou-rien)

    # ── Le brut ────────────────────────────────────────────────────────
    # Rayon du barreau dont la pièce est tirée (mm). `None` = non déclaré.
    #
    # Sans cette valeur, l'ébauche balaie toute l'enveloppe de dégagement —
    # jusqu'à r_max + 2ρ + 2 — parce que le générateur n'a aucun moyen de
    # savoir où la matière s'arrête. C'est le choix SÛR : couper de l'air
    # coûte du temps, laisser de la matière la fait rencontrer à la finition,
    # à 120 mm/min, par le flanc de la bille.
    #
    # Mais ce choix sûr est cher. Sur le dôme R20 de référence tiré d'un
    # barreau Ø42, il représente 83 des 218 minutes du programme — 38 %
    # passées à tourner dans le vide. Déclarer le barreau les supprime sans
    # toucher à une seule condition de coupe.
    stock_radius: float | None = None


def f3(v: float) -> str:
    s = f"{v:.3f}"
    return "0.000" if s == "-0.000" else s


# ── Profil ──────────────────────────────────────────────────────────────────


def load_profile_csv(path: str) -> np.ndarray:
    """Charge un profil (rayon, hauteur), trié du sommet vers la base."""
    rows = np.loadtxt(path, delimiter=",", skiprows=1)
    prof = np.atleast_2d(rows)[:, :2].astype(float)
    return prof[np.argsort(-prof[:, 1])]


def tool_path_points(profile: np.ndarray, rho: float) -> np.ndarray:
    """Positions de la POINTE de l'outil le long du profil.

    Offset extérieur de ρ le long de la normale, puis descente de ρ pour passer
    du centre de la bille à sa pointe. Exactement l'inverse de l'extraction de
    profil — les deux opérations doivent se composer en l'identité.
    """
    prof = np.asarray(profile, dtype=float)
    n = len(prof)
    out = np.empty_like(prof)
    for i in range(n):
        a = prof[max(i - 1, 0)]
        b = prof[min(i + 1, n - 1)]
        tr, tz = b[0] - a[0], b[1] - a[1]
        norm = math.hypot(tr, tz)
        if norm == 0:
            out[i] = prof[i]
            continue
        tr, tz = tr / norm, tz / norm
        # Normale = tangente tournée de 90°, orientée VERS L'EXTÉRIEUR
        # (r croissant) : c'est le côté où se trouve l'outil.
        nr, nz = -tz, tr
        if nr < 0:
            nr, nz = -nr, -nz
        out[i] = (prof[i][0] + rho * nr, prof[i][1] + rho * nz - rho)
    return out


def find_undercut(profile: np.ndarray, tolerance: float = 0.02) -> tuple[bool, float, float]:
    """Le profil comporte-t-il une CONTRE-DÉPOUILLE ?

    L'outil est vertical et A reste à 0 : il ne peut atteindre un point que si
    rien ne le surplombe. Le rayon doit donc croître — ou rester égal — à
    mesure qu'on descend. Partout où il DÉCROÎT en descendant, la matière
    au-dessus fait ombrage : la zone est inatteignable, et un parcours qui
    prétend l'usiner ferait forcer l'outil dans la pièce.

    C'est le cas d'un vase à panse renflée, d'une gorge, d'un col rentrant.
    Y remédier suppose de basculer l'axe A, donc de compenser le pivot — hors
    de portée de ce générateur (voir PLAN-IA, RTCP).

    Retourne (présence, hauteur de la première contre-dépouille, ampleur max).
    """
    prof = np.asarray(profile, dtype=float)
    order = np.argsort(-prof[:, 1])  # du sommet vers la base
    r = prof[order, 0]
    z = prof[order, 1]

    running_max = np.maximum.accumulate(r)
    deficit = running_max - r  # > 0 : ce point est surplombé
    bad = deficit > tolerance
    if not bad.any():
        return False, 0.0, 0.0
    first = int(np.argmax(bad))
    return True, float(z[first]), float(deficit.max())


def radius_at_depth(profile: np.ndarray, depth: float) -> float:
    """Rayon de la pièce à la profondeur [depth] sous le sommet."""
    z_top = profile[0][1]
    z = z_top - depth
    zs = profile[:, 1][::-1]  # croissant, pour np.interp
    rs = profile[:, 0][::-1]
    return float(np.interp(z, zs, rs))


def resample_by_arclength(profile: np.ndarray, step: float) -> np.ndarray:
    """Rééchantillonne le profil à pas constant SUR LA SURFACE.

    Un pas constant en Z donnerait des passes serrées là où la paroi est
    verticale et très espacées là où elle est plate — l'inverse de ce qu'il
    faut. C'est le long de la courbe que le pas doit être régulier, car c'est
    lui qui fixe la hauteur de crête laissée entre deux passes.
    """
    prof = np.asarray(profile, dtype=float)
    seg = np.hypot(np.diff(prof[:, 0]), np.diff(prof[:, 1]))
    s = np.concatenate([[0.0], np.cumsum(seg)])
    total = s[-1]
    if total <= 0:
        return prof
    n = max(2, int(math.ceil(total / step)) + 1)
    targets = np.linspace(0.0, total, n)
    return np.column_stack(
        [np.interp(targets, s, prof[:, 0]), np.interp(targets, s, prof[:, 1])]
    )


# ── Émission du G-code ──────────────────────────────────────────────────────


def _circle(out: list[str], r: float) -> None:
    """Cercle complet en quatre quarts G3.

    G3 et non G2 : en G17, G2 est HORAIRE. Partant de (r, 0), un
    « G2 X0 Y{r} I-{r} J0 » ne fait pas un quart de tour mais 270°.
    """
    s = f3(r)
    out += [
        f"G3 X0.000 Y{s} I-{s} J0.000",
        f"G3 X-{s} Y0.000 I0.000 J-{s}",
        f"G3 X0.000 Y-{s} I{s} J0.000",
        f"G3 X{s} Y0.000 I0.000 J{s}",
    ]


def _helix(out: list[str], r: float, z0: float, z1: float) -> None:
    """Un tour en hélice descendante : remplace la plongée verticale.

    Le centre d'une fraise boule a une vitesse de coupe nulle — il racle au
    lieu de couper. Étaler la descente sur toute la circonférence supprime le
    geste le plus vibrant du programme.
    """
    s = f3(r)
    dz = (z1 - z0) / 4
    out += [
        f"G3 X0.000 Y{s} Z{f3(z0 + dz)} I-{s} J0.000",
        f"G3 X-{s} Y0.000 Z{f3(z0 + 2 * dz)} I0.000 J-{s}",
        f"G3 X0.000 Y-{s} Z{f3(z0 + 3 * dz)} I{s} J0.000",
        f"G3 X{s} Y0.000 Z{f3(z1)} I0.000 J{s}",
    ]


def generate(profile: np.ndarray, p: CutParams = CutParams()) -> tuple[str, dict]:
    """Programme complet : ébauche 3 axes puis finition 5 axes.

    Retourne le G-code et un rapport (durées, enveloppe, nombre de passes) —
    c'est le rapport que l'agent lit, jamais les milliers de lignes.
    """
    rho = p.tool_dia / 2
    prof = np.asarray(profile, dtype=float)
    r_max = float(prof[:, 0].max())
    z_top = float(prof[:, 1].max())
    z_bot = float(prof[:, 1].min())
    height = z_top - z_bot

    # Le dégagement doit laisser passer la bille ET la queue de l'outil quand
    # celui-ci travaille au rayon maximal : R + 2ρ, plus 2 mm de marge.
    clear_r = r_max + 2 * rho + 2.0
    clear_d = height + rho + 2.0

    # Rayon au-delà duquel il n'y a rien à couper. La bille touche le flanc
    # du barreau quand l'axe de l'outil est à r_brut + ρ : plus loin, les
    # cercles ne rencontrent rien.
    rough_r = clear_r if p.stock_radius is None else min(clear_r, p.stock_radius + rho)

    # Sert uniquement à chiffrer, dans le rapport, ce qu'un brut déclaré ferait
    # gagner — pour que l'opérateur sache que la question vaut d'être posée.
    # Quand il EST déclaré, il n'y a par construction plus rien à gagner :
    # l'ébauche s'arrête déjà où la matière s'arrête.
    tightest_r = (
        rough_r if p.stock_radius is not None else min(clear_r, r_max + p.stock + rho)
    )

    undercut, z_first, amount = find_undercut(prof)
    if undercut:
        # On n'interrompt pas : le programme reste utile pour la partie
        # atteignable, et l'opérateur doit savoir exactement ce qui manquera.
        warn = (
            f"(!!! CONTRE-DEPOUILLE A PARTIR DE Z{f3(z_first)} -"
            f" JUSQU A {f3(amount)} MM DE MATIERE INATTEIGNABLE)"
        )
    else:
        warn = None

    rough: list[str] = []
    rough_min = 0.0
    air_min = 0.0
    n_air = 0
    n_layers = int(math.ceil(clear_d / p.ap))
    n_circles = 0
    first = True

    for k in range(1, n_layers + 1):
        d = min(p.ap * k, clear_d)
        d_prev = min(p.ap * (k - 1), clear_d)
        # La bille mord jusqu'à ρ en deçà de la pointe : partir à
        # r_pièce + surépaisseur + ρ garde la matière à conserver hors d'atteinte.
        x_min = radius_at_depth(prof, d) + p.stock + rho
        if x_min > rough_r:
            continue

        rough.append(
            f"(COUCHE {k}/{n_layers} - Z{f3(-d)}"
            f" - DE X{f3(x_min)} A X{f3(rough_r)})"
        )
        if first:
            rough += [
                f"G0 X{f3(x_min)} Y0.000",
                f"G0 Z{f3(p.approach_gap)}",
                f"G1 Z{f3(-d_prev)} F{f3(p.feed_plunge)}",
            ]
            first = False
        else:
            # On arrive à 1 mm au-dessus du fond précédent, au rayon extérieur.
            rough += [
                f"G0 X{f3(x_min)} Y0.000",
                f"G1 Z{f3(-d_prev)} F{f3(p.feed_plunge)}",
            ]
        rough_min += p.approach_gap / p.feed_plunge

        rough.append(f"F{f3(p.feed_rough)}")
        _helix(rough, x_min, -d_prev, -d)
        _circle(rough, x_min)
        rough_min += 2 * 2 * math.pi * x_min / p.feed_rough
        n_circles += 2

        r = x_min
        while r < rough_r:
            r = min(r + p.ae, rough_r)
            rough.append(f"G1 X{f3(r)} Y0.000")
            _circle(rough, r)
            rough_min += 2 * math.pi * r / p.feed_rough
            n_circles += 1
            # Ce même cercle aurait-il été coupé dans le vide, si le barreau
            # était au plus juste ? On cumule pour le rapport.
            if r > tightest_r:
                air_min += 2 * math.pi * r / p.feed_rough
                n_air += 1
        rough.append(f"G0 Z{f3(-d + p.approach_gap)}")

    rough.append(f"G0 Z{f3(p.z_safe)}")

    # ── Finition : un tour de plateau par niveau ────────────────────────────
    levels = resample_by_arclength(prof, p.stepover)
    tips = tool_path_points(levels, rho)

    finish: list[str] = []
    finish_min = 0.0
    for i, ((r_c, _z_c), (x, z)) in enumerate(zip(levels, tips), start=1):
        # La vitesse de surface dépend du rayon du POINT DE CONTACT, pas de la
        # position de la pointe.
        r_contact = max(float(r_c), 1e-6)
        feed = min(p.v_surface * 180.0 / (math.pi * r_contact), p.feed_cap)
        finish_min += 360.0 / feed
        finish.append(
            f"(NIVEAU {i}/{len(levels)} - RAYON CONTACT {f3(r_contact)})"
        )
        if i == 1:
            finish += [
                f"G0 X{f3(x)} Y0.000",
                f"G1 Z{f3(z)} F{f3(p.feed_plunge)}",
            ]
        else:
            finish.append(f"G1 X{f3(x)} Z{f3(z)} F{f3(p.feed_link)}")
        # Bloc de rotation PUR : aucun mot linéaire, F en degrés par minute.
        finish.append(f"G1 C{f3(360.0 * i)} F{f3(feed)}")

    total = rough_min + finish_min
    crest = p.stepover**2 / (8 * rho)

    head = [
        "(FORGERON - PIECE DE REVOLUTION - PROFIL LIBRE)",
        f"(RAYON MAXIMAL {f3(r_max)} - HAUTEUR {f3(height)})",
        f"(OUTIL : FRAISE BOULE DIAM {f3(p.tool_dia)}"
        " - COMPENSATION DE RAYON INCLUSE)",
        f"(EBAUCHE 3 AXES : {n_layers} COUCHES, {n_circles} CONTOURS,"
        f" AP {f3(p.ap)} AE {f3(p.ae)}, SUREPAISSEUR {f3(p.stock)})",
        (f"(BRUT DECLARE : BARREAU RAYON {f3(p.stock_radius)}"
         f" - EBAUCHE JUSQU A X{f3(rough_r)})")
        if p.stock_radius is not None else
        (f"(BRUT NON DECLARE : EBAUCHE JUSQU A X{f3(rough_r)} PAR SECURITE"
         f" - {n_air} CONTOURS Y TOURNENT DANS LE VIDE SI LE BARREAU FAIT"
         f" MOINS DE {f3(tightest_r - rho)} DE RAYON,"
         f" SOIT {round(air_min)} MIN)"),
        "(ENTREE EN HELICE - AUCUNE PLONGEE VERTICALE DANS LA MATIERE)",
        f"(FINITION 5 AXES : {len(levels)} NIVEAUX,"
        f" PAS SURFACE {f3(p.stepover)}, CRETE {crest:.4f})",
        "(A RESTE A 0 SUR TOUT LE PROGRAMME - PAS DE RTCP REQUIS)",
        f"(C ABSOLU CROISSANT JUSQU A {f3(360.0 * len(levels))} DEG"
        f" = {len(levels)} TOURS - RIEN NE DOIT ETRE CABLE SUR LE PLATEAU)",
        f"(DUREE ESTIMEE : {round(rough_min)} MIN EBAUCHE"
        f" + {round(finish_min)} MIN FINITION = {round(total)} MIN)",
        "(ZERO PIECE : X ET Y SUR L AXE DU PLATEAU, Z SUR LE SOMMET)",
        *( [warn, "(L OUTIL EST VERTICAL ET A RESTE A 0 :"
                  " CETTE ZONE NE SERA PAS USINEE.)"] if warn else [] ),
        f"(ENVELOPPE : X ET Y PLUS OU MOINS {f3(clear_r)}"
        f"  Z DE {f3(-clear_d)} A {f3(p.z_safe)})",
        "G21 G90 G94 G17 G40",
        "G54",
        "M5",
        f"G0 Z{f3(p.z_safe)}",
        f"M0 (VERIFIER FRAISE BOULE DIAM {f3(p.tool_dia)},"
        " BRIDAGE ET ZERO PIECE PUIS REPRENDRE)",
        f"M3 S{p.spindle}",
        # Trois tranches d'une seconde : pendant une temporisation la carte
        # n'acquitte rien, et un silence aussi long que le watchdog du
        # streaming passait pour un blocage au démarrage.
        "G4 P1 (MONTEE EN REGIME 1 SUR 3)",
        "G4 P1 (MONTEE EN REGIME 2 SUR 3)",
        "G4 P1 (MONTEE EN REGIME 3 SUR 3)",
        "(=== ETAPE 1 : EBAUCHE 3 AXES ===)",
    ]
    tail = [
        "(DEGAGEMENT)",
        f"G0 Z{f3(p.z_safe)}",
        "M5",
        "M30",
    ]
    lines = head + rough + ["(=== ETAPE 2 : FINITION - TURN MILLING ===)"] + finish + tail

    report = {
        "rayon_max_mm": r_max,
        "hauteur_mm": height,
        "enveloppe_r_mm": clear_r,
        "profondeur_mm": clear_d,
        "couches_ebauche": n_layers,
        "contours_ebauche": n_circles,
        "brut_rayon_mm": p.stock_radius,
        "ebauche_rayon_mm": rough_r,
        # Ce que coûte le fait de ne pas savoir où s'arrête la matière.
        # Nul dès qu'un brut au plus juste est déclaré.
        "contours_a_vide": n_air,
        "duree_a_vide_min": air_min,
        "niveaux_finition": len(levels),
        "crete_mm": crest,
        "duree_ebauche_min": rough_min,
        "duree_finition_min": finish_min,
        "duree_totale_min": total,
        "rotation_totale_deg": 360.0 * len(levels),
        "contre_depouille": undercut,
        "contre_depouille_z_mm": z_first if undercut else None,
        "contre_depouille_ampleur_mm": amount if undercut else None,
    }
    return "\n".join(lines) + "\n", report


def main() -> int:
    import argparse
    import json

    ap = argparse.ArgumentParser(
        description="Génère le G-code d'une pièce de révolution depuis un profil."
    )
    ap.add_argument("profil", help="CSV (rayon_mm, hauteur_mm)")
    ap.add_argument("-o", "--sortie", help="fichier .nc (défaut : <profil>.nc)")
    ap.add_argument("--outil", type=float, default=6.0, help="diamètre fraise boule")
    ap.add_argument("--ap", type=float, default=0.5)
    ap.add_argument("--ae", type=float, default=1.0)
    ap.add_argument("--stepover", type=float, default=0.4)
    ap.add_argument(
        "--brut-rayon",
        type=float,
        default=None,
        help="rayon du barreau (mm) — sans lui l'ébauche balaie toute "
        "l'enveloppe par sécurité, et coupe de l'air",
    )
    args = ap.parse_args()

    prof = load_profile_csv(args.profil)
    params = CutParams(
        tool_dia=args.outil,
        ap=args.ap,
        ae=args.ae,
        stepover=args.stepover,
        stock_radius=args.brut_rayon,
    )
    gcode, report = generate(prof, params)

    out = args.sortie or args.profil.rsplit(".", 1)[0] + ".nc"
    with open(out, "w", encoding="utf-8") as f:
        f.write(gcode)

    print(f"{len(gcode.splitlines())} lignes -> {out}")
    if report["brut_rayon_mm"] is None and report["duree_a_vide_min"] > 1.0:
        print(
            f"AVIS : brut non déclaré. {report['contours_a_vide']} contours "
            f"({round(report['duree_a_vide_min'])} min) tournent dans le vide "
            f"si le barreau fait moins de "
            f"{report['ebauche_rayon_mm'] - args.outil / 2:.1f} mm de rayon. "
            f"Relancer avec --brut-rayon pour les supprimer."
        )
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
