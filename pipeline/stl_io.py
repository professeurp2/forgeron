"""Lecture et écriture de fichiers STL, en numpy pur.

Aucune dépendance en dehors de numpy. C'est délibéré : `trimesh` provoque une
erreur de segmentation sur Python 3.15.0b1 (une de ses dépendances compilées
n'est pas prête pour cette bêta), et le format STL est assez simple pour être
lu directement.

Le STL binaire tient en trois règles :
    80 octets      en-tête libre, ignoré
     4 octets      uint32 : nombre de triangles
    50 octets      par triangle : 12 float32 (normale + 3 sommets) + 2 octets

Le STL ASCII est du texte, plus lourd mais courant en sortie de CAO. Les deux
sont gérés ; la détection ne se fie pas au mot « solid » du début — beaucoup de
fichiers binaires commencent ainsi — mais à la taille du fichier, qui vaut
exactement 84 + 50 n pour un binaire.
"""

from __future__ import annotations

import struct

import numpy as np

_HEADER = 80
_COUNT = 4
_TRI = 50


def _looks_binary(raw: bytes) -> bool:
    """Un STL binaire a une taille EXACTEMENT égale à 84 + 50 × n."""
    if len(raw) < _HEADER + _COUNT:
        return False
    n = struct.unpack_from("<I", raw, _HEADER)[0]
    return len(raw) == _HEADER + _COUNT + n * _TRI


def read_stl(path: str) -> np.ndarray:
    """Retourne les triangles sous forme (n, 3, 3) : n triangles, 3 sommets, xyz."""
    with open(path, "rb") as f:
        raw = f.read()

    if _looks_binary(raw):
        n = struct.unpack_from("<I", raw, _HEADER)[0]
        # dtype structuré : on saute la normale et les 2 octets d'attribut.
        dt = np.dtype(
            [("normal", "<f4", 3), ("v", "<f4", (3, 3)), ("attr", "<u2")]
        )
        data = np.frombuffer(raw, dtype=dt, count=n, offset=_HEADER + _COUNT)
        return np.asarray(data["v"], dtype=np.float64)

    # ASCII : on ne retient que les lignes « vertex x y z ».
    text = raw.decode("utf-8", errors="replace")
    coords = [
        [float(x) for x in line.split()[1:4]]
        for line in text.splitlines()
        if line.strip().lower().startswith("vertex")
    ]
    if not coords or len(coords) % 3 != 0:
        raise ValueError(f"{path} : STL illisible ou incomplet")
    return np.asarray(coords, dtype=np.float64).reshape(-1, 3, 3)


def write_stl(path: str, triangles: np.ndarray, header: str = "forgeron") -> None:
    """Écrit un STL binaire. [triangles] a la forme (n, 3, 3)."""
    tris = np.asarray(triangles, dtype=np.float32)
    if tris.ndim != 3 or tris.shape[1:] != (3, 3):
        raise ValueError("triangles doit avoir la forme (n, 3, 3)")

    # Normale par produit vectoriel, normalisée. Les lecteurs s'en servent peu
    # (ils recalculent), mais un STL sans normales cohérentes est mal vu.
    e1 = tris[:, 1] - tris[:, 0]
    e2 = tris[:, 2] - tris[:, 0]
    normals = np.cross(e1, e2)
    norms = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = np.divide(normals, norms, out=np.zeros_like(normals), where=norms > 0)

    dt = np.dtype([("normal", "<f4", 3), ("v", "<f4", (3, 3)), ("attr", "<u2")])
    rec = np.zeros(len(tris), dtype=dt)
    rec["normal"] = normals
    rec["v"] = tris

    with open(path, "wb") as f:
        f.write(header.encode("ascii", "replace")[:_HEADER].ljust(_HEADER, b"\0"))
        f.write(struct.pack("<I", len(tris)))
        f.write(rec.tobytes())


def vertices_of(triangles: np.ndarray) -> np.ndarray:
    """Sommets uniques, forme (m, 3). Suffit pour analyser une forme."""
    flat = triangles.reshape(-1, 3)
    return np.unique(np.round(flat, 6), axis=0)


def revolve(profile_rz: np.ndarray, n_around: int = 96) -> np.ndarray:
    """Maillage de révolution autour de Z à partir d'un profil (r, z).

    Sert à fabriquer des cas de test dont on connaît la réponse exacte, sans
    dépendre d'un fichier extérieur.
    """
    prof = np.asarray(profile_rz, dtype=np.float64)
    phi = np.linspace(0.0, 2.0 * np.pi, n_around, endpoint=False)
    cos, sin = np.cos(phi), np.sin(phi)

    # Grille (profil × angle) de points 3D.
    r = prof[:, 0][:, None]
    z = prof[:, 1][:, None]
    pts = np.stack(
        [r * cos[None, :], r * sin[None, :], np.repeat(z, n_around, axis=1)],
        axis=-1,
    )  # (n_prof, n_around, 3)

    tris = []
    n_prof = len(prof)
    for i in range(n_prof - 1):
        for j in range(n_around):
            j2 = (j + 1) % n_around
            a, b = pts[i, j], pts[i, j2]
            c, d = pts[i + 1, j2], pts[i + 1, j]
            tris.append([a, b, c])
            tris.append([a, c, d])
    return np.asarray(tris, dtype=np.float64)
