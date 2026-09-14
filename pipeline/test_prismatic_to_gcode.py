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


def run_pipeline(
    step_path: Path, out_path: Path, *extra: str
) -> tuple[int, str]:
    result = subprocess.run(
        [str(FREECADCMD), str(SCRIPT), str(step_path), str(out_path), *extra],
        capture_output=True,
        text=True,
        timeout=180,
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
    # G83 = perçage AVEC débourrage. Le script l'active par défaut : sans lui
    # le copeau s'accumule et cale une broche déjà sous-alimentée. Un G81 seul
    # veut donc dire que le réglage n'a pas pris.
    if "G83" not in gcode:
        print("  ÉCHEC : perçage sans débourrage (G83 attendu, "
              f"{'G81 trouvé' if 'G81' in gcode else 'aucun cycle'}).")
        ok = False

    # ── Les réglages ont-ils tous été acceptés par CETTE version de FreeCAD ?
    # C'est la vérification la plus importante du fichier : une propriété
    # renommée d'une version à l'autre ne lève aucune erreur — elle laisse
    # simplement le parcours aux défauts de FreeCAD, c'est-à-dire faux.
    non_appliques = report.get("reglages_non_appliques", [])
    if non_appliques:
        print(f"  ÉCHEC : {len(non_appliques)} réglage(s) refusé(s) par FreeCAD :")
        for nom in non_appliques:
            print(f"      - {nom}")
        ok = False
    else:
        print(f"  OK : {len(report.get('reglages_appliques', {}))} réglages appliqués.")

    # ── L'ordre d'usinage : le contour détache la pièce, il passe en DERNIER
    ordre = report["operations"]
    if ordre[-1] != "Profile":
        print(f"  ÉCHEC : le contour doit être la dernière opération, ordre = {ordre}. "
              "Détouré en premier, tout ce qui suit s'usine sur une pièce libre.")
        ok = False
    if "Pocket" in ordre and ordre.index("Pocket") > ordre.index("Drilling"):
        print(f"  ÉCHEC : la poche doit précéder le perçage, ordre = {ordre}.")
        ok = False

    # ── Les conditions de coupe sont-elles celles demandées ? ──────────────
    if report.get("ap_mm") != 0.2 or report.get("ae_mm") != 0.5:
        print(f"  ÉCHEC : plafonds vibratoires attendus (0.2 / 0.5), "
              f"rapport = {report.get('ap_mm')} / {report.get('ae_mm')}.")
        ok = False
    if report.get("outil_diametre_mm") != 6.0:
        print(f"  ÉCHEC : outil Ø6 attendu, rapport = {report.get('outil_diametre_mm')}.")
        ok = False

    # ── 1 bis. Les options de la ligne de commande sont-elles suivies ? ────
    # Sans cette vérification, le script pourrait ignorer ses arguments en
    # silence et produire toujours le même parcours.
    opt_out = tmp / "bloc_opt.nc"
    code_opt, _ = run_pipeline(
        step_path, opt_out, "--outil", "3", "--ap", "0.1", "--ae", "0.25"
    )
    if code_opt == 0:
        opt_report = json.loads(
            (tmp / "bloc_opt_rapport.json").read_text(encoding="utf-8")
        )
        print()
        print(f"avec --outil 3 --ap 0.1 --ae 0.25 : "
              f"Ø{opt_report.get('outil_diametre_mm')} "
              f"ap={opt_report.get('ap_mm')} ae={opt_report.get('ae_mm')}")
        if (opt_report.get("outil_diametre_mm"), opt_report.get("ap_mm"),
                opt_report.get("ae_mm")) != (3.0, 0.1, 0.25):
            print("  ÉCHEC : les options de la ligne de commande sont ignorées.")
            ok = False
        # Le G-code doit VRAIMENT changer : mêmes réglages = mêmes passes.
        if opt_out.read_text(encoding="utf-8") == gcode:
            print("  ÉCHEC : un ap deux fois plus fin produit le même G-code.")
            ok = False
    else:
        print("  ÉCHEC : le pipeline refuse ses propres options.")
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
