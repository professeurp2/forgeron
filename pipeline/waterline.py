"""Waterline (tranchage Z) & ébauche par contours concentriques (pyclipper C++).

Complète `dropcutter.py` sur deux limites structurelles d'un balayage XY :

1. **Parois raides (> 68°)** : en Drop-Cutter pur, l'échantillonnage XY devient
   très espacé verticalement sur les flancs presque verticaux. Le tranchage
   horizontal par niveaux Z (**Waterline**) suit exactement le contour décalé de
   `ρ = tool_dia / 2` via `pyclipper` (Clipper C++), à pas vertical `ap` constant.
2. **Ébauche à engagement maîtrisé (contours concentriques)** : au lieu d'un
   zig-zag qui rencontre brutalement les angles ou coupe du vide, les boucles
   concentriques de pas `ae` (0,5 mm par défaut sur Forgeron) maintiennent un
   engagement radial régulier adapté à la broche 200 W / courroies GT2.
"""

from __future__ import annotations

import math
from typing import Iterable

import numpy as np
import pyclipper

# Clipper travaille en entiers 64 bits : échelle 1e4 = résolution 0,1 µm.
_SCALE = 10_000.0


def _to_clipper(poly: np.ndarray) -> list[tuple[int, int]]:
    return [(int(round(x * _SCALE)), int(round(y * _SCALE))) for x, y in poly]


def _from_clipper(path: list[tuple[int, int]]) -> np.ndarray:
    if not path:
        return np.zeros((0, 2), dtype=np.float64)
    return np.asarray(path, dtype=np.float64) / _SCALE


def slice_mesh_z(
    triangles: np.ndarray,
    z_level: float,
    eps: float = 1e-7,
) -> list[np.ndarray]:
    """Tranche un maillage STL fermé à l'altitude `z_level` et retourne les boucles 2D.

    Chaque triangle coupant le plan `z = z_level` produit un segment 2D ; les
    segments sont ensuite chaînés en polygones fermés.
    """
    tris = np.asarray(triangles, dtype=np.float64)
    z_min = tris[:, :, 2].min(axis=1)
    z_max = tris[:, :, 2].max(axis=1)
    candidates = tris[(z_min <= z_level + eps) & (z_max >= z_level - eps)]

    segments: list[tuple[tuple[float, float], tuple[float, float]]] = []
    for tri in candidates:
        pts: list[tuple[float, float]] = []
        for k in range(3):
            p = tri[k]
            q = tri[(k + 1) % 3]
            zp, zq = p[2], q[2]
            if (zp < z_level - eps and zq < z_level - eps) or (
                zp > z_level + eps and zq > z_level + eps
            ):
                continue
            if abs(zq - zp) < eps:
                continue
            t = (z_level - zp) / (zq - zp)
            if -eps <= t <= 1.0 + eps:
                t = min(1.0, max(0.0, t))
                x = float(p[0] + t * (q[0] - p[0]))
                y = float(p[1] + t * (q[1] - p[1]))
                pts.append((x, y))
        if len(pts) >= 2:
            p0, p1 = pts[0], pts[1]
            if math.hypot(p1[0] - p0[0], p1[1] - p0[1]) > 1e-6:
                segments.append((p0, p1))

    return _chain_segments(segments)


def _chain_segments(
    segments: list[tuple[tuple[float, float], tuple[float, float]]],
    tol: float = 1e-3,
) -> list[np.ndarray]:
    """Chaîne une liste de segments non orientés en boucles fermées."""
    if not segments:
        return []

    def qkey(pt: tuple[float, float]) -> tuple[int, int]:
        return (int(round(pt[0] / tol)), int(round(pt[1] / tol)))

    adj: dict[tuple[int, int], list[int]] = {}
    for idx, (a, b) in enumerate(segments):
        adj.setdefault(qkey(a), []).append(idx)
        adj.setdefault(qkey(b), []).append(idx)

    used = [False] * len(segments)
    loops: list[np.ndarray] = []

    for start_idx in range(len(segments)):
        if used[start_idx]:
            continue
        used[start_idx] = True
        a, b = segments[start_idx]
        chain = [a, b]
        cur = b

        while True:
            key = qkey(cur)
            nxt_idx = -1
            for cand in adj.get(key, []):
                if not used[cand]:
                    nxt_idx = cand
                    break
            if nxt_idx < 0:
                break
            used[nxt_idx] = True
            sa, sb = segments[nxt_idx]
            if math.hypot(sa[0] - cur[0], sa[1] - cur[1]) <= math.hypot(
                sb[0] - cur[0], sb[1] - cur[1]
            ):
                cur = sb
            else:
                cur = sa
            chain.append(cur)
            if math.hypot(cur[0] - chain[0][0], cur[1] - chain[0][1]) <= tol:
                break

        if len(chain) >= 3:
            loops.append(np.asarray(chain, dtype=np.float64))
    return loops


def offset_loops(
    loops: Iterable[np.ndarray],
    delta_mm: float,
    arc_tolerance_mm: float = 0.01,
) -> list[np.ndarray]:
    """Décale des boucles 2D via Clipper (`delta_mm > 0` = dilatation externe)."""
    pco = pyclipper.PyclipperOffset(arc_tolerance=arc_tolerance_mm * _SCALE)
    added = False
    for poly in loops:
        if len(poly) < 3:
            continue
        cpath = _to_clipper(poly)
        if not pyclipper.Orientation(cpath):
            cpath = list(reversed(cpath))
        pco.AddPath(cpath, pyclipper.JT_ROUND, pyclipper.ET_CLOSEDPOLYGON)
        added = True
    if not added:
        return []
    res = pco.Execute(delta_mm * _SCALE)
    return [_from_clipper(p) for p in res if len(p) >= 3]


def waterline_paths(
    triangles: np.ndarray,
    tool_dia: float,
    ap: float,
    z_top: float = 0.0,
    z_bottom: float | None = None,
    stock_leave: float = 0.0,
) -> list[tuple[float, list[np.ndarray]]]:
    """Génère les contours de finition Waterline par tranches Z.

    Retourne une liste de `(z_tip, [boucle_xy, ...])` pour chaque niveau Z.
    Pour une fraise boule, le rayon effectif à la hauteur du centre est `rho` ;
    la pointe de l'outil est à `z_center - rho`.
    """
    rho = tool_dia / 2.0
    tris = np.asarray(triangles, dtype=np.float64)
    if z_bottom is None:
        z_bottom = float(tris[:, :, 2].min())

    offset = rho + stock_leave
    n_layers = max(1, int(math.ceil((z_top - z_bottom) / ap)))
    levels: list[tuple[float, list[np.ndarray]]] = []

    for k in range(1, n_layers + 1):
        z_slice = max(z_top - k * ap, z_bottom)
        raw_loops = slice_mesh_z(tris, z_slice)
        if not raw_loops:
            continue
        # Union + décalage exact pour fusionner les îlots qui se rejoignent
        off = offset_loops(raw_loops, offset)
        if off:
            # Pour la pointe de l'outil sur la tranche z_slice (contact latéral)
            levels.append((z_slice - rho, off))
    return levels


def adaptive_contour_roughing(
    triangles: np.ndarray,
    tool_dia: float,
    ap: float,
    ae: float,
    stock_margin: float = 2.0,
    stock_leave: float = 0.3,
    z_top: float = 0.0,
    z_bottom: float | None = None,
) -> list[tuple[float, list[np.ndarray]]]:
    """Ébauche par contours concentriques (Clipper) à engagement radial `ae` constant.

    À chaque couche Z :
      1. Tranche le maillage et dilate l'îlot de `rho + stock_leave` (zone interdite).
      2. Part du contour extérieur du brut et génère les anneaux concentriques
         vers l'intérieur par pas de `ae`, en évidant uniquement la matière
         située entre le brut et l'îlot dilaté.
    """
    rho = tool_dia / 2.0
    tris = np.asarray(triangles, dtype=np.float64)
    pts = tris.reshape(-1, 3)
    if z_bottom is None:
        z_bottom = float(pts[:, 2].min())

    lo_x, lo_y = float(pts[:, 0].min()) - stock_margin, float(pts[:, 1].min()) - stock_margin
    hi_x, hi_y = float(pts[:, 0].max()) + stock_margin, float(pts[:, 1].max()) + stock_margin
    stock_rect = _to_clipper(
        np.array([[lo_x, lo_y], [hi_x, lo_y], [hi_x, hi_y], [lo_x, hi_y]], dtype=np.float64)
    )

    n_layers = max(1, int(math.ceil((z_top - z_bottom) / ap)))
    layers: list[tuple[float, list[np.ndarray]]] = []

    for k in range(1, n_layers + 1):
        z = max(z_top - k * ap, z_bottom)
        # Coupe la pièce un peu au-dessus de z + stock_leave pour protéger la pente
        raw_loops = slice_mesh_z(tris, min(z_top, z + stock_leave))
        forbidden = offset_loops(raw_loops, rho + stock_leave) if raw_loops else []

        # Zone à évider = brut - zone interdite (pièce dilatée)
        pc = pyclipper.Pyclipper()
        pc.AddPath(stock_rect, pyclipper.PT_SUBJECT, True)
        for f_loop in forbidden:
            cpath = _to_clipper(f_loop)
            if not pyclipper.Orientation(cpath):
                cpath = list(reversed(cpath))
            pc.AddPath(cpath, pyclipper.PT_CLIP, True)
        pocket_regions = pc.Execute(
            pyclipper.CT_DIFFERENCE, pyclipper.PFT_NONZERO, pyclipper.PFT_NONZERO
        )
        if not pocket_regions:
            continue

        # Anneaux concentriques de pas ae depuis le bord extérieur vers l'îlot.
        # La zone interdite inclut déjà (rho + stock_leave) autour de la pièce ;
        # le premier anneau (delta = 0) suit donc le contour exact de la poche
        # sans jamais entamer la pièce.
        ring_paths: list[np.ndarray] = []
        pco = pyclipper.PyclipperOffset(arc_tolerance=0.01 * _SCALE)
        pco.AddPaths(pocket_regions, pyclipper.JT_ROUND, pyclipper.ET_CLOSEDPOLYGON)
        step_idx = 0
        while True:
            delta = -(step_idx * ae) * _SCALE
            rings = pocket_regions if step_idx == 0 else pco.Execute(delta)
            if not rings:
                break
            for r in rings:
                if len(r) >= 3:
                    ring_paths.append(_from_clipper(r))
            step_idx += 1
            if step_idx > 500:  # garde-fou
                break

        if ring_paths:
            layers.append((z, ring_paths))

    return layers
