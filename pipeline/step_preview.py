"""Aperçu 3D d'un fichier STEP : maillage de visualisation, en une commande.

    STEP ──→ BRepMesh ──→ {vertices, indices, bbox, volume} ──→ .json

Le reste du pipeline lit le STEP pour l'USINER : géométrie exacte, faces
analytiques, aucune facettisation (voir `step_io.py`). Ici l'objectif est
l'inverse — on ne veut PAS de précision, on veut de quoi dessiner la pièce à
l'écran avant même de savoir si elle est usinable. OpenCASCADE sait facettiser
une forme exacte à une flèche donnée : c'est exactement ce qu'il faut, et ça
évite d'exiger un export STL en plus du STEP côté opérateur.

La flèche (« deflection ») est l'écart maximal toléré entre la facette et la
surface vraie. Elle est prise RELATIVE à la diagonale de la pièce : une bague
de 8 mm et un carter de 800 mm donnent alors un maillage de finesse
comparable à l'écran, sans réglage.

Sortie : un seul fichier JSON, lu tel quel par `web/three_viewer.html`
(message `load_mesh`). Les normales n'y sont pas — three.js les recalcule à
partir des faces, ce qui épargne un tiers du poids du fichier.

Nécessite `pipeline/.venv312` (voir `step_io.py`).

    pipeline/.venv312/Scripts/python pipeline/step_preview.py piece.step
"""

from __future__ import annotations

import json
import math

from OCP.BRep import BRep_Tool
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.BRepTools import BRepTools
from OCP.TopAbs import TopAbs_FACE, TopAbs_REVERSED
from OCP.TopExp import TopExp_Explorer
from OCP.TopLoc import TopLoc_Location
from OCP.TopoDS import TopoDS, TopoDS_Shape

from step_io import bounding_box, read_step, volume

# Au-delà, le maillage coûte plus cher à transporter et à dessiner qu'il
# n'apporte de détail visible : on re-facettise plus grossièrement.
MAX_TRIANGLES = 200_000

# Flèche par défaut, en fraction de la diagonale de la boîte englobante.
# 1/1000 : sur une pièce de 100 mm, une facette s'écarte au plus de 0.1 mm de
# la surface vraie — invisible à l'écran, largement suffisant pour juger d'une
# forme.
DEFAULT_RELATIVE_DEFLECTION = 1.0 / 1000.0


def _node(triangulation, i):
    """Sommet n° [i] (1-indexé) d'une triangulation.

    `Poly_Triangulation::Node()` remplace `Nodes()` depuis OCCT 7.6 (et
    `Nodes()` a disparu en 7.8). Les deux sont tentés : ce pipeline suit la
    version de `cadquery-ocp` disponible sur PyPI, qui bouge d'une release à
    l'autre, et un aperçu ne vaut pas d'être bloqué par un renommage.
    """
    try:
        return triangulation.Node(i)
    except AttributeError:
        return triangulation.Nodes().Value(i)


def _triangle_nodes(triangle) -> tuple[int, int, int]:
    """Les trois indices de sommets d'un `Poly_Triangle`.

    On passe par `Value()` et non par `Get()` : cette dernière est une
    surcharge à paramètres de sortie, que ces bindings ne convertissent pas —
    même écueil que `Bnd_Box.Get()` dans `step_io.bounding_box`.
    """
    return triangle.Value(1), triangle.Value(2), triangle.Value(3)


def tessellate(shape: TopoDS_Shape, deflection: float) -> tuple[list[float], list[int]]:
    """Facettise [shape] et retourne (sommets à plat, indices à plat).

    Chaque face porte sa propre triangulation, dans son propre repère local :
    les sommets sont ramenés au repère de la pièce par la transformation de la
    face, sans quoi un assemblage se disloquerait à l'écran. Les faces
    d'orientation inversée voient leur ordre de parcours échangé, pour que
    toutes les normales recalculées pointent vers l'extérieur.
    """
    # Une forme relue peut déjà porter une triangulation d'un autre appel, à
    # une autre flèche : on repart propre, sinon BRepMesh la conserve et le
    # paramètre est sans effet.
    BRepTools.Clean_s(shape)
    BRepMesh_IncrementalMesh(shape, deflection, False, 0.5, True)

    vertices: list[float] = []
    indices: list[int] = []

    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    while explorer.More():
        face = TopoDS.Face_s(explorer.Current())
        location = TopLoc_Location()
        triangulation = BRep_Tool.Triangulation_s(face, location)
        explorer.Next()

        # Une face peut rester non facettisée (géométrie dégénérée) : on la
        # saute plutôt que d'abandonner tout l'aperçu.
        if triangulation is None:
            continue

        transform = location.Transformation()
        identity = location.IsIdentity()
        base = len(vertices) // 3

        for i in range(1, triangulation.NbNodes() + 1):
            point = _node(triangulation, i)
            if not identity:
                point = point.Transformed(transform)
            vertices.extend((point.X(), point.Y(), point.Z()))

        reversed_face = face.Orientation() == TopAbs_REVERSED
        for i in range(1, triangulation.NbTriangles() + 1):
            n1, n2, n3 = _triangle_nodes(triangulation.Triangle(i))
            if reversed_face:
                n2, n3 = n3, n2
            # Les indices d'OpenCASCADE sont 1-indexés, ceux de three.js 0.
            indices.extend((base + n1 - 1, base + n2 - 1, base + n3 - 1))

    return vertices, indices


def preview(step_path: str, relative_deflection: float = DEFAULT_RELATIVE_DEFLECTION) -> dict:
    """Lit [step_path] et retourne le maillage d'aperçu, prêt à sérialiser.

    Si la pièce produit un maillage déraisonnable pour un affichage, la flèche
    est doublée et la facettisation refaite — au pire quelques tours, jamais
    une boucle sans fin.
    """
    shape = read_step(step_path)

    xmin, ymin, zmin, xmax, ymax, zmax = bounding_box(shape)
    size = (xmax - xmin, ymax - ymin, zmax - zmin)
    diagonal = math.sqrt(sum(s * s for s in size))
    # Une pièce plate (tôle) a une diagonale non nulle ; une forme vide en
    # aurait une nulle, et une flèche nulle ferait tourner BRepMesh sans fin.
    deflection = max(diagonal * relative_deflection, 1e-3)

    for _ in range(5):
        vertices, indices = tessellate(shape, deflection)
        if len(indices) // 3 <= MAX_TRIANGLES:
            break
        deflection *= 2.0

    return {
        "source": step_path,
        "unit": "mm",
        "vertices": [round(v, 4) for v in vertices],
        "indices": indices,
        "vertexCount": len(vertices) // 3,
        "triangles": len(indices) // 3,
        "deflection": deflection,
        "volume": volume(shape),
        "bbox": {
            "min": [xmin, ymin, zmin],
            "max": [xmax, ymax, zmax],
            "size": list(size),
        },
    }


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser(
        description="Maillage d'aperçu d'un fichier STEP, pour le visualiseur 3D."
    )
    ap.add_argument("step", help="fichier .step / .stp à prévisualiser")
    ap.add_argument("-o", "--sortie", help="fichier .json (défaut : <step>_apercu.json)")
    ap.add_argument(
        "--fleche",
        type=float,
        default=DEFAULT_RELATIVE_DEFLECTION,
        help="flèche de facettisation, en fraction de la diagonale (défaut 0.001)",
    )
    args = ap.parse_args()

    try:
        data = preview(args.step, args.fleche)
    except (ValueError, RuntimeError) as exc:
        print(f"REFUS : {exc}")
        return 1

    base = args.step.rsplit(".", 1)[0]
    out = args.sortie or base + "_apercu.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)

    size = data["bbox"]["size"]
    print(
        f"{args.step} : {data['triangles']} triangles "
        f"({data['vertexCount']} sommets), flèche {data['deflection']:.4f} mm"
    )
    print(f"encombrement : {size[0]:.2f} × {size[1]:.2f} × {size[2]:.2f} mm")
    print(f"volume : {data['volume']:.2f} mm³")
    print(f"aperçu -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
