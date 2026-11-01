"""Usinage 5 axes CONTINU d'une surface : ébauche 3 axes + finition A/C simultanés.

Il remplace le parcours de `gen_surface5.generate`, dont le rejeu par `verify5`
a montré trois défauts sur un simple dôme :

  - ébauche et finition n'étaient pas dans le même repère (écart de `d`), et la
    pièce était placée sous la table du modèle cinématique ;
  - une passe d'ébauche allait du premier au dernier point coupable de la ligne,
    à travers ce qu'il y a entre les deux ;
  - la normale brute faisait sauter C au pôle et aux bords.

── Le repère, une seule fois ───────────────────────────────────────────────

G54 : X/Y sur l'axe C, Z sur le dessus de la pièce, à A=0 et C=0. Le pivot A est
donc à D = hauteur pièce + cale + d SOUS le zéro :

    machine = (0, 0, -D) + Rx(A)·( Rz(C)·p + (0, 0, D) )

À A=C=0 on retrouve machine = p : ébauche et finition parlent du même point.

── L'orientation ───────────────────────────────────────────────────────────

Avec une fraise boule, le point touché ne dépend pas de l'axe outil : on peut
s'écarter de la normale sans abîmer la surface. On s'en sert pour ménager une
machine sans RTCP, où chaque degré se paie en X/Y/Z :

  1. normales lissées (une rotation ne doit pas suivre le bruit du maillage) ;
  2. inclinaison mise à zéro près du pôle, là où C est indéterminé ;
  3. inclinaison plafonnée (hauteur de collision, course X/Y/Z) ;
  4. rotation bornée en degrés par mm parcouru sur la pièce.

Limite assumée : la carte de hauteur ne voit la pièce que par le dessus. Une
contre-dépouille (entre les pales d'une turbine) n'est PAS atteinte, ni un point
trop profond pour la sortie d'outil, ni un flanc quasi vertical en finition ; le
rapport chiffre ce qui n'est pas usiné au lieu de le taire.
"""

from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass, field as dc_field
from pathlib import Path

import numpy as np

from dropcutter import height_map
from kinematics import (
    Trunnion,
    machine_to_piece,
    normals_from_height_map,
    piece_to_machine,
    tool_axis_in_piece,
)
from verify5 import MAX_RATE, TRAVEL, _bilinear, is_safe, verify

D_PIVOT_TO_TABLE = 8.0  # mesuré sur la machine, cf. TrunnionConfig.pivotToTableOffset


def f3(v: float) -> str:
    s = f"{v:.3f}"
    return "0.000" if s == "-0.000" else s


@dataclass(frozen=True)
class Params:
    tool_dia: float = 6.0
    ap: float = 0.2                # plafond vibratoire mesuré, PLAN-OPTIMISATION
    ae: float = 0.5
    stepover: float = 0.5          # pas de finition
    stock_leave: float = 0.3
    feed_rough: float = 400.0
    feed_plunge: float = 80.0
    v_surface: float = 150.0       # visée au centre de la bille (mm/min)
    feed_cap: float = 500.0        # au-delà, ForceGuard réécrit le F
    spindle: int = 1000
    under_part: float = 0.0        # cale ou surépaisseur sous la pièce (mm)
    d_pivot_table: float = D_PIVOT_TO_TABLE
    tilt_max: float = 45.0
    tilt_deadband: float = 6.0     # sous cette pente, l'outil reste vertical
    smooth_mm: float = 2.0
    rate_a: float = 3.0            # degrés par mm parcouru sur la pièce
    rate_c: float = 4.0
    chord_tol: float = 0.01
    clearance: float = 5.0
    five_axis: bool = True
    a_branch: int = -1             # -1 : A négatif, sens validé à vide sur la machine
    c_wind_max: float = 340.0      # course C de 720° : ±340° autour du dernier rembobinage
    fine_step: float = 0.25        # pas de la carte de finition
    max_slope: float = 2.5         # au-delà (68°), on ne suit plus le flanc
    flute_length: float = 18.0     # sortie d'outil mesurée
    holder_radius: float = 12.0
    holder_length: float = 40.0


@dataclass
class Toolpaths:
    rough: list[str]
    finish: list[str]
    trunnion: Trunnion
    z_safe: float
    table_z: float
    field: tuple
    stats: dict = dc_field(default_factory=dict)


def trunnion_for(triangles: np.ndarray, p: Params) -> tuple[Trunnion, float]:
    pts = triangles.reshape(-1, 3)
    top, bottom = float(pts[:, 2].max()), float(pts[:, 2].min())
    if abs(top) > 1e-3:
        raise ValueError(f"le dessus de la pièce doit être à Z=0 (trouvé Z={top:.3f})")
    table_z = bottom - p.under_part
    D = -table_z + p.d_pivot_table
    return Trunnion(pivot_to_table=D, pivot=(0.0, 0.0, -D)), table_z


def swept_safe_z(triangles: np.ndarray, tr: Trunnion, clearance: float) -> float:
    """Z de pointe au-dessus de tout ce que la pièce peut balayer en tournant."""
    pts = triangles.reshape(-1, 3)
    radial = np.hypot(pts[:, 0], pts[:, 1])
    reach = np.hypot(radial, pts[:, 2] + tr.pivot_to_table).max()
    return float(tr.pivot[2] + reach + clearance)


def _gauss1d(a: np.ndarray, sigma: float, axis: int) -> np.ndarray:
    radius = max(1, int(3 * sigma))
    k = np.exp(-0.5 * (np.arange(-radius, radius + 1) / sigma) ** 2)
    k /= k.sum()
    return np.apply_along_axis(lambda m: np.convolve(m, k, mode="same"), axis, a)


def smooth_normals(xs: np.ndarray, ys: np.ndarray, Z: np.ndarray, sigma_mm: float) -> np.ndarray:
    """Moyenne des NORMALES, pas des hauteurs : lisser Z aplatit la pente au bord
    de la pièce, et l'outil n'y suit plus la surface. Les cases sans surface ne
    pèsent rien."""
    step = xs[1] - xs[0] if len(xs) > 1 else 1.0
    sigma = max(0.5, sigma_mm / step)
    mask = np.isfinite(Z).astype(float)
    raw = normals_from_height_map(xs, ys, np.where(mask > 0, Z, np.nan))
    out = np.stack(
        [_gauss1d(_gauss1d(raw[..., k] * mask, sigma, 0), sigma, 1) for k in range(3)],
        axis=-1,
    )
    norm = np.linalg.norm(out, axis=-1, keepdims=True)
    return np.where(norm > 1e-9, out / np.maximum(norm, 1e-9), np.array([0.0, 0.0, 1.0]))


def _sliding_max(a: np.ndarray, radius: int, axis: int) -> np.ndarray:
    pad = [(0, 0), (0, 0)]
    pad[axis] = (radius, radius)
    win = np.lib.stride_tricks.sliding_window_view(
        np.pad(a, pad, constant_values=-np.inf), 2 * radius + 1, axis=axis)
    return win.max(axis=-1)


def reach_floor(xs, Z: np.ndarray, p: Params) -> np.ndarray:
    """Plus basse position du CENTRE de bille pour laquelle le porte-outil, outil
    vertical, reste au-dessus de la matière voisine. Aucune inclinaison ne sauve
    un point plus profond : avec une sortie d'outil trop courte, il est hors de
    portée, et le dire vaut mieux que l'usiner dans le porte-outil."""
    step = xs[1] - xs[0] if len(xs) > 1 else 1.0
    radius = max(1, int(math.ceil((p.holder_radius + 1.0) / step)))
    top = np.where(np.isfinite(Z), Z - p.tool_dia / 2, -np.inf)
    around = _sliding_max(_sliding_max(top, radius, 0), radius, 1)
    return around - p.flute_length + 1.0


def _rough(xs, ys, Z_tip, min_tip, p: Params, z_safe: float, table_z: float) -> tuple[list[str], dict]:
    finite = np.isfinite(Z_tip)
    target = np.where(finite, Z_tip + p.stock_leave, -np.inf)
    # Sous cette hauteur, le porte-outil toucherait : la matière reste.
    target = np.maximum(target, min_tip)
    floor = max(float(target[np.isfinite(target)].min()), table_z + 0.2)
    dy = ys[1] - ys[0] if len(ys) > 1 else 1.0
    row_step = max(1, int(round(p.ae / dy)))
    n_layers = max(1, int(math.ceil(-floor / p.ap)))

    lines = ["G0 A0.000 C0.000", f"G0 X{f3(xs[0])} Y{f3(ys[0])}"]
    minutes = 0.0
    segments = 0
    z_now = z_safe
    x_now, y_now = float(xs[0]), float(ys[0])
    for k in range(1, n_layers + 1):
        z = max(-k * p.ap, floor)
        lines.append(f"(EBAUCHE COUCHE {k}/{n_layers} - Z{f3(z)})")
        forward = True
        last_ij = None
        for j in range(0, len(ys), row_step):
            cuttable = target[j] <= z + 1e-9
            if not cuttable.any():
                continue
            # Une passe = une suite CONTIGUË de points coupables : ce qui dépasse
            # entre deux suites reste debout.
            edges = np.flatnonzero(np.diff(np.concatenate(([0], cuttable.astype(int), [0]))))
            runs = list(zip(edges[::2], edges[1::2] - 1))
            if not forward:
                runs = [(b, a) for a, b in reversed(runs)]
            forward = not forward
            for start, end in runs:
                x0, x1 = float(xs[start]), float(xs[end])
                y = float(ys[j])
                stay = False
                if last_ij is not None and abs(z_now - z) < 1e-9:
                    lo, hi = sorted((last_ij[0], start))
                    # Rester en matière si tout le trajet est déjà à ce niveau.
                    stay = (last_ij[1] == j or last_ij[1] + row_step == j) and bool(
                        np.all(target[j, lo:hi + 1] <= z + 1e-9)
                        and np.all(target[last_ij[1], lo:hi + 1] <= z + 1e-9)
                    )
                if stay:
                    lines.append(f"G1 X{f3(x0)} Y{f3(y)} F{f3(p.feed_rough)}")
                    minutes += math.hypot(x0 - x_now, y - y_now) / p.feed_rough
                else:
                    jl, jh = sorted((last_ij[1] if last_ij else j, j))
                    il, ih = sorted((last_ij[0] if last_ij else start, start))
                    box = target[jl:jh + 1, il:ih + 1]
                    highest = float(box.max()) if box.size else z
                    hop = max(z + p.ap + 1.0, highest + 1.0)
                    hop = min(hop, 1.0)
                    if z_now < hop:
                        lines.append(f"G0 Z{f3(hop)}")
                        minutes += (hop - z_now) / MAX_RATE["Z"]
                    lines.append(f"G0 X{f3(x0)} Y{f3(y)}")
                    minutes += max(abs(x0 - x_now), abs(y - y_now)) / MAX_RATE["X"]
                    lines.append(f"G1 Z{f3(z)} F{f3(p.feed_plunge)}")
                    minutes += (hop - z) / p.feed_plunge
                if abs(x1 - x0) > 1e-9:
                    lines.append(f"G1 X{f3(x1)} Y{f3(y)} F{f3(p.feed_rough)}")
                    minutes += abs(x1 - x0) / p.feed_rough
                z_now, x_now, y_now = z, x1, y
                last_ij = (end, j)
                segments += 1
        lines.append("G0 Z1.000")
        minutes += (1.0 - z_now) / MAX_RATE["Z"]
        z_now = 1.0
        last_ij = None
    lines.append(f"G0 Z{f3(z_safe)}")
    return lines, {"couches": n_layers, "segments": segments, "duree_min": minutes, "z_fond": floor}


def _solve_angles(centres, normals, p: Params, c_start: float, cap: np.ndarray):
    """(A, C) continus le long d'une passe, cf. l'en-tête du module."""
    n = len(centres)
    h = np.hypot(normals[:, 0], normals[:, 1])
    tilt = np.degrees(np.arctan2(h, normals[:, 2]))
    tilt = np.minimum(np.clip(tilt - p.tilt_deadband, 0.0, p.tilt_max), cap)
    azim = np.degrees(np.arctan2(normals[:, 0], normals[:, 1]))
    if p.a_branch < 0:
        azim = azim + 180.0
    ds = np.linalg.norm(np.diff(centres, axis=0), axis=1) if n > 1 else np.zeros(0)

    # A : enveloppe sous la cible. L'inclinaison monte et descend progressivement.
    for i in range(1, n):
        tilt[i] = min(tilt[i], tilt[i - 1] + p.rate_a * ds[i - 1])
    for i in range(n - 2, -1, -1):
        tilt[i] = min(tilt[i], tilt[i + 1] + p.rate_a * ds[i])

    # C : là où l'outil est vertical, l'azimut ne veut rien dire, on le garde.
    c = np.empty(n)
    prev = c_start
    for i in range(n):
        target = azim[i] if tilt[i] > 1e-6 else prev
        while target - prev > 180.0:
            target -= 360.0
        while prev - target > 180.0:
            target += 360.0
        prev = target
        c[i] = target
    for i in range(1, n):
        c[i] = c[i - 1] + np.clip(c[i] - c[i - 1], -p.rate_c * ds[i - 1], p.rate_c * ds[i - 1])
    for i in range(n - 2, -1, -1):
        c[i] = c[i + 1] + np.clip(c[i] - c[i + 1], -p.rate_c * ds[i], p.rate_c * ds[i])
    return p.a_branch * tilt, c


def _tool_hits(centre, a, c, verts, p: Params) -> bool:
    """La queue ou le porte-outil touche-t-il la pièce ? Marge de 1 mm : le
    vérificateur, plus fin, ne doit pas trouver ce que ce test aurait raté."""
    rho = p.tool_dia / 2
    ax = tool_axis_in_piece(a, c)
    rel = verts - centre
    along = rel @ ax
    # |rel|² − along² = distance² à l'axe (ax unitaire) : évite un tableau N×3
    # temporaire à chacun des ~30 000 appels de _orient_safe.
    radial2 = np.einsum("ij,ij->i", rel, rel) - along * along
    flute = (along > rho) & (along < p.flute_length) & (radial2 < (rho + 0.5) ** 2)
    holder = (along >= p.flute_length - 1.0) & (along < p.flute_length + p.holder_length) & (
        radial2 < (p.holder_radius + 1.0) ** 2)
    return bool(flute.any() or holder.any())


def _orient_safe(centres, normals, p: Params, c_start: float, verts: np.ndarray):
    """Angles de la passe, redressés vers la verticale là où l'outil toucherait.
    Une fraise boule coupe pareil : on perd de l'inclinaison, pas de la précision."""
    n = len(centres)
    cap = np.full(n, p.tilt_max)
    spacing = float(np.median(np.linalg.norm(np.diff(centres, axis=0), axis=1))) if n > 1 else 1.0
    stride = max(1, int(round(0.5 / max(spacing, 1e-3))))
    a, c = _solve_angles(centres, normals, p, c_start, cap)
    for round_no in range(5):
        bad = [i for i in range(0, n, stride) if abs(a[i]) > 1e-6
               and _tool_hits(centres[i], a[i], c[i], verts, p)]
        if not bad:
            break
        for i in bad:
            lo, hi = max(0, i - 2 * stride), min(n, i + 2 * stride + 1)
            new = abs(a[i]) * 0.6 if round_no < 3 else 0.0
            cap[lo:hi] = np.minimum(cap[lo:hi], new)
        a, c = _solve_angles(centres, normals, p, c_start, cap)
    return a, c


def _simplify_row(z_row: np.ndarray, cols: np.ndarray, max_span: int, tol: float) -> list[int]:
    """Garde les colonnes nécessaires : la corde du centre de bille ne doit jamais
    passer sous la carte. Sur un flanc, les points se resserrent tout seuls."""
    n = len(cols)
    keep = [0]
    start = 0
    while start < n - 1:
        end = min(start + max_span, n - 1)
        while end > start + 1:
            k = np.arange(start + 1, end)
            chord = z_row[cols[start]] + (z_row[cols[end]] - z_row[cols[start]]) * (
                (k - start) / (end - start))
            if (z_row[cols[k]] - chord).max() <= tol:
                break
            end -= 1
        keep.append(end)
        start = end
    return keep


def _finish(xs, ys, Z, normals, triangles, p: Params, tr: Trunnion, z_safe: float, table_z: float):
    rho = p.tool_dia / 2
    dx = xs[1] - xs[0] if len(xs) > 1 else 1.0
    dy = ys[1] - ys[0] if len(ys) > 1 else 1.0
    row_step = max(1, int(round(p.stepover / dy)))
    col_step = max(1, int(round(p.stepover / dx)))
    valid = np.isfinite(Z) & (Z - rho >= table_z) & (Z >= reach_floor(xs, Z, p))
    verts = np.unique(np.round(triangles.reshape(-1, 3), 2), axis=0)
    if len(verts) > 16000:
        verts = verts[:: len(verts) // 16000]
    n_out_of_reach = int((np.isfinite(Z) & (Z < reach_floor(xs, Z, p))).sum())

    runs: list[list[tuple[int, int]]] = []
    current: list[tuple[int, int]] = []
    for row_i, j in enumerate(range(0, len(ys), row_step)):
        edges = np.flatnonzero(np.diff(np.concatenate(([0], valid[j].astype(int), [0]))))
        pieces = []
        for u, v in zip(edges[::2], edges[1::2]):
            # Un flanc quasi vertical : la corde mordrait la pièce, et la bille n'y
            # enlève rien d'utile. La passe s'arrête et reprend de l'autre côté.
            jumps = np.flatnonzero(np.abs(np.diff(Z[j, u:v])) > p.max_slope * dx) + 1
            pieces += [q for q in np.split(np.arange(u, v), jumps) if len(q) >= 2]
        if row_i % 2:
            pieces = [q[::-1] for q in reversed(pieces)]
        for cols in pieces:
            if len(cols) < 2:
                continue
            kept = [(int(cols[k]), j) for k in _simplify_row(Z[j], cols, col_step, p.chord_tol)]
            if current:
                pi, pj = current[-1]
                ni, nj = kept[0]
                link_ok = pi == ni and nj == pj + row_step
                if link_ok:
                    link_ok = abs(Z[nj, ni] - Z[pj, pi]) <= p.max_slope * (nj - pj) * dy
                if link_ok:
                    span = np.arange(pj + 1, nj)
                    chord = Z[pj, pi] + (Z[nj, ni] - Z[pj, pi]) * ((span - pj) / (nj - pj))
                    link_ok = bool(valid[span, pi].all()
                                   and (Z[span, pi] - chord).max(initial=-1.0) <= p.chord_tol)
                if not link_ok:
                    runs.append(current)
                    current = []
            current += kept
    if current:
        runs.append(current)

    lines: list[str] = []
    minutes = 0.0
    n_points = n_both = n_refined = n_passes = 0
    c_prev = 0.0
    a_seen = [0.0, 0.0]
    c_seen = [0.0, 0.0]
    drop = np.array([0.0, 0.0, rho])

    def tip(centre, a, c):
        return piece_to_machine(centre, a, c, tr) - drop

    def emit(c0, a0, c_0, c1, a1, c_1, depth=0):
        """Bloc de c0 à c1, coupé tant que la corde machine s'écarte de la pièce."""
        nonlocal minutes, n_both, n_refined
        if depth < 6 and abs(a1 - a0) + abs(c_1 - c_0) > 1e-9:
            cm, am, ccm = (c0 + c1) / 2, (a0 + a1) / 2, (c_0 + c_1) / 2
            mid_machine = (tip(c0, a0, c_0) + tip(c1, a1, c_1)) / 2 + drop
            if np.linalg.norm(machine_to_piece(mid_machine, am, ccm, tr) - cm) > p.chord_tol:
                n_refined += 1
                emit(c0, a0, c_0, cm, am, ccm, depth + 1)
                emit(cm, am, ccm, c1, a1, c_1, depth + 1)
                return
        m0, m1 = tip(c0, a0, c_0), tip(c1, a1, c_1)
        d = m1 - m0
        da, dc = a1 - a0, c_1 - c_0
        real = float(np.linalg.norm(c1 - c0))
        if real < 1e-6 and abs(da) + abs(dc) < 1e-6:
            return
        l_grbl = math.sqrt(float(d @ d) + da * da + dc * dc)
        # Durée visée, relevée par l'axe qui ne suit pas : F est écrit pour que
        # grbl tienne exactement cette durée malgré sa norme mm + degrés.
        t = max(
            real / p.v_surface,
            abs(d[0]) / MAX_RATE["X"], abs(d[1]) / MAX_RATE["Y"], abs(d[2]) / MAX_RATE["Z"],
            abs(da) / MAX_RATE["A"], abs(dc) / MAX_RATE["C"], 1e-6,
        )
        feed = min(l_grbl / t, p.feed_cap)
        minutes += l_grbl / feed
        if abs(da) > 1e-6 and abs(dc) > 1e-6:
            n_both += 1
        words = f"G1 X{f3(m1[0])} Y{f3(m1[1])} Z{f3(m1[2])}"
        if p.five_axis:
            words += f" A{f3(a1)} C{f3(c_1)}"
        lines.append(f"{words} F{f3(max(feed, 1.0))}")

    work = [r for r in runs if len(r) >= 2]
    while work:
        run = work.pop(0)
        ii = np.array([r[0] for r in run])
        jj = np.array([r[1] for r in run])
        centres = np.column_stack([xs[ii], ys[jj], Z[jj, ii]])
        c_start = ((c_prev + 180.0) % 360.0) - 180.0  # on rembobine à chaque dégagement
        if p.five_axis:
            a, c = _orient_safe(centres, normals[jj, ii], p, c_start, verts)
            over = np.flatnonzero(np.abs(c) > p.c_wind_max)
            if len(over) and over[0] >= 2:
                # C ferait trop de tours : dégagement, rembobinage, reprise au même point.
                work.insert(0, run[int(over[0]) - 1:])
                run = run[: int(over[0])]
                centres, a, c = centres[: len(run)], a[: len(run)], c[: len(run)]
        else:
            a, c = np.zeros(len(run)), np.zeros(len(run))
        c_prev = float(c[-1])
        a_seen = [min(a_seen[0], float(a.min())), max(a_seen[1], float(a.max()))]
        c_seen = [min(c_seen[0], float(c.min())), max(c_seen[1], float(c.max()))]

        m = tip(centres[0], a[0], c[0])
        lines.append(f"G0 Z{f3(z_safe)}")
        if p.five_axis:
            lines.append(f"G0 A{f3(a[0])} C{f3(c[0])}")
        lines.append(f"G0 X{f3(m[0])} Y{f3(m[1])}")
        lines.append(f"G1 Z{f3(m[2])} F{f3(p.feed_plunge)}")
        minutes += (z_safe - m[2]) / p.feed_plunge
        for k in range(1, len(run)):
            emit(centres[k - 1], float(a[k - 1]), float(c[k - 1]),
                 centres[k], float(a[k]), float(c[k]))
        n_points += len(run)
        n_passes += 1
    lines.append(f"G0 Z{f3(z_safe)}")
    if p.five_axis:
        lines.append("G0 A0.000 C0.000")
    return lines, {
        "points": n_points,
        "passes": n_passes,
        "hors_portee_pct": round(100.0 * n_out_of_reach / max(1, int(np.isfinite(Z).sum())), 1),
        "blocs_a_et_c_simultanes": n_both,
        "blocs_redecoupes": n_refined,
        "a_deg": a_seen,
        "c_deg": c_seen,
        "duree_min": minutes,
    }


def reachable_share(triangles: np.ndarray, xs, ys, Z, rho: float) -> float:
    """Part de la surface (en aire) que la bille touche par le dessus."""
    t = np.asarray(triangles)
    cross = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    area = 0.5 * np.linalg.norm(cross, axis=1)
    with np.errstate(invalid="ignore", divide="ignore"):
        n = cross / np.maximum(2 * area, 1e-12)[:, None]
    # L'orientation d'un maillage scanné n'est pas fiable : on essaie les deux.
    n = np.where(n[:, 2:3] < 0, -n, n)
    c = t.mean(axis=1) + rho * n
    floor = _bilinear(xs, ys, Z, c[:, 0], c[:, 1])
    touched = np.abs(floor - c[:, 2]) < max(0.1, 2 * (xs[1] - xs[0]) ** 2 / rho)
    total = float(area.sum())
    return float(area[touched].sum() / total) if total > 0 else 0.0


def toolpaths(triangles: np.ndarray, p: Params = Params()) -> Toolpaths:
    tris = np.asarray(triangles, dtype=float)
    tr, table_z = trunnion_for(tris, p)
    rho = p.tool_dia / 2
    z_safe = swept_safe_z(tris, tr, p.clearance) if p.five_axis else p.clearance
    fine = min(p.fine_step, p.stepover, p.ae)

    # Une seule carte, la plus fine, pour l'ébauche, la finition et le rejeu : c'est
    # le poste le plus coûteux du calcul. Elle déborde de la pièce de ρ pour l'ébauche.
    xs, ys, Z = height_map(tris, rho=rho, step=fine, margin=rho)
    if not np.isfinite(Z).any():
        raise ValueError("Aucun point de contact outil sur le maillage.")
    pts = tris.reshape(-1, 3)
    ci = (xs >= pts[:, 0].min() - 1e-9) & (xs <= pts[:, 0].max() + 1e-9)
    cj = (ys >= pts[:, 1].min() - 1e-9) & (ys <= pts[:, 1].max() + 1e-9)
    xs_f, ys_f, Z_f = xs[ci], ys[cj], Z[np.ix_(cj, ci)]
    normals = smooth_normals(xs_f, ys_f, Z_f, p.smooth_mm)

    k = max(1, int(round(min(p.stepover, p.ae) / fine)))
    min_tip = reach_floor(xs, Z, p)[::k, ::k] - rho
    rough, st_r = _rough(xs[::k], ys[::k], Z[::k, ::k] - rho, min_tip, p, z_safe, table_z)
    finish, st_f = _finish(xs_f, ys_f, Z_f, normals, tris, p, tr, z_safe, table_z)
    return Toolpaths(rough, finish, tr, z_safe, table_z, (xs, ys, Z), {
        "ebauche": st_r,
        "finition": st_f,
        "surface_atteinte_pct": round(100 * reachable_share(tris, xs_f, ys_f, Z_f, rho), 1),
        "pivot_sous_zero_mm": round(tr.pivot_to_table, 3),
        "z_securite": round(z_safe, 3),
    })


def program(tp: Toolpaths, p: Params, *, title: str = "SURFACE", spindle_on: bool = True) -> str:
    st_r, st_f = tp.stats["ebauche"], tp.stats["finition"]
    head = [
        f"(FORGERON - {title} - EBAUCHE 3 AXES + FINITION "
        f"{'5 AXES CONTINU' if p.five_axis else '3 AXES'})",
        f"(OUTIL : FRAISE BOULE DIAM {f3(p.tool_dia)} - AP {f3(p.ap)} AE {f3(p.ae)})",
        f"(FINITION : {st_f['points']} POINTS, A {f3(st_f['a_deg'][0])} A {f3(st_f['a_deg'][1])},"
        f" C {f3(st_f['c_deg'][0])} A {f3(st_f['c_deg'][1])})",
        f"(DUREE MINIMALE : {round(st_r['duree_min'])} MIN EBAUCHE +"
        f" {round(st_f['duree_min'])} MIN FINITION, ACCELERATIONS NON COMPTEES)",
        f"(SURFACE ATTEINTE PAR LE DESSUS : {tp.stats['surface_atteinte_pct']} POURCENT,"
        f" HORS DE PORTEE DE L OUTIL : {st_f['hors_portee_pct']} POURCENT)",
        "(COORDONNEES MACHINE COMPENSEES : FLUIDNC EST CARTESIEN, PAS DE RTCP)",
        f"(PIVOT A {f3(tp.trunnion.pivot_to_table)} MM SOUS LE ZERO PIECE, SUR L AXE C)",
        "G21 G90 G94 G17 G40",
        "G54",
        "M5",
        f"G0 Z{f3(tp.z_safe)}",
        "M0 (A0 C0 : G54 X Y SUR L AXE C, Z SUR LE DESSUS DU BRUT. VERIFIER OUTIL ET BRIDAGE)",
    ]
    if spindle_on:
        head += [
            f"M3 S{p.spindle}",
            "G4 P1 (MONTEE EN REGIME 1 SUR 3)",
            "G4 P1 (MONTEE EN REGIME 2 SUR 3)",
            "G4 P1 (MONTEE EN REGIME 3 SUR 3)",
        ]
    else:
        head.append("(ESSAI A VIDE : BROCHE COUPEE, SANS OUTIL NI PIECE)")
    tail = [f"G0 Z{f3(tp.z_safe)}", "M5", "M30"]
    lines = (head + ["(=== ETAPE 1 : EBAUCHE ===)"] + tp.rough
             + ["(=== ETAPE 2 : FINITION ===)"] + tp.finish + tail)
    return "\n".join(lines) + "\n"


def checked_program(
    triangles: np.ndarray,
    p: Params = Params(),
    *,
    fit_travel: bool = False,
    title: str = "SURFACE",
    spindle_on: bool = True,
) -> tuple[Toolpaths, str, dict, np.ndarray, float]:
    """Génère PUIS rejoue. Avec [fit_travel], réduit la pièce tant que l'excursion
    réelle, rotations comprises, dépasse les courses — et le dit via le facteur."""
    tris = np.asarray(triangles, dtype=float)
    factor = 1.0
    for _ in range(3):
        tp = toolpaths(tris, p)
        gcode = program(tp, p, title=title, spindle_on=spindle_on)
        check = verify(gcode, tris, tp.trunnion, tool_dia=p.tool_dia, table_z=tp.table_z,
                       v_target=p.v_surface, flute_length=p.flute_length,
                       holder_radius=p.holder_radius, holder_length=p.holder_length,
                       height_field=tp.field)
        if check["excursion_tient"] or not fit_travel:
            break
        ratio = 0.97 * min(TRAVEL[k] / max(check["excursion_mm"][k], 1e-6) for k in TRAVEL)
        tris = tris * ratio
        factor *= ratio
    return tp, gcode, check, tris, factor


def main() -> int:
    import argparse

    from medical_implant import prepare_implant_mesh, read_3d_file
    from stl_io import write_stl

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="STEP/STL -> programme 5 axes continu, vérifié.")
    ap.add_argument("fichier")
    ap.add_argument("-o", "--sortie")
    ap.add_argument("--outil", type=float, default=6.0)
    ap.add_argument("--ap", type=float, default=0.2)
    ap.add_argument("--ae", type=float, default=0.5)
    ap.add_argument("--stepover", type=float, default=0.5)
    ap.add_argument("--vitesse", type=float, default=150.0, help="avance visée sur la pièce")
    ap.add_argument("--cale", type=float, default=0.0, help="épaisseur sous la pièce (mm)")
    ap.add_argument("--inclinaison-max", type=float, default=45.0)
    ap.add_argument("--sans-reorientation", action="store_true")
    ap.add_argument("--echelle-auto", action="store_true",
                    help="réduire la pièce pour tenir dans les courses (sinon : refus)")
    ap.add_argument("--a-vide", action="store_true", help="essai à vide : broche jamais allumée")
    ap.add_argument("--trois-axes", action="store_true")
    args = ap.parse_args()

    p = Params(tool_dia=args.outil, ap=args.ap, ae=args.ae, stepover=args.stepover,
               v_surface=args.vitesse, under_part=args.cale, tilt_max=args.inclinaison_max,
               five_axis=not args.trois_axes)
    try:
        prep = prepare_implant_mesh(read_3d_file(args.fichier),
                                    auto_orient=not args.sans_reorientation,
                                    auto_fit=args.echelle_auto)
        tp, gcode, check, tris, factor = checked_program(
            prep.triangles, p, fit_travel=args.echelle_auto, spindle_on=not args.a_vide)
    except ValueError as exc:
        print(f"REFUS : {exc}")
        return 1

    base = args.fichier.rsplit(".", 1)[0]
    write_stl(base + "_5x_prepare.stl", tris, header="forgeron-5x")
    safe = is_safe(check)
    out = args.sortie or base + "_5x.nc"
    if not safe:
        out = out.rsplit(".", 1)[0] + "_REFUSE.nc.txt"
    Path(out).write_text(gcode, encoding="utf-8")
    size = tris.reshape(-1, 3).max(axis=0) - tris.reshape(-1, 3).min(axis=0)
    report = {"gcode_path": out, "valide": safe, "echelle": round(prep.scale_factor * factor, 5),
              "dimensions_mm": [round(float(v), 3) for v in size], "notes": prep.notes,
              **tp.stats, "verification": check}
    Path(base + "_5x_rapport.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if not safe:
        print("REFUS : le rejeu du programme a échoué, il n'est pas exécutable (voir verification).")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
