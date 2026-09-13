"""Vérifie la détection d'axe et l'extraction de profil depuis un STEP.

Aucun fichier externe : les solides sont construits par OpenCASCADE lui-même.
La sphère R20 fait écho au dôme R20 réellement usiné, comme dans
`test_mesh_profile.py` côté STL — mais ici le profil est exact (géométrie
analytique), pas approché (facettes d'un maillage), et l'écart mesuré doit le
montrer.

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_step_profile.py
"""

from __future__ import annotations

import math
import tempfile
from pathlib import Path

from OCP.BRepPrimAPI import BRepPrimAPI_MakeBox, BRepPrimAPI_MakeCylinder, BRepPrimAPI_MakeSphere

from step_io import read_step, write_step
from step_profile import detect_axis, extract_profile

R = 20.0  # rayon de la sphère, comme dome_r20.nc


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="forgeron_step_profile_"))
    ok = True

    # ── 1. Un pavé doit être REFUSÉ : aucune face de révolution ────────────
    box_path = tmp / "box.step"
    write_step(BRepPrimAPI_MakeBox(40.0, 40.0, 40.0).Shape(), str(box_path))
    verdict = detect_axis(read_step(str(box_path)))
    print(f"pavé      : axe={verdict.axis is not None}  ({verdict.reason})")
    if verdict.axis is not None:
        print("  ÉCHEC : un pavé ne doit porter aucun axe de révolution.")
        ok = False

    # ── 2. Sphère R20 : axe détecté, profil exact ───────────────────────────
    sphere_path = tmp / "sphere_r20.step"
    write_step(BRepPrimAPI_MakeSphere(R).Shape(), str(sphere_path))
    shape = read_step(str(sphere_path))
    verdict = detect_axis(shape)
    print(f"sphère R20 : axe={verdict.axis is not None}  ({verdict.reason})")
    if verdict.axis is None:
        print("  ÉCHEC : la sphère doit porter un axe de révolution.")
        return 1

    axis = verdict.axis
    print(f"  point={tuple(round(x, 6) for x in axis.point)}"
          f"  direction={tuple(round(x, 6) for x in axis.direction)}")
    if math.hypot(*axis.point) > 1e-6:
        print("  ÉCHEC : l'axe devrait passer par l'origine, centre de la sphère.")
        ok = False

    profile = extract_profile(shape, axis, n_par_arete=400)
    # Surface exacte : r² + z² = R² (axe = origine, centre de la sphère).
    errors = [abs(math.hypot(p.r, p.z) - R) for p in profile]
    moyenne = sum(errors) / len(errors)
    maximum = max(errors)

    print(f"  points du profil : {len(profile)}")
    print(f"  écart moyen au cercle   : {moyenne * 1e6:.3f} nm")
    print(f"  écart maximal au cercle : {maximum * 1e6:.3f} nm")
    # mesh_profile.py, même sphère en STL : 13 µm d'écart moyen (facettisation
    # du maillage). Ici l'écart n'est plus que du bruit flottant, en dessous
    # du nanomètre : comparer les deux comme un ratio n'aurait pas de sens.
    print("  (mesh_profile.py, même sphère en STL : 13 µm — ici, sous le bruit flottant)")

    # Géométrie analytique : l'écart ne vient que de l'arithmétique flottante.
    if maximum > 1e-6:
        print("  ÉCHEC : un profil exact ne devrait pas s'écarter du cercle théorique.")
        ok = False

    # ── 3. Cylindre : la paroi doit rester à r=R entre les deux fonds ──────
    cyl_path = tmp / "cylindre.step"
    rayon_cyl, hauteur_cyl = 10.0, 30.0
    write_step(BRepPrimAPI_MakeCylinder(rayon_cyl, hauteur_cyl).Shape(), str(cyl_path))
    shape_cyl = read_step(str(cyl_path))
    verdict_cyl = detect_axis(shape_cyl)
    print()
    print(f"cylindre R10×H30 : axe={verdict_cyl.axis is not None}  ({verdict_cyl.reason})")
    if verdict_cyl.axis is None:
        print("  ÉCHEC : le cylindre doit porter un axe de révolution.")
        return 1

    # Les fonds plats ne sont pas des faces de révolution : `extract_profile`
    # ne sectionne que la paroi cylindrique, seule face de ce type ici — donc
    # aucun point parasite à écarter.
    profile_cyl = extract_profile(shape_cyl, verdict_cyl.axis, n_par_arete=100)
    ecarts_paroi = [abs(p.r - rayon_cyl) for p in profile_cyl]
    z_span = (min(p.z for p in profile_cyl), max(p.z for p in profile_cyl))

    print(f"  points sur la paroi : {len(profile_cyl)}")
    print(f"  étendue en z : {z_span[0]:.3f} .. {z_span[1]:.3f}  (attendu 0 .. {hauteur_cyl:.3f})")
    print(f"  écart maximal au rayon nominal : {max(ecarts_paroi) * 1e6:.3f} nm")
    if max(ecarts_paroi) > 1e-6:
        print("  ÉCHEC : la paroi cylindrique devrait rester exactement à r=R.")
        ok = False
    if abs(z_span[0] - 0.0) > 1e-6 or abs(z_span[1] - hauteur_cyl) > 1e-6:
        print("  ÉCHEC : l'étendue en z ne couvre pas toute la hauteur du cylindre.")
        ok = False

    print()
    print("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
