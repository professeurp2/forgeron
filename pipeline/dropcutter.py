"""Carte de hauteur d'une fraise BOULE au-dessus d'un maillage quelconque.

C'est le cœur d'un CAM 3 axes, et il ne suppose aucune forme : ni révolution,
ni symétrie, ni surface analytique. N'importe quel STL passe.

── Le problème ─────────────────────────────────────────────────────────────

Pour chaque position (x, y), on cherche la hauteur la plus BASSE que le centre
de la bille peut atteindre sans qu'aucun triangle ne pénètre dans la sphère.
Autrement dit, la bille « tombe » verticalement jusqu'à toucher la pièce —
d'où le nom.

    z_centre(x, y) = max sur tous les triangles de  z_contact(triangle)

Le maximum, car il suffit qu'UN triangle bloque la descente.

── Les trois façons de toucher ─────────────────────────────────────────────

Une sphère qui descend sur un triangle le touche par sa FACE, par une ARÊTE ou
par un SOMMET. Les trois cas doivent être traités : n'en garder qu'un laisse
l'outil pénétrer la matière aux endroits que ce cas ne couvre pas.

  FACE   — le centre se projette dans le triangle. La sphère touche le plan
           quand n·(C − p₀) = ρ, d'où  z = (ρ + n·p₀ − nₓx − n_yy) / n_z.
  SOMMET — |C − v| = ρ, d'où  z = v_z + √(ρ² − (x−vₓ)² − (y−v_y)²).
  ARÊTE  — même chose sur le cylindre d'axe l'arête et de rayon ρ.

── Coût ────────────────────────────────────────────────────────────────────

Plutôt que d'interroger tous les triangles pour chaque point de grille, on
parcourt les triangles une fois et on met à jour, pour chacun, les seuls points
de grille situés dans sa boîte englobante élargie de ρ. On passe d'un produit
(points × triangles) à une somme de petites mises à jour vectorisées.
"""

from __future__ import annotations

import numpy as np


def _face_contact(
    tri: np.ndarray, gx: np.ndarray, gy: np.ndarray, rho: float
) -> np.ndarray:
    """Hauteur du centre en contact avec la FACE, ou -inf hors du triangle."""
    a, b, c = tri
    n = np.cross(b - a, c - a)
    norm = np.linalg.norm(n)
    if norm < 1e-12:
        return np.full(gx.shape, -np.inf)  # triangle dégénéré
    n = n / norm
    if n[2] < 0:
        n = -n  # normale vers le haut : c'est de là que vient l'outil
    if abs(n[2]) < 1e-9:
        return np.full(gx.shape, -np.inf)  # face verticale : jamais de contact facial

    # Le contact facial n'est valide que si le centre se projette DANS le
    # triangle, décalé de ρ·n. On teste l'appartenance en coordonnées
    # barycentriques, sur la projection XY du triangle décalé.
    a2, b2, c2 = (a + rho * n)[:2], (b + rho * n)[:2], (c + rho * n)[:2]
    v0, v1 = b2 - a2, c2 - a2
    d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-12:
        return np.full(gx.shape, -np.inf)

    px, py = gx - a2[0], gy - a2[1]
    d20 = px * v0[0] + py * v0[1]
    d21 = px * v1[0] + py * v1[1]
    u = (d11 * d20 - d01 * d21) / den
    v = (d00 * d21 - d01 * d20) / den
    inside = (u >= -1e-9) & (v >= -1e-9) & (u + v <= 1 + 1e-9)

    z = (rho + n @ a - n[0] * gx - n[1] * gy) / n[2]
    return np.where(inside, z, -np.inf)


def _vertex_contact(
    v: np.ndarray, gx: np.ndarray, gy: np.ndarray, rho: float
) -> np.ndarray:
    """Hauteur du centre en contact avec un SOMMET."""
    d2 = (gx - v[0]) ** 2 + (gy - v[1]) ** 2
    reach = rho * rho - d2
    return np.where(reach >= 0, v[2] + np.sqrt(np.maximum(reach, 0.0)), -np.inf)


def _edge_contact(
    p: np.ndarray, q: np.ndarray, gx: np.ndarray, gy: np.ndarray, rho: float
) -> np.ndarray:
    """Hauteur du centre en contact avec une ARÊTE (segment p→q).

    Le centre est à distance ρ de la droite portant l'arête. On résout dans le
    repère de l'arête : la composante du centre le long de l'arête donne le
    point le plus proche, et la distance perpendiculaire doit valoir ρ.
    """
    e = q - p
    ee = e @ e
    if ee < 1e-18:
        return np.full(gx.shape, -np.inf)

    # Centre C = (gx, gy, z). On cherche z tel que dist(C, droite) = ρ, en
    # gardant la plus grande racine (la bille pose par le dessus).
    wx, wy = gx - p[0], gy - p[1]
    # Coefficients du polynôme en z, obtenus en développant |w − (w·e/ee)e|² = ρ².
    # w = (wx, wy, z − p_z) ; on note s = z − p_z.
    ex, ey, ez = e
    # w·e = wx·ex + wy·ey + s·ez
    k = wx * ex + wy * ey
    # |w|² = wx² + wy² + s²
    m = wx * wx + wy * wy
    # |w|² − (w·e)²/ee = ρ²
    #  → (1 − ez²/ee)s² − 2·k·ez/ee·s + (m − k²/ee − ρ²) = 0
    A = 1.0 - ez * ez / ee
    B = -2.0 * k * ez / ee
    C = m - k * k / ee - rho * rho

    out = np.full(gx.shape, -np.inf)
    if abs(A) < 1e-12:
        # Arête verticale : traitée par les contacts de sommet.
        return out
    disc = B * B - 4 * A * C
    ok = disc >= 0
    if not np.any(ok):
        return out
    s = (-B + np.sqrt(np.maximum(disc, 0.0))) / (2 * A)
    z = p[2] + s

    # Le point de contact doit tomber DANS le segment, pas sur son prolongement.
    t = (k + s * ez) / ee
    valid = ok & (t >= 0.0) & (t <= 1.0)
    return np.where(valid, z, -np.inf)


def height_map(
    triangles: np.ndarray,
    rho: float,
    step: float,
    margin: float = 0.0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Hauteur du CENTRE de la bille sur une grille XY régulière.

    Retourne (xs, ys, Z) où Z[j, i] correspond à (xs[i], ys[j]). Les points
    qu'aucun triangle n'atteint valent -inf : c'est au générateur de parcours
    de décider quoi en faire (typiquement, le plan du brut).
    """
    tris = np.asarray(triangles, dtype=float)
    if tris.ndim != 3 or tris.shape[1:] != (3, 3):
        raise ValueError("triangles doit avoir la forme (n, 3, 3)")

    lo = tris.reshape(-1, 3).min(axis=0) - margin
    hi = tris.reshape(-1, 3).max(axis=0) + margin
    xs = np.arange(lo[0], hi[0] + step, step)
    ys = np.arange(lo[1], hi[1] + step, step)
    Z = np.full((len(ys), len(xs)), -np.inf)

    for tri in tris:
        # Seuls les points de grille sous l'influence de ce triangle.
        tlo = tri.min(axis=0) - rho
        thi = tri.max(axis=0) + rho
        i0 = int(np.searchsorted(xs, tlo[0], "left"))
        i1 = int(np.searchsorted(xs, thi[0], "right"))
        j0 = int(np.searchsorted(ys, tlo[1], "left"))
        j1 = int(np.searchsorted(ys, thi[1], "right"))
        if i0 >= i1 or j0 >= j1:
            continue

        gx, gy = np.meshgrid(xs[i0:i1], ys[j0:j1])
        best = _face_contact(tri, gx, gy, rho)
        for k in range(3):
            best = np.maximum(best, _vertex_contact(tri[k], gx, gy, rho))
            best = np.maximum(
                best, _edge_contact(tri[k], tri[(k + 1) % 3], gx, gy, rho)
            )
        Z[j0:j1, i0:i1] = np.maximum(Z[j0:j1, i0:i1], best)

    return xs, ys, Z
