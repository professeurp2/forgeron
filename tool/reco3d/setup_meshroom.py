"""Script de téléchargement et configuration automatique de Meshroom pour Forgeron.

Télécharge Meshroom 2023.3.0 portable pour Windows (x64) et le place dans `tool/reco3d/bin/Meshroom`.
"""

import os
import sys
import zipfile
import urllib.request
from pathlib import Path

MESHROOM_ZIP_URL = "https://github.com/alicevision/Meshroom/releases/download/v2023.3.0/Meshroom-2023.3.0-win64.zip"
TARGET_DIR = Path(__file__).resolve().parent / "bin" / "Meshroom"
ZIP_PATH = Path(__file__).resolve().parent / "bin" / "meshroom.zip"


def report_progress(block_num, block_size, total_size):
    downloaded = block_num * block_size
    if total_size > 0:
        percent = min(100.0, downloaded * 100.0 / total_size)
        mb_down = downloaded / (1024 * 1024)
        mb_tot = total_size / (1024 * 1024)
        if block_num % 500 == 0 or percent >= 100.0:
            print(f"Téléchargement Meshroom : {percent:.1f}% ({mb_down:.1f} / {mb_tot:.1f} Mo)", flush=True)


def install_meshroom():
    TARGET_DIR.parent.mkdir(parents=True, exist_ok=True)
    exe_candidate = TARGET_DIR / "meshroom_batch.exe"
    nested_exe = list(TARGET_DIR.glob("**/meshroom_batch.exe"))
    if exe_candidate.exists() or nested_exe:
        print(f"Meshroom est déjà installé dans {TARGET_DIR}")
        return True

    print(f"Téléchargement de Meshroom depuis {MESHROOM_ZIP_URL}...")
    try:
        urllib.request.urlretrieve(MESHROOM_ZIP_URL, str(ZIP_PATH), reporthook=report_progress)
    except Exception as e:
        print(f"Échec du téléchargement : {e}")
        return False

    print("Extraction de l'archive Meshroom...")
    try:
        with zipfile.ZipFile(str(ZIP_PATH), "r") as z:
            z.extractall(str(TARGET_DIR))
        print("Extraction terminée avec succès.")
        if ZIP_PATH.exists():
            ZIP_PATH.unlink()
        return True
    except Exception as e:
        print(f"Échec de l'extraction : {e}")
        return False


if __name__ == "__main__":
    success = install_meshroom()
    sys.exit(0 if success else 1)
