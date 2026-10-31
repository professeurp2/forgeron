"""Chaîne d'usinage d'implants médicaux et guides chirurgicaux sur mesure (STL → G-code).

Reçoit un maillage `.stl` issu d'une segmentation DICOM (3D Slicer, InVesalius)
ou du module de numérisation 3D (`reco3d`), prépare la géométrie pour le
trunnion 5 axes Forgeron, applique les garde-fous matériaux/biomédicaux et
génère :

  1. `<base>_apercu.json`          maillage d'aperçu pour `three_viewer.html`
  2. `<base>.nc`                   programme G-code (ébauche 3 axes + finition 5 axes)
  3. `<base>_rapport.json`         rapport technique lu par l'application / l'agent IA
  4. `<base>_dossier_medical.json` dossier de lot et de traçabilité (inspiré ISO 13485)

── Réalisme matériel assumé ────────────────────────────────────────────────

La machine Forgeron porte une broche DC 775 de 200 W sur un bâti léger à
courroies GT2, avec un plafond vibratoire mesuré à ap = 0,2 mm et ae = 0,5 mm
dans l'aluminium AW-2017A. Elle est dimensionnée pour :
  - les polymères implantables ou dentaires : PMMA, UHMWPE, PEEK ;
  - les guides chirurgicaux d'ostéotomie / de perçage ;
  - les modèles anatomiques pré-opératoires (cire, résine).

Les alliages métalliques d'orthopédie lourde (Titane Ti-6Al-4V, Cobalt-Chrome
CoCrMo) exigent une rigidité, un couple à basse vitesse et une puissance
(> 1,5 kW) hors de portée de cette broche : ils figurent au catalogue pour être
explicitement REFUSÉS avec la justification physique, jamais laissés passer.

── Hygiène de coupe (coupe à sec M9) ───────────────────────────────────────

Un fluide de coupe d'atelier contamine les polymères médicaux poreux et provoque
la fissuration sous contrainte (crazing) du PMMA. Tout programme médical émet
explicitement `M9` (arrosage coupé) et interdit `M7`/`M8`.
"""

from __future__ import annotations

import datetime
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from dropcutter import height_map
from gen_surface5 import SurfaceParams, f3
from kinematics import Trunnion, normals_from_height_map, orient, piece_to_machine
from stl_io import read_stl, write_stl


def read_3d_file(path: str | Path, step_deflection: float = 0.01) -> np.ndarray:
    """Lit un fichier géométrique 3D (.stl, .step, .stp) et renvoie les triangles (N, 3, 3).

    Pour un modèle CAO STEP (.step, .stp) :
      - Vérifie si un cache d'aperçu existe déjà (<base>_apercu.json). S'il existe,
        il est chargé directement en < 0.5 s sans recalcul OpenCASCADE.
      - Sinon, utilise OpenCASCADE pour lire la B-Rep exacte et facettiser.
      - Si le nombre de triangles dépasse 40 000, une décimation QEM rapide
        (fast_simplification) optimise le maillage pour Drop-Cutter en conservant
        une précision submillimétrique.

    Pour un maillage STL (.stl) :
      - Lit le maillage binaire ou ASCII directement via `stl_io.read_stl`.
    """
    path_str = str(path)
    lower = path_str.lower()
    tris: np.ndarray

    if lower.endswith((".step", ".stp")):
        base_path = Path(path_str).with_suffix("")
        apercu_path = base_path.parent / f"{base_path.name}_apercu.json"
        loaded = False
        if apercu_path.is_file():
            try:
                with open(apercu_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if "vertices" in data and "indices" in data and len(data["indices"]) > 0:
                    pts = np.asarray(data["vertices"], dtype=np.float64).reshape(-1, 3)
                    faces = np.asarray(data["indices"], dtype=np.int64).reshape(-1, 3)
                    tris = pts[faces]
                    loaded = True
            except Exception:
                loaded = False

        if not loaded:
            from step_io import read_step
            from step_preview import tessellate

            shape = read_step(path_str)
            verts, idxs = tessellate(shape, step_deflection)
            pts = np.asarray(verts, dtype=np.float64).reshape(-1, 3)
            faces = np.asarray(idxs, dtype=np.int64).reshape(-1, 3)
            tris = pts[faces]
    else:
        tris = read_stl(path_str)

    # Optimisation Drop-Cutter : décimation QEM ultra-rapide si le maillage est très lourd
    if len(tris) > 40_000:
        try:
            import fast_simplification
            pts_flat = tris.reshape(-1, 3).astype(np.float32)
            pts_uniq, inv = np.unique(np.round(pts_flat, 4), axis=0, return_inverse=True)
            faces_arr = inv.reshape(-1, 3).astype(np.int32)
            if len(faces_arr) > 40_000:
                target_red = max(0.5, 1.0 - (30_000.0 / len(faces_arr)))
                pts_s, faces_s = fast_simplification.simplify(pts_uniq, faces_arr, target_reduction=target_red)
                if len(faces_s) > 0:
                    tris = pts_s[faces_s].astype(np.float64)
        except Exception:
            pass

    return tris


# ── Enveloppe machine de production (mêmes constantes que GcodeCritic) ──────

MAX_TRAVEL_X_MM = 88.0
MAX_TRAVEL_Y_MM = 150.0
MAX_TRAVEL_Z_MM = 110.0


# ── Catalogue des matériaux médicaux ────────────────────────────────────────


@dataclass(frozen=True)
class MedicalMaterial:
    id: str
    nom: str
    norme: str
    usinable: bool
    ap_max: float
    ae_max: float
    stepover: float
    feed_rough: float
    feed_plunge: float
    v_surface: float
    spindle_rpm: int
    arrosage_autorise: bool
    usage_clinique: str
    motif_refus: str | None = None


MEDICAL_MATERIALS: dict[str, MedicalMaterial] = {
    "pmma": MedicalMaterial(
        id="pmma",
        nom="PMMA chirurgical / résine acrylique",
        norme="ISO 5833 / USP Class VI",
        usinable=True,
        ap_max=0.20,
        ae_max=0.50,
        stepover=0.35,
        feed_rough=400.0,
        feed_plunge=80.0,
        v_surface=120.0,
        spindle_rpm=1000,
        arrosage_autorise=False,
        usage_clinique="Guides chirurgicaux, volets crâniens provisoires, prothèses dentaires",
    ),
    "uhmwpe": MedicalMaterial(
        id="uhmwpe",
        nom="Polyéthylène UHMWPE médical",
        norme="ISO 5834-2 / ASTM F648",
        usinable=True,
        ap_max=0.20,
        ae_max=0.40,
        stepover=0.30,
        feed_rough=450.0,
        feed_plunge=90.0,
        v_surface=140.0,
        spindle_rpm=1000,
        arrosage_autorise=False,
        usage_clinique="Inserts articulaires (genou, hanche), cales d'essai orthopédiques",
    ),
    "peek": MedicalMaterial(
        id="peek",
        nom="PEEK implantable (qualité médicale)",
        norme="ASTM F2026 / ISO 10993",
        usinable=True,
        ap_max=0.15,
        ae_max=0.35,
        stepover=0.25,
        feed_rough=300.0,
        feed_plunge=60.0,
        v_surface=100.0,
        spindle_rpm=1000,
        arrosage_autorise=False,
        usage_clinique="Implants crânio-maxillo-faciaux sur mesure, cages intersomatiques",
    ),
    "wax_model": MedicalMaterial(
        id="wax_model",
        nom="Cire / résine pour modèle anatomique",
        norme="Modèle pré-opératoire non implantable",
        usinable=True,
        ap_max=0.20,
        ae_max=0.50,
        stepover=0.40,
        feed_rough=500.0,
        feed_plunge=100.0,
        v_surface=150.0,
        spindle_rpm=1000,
        arrosage_autorise=False,
        usage_clinique="Fantôme osseux issu de DICOM pour répétition chirurgicale ou fonderie",
    ),
    "ti6al4v": MedicalMaterial(
        id="ti6al4v",
        nom="Titane médical Ti-6Al-4V ELI (Grade 23)",
        norme="ISO 5832-3 / ASTM F136",
        usinable=False,
        ap_max=0.0,
        ae_max=0.0,
        stepover=0.0,
        feed_rough=0.0,
        feed_plunge=0.0,
        v_surface=0.0,
        spindle_rpm=0,
        arrosage_autorise=False,
        usage_clinique="Plaques d'ostéosynthèse, tiges fémorales, visserie osseuse",
        motif_refus=(
            "Hors capacité machine : le Ti-6Al-4V exige une rigidité de bâti élevée, "
            "un fort couple à basse vitesse et une puissance > 1,5 kW. Sur la broche "
            "DC 775 (200 W) et le bâti Forgeron (plafond vibratoire 0,2 mm sur alu), "
            "l'outil frotte, écrouit le titane et casse immédiatement."
        ),
    ),
    "cocrmo": MedicalMaterial(
        id="cocrmo",
        nom="Alliage Cobalt-Chrome CoCrMo",
        norme="ISO 5832-4 / ASTM F75",
        usinable=False,
        ap_max=0.0,
        ae_max=0.0,
        stepover=0.0,
        feed_rough=0.0,
        feed_plunge=0.0,
        v_surface=0.0,
        spindle_rpm=0,
        arrosage_autorise=False,
        usage_clinique="Condyles fémoraux, têtes prothétiques",
        motif_refus=(
            "Hors capacité machine : alliage réfractaire à très fort écrouissage, "
            "incompatible avec la broche DC 775 (200 W) et la transmission GT2."
        ),
    ),
}

IMPLANT_TYPES: dict[str, str] = {
    "guide_chirurgical": "Guide chirurgical (perçage / ostéotomie)",
    "plaque_cranienne": "Implant crânio-maxillo-facial sur mesure",
    "insert_articulaire": "Insert articulaire / cale orthopédique",
    "modele_anatomique": "Modèle anatomique pré-opératoire (DICOM)",
}


# ── Analyse et préparation géométrique du STL ───────────────────────────────


@dataclass(frozen=True)
class PreparedMesh:
    triangles: np.ndarray
    initial_size_mm: tuple[float, float, float]
    prepared_size_mm: tuple[float, float, float]
    scale_factor: float
    has_explicit_target_length: bool
    unit_converted_from_meters: bool
    reoriented: bool
    volume_mm3: float
    open_edges_count: int
    notes: list[str]


def _signed_volume(triangles: np.ndarray) -> float:
    """Volume enfermé par le maillage (mm³) via le théorème de la divergence."""
    v0 = triangles[:, 0, :]
    v1 = triangles[:, 1, :]
    v2 = triangles[:, 2, :]
    cross = np.cross(v1, v2)
    return float(abs(np.einsum("ij,ij->", v0, cross)) / 6.0)


def count_open_edges(triangles: np.ndarray) -> int:
    """Compte les arêtes de bord (appartenant à un seul triangle).

    Sur un maillage fermé (watertight), chaque arête est partagée par exactement
    deux triangles : le compte vaut 0. Un compte > 0 signale des trous de
    numérisation ou de segmentation DICOM, qui ne doivent jamais être passés
    sous silence.
    """
    pts = np.round(triangles.reshape(-1, 3), 5)
    _, inv = np.unique(pts, axis=0, return_inverse=True)
    faces = inv.reshape(-1, 3)
    e01 = np.sort(faces[:, [0, 1]], axis=1)
    e12 = np.sort(faces[:, [1, 2]], axis=1)
    e20 = np.sort(faces[:, [2, 0]], axis=1)
    all_edges = np.vstack([e01, e12, e20])
    _, counts = np.unique(all_edges, axis=0, return_counts=True)
    return int(np.sum(counts == 1))


def prepare_implant_mesh(
    triangles: np.ndarray,
    *,
    auto_orient: bool = True,
    target_length_mm: float | None = None,
    auto_fit: bool = True,
) -> PreparedMesh:
    """Prépare un maillage brut (DICOM / scanner) pour le plateau 5 axes :

    1. Détecte un export en mètres (< 1,0 unité) ou applique `target_length_mm`.
    2. Oriente la plus faible épaisseur selon Z (pièce posée à plat sur le
       berceau : minimise la plongée Z et maintient les normales dans la plage A).
    3. Recentre X et Y sur (0, 0) (axe du plateau C) et pose le sommet de la
       pièce à Z = 0,0 (convention G54 Forgeron : l'usinage se fait en Z ≤ 0).
    4. Vérifie que la pièce préparée tient dans l'enveloppe de production.
    """
    tris = np.asarray(triangles, dtype=np.float64).copy()
    if tris.ndim != 3 or tris.shape[1:] != (3, 3) or len(tris) == 0:
        raise ValueError("Maillage STL vide ou mal formé")

    notes: list[str] = []
    pts = tris.reshape(-1, 3)
    lo0, hi0 = pts.min(axis=0), pts.max(axis=0)
    init_size = (float(hi0[0] - lo0[0]), float(hi0[1] - lo0[1]), float(hi0[2] - lo0[2]))
    max_dim = max(init_size)
    if max_dim <= 1e-9:
        raise ValueError("Maillage dégénéré : dimensions nulles")

    # 1. Orientation : l'épaisseur la plus faible devient Z, la plus grande Y
    #    (car la course Y = 150 mm est plus grande que la course X = 88 mm).
    reoriented = False
    if auto_orient:
        order = np.argsort(init_size)  # [min_axis, mid_axis, max_axis]
        # On veut : X = mid_axis, Y = max_axis, Z = min_axis
        desired = [int(order[1]), int(order[2]), int(order[0])]
        if desired != [0, 1, 2]:
            tris = tris[:, :, desired]
            # Si la permutation est impaire, on échange deux sommets par triangle
            # pour conserver l'orientation des normales vers l'extérieur.
            sign = np.linalg.det(np.eye(3)[desired])
            if sign < 0:
                tris[:, [1, 2], :] = tris[:, [2, 1], :]
            reoriented = True
            notes.append(
                "Pièce réorientée à plat sur le plateau (épaisseur minimale selon Z, "
                "grande longueur selon Y)."
            )

    # 2. Mise à l'échelle (conversion m -> mm ou cote chirurgicale cible)
    pts = tris.reshape(-1, 3)
    cur_size = pts.max(axis=0) - pts.min(axis=0)
    cur_xy_max = float(max(cur_size[0], cur_size[1]))
    scale_factor = 1.0
    unit_from_m = False

    if target_length_mm is not None:
        if target_length_mm <= 0:
            raise ValueError("--longueur-cible doit être strictement positif")
        scale_factor = float(target_length_mm) / max(cur_xy_max, 1e-9)
        tris *= scale_factor
        notes.append(
            f"Mise à l'échelle métrique appliquée : longueur XY calée à "
            f"{target_length_mm:.2f} mm (facteur ×{scale_factor:.4f})."
        )
    elif max(cur_size) < 1.0:
        scale_factor = 1000.0
        unit_from_m = True
        tris *= scale_factor
        notes.append(
            "Dimensions brutes < 1,0 : export en mètres détecté, conversion "
            "automatique en millimètres (×1000)."
        )

    # 3. Recentrage dans le repère pièce G54 : X,Y centrés sur 0, sommet à Z = 0
    pts = tris.reshape(-1, 3)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    center_xy = (lo[:2] + hi[:2]) / 2.0
    z_top = float(hi[2])
    shift = np.array([-center_xy[0], -center_xy[1], -z_top], dtype=np.float64)
    tris += shift
    if np.linalg.norm(shift) > 0.01:
        notes.append(
            f"Recentrage G54 automatique (décalage DICOM/scanner corrigé de "
            f"ΔX={shift[0]:+.1f}, ΔY={shift[1]:+.1f}, ΔZ={shift[2]:+.1f} mm)."
        )

    pts = tris.reshape(-1, 3)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    prep_size = (float(hi[0] - lo[0]), float(hi[1] - lo[1]), float(hi[2] - lo[2]))

    # 4. Ajustement automatique à l'enveloppe machine (si activé) ou vérification
    if auto_fit and target_length_mm is None:
        fit_ratio = min(
            (MAX_TRAVEL_X_MM * 0.85) / max(prep_size[0], 1e-6),
            (MAX_TRAVEL_Y_MM * 0.85) / max(prep_size[1], 1e-6),
            (MAX_TRAVEL_Z_MM * 0.85) / max(prep_size[2], 1e-6),
        )
        if fit_ratio < 1.0:
            tris *= fit_ratio
            scale_factor *= fit_ratio
            notes.append(
                f"Ajustement d'échelle automatique pour respecter l'enveloppe machine Forgeron "
                f"({MAX_TRAVEL_X_MM:.0f} × {MAX_TRAVEL_Y_MM:.0f} × {MAX_TRAVEL_Z_MM:.0f} mm) : "
                f"facteur ×{fit_ratio:.4f} (taille adaptée : {prep_size[0]*fit_ratio:.1f} × "
                f"{prep_size[1]*fit_ratio:.1f} × {prep_size[2]*fit_ratio:.1f} mm)."
            )
            pts = tris.reshape(-1, 3)
            lo, hi = pts.min(axis=0), pts.max(axis=0)
            center_xy = (lo[:2] + hi[:2]) / 2.0
            shift = np.array([-center_xy[0], -center_xy[1], -float(hi[2])], dtype=np.float64)
            tris += shift
            pts = tris.reshape(-1, 3)
            lo, hi = pts.min(axis=0), pts.max(axis=0)
            prep_size = (float(hi[0] - lo[0]), float(hi[1] - lo[1]), float(hi[2] - lo[2]))

    if prep_size[0] > MAX_TRAVEL_X_MM:
        raise ValueError(
            f"Implant trop large en X ({prep_size[0]:.1f} mm > course machine "
            f"{MAX_TRAVEL_X_MM:.0f} mm). Réduire l'échelle ou réorienter."
        )
    if prep_size[1] > MAX_TRAVEL_Y_MM:
        raise ValueError(
            f"Implant trop long en Y ({prep_size[1]:.1f} mm > course machine "
            f"{MAX_TRAVEL_Y_MM:.0f} mm)."
        )
    if prep_size[2] > MAX_TRAVEL_Z_MM:
        raise ValueError(
            f"Implant trop épais en Z ({prep_size[2]:.1f} mm > course machine "
            f"{MAX_TRAVEL_Z_MM:.0f} mm)."
        )

    open_edges = count_open_edges(tris)
    if open_edges > 0:
        notes.append(
            f"{open_edges} arête(s) ouverte(s) détectée(s) dans le maillage STL : "
            "le Drop-Cutter les franchit par le haut sans plonger dedans."
        )

    return PreparedMesh(
        triangles=tris,
        initial_size_mm=init_size,
        prepared_size_mm=prep_size,
        scale_factor=scale_factor,
        has_explicit_target_length=target_length_mm is not None,
        unit_converted_from_meters=unit_from_m,
        reoriented=reoriented,
        volume_mm3=_signed_volume(tris),
        open_edges_count=open_edges,
        notes=notes,
    )


def build_stl_preview_dict(stl_path: str, prep: PreparedMesh) -> dict:
    """Construit le dictionnaire JSON d'aperçu 3D compatible avec `StepPreview`
    et `web/three_viewer.html` (`load_mesh`)."""
    tris = prep.triangles
    pts = tris.reshape(-1, 3)
    uniq, inv = np.unique(np.round(pts, 4), axis=0, return_inverse=True)
    lo = pts.min(axis=0)
    hi = pts.max(axis=0)
    return {
        "source": stl_path,
        "unit": "mm",
        "vertices": [round(float(v), 4) for v in uniq.reshape(-1)],
        "indices": [int(i) for i in inv],
        "vertexCount": int(len(uniq)),
        "triangles": int(len(tris)),
        "deflection": 0.0,
        "volume": round(prep.volume_mm3, 2),
        "bbox": {
            "min": [round(float(lo[0]), 3), round(float(lo[1]), 3), round(float(lo[2]), 3)],
            "max": [round(float(hi[0]), 3), round(float(hi[1]), 3), round(float(hi[2]), 3)],
            "size": [round(s, 3) for s in prep.prepared_size_mm],
        },
    }


# ── Génération du parcours (Ébauche 3 axes en Z + Finition 5 axes continu) ──


@dataclass(frozen=True)
class ImplantCutConfig:
    material_id: str = "peek"
    implant_type: str = "plaque_cranienne"
    tool_dia: float = 6.0
    ap: float | None = None
    ae: float | None = None
    stepover: float | None = None
    stock_leave: float = 0.3
    five_axis: bool = True
    z_safe: float = 20.0
    feed_cap: float = 500.0
    lot_id: str = "LOT-MED-AUTO"
    patient_ref: str = "PAT-ANONYME"
    provenance_approximate: bool = False


def generate_implant_program(
    prep: PreparedMesh,
    cfg: ImplantCutConfig = ImplantCutConfig(),
    tr: Trunnion = Trunnion(),
) -> tuple[str, dict]:
    """Génère le programme complet d'usinage médical (ébauche + finition)."""
    mat_key = cfg.material_id.lower().strip()
    if mat_key not in MEDICAL_MATERIALS:
        known = ", ".join(sorted(MEDICAL_MATERIALS))
        raise ValueError(f"Matériau médical inconnu « {cfg.material_id} » (connus : {known})")

    mat = MEDICAL_MATERIALS[mat_key]
    if not mat.usinable:
        raise ValueError(f"{mat.nom} ({mat.norme}) — {mat.motif_refus}")

    if cfg.implant_type not in IMPLANT_TYPES:
        known_t = ", ".join(sorted(IMPLANT_TYPES))
        raise ValueError(f"Type d'implant inconnu « {cfg.implant_type} » (connus : {known_t})")

    # Garde-fou d'honnêteté métrique : un implant ou guide chirurgical destiné
    # à un patient ne peut pas partir d'une forme générative sans cote certifiée.
    if cfg.provenance_approximate and cfg.implant_type != "modele_anatomique":
        if not prep.has_explicit_target_length:
            raise ValueError(
                "Modèle 3D issu d'une reconstruction approximative sans mire ni "
                "longueur cible déclarée : interdit pour un implant ou guide "
                "chirurgical. Déclarer --longueur-cible (mm) ou choisir le type "
                "« modele_anatomique »."
            )

    if cfg.tool_dia <= 0:
        raise ValueError("Le diamètre d'outil doit être strictement positif.")

    # Application stricte des plafonds vibratoires et matériaux
    ap = min(cfg.ap if cfg.ap and cfg.ap > 0 else mat.ap_max, mat.ap_max)
    ae = min(cfg.ae if cfg.ae and cfg.ae > 0 else mat.ae_max, mat.ae_max)
    stepover = cfg.stepover if cfg.stepover and cfg.stepover > 0 else mat.stepover
    rho = cfg.tool_dia / 2.0

    # 1. Carte de hauteur Drop-Cutter (centre de la bille) et normales
    grid_step = min(stepover, ae)
    xs, ys, Z = height_map(prep.triangles, rho=rho, step=grid_step)
    normals = normals_from_height_map(xs, ys, Z)

    # Hauteur de la POINTE d'outil en 3 axes (A=0, C=0) : centre bille - rho
    Z_tip = Z - rho
    finite_mask = np.isfinite(Z_tip)
    if not np.any(finite_mask):
        raise ValueError("Aucun point de contact outil trouvé sur le maillage.")

    z_min_cut = float(np.min(Z_tip[finite_mask]))
    z_top_stock = 0.0

    # ── Étape 1 : Ébauche 3 axes par couches Z (respecte ap et ae) ──────────
    rough_lines: list[str] = []
    rough_min = 0.0
    n_rough_layers = max(1, int(math.ceil(abs(z_min_cut) / ap)))
    rough_row_step = max(1, int(round(ae / (ys[1] - ys[0])))) if len(ys) > 1 else 1
    rough_segments = 0

    for layer_idx in range(1, n_rough_layers + 1):
        z_layer = max(-layer_idx * ap, z_min_cut)
        layer_has_cuts = False
        for row_k, j in enumerate(range(0, len(ys), rough_row_step)):
            y_val = float(ys[j])
            row_z = Z_tip[j, :] + cfg.stock_leave
            # On enlève la matière là où la surface + surépaisseur est sous z_layer
            # (et où il y a effectivement un triangle sous ce point XY).
            cut_mask = np.isfinite(Z_tip[j, :]) & (row_z < z_layer)
            if not np.any(cut_mask):
                continue

            idxs = np.where(cut_mask)[0]
            x_start = float(xs[idxs[0]])
            x_end = float(xs[idxs[-1]])
            if row_k % 2 == 1:
                x_start, x_end = x_end, x_start

            if not layer_has_cuts:
                rough_lines.append(
                    f"(EBAUCHE COUCHE {layer_idx}/{n_rough_layers} - Z{f3(z_layer)})"
                )
                layer_has_cuts = True

            rough_lines.append(f"G0 X{f3(x_start)} Y{f3(y_val)}")
            rough_lines.append(f"G1 Z{f3(z_layer)} F{f3(mat.feed_plunge)}")
            dist = abs(x_end - x_start)
            if dist > 1e-6:
                rough_lines.append(f"G1 X{f3(x_end)} Y{f3(y_val)} F{f3(mat.feed_rough)}")
                rough_min += dist / mat.feed_rough
            rough_lines.append(f"G0 Z{f3(min(z_top_stock + 1.0, z_layer + 2.0))}")
            rough_min += 2.0 / mat.feed_plunge
            rough_segments += 1

    rough_lines.append(f"G0 Z{f3(cfg.z_safe)}")

    # ── Étape 2 : Finition 5 axes continu (ou 3 axes) sur la surface exacte ─
    surf_params = SurfaceParams(
        tool_dia=cfg.tool_dia,
        stepover=stepover,
        step_along=stepover,
        v_surface=mat.v_surface,
        feed_cap=cfg.feed_cap,
        feed_link=min(200.0, mat.feed_rough),
        z_safe=cfg.z_safe,
        spindle=mat.spindle_rpm,
        five_axis=cfg.five_axis,
    )

    row_step = max(1, int(round(surf_params.stepover / (ys[1] - ys[0])))) if len(ys) > 1 else 1
    col_step = max(1, int(round(surf_params.step_along / (xs[1] - xs[0])))) if len(xs) > 1 else 1

    finish_lines: list[str] = []
    warnings: list[str] = []
    finish_min = 0.0
    n_points = 0
    n_jerky = 0
    a_min_seen, a_max_seen = 0.0, 0.0

    prev_machine: np.ndarray | None = None
    prev_contact: np.ndarray | None = None
    prev_a = prev_c = 0.0
    first = True

    for row_i, j in enumerate(range(0, len(ys), row_step)):
        cols = range(0, len(xs), col_step)
        if row_i % 2:
            cols = reversed(list(cols))

        for i in cols:
            zc = Z[j, i]
            if not np.isfinite(zc):
                continue

            centre = np.array([xs[i], ys[j], zc])
            n = normals[j, i]
            contact = centre - rho * n

            if cfg.five_axis:
                a, c = orient(n)
                # Limiter l'inclinaison A à ±65° sur un implant en plaque pour
                # éviter toute collision porte-outil / plateau tout en gardant
                # l'outil hors de sa pointe à vitesse nulle.
                a = float(np.clip(a, -65.0, 65.0))
                # Zone de singularité du trunnion (|A| < 5°, cf. TrunnionConfig) :
                # près de l'horizontale, l'azimut C est indéterminé et ferait
                # tourner le plateau de 180° pour rien.
                if abs(a) < 5.0 and not first:
                    c = prev_c
                while c - prev_c > 180.0:
                    c -= 360.0
                while prev_c - c > 180.0:
                    c += 360.0
                # Lissage cinématique : borne la rotation par pas à 1,2 deg/mm
                # de déplacement sur la pièce pour que la norme composite GRBL
                # √(mm² + deg²) n'écrase jamais l'avance linéaire (ratio ≥ 0,64).
                if not first and prev_contact is not None:
                    step_mm = max(float(np.linalg.norm(contact - prev_contact)), 0.1)
                    max_ang = 1.2 * step_mm
                    da, dc = a - prev_a, c - prev_c
                    ang_norm = math.hypot(da, dc)
                    if ang_norm > max_ang:
                        scale_ang = max_ang / ang_norm
                        a = prev_a + da * scale_ang
                        c = prev_c + dc * scale_ang
                machine = piece_to_machine(centre, a, c, tr) - np.array([0.0, 0.0, rho])
            else:
                a, c = 0.0, prev_c
                machine = centre - np.array([0.0, 0.0, rho])

            a_min_seen, a_max_seen = min(a_min_seen, a), max(a_max_seen, a)

            if first:
                if cfg.five_axis:
                    finish_lines.append(f"G0 A{f3(a)} C{f3(c)}")
                finish_lines += [
                    f"G0 X{f3(machine[0])} Y{f3(machine[1])}",
                    f"G1 Z{f3(machine[2])} F{f3(surf_params.feed_link)}",
                ]
                first = False
            else:
                d_machine = float(np.linalg.norm(machine - prev_machine))
                d_contact = float(np.linalg.norm(contact - prev_contact))
                d_ang = math.hypot(a - prev_a, c - prev_c)

                if d_machine < 1e-9 and d_ang < 1e-9:
                    continue

                l_grbl = math.sqrt(d_machine**2 + d_ang**2)
                l_real = max(d_contact, 1e-6)
                feed = min(surf_params.v_surface * l_grbl / l_real, surf_params.feed_cap)
                finish_min += l_grbl / feed

                if d_contact > 1e-6 and d_ang / d_contact > surf_params.max_deg_per_mm:
                    n_jerky += 1

                words = f"X{f3(machine[0])} Y{f3(machine[1])} Z{f3(machine[2])}"
                if cfg.five_axis:
                    words += f" A{f3(a)} C{f3(c)}"
                finish_lines.append(f"G1 {words} F{f3(feed)}")

            prev_machine, prev_contact, prev_a, prev_c = machine, contact, a, c
            n_points += 1

    if n_jerky:
        warnings.append(
            f"(AVIS : {n_jerky} BLOC(S) A FORTE ROTATION ANGULAIRE SUR COURTE DISTANCE)"
        )

    total_min = rough_min + finish_min
    crest_mm = (stepover**2) / (8.0 * rho)
    crest_um = crest_mm * 1000.0
    sx, sy, sz = prep.prepared_size_mm

    head = [
        "(FORGERON - CHAINE IMPLANT MEDICAL SUR MESURE - ISO 13485)",
        f"(LOT : {cfg.lot_id} - REF CAS : {cfg.patient_ref})",
        f"(DISPOSITIF : {IMPLANT_TYPES[cfg.implant_type].upper()})",
        f"(MATERIAU : {mat.nom.upper()} - {mat.norme})",
        f"(DIMENSIONS PREPAREES : {f3(sx)} X {f3(sy)} X {f3(sz)} MM)",
        f"(OUTIL : FRAISE BOULE DIAM {f3(cfg.tool_dia)} MM - COUPE A SEC OBLIGATOIRE M9)",
        f"(EBAUCHE 3 AXES : {n_rough_layers} COUCHES, AP {f3(ap)} MM, AE {f3(ae)} MM,"
        f" SUREPAISSEUR {f3(cfg.stock_leave)} MM)",
        f"(FINITION {'5 AXES CONTINU' if cfg.five_axis else '3 AXES'} : {n_points} POINTS,"
        f" PAS {f3(stepover)} MM, CRETE {crest_um:.1f} UM)",
        f"(DUREE ESTIMEE : {round(rough_min)} MIN EBAUCHE + {round(finish_min)} MIN FINITION"
        f" = {round(total_min)} MIN)",
        *warnings,
        "G21 G90 G94 G17 G40",
        "G54",
        "M5",
        "M9 (INTERDICTION D ARROSAGE - BIOCOMPATIBILITE POLYMERE)",
        f"G0 Z{f3(cfg.z_safe)}",
        f"M0 (VERIFIER BRUT {mat.id.upper()}, FRAISE BOULE DIAM {f3(cfg.tool_dia)}"
        " PROPRE ET DEGRAISSEE, ZERO PIECE G54 AU CENTRE SOMMET)",
        f"M3 S{mat.spindle_rpm}",
        "G4 P1 (MONTEE EN REGIME 1 SUR 3)",
        "G4 P1 (MONTEE EN REGIME 2 SUR 3)",
        "G4 P1 (MONTEE EN REGIME 3 SUR 3)",
        "(=== ETAPE 1 : EBAUCHE 3 AXES PAR COUCHES ===)",
    ]
    tail = [
        "(DEGAGEMENT ET FIN DE LOT MEDICAL)",
        f"G0 Z{f3(cfg.z_safe)}",
        "M9",
        "M5",
        "M30",
    ]
    lines = (
        head
        + rough_lines
        + ["(=== ETAPE 2 : FINITION SURFACE ANATOMIQUE ===)"]
        + finish_lines
        + tail
    )
    gcode = "\n".join(lines) + "\n"

    report = {
        "pipeline": "implant_medical_5axes" if cfg.five_axis else "implant_medical_3axes",
        "lot_id": cfg.lot_id,
        "patient_ref": cfg.patient_ref,
        "implant_type": cfg.implant_type,
        "implant_type_label": IMPLANT_TYPES[cfg.implant_type],
        "materiau_id": mat.id,
        "materiau_nom": mat.nom,
        "materiau_norme": mat.norme,
        "arrosage_autorise": mat.arrosage_autorise,
        "outil_diametre_mm": cfg.tool_dia,
        "ap_mm": ap,
        "ae_mm": ae,
        "stepover_mm": stepover,
        "surepaisseur_ebauche_mm": cfg.stock_leave,
        "dimensions_initiales_mm": [round(x, 3) for x in prep.initial_size_mm],
        "dimensions_preparees_mm": [round(x, 3) for x in prep.prepared_size_mm],
        "facteur_echelle": round(prep.scale_factor, 5),
        "reoriente_a_plat": prep.reoriented,
        "volume_mm3": round(prep.volume_mm3, 2),
        "trous_maillage_aretes": prep.open_edges_count,
        "couches_ebauche": n_rough_layers,
        "segments_ebauche": rough_segments,
        "points_finition": n_points,
        "crete_um": round(crest_um, 2),
        "a_min_deg": round(a_min_seen, 2),
        "a_max_deg": round(a_max_seen, 2),
        "blocs_brusques": n_jerky,
        "duree_ebauche_min": round(rough_min, 2),
        "duree_finition_min": round(finish_min, 2),
        "duree_totale_min": round(total_min, 2),
        "lignes_gcode": len(gcode.splitlines()),
        "notes_preparation": prep.notes,
        "avertissements": warnings,
        "operations": ["Ebauche_3Axes_Z", "Finition_Surface_Anatomique"],
    }
    return gcode, report


def _sha256_file(path: str | Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def build_medical_dossier(
    *,
    stl_path: str,
    gcode_path: str,
    gcode_content: str,
    report: dict,
    provenance_approximate: bool,
) -> dict:
    """Construit le dossier de lot médical (traçabilité type ISO 13485)."""
    return {
        "norme_tracabilite": "ISO 13485 — Dossier de lot d'usinage numérique (DHR)",
        "horodatage_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "lot_id": report["lot_id"],
        "patient_ref": report["patient_ref"],
        "dispositif": {
            "type": report["implant_type"],
            "libelle": report["implant_type_label"],
        },
        "materiau": {
            "id": report["materiau_id"],
            "nom": report["materiau_nom"],
            "norme": report["materiau_norme"],
            "coupe_a_sec_m9": not report["arrosage_autorise"],
        },
        "fichiers_et_empreintes": {
            "source_fichier": stl_path,
            "source_stl": stl_path,
            "format": "STEP" if str(stl_path).lower().endswith((".step", ".stp")) else "STL",
            "source_fichier_sha256": _sha256_file(stl_path),
            "source_stl_sha256": _sha256_file(stl_path),
            "programme_nc": gcode_path,
            "programme_nc_sha256": _sha256_text(gcode_content),
        },
        "geometrie_et_provenance": {
            "dimensions_initiales_mm": report["dimensions_initiales_mm"],
            "dimensions_preparees_mm": report["dimensions_preparees_mm"],
            "facteur_echelle": report["facteur_echelle"],
            "reoriente_a_plat": report["reoriente_a_plat"],
            "volume_mm3": report["volume_mm3"],
            "aretes_ouvertes": report["trous_maillage_aretes"],
            "provenance_approximative": provenance_approximate,
            "notes": report["notes_preparation"],
        },
        "conditions_de_coupe": {
            "outil_fraise_boule_mm": report["outil_diametre_mm"],
            "ap_mm": report["ap_mm"],
            "ae_mm": report["ae_mm"],
            "stepover_mm": report["stepover_mm"],
            "crete_theorique_um": report["crete_um"],
            "plafond_forceguard_n": 45.6,
        },
        "parcours_et_duree": {
            "pipeline": report["pipeline"],
            "couches_ebauche": report["couches_ebauche"],
            "points_finition": report["points_finition"],
            "plage_axe_a_deg": [report["a_min_deg"], report["a_max_deg"]],
            "duree_ebauche_min": report["duree_ebauche_min"],
            "duree_finition_min": report["duree_finition_min"],
            "duree_totale_min": report["duree_totale_min"],
            "lignes_gcode": report["lignes_gcode"],
        },
    }


def stl_to_implant_gcode(
    stl_path: str,
    cfg: ImplantCutConfig = ImplantCutConfig(),
    *,
    auto_orient: bool = True,
    target_length_mm: float | None = None,
    step_deflection: float = 0.01,
) -> tuple[str, dict, dict, dict]:
    """Pipeline complet : lit le STL ou STEP, prépare l'implant, génère le G-code,
    l'aperçu 3D et le dossier de traçabilité médicale."""
    raw_tris = read_3d_file(stl_path, step_deflection=step_deflection)
    prep = prepare_implant_mesh(
        raw_tris,
        auto_orient=auto_orient,
        target_length_mm=target_length_mm,
    )
    preview_dict = build_stl_preview_dict(stl_path, prep)
    gcode, report = generate_implant_program(prep, cfg)
    base = stl_path.rsplit(".", 1)[0]
    out_nc = base + "_implant.nc"
    dossier = build_medical_dossier(
        stl_path=stl_path,
        gcode_path=out_nc,
        gcode_content=gcode,
        report=report,
        provenance_approximate=cfg.provenance_approximate,
    )
    return gcode, report, dossier, preview_dict


def main() -> int:
    import argparse
    import sys

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser(
        description="Fichier 3D (STL ou STEP B-Rep) -> G-code d'implant médical sur mesure + dossier ISO 13485."
    )
    ap.add_argument("stl", help="fichier .stl ou .step / .stp de l'implant ou du guide chirurgical")
    ap.add_argument("-o", "--sortie", help="fichier .nc de sortie")
    ap.add_argument(
        "--materiau",
        default="peek",
        help="identifiant du matériau : pmma, uhmwpe, peek, wax_model (ti6al4v et cocrmo sont refusés)",
    )
    ap.add_argument(
        "--type-implant",
        default="plaque_cranienne",
        help="guide_chirurgical, plaque_cranienne, insert_articulaire, modele_anatomique",
    )
    ap.add_argument("--outil", type=float, default=6.0, help="diamètre fraise boule (mm)")
    ap.add_argument("--ap", type=float, default=None, help="profondeur de passe ébauche (mm)")
    ap.add_argument("--ae", type=float, default=None, help="engagement radial ébauche (mm)")
    ap.add_argument("--stepover", type=float, default=None, help="pas de finition (mm)")
    ap.add_argument(
        "--longueur-cible",
        type=float,
        default=None,
        help="longueur XY cible en mm (pour recaler l'échelle du maillage)",
    )
    ap.add_argument(
        "--deflection",
        type=float,
        default=0.01,
        help="flèche maximale pour la facettisation STEP en mm (défaut : 0.01 mm = 10 µm)",
    )
    ap.add_argument("--lot", default="LOT-MED-AUTO", help="numéro de lot de traçabilité")
    ap.add_argument("--patient", default="PAT-ANONYME", help="référence anonymisée du cas")
    ap.add_argument(
        "--trois-axes",
        action="store_true",
        help="forcer la finition en 3 axes (A=0, C=0) au lieu du 5 axes continu",
    )
    ap.add_argument(
        "--sans-reorientation",
        action="store_true",
        help="ne pas réorienter automatiquement l'épaisseur minimale selon Z",
    )
    ap.add_argument(
        "--provenance-approx",
        action="store_true",
        help="signale un maillage issu d'un mode génératif ou sans mire d'échelle",
    )
    ap.add_argument(
        "--sans-auto-fit",
        action="store_true",
        help="désactive l'ajustement automatique d'échelle aux dimensions de la machine",
    )
    ap.add_argument(
        "--apercu-seul",
        action="store_true",
        help="génère uniquement le fichier <base>_apercu.json pour le visualiseur 3D",
    )
    args = ap.parse_args()

    try:
        raw_tris = read_3d_file(args.stl, step_deflection=args.deflection)
        prep = prepare_implant_mesh(
            raw_tris,
            auto_orient=not args.sans_reorientation,
            target_length_mm=args.longueur_cible,
            auto_fit=not args.sans_auto_fit,
        )
    except Exception as exc:
        print(f"REFUS : {exc}")
        return 1

    base = args.stl.rsplit(".", 1)[0]
    preview_path = args.sortie if args.apercu_seul and args.sortie else base + "_apercu.json"
    preview_data = build_stl_preview_dict(args.stl, prep)
    with open(preview_path, "w", encoding="utf-8") as f:
        json.dump(preview_data, f, ensure_ascii=False)

    if args.apercu_seul:
        print(f"aperçu STL -> {preview_path}")
        return 0

    cfg = ImplantCutConfig(
        material_id=args.materiau,
        implant_type=args.type_implant,
        tool_dia=args.outil,
        ap=args.ap,
        ae=args.ae,
        stepover=args.stepover,
        five_axis=not args.trois_axes,
        lot_id=args.lot,
        patient_ref=args.patient,
        provenance_approximate=args.provenance_approx,
    )

    try:
        gcode, report = generate_implant_program(prep, cfg)
    except ValueError as exc:
        print(f"REFUS : {exc}")
        return 1

    out_nc = args.sortie or base + "_implant.nc"
    with open(out_nc, "w", encoding="utf-8") as f:
        f.write(gcode)

    # Sauvegarde aussi le STL préparé (recentré G54 et orienté) pour traçabilité
    prep_stl_path = base + "_prepare.stl"
    write_stl(prep_stl_path, prep.triangles, header=f"forgeron-med {cfg.lot_id}")

    dossier_path = base + "_dossier_medical.json"
    dossier = build_medical_dossier(
        stl_path=args.stl,
        gcode_path=out_nc,
        gcode_content=gcode,
        report=report,
        provenance_approximate=cfg.provenance_approximate,
    )
    with open(dossier_path, "w", encoding="utf-8") as f:
        json.dump(dossier, f, indent=2, ensure_ascii=False)

    report_path = base + "_rapport.json"
    full_report = {
        **report,
        "gcode_path": out_nc,
        "preview_json_path": preview_path,
        "prepared_stl_path": prep_stl_path,
        "dossier_medical_path": dossier_path,
    }
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(full_report, f, indent=2, ensure_ascii=False)

    print(
        f"{args.stl} ({report['materiau_nom']}) : "
        f"{report['lignes_gcode']} lignes -> {out_nc}"
    )
    print(f"dossier médical -> {dossier_path}")
    print(f"rapport -> {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
