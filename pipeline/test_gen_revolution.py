"""Valide le générateur à profil libre contre une géométrie connue.

Le dôme R20 est le seul cas dont on connaisse la vérité de bout en bout : sa
formule est analytique, et la machine l'a réellement usiné en 3 h 35. On vérifie
donc que le générateur généraliste, qui ne sait rien des sphères, retrouve
exactement les coordonnées que la formule impose.

On vérifie aussi la règle qui a coûté le plus cher sur cette machine : aucun
bloc ne doit mêler un mot linéaire et un mot rotatif.

Lancer :  cd pipeline && .venv/Scripts/python test_gen_revolution.py
"""

from __future__ import annotations

import math
import re
import tempfile
from pathlib import Path

import numpy as np

from gen_revolution import CutParams, generate, tool_path_points
from mesh_profile import check_revolution, extract_profile, load
from stl_io import revolve, write_stl

R = 20.0
RHO = 3.0


def dome_profile(n: int = 400) -> np.ndarray:
    """Profil méridien exact d'un dôme R20, sommet en Z=0."""
    theta = np.linspace(0.0, np.pi / 2, n)
    return np.column_stack([R * np.sin(theta), R * np.cos(theta) - R])


def check(label: str, ok: bool, detail: str = "") -> bool:
    print(f"  {'OK  ' if ok else 'ECHEC'} {label}{('  — ' + detail) if detail else ''}")
    return ok


def main() -> int:
    ok = True
    prof = dome_profile()

    # ── 1. Compensation d'outil : la pointe suit la formule analytique ─────
    # Sur une sphère R de sommet 0, la pointe d'une bille ρ vaut
    #   X = (R+ρ)·sinθ      Z = (R+ρ)·cosθ − (R+ρ)
    print("\n1. Compensation du rayon de bille")
    tips = tool_path_points(prof, RHO)
    theta = np.linspace(0.0, np.pi / 2, len(prof))
    x_th = (R + RHO) * np.sin(theta)
    z_th = (R + RHO) * np.cos(theta) - (R + RHO)
    # Les extrémités reposent sur une normale estimée en différences décentrées.
    err_x = float(np.abs(tips[1:-1, 0] - x_th[1:-1]).max())
    err_z = float(np.abs(tips[1:-1, 1] - z_th[1:-1]).max())
    ok &= check("X suit (R+ρ)·sinθ", err_x < 0.01, f"écart max {err_x * 1000:.1f} µm")
    ok &= check("Z suit (R+ρ)·cosθ−(R+ρ)", err_z < 0.01,
                f"écart max {err_z * 1000:.1f} µm")

    # Sans compensation, l'erreur atteint plusieurs millimètres : on le montre
    # pour que le chiffre reste sous les yeux.
    naive = float(np.abs(prof[:, 0] - x_th).max())
    print(f"       (programmer le point de contact donnerait {naive:.2f} mm d'erreur)")

    # ── 2. Le programme généré ─────────────────────────────────────────────
    print("\n2. Programme généré")
    gcode, report = generate(prof, CutParams(tool_dia=2 * RHO))
    lines = gcode.splitlines()
    ok &= check("le programme n'est pas vide", len(lines) > 100,
                f"{len(lines)} lignes")
    ok &= check("rayon maximal retrouvé", abs(report["rayon_max_mm"] - R) < 1e-6,
                f"{report['rayon_max_mm']:.3f} mm")
    ok &= check("hauteur retrouvée", abs(report["hauteur_mm"] - R) < 1e-6,
                f"{report['hauteur_mm']:.3f} mm")
    ok &= check("enveloppe = R + 2ρ + 2",
                abs(report["enveloppe_r_mm"] - (R + 2 * RHO + 2)) < 1e-6,
                f"{report['enveloppe_r_mm']:.3f} mm")

    # ── 3. Aucun bloc ne mêle millimètres et degrés ────────────────────────
    # C'est la règle qui a coûté 2 h 10 sur le parcours écrit à la main : GRBL
    # répartit F sur √(mm² + deg²), et l'avance linéaire s'effondre.
    print("\n3. Séparation des mots linéaires et rotatifs")
    coupables = [
        ln for ln in lines
        if re.search(r"\bC-?\d", ln) and re.search(r"\b[XYZ]-?\d", ln)
    ]
    ok &= check("aucun bloc mixte mm/degrés", not coupables,
                f"{len(coupables)} bloc(s) fautif(s)")

    # ── 4. Les niveaux de finition suivent la théorie ──────────────────────
    print("\n4. Coordonnées de finition")
    fin = []
    for i, ln in enumerate(lines):
        if ln.startswith("(NIVEAU "):
            for nxt in lines[i + 1:i + 4]:
                mx = re.search(r"X(-?[\d.]+)", nxt)
                mz = re.search(r"Z(-?[\d.]+)", nxt)
                if mx:
                    fin.append([float(mx.group(1)), float(mz.group(1)) if mz else None])
                    break
    fin = [p for p in fin if p[1] is not None]
    # Chaque pointe doit être à R+ρ du centre de la sphère, décalée de ρ vers le bas.
    ecarts = [
        abs(math.hypot(x, z + RHO + R) - (R + RHO)) for x, z in fin[1:-1]
    ]
    pire = max(ecarts) if ecarts else float("inf")
    ok &= check(f"les {len(fin)} niveaux sont sur la sphère décalée",
                pire < 0.02, f"écart max {pire * 1000:.1f} µm")

    # ── 5. Chaîne complète : STL → profil → G-code ─────────────────────────
    print("\n5. Chaîne complète depuis un STL")
    tmp = Path(tempfile.mkdtemp(prefix="forgeron_"))
    stl = tmp / "dome.stl"
    write_stl(str(stl), revolve(dome_profile(120), n_around=96))
    verts = load(str(stl))
    verdict = check_revolution(verts)
    ok &= check("STL reconnu comme révolution", verdict.is_revolution, verdict.reason)
    prof_stl = np.array([[p.r, p.z] for p in extract_profile(verts, n_slices=150)])
    gcode2, rapport2 = generate(prof_stl, CutParams(tool_dia=2 * RHO))
    nc = tmp / "dome_depuis_stl.nc"
    nc.write_text(gcode2, encoding="utf-8")
    ok &= check("G-code produit depuis le STL",
                len(gcode2.splitlines()) > 100,
                f"{len(gcode2.splitlines())} lignes, "
                f"{rapport2['duree_totale_min']:.0f} min estimées")
    ok &= check("rayon conservé de bout en bout",
                abs(rapport2["rayon_max_mm"] - R) < 0.05,
                f"{rapport2['rayon_max_mm']:.3f} mm pour {R:.3f} attendus")

    print("\n" + ("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
