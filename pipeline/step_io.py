"""Lecture et écriture de fichiers STEP, via OpenCASCADE (OCP).

Nécessite l'environnement `pipeline/.venv312` : les bindings OpenCASCADE sont
des binaires précompilés, publiés uniquement pour des versions stables de
Python. `cadquery-ocp` fournit ces bindings pour Python 3.12 ; ils n'existent
pas pour Python 3.15.0b1, la version utilisée par le reste du pipeline (voir
`stl_io.py`) — d'où le second venv, indépendant du premier.

    python -m venv pipeline/.venv312
    pipeline/.venv312/Scripts/python -m pip install -r pipeline/requirements-step.txt

Contrairement au STL (un maillage, une approximation de la surface), le STEP
porte une géométrie exacte — faces analytiques, aucune facettisation. C'est le
format visé par la phase 5.b du PLAN-IA pour lire une pièce de révolution.
"""

from __future__ import annotations

from OCP.Bnd import Bnd_Box
from OCP.BRepBndLib import BRepBndLib
from OCP.BRepGProp import BRepGProp
from OCP.GProp import GProp_GProps
from OCP.IFSelect import IFSelect_RetDone
from OCP.STEPControl import STEPControl_AsIs, STEPControl_Reader, STEPControl_Writer
from OCP.TopoDS import TopoDS_Shape

BoundingBox = tuple[float, float, float, float, float, float]


def read_step(path: str) -> TopoDS_Shape:
    """Lit un fichier STEP et retourne la forme qu'il contient.

    Une pièce, pas un assemblage : on attend une seule forme utile. Si le
    fichier porte plusieurs racines, `TransferRoots` les fusionne en une forme
    composite — utile plus tard pour un assemblage, invisible ici.
    """
    reader = STEPControl_Reader()
    status = reader.ReadFile(path)
    if status != IFSelect_RetDone:
        raise ValueError(f"{path} : lecture STEP refusée (statut {status})")

    if reader.TransferRoots() < 1:
        raise ValueError(f"{path} : aucune forme transférée")

    shape = reader.OneShape()
    if shape.IsNull():
        raise ValueError(f"{path} : forme vide après transfert")
    return shape


def write_step(shape: TopoDS_Shape, path: str) -> None:
    """Écrit une forme dans un fichier STEP (AP203/214, comme un export CAO).

    Sert surtout à fabriquer des fixtures de test dont la géométrie exacte est
    connue à l'avance, sans dépendre d'un fichier externe — même logique que
    `stl_io.revolve` côté maillage.
    """
    writer = STEPControl_Writer()
    if writer.Transfer(shape, STEPControl_AsIs) != IFSelect_RetDone:
        raise ValueError(f"{path} : conversion vers STEP refusée")
    if writer.Write(path) != IFSelect_RetDone:
        raise ValueError(f"{path} : écriture du fichier STEP échouée")


def bounding_box(shape: TopoDS_Shape) -> BoundingBox:
    """Boîte englobante (xmin, ymin, zmin, xmax, ymax, zmax), en mm.

    `Bnd_Box.Get()` est surchargée côté C++ et renvoie par défaut une struct
    `Limits` que ces bindings ne savent pas convertir : on passe par les six
    accesseurs individuels, sans ambiguïté.
    """
    box = Bnd_Box()
    BRepBndLib.Add_s(shape, box)
    return (
        box.GetXMin(), box.GetYMin(), box.GetZMin(),
        box.GetXMax(), box.GetYMax(), box.GetZMax(),
    )


def volume(shape: TopoDS_Shape) -> float:
    """Volume exact de la forme (mm³) — intégration sur la géométrie
    analytique, pas une somme approchée sur des facettes."""
    props = GProp_GProps()
    BRepGProp.VolumeProperties_s(shape, props)
    return props.Mass()
