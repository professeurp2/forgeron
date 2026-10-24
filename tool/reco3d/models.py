"""Modèles de données du service reco3d.

Conformes aux règles d'honnêteté de docs/conception-photos-vers-step.md :
- Rien d'inventé affiché comme mesuré (marquage 'is_approximate' strict).
- Chaque résultat porte sa fiche de provenance complète.
"""

from __future__ import annotations

from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class JobMode(str, Enum):
    PHOTO = "photo"  # Photogrammétrie métrique (Meshroom / AliceVision / COLMAP)
    GEN = "gen"      # Génératif concept (TRELLIS / SF3D)


class JobStage(str, Enum):
    QUEUED = "queued"
    SFM = "sfm"                    # Structure-from-Motion
    MVS = "mvs"                    # Multi-View Stereo (nuage dense)
    MESHING = "meshing"            # Maillage et nettoyage (Open3D)
    POSTPROCESSING = "postprocessing"  # Conversion STEP / maillage propre
    DONE = "done"
    FAILED = "failed"


class ScaleType(str, Enum):
    ARUCO = "aruco"
    CHARUCO = "charuco"
    RULER = "ruler"
    MANUAL_EDGE = "manual_edge"
    NONE = "none"


class ScaleReference(BaseModel):
    scale_type: ScaleType = ScaleType.NONE
    dimension_mm: Optional[float] = None
    detected: bool = False
    confidence: float = 0.0


class ProvenanceInfo(BaseModel):
    """Fiche de provenance attestant de l'origine et de la fidélité de la géométrie."""
    mode: JobMode
    engine: str
    engine_version: str
    has_scale_reference: bool = False
    scale_type: ScaleType = ScaleType.NONE
    scale_factor: Optional[float] = None
    photo_count: int = 0
    is_approximate: bool = True  # True par défaut si mode=gen ou sans mire certifiée
    unreconstructed_holes_count: int = 0
    facets_count: Optional[int] = None
    created_at: str
    notes: List[str] = Field(default_factory=list)


class JobCreateResponse(BaseModel):
    job_id: str
    mode: JobMode
    stage: JobStage = JobStage.QUEUED
    queue_position: int = 0
    message: str = "Job mis en file d'attente."


class JobStatusResponse(BaseModel):
    job_id: str
    mode: JobMode
    stage: JobStage
    progress_percent: float = 0.0
    message: str = ""
    error: Optional[str] = None
    provenance: Optional[ProvenanceInfo] = None
    has_step: bool = False
    has_mesh: bool = False


class HealthResponse(BaseModel):
    status: str  # "ready", "busy", "gpu_unavailable"
    gpu_name: Optional[str] = None
    gpu_vram_total_mb: Optional[int] = None
    gpu_vram_free_mb: Optional[int] = None
    active_job_id: Optional[str] = None
    queue_length: int = 0
    engines: Dict[str, str] = Field(default_factory=dict)
