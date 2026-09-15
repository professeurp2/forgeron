"""Extraction de l'AXE et du PROFIL d'une pièce de révolution depuis un STEP.

Troisième source du même profil que `mesh_profile.py` (STL) et
`tool/extract_profile.dart` (G-code) produisent déjà — les trois alimentent
`gen_revolution.py`.

Contrairement au maillage, où la révolution doit être devinée
statistiquement depuis un nuage de points
(`mesh_profile.check_revolution`), un STEP porte l'axe de révolution comme
donnée EXACTE : chaque face cylindrique, conique, sphérique ou torique a un
axe analytique déjà calculé par OpenCASCADE. Ce module se contente de le
lire, puis coupe la pièce par un plan contenant cet axe pour obtenir le
profil méridien exact — aucun échantillonnage statistique, aucune tolérance
de maillage.

Nécessite `pipeline/.venv312` (voir `step_io.py`).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from OCP.BRep import BRep_Builder
from OCP.BRepAdaptor import BRepAdaptor_Curve, BRepAdaptor_Surface
from OCP.BRepAlgoAPI import BRepAlgoAPI_Section
from OCP.GeomAbs import (
    GeomAbs_Cone,
    GeomAbs_Cylinder,
    GeomAbs_Sphere,
    GeomAbs_SurfaceOfRevolution,
    GeomAbs_Torus,
)
from OCP.gp import gp_Dir, gp_Pln, gp_Pnt, gp_Vec
from OCP.TopAbs import TopAbs_EDGE, TopAbs_FACE
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS, TopoDS_Compound, TopoDS_Face, TopoDS_Shape

from mesh_profile import ProfilePoint


@dataclass(frozen=True)
class Axis:
    """Un axe de révolution : un point et une direction unitaire."""

    point: tuple[float, float, float]
    direction: tuple[float, float, float]


@dataclass(frozen=True)
class AxisCheck:
    """Verdict de la détection d'axe, avec de quoi le justifier."""

    axis: Axis | None
    reason: str


def _face_axis(face: TopoDS_Face) -> tuple[gp_Pnt, gp_Dir] | None:
    """Axe de révolution porté par la surface d'une face, s'il y en a un.

    None pour un plan, une surface libre (BSpline non-révolue), etc. — ces
    faces ne CONTREDISENT pas la révolution (un plan perpendiculaire à l'axe
    est un fond ou un sommet plat parfaitement valide) : on les ignore plutôt
    que de les rejeter.
    """
    surf = BRepAdaptor_Surface(face, True)
    t = surf.GetType()
    if t == GeomAbs_Cylinder:
        ax1 = surf.Cylinder().Axis()
    elif t == GeomAbs_Cone:
        ax1 = surf.Cone().Axis()
    elif t == GeomAbs_Sphere:
        ax1 = surf.Sphere().Position().Axis()
    elif t == GeomAbs_Torus:
        ax1 = surf.Torus().Axis()
    elif t == GeomAbs_SurfaceOfRevolution:
        ax1 = surf.AxeOfRevolution()
    else:
        return None
    return ax1.Location(), ax1.Direction()


def _revolution_faces(shape: TopoDS_Shape) -> list[TopoDS_Face]:
    """Les faces dont la surface porte un axe de révolution — ni les plans,
    ni les surfaces libres. Ce sont les seules qui décrivent une paroi
    tournée ; un fond plat n'en est pas une (voir `extract_profile`)."""
    faces: list[TopoDS_Face] = []
    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    while explorer.More():
        face = TopoDS.Face(explorer.Current())
        if _face_axis(face) is not None:
            faces.append(face)
        explorer.Next()
    return faces


def detect_axis(shape: TopoDS_Shape, tolerance: float = 1e-4) -> AxisCheck:
    """Trouve l'axe de révolution commun aux faces de la pièce.

    Chaque face « de révolution » porte son propre axe, exact. La pièce n'est
    une pièce de révolution que si tous ces axes coïncident : même direction,
    et des points portés par la même droite. Faute de face de ce type — un
    pavé, par exemple — ou en cas d'axes discordants, on REFUSE : c'est la
    même prudence que `mesh_profile.check_revolution` côté maillage.
    """
    axes = [_face_axis(f) for f in _revolution_faces(shape)]

    if not axes:
        return AxisCheck(
            None,
            "aucune face cylindrique/conique/sphérique/torique : "
            "pas de révolution détectable",
        )

    p0, d0 = axes[0]
    d0v = (d0.X(), d0.Y(), d0.Z())

    for p, d in axes[1:]:
        dv = (d.X(), d.Y(), d.Z())
        # Le sens de l'axe est arbitraire par face (une face conique et sa
        # voisine peuvent le porter en sens opposés) : seule la droite compte.
        if sum(a * b for a, b in zip(d0v, dv)) < 0:
            dv = tuple(-x for x in dv)
        cross = (
            d0v[1] * dv[2] - d0v[2] * dv[1],
            d0v[2] * dv[0] - d0v[0] * dv[2],
            d0v[0] * dv[1] - d0v[1] * dv[0],
        )
        if math.hypot(*cross) > tolerance:
            return AxisCheck(
                None,
                "des faces portent des axes de directions différentes : "
                "pas de révolution autour d'un axe commun",
            )

        v = (p.X() - p0.X(), p.Y() - p0.Y(), p.Z() - p0.Z())
        v_croix_d = (
            v[1] * d0v[2] - v[2] * d0v[1],
            v[2] * d0v[0] - v[0] * d0v[2],
            v[0] * d0v[1] - v[1] * d0v[0],
        )
        if math.hypot(*v_croix_d) > tolerance:
            return AxisCheck(
                None,
                "des faces portent des axes parallèles mais décalés : "
                "pas de révolution autour d'un axe commun",
            )

    # Le signe retenu par OpenCASCADE dépend de la convention interne de
    # chaque type de surface (un cône dont le rayon diminue vers +Z peut
    # porter un axe pointant vers -Z) — sans rapport avec un « haut » ou un
    # « bas » de la pièce. On fixe le sens vers Z croissant, la convention du
    # fichier STEP pour désigner le haut d'une pièce posée sur la machine :
    # sans ça, `find_undercut` en aval peut prendre une paroi parfaitement
    # conique pour une contre-dépouille, faute de savoir quel bout est le
    # sommet.
    if d0v[2] < 0:
        d0v = tuple(-x for x in d0v)

    return AxisCheck(
        Axis((p0.X(), p0.Y(), p0.Z()), d0v),
        f"{len(axes)} face(s) de révolution, axe commun",
    )


def extract_profile(
    shape: TopoDS_Shape, axis: Axis, n_par_arete: int = 200
) -> list[ProfilePoint]:
    """Profil méridien exact : section de la pièce par un plan contenant l'axe.

    Seules les faces de révolution sont sectionnées — pas la pièce entière.
    Un fond plat (le dessous d'un cylindre, la base d'un cône) coupé par ce
    plan donnerait un segment de droite qui balaie tout le rayon jusqu'au
    centre, un aller-retour sans rapport avec la paroi tournée que l'outil
    doit suivre ; l'inclure a fait passer un simple cône pour une pièce à
    contre-dépouille lors du premier essai bout en bout.

    Le plan traverse ces faces et coupe donc le méridien EN DEUX, de part et
    d'autre de l'axe. Les deux moitiés sont, par construction, le même profil
    — le rayon est une distance à l'axe, toujours positive — donc elles se
    superposent sans qu'il faille choisir un côté.
    """
    faces = _revolution_faces(shape)
    if not faces:
        raise ValueError("aucune face de révolution à sectionner")

    builder = BRep_Builder()
    compound = TopoDS_Compound()
    builder.MakeCompound(compound)
    for face in faces:
        builder.Add(compound, face)

    origin = gp_Pnt(*axis.point)
    d = gp_Dir(*axis.direction)
    d_vec = gp_Vec(d)

    # Normale du plan perpendiculaire à l'axe, pour que l'axe soit CONTENU
    # dans le plan (et non perpendiculaire à lui). N'importe quelle direction
    # non colinéaire à l'axe convient comme germe du produit vectoriel.
    seed = gp_Dir(1, 0, 0) if abs(d.Z()) < 0.9 else gp_Dir(0, 1, 0)
    plane = gp_Pln(origin, d.Crossed(seed))

    section = BRepAlgoAPI_Section(compound, plane, True)
    edges = section.Shape()

    points: list[ProfilePoint] = []
    explorer = TopExp_Explorer(edges, TopAbs_EDGE)
    while explorer.More():
        curve = BRepAdaptor_Curve(TopoDS.Edge(explorer.Current()))
        t0, t1 = curve.FirstParameter(), curve.LastParameter()
        for i in range(n_par_arete):
            t = t0 + (t1 - t0) * i / (n_par_arete - 1)
            v = gp_Vec(origin, curve.Value(t))
            z = v.Dot(d_vec)
            radial = v.Subtracted(d_vec.Multiplied(z))
            points.append(ProfilePoint(radial.Magnitude(), z))
        explorer.Next()

    if not points:
        raise ValueError(
            "plan méridien : aucune arête d'intersection — l'axe détecté "
            "ne traverse peut-être pas la pièce"
        )

    points.sort(key=lambda p: p.z, reverse=True)
    return points
