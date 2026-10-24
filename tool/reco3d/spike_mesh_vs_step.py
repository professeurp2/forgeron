"""Spike phase 0 (docs/conception-photos-vers-step.md, §8) — état PARTIEL.

Question : un STEP facetté (issu d'un scan) passe-t-il l'adaptateur
STEP -> G-code existant, ou faut-il un chemin maillage -> CAM direct ?

Ce script ne rapporte que ce qu'il MESURE :
- MESURÉ : le chemin maillage direct (STL -> mesh_profile -> gen_revolution)
  sur pipeline/vase.stl. Attention : maillage CAO propre, pas un scan bruité.
- NON MESURÉ : le STEP facetté. Il faut OCP (pipeline/.venv312) ou FreeCAD
  (pipeline/freecad/), absents de ce poste au 24/10/2026. L'hypothèse issue
  de la lecture du code est consignée comme hypothèse, pas comme résultat.

Lancer :  python -X utf8 tool/reco3d/spike_mesh_vs_step.py
"""

from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import time
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parents[2] / "pipeline"
sys.path.insert(0, str(PIPELINE_DIR))

import numpy as np
from gen_revolution import CutParams, generate
from mesh_profile import check_revolution, extract_profile
from stl_io import read_stl, vertices_of


def measure_direct_mesh(stl_path: Path) -> dict:
    t0 = time.perf_counter()
    vertices = vertices_of(read_stl(str(stl_path)))
    verdict = check_revolution(vertices)
    profile = extract_profile(vertices)
    prof = np.array([[p.r, p.z] for p in profile], dtype=float)
    gcode, report = generate(prof, CutParams())
    return {
        "source": stl_path.name,
        "nature_source": "maillage CAO propre (pas un scan)",
        "sommets": int(len(vertices)),
        "revolution": verdict.is_revolution,
        "ecart_max_mm": round(float(verdict.max_deviation), 4),
        "points_profil": len(profile),
        "lignes_gcode": len(gcode.splitlines()),
        "duree_calcul_s": round(time.perf_counter() - t0, 3),
        "duree_usinage_estimee_min": round(report["duree_totale_min"], 1),
    }


def faceted_step_status() -> dict:
    has_ocp = importlib.util.find_spec("OCP") is not None
    freecad = PIPELINE_DIR / "freecad"
    has_freecad = freecad.exists() or shutil.which("freecadcmd") is not None
    return {
        "mesure": "NON EFFECTUÉE",
        "outils": {"OCP": has_ocp, "FreeCAD": has_freecad},
        "hypothese_lecture_code": (
            "step_profile.detect_axis ne lit que les faces analytiques "
            "(cylindre, cône, sphère, tore). Un solide facetté n'a que des "
            "faces planes : l'adaptateur de révolution devrait donc refuser. "
            "À CONFIRMER par la mesure."
        ),
        "pour_mesurer": (
            "installer pipeline/.venv312 (requirements-step.txt) ou FreeCAD "
            "portable, convertir vase.stl en STEP facetté, passer "
            "step_to_gcode.py et prismatic_to_gcode.py dessus."
        ),
    }


def main() -> int:
    stl = PIPELINE_DIR / "vase.stl"
    report = {
        "spike": "phase 0 — STEP facetté vs maillage direct",
        "statut": "PARTIEL — verdict suspendu à la mesure du STEP facetté",
        "maillage_direct": measure_direct_mesh(stl),
        "step_facette": faceted_step_status(),
    }
    out = Path(__file__).with_name("spike_phase0_report.json")
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
