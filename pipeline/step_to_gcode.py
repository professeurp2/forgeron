"""STEP → G-code en une commande : la démonstration « zéro-clic » de la
phase 5.b du PLAN-IA, pour une pièce de révolution.

    STEP ──→ detect_axis ──→ extract_profile ──→ generate ──→ .nc

Chaque étape reste utilisable seule (`step_io.py`, `step_profile.py`,
`gen_revolution.py`) — ce module se contente de les enchaîner, et de refuser
proprement quand la pièce n'est pas une révolution, plutôt que de produire un
parcours sans rapport avec la forme.
"""

from __future__ import annotations

import numpy as np

from gen_revolution import CutParams, generate
from mesh_profile import ProfilePoint, write_csv
from step_io import read_step
from step_profile import detect_axis, extract_profile


def step_to_gcode(
    step_path: str, params: CutParams = CutParams()
) -> tuple[str, dict, list[ProfilePoint]]:
    """Pipeline complet. Retourne (g-code, rapport, profil).

    Lève ValueError si la pièce n'est pas reconnue comme une révolution — le
    même refus motivé que `mesh_profile.check_revolution` côté STL : mieux
    vaut un échec net qu'un parcours sans rapport avec la pièce.
    """
    shape = read_step(step_path)
    verdict = detect_axis(shape)
    if verdict.axis is None:
        raise ValueError(f"{step_path} : pas une pièce de révolution — {verdict.reason}")

    profile = extract_profile(shape, verdict.axis)
    prof = np.array([[p.r, p.z] for p in profile], dtype=float)
    gcode, report = generate(prof, params)
    return gcode, report, profile


def main() -> int:
    import argparse
    import json

    ap = argparse.ArgumentParser(
        description="STEP -> G-code en une commande, pour une pièce de révolution."
    )
    ap.add_argument("step", help="fichier .step / .stp à usiner")
    ap.add_argument("-o", "--sortie", help="fichier .nc (défaut : <step>.nc)")
    ap.add_argument("--outil", type=float, default=6.0, help="diamètre fraise boule (mm)")
    ap.add_argument("--ap", type=float, default=0.5, help="profondeur de passe ébauche (mm)")
    ap.add_argument("--ae", type=float, default=1.0, help="engagement radial ébauche (mm)")
    ap.add_argument(
        "--stepover", type=float, default=0.4, help="pas de finition sur la surface (mm)"
    )
    ap.add_argument(
        "--brut-rayon",
        type=float,
        default=None,
        help="rayon du barreau brut (mm). Sans lui, l'ébauche balaie toute "
        "l'enveloppe par sécurité — et coupe de l'air : sur le dôme de "
        "référence, un tiers du programme",
    )
    args = ap.parse_args()

    params = CutParams(
        tool_dia=args.outil,
        ap=args.ap,
        ae=args.ae,
        stepover=args.stepover,
        stock_radius=args.brut_rayon,
    )

    try:
        gcode, report, profile = step_to_gcode(args.step, params)
    except ValueError as exc:
        print(f"REFUS : {exc}")
        return 1

    base = args.step.rsplit(".", 1)[0]
    out = args.sortie or base + ".nc"
    with open(out, "w", encoding="utf-8") as f:
        f.write(gcode)

    profile_csv = base + "_profil.csv"
    write_csv(profile, profile_csv)

    # Rapport en fichier à part, plutôt que sur stdout : un appelant (l'agent
    # IA, via un sous-processus) n'a alors rien à extraire d'une sortie texte
    # qui peut aussi porter des avertissements — juste ce fichier à lire.
    report_path = base + "_rapport.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(
            {**report, "gcode_path": out, "profile_csv_path": profile_csv},
            f,
            indent=2,
            ensure_ascii=False,
        )

    print(f"{args.step} : {len(profile)} points de profil -> {profile_csv}")
    print(f"{len(gcode.splitlines())} lignes -> {out}")
    if report.get("brut_rayon_mm") is None and report.get("duree_a_vide_min", 0) > 1.0:
        print(
            f"AVIS : brut non déclaré, {round(report['duree_a_vide_min'])} min "
            f"d'ébauche dans le vide évitables avec --brut-rayon."
        )
    print(f"rapport -> {report_path}")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
