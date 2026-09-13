"""Pièce prismatique -> G-code, via FreeCAD CAM (workbench « CAM », ex-Path).

Phase 5.c du PLAN-IA — le cas général que le pipeline de révolution
(step_to_gcode.py) refuse explicitement. Contrairement à lui, ce script ne
tourne PAS dans pipeline/.venv312 : il s'exécute DANS l'interpréteur Python
que FreeCAD embarque, via freecadcmd — le seul moyen d'obtenir les modules
FreeCAD/Part/Path sans faire correspondre un venv à une version de FreeCAD
précise (voir le commit qui a ajouté pipeline/freecad/ : ocp-freecad-cam a
été écarté pour cette raison).

    pipeline/freecad/FreeCAD_1.1.3-Windows-x86_64-py311/bin/freecadcmd.exe \\
        pipeline/prismatic_to_gcode.py <piece.step> <sortie.nc>

── Ce qui est automatique, ce qui ne l'est pas ─────────────────────────────

Lu dans le code source de FreeCAD CAM, pas supposé : il n'y a PAS de
reconnaissance de formes générale façon AFR SolidWorks.

- Perçages : reconnus automatiquement (Path.Op.Drilling.Create() appelle
  findAllHoles() en interne) — toute face cylindrique verticale de diamètre
  suffisant devient un perçage.
- Contour extérieur : un Profile sans sélection de face profile la
  silhouette extérieure globale de la pièce — exactement ce qu'il faut pour
  un contour de pourtour, sans rien détecter.
- Poches : aucune reconnaissance native. Ce script détecte lui-même les
  faces planes horizontales en retrait du dessus de la pièce — une
  heuristique locale, pas un AFR général : une poche inclinée, ou creusée
  dans une autre poche, y échapperait.
"""

from __future__ import annotations

import sys

import FreeCAD
import Import
import Path.Main.Job as PathJob
import Path.Op.Drilling as PathDrilling
import Path.Op.Pocket as PathPocket
import Path.Op.Profile as PathProfile


def find_pocket_faces(shape, tolerance: float = 0.05) -> list[str]:
    """Faces planes horizontales en retrait du sommet de la pièce, hors le
    dessous du brut.

    Heuristique, pas une reconnaissance générale : une poche est ici « une
    face plane horizontale plus basse que le dessus de la pièce, mais pas
    le dessous du bloc lui-même ». Sans l'exclusion du dessous, le fond du
    brut (z = ZMin, une face plane horizontale comme une autre) se fait
    prendre pour une poche — constaté sur le premier essai : 2 faces
    trouvées sur un bloc à une seule poche, l'une d'elles étant le dessous.
    Une poche inclinée, ou creusée dans une autre poche, échappe à ce test.
    """
    box = shape.BoundBox
    z_top, z_bottom = box.ZMax, box.ZMin
    names = []
    for i, face in enumerate(shape.Faces, start=1):
        if face.Surface.TypeId != "Part::GeomPlane":
            continue
        normal = face.normalAt(0, 0)
        if abs(normal.z) < 0.999:  # pas horizontale
            continue
        z = face.CenterOfMass.z
        if z < z_top - tolerance and z > z_bottom + tolerance:
            names.append(f"Face{i}")
    return names


def build_job(step_path: str):
    """Importe le STEP et construit le Job CAM. Lève ValueError si le
    fichier ne porte pas exactement un solide (assemblage non géré ici)."""
    doc = FreeCAD.newDocument("Piece")
    Import.insert(step_path, doc.Name)
    doc.recompute()
    FreeCAD.setActiveDocument(doc.Name)  # Job.Create() lit ActiveDocument

    features = [o for o in doc.Objects if o.TypeId == "Part::Feature"]
    if not features:
        raise ValueError(f"{step_path} : aucun solide importé")
    if len(features) > 1:
        raise ValueError(
            f"{step_path} : {len(features)} solides — assemblage non géré, "
            "une seule pièce attendue"
        )
    base = features[0]

    job = PathJob.Create("Job", [base], None)
    job.PostProcessor = "grbl"

    # Le Tool Controller par défaut (Tools.Group[0]) existe mais ses avances
    # sont à zéro tant que rien ne les règle — constaté : un G-code entier
    # sans aucun F, et F0.00 sur le seul endroit qui en émet une (le
    # perçage). Valeurs de départ prudentes, du même ordre que celles de
    # gen_revolution.CutParams (dôme R20 réellement usiné).
    tc = job.Tools.Group[0]
    tc.HorizFeed = "500 mm/min"   # avance de coupe horizontale
    tc.VertFeed = "100 mm/min"    # plongée
    tc.HorizRapid = "3000 mm/min"
    tc.VertRapid = "1000 mm/min"

    # Noms canoniques (pas de libellé français) : SetupSheet retrouve les
    # avances/vitesses par défaut d'une opération par ce nom exact — un nom
    # personnalisé le laisse sans réglage (constaté : F0.00 sur le
    # perçage tant que l'opération s'appelait « Percage »).
    contour = PathProfile.Create("Profile", parentJob=job)
    # Base laissée vide : silhouette extérieure globale, sans sélection.

    drill = PathDrilling.Create("Drilling", parentJob=job)
    # Base déjà rempli par findAllHoles(), appelé dans Create().

    pocket_faces = find_pocket_faces(base.Shape)
    pocket = None
    if pocket_faces:
        pocket = PathPocket.Create("Pocket", parentJob=job)
        pocket.Base = [(base, pocket_faces)]

    doc.recompute()
    ops = [o for o in (contour, pocket, drill) if o is not None]
    return doc, job, ops, pocket_faces, len(drill.Base) if drill.Base else 0


def _import_grbl_post():
    try:
        import grbl_post
        return grbl_post
    except ImportError:
        sys.path.append(
            FreeCAD.getHomePath() + "Mod/CAM/Path/Post/scripts"
        )
        import grbl_post
        return grbl_post


def main() -> int:
    # freecadcmd place son propre chemin en argv[0] et celui du script en
    # argv[1] (pas le script en argv[0] comme un interpréteur Python normal)
    # — vérifié empiriquement, pas supposé.
    if len(sys.argv) < 4:
        print("usage : freecadcmd prismatic_to_gcode.py <piece.step> <sortie.nc>")
        return 1
    step_path, out_path = sys.argv[2], sys.argv[3]

    try:
        doc, job, ops, pocket_faces, n_holes = build_job(step_path)
    except ValueError as exc:
        print(f"REFUS : {exc}")
        return 1

    grbl_post = _import_grbl_post()
    grbl_post.export(ops, out_path, "--no-show-editor")

    with open(out_path, encoding="utf-8") as f:
        n_lignes = sum(1 for _ in f)

    # Rapport en fichier à part, même convention que step_to_gcode.py : un
    # appelant (l'agent IA, via sous-processus) lit ce fichier plutôt que de
    # parser la sortie texte, qui porte aussi les journaux de FreeCAD.
    report_path = out_path.rsplit(".", 1)[0] + "_rapport.json"
    import json

    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "operations": [o.Name for o in ops],
                "faces_poche": pocket_faces,
                "percages_detectes": n_holes,
                "lignes_gcode": n_lignes,
                "gcode_path": out_path,
            },
            f,
            indent=2,
            ensure_ascii=False,
        )

    print(f"{step_path} : {len(pocket_faces)} face(s) de poche, {n_holes} perçage(s)")
    print(f"{len(ops)} opération(s), {n_lignes} lignes -> {out_path}")
    print(f"rapport -> {report_path}")
    return 0


# freecadcmd exécute le script avec __name__ = son nom de fichier, jamais
# "__main__" (vérifié empiriquement) — la garde habituelle ne se
# déclencherait donc jamais. Appel inconditionnel.
raise SystemExit(main())
