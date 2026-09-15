"""Extraction du PROFIL d'une pièce de révolution depuis un maillage (STL).

Première brique du pipeline « du dessin au copeau » (phase 5.b du PLAN-IA),
côté maillage. Elle produit exactement le même objet que
`tool/extract_profile.dart` produit depuis un G-code : une liste de couples
(rayon, hauteur) décrivant la pièce. Les deux alimentent le même générateur.

    STL  ─┐
          ├─→  profil (r, z)  ─→  générateur  ─→  G-code
  G-code ─┘

Pourquoi commencer par le STL et non le STEP : la lecture de STEP exige un
noyau géométrique (OpenCASCADE), distribué en binaire précompilé pour des
versions stables de Python uniquement. Le STL, lui, se lit en numpy pur — voir
`stl_io.py`, aucune dépendance fragile. Et tout logiciel de CAO exporte du STL.

Limite assumée : un maillage est une approximation. L'écart au modèle exact
dépend de la finesse du maillage à l'export — c'est le prix à payer pour ne pas
dépendre d'un noyau géométrique. Le STEP viendra pour les cas où cette
approximation ne suffit pas.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from stl_io import read_stl, vertices_of


@dataclass(frozen=True)
class ProfilePoint:
    """Un point du profil, en coordonnées pièce."""

    r: float  # distance à l'axe de révolution (mm)
    z: float  # hauteur (mm)


@dataclass(frozen=True)
class RevolutionCheck:
    """Verdict du test de révolution, avec de quoi le justifier."""

    is_revolution: bool
    max_deviation: float  # écart radial maximal observé sur une tranche (mm)
    reason: str


def check_revolution(
    vertices: np.ndarray,
    n_slices: int = 40,
    n_sectors: int = 8,
    tolerance: float = 0.2,
) -> RevolutionCheck:
    """La pièce est-elle de révolution autour de Z ?

    Test : on découpe en tranches horizontales ET en secteurs angulaires, puis
    on compare le rayon extérieur d'un secteur à l'autre, à hauteur égale. Sur
    un solide de révolution il est identique partout ; sur un cube il passe du
    demi-côté au demi-diagonale.

    Une première version comparait les rayons À L'INTÉRIEUR d'une tranche. Ça
    ne teste pas la révolution mais la verticalité de la paroi : sur un dôme,
    la surface est quasi horizontale au sommet, donc une tranche y couvre une
    large plage de rayons et la pièce était refusée à tort.

    En cas de données insuffisantes pour conclure, on REFUSE : appliquer une
    stratégie de tournage-fraisage à une pièce qui n'est pas de révolution
    donnerait un parcours sans rapport avec la forme voulue.
    """
    v = np.asarray(vertices, dtype=float)
    if len(v) < 32:
        return RevolutionCheck(
            False, float("inf"), f"{len(v)} sommets : trop peu pour conclure"
        )

    radii = np.hypot(v[:, 0], v[:, 1])
    z = v[:, 2]
    phi = np.arctan2(v[:, 1], v[:, 0])

    z_min, z_max = float(z.min()), float(z.max())
    if z_max - z_min <= 0:
        return RevolutionCheck(False, float("inf"), "pièce plate : hauteur nulle")

    sector = np.floor((phi + np.pi) / (2 * np.pi) * n_sectors).astype(int)
    sector = np.clip(sector, 0, n_sectors - 1)

    edges = np.linspace(z_min, z_max, n_slices + 1)
    worst = 0.0
    evaluated = 0
    for i in range(n_slices):
        in_slice = (z >= edges[i]) & (z <= edges[i + 1])
        if in_slice.sum() < n_sectors:
            continue
        # Rayon extérieur de chaque secteur, à cette hauteur.
        per_sector = [
            radii[in_slice & (sector == k)].max()
            for k in range(n_sectors)
            if (in_slice & (sector == k)).any()
        ]
        if len(per_sector) < n_sectors // 2:
            continue  # trop peu de secteurs peuplés pour comparer
        spread = float(max(per_sector) - min(per_sector))
        worst = max(worst, spread)
        evaluated += 1

    if evaluated < 5:
        return RevolutionCheck(
            False,
            float("inf"),
            f"seulement {evaluated} tranche(s) exploitable(s) : maillage trop "
            "grossier pour conclure",
        )

    if worst <= tolerance:
        return RevolutionCheck(
            True,
            worst,
            f"écart de rayon entre secteurs ≤ {worst:.3f} mm "
            f"sur {evaluated} tranches",
        )
    return RevolutionCheck(
        False,
        worst,
        f"écart de rayon entre secteurs jusqu'à {worst:.3f} mm "
        f"(> {tolerance} mm) : pas de révolution autour de Z",
    )


def extract_profile(
    vertices: np.ndarray, n_slices: int = 200
) -> list[ProfilePoint]:
    """Profil méridien d'une pièce de révolution autour de Z.

    Pour chaque tranche horizontale, on retient le rayon MAXIMAL : c'est la
    surface extérieure, celle que l'outil doit suivre. Un rayon moyen lisserait
    la forme et rétrécirait la pièce.
    """
    v = np.asarray(vertices)
    radii = np.hypot(v[:, 0], v[:, 1])
    z = v[:, 2]
    z_min, z_max = float(z.min()), float(z.max())

    edges = np.linspace(z_min, z_max, n_slices + 1)
    profile: list[ProfilePoint] = []
    for i in range(n_slices):
        in_slice = (z >= edges[i]) & (z <= edges[i + 1])
        if not in_slice.any():
            continue
        z_mid = float((edges[i] + edges[i + 1]) / 2)
        profile.append(ProfilePoint(float(radii[in_slice].max()), z_mid))

    # Du sommet vers la base : l'ordre qu'attendent les générateurs.
    profile.sort(key=lambda p: p.z, reverse=True)
    return profile


def load(path: str) -> np.ndarray:
    """Charge un STL et retourne ses sommets uniques, forme (m, 3)."""
    return vertices_of(read_stl(path))


def write_csv(profile: list[ProfilePoint], path: str) -> None:
    """Même format que `tool/extract_profile.dart`, pour que les deux sources
    soient interchangeables en entrée du générateur."""
    with open(path, "w", encoding="utf-8") as f:
        f.write("rayon_mm,hauteur_mm\n")
        for p in profile:
            f.write(f"{p.r:.4f},{p.z:.4f}\n")


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser(
        description="Extrait le profil d'une pièce de révolution depuis un STL."
    )
    ap.add_argument("fichier", help="le maillage à analyser (.stl, .obj, .ply…)")
    ap.add_argument("--slices", type=int, default=200, help="nombre de tranches")
    ap.add_argument(
        "--tolerance",
        type=float,
        default=0.2,
        help="dispersion radiale admise pour conclure à une révolution (mm)",
    )
    args = ap.parse_args()

    verts = load(args.fichier)
    print(f"maillage : {len(verts)} sommets")

    verdict = check_revolution(verts, tolerance=args.tolerance)
    print(f"révolution : {'OUI' if verdict.is_revolution else 'NON'} — {verdict.reason}")
    if not verdict.is_revolution:
        print("Aucun profil produit : voir PLAN-IA phase 5.c pour le cas général.")
        return 1

    profile = extract_profile(verts, n_slices=args.slices)
    out = args.fichier.rsplit(".", 1)[0] + "_profil.csv"
    write_csv(profile, out)

    r_max = max(p.r for p in profile)
    hauteur = profile[0].z - profile[-1].z
    print(f"{len(profile)} points -> {out}")
    print(f"rayon maximal : {r_max:.3f} mm    hauteur : {abs(hauteur):.3f} mm")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
