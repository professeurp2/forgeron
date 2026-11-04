"""Génération et vérification des fiches de provenance pour le service reco3d.

Règles impératives de docs/conception-photos-vers-step.md :
1. Rien d'inventé affiché comme mesuré :
   - Mode GEN => `is_approximate = True`, `notes.append("Forme issue d'un modèle génératif — cotes non contractuelles")`
   - Mode PHOTO sans mire => `is_approximate = True`, `notes.append("Aucune mire d'échelle détectée — modèle sans cote")`
   - Mode PHOTO avec mire => `is_approximate = False`, `scale_factor` renseigné.
2. Signalement des trous :
   - Les trous de reconstruction ne sont jamais comblés en silence.
"""

from __future__ import annotations

import datetime
import json
from pathlib import Path
from typing import List, Optional

from models import JobMode, ProvenanceInfo, ScaleReference, ScaleType


def build_provenance(
    mode: JobMode,
    engine: str,
    engine_version: str,
    photo_count: int,
    scale_ref: Optional[ScaleReference] = None,
    unreconstructed_holes_count: int = 0,
    facets_count: Optional[int] = None,
    extra_notes: Optional[List[str]] = None,
) -> ProvenanceInfo:
    notes: List[str] = list(extra_notes or [])

    has_scale = False
    scale_type = ScaleType.NONE
    scale_factor = None
    is_approximate = True

    if mode == JobMode.GEN:
        is_approximate = True
        notes.append("Forme issue d'un modèle génératif — géométrie approximative, sans échelle d'origine.")
        if scale_ref and scale_ref.scale_type == ScaleType.MANUAL_EDGE and scale_ref.dimension_mm:
            notes.append(f"Échelle calée manuellement sur une arête de référence : {scale_ref.dimension_mm:.2f} mm.")
            has_scale = True
            scale_type = ScaleType.MANUAL_EDGE
            scale_factor = scale_ref.dimension_mm
    else:  # PHOTO
        if scale_ref and scale_ref.detected and scale_ref.scale_type in (ScaleType.ARUCO, ScaleType.CHARUCO, ScaleType.RULER):
            has_scale = True
            scale_type = scale_ref.scale_type
            scale_factor = scale_ref.dimension_mm
            is_approximate = False
            notes.append(f"Échelle métrique certifiée par mire ({scale_ref.scale_type.value}) : {scale_ref.dimension_mm} mm.")
        else:
            is_approximate = True
            notes.append("Aucune mire d'échelle détectée — pièce sans cote métrique certifiée.")

    if unreconstructed_holes_count > 0:
        notes.append(f"{unreconstructed_holes_count} zone(s) non reconstruite(s) (trous) conservée(s) et signalée(s).")

    return ProvenanceInfo(
        mode=mode,
        engine=engine,
        engine_version=engine_version,
        has_scale_reference=has_scale,
        scale_type=scale_type,
        scale_factor=scale_factor,
        photo_count=photo_count,
        is_approximate=is_approximate,
        unreconstructed_holes_count=unreconstructed_holes_count,
        facets_count=facets_count,
        created_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        notes=notes,
    )


def save_provenance_file(provenance: ProvenanceInfo, output_path: Path) -> Path:
    """Enregistre la fiche de provenance à côté du fichier 3D (.step ou .stl)."""
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(provenance.model_dump(), f, indent=2, ensure_ascii=False)
    return output_path
