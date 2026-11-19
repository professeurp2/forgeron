"""Vérifie le 5 axes continu par REJEU du G-code (`verify5`), jamais par ce que
le générateur croit avoir fait.

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_continuous5.py
"""

from __future__ import annotations

import numpy as np

from continuous5 import Params, program, toolpaths, trunnion_for
from kinematics import Trunnion, machine_to_piece, orient, piece_to_machine
from verify5 import _centres_in_piece, is_safe, parse_moves, verify

_ok = True


def chk(label: str, cond: bool, detail: str = "") -> None:
    global _ok
    _ok &= bool(cond)
    print(f"  {'OK  ' if cond else 'ECHEC'} {label}" + (f"  — {detail}" if detail else ""))


def surface(fn, half_x: float, half_y: float, n: int = 90) -> np.ndarray:
    """Dessus z=fn(x,y) fermé par un fond plat ; le sommet est ramené à Z=0."""
    xs, ys = np.linspace(-half_x, half_x, n), np.linspace(-half_y, half_y, n)
    gx, gy = np.meshgrid(xs, ys)
    gz = fn(gx, gy)
    gz = gz - gz.max()
    bottom = gz.min() - 2.0
    tris = []
    for j in range(n - 1):
        for i in range(n - 1):
            a = [gx[j, i], gy[j, i], gz[j, i]]
            b = [gx[j, i + 1], gy[j, i + 1], gz[j, i + 1]]
            c = [gx[j + 1, i + 1], gy[j + 1, i + 1], gz[j + 1, i + 1]]
            d = [gx[j + 1, i], gy[j + 1, i], gz[j + 1, i]]
            tris += [[a, b, c], [a, c, d]]
    c = [[-half_x, -half_y], [half_x, -half_y], [half_x, half_y], [-half_x, half_y]]
    tris += [[[*c[0], bottom], [*c[2], bottom], [*c[1], bottom]],
             [[*c[0], bottom], [*c[3], bottom], [*c[2], bottom]]]
    return np.array(tris)


def dome(R: float = 20.0):
    return lambda x, y: np.sqrt(np.maximum(R * R - x * x - y * y, 0.0))


FAST = Params(ap=1.0, ae=1.5, stepover=0.8, v_surface=150.0)


def run(tris: np.ndarray, p: Params = FAST):
    tp = toolpaths(tris, p)
    g = program(tp, p)
    return tp, g, verify(g, tris, tp.trunnion, tool_dia=p.tool_dia, table_z=tp.table_z,
                         v_target=p.v_surface)


def test_frame() -> None:
    print("repère : un seul zéro pour l'ébauche et la finition")
    tris = surface(dome(), 14, 14)
    tr, table_z = trunnion_for(tris, FAST)
    p = np.array([3.0, -4.0, -1.5])
    chk("à A=C=0, machine = pièce", np.allclose(piece_to_machine(p, 0, 0, tr), p))
    back = machine_to_piece(piece_to_machine(p, -33.0, 71.0, tr), -33.0, 71.0, tr)
    chk("aller-retour pièce-machine exact", np.allclose(back, p, atol=1e-9))
    chk("le pivot est sous la table de d",
        abs(tr.pivot[2] - (table_z - FAST.d_pivot_table)) < 1e-9, f"pivot Z={tr.pivot[2]:.2f}")
    batch = _centres_in_piece(
        np.array([[*(piece_to_machine(p, -33.0, 71.0, tr) - [0, 0, 3.0]), -33.0, 71.0]]), 3.0, tr)
    chk("le vérificateur inverse la même chaîne", np.allclose(batch[0], p, atol=1e-9))
    n = np.array([0.3, -0.5, 0.81])
    n /= np.linalg.norm(n)
    a, c = orient(n)
    tr0 = Trunnion()
    v = piece_to_machine(n, a, c, tr0) - piece_to_machine(np.zeros(3), a, c, tr0)
    v2 = piece_to_machine(n, -a, c + 180, tr0) - piece_to_machine(np.zeros(3), -a, c + 180, tr0)
    chk("les deux branches amènent la normale sur Z",
        np.allclose(v, [0, 0, 1], atol=1e-9) and np.allclose(v2, [0, 0, 1], atol=1e-9))


def test_guard_sees_defects() -> None:
    print("le vérificateur attrape ce qu'il doit attraper")
    tris = surface(dome(), 14, 14)
    tp, g, rep = run(tris)
    chk("programme sain accepté", is_safe(rep), str(rep["penetration_max_mm"]))
    # Toutes les coordonnées descendues de 2 mm : l'outil doit rentrer dans la pièce.
    low = []
    for line in g.splitlines():
        if line.startswith("G1") and " Z" in line:
            head, tail = line.split(" Z", 1)
            z, rest = (tail.split(" ", 1) + [""])[:2]
            line = f"{head} Z{float(z) - 2.0:.3f} {rest}"
        low.append(line)
    rep_low = verify("\n".join(low), tris, tp.trunnion, tool_dia=6.0, table_z=tp.table_z)
    chk("programme descendu de 2 mm refusé", not is_safe(rep_low),
        f"pénétration {rep_low['penetration_max_mm']} mm")
    tr_bad = Trunnion(pivot_to_table=tp.trunnion.pivot_to_table + 8,
                      pivot=(0.0, 0.0, tp.trunnion.pivot[2] + 8))
    rep_frame = verify(g, tris, tr_bad, tool_dia=6.0, table_z=tp.table_z)
    chk("erreur de pivot de 8 mm refusée", not is_safe(rep_frame),
        f"pénétration {rep_frame['penetration_max_mm']} mm")


def test_dome() -> None:
    print("dôme : vrai 5 axes, sans pénétration")
    tris = surface(dome(), 14, 14)
    tp, g, rep = run(tris)
    chk("zéro pénétration pièce et table",
        rep["blocs_penetrant_piece"] == 0 and rep["blocs_penetrant_table"] == 0,
        f"{rep['blocs_penetrant_piece']} bloc(s), max {rep['penetration_max_mm']} mm")
    chk("zéro collision outil", rep["collisions_queue"] == 0 and rep["collisions_porte_outil"] == 0)
    chk("A et C bougent ensemble", rep["blocs_a_et_c"] > 100, f"{rep['blocs_a_et_c']} blocs")
    chk("A reste dans la course et sous le plafond",
        rep["a_dans_course"] and rep["a_deg"][0] >= -45.0 - 1e-6, str(rep["a_deg"]))
    # Pente de la surface décalée au bord : atan(14 / 18,2) = 37,6°, moins la zone morte.
    chk("A suit vraiment la pente du dôme", rep["a_deg"][0] <= -25.0, str(rep["a_deg"]))
    chk("excursion dans les courses", rep["excursion_tient"], str(rep["excursion_mm"]))
    finish = g.split("ETAPE 2")[1]
    moves = parse_moves("G0 X0 Y0 Z30 A0 C0\n" + finish)
    jumps = [abs((m.end - m.start)[4]) for m in moves if not m.rapid]
    chk("pas d'embardée de C en coupe", max(jumps) < 15.0, f"max {max(jumps):.2f}°/bloc")
    chk("F jamais au-dessus du plafond ForceGuard",
        all(m.feed <= FAST.feed_cap + 1e-6 for m in moves if not m.rapid))
    sp = rep["avance_reelle_mm_min"]
    chk("avance réelle proche de la visée", 75.0 <= sp["mediane"] <= 165.0, str(sp))


def test_island() -> None:
    print("ébauche : un îlot au milieu d'une ligne reste debout")

    def bump(x, y):
        return 6.0 * np.exp(-(x**2 + y**2) / 18.0) + 3.0 * np.exp(-((x - 9) ** 2 + y**2) / 6.0)

    tris = surface(bump, 16, 12)
    _, _, rep = run(tris)
    chk("aucune passe à travers les îlots", rep["blocs_penetrant_piece"] == 0,
        f"{rep['blocs_penetrant_piece']} bloc(s), max {rep['penetration_max_mm']} mm")
    chk("programme accepté", is_safe(rep))


def test_cliff() -> None:
    print("flancs raides : ni corde sous la surface, ni queue d'outil dans la pièce")

    def tower(x, y):
        return 18.0 * np.exp(-((x**2 + y**2) / 30.0) ** 3)

    tris = surface(tower, 16, 16, n=120)
    _, _, rep = run(tris, Params(ap=2.0, ae=2.0, stepover=0.8))
    chk("aucune pénétration", rep["blocs_penetrant_piece"] == 0,
        f"{rep['blocs_penetrant_piece']} bloc(s), max {rep['penetration_max_mm']} mm")
    chk("aucune collision d'outil", rep["collisions_queue"] == 0 and rep["collisions_porte_outil"] == 0,
        f"queue {rep['collisions_queue']}, porte-outil {rep['collisions_porte_outil']}")
    chk("C reste dans ses 720°", rep["c_dans_course"], str(rep["c_deg"]))


def test_out_of_reach() -> None:
    print("trop profond pour la sortie d'outil : pas usiné, et dit")

    def well(x, y):
        return -30.0 * np.exp(-((x**2 + y**2) / 40.0) ** 2)

    tris = surface(well, 18, 18, n=100)
    tp, _, rep = run(tris, Params(ap=3.0, ae=2.0, stepover=1.0))
    chk("aucune collision de porte-outil", rep["collisions_porte_outil"] == 0,
        str(rep["collisions_porte_outil"]))
    chk("programme accepté", is_safe(rep), str(rep["penetration_max_mm"]))
    chk("la zone non usinée est chiffrée", tp.stats["finition"]["hors_portee_pct"] > 0.0,
        f"{tp.stats['finition']['hors_portee_pct']} %")


def test_fit_to_travel() -> None:
    print("adaptation aux courses : la réduction est mesurée après rotation")
    from continuous5 import checked_program

    tris = surface(dome(70.0), 44, 44, n=40)
    p = Params(ap=8.0, ae=6.0, stepover=3.0, smooth_mm=4.0)
    _, _, rep, scaled, factor = checked_program(tris, p, fit_travel=True)
    chk("la pièce a été réduite", factor < 1.0, f"facteur {factor:.3f}")
    chk("l'excursion tient après réduction", rep["excursion_tient"], str(rep["excursion_mm"]))
    size = scaled.reshape(-1, 3).max(axis=0) - scaled.reshape(-1, 3).min(axis=0)
    chk("la géométrie suit le facteur", abs(size[0] - 88.0 * factor) < 1e-6, f"{size[0]:.2f} mm")


def test_refuses_out_of_travel() -> None:
    print("une pièce trop large ne passe pas la garde")
    tris = surface(dome(120.0), 60, 40, n=40)
    p = Params(ap=8.0, ae=6.0, stepover=4.0, smooth_mm=8.0)
    tp = toolpaths(tris, p)
    rep = verify(program(tp, p), tris, tp.trunnion, tool_dia=6.0, table_z=tp.table_z)
    chk("excursion X de 120 mm refusée", not rep["excursion_tient"], str(rep["excursion_mm"]))
    chk("is_safe suit l'excursion", not is_safe(rep))


def test_undercut_is_reported() -> None:
    print("contre-dépouille : la part atteinte est dite, pas tue")
    tris = surface(dome(), 14, 14)
    flipped = tris.copy()
    flipped[:, :, 2] = -flipped[:, :, 2] - 30.0
    both = np.vstack([tris, flipped])
    both[:, :, 2] -= both[:, :, 2].max()
    tp = toolpaths(both, FAST)
    pct = tp.stats["surface_atteinte_pct"]
    chk("le dessous n'est pas compté comme atteint", pct < 65.0, f"{pct} %")


def main() -> int:
    test_frame()
    test_guard_sees_defects()
    test_dome()
    test_island()
    test_cliff()
    test_out_of_reach()
    test_fit_to_travel()
    test_refuses_out_of_travel()
    test_undercut_is_reported()
    print("\nTOUT PASSE" if _ok else "\nECHEC")
    return 0 if _ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
