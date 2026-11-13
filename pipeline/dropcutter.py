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

── Accélération Numba (multi-cœur LLVM) ────────────────────────────────────

Lorsque `numba` est disponible (cas de `pipeline/.venv312`), le balayage est
compilé en code machine natif parallélisé par lignes (`prange` sans conflit
d'écriture) avec élagage spatial et Z-culling. En l'absence de `numba`, le
moteur bascule de façon transparente sur l'implémentation NumPy vectorisée.
"""

from __future__ import annotations

import math

import numpy as np

try:
    from numba import njit, prange

    _HAS_NUMBA = True
except ImportError:  # pragma: no cover — repli NumPy pur (ex. Python 3.15)
    _HAS_NUMBA = False


# ── Noyau NumPy pur (référence + repli) ─────────────────────────────────────


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
    """Hauteur du centre en contact avec une ARÊTE (segment p→q)."""
    e = q - p
    ee = e @ e
    if ee < 1e-18:
        return np.full(gx.shape, -np.inf)

    wx, wy = gx - p[0], gy - p[1]
    ex, ey, ez = e
    k = wx * ex + wy * ey
    m = wx * wx + wy * wy
    A = 1.0 - ez * ez / ee
    B = -2.0 * k * ez / ee
    C = m - k * k / ee - rho * rho

    out = np.full(gx.shape, -np.inf)
    if abs(A) < 1e-12:
        return out
    disc = B * B - 4 * A * C
    ok = disc >= 0
    if not np.any(ok):
        return out
    s = (-B + np.sqrt(np.maximum(disc, 0.0))) / (2 * A)
    z = p[2] + s

    t = (k + s * ez) / ee
    valid = ok & (t >= 0.0) & (t <= 1.0)
    return np.where(valid, z, -np.inf)


def _height_map_numpy(
    tris: np.ndarray,
    xs: np.ndarray,
    ys: np.ndarray,
    rho: float,
    tlo_all: np.ndarray,
    thi_all: np.ndarray,
    i0_all: np.ndarray,
    i1_all: np.ndarray,
    j0_all: np.ndarray,
    j1_all: np.ndarray,
) -> np.ndarray:
    Z = np.full((len(ys), len(xs)), -np.inf)
    for idx, tri in enumerate(tris):
        i0 = int(i0_all[idx])
        i1 = int(i1_all[idx])
        j0 = int(j0_all[idx])
        j1 = int(j1_all[idx])
        if i0 >= i1 or j0 >= j1:
            continue

        sub_z = Z[j0:j1, i0:i1]
        if thi_all[idx, 2] <= sub_z.min():
            continue

        gx, gy = np.broadcast_arrays(xs[None, i0:i1], ys[j0:j1, None])
        best = _face_contact(tri, gx, gy, rho)
        for k in range(3):
            best = np.maximum(best, _vertex_contact(tri[k], gx, gy, rho))
            best = np.maximum(
                best, _edge_contact(tri[k], tri[(k + 1) % 3], gx, gy, rho)
            )
        Z[j0:j1, i0:i1] = np.maximum(sub_z, best)
    return Z


# ── Noyau Numba multi-cœur (code machine natif LLVM) ────────────────────────


if _HAS_NUMBA:

    @njit(cache=True, fastmath=True)
    def _tri_z_at(
        ax: float, ay: float, az: float,
        bx: float, by: float, bz: float,
        cx: float, cy: float, cz: float,
        # Données pré-calculées de face
        face_ok: bool,
        nx: float, ny: float, nz: float,
        a2x: float, a2y: float,
        v0x: float, v0y: float,
        v1x: float, v1y: float,
        d11: float, d01: float, d00: float, inv_den: float,
        face_k: float,
        # Rayon sphère
        gx: float, gy: float, rho: float, rho2: float,
    ) -> float:
        best = -np.inf

        # 1. Contact FACE
        if face_ok:
            px = gx - a2x
            py = gy - a2y
            d20 = px * v0x + py * v0y
            d21 = px * v1x + py * v1y
            u = (d11 * d20 - d01 * d21) * inv_den
            v = (d00 * d21 - d01 * d20) * inv_den
            if u >= -1e-9 and v >= -1e-9 and (u + v) <= 1.0 + 1e-9:
                zf = (face_k - nx * gx - ny * gy) / nz
                if zf > best:
                    best = zf

        # 2. Contact SOMMETS (3)
        d2 = (gx - ax) * (gx - ax) + (gy - ay) * (gy - ay)
        if d2 <= rho2:
            zv = az + math.sqrt(max(rho2 - d2, 0.0))
            if zv > best:
                best = zv

        d2 = (gx - bx) * (gx - bx) + (gy - by) * (gy - by)
        if d2 <= rho2:
            zv = bz + math.sqrt(max(rho2 - d2, 0.0))
            if zv > best:
                best = zv

        d2 = (gx - cx) * (gx - cx) + (gy - cy) * (gy - cy)
        if d2 <= rho2:
            zv = cz + math.sqrt(max(rho2 - d2, 0.0))
            if zv > best:
                best = zv

        # 3. Contact ARÊTES (3)
        # Arête A -> B
        ex, ey, ez = bx - ax, by - ay, bz - az
        ee = ex * ex + ey * ey + ez * ez
        if ee >= 1e-18:
            A = 1.0 - ez * ez / ee
            if abs(A) >= 1e-12:
                wx, wy = gx - ax, gy - ay
                k = wx * ex + wy * ey
                m = wx * wx + wy * wy
                B = -2.0 * k * ez / ee
                C = m - k * k / ee - rho2
                disc = B * B - 4.0 * A * C
                if disc >= 0.0:
                    s = (-B + math.sqrt(disc)) / (2.0 * A)
                    t = (k + s * ez) / ee
                    if 0.0 <= t <= 1.0:
                        ze = az + s
                        if ze > best:
                            best = ze

        # Arête B -> C
        ex, ey, ez = cx - bx, cy - by, cz - bz
        ee = ex * ex + ey * ey + ez * ez
        if ee >= 1e-18:
            A = 1.0 - ez * ez / ee
            if abs(A) >= 1e-12:
                wx, wy = gx - bx, gy - by
                k = wx * ex + wy * ey
                m = wx * wx + wy * wy
                B = -2.0 * k * ez / ee
                C = m - k * k / ee - rho2
                disc = B * B - 4.0 * A * C
                if disc >= 0.0:
                    s = (-B + math.sqrt(disc)) / (2.0 * A)
                    t = (k + s * ez) / ee
                    if 0.0 <= t <= 1.0:
                        ze = bz + s
                        if ze > best:
                            best = ze

        # Arête C -> A
        ex, ey, ez = ax - cx, ay - cy, az - cz
        ee = ex * ex + ey * ey + ez * ez
        if ee >= 1e-18:
            A = 1.0 - ez * ez / ee
            if abs(A) >= 1e-12:
                wx, wy = gx - cx, gy - cy
                k = wx * ex + wy * ey
                m = wx * wx + wy * wy
                B = -2.0 * k * ez / ee
                C = m - k * k / ee - rho2
                disc = B * B - 4.0 * A * C
                if disc >= 0.0:
                    s = (-B + math.sqrt(disc)) / (2.0 * A)
                    t = (k + s * ez) / ee
                    if 0.0 <= t <= 1.0:
                        ze = cz + s
                        if ze > best:
                            best = ze

        return best

    @njit(parallel=True, cache=True, fastmath=True)
    def _height_map_numba(
        tris: np.ndarray,
        xs: np.ndarray,
        ys: np.ndarray,
        rho: float,
        zmax_all: np.ndarray,
        i0_all: np.ndarray,
        i1_all: np.ndarray,
        j0_all: np.ndarray,
        j1_all: np.ndarray,
    ) -> np.ndarray:
        ny = len(ys)
        nx_grid = len(xs)
        n_tris = len(tris)
        rho2 = rho * rho
        Z = np.full((ny, nx_grid), -np.inf)

        # Pré-calcul des constantes de face par triangle (parallélisé)
        face_ok = np.zeros(n_tris, dtype=np.bool_)
        fn = np.zeros((n_tris, 3), dtype=np.float64)
        fa2 = np.zeros((n_tris, 2), dtype=np.float64)
        fv0 = np.zeros((n_tris, 2), dtype=np.float64)
        fv1 = np.zeros((n_tris, 2), dtype=np.float64)
        fdot = np.zeros((n_tris, 4), dtype=np.float64)  # d11, d01, d00, inv_den
        fk = np.zeros(n_tris, dtype=np.float64)

        for t in prange(n_tris):
            if i0_all[t] >= i1_all[t] or j0_all[t] >= j1_all[t]:
                continue
            ax, ay, az = tris[t, 0, 0], tris[t, 0, 1], tris[t, 0, 2]
            bx, by, bz = tris[t, 1, 0], tris[t, 1, 1], tris[t, 1, 2]
            cx, cy, cz = tris[t, 2, 0], tris[t, 2, 1], tris[t, 2, 2]

            abx, aby, abz = bx - ax, by - ay, bz - az
            acx, acy, acz = cx - ax, cy - ay, cz - az
            nx = aby * acz - abz * acy
            ny_v = abz * acx - abx * acz
            nz = abx * acy - aby * acx
            norm = math.sqrt(nx * nx + ny_v * ny_v + nz * nz)
            if norm < 1e-12:
                continue
            nx /= norm
            ny_v /= norm
            nz /= norm
            if nz < 0.0:
                nx = -nx
                ny_v = -ny_v
                nz = -nz
            if abs(nz) < 1e-9:
                continue

            a2x = ax + rho * nx
            a2y = ay + rho * ny_v
            b2x = bx + rho * nx
            b2y = by + rho * ny_v
            c2x = cx + rho * nx
            c2y = cy + rho * ny_v

            v0x, v0y = b2x - a2x, b2y - a2y
            v1x, v1y = c2x - a2x, c2y - a2y
            d00 = v0x * v0x + v0y * v0y
            d01 = v0x * v1x + v0y * v1y
            d11 = v1x * v1x + v1y * v1y
            den = d00 * d11 - d01 * d01
            if abs(den) < 1e-12:
                continue

            face_ok[t] = True
            fn[t, 0] = nx
            fn[t, 1] = ny_v
            fn[t, 2] = nz
            fa2[t, 0] = a2x
            fa2[t, 1] = a2y
            fv0[t, 0] = v0x
            fv0[t, 1] = v0y
            fv1[t, 0] = v1x
            fv1[t, 1] = v1y
            fdot[t, 0] = d11
            fdot[t, 1] = d01
            fdot[t, 2] = d00
            fdot[t, 3] = 1.0 / den
            fk[t] = rho + nx * ax + ny_v * ay + nz * az

        # Parallélisation par ligne j : zéro conflit d'écriture sur Z[j, :]
        for j in prange(ny):
            gy = ys[j]
            for t in range(n_tris):
                if j < j0_all[t] or j >= j1_all[t]:
                    continue
                i0 = i0_all[t]
                i1 = i1_all[t]
                if i0 >= i1:
                    continue
                zmax_t = zmax_all[t]

                ax, ay, az = tris[t, 0, 0], tris[t, 0, 1], tris[t, 0, 2]
                bx, by, bz = tris[t, 1, 0], tris[t, 1, 1], tris[t, 1, 2]
                cx, cy, cz = tris[t, 2, 0], tris[t, 2, 1], tris[t, 2, 2]
                fok = face_ok[t]
                nx = fn[t, 0]
                ny_v = fn[t, 1]
                nz = fn[t, 2]
                a2x = fa2[t, 0]
                a2y = fa2[t, 1]
                v0x = fv0[t, 0]
                v0y = fv0[t, 1]
                v1x = fv1[t, 0]
                v1y = fv1[t, 1]
                d11 = fdot[t, 0]
                d01 = fdot[t, 1]
                d00 = fdot[t, 2]
                inv_den = fdot[t, 3]
                face_k = fk[t]

                for i in range(i0, i1):
                    if zmax_t <= Z[j, i]:
                        continue
                    z = _tri_z_at(
                        ax, ay, az, bx, by, bz, cx, cy, cz,
                        fok, nx, ny_v, nz,
                        a2x, a2y, v0x, v0y, v1x, v1y,
                        d11, d01, d00, inv_den, face_k,
                        xs[i], gy, rho, rho2,
                    )
                    if z > Z[j, i]:
                        Z[j, i] = z

        return Z


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
    tris = np.ascontiguousarray(triangles, dtype=np.float64)
    if tris.ndim != 3 or tris.shape[1:] != (3, 3):
        raise ValueError("triangles doit avoir la forme (n, 3, 3)")

    lo = tris.reshape(-1, 3).min(axis=0) - margin
    hi = tris.reshape(-1, 3).max(axis=0) + margin
    xs = np.arange(lo[0], hi[0] + step, step, dtype=np.float64)
    ys = np.arange(lo[1], hi[1] + step, step, dtype=np.float64)

    tlo_all = tris.min(axis=1) - rho
    thi_all = tris.max(axis=1) + rho
    i0_all = np.searchsorted(xs, tlo_all[:, 0], "left")
    i1_all = np.searchsorted(xs, thi_all[:, 0], "right")
    j0_all = np.searchsorted(ys, tlo_all[:, 1], "left")
    j1_all = np.searchsorted(ys, thi_all[:, 1], "right")

    if _HAS_NUMBA:
        Z = _height_map_numba(
            tris,
            xs,
            ys,
            float(rho),
            np.ascontiguousarray(thi_all[:, 2], dtype=np.float64),
            np.ascontiguousarray(i0_all, dtype=np.int64),
            np.ascontiguousarray(i1_all, dtype=np.int64),
            np.ascontiguousarray(j0_all, dtype=np.int64),
            np.ascontiguousarray(j1_all, dtype=np.int64),
        )
    else:
        Z = _height_map_numpy(
            tris, xs, ys, float(rho), tlo_all, thi_all, i0_all, i1_all, j0_all, j1_all
        )

    return xs, ys, Z
