"""Superviseur des services locaux de l'installation Windows de Forgeron.

Lancé par l'application (``pythonw.exe forgeron_services.py --parent-pid N``)
au démarrage, il fait tourner en arrière-plan, sans fenêtre de console :

- **Ollama** (``runtime/ollama/ollama.exe serve``) avec les modèles embarqués
  (``runtime/ollama/models``) — forgeron-qwen, gemma3n ;
- **reco3d** (``uvicorn service:app`` dans ``tool/reco3d``) — photos -> STEP.

Règles :

- un service déjà joignable sur son port (Ollama installé par l'utilisateur,
  reco3d lancé à la main, autre instance de Forgeron) n'est PAS relancé : on
  s'en sert tel quel ;
- un service mort en cours de route est relancé (au plus ``MAX_RESTARTS``
  fois), pour qu'un plantage d'Ollama ne prive pas l'atelier de l'agent IA ;
- quand l'application se ferme — ou plante — le superviseur le voit (le PID
  parent disparaît) et arrête tout ce qu'il a lancé, arbre de processus compris.

Disposition attendue (celle que pose ``installer/forgeron_installer.iss``) ::

    {app}/forgeron.exe
    {app}/forgeron_bundle.json
    {app}/pipeline/                 scripts CAO/FAO
    {app}/tool/reco3d/              service reco3d (+ bin/Meshroom)
    {app}/runtime/python/           Python 3.12 + OCP, numpy, fastapi…
    {app}/runtime/ollama/           ollama.exe + lib/ + models/
    {app}/runtime/forgeron_services.py   (ce fichier)

Journaux : ``%LOCALAPPDATA%\\Forgeron\\logs``.
"""

from __future__ import annotations

import argparse
import ctypes
import datetime
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

CREATE_NO_WINDOW = 0x08000000
SYNCHRONIZE = 0x00100000
WAIT_TIMEOUT = 0x00000102

OLLAMA_PORT = 11434
RECO3D_PORT = 8765
POLL_SECONDS = 2.0
MAX_RESTARTS = 5


def _data_dir() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
    d = Path(base) / "Forgeron"
    d.mkdir(parents=True, exist_ok=True)
    return d


LOG_DIR = _data_dir() / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
_SUPERVISOR_LOG = LOG_DIR / "services.log"


def log(msg: str) -> None:
    stamp = datetime.datetime.now().isoformat(timespec="seconds")
    try:
        with _SUPERVISOR_LOG.open("a", encoding="utf-8") as f:
            f.write(f"{stamp} {msg}\n")
    except OSError:
        pass


def port_open(port: int, host: str = "127.0.0.1", timeout: float = 0.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def parent_alive(pid: int) -> bool:
    """Vrai tant que le processus [pid] existe (Windows : handle SYNCHRONIZE)."""
    if pid <= 0:
        return True
    if os.name != "nt":
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False
    kernel32 = ctypes.windll.kernel32
    handle = kernel32.OpenProcess(SYNCHRONIZE, False, pid)
    if not handle:
        return False
    try:
        return kernel32.WaitForSingleObject(handle, 0) == WAIT_TIMEOUT
    finally:
        kernel32.CloseHandle(handle)


def kill_tree(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    try:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/T", "/F", "/PID", str(proc.pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=CREATE_NO_WINDOW,
                check=False,
            )
        else:
            proc.kill()
        proc.wait(timeout=10)
    except Exception as e:  # noqa: BLE001 - l'arrêt doit aller au bout
        log(f"arrêt de PID {proc.pid} incomplet : {e}")


class Service:
    def __init__(self, name: str, port: int, cmd: List[str], cwd: Path, env: Dict[str, str]):
        self.name = name
        self.port = port
        self.cmd = cmd
        self.cwd = cwd
        self.env = env
        self.proc: Optional[subprocess.Popen] = None
        self.restarts = 0
        self.given_up = False

    def start(self) -> None:
        out = (LOG_DIR / f"{self.name}.log").open("a", encoding="utf-8", errors="replace")
        out.write(f"\n===== {datetime.datetime.now().isoformat(timespec='seconds')} démarrage {self.name}\n")
        out.flush()
        self.proc = subprocess.Popen(
            self.cmd,
            cwd=str(self.cwd),
            env=self.env,
            stdin=subprocess.DEVNULL,
            stdout=out,
            stderr=subprocess.STDOUT,
            creationflags=CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        log(f"{self.name} lancé (PID {self.proc.pid}) : {' '.join(self.cmd)}")

    def tick(self) -> None:
        """Lance le service s'il n'est joignable nulle part, relance s'il est mort."""
        if self.given_up:
            return
        if self.proc is not None and self.proc.poll() is None:
            return  # le nôtre tourne
        if self.proc is not None:
            log(f"{self.name} s'est arrêté (code {self.proc.returncode})")
            self.proc = None
            self.restarts += 1
            if self.restarts > MAX_RESTARTS:
                log(f"{self.name} : trop de redémarrages, abandon")
                self.given_up = True
                return
        if port_open(self.port):
            return  # un autre (Ollama système, autre instance…) répond déjà
        try:
            self.start()
        except OSError as e:
            log(f"{self.name} : lancement impossible : {e}")
            self.given_up = True

    def stop(self) -> None:
        if self.proc is not None:
            log(f"arrêt de {self.name} (PID {self.proc.pid})")
            kill_tree(self.proc)
            self.proc = None


def build_services(app_dir: Path) -> List[Service]:
    services: List[Service] = []
    base_env = dict(os.environ)

    # --- Ollama + modèles embarqués -------------------------------------
    ollama_dir = app_dir / "runtime" / "ollama"
    ollama_exe = ollama_dir / "ollama.exe"
    if ollama_exe.exists():
        env = dict(base_env)
        env.update(
            {
                "OLLAMA_MODELS": str(ollama_dir / "models"),
                # 0.0.0.0 : le téléphone de l'atelier interroge aussi ce PC
                # (réglage « serveur IA local » = http://<ip-du-pc>:11434).
                "OLLAMA_HOST": f"0.0.0.0:{OLLAMA_PORT}",
                # Le dossier des modèles est en lecture seule de fait : jamais
                # de ménage automatique dedans.
                "OLLAMA_NOPRUNE": "1",
            }
        )
        services.append(Service("ollama", OLLAMA_PORT, [str(ollama_exe), "serve"], ollama_dir, env))
    else:
        log(f"Ollama absent ({ollama_exe}) : agent IA local indisponible")

    # --- reco3d -----------------------------------------------------------
    reco3d_dir = app_dir / "tool" / "reco3d"
    python_dir = app_dir / "runtime" / "python"
    python_exe = python_dir / "python.exe"
    if not python_exe.exists():
        python_exe = Path(sys.executable)
    if (reco3d_dir / "service.py").exists():
        storage = _data_dir() / "reco3d" / "storage"
        storage.mkdir(parents=True, exist_ok=True)
        env = dict(base_env)
        env.update(
            {
                "PYTHONNOUSERSITE": "1",
                "PYTHONDONTWRITEBYTECODE": "1",
                "PYTHONUTF8": "1",
                "FORGERON_PYTHON": str(python_exe),
                "FORGERON_RECO3D_STORAGE": str(storage),
            }
        )
        env.pop("PYTHONHOME", None)
        env.pop("PYTHONPATH", None)
        cmd = [
            str(python_exe), "-m", "uvicorn", "service:app",
            "--app-dir", str(reco3d_dir),
            "--host", "0.0.0.0", "--port", str(RECO3D_PORT),
        ]
        services.append(Service("reco3d", RECO3D_PORT, cmd, reco3d_dir, env))
    else:
        log(f"reco3d absent ({reco3d_dir}) : scan 3D par photos indisponible")

    return services


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--parent-pid", type=int, default=0, help="PID de forgeron.exe (0 = ne pas surveiller)")
    ap.add_argument(
        "--app-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="dossier d'installation (défaut : parent de runtime/)",
    )
    args = ap.parse_args()

    app_dir: Path = args.app_dir.resolve()
    log(f"superviseur démarré (PID {os.getpid()}, parent {args.parent_pid}, app {app_dir})")
    services = build_services(app_dir)

    try:
        while parent_alive(args.parent_pid):
            for s in services:
                s.tick()
            time.sleep(POLL_SECONDS)
        log("application fermée : arrêt des services")
    except KeyboardInterrupt:
        log("interruption : arrêt des services")
    finally:
        for s in services:
            s.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())

