"""Vérifie prismatic_to_gcode.py de bout en bout, en conditions réelles.

Contrairement aux autres tests du pipeline, celui-ci ne tourne PAS dans
l'environnement du script qu'il teste : prismatic_to_gcode.py s'exécute DANS
l'interpréteur embarqué de FreeCAD (freecadcmd), pas dans pipeline/.venv312.
Ce test tourne donc dans .venv312 (pour fabriquer la pièce de test via OCP)
et appelle freecadcmd en SOUS-PROCESSUS — exactement l'invocation qu'utilisera
le service Dart en production, donc ce test valide aussi cette mécanique.

Pièce de test : un bloc 40×40×15 avec une poche rectangulaire 20×20×5 et un
perçage central Ø8 traversant — même famille de pièce que Carre35x35.STEP,
celle qui a révélé les trois bugs corrigés dans ce module (argv décalé de un,
__name__ jamais "__main__" sous freecadcmd, avances à zéro tant que le Tool
Controller n'est pas configuré explicitement).

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_prismatic_to_gcode.py
"""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from OCP.BRepAlgoAPI import BRepAlgoAPI_Cut
from OCP.BRepPrimAPI import BRepPrimAPI_MakeBox, BRepPrimAPI_MakeCylinder
from OCP.gp import gp_Ax2, gp_Dir, gp_Pnt

from step_io import write_step

FREECADCMD = (
    Path(__file__).parent
    / "freecad"
    / "FreeCAD_1.1.3-Windows-x86_64-py311"
    / "bin"
    / "freecadcmd.exe"
)
SCRIPT = Path(__file__).parent / "prismatic_to_gcode.py"


def make_test_block() -> object:
    """Bloc 40×40×15, poche 20×20×5 centrée en haut, perçage Ø8 traversant."""
    box = BRepPrimAPI_MakeBox(40.0, 40.0, 15.0).Shape()

    pocket = BRepPrimAPI_MakeBox(gp_Pnt(10.0, 10.0, 10.0), 20.0, 20.0, 5.0).Shape()
    cut1 = BRepAlgoAPI_Cut(box, pocket).Shape()

    axis = gp_Ax2(gp_Pnt(20.0, 20.0, -1.0), gp_Dir(0, 0, 1))
    hole = BRepPrimAPI_MakeCylinder(axis, 4.0, 17.0).Shape()
    return BRepAlgoAPI_Cut(cut1, hole).Shape()


def run_pipeline(step_path: Path, out_path: Path) -> tuple[int, str]:
    result = subprocess.run(
        [str(FREECADCMD), str(SCRIPT), str(step_path), str(out_path)],
        capture_output=True,
        text=True,
        timeout=120,
    )
    return result.returncode, result.stdout + result.stderr


def main() -> int:
    if not FREECADCMD.exists():
        print(f"IGNORÉ : {FREECADCMD} absent (FreeCAD non installé sur ce poste).")
        return 0

    tmp = Path(tempfile.mkdtemp(prefix="forgeron_prismatic_"))
    ok = True

    # ── 1. Bloc à poche + perçage : les trois opérations doivent sortir ────
    step_path = tmp / "bloc.step"
    write_step(make_test_block(), str(step_path))
    out_path = tmp / "bloc.nc"

    code, output = run_pipeline(step_path, out_path)
    print(f"code de sortie : {code}")
    if code != 0:
        print(output[-2000:])
        print("  ÉCHEC : le pipeline aurait dû réussir sur un bloc à poche+perçage.")
        return 1

    report_path = tmp / "bloc_rapport.json"
    if not report_path.exists():
        print("  ÉCHEC : aucun rapport produit.")
        return 1
    report = json.loads(report_path.read_text(encoding="utf-8"))
    print(json.dumps(report, indent=2, ensure_ascii=False))

    if set(report["operations"]) != {"Profile", "Pocket", "Drilling"}:
        print("  ÉCHEC : les trois opérations attendues ne sont pas toutes présentes.")
        ok = False
    if len(report["faces_poche"]) != 1:
        print(f"  ÉCHEC : 1 face de poche attendue, {len(report['faces_poche'])} trouvée(s) "
              "— le dessous du brut est peut-être repris à tort comme une poche.")
        ok = False
    if report["percages_detectes"] != 1:
        print(f"  ÉCHEC : 1 perçage attendu, {report['percages_detectes']} détecté(s).")
        ok = False

    gcode = out_path.read_text(encoding="utf-8")
    if "F0.00" in gcode or " F0.000" in gcode:
        print("  ÉCHEC : une avance nulle est présente dans le G-code.")
        ok = False
    if "G81" not in gcode:
        print("  ÉCHEC : aucun cycle de perçage (G81) dans le G-code.")
        ok = False

    # ── 2. Pavé plein, sans poche ni perçage : Pocket ne doit pas apparaître
    plain_step = tmp / "plein.step"
    write_step(BRepPrimAPI_MakeBox(30.0, 30.0, 10.0).Shape(), str(plain_step))
    plain_out = tmp / "plein.nc"
    code2, output2 = run_pipeline(plain_step, plain_out)
    plain_report = json.loads((tmp / "plein_rapport.json").read_text(encoding="utf-8"))
    print()
    print(f"pavé plein : opérations = {plain_report['operations']}")
    if code2 != 0 or "Pocket" in plain_report["operations"]:
        print("  ÉCHEC : un pavé plein sans poche ne devrait pas produire d'opération Pocket.")
        ok = False

    print()
    print("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
