"""Vérifie la chaîne d'usinage d'implants médicaux sur mesure (STL → G-code).

Contrôle :
  1. Le refus honnête des métaux hors capacité (Titane Ti-6Al-4V, CoCrMo).
  2. La préparation géométrique d'un STL issu de DICOM (coordonnées décalées,
     export en mètres, pièce debout remise à plat, centrage G54).
  3. Le garde-fou de provenance (blocage d'un scan approximatif sans cote pour
     un implant chirurgical, autorisation pour un modèle anatomique ou avec
     cote recalée).
  4. Le refus d'un implant dépassant l'enveloppe machine (88 × 150 × 110 mm).
  5. La conformité du G-code médical (coupe à sec M9, absence de M7/M8,
     plafond ap = 0,15 mm sur PEEK, ébauche 3 axes + finition 5 axes) et du
     dossier de lot ISO 13485 (empreintes SHA-256).

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_medical_implant.py
"""

from __future__ import annotations

import math
import tempfile
from pathlib import Path

import numpy as np

from medical_implant import (
    ImplantCutConfig,
    generate_implant_program,
    prepare_implant_mesh,
    stl_to_implant_gcode,
)
from stl_io import write_stl

_ok = True


def chk(label: str, cond: bool, detail: str = "") -> None:
    global _ok
    _ok &= bool(cond)
    print(f"  {'OK  ' if cond else 'ECHEC'} {label}" + (f"  — {detail}" if detail else ""))


def _make_curved_cranial_plate_stl(
    path: Path,
    *,
    width_x: float = 24.0,
    length_y: float = 32.0,
    thickness_z: float = 3.0,
    arch_height: float = 2.0,
    offset: tuple[float, float, float] = (140.0, -75.0, 510.0),
    scale: float = 1.0,
    stand_upright: bool = False,
) -> None:
    """Construit un maillage STL fermé d'une plaque crânienne bombée asymétrique
    (non de révolution), décalée dans un repère scanner DICOM."""
    nx, ny = 7, 9
    xs = np.linspace(-width_x / 2, width_x / 2, nx)
    ys = np.linspace(-length_y / 2, length_y / 2, ny)

    def z_top_fn(x: float, y: float) -> float:
        rx = x / (width_x / 2)
        ry = y / (length_y / 2)
        return arch_height * (1.0 - 0.5 * (rx * rx + ry * ry))

    tris: list[list[list[float]]] = []
    for j in range(ny - 1):
        for i in range(nx - 1):
            x0, x1 = float(xs[i]), float(xs[i + 1])
            y0, y1 = float(ys[j]), float(ys[j + 1])
            # Face supérieure (normale +Z)
            p00 = [x0, y0, z_top_fn(x0, y0)]
            p10 = [x1, y0, z_top_fn(x1, y0)]
            p11 = [x1, y1, z_top_fn(x1, y1)]
            p01 = [x0, y1, z_top_fn(x0, y1)]
            tris.append([p00, p10, p11])
            tris.append([p00, p11, p01])
            # Face inférieure (décalée de -thickness_z, normale -Z)
            b00 = [x0, y0, p00[2] - thickness_z]
            b10 = [x1, y0, p10[2] - thickness_z]
            b11 = [x1, y1, p11[2] - thickness_z]
            b01 = [x0, y1, p01[2] - thickness_z]
            tris.append([b00, b11, b10])
            tris.append([b00, b01, b11])

    arr = np.asarray(tris, dtype=np.float64)
    if stand_upright:
        # Échange Y et Z : la plaque est debout sur la tranche (épaisseur selon Y)
        arr = arr[:, :, [0, 2, 1]]
        arr[:, [1, 2], :] = arr[:, [2, 1], :]

    arr = (arr + np.asarray(offset, dtype=np.float64)) * scale
    write_stl(str(path), arr)


def main() -> int:
    import sys

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    tmp = Path(tempfile.mkdtemp(prefix="forgeron_med_"))

    print("\n1. Garde-fous matériaux : refus honnête des métaux hors capacité")
    plate_path = tmp / "plaque_dicom.stl"
    _make_curved_cranial_plate_stl(plate_path)

    for metal in ("ti6al4v", "cocrmo"):
        try:
            stl_to_implant_gcode(
                str(plate_path),
                ImplantCutConfig(material_id=metal),
            )
            chk(f"refus {metal}", False, "aucune exception levée")
        except ValueError as exc:
            chk(
                f"refus {metal} motivé",
                "Hors capacité machine" in str(exc) and "200 W" in str(exc),
                str(exc)[:80] + "…",
            )

    print("\n2. Préparation géométrique DICOM (mètres → mm, réorientation, centrage G54)")
    meters_upright_path = tmp / "plaque_metres_debout.stl"
    _make_curved_cranial_plate_stl(
        meters_upright_path,
        width_x=24.0,
        length_y=32.0,
        thickness_z=3.0,
        arch_height=2.0,
        scale=0.001,  # en mètres !
        stand_upright=True,
    )
    from stl_io import read_stl

    prep = prepare_implant_mesh(read_stl(str(meters_upright_path)), auto_orient=True)
    sx, sy, sz = prep.prepared_size_mm
    pts = prep.triangles.reshape(-1, 3)
    chk("conversion m → mm détectée", prep.unit_converted_from_meters)
    chk("réorientation à plat effectuée", prep.reoriented)
    chk(
        "dimensions retrouvées (24 × 32 × 5 mm)",
        abs(sx - 24.0) < 0.1 and abs(sy - 32.0) < 0.1 and abs(sz - 5.0) < 0.1,
        f"{sx:.2f} × {sy:.2f} × {sz:.2f} mm",
    )
    chk(
        "centrage G54 (X,Y centrés sur 0, sommet à Z=0)",
        abs(pts[:, 0].mean()) < 1.0
        and abs(pts[:, 1].mean()) < 1.0
        and abs(pts[:, 2].max() - 0.0) < 1e-5,
        f"Z_max={pts[:, 2].max():.4f} mm",
    )

    print("\n3. Garde-fou de provenance (scan approximatif vs cote certifiée)")
    try:
        generate_implant_program(
            prep,
            ImplantCutConfig(
                material_id="peek",
                implant_type="plaque_cranienne",
                provenance_approximate=True,
            ),
        )
        chk("scan approximatif sans cote bloqué pour un implant", False)
    except ValueError as exc:
        chk(
            "scan approximatif sans cote bloqué pour un implant",
            "approximative" in str(exc),
            str(exc)[:75] + "…",
        )

    # En revanche, si l'opérateur recale explicitement la longueur cible, ça passe :
    prep_scaled = prepare_implant_mesh(
        read_stl(str(plate_path)),
        target_length_mm=30.0,
    )
    _, rep_scaled = generate_implant_program(
        prep_scaled,
        ImplantCutConfig(
            material_id="pmma",
            implant_type="guide_chirurgical",
            provenance_approximate=True,
            stepover=2.0,
        ),
    )
    chk(
        "scan approximatif recalé par longueur cible autorisé",
        abs(rep_scaled["dimensions_preparees_mm"][1] - 30.0) < 0.05,
        f"longueur={rep_scaled['dimensions_preparees_mm'][1]} mm",
    )

    print("\n4. Garde-fou d'enveloppe machine (88 × 150 × 110 mm)")
    huge_path = tmp / "trop_grand.stl"
    _make_curved_cranial_plate_stl(huge_path, width_x=95.0, length_y=120.0)
    try:
        prepare_implant_mesh(read_stl(str(huge_path)), auto_fit=False)
        chk("dépassement d'enveloppe X refusé", False)
    except ValueError as exc:
        chk("dépassement d'enveloppe X refusé", "course machine" in str(exc), str(exc))

    print("\n5. Génération complète PEEK 5 axes + Dossier ISO 13485 + Aperçu 3D")
    gcode, report, dossier, preview_dict = stl_to_implant_gcode(
        str(plate_path),
        ImplantCutConfig(
            material_id="peek",
            implant_type="plaque_cranienne",
            tool_dia=6.0,
            ap=0.5,  # volontairement trop haut : doit être bridé à 0.15 mm (PEEK)
            stepover=1.5,
            lot_id="LOT-2026-CHU-01",
            patient_ref="CAS-CRANE-042",
        ),
    )
    chk("ap bridé au plafond PEEK (0.15 mm)", abs(report["ap_mm"] - 0.15) < 1e-6, f"ap={report['ap_mm']}")
    chk("coupe à sec M9 présente dans le G-code", "M9" in gcode)
    chk("aucun arrosage M7/M8 dans le G-code", "M7" not in gcode and "M8" not in gcode)
    chk("ébauche 3 axes + finition 5 axes présentes", report["couches_ebauche"] >= 10 and report["points_finition"] > 20)
    chk("mouvements 5 axes (A et C) générés", " A" in gcode and " C" in gcode)
    chk(
        "dossier médical ISO 13485 complet avec SHA-256",
        dossier["lot_id"] == "LOT-2026-CHU-01"
        and len(dossier["fichiers_et_empreintes"]["source_stl_sha256"]) == 64
        and len(dossier["fichiers_et_empreintes"]["programme_nc_sha256"]) == 64,
    )
    chk(
        "aperçu 3D compatible three_viewer.html",
        preview_dict["triangles"] > 0 and len(preview_dict["vertices"]) > 0,
    )

    print("\n6. Support des fichiers STEP B-Rep natifs (CAO)")
    from OCP.BRepPrimAPI import BRepPrimAPI_MakeSphere
    from step_io import write_step

    step_path = tmp / "spherical_cap.step"
    write_step(BRepPrimAPI_MakeSphere(12.0).Shape(), str(step_path))
    gcode_step, report_step, dossier_step, preview_step = stl_to_implant_gcode(
        str(step_path),
        ImplantCutConfig(
            material_id="pmma",
            implant_type="modele_anatomique",
            tool_dia=6.0,
            ap=0.2,
            stepover=2.0,
            lot_id="LOT-STEP-2026",
            patient_ref="CAS-STEP-001",
        ),
        step_deflection=0.01,
    )
    chk("STEP relu et maillé avec succès", report_step["lignes_gcode"] > 10)
    chk("format STEP consigné dans le dossier ISO 13485", dossier_step["fichiers_et_empreintes"]["format"] == "STEP")
    chk("G-code STEP généré avec coupe à sec M9", "M9" in gcode_step and "M7" not in gcode_step)
    chk("aperçu 3D généré depuis le STEP", preview_step["triangles"] > 0)

    print("\n" + ("TOUT PASSE" if _ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ"))
    return 0 if _ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
