"""Stratégie 3+2 axes multi-vues pour contre-dépouilles et flancs raides.

En usinage 3 axes (ou 5 axes sur une seule carte de hauteur Z+), les zones
situées sous un surplomb (contre-dépouille) ou sur des flancs quasi-verticaux
sont invisibles. Grâce à l'accélération Numba de `dropcutter.height_map`, on peut
calculer en quelques centièmes de seconde des cartes de hauteur depuis plusieurs
orientations indexées `(A, C)` du trunnion, identifier les triangles non couverts
par la vue verticale `(0°, 0°)` et générer les passes d'indexage 3+2 correspondantes.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from continuous5 import Params, f3
from dropcutter import height_map
from kinematics import Trunnion, _rx, _rz, machine_to_piece


@dataclass(frozen=True)
class IndexedView:
    """Orientation indexée du trunnion (degrés)."""

    a_deg: float
    c_deg: float
    label: str = ""


DEFAULT_3PLUS2_VIEWS: tuple[IndexedView, ...] = (
    IndexedView(0.0, 0.0, "dessus"),
    IndexedView(-45.0, 0.0, "face_avant"),
    IndexedView(-45.0, 90.0, "droite"),
    IndexedView(-45.0, 180.0, "arriere"),
    IndexedView(-45.0, 270.0, "gauche"),
)


def _rotate_triangles_for_view(
    triangles: np.ndarray, a_deg: float, c_deg: float, tr: Trunnion
) -> np.ndarray:
    """Transforme tous les sommets du repère pièce vers le repère machine à (A, C)."""
    pts = triangles.reshape(-1, 3)
    inner = pts @ _rz(c_deg).T + np.array([0.0, 0.0, tr.pivot_to_table], dtype=np.float64)
    rotated = inner @ _rx(a_deg).T + np.asarray(tr.pivot, dtype=np.float64)
    return rotated.reshape(triangles.shape)


def analyze_view_coverage(
    triangles: np.ndarray,
    tr: Trunnion,
    p: Params,
    views: tuple[IndexedView, ...] = DEFAULT_3PLUS2_VIEWS,
) -> list[dict]:
    """Évalue la couverture géométrique de chaque vue indexée `(A, C)`."""
    rho = p.tool_dia / 2.0
    tris = np.asarray(triangles, dtype=np.float64)
    # Normales des triangles dans le repère pièce
    ab = tris[:, 1] - tris[:, 0]
    ac = tris[:, 2] - tris[:, 0]
    normals = np.cross(ab, ac)
    norms = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = np.where(norms > 1e-12, normals / np.maximum(norms, 1e-12), [0.0, 0.0, 1.0])

    # Vecteur d'approche de l'outil dans le repère pièce pour (A, C) :
    # Rz(-C) · Rx(-A) · (0, 0, 1)
    covered = np.zeros(len(tris), dtype=bool)
    report: list[dict] = []

    for view in views:
        a = math.radians(view.a_deg)
        c = math.radians(view.c_deg)
        # Axe outil dans le repère pièce :
        # piece_to_machine applique Rz(C) puis Rx(A), donc l'inverse sur (0,0,1) :
        # Rx(-A) @ (0,0,1) = (0, sin(A), cos(A))
        # Rz(-C) @ v = (vx*cos(C) + vy*sin(C), -vx*sin(C) + vy*cos(C), vz)
        vy_a = math.sin(a)
        vz_a = math.cos(a)
        ax_p = np.array([vy_a * math.sin(c), vy_a * math.cos(c), vz_a], dtype=np.float64)

        dots = normals @ ax_p
        # Visible si la normale pointe à moins de 68° de l'axe outil (cos > 0.37)
        visible = dots > 0.37
        newly_covered = visible & ~covered
        covered |= visible

        # Calcul rapide de la carte de hauteur dans le repère machine de cette vue
        tris_m = _rotate_triangles_for_view(tris, view.a_deg, view.c_deg, tr)
        xs, ys, Z_c = height_map(tris_m, rho=rho, step=max(p.fine_step, 0.5), margin=0.0)
        reachable_pts = int(np.isfinite(Z_c).sum())

        report.append({
            "view": view.label or f"A{view.a_deg}_C{view.c_deg}",
            "a_deg": view.a_deg,
            "c_deg": view.c_deg,
            "triangles_visibles": int(visible.sum()),
            "nouveaux_triangles_debloques": int(newly_covered.sum()),
            "couverture_cumulee_pct": round(100.0 * float(covered.sum()) / max(1, len(tris)), 2),
            "grille_points_atteints": reachable_pts,
        })
    return report


def generate_indexed_pass(
    triangles: np.ndarray,
    tr: Trunnion,
    view: IndexedView,
    p: Params,
    z_safe_machine: float,
    table_z: float | None = None,
) -> list[str]:
    """Génère les blocs G-code 3+2 (positionnement A/C puis balayage Z_machine) pour une vue."""
    rho = p.tool_dia / 2.0
    tris_m = _rotate_triangles_for_view(triangles, view.a_deg, view.c_deg, tr)
    xs, ys, Z_c = height_map(tris_m, rho=rho, step=p.fine_step, margin=0.0)

    # Garde-fou table : en repère pièce, le centre de bille ne doit jamais
    # descendre sous (table_z + rho) pour éviter de fraiser le plateau trunnion.
    if table_z is not None:
        ny, nx = Z_c.shape
        gx, gy = np.meshgrid(xs, ys)
        finite = np.isfinite(Z_c)
        if np.any(finite):
            pts_m = np.column_stack([gx[finite], gy[finite], Z_c[finite]])
            # Inverse rapide : Rz(-C) · (Rx(-A)·(pts_m - pivot) - (0,0,d))
            t = pts_m - np.asarray(tr.pivot, dtype=np.float64)
            inner = t @ _rx(-view.a_deg).T - np.array([0.0, 0.0, tr.pivot_to_table], dtype=np.float64)
            pts_p = inner @ _rz(-view.c_deg).T
            safe_mask = pts_p[:, 2] >= (table_z + rho + 0.05)
            valid_idx = np.flatnonzero(finite)
            drop_idx = valid_idx[~safe_mask]
            Z_c_flat = Z_c.ravel()
            Z_c_flat[drop_idx] = -np.inf

    Z_tip = Z_c - rho

    dy = ys[1] - ys[0] if len(ys) > 1 else p.stepover
    row_step = max(1, int(round(p.stepover / dy)))

    lines = [
        f"(VUE 3+2 : {view.label} A={f3(view.a_deg)} C={f3(view.c_deg)})",
        f"G0 Z{f3(z_safe_machine)}",
        f"G0 A{f3(view.a_deg)} C{f3(view.c_deg)}",
    ]

    forward = True
    for j in range(0, len(ys), row_step):
        row = Z_tip[j]
        valid = np.flatnonzero(np.isfinite(row))
        if len(valid) == 0:
            continue
        indices = valid if forward else valid[::-1]
        forward = not forward

        i0 = int(indices[0])
        lines.append(f"G0 X{f3(xs[i0])} Y{f3(ys[j])}")
        lines.append(f"G1 Z{f3(row[i0])} F{f3(p.feed_plunge)}")
        for i in indices[1:]:
            lines.append(f"G1 X{f3(xs[int(i)])} Y{f3(ys[j])} Z{f3(row[int(i)])} F{f3(p.v_surface)}")
        lines.append(f"G0 Z{f3(z_safe_machine)}")

    return lines
