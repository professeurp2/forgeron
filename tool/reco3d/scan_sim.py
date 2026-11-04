"""Point d'entrée — bring-up du scan en machine EN SIMULATION (doc §12.1, jalon 5.0).

Zéro câblage : aucun moteur, aucun driver, aucune broche. On utilise
SimController (boucle ouverte) et, pour les caméras, soit la vraie ESP32-CAM
sur le réseau (défaut, via cameras.json), soit des images synthétiques
(--synthetic) pour un essai 100 % sans matériel.

But : prouver la plomberie — commander un angle, lire la position, capturer,
étiqueter {cam, A, C}, écrire un job reco3d ingérable par reconstruct.py.
Ce que ça NE prouve PAS : la qualité d'une reconstruction (une caméra, pas de
vraie rotation) — c'est écrit dans views.json.

Exemples :
    # Sans aucun matériel (images synthétiques) :
    python tool/reco3d/scan_sim.py --synthetic --poses 8

    # Avec l'ESP32-CAM réelle sur l'AP (IP dans cameras.json) :
    python tool/reco3d/scan_sim.py --poses 12
"""

from __future__ import annotations

import argparse
import sys
import uuid
from pathlib import Path

RECO3D_DIR = Path(__file__).resolve().parent
if str(RECO3D_DIR) not in sys.path:
    sys.path.insert(0, str(RECO3D_DIR))

from capture import CapturePlan, SimController, load_cameras, run_capture

STORAGE_DIR = RECO3D_DIR / "storage"


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan en machine — simulation (jalon 5.0, sans câblage)")
    ap.add_argument("--cameras", type=Path, default=RECO3D_DIR / "cameras.json",
                    help="config des caméras (défaut : tool/reco3d/cameras.json)")
    ap.add_argument("--poses", type=int, default=8, help="nombre de pas de l'axe C")
    ap.add_argument("--a-deg", type=float, default=0.0, help="angle A fixe (dans la course)")
    ap.add_argument("--settle", type=float, default=0.0, help="stabilisation après mouvement (s)")
    ap.add_argument("--synthetic", action="store_true",
                    help="images synthétiques au lieu de l'ESP32-CAM (aucun matériel)")
    ap.add_argument("--out", type=Path, default=None, help="dossier du job (défaut : storage/job_XXXX)")
    args = ap.parse_args()

    out_dir = args.out or (STORAGE_DIR / f"job_{uuid.uuid4().hex[:8]}")

    try:
        cameras = load_cameras(args.cameras, synthetic=args.synthetic)
    except Exception as exc:
        print(f"Erreur config caméras : {exc}", file=sys.stderr)
        return 1

    controller = SimController()
    plan = CapturePlan.orbit_c(n=args.poses, a_deg=args.a_deg)

    src = "synthétiques (sans matériel)" if args.synthetic else "ESP32-CAM réelle(s) sur le réseau"
    print(f"Scan SIMULATION — {len(cameras)} caméra(s) {src}, {args.poses} poses, A={args.a_deg:+.1f}°")
    print(f"Contrôleur : SimController (boucle ouverte, aucun moteur). Sortie : {out_dir}")

    def progress(done, total):
        print(f"  pose {done}/{total}")

    try:
        doc = run_capture(plan, cameras, controller, out_dir,
                          simulation=True, on_progress=progress)
    except Exception as exc:
        print(f"Échec capture : {exc}", file=sys.stderr)
        return 2
    finally:
        controller.close()

    print(f"\nOK : {doc['view_count']} vue(s) étiquetée(s) -> {out_dir / 'photos'}")
    print(f"     poses {doc['pose_count']}, boucle ouverte={doc['open_loop']}, views.json écrit.")
    print(f"\nÉtape suivante (ingestion par la reconstruction) :")
    print(f'     python tool/reco3d/reconstruct.py --photos-dir "{out_dir / "photos"}" '
          f'--out-dir "{out_dir / "outputs"}" --mode gen')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
