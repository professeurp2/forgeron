"""Vérificateur indépendant d'un programme 5 axes, sans machine.

Il ne fait pas confiance au générateur : il relit le G-code, le rejoue tel que
FluidNC l'exécute (interpolation LINÉAIRE de tous les axes dans un bloc), repasse
dans le repère pièce et compare au maillage. Il mesure, il ne corrige rien.

Contrôles :
  - pénétration de la bille dans la pièce, y compris ENTRE deux points programmés
    (en 5 axes, une corde machine n'est pas une corde pièce) ;
  - pénétration de la bille dans la table ;
  - collision de la queue d'outil et du porte-outil avec la pièce (échantillonnée) ;
  - course A, excursion X/Y/Z ;
  - avance RÉELLE au centre de la bille, avec le plafond max_rate de chaque axe.

Ce qu'il ne voit pas : les brides et le montage (absents du modèle), le brut pas
encore enlevé, la position absolue du G54 dans les courses (seule l'excursion est
contrôlée). L'accélération n'est pas simulée : les durées sont des minorants.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from dataclasses import dataclass

import numpy as np

from dropcutter import height_map
from kinematics import Trunnion, tool_axis_in_piece
from stl_io import read_stl

# scratch/config_5axes_production.yaml
MAX_RATE = {"X": 500.0, "Y": 500.0, "Z": 300.0, "A": 3600.0, "C": 3600.0}
TRAVEL = {"X": 88.0, "Y": 150.0, "Z": 110.0}

_WORD = re.compile(r"([A-Z])\s*(-?\d+(?:\.\d*)?|-?\.\d+)")
_COMMENT = re.compile(r"\([^)]*\)|;.*$")


@dataclass(frozen=True)
class Move:
    line: int
    rapid: bool
    start: np.ndarray  # X Y Z A C
    end: np.ndarray
    feed: float


_AXIS_INDEX = {"X": 0, "Y": 1, "Z": 2, "A": 3, "C": 4}


def _allclose5(new: list[float], pos: list[float]) -> bool:
    """Équivalent exact de `np.allclose(new, pos)` (rtol=1e-5, atol=1e-8) sur
    cinq flottants, sans le coût d'un appel NumPy par ligne de G-code."""
    for a, b in zip(new, pos):
        if abs(a - b) > 1e-8 + 1e-5 * abs(b):
            return False
    return True


def parse_moves(gcode: str) -> list[Move]:
    # Python pur ligne à ligne : sur un programme de 300 000 lignes, les petits
    # appels NumPy (copy, allclose, all) coûtaient ~30 s pour un résultat identique.
    pos = [0.0, 0.0, 0.0, 0.0, 0.0]
    known = [False] * 5
    motion = 0
    feed = 0.0
    moves: list[Move] = []
    for no, raw in enumerate(gcode.splitlines(), 1):
        words = _WORD.findall(_COMMENT.sub("", raw).upper())
        coords = {}
        for letter, value in words:
            if letter == "G" and float(value) in (0.0, 1.0):
                motion = int(float(value))
            elif letter == "G" and float(value) in (2.0, 3.0, 93.0):
                raise ValueError(f"ligne {no} : G{value} non géré par le vérificateur")
            elif letter == "F":
                feed = float(value)
            elif letter in "XYZAC":
                coords[letter] = float(value)
        if not coords:
            continue
        new = pos.copy()
        for letter, value in coords.items():
            k = _AXIS_INDEX[letter]
            new[k] = value
            known[k] = True
        # Tant que les cinq axes ne sont pas connus, le départ du bloc ne l'est pas.
        if all(known) and not _allclose5(new, pos):
            moves.append(Move(no, motion == 0, np.array(pos), np.array(new), feed))
        pos = new
    return moves


def _bilinear(xs: np.ndarray, ys: np.ndarray, Z: np.ndarray, x, y) -> np.ndarray:
    """Hauteur interpolée. Au bord de la surface, le coin le plus proche décide."""
    dx, dy = xs[1] - xs[0], ys[1] - ys[0]
    fx = (np.asarray(x) - xs[0]) / dx
    fy = (np.asarray(y) - ys[0]) / dy
    i = np.floor(fx).astype(int)
    j = np.floor(fy).astype(int)
    out = np.full(i.shape, -np.inf)
    ok = (i >= 0) & (j >= 0) & (i < len(xs) - 1) & (j < len(ys) - 1)
    ii, jj = i[ok], j[ok]
    tx, ty = fx[ok] - ii, fy[ok] - jj
    corners = np.stack([Z[jj, ii], Z[jj, ii + 1], Z[jj + 1, ii], Z[jj + 1, ii + 1]])
    with np.errstate(invalid="ignore"):
        v = (corners[0] * (1 - tx) * (1 - ty) + corners[1] * tx * (1 - ty)
             + corners[2] * (1 - tx) * ty + corners[3] * tx * ty)
    nearest = corners[np.round(ty).astype(int) * 2 + np.round(tx).astype(int), np.arange(len(ii))]
    out[ok] = np.where(np.isfinite(v), v, nearest)
    return out


def _centres_in_piece(samples: np.ndarray, rho: float, tr: Trunnion) -> np.ndarray:
    """Centre de la bille dans le repère pièce : inverse de la chaîne du trunnion."""
    t = samples[:, :3] + np.array([0.0, 0.0, rho]) - np.asarray(tr.pivot, dtype=float)
    a = np.radians(samples[:, 3])
    c = np.radians(samples[:, 4])
    y = np.cos(a) * t[:, 1] + np.sin(a) * t[:, 2]
    z = -np.sin(a) * t[:, 1] + np.cos(a) * t[:, 2] - tr.pivot_to_table
    x = np.cos(c) * t[:, 0] + np.sin(c) * y
    yy = -np.sin(c) * t[:, 0] + np.cos(c) * y
    return np.column_stack([x, yy, z])


def _distance_to_mesh(point: np.ndarray, triangles: np.ndarray) -> float:
    """Distance exacte d'un point à un maillage (point le plus proche, Ericson)."""
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    ab, ac = b - a, c - a
    ap = point - a
    d1 = (ab * ap).sum(1)
    d2 = (ac * ap).sum(1)
    bp = point - b
    d3 = (ab * bp).sum(1)
    d4 = (ac * bp).sum(1)
    cp = point - c
    d5 = (ab * cp).sum(1)
    d6 = (ac * cp).sum(1)
    vc = d1 * d4 - d3 * d2
    vb = d5 * d2 - d1 * d6
    va = d3 * d6 - d5 * d4
    with np.errstate(divide="ignore", invalid="ignore"):
        denom = 1.0 / (va + vb + vc)
        q = a + ab * (vb * denom)[:, None] + ac * (vc * denom)[:, None]  # dans la face
        w = d2 / (d2 - d6)
        q = np.where(((vb <= 0) & (d2 >= 0) & (d6 <= 0))[:, None], a + w[:, None] * ac, q)
        v = d1 / (d1 - d3)
        q = np.where(((vc <= 0) & (d1 >= 0) & (d3 <= 0))[:, None], a + v[:, None] * ab, q)
        u = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        q = np.where(((va <= 0) & (d4 - d3 >= 0) & (d5 - d6 >= 0))[:, None], b + u[:, None] * (c - b), q)
    q = np.where(((d6 >= 0) & (d5 <= d6))[:, None], c, q)
    q = np.where(((d3 >= 0) & (d4 <= d3))[:, None], b, q)
    q = np.where(((d1 <= 0) & (d2 <= 0))[:, None], a, q)
    return float(np.sqrt(np.nanmin(((q - point) ** 2).sum(1))))


def verify(
    gcode: str,
    triangles: np.ndarray,
    tr: Trunnion,
    *,
    tool_dia: float = 6.0,
    table_z: float | None = None,
    flute_length: float = 18.0,
    holder_radius: float = 12.0,
    holder_length: float = 40.0,
    gouge_tol: float = 0.05,
    v_target: float | None = None,
    max_step_mm: float = 0.25,
    max_step_deg: float = 1.0,
    max_tool_samples: int = 3000,
    max_exact_checks: int = 3000,
    height_field: tuple | None = None,
) -> dict:
    rho = tool_dia / 2
    moves = parse_moves(gcode)
    if not moves:
        raise ValueError("aucun mouvement complet (X Y Z A C) dans le programme")

    if height_field is not None:
        xs, ys, Zmap = height_field  # carte déjà calculée pour ce maillage et cet outil
    else:
        grid = max(0.15, min(0.4, tool_dia / 20))
        xs, ys, Zmap = height_map(triangles, rho=rho, step=grid, margin=rho + grid)
    verts = np.unique(np.round(triangles.reshape(-1, 3), 3), axis=0)
    if len(verts) > 20000:
        verts = verts[:: len(verts) // 20000]

    starts = np.array([m.start for m in moves])
    ends = np.array([m.end for m in moves])
    deltas = ends - starts
    all_axes = np.vstack([starts, ends])
    span = all_axes.max(axis=0) - all_axes.min(axis=0)
    d_lin = np.linalg.norm(deltas[:, :3], axis=1)
    d_ang = np.linalg.norm(deltas[:, 3:], axis=1)
    counts = np.maximum(1, np.ceil(np.maximum(d_lin / max_step_mm, d_ang / max_step_deg))).astype(int)
    rapid = np.array([m.rapid for m in moves])
    feeds = np.array([m.feed for m in moves])
    lines = np.array([m.line for m in moves])

    # Échantillons : le départ de chaque bloc puis ses points intermédiaires.
    idx = np.repeat(np.arange(len(moves)), counts + 1)
    ts = np.concatenate([np.arange(c + 1) / c for c in counts])
    samples = starts[idx] + ts[:, None] * deltas[idx]
    centres = _centres_in_piece(samples, rho, tr)
    offsets = np.concatenate(([0], np.cumsum(counts + 1)))[:-1]

    # Temps du bloc tel que grbl le calcule, plafonné axe par axe.
    rates = np.array([MAX_RATE[k] for k in "XYZAC"])
    axis_times = np.abs(deltas) / rates
    t_axes = axis_times.max(axis=1)
    slow = axis_times.argmax(axis=1)
    with np.errstate(divide="ignore"):
        t_feed = np.where(feeds > 0, np.hypot(d_lin, d_ang) / np.maximum(feeds, 1e-9), np.inf)
    rapid_time = float(t_axes[rapid].sum())
    t_cut = np.maximum(t_feed, t_axes)
    cut = ~rapid
    cut_time = float(t_cut[cut].sum())
    is_capped = cut & (t_axes > t_feed)
    limiting = {k: int((slow[is_capped] == i).sum()) for i, k in enumerate("XYZAC")}

    step = np.linalg.norm(np.diff(centres, axis=0), axis=1)
    step[offsets[1:] - 1] = 0.0  # pas de longueur entre deux blocs
    dist = np.add.reduceat(np.append(step, 0.0), offsets)
    usable = cut & (dist > 1e-6) & (t_cut > 0)
    sp = dist[usable] / t_cut[usable] if usable.any() else np.array([0.0])

    floor = _bilinear(xs, ys, Zmap, centres[:, 0], centres[:, 1])
    pen = np.where(np.isfinite(floor), floor - centres[:, 2], -np.inf)
    pen_move = np.maximum.reduceat(pen, offsets)
    hit = pen_move > gouge_tol

    # La carte est une grille : tangente à une paroi, elle crie au loup. Chaque
    # suspect est donc jugé par la vraie distance aux triangles. Au-delà du
    # plafond, le programme est de toute façon refusé : les suivants restent suspects.
    suspects = np.flatnonzero(hit)
    for k in suspects[:max_exact_checks]:
        worst = offsets[k] + int(pen[offsets[k]: offsets[k] + counts[k] + 1].argmax())
        depth = rho - _distance_to_mesh(centres[worst], triangles)
        pen_move[k] = depth
        hit[k] = depth > gouge_tol

    n_gouge = int(hit.sum())
    worst_gouge = float(pen_move[hit].max()) if n_gouge else 0.0
    worst_line = int(lines[hit][int(pen_move[hit].argmax())]) if n_gouge else None

    n_table = 0
    worst_table = 0.0
    if table_z is not None:
        table_pen = np.maximum.reduceat(table_z + rho - centres[:, 2], offsets)
        n_table = int((table_pen > gouge_tol).sum())
        worst_table = float(table_pen.max()) if n_table else 0.0

    # Queue d'outil et porte-outil : axe outil dans le repère pièce, testé contre
    # les sommets du maillage, en bout de bloc et sur un échantillon de blocs.
    n_flute = n_holder = 0
    first_flute = first_holder = None
    moving = np.abs(ends[:, 3]) + d_ang > 1e-6
    tilted = np.flatnonzero(moving)
    vertical = np.flatnonzero(~moving)
    checked = np.concatenate([
        tilted[:: max(1, len(tilted) // max_tool_samples)],
        vertical[:: max(1, len(vertical) // 500)],
    ])
    for k in checked:
        c = centres[offsets[k] + counts[k]]
        ax = tool_axis_in_piece(ends[k, 3], ends[k, 4])
        rel = verts - c
        along = rel @ ax
        radial = np.linalg.norm(rel - along[:, None] * ax, axis=1)
        if np.any((along > rho) & (along < flute_length) & (radial < rho - gouge_tol)):
            n_flute += 1
            first_flute = first_flute or int(lines[k])
        if np.any((along >= flute_length) & (along < flute_length + holder_length)
                  & (radial < holder_radius)):
            n_holder += 1
            first_holder = first_holder or int(lines[k])

    report = {
        "blocs": len(moves),
        "blocs_avec_rotation": int((d_ang > 1e-6).sum()),
        "blocs_a_et_c": int(((np.abs(deltas[:, 3]) > 1e-6) & (np.abs(deltas[:, 4]) > 1e-6)).sum()),
        "blocs_outil_controles": int(len(checked)),
        "excursion_mm": {k: round(float(span[i]), 2) for i, k in enumerate("XYZ")},
        "courses_mm": TRAVEL,
        "excursion_tient": bool(all(span[i] <= TRAVEL[k] for i, k in enumerate("XYZ"))),
        "a_deg": [round(float(all_axes[:, 3].min()), 2), round(float(all_axes[:, 3].max()), 2)],
        "c_deg": [round(float(all_axes[:, 4].min()), 2), round(float(all_axes[:, 4].max()), 2)],
        "a_dans_course": bool(all_axes[:, 3].min() >= tr.a_min and all_axes[:, 3].max() <= tr.a_max),
        "c_dans_course": bool(span[4] <= 720.0),
        "blocs_penetrant_piece": n_gouge,
        "dont_rapides": int((hit & rapid).sum()),
        "penetration_max_mm": round(worst_gouge, 3),
        "ligne_penetration_max": worst_line,
        "blocs_penetrant_table": n_table,
        "penetration_table_max_mm": round(worst_table, 3),
        "collisions_queue": n_flute,
        "premiere_collision_queue_ligne": first_flute,
        "collisions_porte_outil": n_holder,
        "premiere_collision_porte_outil_ligne": first_holder,
        "avance_reelle_mm_min": {
            "min": round(float(sp.min()), 1),
            "p05": round(float(np.percentile(sp, 5)), 1),
            "mediane": round(float(np.median(sp)), 1),
            "p95": round(float(np.percentile(sp, 95)), 1),
            "max": round(float(sp.max()), 1),
        },
        "blocs_ecretes_max_rate": int(is_capped.sum()),
        "axe_limitant": {k: v for k, v in limiting.items() if v},
        "duree_coupe_min": round(cut_time, 2),
        "duree_rapides_min": round(rapid_time, 2),
        "longueur_coupe_mm": round(float(dist[cut].sum()), 1),
    }
    if v_target:
        report["avance_visee_mm_min"] = v_target
        report["blocs_sous_50pct_visee"] = int((sp < 0.5 * v_target).sum())
    return report


def replay_reference(gcode: str, tr: Trunnion) -> list[tuple[int, float, float, float, float]]:
    """(ligne, pointe X Y Z dans le repère pièce, temps cumulé en s) en fin de bloc.

    Référence que le rejeu Dart et le simulateur doivent retrouver : une seule
    vérité sur « où est l'outil » et sur la durée du programme.
    """
    rates = np.array([MAX_RATE[k] for k in "XYZAC"])
    rows = []
    elapsed = 0.0
    for m in parse_moves(gcode):
        delta = m.end - m.start
        t = float((np.abs(delta) / rates).max())
        if not m.rapid and m.feed > 0:
            t = max(t, float(np.linalg.norm(delta)) / m.feed)
        elapsed += t * 60.0
        tip = _centres_in_piece(m.end[None, :], 0.0, tr)[0]
        rows.append((m.line, float(tip[0]), float(tip[1]), float(tip[2]), elapsed))
    return rows


def is_safe(report: dict) -> bool:
    """Le programme peut-il être proposé pour un essai à vide ?"""
    return (
        report["blocs_penetrant_piece"] == 0
        and report["blocs_penetrant_table"] == 0
        and report["collisions_queue"] == 0
        and report["collisions_porte_outil"] == 0
        and report["a_dans_course"]
        and report["c_dans_course"]
        and report["excursion_tient"]
    )


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Rejoue un programme 5 axes contre son maillage.")
    ap.add_argument("gcode")
    ap.add_argument("stl", help="maillage préparé, dans le repère pièce du programme")
    ap.add_argument("--outil", type=float, default=6.0)
    ap.add_argument("--pivot-z", type=float, default=0.0, help="Z du pivot A dans le G54")
    ap.add_argument("--pivot-table", type=float, default=8.0,
                    help="distance du pivot A à l'origine Z du repère pièce")
    ap.add_argument("--table-z", type=float, default=None, help="Z de la table, repère pièce")
    args = ap.parse_args()
    tr = Trunnion(pivot_to_table=args.pivot_table, pivot=(0.0, 0.0, args.pivot_z))
    with open(args.gcode, encoding="utf-8", errors="replace") as f:
        gcode = f.read()
    report = verify(gcode, read_stl(args.stl), tr, tool_dia=args.outil, table_z=args.table_z)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if is_safe(report) else 1


if __name__ == "__main__":
    raise SystemExit(main())
