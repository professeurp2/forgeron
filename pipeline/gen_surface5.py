"""Parcours 5 AXES CONTINU sur une surface quelconque.

Assemble les deux moitiés : `dropcutter` dit où l'outil touche, `kinematics`
dit comment orienter la pièce et où placer la broche. Aucune hypothèse de
forme — n'importe quel maillage passe.

── Le problème de l'avance, et sa solution ─────────────────────────────────

En 5 axes continu, chaque bloc fait bouger les axes linéaires ET les rotatifs.
Or GRBL calcule la longueur d'un bloc en mettant les millimètres et les degrés
dans la même racine carrée :

    L_grbl = √(ΔX² + ΔY² + ΔZ² + ΔA² + ΔC²)

Un F écrit naïvement s'applique donc à cette longueur composite, pas au
déplacement réel de l'outil sur la pièce. Sur un bloc où la pièce tourne
beaucoup pour un petit déplacement d'outil, l'avance réelle s'effondre — c'est
le facteur 45 constaté sur le parcours écrit à la main.

Une machine industrielle règle ça avec G93 (inverse time feed), que GRBL ne
connaît pas. On compense donc à la source, bloc par bloc :

    F_écrit = v_visée × L_grbl / L_réelle

où L_réelle est la distance parcourue par le point de CONTACT sur la pièce.
Le bloc dure alors exactement le temps voulu, et l'outil avance à la vitesse
demandée quelle que soit la part de rotation.

── Les embardées ───────────────────────────────────────────────────────────

Deux points voisins de la surface peuvent demander des orientations très
différentes — près d'un pôle, C peut sauter de 180° pour un déplacement d'outil
microscopique. Le berceau ferait une embardée violente, dangereuse pour la
pièce comme pour la mécanique.

Deux gardes : C est déroulé en continu (pas de saut de ±360°), et tout bloc
dont la rotation dépasse `max_deg_per_mm` par millimètre d'avance est signalé.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from dropcutter import height_map
from kinematics import Trunnion, normals_from_height_map, orient, piece_to_machine


@dataclass(frozen=True)
class SurfaceParams:
    tool_dia: float = 6.0
    stepover: float = 0.5      # écart entre deux passes (mm)
    step_along: float = 0.5    # pas le long d'une passe (mm)
    v_surface: float = 120.0   # vitesse visée au point de contact (mm/min)
    feed_cap: float = 500.0    # plafond ForceGuard 5 axes
    feed_link: float = 200.0
    z_safe: float = 20.0
    spindle: int = 1000
    max_deg_per_mm: float = 90.0  # au-delà, le bloc est signalé
    five_axis: bool = True     # False → outil vertical, A et C figés à 0


def f3(v: float) -> str:
    s = f"{v:.3f}"
    return "0.000" if s == "-0.000" else s


def _unwrap(prev: float, c: float) -> float:
    """Ramène C au plus près de la valeur précédente.

    Sans cela, passer de 359° à 1° ferait tourner le plateau de 358° en arrière
    au lieu de 2° en avant.
    """
    while c - prev > 180.0:
        c -= 360.0
    while prev - c > 180.0:
        c += 360.0
    return c


def generate(
    triangles: np.ndarray,
    p: SurfaceParams = SurfaceParams(),
    tr: Trunnion = Trunnion(),
) -> tuple[str, dict]:
    """Programme de finition 5 axes sur le maillage fourni."""
    rho = p.tool_dia / 2

    # 1. Où l'outil peut descendre, et quelle est la normale en chaque point.
    xs, ys, Z = height_map(triangles, rho=rho, step=min(p.step_along, p.stepover))
    normals = normals_from_height_map(xs, ys, Z)

    # 2. Balayage en zigzag : une passe par ligne Y, alternée pour éviter les
    #    retours à vide.
    row_step = max(1, int(round(p.stepover / (ys[1] - ys[0])))) if len(ys) > 1 else 1
    col_step = max(1, int(round(p.step_along / (xs[1] - xs[0])))) if len(xs) > 1 else 1

    body: list[str] = []
    warnings: list[str] = []
    total_min = 0.0
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
                continue  # aucun triangle sous ce point

            centre = np.array([xs[i], ys[j], zc])       # centre de la bille
            n = normals[j, i]
            contact = centre - rho * n                   # point touché sur la pièce

            if p.five_axis:
                a, c = orient(n)
                c = _unwrap(prev_c, c)
                machine = piece_to_machine(centre, a, c, tr) - np.array([0, 0, rho])
            else:
                a, c = 0.0, prev_c
                machine = centre - np.array([0.0, 0.0, rho])

            a_min_seen, a_max_seen = min(a_min_seen, a), max(a_max_seen, a)

            if first:
                body += [
                    f"G0 X{f3(machine[0])} Y{f3(machine[1])}"
                    + (f" A{f3(a)} C{f3(c)}" if p.five_axis else ""),
                    f"G1 Z{f3(machine[2])} F{f3(p.feed_link)}",
                ]
                first = False
            else:
                d_machine = float(np.linalg.norm(machine - prev_machine))
                d_contact = float(np.linalg.norm(contact - prev_contact))
                d_ang = math.hypot(a - prev_a, c - prev_c)

                if d_machine < 1e-9 and d_ang < 1e-9:
                    continue

                # Longueur telle que GRBL la voit : mm et degrés mêlés.
                l_grbl = math.sqrt(d_machine**2 + d_ang**2)
                # Distance réellement parcourue par l'outil SUR la pièce.
                l_real = max(d_contact, 1e-6)
                feed = min(p.v_surface * l_grbl / l_real, p.feed_cap)
                total_min += l_grbl / feed

                if d_contact > 1e-6 and d_ang / d_contact > p.max_deg_per_mm:
                    n_jerky += 1

                words = f"X{f3(machine[0])} Y{f3(machine[1])} Z{f3(machine[2])}"
                if p.five_axis:
                    words += f" A{f3(a)} C{f3(c)}"
                body.append(f"G1 {words} F{f3(feed)}")

            prev_machine, prev_contact, prev_a, prev_c = machine, contact, a, c
            n_points += 1

    if n_jerky:
        warnings.append(
            f"(!!! {n_jerky} BLOC(S) DEPASSENT {f3(p.max_deg_per_mm)} DEG/MM :"
            " ROTATION BRUTALE POUR UN FAIBLE DEPLACEMENT)"
        )
    if a_max_seen > tr.a_max or a_min_seen < tr.a_min:
        warnings.append(
            f"(!!! AXE A HORS COURSE : {f3(a_min_seen)} A {f3(a_max_seen)} DEG"
            f" POUR UNE COURSE DE {f3(tr.a_min)} A {f3(tr.a_max)})"
        )

    head = [
        "(FORGERON - FINITION 5 AXES CONTINU - SURFACE QUELCONQUE)",
        f"(OUTIL : FRAISE BOULE DIAM {f3(p.tool_dia)})",
        f"(PAS {f3(p.stepover)} X {f3(p.step_along)} MM - {n_points} POINTS)",
        f"(AXE A DE {f3(a_min_seen)} A {f3(a_max_seen)} DEG)"
        if p.five_axis else "(MODE 3 AXES : A ET C FIGES)",
        "(AVANCE COMPENSEE BLOC PAR BLOC : GRBL MELE MM ET DEGRES DANS LA MEME",
        " NORME, LE F ECRIT VAUT DONC V x L_GRBL / L_REELLE.)",
        f"(DUREE ESTIMEE : {round(total_min)} MIN)",
        *warnings,
        "G21 G90 G94 G17 G40",
        "G54",
        "M5",
        f"G0 Z{f3(p.z_safe)}",
        f"M0 (VERIFIER OUTIL, BRIDAGE ET ZERO PIECE PUIS REPRENDRE)",
        f"M3 S{p.spindle}",
        "G4 P1 (MONTEE EN REGIME 1 SUR 3)",
        "G4 P1 (MONTEE EN REGIME 2 SUR 3)",
        "G4 P1 (MONTEE EN REGIME 3 SUR 3)",
    ]
    tail = ["(DEGAGEMENT)", f"G0 Z{f3(p.z_safe)}", "M5", "M30"]

    report = {
        "points": n_points,
        "duree_min": total_min,
        "a_min_deg": a_min_seen,
        "a_max_deg": a_max_seen,
        "blocs_brusques": n_jerky,
        "avertissements": warnings,
        "grille": [int(len(xs)), int(len(ys))],
    }
    return "\n".join(head + body + tail) + "\n", report
