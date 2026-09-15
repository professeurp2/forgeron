"""Vérifie le maillage d'aperçu sur des solides dont la géométrie est connue.

Aucun fichier externe : les solides sont construits par OpenCASCADE (sphère,
boîte), écrits en STEP, relus, puis facettisés. Trois propriétés sont
contrôlées — ce sont exactement celles qui, si elles cassent, donnent une
pièce fausse à l'écran sans aucun message d'erreur :

  1. l'encombrement du maillage colle à celui de la forme exacte
     (indices bien 0-indexés, sommets bien transformés) ;
  2. le volume calculé par le théorème de la divergence sur les triangles est
     POSITIF et proche du volume exact — donc les triangles tournent tous vers
     l'extérieur (c'est la gestion de `TopAbs_REVERSED` qui se joue là, et une
     pièce à l'envers apparaît creuse et noire dans three.js) ;
  3. resserrer la flèche augmente le nombre de triangles — donc le paramètre
     est bien pris en compte et la triangulation précédente bien nettoyée.

Lancer :  pipeline/.venv312/Scripts/python pipeline/test_step_preview.py
"""

from __future__ import annotations

import math
import tempfile
from pathlib import Path

from OCP.BRepPrimAPI import BRepPrimAPI_MakeBox, BRepPrimAPI_MakeSphere

from step_io import write_step
from step_preview import preview

R = 20.0  # rayon de la sphère, comme test_step_io.py


def mesh_volume(vertices: list[float], indices: list[int]) -> float:
    """Volume enfermé par le maillage (théorème de la divergence).

    Somme des volumes signés des tétraèdres (origine, v0, v1, v2). Positif si
    les triangles tournent vers l'extérieur, négatif sinon — c'est ce signe
    qui fait le test d'orientation.
    """
    total = 0.0
    for t in range(0, len(indices), 3):
        a, b, c = (indices[t] * 3, indices[t + 1] * 3, indices[t + 2] * 3)
        ax, ay, az = vertices[a], vertices[a + 1], vertices[a + 2]
        bx, by, bz = vertices[b], vertices[b + 1], vertices[b + 2]
        cx, cy, cz = vertices[c], vertices[c + 1], vertices[c + 2]
        total += (
            ax * (by * cz - bz * cy)
            - ay * (bx * cz - bz * cx)
            + az * (bx * cy - by * cx)
        )
    return total / 6.0


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="forgeron_preview_"))
    ok = True

    # ── 1. Sphère R20 : encombrement, orientation, volume ──────────────────
    sphere_path = tmp / "sphere_r20.step"
    write_step(BRepPrimAPI_MakeSphere(R).Shape(), str(sphere_path))
    data = preview(str(sphere_path))

    size = data["bbox"]["size"]
    print(f"sphère R20 : {data['triangles']} triangles, flèche {data['deflection']:.4f} mm")
    print(f"  encombrement : {size[0]:.4f} × {size[1]:.4f} × {size[2]:.4f} mm"
          f"   (attendu {2 * R:.3f} sur les trois axes)")
    if any(abs(s - 2 * R) > 1e-6 for s in size):
        print("  ÉCHEC : l'encombrement ne correspond pas à la sphère.")
        ok = False

    if data["triangles"] < 100:
        print(f"  ÉCHEC : {data['triangles']} triangles, maillage vide ou quasi vide.")
        ok = False

    v_mesh = mesh_volume(data["vertices"], data["indices"])
    v_exact = 4.0 / 3.0 * math.pi * R**3
    print(f"  volume du maillage : {v_mesh:.2f} mm³   (exact {v_exact:.2f})")
    if v_mesh <= 0:
        print("  ÉCHEC : volume négatif — les triangles pointent vers l'intérieur.")
        ok = False
    # Un maillage inscrit sous-estime toujours un peu une sphère : 1 % suffit
    # largement à distinguer « correct » de « faux ».
    elif abs(v_mesh - v_exact) / v_exact > 0.01:
        print("  ÉCHEC : le volume du maillage s'écarte trop de la forme exacte.")
        ok = False

    # ── 2. Boîte : une forme plane se facettise exactement ─────────────────
    box_path = tmp / "boite.step"
    write_step(BRepPrimAPI_MakeBox(30.0, 20.0, 10.0).Shape(), str(box_path))
    box = preview(str(box_path))
    v_box = mesh_volume(box["vertices"], box["indices"])

    print()
    print(f"boîte 30×20×10 : {box['triangles']} triangles")
    print(f"  volume du maillage : {v_box:.4f} mm³   (exact 6000.0000)")
    # Des faces planes : le maillage est exact, pas approché.
    if abs(v_box - 6000.0) > 1e-6:
        print("  ÉCHEC : une boîte doit se mailler exactement.")
        ok = False
    if box["triangles"] < 12:
        print("  ÉCHEC : une boîte a au moins 12 triangles (2 par face).")
        ok = False

    # ── 3. La flèche pilote bien la finesse ────────────────────────────────
    fin = preview(str(sphere_path), relative_deflection=1.0 / 8000.0)
    print()
    print(f"flèche resserrée : {fin['triangles']} triangles "
          f"(contre {data['triangles']} par défaut)")
    if fin["triangles"] <= data["triangles"]:
        print("  ÉCHEC : resserrer la flèche n'a rien changé — triangulation "
              "précédente non nettoyée ?")
        ok = False

    print()
    print("TOUT PASSE" if ok else "DES VÉRIFICATIONS ONT ÉCHOUÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
