"""Vérifie l'assemblage complet STEP → G-code, sur des solides synthétiques.

Ne revalide pas la précision géométrique (déjà couverte par
`test_step_profile.py`) : ce test porte sur l'ASSEMBLAGE — le refus propre
d'une pièce non révolue, et un rapport cohérent avec la géométrie d'entrée,
dans le cas sans contre-dépouille comme dans celui qui en a une.

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_step_to_gcode.py
"""

from __future__ import annotations

import tempfile
from pathlib import Path

from OCP.BRepPrimAPI import BRepPrimAPI_MakeBox, BRepPrimAPI_MakeCone, BRepPrimAPI_MakeSphere

from step_io import write_step
from step_to_gcode import step_to_gcode


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="forgeron_step2gcode_"))
    ok = True

    # ── 1. Un pavé doit être REFUSÉ, sans exception non gérée ──────────────
    box_path = tmp / "box.step"
    write_step(BRepPrimAPI_MakeBox(40.0, 40.0, 40.0).Shape(), str(box_path))
    try:
        step_to_gcode(str(box_path))
        print("pavé : ÉCHEC — aucune exception levée pour une pièce non révolue.")
        ok = False
    except ValueError as exc:
        print(f"pavé : refusé comme attendu — {exc}")

    # ── 2. Cône (apex en haut) : pas de contre-dépouille ────────────────────
    cone_path = tmp / "cone.step"
    r_base, hauteur = 15.0, 25.0
    write_step(BRepPrimAPI_MakeCone(r_base, 0.0, hauteur).Shape(), str(cone_path))
    gcode, report, profile = step_to_gcode(str(cone_path))

    print()
    print(f"cône R{r_base}×H{hauteur} : {len(profile)} points de profil, "
          f"{len(gcode.splitlines())} lignes de G-code")
    print(f"  rayon max mesuré : {report['rayon_max_mm']:.3f} mm (attendu {r_base:.3f})")
    print(f"  hauteur mesurée  : {report['hauteur_mm']:.3f} mm (attendu {hauteur:.3f})")
    print(f"  contre-dépouille : {report['contre_depouille']}")

    if abs(report["rayon_max_mm"] - r_base) > 0.05:
        print("  ÉCHEC : rayon maximal hors tolérance.")
        ok = False
    if abs(report["hauteur_mm"] - hauteur) > 0.05:
        print("  ÉCHEC : hauteur hors tolérance.")
        ok = False
    if report["contre_depouille"]:
        print("  ÉCHEC : un cône simple ne doit pas déclencher de contre-dépouille.")
        ok = False
    if "M30" not in gcode or "G54" not in gcode:
        print("  ÉCHEC : le G-code généré ne contient pas les blocs attendus.")
        ok = False

    # ── 3. Sphère complète : la contre-dépouille doit être détectée ────────
    sphere_path = tmp / "sphere.step"
    R = 20.0
    write_step(BRepPrimAPI_MakeSphere(R).Shape(), str(sphere_path))
    gcode_s, report_s, profile_s = step_to_gcode(str(sphere_path))

    print()
    print(f"sphère R{R} (complète) : contre-dépouille = {report_s['contre_depouille']}")
    if not report_s["contre_depouille"]:
        print("  ÉCHEC : une sphère complète usinée outil vertical DOIT signaler"
              " une contre-dépouille sous l'équateur.")
        ok = False
    if "CONTRE-DEPOUILLE" not in gcode_s:
        print("  ÉCHEC : l'avertissement de contre-dépouille devrait apparaître"
              " en tête du G-code.")
        ok = False

    print()
    print("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
