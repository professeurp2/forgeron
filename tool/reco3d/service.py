"""Service HTTP reco3d (FastAPI) — photos -> maillage / STEP.

Contrat : docs/conception-photos-vers-step.md, §6.
- Un seul job GPU à la fois (file FIFO, un worker).
- Progression par jalon (queued -> sfm -> mvs -> meshing -> postprocessing -> done).
- Chaque résultat porte sa fiche de provenance.
- Aucun résultat inventé : moteur absent => job FAILED avec motif.

Lancer :  python -m uvicorn service:app --app-dir tool/reco3d --host 0.0.0.0 --port 8765
"""

from __future__ import annotations

import asyncio
import contextlib
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Dict, List, Optional

RECO3D_DIR = Path(__file__).resolve().parent
if str(RECO3D_DIR) not in sys.path:
    sys.path.insert(0, str(RECO3D_DIR))

from fastapi import FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from models import (
    HealthResponse,
    JobCreateResponse,
    JobMode,
    JobStage,
    JobStatusResponse,
    ProvenanceInfo,
    ScaleReference,
    ScaleType,
)
from provenance import build_provenance, save_provenance_file
from runners import LocalEnginesRunner, Runner

STORAGE_DIR = RECO3D_DIR / "storage"


class JobState:
    def __init__(self, job_id: str, mode: JobMode, scale_ref: ScaleReference,
                 job_dir: Path, photo_count: int):
        self.job_id = job_id
        self.mode = mode
        self.scale_ref = scale_ref
        self.job_dir = job_dir
        self.photo_count = photo_count
        self.stage = JobStage.QUEUED
        self.progress = 0.0
        self.message = "En attente dans la file GPU"
        self.error: Optional[str] = None
        self.provenance: Optional[ProvenanceInfo] = None
        self.output_files: Dict[str, Path] = {}


jobs_db: Dict[str, JobState] = {}
runner: Runner = LocalEnginesRunner()
_queue: Optional[asyncio.Queue[str]] = None
active_job_id: Optional[str] = None


def _get_queue() -> asyncio.Queue[str]:
    global _queue
    if _queue is None:
        _queue = asyncio.Queue()
    return _queue


def get_gpu_info() -> tuple[Optional[str], Optional[int], Optional[int]]:
    """Métriques GPU réelles via nvidia-smi ; (None, None, None) si absent."""
    try:
        res = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,memory.free",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, check=True, timeout=5,
        )
        name, total, free = [p.strip() for p in res.stdout.strip().splitlines()[0].split(",")]
        return name, int(total), int(free)
    except Exception:
        return None, None, None


async def process_job(job: JobState) -> None:
    async def on_stage(stage: JobStage, progress: float, message: str) -> None:
        job.stage, job.progress, job.message = stage, progress, message

    out_dir = job.job_dir / "outputs"
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        result = await runner.run(job.mode, job.job_dir / "photos", out_dir,
                                  job.scale_ref, on_stage)
    except Exception as exc:  # moteur absent, échec de reconstruction...
        job.stage = JobStage.FAILED
        job.error = str(exc)
        job.message = f"Échec : {exc}"
        return

    # La détection de mire vient du moteur, jamais de la seule déclaration.
    measured_scale = job.scale_ref.model_copy(update={"detected": result.scale_detected})
    prov = build_provenance(
        mode=job.mode,
        engine=result.engine,
        engine_version=result.engine_version,
        photo_count=job.photo_count,
        scale_ref=measured_scale,
        unreconstructed_holes_count=result.holes_count,
        facets_count=result.facets_count,
        extra_notes=result.notes,
    )
    job.output_files["mesh"] = result.mesh_path
    if result.step_path:
        job.output_files["step"] = result.step_path
    prov_path = save_provenance_file(prov, out_dir / f"{job.job_id}_provenance.json")
    job.output_files["provenance"] = prov_path
    job.provenance = prov
    job.stage, job.progress, job.message = JobStage.DONE, 100.0, "Reconstruction terminée."


async def gpu_worker() -> None:
    """Un seul job GPU à la fois : les reconstructions saturent la VRAM."""
    global active_job_id
    q = _get_queue()
    while True:
        job_id = await q.get()
        active_job_id = job_id
        try:
            job = jobs_db.get(job_id)
            if job:
                await process_job(job)
        finally:
            active_job_id = None
            q.task_done()


@contextlib.asynccontextmanager
async def lifespan(_: FastAPI):
    global _queue
    _queue = asyncio.Queue()  # lié à la boucle d'événements du serveur
    STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    task = asyncio.create_task(gpu_worker())
    try:
        yield
    finally:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


app = FastAPI(title="Forgeron reco3d", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    gpu_name, total, free = get_gpu_info()
    if active_job_id:
        st = "busy"
    elif gpu_name is None:
        st = "gpu_unavailable"
    else:
        st = "ready"
    return HealthResponse(
        status=st, gpu_name=gpu_name, gpu_vram_total_mb=total, gpu_vram_free_mb=free,
        active_job_id=active_job_id, queue_length=_get_queue().qsize(),
        engines={m.value: runner.availability(m)[1] for m in JobMode},
    )


@app.post("/jobs", response_model=JobCreateResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_job(
    mode: str = Form("photo"),
    scale_type: str = Form("none"),
    scale_mm: Optional[float] = Form(None),
    photos: List[UploadFile] = File(...),
) -> JobCreateResponse:
    try:
        job_mode = JobMode(mode.lower())
    except ValueError:
        raise HTTPException(400, f"Mode invalide : {mode} (attendu : photo ou gen).")
    try:
        sc_type = ScaleType(scale_type.lower())
    except ValueError:
        raise HTTPException(400, f"Type d'échelle invalide : {scale_type}.")
    if sc_type != ScaleType.NONE and (scale_mm is None or scale_mm <= 0):
        raise HTTPException(400, "Une référence d'échelle exige scale_mm > 0.")

    job_id = f"job_{uuid.uuid4().hex[:8]}"
    job_dir = STORAGE_DIR / job_id
    photos_dir = job_dir / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)
    saved = 0
    for i, upload in enumerate(photos):
        # Nom réécrit : jamais de chemin fourni par le client sur le disque.
        suffix = Path(upload.filename or "").suffix.lower() or ".jpg"
        (photos_dir / f"{i:03d}{suffix}").write_bytes(await upload.read())
        saved += 1
    if saved == 0:
        raise HTTPException(400, "Au moins une image est requise.")

    # Déclaration seulement : `detected` reste False tant que le moteur
    # n'a pas retrouvé la mire dans les images.
    declared = ScaleReference(scale_type=sc_type, dimension_mm=scale_mm, detected=False)
    jobs_db[job_id] = JobState(job_id, job_mode, declared, job_dir, saved)
    q = _get_queue()
    await q.put(job_id)
    return JobCreateResponse(job_id=job_id, mode=job_mode, queue_position=q.qsize(),
                             message="Images reçues, job placé dans la file GPU.")


def _job_or_404(job_id: str) -> JobState:
    job = jobs_db.get(job_id)
    if not job:
        raise HTTPException(404, f"Job {job_id} introuvable.")
    return job


@app.get("/jobs/{job_id}", response_model=JobStatusResponse)
async def job_status(job_id: str) -> JobStatusResponse:
    job = _job_or_404(job_id)
    return JobStatusResponse(
        job_id=job.job_id, mode=job.mode, stage=job.stage,
        progress_percent=job.progress, message=job.message, error=job.error,
        provenance=job.provenance,
        has_step="step" in job.output_files, has_mesh="mesh" in job.output_files,
    )


@app.get("/jobs/{job_id}/result")
async def job_result(job_id: str, format: str = "mesh"):
    job = _job_or_404(job_id)
    if job.stage != JobStage.DONE:
        raise HTTPException(409, f"Job non terminé (état : {job.stage.value}).")
    key = "step" if format.lower() == "step" else "mesh"
    path = job.output_files.get(key)
    if not path or not path.exists():
        raise HTTPException(404, f"Aucune sortie « {key} » pour ce job.")
    media = "application/step" if key == "step" else "application/octet-stream"
    return FileResponse(str(path), filename=path.name, media_type=media)


@app.get("/jobs/{job_id}/provenance", response_model=ProvenanceInfo)
async def job_provenance(job_id: str) -> ProvenanceInfo:
    job = _job_or_404(job_id)
    if not job.provenance:
        raise HTTPException(409, "Provenance disponible seulement une fois le job terminé.")
    return job.provenance
