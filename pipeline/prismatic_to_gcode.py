"""Pièce prismatique -> G-code, via FreeCAD CAM (workbench « CAM », ex-Path).

Phase 5.c du PLAN-IA — le cas général que le pipeline de révolution
(step_to_gcode.py) refuse explicitement. Contrairement à lui, ce script ne
tourne PAS dans pipeline/.venv312 : il s'exécute DANS l'interpréteur Python
que FreeCAD embarque, via freecadcmd — le seul moyen d'obtenir les modules
FreeCAD/Part/Path sans faire correspondre un venv à une version de FreeCAD
précise (voir le commit qui a ajouté pipeline/freecad/ : ocp-freecad-cam a
été écarté pour cette raison).

    pipeline/freecad/FreeCAD_1.1.3-Windows-x86_64-py311/bin/freecadcmd.exe \\
        pipeline/prismatic_to_gcode.py <piece.step> <sortie.nc>

── Ce qui est automatique, ce qui ne l'est pas ─────────────────────────────

Lu dans le code source de FreeCAD CAM, pas supposé : il n'y a PAS de
reconnaissance de formes générale façon AFR SolidWorks.

- Perçages : reconnus automatiquement (Path.Op.Drilling.Create() appelle
  findAllHoles() en interne) — toute face cylindrique verticale de diamètre
  suffisant devient un perçage.
- Contour extérieur : un Profile sans sélection de face profile la
  silhouette extérieure globale de la pièce — exactement ce qu'il faut pour
  un contour de pourtour, sans rien détecter.
- Poches : aucune reconnaissance native. Ce script détecte lui-même les
  faces planes horizontales en retrait du dessus de la pièce — une
  heuristique locale, pas un AFR général : une poche inclinée, ou creusée
  dans une autre poche, y échapperait.

── Pourquoi les parcours sortaient mauvais ─────────────────────────────────

La première version ne réglait QUE les avances. Tout le reste — l'outil, la
profondeur de passe, le recouvrement, l'ordre des opérations — restait aux
valeurs par défaut de FreeCAD, qui décrivent une fraiseuse ordinaire et non
cette machine-ci. Quatre conséquences, toutes visibles sur le parcours :

1. **L'outil n'était jamais défini.** Le Tool Controller par défaut porte la
   fraise par défaut de FreeCAD. Tous les décalages — offset du contour,
   recouvrement de poche, choix des perçages — étaient donc calculés pour un
   diamètre qui n'est pas celui monté sur la broche. Un contour calculé pour
   Ø5 et usiné avec Ø6 entame la pièce de 0,5 mm au rayon.

2. **La profondeur de passe restait au défaut FreeCAD** (de l'ordre du
   millimètre), soit cinq fois le plafond vibratoire de cette machine
   (ap = 0,2 mm).

3. **Le recouvrement de poche restait à 100 % du diamètre**, soit 6 mm pour
   une fraise Ø6, contre les 0,5 mm admissibles — douze fois trop.

4. **Le contour extérieur passait EN PREMIER.** C'est l'opération qui
   détache la pièce du brut : tout ce qui la suit — poche, perçage —
   s'exécutait sur une pièce qui ne tenait plus. Le contour se fait en
   dernier, toujours.

Ce script règle donc explicitement tout ce qui détermine le parcours, et le
consigne dans son rapport : une propriété que la version de FreeCAD installée
ne connaîtrait pas apparaît dans `reglages_non_appliques` au lieu de
disparaître en silence.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass

import FreeCAD
import Import
import Path.Main.Job as PathJob
import Path.Op.Drilling as PathDrilling
import Path.Op.Pocket as PathPocket
import Path.Op.Profile as PathProfile


@dataclass(frozen=True)
class CutParams:
    """Conditions de coupe, mêmes plafonds que `gen_revolution.CutParams`.

    `ap` et `ae` sont plafonnés par la VIBRATION, pas par l'effort : bâti
    léger, broche DC en porte-à-faux, pièce tenue d'un seul côté. Ces valeurs
    ne doivent pas être relevées sans essai.
    """

    tool_dia: float = 6.0        # fraise (mm) — celle réellement montée
    ap: float = 0.2              # profondeur de passe (mm) — plafond vibratoire
    ae: float = 0.5              # recouvrement latéral (mm) — plafond vibratoire
    feed: float = 500.0          # avance de coupe (mm/min) = F max de X et Y
    feed_plunge: float = 100.0   # plongée (mm/min)
    spindle: int = 1000          # S de la broche (relais tout-ou-rien)
    peck: float = 1.0            # débourrage au perçage (mm), 0 = désactivé

    # Rapides RÉELS de la machine, pas ceux d'une fraiseuse de catalogue :
    # X et Y plafonnent à 500 mm/min et Z à 300 (config FluidNC de
    # production). Les annoncer plus élevés ne rend rien plus rapide — la
    # carte bride — mais fausse toutes les estimations de durée.
    rapid_xy: float = 500.0
    rapid_z: float = 300.0

    # Dégagements au-dessus du brut (mm). Z monte à 300 mm/min : chaque
    # millimètre de trop se paie à chaque remontée, et il y en a une par trou
    # et par passe.
    clearance: float = 5.0
    safe: float = 2.0

    # Brut : marge autour et au-dessus de la pièce (mm). Les défauts sont ceux
    # de FreeCAD (1 mm partout), c'est-à-dire le choix SÛR — voir la note dans
    # `apply_stock`.
    stock_side: float = 1.0
    stock_top: float = 1.0


class Settings:
    """Journal des réglages : ce qui a pris, ce qui n'a pas pris.

    Ce script ne peut pas être essayé ailleurs que sur le poste qui porte
    FreeCAD. Plutôt que de supposer que chaque propriété existe sous le nom
    attendu — ils changent d'une version de FreeCAD à l'autre — on écrit et on
    consigne. Une propriété absente devient une ligne du rapport, pas un
    plantage ni, pire, un silence.
    """

    def __init__(self) -> None:
        self.applied: dict[str, str] = {}
        self.missing: list[str] = []

    def set(self, obj, name: str, value, label: str | None = None) -> bool:
        key = label or f"{getattr(obj, 'Name', type(obj).__name__)}.{name}"
        if not hasattr(obj, name):
            self.missing.append(key)
            return False
        try:
            setattr(obj, name, value)
        except Exception as exc:  # propriété présente mais type refusé
            self.missing.append(f"{key} ({exc})")
            return False
        self.applied[key] = str(value)
        return True


def find_pocket_faces(shape, tolerance: float = 0.05) -> list[str]:
    """Faces planes horizontales en retrait du sommet de la pièce, hors le
    dessous du brut.

    Heuristique, pas une reconnaissance générale : une poche est ici « une
    face plane horizontale plus basse que le dessus de la pièce, mais pas
    le dessous du bloc lui-même ». Sans l'exclusion du dessous, le fond du
    brut (z = ZMin, une face plane horizontale comme une autre) se fait
    prendre pour une poche — constaté sur le premier essai : 2 faces
    trouvées sur un bloc à une seule poche, l'une d'elles étant le dessous.
    Une poche inclinée, ou creusée dans une autre poche, échappe à ce test.
    """
    box = shape.BoundBox
    z_top, z_bottom = box.ZMax, box.ZMin
    names = []
    for i, face in enumerate(shape.Faces, start=1):
        if face.Surface.TypeId != "Part::GeomPlane":
            continue
        normal = face.normalAt(0, 0)
        if abs(normal.z) < 0.999:  # pas horizontale
            continue
        z = face.CenterOfMass.z
        if z < z_top - tolerance and z > z_bottom + tolerance:
            names.append(f"Face{i}")
    return names


def apply_tool(job, p: CutParams, log: Settings) -> None:
    """Outil et régimes. C'est le réglage le plus important du script.

    Le Tool Controller par défaut existe toujours, mais il porte la fraise par
    défaut de FreeCAD et ses avances sont à zéro tant que rien ne les règle —
    constaté : un G-code entier sans aucun F, et F0.00 sur le seul endroit qui
    en émet une. Le DIAMÈTRE, lui, ne se voit pas dans le G-code : il se voit
    sur la pièce, en trop ou en moins.
    """
    tc = job.Tools.Group[0]
    log.set(tc, "HorizFeed", f"{p.feed} mm/min", "outil.avance_coupe")
    log.set(tc, "VertFeed", f"{p.feed_plunge} mm/min", "outil.avance_plongee")
    log.set(tc, "HorizRapid", f"{p.rapid_xy} mm/min", "outil.rapide_xy")
    log.set(tc, "VertRapid", f"{p.rapid_z} mm/min", "outil.rapide_z")
    log.set(tc, "SpindleSpeed", float(p.spindle), "outil.broche_S")
    log.set(tc, "SpindleDir", "Forward", "outil.broche_sens")

    # Le diamètre vit sur le ToolBit, pas sur le contrôleur.
    bit = getattr(tc, "Tool", None)
    if bit is None:
        log.missing.append("outil.diametre (aucun ToolBit sur le contrôleur)")
        return
    if not log.set(bit, "Diameter", f"{p.tool_dia} mm", "outil.diametre"):
        return
    # Une fraise dont la hauteur de coupe utile serait plus courte que la
    # profondeur totale ferait plonger le corps de l'outil dans la pièce.
    # On ne l'impose pas — on la consigne si elle existe.
    for name, label in (("CuttingEdgeHeight", "outil.hauteur_coupe"),
                        ("Flutes", "outil.dents")):
        if hasattr(bit, name):
            log.applied[label] = str(getattr(bit, name))


def apply_stock(job, p: CutParams, log: Settings) -> None:
    """Marges du brut autour de la pièce.

    Les défauts de FreeCAD (1 mm partout) sont conservés, et c'est délibéré.
    Mettre 0 au-dessus serait plus rapide — moins de passes dans le vide —
    mais si la plaque est en réalité plus épaisse que la pièce, la première
    passe du contour attaque toute l'épaisseur excédentaire d'un coup au lieu
    de 0,2 mm. Sur une machine plafonnée par la vibration, c'est le geste à ne
    pas faire. La marge se déclare, elle ne se devine pas.
    """
    stock = getattr(job, "Stock", None)
    if stock is None:
        log.missing.append("brut (aucun objet Stock sur le Job)")
        return
    for name, value, label in (
        ("ExtXneg", p.stock_side, "brut.marge_X-"),
        ("ExtXpos", p.stock_side, "brut.marge_X+"),
        ("ExtYneg", p.stock_side, "brut.marge_Y-"),
        ("ExtYpos", p.stock_side, "brut.marge_Y+"),
        ("ExtZneg", 0.0, "brut.marge_Z-"),
        ("ExtZpos", p.stock_top, "brut.marge_Z+"),
    ):
        log.set(stock, name, f"{value} mm", label)


def apply_heights(job, p: CutParams, log: Settings) -> None:
    """Hauteurs de dégagement, réglées sur la feuille de montage.

    Les opérations tirent leurs `ClearanceHeight`/`SafeHeight` d'expressions
    liées à la SetupSheet : régler celle-ci les régit toutes, alors qu'écrire
    directement sur une opération se ferait écraser au recalcul.
    """
    sheet = getattr(job, "SetupSheet", None)
    if sheet is None:
        log.missing.append("hauteurs (aucune SetupSheet sur le Job)")
        return
    log.set(sheet, "ClearanceHeightOffset", f"{p.clearance} mm", "hauteur.degagement")
    log.set(sheet, "SafeHeightOffset", f"{p.safe} mm", "hauteur.securite")


def apply_depths(op, p: CutParams, log: Settings, label: str) -> None:
    """Profondeur de passe d'une opération — le plafond vibratoire."""
    log.set(op, "StepDown", f"{p.ap} mm", f"{label}.profondeur_passe")


def apply_pocket(op, p: CutParams, log: Settings) -> None:
    """Recouvrement et motif de la poche.

    `StepOver` s'exprime en POURCENTAGE du diamètre de l'outil, pas en
    millimètres : 0,5 mm sur une fraise Ø6 font 8 %, pas 0,5. Le défaut de
    FreeCAD est 100 % — le diamètre entier à chaque passe.
    """
    percent = max(1, min(100, round(100.0 * p.ae / p.tool_dia)))
    log.set(op, "StepOver", percent, "poche.recouvrement_%")
    log.applied["poche.recouvrement_mm"] = f"{p.tool_dia * percent / 100:.3f} mm"
    # Une spirale sortante garde l'outil dans la matière et évite les entrées
    # répétées d'un zigzag — sur une machine sensible au broutage, ce sont les
    # entrées qui font le bruit.
    log.set(op, "OffsetPattern", "Spiral", "poche.motif")
    log.set(op, "KeepToolDown", True, "poche.outil_reste_bas")


def apply_drilling(op, p: CutParams, log: Settings) -> None:
    """Débourrage et retrait au perçage.

    Sans débourrage, le copeau s'accumule dans le trou : sur une broche
    alimentée bien en dessous de sa puissance nominale, c'est ce qui la cale.
    Et le retrait au plan de dégagement entre deux trous (G98) fait monter et
    descendre Z à 300 mm/min pour rien — G99 s'arrête au plan de retrait.
    """
    if p.peck > 0:
        log.set(op, "PeckEnabled", True, "percage.debourrage")
        log.set(op, "PeckDepth", f"{p.peck} mm", "percage.pas_debourrage")
    else:
        log.set(op, "PeckEnabled", False, "percage.debourrage")
    log.set(op, "DwellEnabled", False, "percage.temporisation")
    log.set(op, "RetractMode", "G99", "percage.mode_retrait")


def build_job(step_path: str, p: CutParams):
    """Importe le STEP et construit le Job CAM. Lève ValueError si le
    fichier ne porte pas exactement un solide (assemblage non géré ici)."""
    doc = FreeCAD.newDocument("Piece")
    Import.insert(step_path, doc.Name)
    doc.recompute()
    FreeCAD.setActiveDocument(doc.Name)  # Job.Create() lit ActiveDocument

    features = [o for o in doc.Objects if o.TypeId == "Part::Feature"]
    if not features:
        raise ValueError(f"{step_path} : aucun solide importé")
    if len(features) > 1:
        raise ValueError(
            f"{step_path} : {len(features)} solides — assemblage non géré, "
            "une seule pièce attendue"
        )
    base = features[0]

    job = PathJob.Create("Job", [base], None)
    job.PostProcessor = "grbl"

    log = Settings()
    apply_tool(job, p, log)
    apply_stock(job, p, log)
    apply_heights(job, p, log)

    # Noms canoniques (pas de libellé français) : SetupSheet retrouve les
    # avances/vitesses par défaut d'une opération par ce nom exact — un nom
    # personnalisé le laisse sans réglage (constaté : F0.00 sur le
    # perçage tant que l'opération s'appelait « Percage »).
    pocket_faces = find_pocket_faces(base.Shape)
    pocket = None
    if pocket_faces:
        pocket = PathPocket.Create("Pocket", parentJob=job)
        pocket.Base = [(base, pocket_faces)]
        apply_depths(pocket, p, log, "poche")
        apply_pocket(pocket, p, log)

    drill = PathDrilling.Create("Drilling", parentJob=job)
    # Base déjà rempli par findAllHoles(), appelé dans Create().
    apply_drilling(drill, p, log)

    contour = PathProfile.Create("Profile", parentJob=job)
    # Base laissée vide : silhouette extérieure globale, sans sélection.
    apply_depths(contour, p, log, "contour")

    doc.recompute()

    # ORDRE D'USINAGE — c'est lui que le post-processeur suit, et il compte
    # autant que les réglages. Le contour extérieur détache la pièce du brut :
    # tout ce qui vient après s'exécute sur une pièce qui ne tient plus. On
    # vide donc les poches d'abord, on perce ensuite (le foret trouve une
    # pièce encore bridée), et on détoure en dernier.
    ops = [o for o in (pocket, drill, contour) if o is not None]
    n_holes = len(drill.Base) if drill.Base else 0
    return doc, job, ops, pocket_faces, n_holes, log


def _import_grbl_post():
    try:
        import grbl_post
        return grbl_post
    except ImportError:
        sys.path.append(
            FreeCAD.getHomePath() + "Mod/CAM/Path/Post/scripts"
        )
        import grbl_post
        return grbl_post


def parse_args(argv: list[str]) -> tuple[str, str, CutParams]:
    """Arguments, sans argparse.

    freecadcmd place son propre chemin en argv[0] et celui du script en
    argv[1] (pas le script en argv[0] comme un interpréteur Python normal)
    — vérifié empiriquement, pas supposé. argparse, lui, suppose l'inverse
    pour composer son message d'usage ; on découpe donc à la main.
    """
    args = argv[2:]
    positional = [a for a in args if not a.startswith("--")]
    if len(positional) < 2:
        raise ValueError(
            "usage : freecadcmd prismatic_to_gcode.py <piece.step> <sortie.nc> "
            "[--outil D] [--ap P] [--ae R] [--avance F] [--plongee F] "
            "[--broche S] [--debourrage P] [--brut-marge M] [--brut-dessus M]"
        )

    values: dict[str, float] = {}
    i = 0
    while i < len(args):
        if args[i].startswith("--"):
            if i + 1 >= len(args):
                raise ValueError(f"{args[i]} attend une valeur")
            try:
                values[args[i][2:]] = float(args[i + 1])
            except ValueError:
                raise ValueError(f"{args[i]} : « {args[i + 1]} » n'est pas un nombre")
            i += 2
        else:
            i += 1

    base = CutParams()
    p = CutParams(
        tool_dia=values.get("outil", base.tool_dia),
        ap=values.get("ap", base.ap),
        ae=values.get("ae", base.ae),
        feed=values.get("avance", base.feed),
        feed_plunge=values.get("plongee", base.feed_plunge),
        spindle=int(values.get("broche", base.spindle)),
        peck=values.get("debourrage", base.peck),
        stock_side=values.get("brut-marge", base.stock_side),
        stock_top=values.get("brut-dessus", base.stock_top),
    )
    if p.tool_dia <= 0:
        raise ValueError("--outil doit être positif")
    if p.ap <= 0 or p.ae <= 0:
        raise ValueError("--ap et --ae doivent être positifs")
    return positional[0], positional[1], p


def main() -> int:
    try:
        step_path, out_path, p = parse_args(sys.argv)
    except ValueError as exc:
        print(f"REFUS : {exc}")
        return 1

    try:
        doc, job, ops, pocket_faces, n_holes, log = build_job(step_path, p)
    except ValueError as exc:
        print(f"REFUS : {exc}")
        return 1

    grbl_post = _import_grbl_post()
    grbl_post.export(ops, out_path, "--no-show-editor")

    with open(out_path, encoding="utf-8") as f:
        n_lignes = sum(1 for _ in f)

    # Rapport en fichier à part, même convention que step_to_gcode.py : un
    # appelant (l'agent IA, via sous-processus) lit ce fichier plutôt que de
    # parser la sortie texte, qui porte aussi les journaux de FreeCAD.
    report_path = out_path.rsplit(".", 1)[0] + "_rapport.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "operations": [o.Name for o in ops],
                "ordre_usinage": [o.Name for o in ops],
                "faces_poche": pocket_faces,
                "percages_detectes": n_holes,
                "lignes_gcode": n_lignes,
                "gcode_path": out_path,
                "outil_diametre_mm": p.tool_dia,
                "ap_mm": p.ap,
                "ae_mm": p.ae,
                "avance_mm_min": p.feed,
                "reglages_appliques": log.applied,
                "reglages_non_appliques": log.missing,
            },
            f,
            indent=2,
            ensure_ascii=False,
        )

    print(f"{step_path} : {len(pocket_faces)} face(s) de poche, {n_holes} perçage(s)")
    print(f"outil Ø{p.tool_dia} - ap {p.ap} - ae {p.ae} - F{p.feed:.0f}")
    print(f"ordre : {' -> '.join(o.Name for o in ops)}")
    print(f"{len(ops)} opération(s), {n_lignes} lignes -> {out_path}")
    if log.missing:
        print(
            f"ATTENTION : {len(log.missing)} réglage(s) non appliqué(s) — "
            "cette version de FreeCAD ne connaît pas ces propriétés :"
        )
        for name in log.missing:
            print(f"  - {name}")
    print(f"rapport -> {report_path}")
    return 0


# freecadcmd exécute le script avec __name__ = son nom de fichier, jamais
# "__main__" (vérifié empiriquement) — la garde habituelle ne se
# déclencherait donc jamais. Appel inconditionnel.
raise SystemExit(main())
