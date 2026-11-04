"""Infrastructure de capture pour le scan en machine (doc §12).

Boucle : pour chaque pose (A, C) connue → commander l'axe (ControllerLink) →
lire la position rapportée → capturer depuis chaque caméra (CameraSource) →
étiqueter la vue {camera_id, A, C}. Les angles étant CONNUS (encodeurs de la
machine), on produit un jeu de vues MULTI-VUES CALIBRÉES, pas du freehand.

Règle d'honnêteté (comme le reste de reco3d) : rien d'inventé. En simulation
(pas de moteurs ni de câblage), le contrôleur est en BOUCLE OUVERTE — il
rapporte l'angle *commandé*, et `views.json` le signale (`open_loop: true`).

Trois briques, chacune avec une implémentation réelle et une de simulation :
- CameraSource   : HttpCamera (ESP32-CAM) | SyntheticCamera (sans matériel)
- ControllerLink : FluidNcController (WebSocket) | SimController (boucle ouverte)
- CapturePlan    : la liste des poses (A, C) à parcourir

Aucune dépendance obligatoire hors stdlib pour le chemin de simulation. PIL
n'est requis que par SyntheticCamera ; `websockets` que par FluidNcController.
"""

from __future__ import annotations

import json
import time
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Protocol

# Course de l'axe A — doit rester cohérente avec pipeline/kinematics.py (Trunnion).
A_MIN_DEG = -88.0
A_MAX_DEG = 90.0


class CaptureError(RuntimeError):
    """Échec de capture d'une caméra (réseau, caméra absente, réponse vide)."""


class ControllerError(RuntimeError):
    """Échec de dialogue avec le contrôleur (FluidNC)."""


@dataclass(frozen=True)
class Pose:
    """Une orientation du plateau, en degrés machine."""

    a_deg: float
    c_deg: float


def pose_in_course(pose: Pose) -> bool:
    """La pose tient-elle dans la course de l'axe A ? (C tourne sans butée.)"""
    return A_MIN_DEG <= pose.a_deg <= A_MAX_DEG


# --------------------------------------------------------------------------- #
# Caméras                                                                      #
# --------------------------------------------------------------------------- #
class CameraSource(Protocol):
    id: str

    def capture(self, pose: Optional[Pose] = None) -> bytes:
        """Renvoie une image JPEG. `pose` est une métadonnée : une vraie caméra
        l'ignore (elle filme ce qui est devant elle)."""
        ...


@dataclass
class HttpCamera:
    """Caméra réelle sur le réseau (ESP32-CAM) : une requête HTTP = une image."""

    id: str
    url: str
    timeout_s: float = 5.0

    def capture(self, pose: Optional[Pose] = None) -> bytes:
        req = urllib.request.Request(self.url, headers={"User-Agent": "reco3d-capture"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
                data = resp.read()
        except Exception as exc:  # réseau, timeout, DNS, HTTP…
            raise CaptureError(f"caméra {self.id} injoignable ({self.url}) : {exc}") from exc
        if not data:
            raise CaptureError(f"caméra {self.id} : réponse vide depuis {self.url}")
        return data


@dataclass
class SyntheticCamera:
    """Caméra factice SANS MATÉRIEL : dessine une image portant la pose, pour
    tester la plomberie (étiquetage, stockage, ingestion) à vide. Nommée comme
    telle — ce n'est jamais une vraie reconstruction."""

    id: str
    size: tuple = (320, 240)

    def capture(self, pose: Optional[Pose] = None) -> bytes:
        from io import BytesIO

        from PIL import Image, ImageDraw  # dépendance locale, déjà dans le venv

        img = Image.new("RGB", self.size, (28, 32, 40))
        d = ImageDraw.Draw(img)
        a = pose.a_deg if pose else 0.0
        c = pose.c_deg if pose else 0.0
        d.text((10, 10), f"SYNTHETIQUE {self.id}", fill=(230, 230, 230))
        d.text((10, 30), f"A={a:+.1f}  C={c:.1f}", fill=(120, 200, 255))
        # Une pièce modèle (cylindre/bloc au centre du plateau)
        cx, cy, r = self.size[0] / 2, self.size[1] / 2, 70
        d.rectangle([cx - 30, cy - 40, cx + 30, cy + 40], fill=(210, 80, 50))
        # Un repère qui tourne avec C, pour que les vues diffèrent visiblement.
        import math

        x = cx + r * math.cos(math.radians(c))
        y = cy + r * math.sin(math.radians(c))
        d.line((cx, cy, x, y), fill=(255, 160, 60), width=4)
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=80)
        return buf.getvalue()


# --------------------------------------------------------------------------- #
# Contrôleur                                                                   #
# --------------------------------------------------------------------------- #
class ControllerLink(Protocol):
    def move_to(self, a_deg: float, c_deg: float) -> None: ...

    def position(self) -> tuple[float, float]:
        """(A, C) rapportés par le contrôleur, en degrés."""
        ...

    def close(self) -> None: ...


@dataclass
class SimController:
    """Contrôleur de SIMULATION : aucun moteur, aucun câblage. Boucle ouverte —
    la position rapportée est la position commandée. C'est le jalon 5.0."""

    _a: float = 0.0
    _c: float = 0.0

    def move_to(self, a_deg: float, c_deg: float) -> None:
        self._a, self._c = a_deg, c_deg

    def position(self) -> tuple[float, float]:
        return (self._a, self._c)

    def close(self) -> None:
        pass


@dataclass
class FluidNcController:
    """Contrôleur RÉEL via WebSocket FluidNC. NON TESTÉ sans matériel — fourni
    pour le jalon 5.1+. Nécessite `pip install websockets`.

    Hypothèses (à confirmer sur la vraie carte) : statut FluidNC de la forme
    `<Idle|MPos:x,y,z,a,c|...>` (5 axes X Y Z A C), déplacement par G-code
    `G90 G0 A<..> C<..>`. En boucle fermée, `position()` relit MPos (A=idx 3,
    C=idx 4). Tant que ce n'est pas validé sur machine, préférer SimController.
    """

    ws_url: str  # ex. "ws://192.168.0.1:81/"
    feed_settle_s: float = 0.0
    _ws: Optional[object] = field(default=None, repr=False)

    def _connect(self):
        if self._ws is not None:
            return
        try:
            from websocket import create_connection  # websocket-client
        except Exception as exc:  # pragma: no cover - dépend du matériel
            raise ControllerError(
                "FluidNcController nécessite `pip install websocket-client`. "
                "Pour un essai sans matériel, utiliser SimController."
            ) from exc
        self._ws = create_connection(self.ws_url, timeout=5.0)

    def move_to(self, a_deg: float, c_deg: float) -> None:  # pragma: no cover
        self._connect()
        self._ws.send(f"G90 G0 A{a_deg:.3f} C{c_deg:.3f}\n")

    def position(self) -> tuple[float, float]:  # pragma: no cover
        self._connect()
        self._ws.send("?")
        status = self._ws.recv()
        # <Idle|MPos:0.000,0.000,0.000,0.000,0.000|...>
        try:
            mpos = status.split("MPos:")[1].split("|")[0]
            vals = [float(v) for v in mpos.split(",")]
            return (vals[3], vals[4])
        except Exception as exc:
            raise ControllerError(f"statut FluidNC illisible : {status!r}") from exc

    def close(self) -> None:  # pragma: no cover
        if self._ws is not None:
            with __import__("contextlib").suppress(Exception):
                self._ws.close()
            self._ws = None


# --------------------------------------------------------------------------- #
# Plan de capture                                                              #
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class CapturePlan:
    poses: List[Pose]
    settle_s: float = 0.5  # temps de stabilisation après un mouvement

    @staticmethod
    def orbit_c(n: int = 8, a_deg: float = 0.0, settle_s: float = 0.5) -> "CapturePlan":
        """Orbite simple : n pas réguliers de l'axe C, A fixe."""
        if n < 1:
            raise ValueError("n doit être >= 1")
        step = 360.0 / n
        return CapturePlan([Pose(a_deg, i * step) for i in range(n)], settle_s=settle_s)

    def out_of_course(self) -> List[Pose]:
        """Poses dont l'angle A sort de la course machine (à ne pas commander)."""
        return [p for p in self.poses if not pose_in_course(p)]


# --------------------------------------------------------------------------- #
# Chargement de la config caméras                                             #
# --------------------------------------------------------------------------- #
def load_cameras(path: Path, synthetic: bool = False) -> List[CameraSource]:
    """Lit cameras.json et instancie les caméras actives (champ `cameras`).
    `synthetic=True` remplace chaque caméra par une SyntheticCamera de même id,
    pour un essai sans matériel."""
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    cams: List[CameraSource] = []
    for c in doc.get("cameras", []):
        if synthetic:
            cams.append(SyntheticCamera(id=c["id"]))
        else:
            cams.append(HttpCamera(id=c["id"], url=c["url"]))
    if not cams:
        raise ValueError(f"aucune caméra active dans {path}")
    return cams


# --------------------------------------------------------------------------- #
# Orchestration                                                                #
# --------------------------------------------------------------------------- #
def run_capture(
    plan: CapturePlan,
    cameras: List[CameraSource],
    controller: ControllerLink,
    out_dir: Path,
    *,
    simulation: bool,
    on_progress=None,
) -> dict:
    """Parcourt le plan, capture et étiquette chaque vue, écrit `views.json`.
    Renvoie le document views. Lève si une pose sort de la course A."""
    bad = plan.out_of_course()
    if bad:
        raise ControllerError(
            f"{len(bad)} pose(s) hors course A [{A_MIN_DEG}, {A_MAX_DEG}]° — refusé : "
            f"{[(p.a_deg, p.c_deg) for p in bad]}"
        )

    out_dir = Path(out_dir)
    photos_dir = out_dir / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)

    views: List[dict] = []
    total = len(plan.poses)
    for i, pose in enumerate(plan.poses):
        controller.move_to(pose.a_deg, pose.c_deg)
        if plan.settle_s:
            time.sleep(plan.settle_s)
        a_rep, c_rep = controller.position()
        for cam in cameras:
            data = cam.capture(pose)
            name = f"{cam.id}_{i:03d}_A{a_rep:+06.1f}_C{c_rep:05.1f}.jpg"
            (photos_dir / name).write_bytes(data)
            views.append(
                {
                    "file": f"photos/{name}",
                    "camera_id": cam.id,
                    "index": i,
                    "a_deg": a_rep,
                    "c_deg": c_rep,
                    "commanded_a_deg": pose.a_deg,
                    "commanded_c_deg": pose.c_deg,
                }
            )
        if on_progress:
            on_progress(i + 1, total)

    doc = {
        "simulation": simulation,
        "open_loop": simulation,  # boucle ouverte : rapporté == commandé
        "camera_count": len(cameras),
        "pose_count": total,
        "view_count": len(views),
        "a_course_deg": [A_MIN_DEG, A_MAX_DEG],
        "notes": [
            "Vues multi-caméras CALIBRÉES par angles connus (encodeurs machine)."
            if not simulation
            else "SIMULATION : boucle ouverte (angle commandé = angle rapporté), "
            "rotation non réelle — valide la plomberie, pas la qualité.",
        ],
        "views": views,
    }
    (out_dir / "views.json").write_text(
        json.dumps(doc, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return doc
