# Installateur et Déploiement Autonome — Forgeron CNC 5-Axes

Ce dossier contient l'infrastructure d'empaquetage pour générer l'installateur Windows autonome unifié de Forgeron.

## Architecture du Système Embarqué

L'installateur produit un système 100 % autonome, prêt pour une utilisation en atelier sans connexion Internet ni dépendances préinstallées sur la machine hôte :

1. **Frontend IHM (Flutter Windows x64)**
   - Compilé en mode `--release` avec accélération matérielle et vue 3D WebView2.
   - Intègre les fenêtres détachables (ai_sub_window), la télémétrie Grbl-HAL, la simulation 5 axes en continu et le visualiseur WebGL / Three.js.

2. **Backend CAO / FAO & Calcul Géométrique (Python 3.12 Portable)**
   - Embarque un runtime Python 3.12 autonome avec les modules spécialisés :
     - `OCP` / `cadquery-ocp` (noyau géométrique OpenCASCADE pour fichiers STEP).
     - `scipy`, `numpy`, `trimesh`, `scikit-image` pour l'analyse des maillages STL et trajectoires 5 axes.
     - `fastapi`, `uvicorn`, `click` pour les services locaux.
   - Scripts de FAO embarqués sous `pipeline/` (`continuous5.py`, `medical_implant.py`, `step_to_gcode.py`, `prismatic_to_gcode.py`, `step_preview.py`).

3. **Reconstruction & Scan 3D (`tool/reco3d/`)**
   - Service FastAPI local pour le calcul de pièces réelles à partir de photographies ou du mode conceptuel.
   - Moteur photogrammétrique AliceVision Meshroom 2023.3.0 préconfiguré sous `tool/reco3d/bin/Meshroom/`.

4. **Serveur d'Inférence IA Local (Ollama & Modèles Embarqués)**
   - Binaire `ollama.exe` avec bibliothèques d'accélération matérielle GPU NVIDIA (CUDA v12/v13) et Vulkan.
   - Modèles pré-téléchargés et prêts à l'emploi :
     - `forgeron-qwen` (Qwen 2.5 7B calibré avec contexte 16k tokens et basse température pour le pilotage machine).
     - `gemma3n:latest` pour la vision artificielle et l'analyse d'images/photos d'usinage.

5. **Superviseur de Services (`runtime/forgeron_services.py`)**
   - Lancé de façon invisible au démarrage de l'application via `pythonw.exe`.
   - Lance Ollama (`port 11434`) et le service Reco3D (`port 8765`) s'ils ne sont pas déjà actifs.
   - Surveille le processus parent `forgeron.exe` (via PID Windows) et arrête proprement l'arbre de processus lors de la fermeture de l'application.

---

## Comment Générer le Build (.exe)

Ouvrir un terminal PowerShell à la racine du projet :

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1
```

Pour utiliser le build Flutter déjà compilé et régénérer uniquement le paquet :

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1 -SkipFlutterBuild
```

### Fichiers Produits dans `dist/`

- `dist\Forgeron_CNC_5Axis_Setup_v1.0.exe` : Installateur principal avec assistant moderne en français et en anglais, création de raccourci Bureau et Menu Démarrer.
- `dist\Forgeron_CNC_5Axis_Setup_v1.0-*.bin` : Tranches de données compressées (Inno Setup avec `DiskSpanning=yes` et `DiskSliceSize=max`).

