"""Vérifie la lecture/écriture STEP sur des solides dont le volume est connu.

Aucun fichier externe : les solides sont construits par OpenCASCADE lui-même
(sphère, cylindre), écrits en STEP, relus, puis comparés à la formule
analytique. La sphère R20 fait écho au dôme R20 réellement usiné — même ordre
de grandeur, pour que les tolérances restent comparables aux autres tests du
pipeline.

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_step_io.py
"""

from __future__ import annotations

import math
import tempfile
from pathlib import Path

from OCP.BRepPrimAPI import BRepPrimAPI_MakeCylinder, BRepPrimAPI_MakeSphere

from step_io import bounding_box, read_step, volume, write_step

R = 20.0  # rayon de la sphère, comme dome_r20.nc côté maillage


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="forgeron_step_"))
    ok = True

    # ── 1. Sphère R20 : volume et boîte englobante exacts ──────────────────
    sphere_path = tmp / "sphere_r20.step"
    write_step(BRepPrimAPI_MakeSphere(R).Shape(), str(sphere_path))
    shape = read_step(str(sphere_path))

    v = volume(shape)
    v_attendu = 4.0 / 3.0 * math.pi * R**3
    ecart_v = abs(v - v_attendu) / v_attendu

    xmin, ymin, zmin, xmax, ymax, zmax = bounding_box(shape)
    etendue = (xmax - xmin, ymax - ymin, zmax - zmin)

    print(f"sphère R20 : volume relu {v:.3f} mm³   (attendu {v_attendu:.3f})")
    print(f"  écart relatif : {ecart_v * 100:.4f} %")
    print(f"  boîte englobante : {etendue[0]:.4f} × {etendue[1]:.4f} × {etendue[2]:.4f} mm"
          f"   (attendu {2 * R:.3f} sur les trois axes)")

    # Tolérance large : la boîte englobante d'OpenCASCADE inclut une marge de
    # tolérance de construction (Precision::Confusion, ~1e-7 mm) — pas un défaut
    # de lecture STEP.
    if ecart_v > 1e-6:
        print("  ÉCHEC : le volume relu s'écarte trop de la formule analytique.")
        ok = False
    if any(abs(e - 2 * R) > 1e-3 for e in etendue):
        print("  ÉCHEC : la boîte englobante s'écarte trop de la sphère attendue.")
        ok = False

    # ── 2. Cylindre : deuxième forme, pour ne pas valider un cas unique ────
    cyl_path = tmp / "cylindre.step"
    rayon_cyl, hauteur_cyl = 10.0, 30.0
    write_step(BRepPrimAPI_MakeCylinder(rayon_cyl, hauteur_cyl).Shape(), str(cyl_path))
    shape_cyl = read_step(str(cyl_path))

    v_cyl = volume(shape_cyl)
    v_cyl_attendu = math.pi * rayon_cyl**2 * hauteur_cyl
    ecart_cyl = abs(v_cyl - v_cyl_attendu) / v_cyl_attendu

    print()
    print(f"cylindre R10×H30 : volume relu {v_cyl:.3f} mm³   (attendu {v_cyl_attendu:.3f})")
    print(f"  écart relatif : {ecart_cyl * 100:.4f} %")

    if ecart_cyl > 1e-6:
        print("  ÉCHEC : le volume du cylindre s'écarte trop de la formule analytique.")
        ok = False

    # ── 3. Aller-retour : écrire ce qu'on vient de relire donne le même volume
    rt_path = tmp / "roundtrip.step"
    write_step(shape, str(rt_path))
    v_rt = volume(read_step(str(rt_path)))
    ecart_rt = abs(v_rt - v) / v

    print()
    print(f"aller-retour STEP : écart de volume {ecart_rt * 100:.6f} %")
    if ecart_rt > 1e-9:
        print("  ÉCHEC : l'aller-retour STEP perd de la précision.")
        ok = False

    print()
    print("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
