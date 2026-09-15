"""Vérifie la boucle STL → profil sur des géométries dont on connaît la réponse.

Le dôme R20 — la pièce que la machine a réellement usinée — est fabriqué par
révolution d'un profil analytique, écrit en STL, relu, puis comparé au cercle
théorique. Aucun fichier externe, aucune dépendance en dehors de numpy : le
test se suffit à lui-même et ne dépend d'aucune bibliothèque fragile.

Lancer :  pipeline/.venv/Scripts/python pipeline/test_mesh_profile.py
"""

from __future__ import annotations

import math
import tempfile
from pathlib import Path

import numpy as np

from mesh_profile import check_revolution, extract_profile, load
from stl_io import revolve, write_stl

R = 20.0  # rayon du dôme, comme dome_r20.nc


def dome_profile(n: int = 120) -> np.ndarray:
    """Profil méridien d'un dôme R20 : sommet en Z=0, base en Z=-20.

    Échantillonné à pas angulaire constant, comme le fait le générateur : c'est
    ce qui donne un pas régulier sur la surface.
    """
    theta = np.linspace(0.0, np.pi / 2, n)
    return np.column_stack([R * np.sin(theta), R * np.cos(theta) - R])


def cube_triangles(side: float = 40.0, n: int = 12) -> np.ndarray:
    """Cube dont chaque face est subdivisée en n×n quads.

    Un cube réduit à ses 8 sommets serait refusé pour cause de maillage trop
    grossier — verdict correct, mais pour la mauvaise raison. On veut vérifier
    que le test REFUSE parce que la forme n'est pas de révolution, ce qui exige
    un maillage réaliste, comparable à ce que sort un logiciel de CAO.
    """
    h = side / 2
    t = np.linspace(-h, h, n + 1)
    a, b = np.meshgrid(t, t, indexing="ij")
    flat = np.full_like(a, h)

    tris: list[list[np.ndarray]] = []
    for axis in range(3):
        for sign in (-1.0, 1.0):
            # Grille de points sur la face perpendiculaire à `axis`.
            comp = [a, b]
            comp.insert(axis, flat * sign)
            grid = np.stack(comp, axis=-1)  # (n+1, n+1, 3)
            for i in range(n):
                for j in range(n):
                    p00, p10 = grid[i, j], grid[i + 1, j]
                    p11, p01 = grid[i + 1, j + 1], grid[i, j + 1]
                    tris.append([p00, p10, p11])
                    tris.append([p00, p11, p01])
    return np.asarray(tris, dtype=np.float64)


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="forgeron_"))
    ok = True

    # ── 1. Le cube doit être REFUSÉ ────────────────────────────────────────
    cube_path = tmp / "cube.stl"
    write_stl(str(cube_path), cube_triangles())
    verdict = check_revolution(load(str(cube_path)))
    print(f"cube      : révolution={verdict.is_revolution}  ({verdict.reason})")
    if verdict.is_revolution:
        print("  ÉCHEC : un cube ne doit pas passer pour une pièce de révolution.")
        ok = False

    # ── 2. Le dôme doit être ACCEPTÉ ───────────────────────────────────────
    dome_path = tmp / "dome_r20.stl"
    write_stl(str(dome_path), revolve(dome_profile(), n_around=96))
    verts = load(str(dome_path))
    verdict = check_revolution(verts)
    print(f"dôme R20  : révolution={verdict.is_revolution}  ({verdict.reason})")
    if not verdict.is_revolution:
        print("  ÉCHEC : le dôme doit être reconnu comme pièce de révolution.")
        return 1

    # ── 3. Le profil doit coller au cercle théorique ───────────────────────
    profile = extract_profile(verts, n_slices=200)
    # Surface exacte : r² + (z+R)² = R². On écarte les tranches extrêmes, où le
    # rayon max d'une tranche surestime structurellement le cercle (la facette
    # couvre une plage de z entière près du pôle et de l'équateur).
    errors = [abs(math.hypot(p.r, p.z + R) - R) for p in profile[2:-2]]
    moyenne = sum(errors) / len(errors)
    maximum = max(errors)

    r_max = max(p.r for p in profile)
    hauteur = abs(profile[0].z - profile[-1].z)

    print()
    print(f"sommets lus      : {len(verts)}")
    print(f"points du profil : {len(profile)}")
    print(f"rayon maximal    : {r_max:.3f} mm   (attendu {R:.3f})")
    print(f"hauteur          : {hauteur:.3f} mm   (attendu {R:.3f})")
    print(f"écart moyen au cercle   : {moyenne * 1000:.1f} µm")
    print(f"écart maximal au cercle : {maximum * 1000:.1f} µm")

    # Seuil : 0,1 mm, l'ordre de grandeur d'une passe de finition.
    if maximum > 0.1:
        print("  ÉCHEC : écart supérieur à 0,1 mm.")
        ok = False
    if abs(r_max - R) > 0.1 or abs(hauteur - R) > 0.3:
        print("  ÉCHEC : dimensions hors tolérance.")
        ok = False

    # ── 4. Aller-retour STL : ce qu'on écrit est ce qu'on relit ────────────
    tris = revolve(dome_profile(40), n_around=32)
    rt_path = tmp / "roundtrip.stl"
    write_stl(str(rt_path), tris)
    from stl_io import read_stl

    relu = read_stl(str(rt_path))
    ecart = float(np.abs(relu - tris).max())
    print(f"aller-retour STL : écart max {ecart * 1000:.3f} µm "
          f"({len(tris)} triangles)")
    # float32 en STL : ~1 µm de quantification sur des valeurs de l'ordre de 20 mm.
    if ecart > 0.01:
        print("  ÉCHEC : l'aller-retour STL perd trop de précision.")
        ok = False

    print()
    print("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
