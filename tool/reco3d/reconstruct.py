"""Moteur de reconstruction 3D locale Forgeron (Python + OCP + Trimesh + Scikit-image).

Exécuté dans `pipeline/.venv312` :
- Entrée : dossier de photos, mode (photo ou gen), échelle (mm)
- Sortie : reconstruction.stl, reconstruction.obj, reconstruction.step, metrics.json
- Sortie standard : lignes `STAGE:<nom>:<pct>:<message>` pour le suivi de progression en direct.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image
import numpy as np
from scipy.ndimage import zoom
from skimage import filters, measure, morphology
import trimesh

PIPELINE_DIR = Path(__file__).resolve().parents[2] / "pipeline"
if str(PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(PIPELINE_DIR))


def log_stage(stage: str, progress: float, message: str) -> None:
    print(f"STAGE:{stage}:{progress:.1f}:{message}", flush=True)


def segment_foreground(img_path: Path, max_dim: int = 256) -> np.ndarray:
    """Segmente l'objet au premier plan à partir d'une photo."""
    img = Image.open(img_path).convert("RGB")
    img.thumbnail((max_dim, max_dim))
    arr = np.array(img)
    r, g, b = arr[:, :, 0].astype(float), arr[:, :, 1].astype(float), arr[:, :, 2].astype(float)
    gray = 0.299 * r + 0.587 * g + 0.114 * b

    # Contraste de couleur / teinte
    diff_blue = b - (r + g) / 2.0
    diff_red = r - (g + b) / 2.0

    thresh = filters.threshold_otsu(gray)

    # Heuristique : objet dominant (couleur saturée ou contraste de luminance)
    if diff_blue.max() > 25:
        mask = diff_blue > (diff_blue.max() * 0.25)
    elif diff_red.max() > 25:
        mask = diff_red > (diff_red.max() * 0.25)
    else:
        # Objet plus sombre ou plus clair que le fond
        mask = gray < thresh if gray.mean() > thresh else gray > thresh

    if mask.sum() < 200:
        mask = gray < thresh

    try:
        mask = morphology.remove_small_holes(mask, max_size=400)
        mask = morphology.remove_small_objects(mask, max_size=400)
    except Exception:
        pass

    return mask


def build_3d_volume(masks: list[np.ndarray], grid_size: int = 64) -> np.ndarray:
    """Construit un volume 3D d'occupation voxel à partir des masques de silhouettes."""
    vol = np.ones((grid_size, grid_size, grid_size), dtype=float)

    for i, mask in enumerate(masks):
        H, W = mask.shape
        m_small = zoom(mask.astype(float), (grid_size / H, grid_size / W), order=1) > 0.45
        y_indices, x_indices = np.where(m_small)
        if len(y_indices) == 0:
            continue

        y_min, y_max = y_indices.min(), y_indices.max()
        x_center = (x_indices.min() + x_indices.max()) / 2.0

        if len(masks) == 1:
            # Révolution radiale à partir de la silhouette unique
            radius_per_y = np.zeros(grid_size)
            for y in range(y_min, y_max + 1):
                row_x = x_indices[y_indices == y]
                if len(row_x) > 0:
                    radius_per_y[y] = max(abs(row_x.min() - x_center), abs(row_x.max() - x_center))

            single_vol = np.zeros((grid_size, grid_size, grid_size), dtype=float)
            for y in range(grid_size):
                r_max = radius_per_y[y]
                if r_max > 0:
                    for z in range(grid_size):
                        for x in range(grid_size):
                            dist = np.sqrt((x - x_center) ** 2 + (z - grid_size / 2) ** 2)
                            if dist <= r_max:
                                single_vol[y, x, z] = 1.0
            vol = np.minimum(vol, single_vol)
        else:
            # Intersection multi-vues (Visual Hull carving)
            # Angle approximatif pour chaque vue
            angle = i * (math.pi / len(masks))
            cos_a, sin_a = math.cos(angle), math.sin(angle)

            view_vol = np.zeros((grid_size, grid_size, grid_size), dtype=float)
            for y in range(y_min, y_max + 1):
                row = m_small[y, :]
                for z in range(grid_size):
                    for x in range(grid_size):
                        # Projection du point (x, z) sur le plan de la vue
                        x_proj = int(round(x_center + (x - grid_size / 2) * cos_a + (z - grid_size / 2) * sin_a))
                        if 0 <= x_proj < grid_size and row[x_proj]:
                            view_vol[y, x, z] = 1.0
            vol = np.minimum(vol, view_vol)

    return vol


def export_step_from_mesh(mesh: trimesh.Trimesh, step_path: Path, max_faces: int = 1500) -> None:
    """Exporte un maillage triangulé vers un STEP solide facetté continu via OCP."""
    try:
        from OCP.BRepBuilderAPI import BRepBuilderAPI_MakeFace, BRepBuilderAPI_MakePolygon, BRepBuilderAPI_Sewing
        from OCP.gp import gp_Pnt
        from step_io import write_step

        # Simplification continue de surface (Quadric Decimation) pour préserver
        # la topologie fermée et connexe sans discontinuités ni trous.
        verts = mesh.vertices
        faces = mesh.faces
        if len(faces) > max_faces:
            try:
                import fast_simplification
                reduction = 1.0 - (max_faces / len(faces))
                verts, faces = fast_simplification.simplify(verts, faces, target_reduction=reduction)
            except Exception as e_simp:
                print(f"Avertissement décimation fast_simplification : {e_simp}", file=sys.stderr)

        sewing = BRepBuilderAPI_Sewing(1e-2)
        for face in faces:
            p1 = gp_Pnt(float(verts[face[0]][0]), float(verts[face[0]][1]), float(verts[face[0]][2]))
            p2 = gp_Pnt(float(verts[face[1]][0]), float(verts[face[1]][1]), float(verts[face[1]][2]))
            p3 = gp_Pnt(float(verts[face[2]][0]), float(verts[face[2]][1]), float(verts[face[2]][2]))
            poly = BRepBuilderAPI_MakePolygon(p1, p2, p3, True)
            if poly.IsDone():
                face_shape = BRepBuilderAPI_MakeFace(poly.Wire(), True).Face()
                sewing.Add(face_shape)

        sewing.Perform()
        sewn_shape = sewing.SewedShape()
        write_step(sewn_shape, str(step_path))
    except Exception as e:
        print(f"Avertissement export STEP via OCP : {e}", file=sys.stderr)


def run_meshroom_pipeline(meshroom_bin: Path, photos_dir: Path, out_dir: Path) -> Path:
    """Exécute meshroom_batch pour reconstruire un maillage dense photogrammétrique."""
    import subprocess
    import shutil
    import tempfile

    meshroom_out = out_dir / "meshroom_out"
    meshroom_out.mkdir(parents=True, exist_ok=True)

    log_stage("sfm", 10.0, "Démarrage du pipeline photogrammétrique AliceVision Meshroom...")
    # Pour la fabrication CNC/CAM, le maillage géométrique volumique filtré (MeshFiltering)
    # est la cible finale. Nous arrêtons à MeshFiltering (--toNode MeshFiltering) pour éviter
    # l'étape Texturing qui consomme plusieurs Go de RAM pour plaquer une texture 8K inutile
    # à l'usinage. Nous désactivons aussi estimateSpaceFromSfM qui échoue sur les petits objets.
    cmd = [
        str(meshroom_bin),
        "--input", str(photos_dir),
        "--output", str(meshroom_out),
        "--toNode", "MeshFiltering",
        "--paramOverrides", "Meshing.estimateSpaceFromSfM=False",
    ]

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    stage_pcts = {
        "camerainit": ("sfm", 15.0, "Initialisation intrinsèque des caméras..."),
        "featureextraction": ("sfm", 25.0, "Extraction des descripteurs visuels (SIFT)..."),
        "imagematching": ("sfm", 35.0, "Mise en correspondance des paires d'images..."),
        "structurefrommotion": ("sfm", 50.0, "Triangulation et calcul des poses caméras (SfM)..."),
        "preparedensegeometry": ("mvs", 60.0, "Préparation de la géométrie multi-vues..."),
        "depthmap": ("mvs", 70.0, "Estimation des cartes de profondeur denses..."),
        "depthmapfilter": ("mvs", 75.0, "Filtrage des cartes de profondeur..."),
        "meshing": ("meshing", 80.0, "Génération du maillage volumique triangulé..."),
        "meshfiltering": ("meshing", 85.0, "Nettoyage et fermeture du maillage..."),
    }

    last_lines = []
    if proc.stdout:
        for raw_line in proc.stdout:
            line = raw_line.strip()
            if line:
                last_lines.append(line)
                if len(last_lines) > 20:
                    last_lines.pop(0)
            line_lower = line.lower()
            for key, (stg, pct, msg) in stage_pcts.items():
                if f"[{key}]" in line_lower or f"node '{key}'" in line_lower:
                    log_stage(stg, pct, msg)
                    break

    proc.wait()

    # Recherche du maillage produit (OBJ) : d'abord dans meshroom_out, puis dans le cache Meshroom
    obj_candidates = (
        list(meshroom_out.glob("**/texturedMesh.obj"))
        + list(meshroom_out.glob("**/mesh.obj"))
        + list(meshroom_out.glob("**/*.obj"))
    )

    if not obj_candidates:
        temp_cache = Path(tempfile.gettempdir()) / "MeshroomCache"
        if temp_cache.exists():
            filtered_meshes = sorted(
                temp_cache.glob("MeshFiltering/**/mesh.obj"),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if not filtered_meshes:
                filtered_meshes = sorted(
                    temp_cache.glob("Meshing/**/mesh.obj"),
                    key=lambda p: p.stat().st_mtime,
                    reverse=True,
                )
            if filtered_meshes:
                dest_obj = meshroom_out / "reconstructed_mesh.obj"
                shutil.copy2(filtered_meshes[0], dest_obj)
                obj_candidates = [dest_obj]

    if not obj_candidates and proc.returncode != 0:
        photos_count = len([p for p in photos_dir.iterdir() if p.suffix.lower() in [".jpg", ".jpeg", ".png"]])
        err_tail = "\n".join(last_lines[-6:])
        raise RuntimeError(
            f"Échec photogrammétrie (Meshroom code {proc.returncode}) pour {photos_count} photo(s) :\n"
            f"{err_tail}\n\n"
            f"Conseil : Vérifiez que l'objet présente suffisamment de motifs/textures contrastés "
            f"et un bon recouvrement angulaire entre chaque prise de vue."
        )

    if not obj_candidates:
        raise RuntimeError("Meshroom s'est terminé sans produire de fichier .obj")

    return obj_candidates[0]


def main() -> None:
    parser = argparse.ArgumentParser(description="Reconstruction 3D locale Forgeron")
    parser.add_argument("--photos-dir", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--mode", default="gen", choices=["photo", "gen"])
    parser.add_argument("--scale-mm", type=float, default=50.0)
    parser.add_argument("--scale-type", default="none")
    parser.add_argument("--meshroom-bin", type=Path, default=None)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    photos = sorted([p for p in args.photos_dir.iterdir() if p.suffix.lower() in [".jpg", ".jpeg", ".png"]])
    if not photos:
        print("Erreur : aucune photo dans le dossier.", file=sys.stderr)
        sys.exit(1)

    target_scale = args.scale_mm if args.scale_mm and args.scale_mm > 0 else 50.0
    engine_name = "Forgeron Visual Hull (Marching Cubes + OCP)"

    if args.mode == "photo":
        if not args.meshroom_bin or not args.meshroom_bin.exists():
            print("Erreur : moteur photogrammétrique meshroom_batch introuvable.", file=sys.stderr)
            sys.exit(1)

        log_stage("sfm", 5.0, f"Lancement de la photogrammétrie pour {len(photos)} photo(s)...")
        raw_obj_path = run_meshroom_pipeline(args.meshroom_bin, args.photos_dir, args.out_dir)
        engine_name = "AliceVision Meshroom (Photogrammétrie dense + OCP)"

        log_stage("meshing", 82.0, "Chargement et orientation du maillage photogrammétrique...")
        mesh = trimesh.load(str(raw_obj_path), force="mesh")
    else:
        # Mode Génératif / Concept : Visual Hull à partir de 1 à 4 photos
        log_stage("sfm", 15.0, f"Analyse des silhouettes de {len(photos)} photo(s)...")
        masks = []
        for idx, p in enumerate(photos):
            mask = segment_foreground(p)
            masks.append(mask)
            pct = 15.0 + (idx + 1) / len(photos) * 25.0
            log_stage("sfm", pct, f"Silhouette {idx + 1}/{len(photos)} extraite")

        log_stage("mvs", 45.0, "Sculpture 3D de l'enveloppe visuelle (Visual Hull)...")
        vol = build_3d_volume(masks, grid_size=72)

        log_stage("meshing", 65.0, "Extraction du maillage triangulé (Marching Cubes)...")
        verts, faces, normals, values = measure.marching_cubes(vol, level=0.5)

        # Réorientation vers le repère machine (Z vertical, centré en X, Y)
        v = verts.copy()
        mesh = trimesh.Trimesh(vertices=v, faces=faces)
        v_new = np.zeros_like(v)
        v_new[:, 0] = v[:, 1] - v[:, 1].mean()
        v_new[:, 1] = v[:, 2] - v[:, 2].mean()
        v_new[:, 2] = -v[:, 0]
        v_new[:, 2] -= v_new[:, 2].min()  # Poser la base à Z = 0
        mesh.vertices = v_new

    # Mise à l'échelle métrique
    current_max_dim = max(mesh.extents)
    if current_max_dim > 0:
        mesh.apply_scale(target_scale / current_max_dim)

    # Lissage et nettoyage du maillage
    mesh.process()

    stl_path = args.out_dir / "reconstruction.stl"
    obj_path = args.out_dir / "reconstruction.obj"
    mesh.export(str(stl_path))
    mesh.export(str(obj_path))

    log_stage("postprocessing", 88.0, "Génération du solide STEP tessellé (OpenCASCADE)...")
    step_path = args.out_dir / "reconstruction.step"
    export_step_from_mesh(mesh, step_path)

    metrics = {
        "facets_count": len(mesh.faces),
        "vertices_count": len(mesh.vertices),
        "is_watertight": bool(mesh.is_watertight),
        "stl_path": str(stl_path),
        "obj_path": str(obj_path),
        "step_path": str(step_path) if step_path.exists() else None,
        "engine": engine_name,
        "engine_version": "1.0.0",
        "scale_applied_mm": target_scale,
    }
    with open(args.out_dir / "metrics.json", "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    log_stage("done", 100.0, "Modèle 3D prêt pour fabrication et usinage CAM !")
    print("RECONSTRUCTION_SUCCESS", flush=True)


if __name__ == "__main__":
    main()
