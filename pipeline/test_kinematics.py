"""Valide la cinématique 5 axes contre la géométrie connue du dôme R20.

Aucun tirage aléatoire : les angles sont énumérés, donc le test est
reproductible à l'identique — et il évite `np.random`, qui fait tomber
Python 3.15.0b1 en erreur de segmentation.

Lancer :  cd pipeline && .venv/Scripts/python test_kinematics.py
"""

from __future__ import annotations

import math

import numpy as np

from kinematics import (
    Trunnion,
    machine_to_piece,
    orient,
    piece_to_machine,
    reachable,
    tool_position,
)

R = 20.0
RHO = 3.0
# Pivot mesuré sur le montage du dôme : 43 mm sous le sommet de la pièce.
TR = Trunnion(pivot_to_table=8.0, pivot=(0.0, 0.0, -43.0))

_ok = True


def chk(label: str, cond: bool, detail: str = "") -> None:
    global _ok
    _ok &= bool(cond)
    print(f"  {'OK  ' if cond else 'ECHEC'} {label}" + (f"  — {detail}" if detail else ""))


def main() -> int:
    print("\n1. Aller-retour pièce ↔ machine")
    worst = 0.0
    for px in (-30.0, -7.5, 0.0, 12.0, 30.0):
        for pz in (-40.0, -12.0, 0.0):
            for a in (-88.0, -30.0, 0.0, 45.0, 90.0):
                for c in (0.0, 73.0, 180.0, 299.0):
                    p = np.array([px, 5.0, pz])
                    back = machine_to_piece(piece_to_machine(p, a, c, TR), a, c, TR)
                    worst = max(worst, float(np.abs(back - p).max()))
    chk("inverse exact sur 300 configurations", worst < 1e-9,
        f"écart max {worst:.2e} mm")

    print("\n2. Orientation depuis la normale")
    for n, exp_a in (((0, 0, 1), 0.0), ((1, 0, 0), 90.0), ((0, 1, 0), 90.0)):
        a, c = orient(np.array(n, dtype=float))
        chk(f"normale {n} → A={a:.1f}° C={c:.1f}°", abs(a - exp_a) < 1e-6)

    print("\n3. Sur le dôme, A doit valoir la colatitude")
    worst_a = 0.0
    for th_deg in (0, 15, 30, 45, 60, 75, 90):
        th = math.radians(th_deg)
        a, _ = orient(np.array([math.sin(th), 0.0, math.cos(th)]))
        worst_a = max(worst_a, abs(a - th_deg))
    chk("A = colatitude sur 7 points", worst_a < 1e-6,
        f"écart max {worst_a:.2e}°")

    print("\n4. Compensation RTCP : la pointe atteint le contact visé")
    worst_d = 0.0
    hors_course = 0
    for th_deg in range(0, 91, 5):
        th = math.radians(th_deg)
        n = np.array([math.sin(th), 0.0, math.cos(th)])
        P = np.array([R * math.sin(th), 0.0, R * math.cos(th) - R])
        tip, a, c = tool_position(P, n, RHO, TR)
        if not reachable(a, TR):
            hors_course += 1
            continue
        # On repart de la position machine pour retrouver le point de contact.
        centre_piece = machine_to_piece(
            tip + np.array([0.0, 0.0, RHO]), a, c, TR
        )
        worst_d = max(worst_d, float(np.linalg.norm(centre_piece - RHO * n - P)))
    chk("contact retrouvé sur 19 orientations", worst_d < 1e-9,
        f"écart max {worst_d:.2e} mm")
    chk("toutes les orientations dans la course A", hors_course == 0,
        f"{hors_course} hors course")

    print("\n5. Ce que coûte l'ABSENCE de compensation")
    for th_deg in (30, 60, 80, 90):
        th = math.radians(th_deg)
        n = np.array([math.sin(th), 0.0, math.cos(th)])
        P = np.array([R * math.sin(th), 0.0, R * math.cos(th) - R])
        tip, a, _ = tool_position(P, n, RHO, TR)
        naif = P + RHO * n - np.array([0.0, 0.0, RHO])
        print(f"       A={a:5.1f}°  →  {np.linalg.norm(tip - naif):6.1f} mm "
              "entre position compensée et non compensée")

    print("\n" + ("TOUT PASSE" if _ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ"))
    return 0 if _ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
