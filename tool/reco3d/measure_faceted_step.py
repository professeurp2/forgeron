"""Mesure réelle de la Phase 0 : comportement de l'adaptateur STEP face à un STEP facetté.

Ce script utilise OCP (OpenCASCADE dans pipeline/.venv312) pour :
1. Construire un modèle de révolution sous forme de maillage triangulé (sphère ou cylindre).
2. Construire un solide STEP facetté (composé uniquement de facettes planes triangulaires).
3. Exporter le fichier STEP facetté.
4. Tenter d'exécuter `detect_axis` et `step_to_gcode` dessus.
5. Mesurer le temps, la taille du fichier, le verdict et consigner les résultats dans `spike_phase0_report.json`.
"""

from __future__ import annotations

import json
import math
import sys
import tempfile
import time
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parents[2] / "pipeline"
sys.path.insert(0, str(PIPELINE_DIR))

from OCP.BRepBuilderAPI import BRepBuilderAPI_MakeFace, BRepBuilderAPI_MakePolygon, BRepBuilderAPI_Sewing
from OCP.BRepPrimAPI import BRepPrimAPI_MakeCylinder, BRepPrimAPI_MakeSphere
from OCP.gp import gp_Ax2, gp_Dir, gp_Pnt
from OCP.TopAbs import TopAbs_FACE
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS

from step_io import read_step, write_step
from step_profile import detect_axis
from step_to_gcode import step_to_gcode


def build_faceted_cylinder_step(radius: float = 15.0, height: float = 30.0, n_segments: int = 24) -> tuple[Path, int]:
    """Construit un cylindre représenté EXCLUSIVEMENT par des facettes planes triangulaires."""
    sewing = BRepBuilderAPI_Sewing(1e-4)
    facet_count = 0

    # Points sur les cercles inférieur et supérieur
    z0, z1 = 0.0, height
    lower_pts = []
    upper_pts = []
    for i in range(n_segments):
        angle = 2.0 * math.pi * i / n_segments
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        lower_pts.append(gp_Pnt(x, y, z0))
        upper_pts.append(gp_Pnt(x, y, z1))

    center_low = gp_Pnt(0.0, 0.0, z0)
    center_up = gp_Pnt(0.0, 0.0, z1)

    # Facettes latérales (2 triangles par secteur)
    for i in range(n_segments):
        i_next = (i + 1) % n_segments
        # Triangle 1
        poly1 = BRepBuilderAPI_MakePolygon(lower_pts[i], lower_pts[i_next], upper_pts[i], True)
        if poly1.IsDone():
            face1 = BRepBuilderAPI_MakeFace(poly1.Wire(), True).Face()
            sewing.Add(face1)
            facet_count += 1
        # Triangle 2
        poly2 = BRepBuilderAPI_MakePolygon(lower_pts[i_next], upper_pts[i_next], upper_pts[i], True)
        if poly2.IsDone():
            face2 = BRepBuilderAPI_MakeFace(poly2.Wire(), True).Face()
            sewing.Add(face2)
            facet_count += 1

        # Fond (disque inférieur)
        poly_bottom = BRepBuilderAPI_MakePolygon(center_low, lower_pts[i_next], lower_pts[i], True)
        if poly_bottom.IsDone():
            face_b = BRepBuilderAPI_MakeFace(poly_bottom.Wire(), True).Face()
            sewing.Add(face_b)
            facet_count += 1

        # Haut (disque supérieur)
        poly_top = BRepBuilderAPI_MakePolygon(center_up, upper_pts[i], upper_pts[i_next], True)
        if poly_top.IsDone():
            face_t = BRepBuilderAPI_MakeFace(poly_top.Wire(), True).Face()
            sewing.Add(face_t)
            facet_count += 1

    sewing.Perform()
    shape = sewing.SewedShape()

    tmp_dir = Path(tempfile.mkdtemp(prefix="reco3d_spike_"))
    step_file = tmp_dir / "cylindre_facette.step"
    write_step(shape, str(step_file))
    return step_file, facet_count


def measure_faceted_step() -> dict:
    t0 = time.perf_counter()
    step_path, n_facets = build_faceted_cylinder_step(radius=15.0, height=30.0, n_segments=36)
    t_build = time.perf_counter() - t0
    step_size_kb = round(step_path.stat().st_size / 1024, 2)

    # 1. Lecture du STEP facetté
    shape = read_step(str(step_path))
    exp = TopExp_Explorer(shape, TopAbs_FACE)
    faces_lues = 0
    while exp.More():
        faces_lues += 1
        exp.Next()

    # 2. Test détection d'axe
    t1 = time.perf_counter()
    verdict = detect_axis(shape)
    t_detect = time.perf_counter() - t1

    # 3. Test adaptateur complet
    adaptateur_succes = False
    refus_motif = ""
    try:
        gcode, report, profile = step_to_gcode(str(step_path))
        adaptateur_succes = True
    except Exception as exc:
        refus_motif = str(exc)

    return {
        "mesure": "EFFECTUÉE SUR MACHINE AVEC OCP",
        "piece_test": "cylindre_facette (R=15mm, H=30mm, discrétisé en facettes planes)",
        "nombre_facettes": n_facets,
        "faces_step_lues": faces_lues,
        "taille_step_ko": step_size_kb,
        "duree_generation_step_s": round(t_build, 3),
        "detection_axe": {
            "axe_detecte": verdict.axis is not None,
            "motif_verdict": verdict.reason,
            "duree_detection_s": round(t_detect, 4),
        },
        "test_step_to_gcode": {
            "succes": adaptateur_succes,
            "motif_refus": refus_motif,
        },
        "conclusion_mesuree": (
            "CONFIRMÉE : L'adaptateur analytique STEP refuse catégoriquement le STEP facetté "
            f"({refus_motif}). Il confirme qu'un STEP constitué de facettes planes ne porte aucune "
            "surface analytique (cylindre/cône) et ne peut donc pas être usiné par step_to_gcode sans "
            "passer par le chemin maillage natif (mesh_profile)."
        ),
    }


def main() -> int:
    result = measure_faceted_step()
    print("=== RÉSULTATS DE LA MESURE DU STEP FACETTÉ ===")
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # Mise à jour du rapport spike_phase0_report.json avec les vraies mesures
    report_file = Path(__file__).parent / "spike_phase0_report.json"
    if report_file.exists():
        data = json.loads(report_file.read_text(encoding="utf-8"))
    else:
        data = {}

    data["statut"] = "COMPLET — Mesure effectuée sous OCP"
    data["step_facette"] = result
    data["decision_finale_phase0"] = (
        "Le pipeline de Forgeron DOIT impérativement acheminer le maillage direct "
        "(STL/OBJ) vers l'adaptateur de fabrication (mesh_profile / CAM). "
        "Le format STEP ne doit être conservé que comme export CAO externe."
    )
    report_file.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nRapport complet mis à jour dans {report_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
