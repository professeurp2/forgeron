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

import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Awaitable, Callable, List, Optional, Protocol

from models import JobMode, JobStage, ScaleReference

StageCallback = Callable[[JobStage, float, str], Awaitable[None]]


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


# Exécutables attendus par mode (doc de conception, §2). Le génératif passe
# par un script Python TRELLIS/SF3D, dont l'emplacement sera épinglé en phase 2.
_REQUIRED = {
    JobMode.PHOTO: ["meshroom_batch", "freecadcmd"],
    JobMode.GEN: ["trellis_infer", "freecadcmd"],
}


class LocalEnginesRunner:
    """Runner de production : vérifie la présence réelle des moteurs.

    L'invocation de Meshroom / TRELLIS est l'objet des phases 1 et 2 ; tant
    qu'elle n'est pas écrite ET mesurée, `run` refuse explicitement plutôt
    que de produire un résultat non vérifié.
    """

    def availability(self, mode: JobMode) -> tuple[bool, str]:
        missing = [exe for exe in _REQUIRED[mode] if shutil.which(exe) is None]
        if missing:
            return False, f"moteur(s) absent(s) sur ce poste : {', '.join(missing)}"
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
        raise EngineUnavailable(
            f"chaîne « {mode.value} » non encore implémentée (phase "
            f"{'1' if mode == JobMode.PHOTO else '2'} du plan)"
        )
