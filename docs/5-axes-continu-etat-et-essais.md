# 5 axes continu — état et essais sur machine

*1ᵉʳ novembre 2026. Tout ce document est mesuré **hors machine**, par rejeu du G-code (`pipeline/verify5.py`). La machine n'était pas joignable depuis le PC : aucun essai réel n'a eu lieu.*

## Verdict

- **Le contrôleur et l'app savent exécuter du 5 axes continu** : un dôme écrit à part a déjà tourné à vide le 24 août, sans perte de pas.
- **Le CAM ne savait pas en produire de sûr.** Rejeu du générateur précédent sur un simple dôme :

| Défaut mesuré | Valeur |
|---|---|
| Pénétration à l'ébauche | 18,8 mm, 6 645 blocs |
| Pénétration à la finition | 9,9 mm |
| Ébauche et finition | pas dans le même repère (8 mm d'écart, pièce sous la table du modèle) |

> **Ne pas exécuter** les `.nc` générés par `medical_implant.py` avant cette correction, ni `gen_surface5.py`, qui reste en l'état mais n'est plus appelé pour produire des programmes.

## Ce qui a changé

| Brique | Rôle |
|---|---|
| `pipeline/continuous5.py` | Ébauche + finition A/C simultanés, depuis un STEP ou un STL |
| `pipeline/verify5.py` | Rejoue le G-code, juge indépendamment. **Un programme refusé n'est pas écrit en `.nc`** |
| `pipeline/medical_implant.py` | Utilise ce générateur et cette garde ; c'est la voie appelée par l'app |
| `GcodeCritic` | Mesure l'avance dans le repère pièce quand le programme déclare son pivot ; ne juge plus les G0 |
| Aperçu du parcours | Utilise le pivot déclaré par le programme |

**Zéro pièce :** G54 X/Y sur l'axe C, Z sur le dessus du brut, à A=0 et C=0. Le pivot est calculé à *hauteur pièce + cale + 8 mm* sous ce zéro et écrit dans le programme.

## Résultats sur les fichiers disponibles

Paramètres : ap 1, ae 2, pas 0,8 mm, fraise boule Ø6, sortie d'outil 18 mm. **Ces ap et ae ne sont pas validés en coupe** : ils servent au calcul. Le plafond mesuré en aluminium reste ap 0,2 et ae 0,5.

| Pièce | Verdict | Détail |
|---|---|---|
| Dôme R20 (test) | **Accepté** | 0 pénétration, 0 collision, A jusqu'à −45°, avance réelle 80–150 mm/min en finition |
| `IMPELLER.STP` | **Accepté, mais ce n'est pas la turbine** | Échelle ×0,374. **24,5 % de la surface atteinte** : les pales en contre-dépouille ne sont pas usinées. Durée ≥ 527 min |
| `rend.step` (implant crânien) | **Refusé** | 2 blocs à 0,081 mm de pénétration (tolérance 0,05), à résoudre. Échelle ×0,46 |

## Limites

1. **Une seule face, vue du dessus.** Pas de contre-dépouille : A et C servent à incliner l'outil sur la surface visible, pas encore à contourner la pièce. C'est le prochain vrai chantier pour une turbine.
2. **Flancs à plus de 68° non repris en finition** : il y reste la surépaisseur d'ébauche (0,3 mm).
3. **Brides et montage absents du modèle** : aucune collision avec eux n'est détectée. Le porte-outil est supposé (rayon 12, longueur 40 mm).
4. **Durée :** les programmes réels durent plus de 8 h, pour des redémarrages thermiques déjà observés vers 25–35 min en armoire non refroidie. `GcodeCritic` le signale sans bloquer.
5. **Position du G54 dans les courses :** seule l'excursion est vérifiée, pas sa place absolue.
6. **Avance :** plafonnée par `F ≤ 500` (ForceGuard), d'où une finition souvent à ~110 mm/min au lieu des 150 visés. Les accélérations ne sont pas simulées.
7. **`G93` :** le support reste non confirmé sur cette carte. Le programme compense F bloc par bloc en G94.

## Essais sur machine, dans l'ordre

Sans outil ni pièce, main sur l'arrêt d'urgence. **Rappel : l'arrêt d'urgence matériel reste à confirmer** (contact NF en série sur la puissance de broche).

1. **Sens de A et C — bloquant.** Toute la chaîne suppose `Rx(+A)` : le bord +Y du plateau monte quand A augmente, et `Rz(+C)` : rotation anti-horaire vue du dessus. Commander `G0 A-10`, regarder, revenir ; idem `G0 C10`. Si le sens diffère, ne rien lancer et me le dire.
2. **`d` et position de l'axe C :** vérifier les 8 mm et que l'axe C passe bien par le G54.
3. **`G93` sans mouvement :** `G93`, `$G`, `G94`, `$G` dans le MDI, juste pour lire si la carte l'accepte.
4. **Essai à vide :** `test/fixtures/dome5_continu.nc` (broche jamais allumée, durée minimale 14 min). Vérifier mentalement au M0 le zéro : la pointe doit suivre un point fixe de la table quand elle tourne.
5. **Première coupe :** dôme dans du bois ou de la cire, seulement après 1 à 4, puis mesure de la pièce au pied à coulisse.

Générer un programme :

```bash
pipeline/.venv312/Scripts/python pipeline/continuous5.py piece.step --echelle-auto --a-vide
```
