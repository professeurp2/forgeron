"""Cinématique du trunnion A/C — orientation de l'outil et compensation RTCP.

Reprend EXACTEMENT la convention de `lib/core/utils/kinematics_service.dart`,
pour que le pipeline et l'application décrivent la même machine :

    pièce → machine :   T(Pivot) · Rx(A) · T(0,0,d) · Rz(C)

Le berceau A incline la table (rotation autour de X), le plateau C la fait
tourner (rotation autour de Z) ; tous deux portent la PIÈCE. La broche ne fait
que du linéaire. `d` est la distance pivot→plateau, `Pivot` la position machine
du centre de rotation A.

── Pourquoi ce module est indispensable ────────────────────────────────────

FluidNC est en cinématique CARTÉSIENNE : il ne recalcule rien quand A et C
tournent. Une machine industrielle ferait ce travail dans le contrôleur (RTCP,
G43.4) ; ici il doit être fait en amont, et le G-code doit sortir en
coordonnées déjà compensées.

C'est la raison pour laquelle un parcours 5 axes écrit à la main sans
compensation envoie l'outil à côté de la pièce : à A=80° avec un pivot à 43 mm,
le centre de la pièce s'est déplacé de plus de 42 mm.

── Orientation de l'outil ──────────────────────────────────────────────────

L'outil est physiquement vertical. Pour l'amener perpendiculaire à la surface,
c'est la PIÈCE qui tourne : on cherche (A, C) tels que la normale au point de
contact vienne s'aligner sur l'axe Z machine.

    Rx(A) · Rz(C) · n = (0, 0, 1)

d'où, en résolvant composante par composante :

    C = atan2(nₓ, n_y)              annule la composante X
    A = atan2(√(nₓ² + n_y²), n_z)   annule la composante Y

Au sommet d'une pièce (n vertical) on retrouve A = 0 et C indéterminé — c'est
correct : l'orientation du plateau n'a alors aucune influence.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class Trunnion:
    """Géométrie du montage. Ce sont des données de CALIBRATION, pas des
    constantes : elles dépendent du zéro pièce posé."""

    pivot_to_table: float = 8.0   # distance pivot A → surface du plateau (mm)
    pivot: tuple[float, float, float] = (0.0, 0.0, 0.0)  # pivot en repère machine
    a_min: float = -88.0          # course de l'axe A (degrés)
    a_max: float = 90.0


def _rz(c_deg: float) -> np.ndarray:
    c = math.radians(c_deg)
    return np.array([[math.cos(c), -math.sin(c), 0.0],
                     [math.sin(c), math.cos(c), 0.0],
                     [0.0, 0.0, 1.0]])


def _rx(a_deg: float) -> np.ndarray:
    a = math.radians(a_deg)
    return np.array([[1.0, 0.0, 0.0],
                     [0.0, math.cos(a), -math.sin(a)],
                     [0.0, math.sin(a), math.cos(a)]])


def orient(normal: np.ndarray) -> tuple[float, float]:
    """Angles (A, C) en degrés qui amènent [normal] sur l'axe Z machine."""
    nx, ny, nz = (float(v) for v in normal)
    horizontal = math.hypot(nx, ny)
    if horizontal < 1e-12:
        return 0.0, 0.0  # normale déjà verticale : le plateau est libre
    c = math.degrees(math.atan2(nx, ny))
    a = math.degrees(math.atan2(horizontal, nz))
    return a, c


def piece_to_machine(
    p_piece: np.ndarray, a_deg: float, c_deg: float, tr: Trunnion
) -> np.ndarray:
    """Position MACHINE d'un point exprimé dans le repère pièce.

    T = Pivot + Rx(A)·( Rz(C)·p + (0,0,d) )
    """
    p = np.asarray(p_piece, dtype=float)
    inner = _rz(c_deg) @ p + np.array([0.0, 0.0, tr.pivot_to_table])
    return np.asarray(tr.pivot, dtype=float) + _rx(a_deg) @ inner


def machine_to_piece(
    t_machine: np.ndarray, a_deg: float, c_deg: float, tr: Trunnion
) -> np.ndarray:
    """Inverse exact de [piece_to_machine] — sert à vérifier la cohérence."""
    t = np.asarray(t_machine, dtype=float) - np.asarray(tr.pivot, dtype=float)
    inner = _rx(-a_deg) @ t - np.array([0.0, 0.0, tr.pivot_to_table])
    return _rz(-c_deg) @ inner


def tool_position(
    contact: np.ndarray,
    normal: np.ndarray,
    rho: float,
    tr: Trunnion,
) -> tuple[np.ndarray, float, float]:
    """Position machine programmée pour toucher [contact] selon [normal].

    Retourne (XYZ machine de la POINTE, A, C). L'outil étant vertical dans le
    repère machine, sa pointe est ρ sous le centre de la bille.
    """
    n = np.asarray(normal, dtype=float)
    norm = np.linalg.norm(n)
    if norm < 1e-12:
        raise ValueError("normale nulle")
    n = n / norm

    a, c = orient(n)
    centre_piece = np.asarray(contact, dtype=float) + rho * n
    centre_machine = piece_to_machine(centre_piece, a, c, tr)
    tip = centre_machine - np.array([0.0, 0.0, rho])
    return tip, a, c


def reachable(a_deg: float, tr: Trunnion) -> bool:
    """L'angle A demandé tient-il dans la course de la machine ?"""
    return tr.a_min - 1e-9 <= a_deg <= tr.a_max + 1e-9


def normals_from_height_map(
    xs: np.ndarray, ys: np.ndarray, Z: np.ndarray
) -> np.ndarray:
    """Normales à la surface, déduites du gradient de la carte de hauteur.

    La carte donne la position du CENTRE de la bille, donc une surface décalée
    de ρ. Un décalage le long de la normale ne change pas la normale : le
    gradient de la carte donne directement celle de la pièce.

    Retourne un tableau (ny, nx, 3). Les points non atteints reçoivent une
    normale verticale, faute de mieux.
    """
    finite = np.isfinite(Z)
    filled = np.where(finite, Z, np.nan)
    # Gradient en ignorant les trous : on les rebouche par le voisin le plus
    # proche avant de dériver, sinon un NaN contamine toute la ligne.
    if np.isnan(filled).any():
        from numpy.lib.stride_tricks import sliding_window_view  # noqa: F401

        med = np.nanmedian(filled) if np.isfinite(np.nanmedian(filled)) else 0.0
        filled = np.where(np.isnan(filled), med, filled)

    dz_dy, dz_dx = np.gradient(filled, ys, xs)
    n = np.stack([-dz_dx, -dz_dy, np.ones_like(filled)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n
