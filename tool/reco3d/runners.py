"""Moteurs de reconstruction du service reco3d.

Règle : le service n'invente rien. Un moteur absent fait ÉCHOUER le job avec
un motif lisible ; il ne fabrique jamais un fichier de remplacement. Les
tests injectent leur propre runner (voir test_reco3d.py) — c'est le seul
endroit où un résultat factice est permis, et il y est nommé comme tel.

La détection de la mire d'échelle appartient au moteur, pas à l'utilisateur :
la taille déclarée dans la requête n'est qu'une attente. Seul
`RunnerResult.scale_detected` peut lever le marquage « approximatif ».
"""

from __future__ import annotations

import asyncio
import json
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Awaitable, Callable, List, Optional, Protocol

from models import JobMode, JobStage, ScaleReference

StageCallback = Callable[[JobStage, float, str], Awaitable[None]]

VENV_PYTHON = Path(__file__).resolve().parents[2] / "pipeline" / ".venv312" / "Scripts" / "python.exe"
RECONSTRUCT_SCRIPT = Path(__file__).resolve().parent / "reconstruct.py"


class EngineUnavailable(RuntimeError):
    """Le moteur requis n'est pas installé sur ce poste."""


@dataclass
class RunnerResult:
    mesh_path: Path
    engine: str
    engine_version: str
    step_path: Optional[Path] = None
    scale_detected: bool = False
    holes_count: int = 0
    facets_count: Optional[int] = None
    notes: List[str] = field(default_factory=list)


class Runner(Protocol):
    def availability(self, mode: JobMode) -> tuple[bool, str]: ...

    async def run(
        self,
        mode: JobMode,
        photos_dir: Path,
        out_dir: Path,
        declared_scale: ScaleReference,
        on_stage: StageCallback,
    ) -> RunnerResult: ...


def find_meshroom_binary() -> Optional[Path]:
    """Recherche l'exécutable meshroom_batch dans le PATH ou dans tool/reco3d/bin/."""
    found = shutil.which("meshroom_batch")
    if found:
        return Path(found)
    bin_dir = Path(__file__).resolve().parent / "bin"
    if bin_dir.exists():
        candidates = list(bin_dir.glob("**/meshroom_batch.exe"))
        if candidates:
            return candidates[0]
    for p in [
        Path("C:/Program Files/Meshroom/meshroom_batch.exe"),
        Path("C:/tools/Meshroom/meshroom_batch.exe"),
        Path("C:/Meshroom/meshroom_batch.exe"),
    ]:
        if p.exists():
            return p
    return None


class LocalEnginesRunner:
    """Runner de reconstruction local combinant photogrammétrie et IA générative."""

    def availability(self, mode: JobMode) -> tuple[bool, str]:
        if not VENV_PYTHON.exists():
            return False, f"environnement de calcul absent ({VENV_PYTHON})"
        if not RECONSTRUCT_SCRIPT.exists():
            return False, f"script de reconstruction absent ({RECONSTRUCT_SCRIPT})"

        if mode == JobMode.PHOTO:
            if not find_meshroom_binary():
                return False, "moteur(s) absent(s) sur ce poste : meshroom_batch"
            return True, "moteurs présents (Meshroom + OCP)"

        if mode == JobMode.GEN:
            return True, "moteurs présents (reconstruction conceptuelle OCP/Trimesh)"

        return True, "moteurs présents"

    async def run(
        self,
        mode: JobMode,
        photos_dir: Path,
        out_dir: Path,
        declared_scale: ScaleReference,
        on_stage: StageCallback,
    ) -> RunnerResult:
        ok, reason = self.availability(mode)
        if not ok:
            raise EngineUnavailable(reason)

        scale_mm = declared_scale.dimension_mm or 50.0
        scale_type = (
            declared_scale.scale_type.value
            if hasattr(declared_scale.scale_type, "value")
            else str(declared_scale.scale_type)
        )

        cmd = [
            str(VENV_PYTHON),
            str(RECONSTRUCT_SCRIPT),
            "--photos-dir", str(photos_dir),
            "--out-dir", str(out_dir),
            "--mode", mode.value,
            "--scale-mm", str(scale_mm),
            "--scale-type", scale_type,
        ]

        mb = find_meshroom_binary()
        if mb:
            cmd.extend(["--meshroom-bin", str(mb)])

        await on_stage(JobStage.QUEUED, 5.0, "Démarrage du processus de reconstruction...")

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stage_map = {
            "queued": JobStage.QUEUED,
            "sfm": JobStage.SFM,
            "mvs": JobStage.MVS,
            "meshing": JobStage.MESHING,
            "postprocessing": JobStage.POSTPROCESSING,
            "done": JobStage.DONE,
            "failed": JobStage.FAILED,
        }

        while True:
            line_bytes = await proc.stdout.readline()
            if not line_bytes:
                break
            line = line_bytes.decode("utf-8", errors="replace").strip()
            if line.startswith("STAGE:"):
                parts = line.split(":", 3)
                if len(parts) == 4:
                    _, stg_str, pct_str, msg = parts
                    stg = stage_map.get(stg_str, JobStage.QUEUED)
                    # Ne pas publier DONE prématurément tant que les fichiers ne sont pas enregistrés dans service.py
                    if stg == JobStage.DONE:
                        stg = JobStage.POSTPROCESSING
                        pct_val = min(float(pct_str), 99.0)
                    else:
                        pct_val = float(pct_str)
                    try:
                        await on_stage(stg, pct_val, msg)
                    except Exception:
                        pass

        stderr_data = await proc.stderr.read()
        await proc.wait()

        if proc.returncode != 0:
            err_msg = stderr_data.decode("utf-8", errors="replace").strip()
            raise RuntimeError(f"Échec reconstruction 3D (code {proc.returncode}): {err_msg}")

        metrics_file = out_dir / "metrics.json"
        metrics = {}
        if metrics_file.exists():
            try:
                with open(metrics_file, "r", encoding="utf-8") as f:
                    metrics = json.load(f)
            except Exception:
                pass

        stl_path = out_dir / "reconstruction.stl"
        step_path = out_dir / "reconstruction.step"

        # La détection d'échelle vient du MOTEUR (metrics.json), JAMAIS du type
        # déclaré par l'opérateur : déclarer « aruco » ne vaut pas détecter une
        # mire. Tant que la détection de mire n'est pas implémentée dans
        # reconstruct.py, la clé "scale_detected" est absente => False, et la
        # pièce reste « approximative » (cote non garantie) — exigence de
        # docs/conception-photos-vers-step.md.
        scale_detected = bool(metrics.get("scale_detected", False))
        is_watertight = metrics.get("is_watertight")
        applied_mm = metrics.get("scale_applied_mm", scale_mm)

        notes: List[str] = []
        if is_watertight is True:
            notes.append("Maillage étanche, orienté machine (Z vertical, base à Z=0).")
        elif is_watertight is False:
            notes.append("Maillage NON étanche (trous non reconstruits) — à vérifier avant usinage.")
        if scale_detected:
            notes.append(f"Échelle mesurée par le moteur : {applied_mm} mm.")
        else:
            notes.append(
                f"Échelle de normalisation appliquée par défaut (non mesurée) : {applied_mm} mm "
                "— cote NON garantie."
            )

        return RunnerResult(
            mesh_path=stl_path,
            step_path=step_path if step_path.exists() else None,
            engine=metrics.get("engine", "Forgeron Visual Hull (Marching Cubes + OCP)"),
            engine_version=metrics.get("engine_version", "1.0.0"),
            scale_detected=scale_detected,
            facets_count=metrics.get("facets_count"),
            notes=notes,
        )
