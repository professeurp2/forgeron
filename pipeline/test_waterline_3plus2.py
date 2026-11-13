"""Tests des nouveaux moteurs Waterline / HSM (pyclipper) & 3+2 multi-vues."""

from __future__ import annotations

import math
import numpy as np

from continuous5 import Params, f3, swept_safe_z, trunnion_for
from multi_axis_3plus2 import (
    DEFAULT_3PLUS2_VIEWS,
    IndexedView,
    analyze_view_coverage,
    generate_indexed_pass,
)
from verify5 import is_safe, verify
from waterline import (
    adaptive_contour_roughing,
    offset_loops,
    slice_mesh_z,
    waterline_paths,
)


def _cylinder_mesh(radius: float = 10.0, height: float = 10.0, n_seg: int = 48) -> np.ndarray:
    """Cylindre fermé de Z=-height à Z=0, centré en (0, 0)."""
    angles = np.linspace(0, 2 * math.pi, n_seg, endpoint=False)
    tris = []
    for k in range(n_seg):
        a0, a1 = angles[k], angles[(k + 1) % n_seg]
        x0, y0 = radius * math.cos(a0), radius * math.sin(a0)
        x1, y1 = radius * math.cos(a1), radius * math.sin(a1)
        # Paroi latérale
        tris.append([[x0, y0, 0.0], [x1, y1, 0.0], [x1, y1, -height]])
        tris.append([[x0, y0, 0.0], [x1, y1, -height], [x0, y0, -height]])
        # Dessus (Z=0) et fond (Z=-height)
        tris.append([[0.0, 0.0, 0.0], [x0, y0, 0.0], [x1, y1, 0.0]])
        tris.append([[0.0, 0.0, -height], [x1, y1, -height], [x0, y0, -height]])
    return np.asarray(tris, dtype=np.float64)


def _sphere_cap_mesh(radius: float = 12.0, n_u: int = 36, n_v: int = 24) -> np.ndarray:
    """Calotte sphérique avec contre-dépouille (jusqu'à 115° depuis le pôle)."""
    phis = np.linspace(0.0, math.radians(115.0), n_v)
    thetas = np.linspace(0.0, 2 * math.pi, n_u, endpoint=False)
    tris = []
    for j in range(n_v - 1):
        p0, p1 = phis[j], phis[j + 1]
        for i in range(n_u):
            t0, t1 = thetas[i], thetas[(i + 1) % n_u]
            def pt(phi, th):
                return [
                    radius * math.sin(phi) * math.cos(th),
                    radius * math.sin(phi) * math.sin(th),
                    radius * math.cos(phi) - radius,
                ]
            a, b, c, d = pt(p0, t0), pt(p0, t1), pt(p1, t1), pt(p1, t0)
            tris.append([a, c, b])
            tris.append([a, d, c])
    arr = np.asarray(tris, dtype=np.float64)
    arr[:, :, 2] -= arr[:, :, 2].max()
    return arr


def test_slice_and_waterline_cylinder():
    cyl = _cylinder_mesh(radius=10.0, height=6.0)
    loops = slice_mesh_z(cyl, z_level=-3.0)
    assert len(loops) == 1
    radii = np.hypot(loops[0][:, 0], loops[0][:, 1])
    assert np.allclose(radii, 10.0, atol=0.05)

    # Décalage par fraise Ø6 (rho = 3.0) -> rayon attendu = 13.0 mm
    off = offset_loops(loops, delta_mm=3.0)
    assert len(off) == 1
    off_radii = np.hypot(off[0][:, 0], off[0][:, 1])
    assert np.allclose(off_radii, 13.0, atol=0.05)

    wl = waterline_paths(cyl, tool_dia=6.0, ap=1.5, z_top=0.0, z_bottom=-6.0)
    assert len(wl) == 4


def test_adaptive_contour_roughing_respects_island():
    cyl = _cylinder_mesh(radius=8.0, height=2.0)
    layers = adaptive_contour_roughing(
        cyl, tool_dia=6.0, ap=0.5, ae=0.5, stock_margin=4.0, stock_leave=0.3, z_top=0.0, z_bottom=-2.0
    )
    assert len(layers) == 4
    # Aucun point d'ébauche ne doit pénétrer l'îlot dilaté (8.0 + 3.0 + 0.3 = 11.3 mm)
    for _, paths in layers:
        assert len(paths) >= 1
        for p in paths:
            r = np.hypot(p[:, 0], p[:, 1])
            assert np.all(r >= 11.25), f"intrusion dans l'îlot: min r={r.min():.3f}"


def test_3plus2_coverage_and_safety():
    tris = _sphere_cap_mesh(radius=12.0)
    p = Params(tool_dia=6.0, stepover=1.0, fine_step=0.5, v_surface=150.0)
    tr, table_z = trunnion_for(tris, p)

    cov = analyze_view_coverage(tris, tr, p, views=DEFAULT_3PLUS2_VIEWS)
    assert len(cov) == 5
    # La vue (0, 0) seule ne couvre pas les contre-dépouilles (>68°),
    # les vues inclinées (-45°) doivent débloquer de nouveaux triangles.
    assert cov[0]["nouveaux_triangles_debloques"] > 0
    assert cov[-1]["couverture_cumulee_pct"] > cov[0]["couverture_cumulee_pct"]

    z_safe = swept_safe_z(tris, tr, p.clearance)
    view = IndexedView(-45.0, 0.0, "face_avant")
    lines = generate_indexed_pass(tris, tr, view, p, z_safe_machine=z_safe, table_z=table_z)
    gcode = f"G90 G21\nG0 X0 Y0 Z{f3(z_safe)} A0 C0\n" + "\n".join(lines) + f"\nG0 Z{f3(z_safe)}\nM2\n"

    rep = verify(gcode, tris, tr, tool_dia=p.tool_dia, table_z=table_z)
    assert is_safe(rep), f"Pénétration détectée sur la vue 3+2 : {rep}"
