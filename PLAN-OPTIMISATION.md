# Plan d'optimisation — ce que cette machine impose

État au 13 septembre 2026. Complète [`PLAN-IA.md`](PLAN-IA.md) (la perception et
le pipeline CAO → parcours) et [`ARCHITECTURE.md`](ARCHITECTURE.md) (la frontière
entre l'IA et le calcul déterministe).

Objet : **réduire le temps d'usinage et supprimer les collisions**, en partant
des caractéristiques réelles de CETTE machine — pas d'un centre d'usinage
générique. Tous les chiffres ci-dessous viennent de
`scratch/config_5axes_production.yaml` et du code ; aucun n'est inventé.

---

## 0. Les chiffres qui commandent tout

### Cinématique (config FluidNC de production)

| Axe | pas | F max | Accélération | Course | Soft limits |
|---|---|---|---|---|---|
| X | 264 pas/mm (vis 3 mm) | 500 mm/min | 30 mm/s² | 88 mm | oui |
| Y | 400 pas/mm (vis 2 mm) | 500 mm/min | 30 mm/s² | 150 mm | oui |
| Z | 400 pas/mm (vis 2 mm) | 300 mm/min | 20 mm/s² | 110 mm | oui |
| A | 16,667 pas/° (GT2 16→60, micro 1/8) | 3600 °/min | 50 °/s² | 178° (−88 → +90) | oui |
| C | 16,667 pas/° | 3600 °/min | 50 °/s² | 720° | **non** |

### Ce que l'accélération en fait réellement

C'est le chiffre le plus important du document, et il n'apparaît nulle part dans
le logiciel aujourd'hui. Distance nécessaire pour atteindre la vitesse maximale,
`v² / 2a` :

| Axe | Distance pour atteindre F max | Longueur minimale d'un mouvement qui atteint F max |
|---|---|---|
| X / Y | 1,16 mm | **2,31 mm** |
| Z | 0,63 mm | **1,25 mm** |
| A / C | 36° | **72°** |

En dessous de ces longueurs, le mouvement est **triangulaire** : il accélère,
atteint `√(a·L)`, et freine. Il n'atteint jamais le F écrit.

| Mouvement | F réellement atteint | Durée réelle | Durée si on ignore l'accélération | Écart |
|---|---|---|---|---|
| 0,4 mm en X/Y (le stepover de finition par défaut) | 208 mm/min | 0,231 s | 0,048 s | **× 4,8** |
| 1,0 mm en X/Y | 329 mm/min | 0,365 s | 0,120 s | × 3,0 |
| 1° sur A ou C | 424 °/min | 0,283 s | 0,017 s | **× 17** |
| 5° sur A ou C | 949 °/min | 0,632 s | 0,083 s | **× 7,6** |

> **Sur un parcours de finition 5 axes, le temps est dominé par les rotations,
> et le logiciel ne le sait pas.** Une réorientation de 1° coûte 0,28 s — six
> fois le coût du déplacement linéaire qui l'accompagne.

### Électricité

| Élément | Fait | Conséquence pour l'optimisation |
|---|---|---|
| Broche | moteur DC, **tout-ou-rien** par relais gpio.21, `speed_map: 0=0% 1000=100%` | La vitesse de coupe n'est **pas** une variable. La seule variable libre est l'avance (et l'engagement). |
| Broche | `spinup_ms: 1000`, `spindown_ms: 1000` | Chaque cycle M3/M5 coûte **2 s** de temps mort. |
| Alim broche | chargeur PC 19,5 V / 3,3 A ≈ 64 W, sous-dimensionnée, étincelles à l'appel | Minimiser le **nombre de démarrages**, pas seulement leur durée. |
| Drivers | 5 × TB6600, `idle_ms: 255` (jamais désactivés) | Chaleur permanente, même à l'arrêt. |
| Carte | redémarrages thermiques observés vers **25–35 min** (cf. `GcodeCritic.maxMinutes`) | La durée d'un programme est une **contrainte dure**, pas un critère de confort. |
| Alarme | `off_on_alarm: true` | Une alarme coupe la broche : un dépassement de soft-limit en plein usinage marque la pièce. |

`must_home: true` : aucun mouvement n'est possible avant `$H`. A se home sur
gpio.5 (capteur à −88°, cycle validé) ; **C n'a aucun capteur** — son origine est
celle où il se trouvait à la mise sous tension, ce dont les briques 4 et 5
doivent tenir compte.

---

## 1. Les trois choses qui empêchent d'optimiser aujourd'hui

### 1.1 L'horloge est fausse

`GcodeCritic.review()` estime la durée ainsi :

```dart
minutes += math.sqrt(linear * linear + angular * angular) / effective;
```

Vitesse constante, pas d'accélération, pas de décélération, pas de jonction
entre blocs. Sur les longueurs de segment que produit réellement le pipeline
(0,4 mm de stepover, quelques degrés de réorientation), cette estimation est
**optimiste d'un facteur 3 à 17** — voir le tableau ci-dessus.

Une optimisation qui s'appuie sur cette horloge optimise la mauvaise chose : elle
va raboter des millimètres de trajet à vide pendant que le vrai coût est dans les
rotations qu'elle ne voit pas.

**Rien d'autre ne peut être construit avant d'avoir corrigé ça.**

### 1.2 Les limites ont trois sources de vérité qui se contredisent

| Source | Course X | Course Y | Course Z | Plage A | Utilisée par |
|---|---|---|---|---|---|
| `TrunnionConfig` (valeurs par défaut Dart) | 200 | 300 | **150** | **±90** | `TrajectoryValidator` |
| `GcodeCritic` (constantes par défaut) | 88 | 150 | 110 | −88 → +90 | la critique de l'agent |
| `axisKinematicsProvider` (config FluidNC lue en direct) | 88 | 150 | 110 | −88 → +90 | le visualiseur 3D seulement |

Conséquences concrètes, aujourd'hui, en production :

- **`TrajectoryValidator` laisse passer un programme qui descend à Z−149** alors
  que la course réelle est 110 mm. FluidNC alarmera en plein usinage, broche
  coupée, pièce marquée.
- Il laisse passer **A = −89,9°** alors que la butée réelle est à −88°.
- Il **ne vérifie ni X ni Y du tout** — les deux axes les plus courts de la
  machine (88 mm en X).
- Il compare des **coordonnées pièce** à des **limites machine**, sans passer par
  l'offset G54. Même avec les bonnes valeurs, la comparaison n'aurait pas de sens.

### 1.3 Un écart de calibration non tranché sur C

La config note, pour l'axe C :

> `# (identique à A ; la mesure C donnait ~19,8, écart = imprécision).`

19,8 contre 16,667, c'est **19 % d'écart**. Si la mesure était juste, une rotation
commandée de 360° en produit 302°. Sur une pièce de révolution finie en 5 axes,
cet écart n'est pas de l'imprécision : c'est une pièce fausse, et un modèle de
collision qui croit le berceau ailleurs qu'il n'est.

À trancher par une mesure propre (comparateur ou disque gradué, 10 tours) avant
toute optimisation d'orientation. Ce n'est pas une brique logicielle, c'est un
préalable métrologique d'une demi-heure.

---

## 2. Les briques

Une brique = un module indépendant, testable seul, remplaçable par une meilleure
version sans toucher aux autres. Pas d'optimiseur monolithique : chacune peut
être améliorée séparément, et une brique naïve qui marche vaut mieux qu'une
brique savante qui n'existe pas.

Chaque brique est décrite par : ce qu'elle lit, ce qu'elle rend, où elle vit,
**comment on sait qu'elle marche**, et à quoi ressemblerait sa version suivante.

---

### Brique 0 — `MachineLimits` : une seule source de vérité

**Rend** un objet unique portant, pour chaque axe, la plage en **coordonnées
machine**, la vitesse max, l'accélération — lus de la config FluidNC vivante,
avec un repli explicite sur le dernier cache connu, et **jamais** de valeur
inventée.

La primitive existe déjà : `AxisKinematics.machineRange` gère correctement le cas
asymétrique de A (capteur à −88, course 178 → −88 → +90). Il ne manque que de
faire converger les consommateurs dessus.

**Lit** `axisKinematicsProvider`, plus l'offset WCS actif (`get_wcs_offsets`,
déjà exposé à l'agent) pour convertir pièce → machine.

**Vit** dans `lib/domain/models/machine_limits.dart` (nouveau).

**À corriger dans la foulée** : `TrajectoryValidator` prend `MachineLimits` au
lieu de `TrunnionConfig` et vérifie X, Y, Z, A **et** C. `GcodeCritic` prend les
mêmes valeurs au lieu de ses constantes. `TrunnionConfig` ne garde que ce qui est
vraiment mécanique et absent de la config FluidNC : `pivotToTableOffset`,
`singularityZone`, les efforts. Ses champs de course et de démultiplication,
hérités du dimensionnement PFE et contredits par la machine construite
(GT2 16→60 et micro 1/8 en réalité, pas 20→120 et 1/16), sont supprimés plutôt
que corrigés : deux valeurs justes finissent toujours par diverger.

**On sait qu'elle marche quand** : un programme fabriqué exprès pour descendre à
Z−120 est refusé avec la bonne ligne et la bonne raison, et le même programme
avec un zéro pièce 30 mm plus haut est accepté.

**Version suivante** : relire la config au retour d'un `$$` plutôt qu'au
démarrage, pour suivre un réglage changé à chaud (`fluidNcSetCommand` existe
déjà).

---

### Brique 1 — `TimeModel` : une horloge qui connaît l'accélération

**Rend**, pour un parcours, une durée et surtout un **profil** : par bloc, la
vitesse réellement atteinte, le temps, et la cause de la limite (accélération,
F max d'un axe, plafond ForceGuard, bloc mixte).

**Modèle minimal, suffisant pour commencer** — trapèze par bloc, arrêt à chaque
jonction :

```
L ≥ v²/a   →  trapèze :   t = L/v + v/a
L <  v²/a  →  triangle :  t = 2·√(L/a),  v_pic = √(a·L)
```

avec `v` = min(F écrit, F max de l'axe le plus lent engagé) et `a` = accélération
de l'axe le plus lent engagé.

Ce modèle **sous-estime** le gain de la mise en vitesse de GRBL entre deux blocs
alignés (il suppose un arrêt franc à chaque jonction), donc il est pessimiste.
C'est le bon sens de l'erreur : mieux vaut annoncer 40 min et en faire 32 que
l'inverse, surtout avec une carte qui redémarre vers 25–35 min.

**Vit** dans `lib/core/utils/time_model.dart` (nouveau). `GcodeCritic` l'appelle
au lieu de sa division ; le reste de sa critique ne bouge pas.

**On sait qu'elle marche quand** : sur trois programmes réels chronométrés à la
montre, l'écart est sous 15 %. Aujourd'hui il est de l'ordre de 300 à 500 %.
Cette mesure est à faire **avant** d'écrire la brique, pour avoir un point de
comparaison — trois `$H` + trois chronos, une heure de travail.

**Version suivante** : jonction à vitesse non nulle selon l'angle entre blocs
(le « junction deviation » de GRBL), qui est ce qui fait vraiment la différence
sur un parcours dense. Puis mesure de l'accélération réelle en charge — la valeur
de 30 mm/s² est un réglage, pas une mesure ; si les moteurs décrochent en dessous,
tout le modèle est faux vers le haut.

---

### Brique 2 — `FeedTruth` : l'avance que la machine appliquera vraiment

Le piège est déjà détecté par `GcodeCritic` (`avance_ecrasee_par_la_rotation`),
il reste à en faire un outil de correction plutôt qu'un simple constat.

GRBL mesure la longueur d'un bloc sur `√(Σmm² + Σdeg²)` — il additionne des
millimètres et des degrés. Sur un bloc qui avance de 0,4 mm en tournant de 5° :

```
longueur mixte = √(0,4² + 5²) = 5,016
part linéaire  = 0,4 / 5,016 = 7,97 %
F300 écrit     → 24 mm/min d'avance linéaire réelle
```

**Rend** deux services : (a) le facteur de perte par bloc, et (b) le F compensé
`F = v_voulue × L_mixte / L_linéaire`, borné par le plafond ForceGuard du mode.

**Vit** à côté du `TimeModel`, et s'insère dans le post-traitement du pipeline
Python (`gen_surface5.py`) — c'est là que le bloc est écrit, pas dans l'app.

**On sait qu'elle marche quand** : sur un parcours 5 axes, l'avance linéaire
mesurée (distance parcourue ÷ temps chronométré) est à moins de 10 % de l'avance
voulue, au lieu du facteur 45 documenté.

**Attention** : compenser F augmente la vitesse des axes rotatifs. La brique doit
refuser une compensation qui ferait dépasser 3600 °/min sur A ou C, et le dire —
sinon on remplace une avance trop lente par un décrochage moteur.

---

### Brique 3 — `EnvelopeGuard` : la validation en coordonnées machine

Ce que `TrajectoryValidator` aurait dû faire depuis le début.

**Pour chaque point du parcours** :
1. appliquer la cinématique directe (`KinematicsService.forward`, déjà écrite,
   `pivotToTableOffset = 8 mm`) pour obtenir la position réelle de la pointe
   d'outil quand le berceau bascule ;
2. ajouter l'offset WCS pour passer en coordonnées machine ;
3. comparer aux plages de la **brique 0**, sur les cinq axes.

**Rend** : le premier point fautif, l'axe, la valeur, la limite, et la ligne
source (`toolpathLineIndices` fait déjà la correspondance).

**On sait qu'elle marche quand** : aucun programme validé ne produit d'`ALARM:2`
(soft limit) en cours d'exécution. C'est binaire et mesurable sur le journal
d'activité, qui est déjà collecté.

**Version suivante** : vérifier aussi que la vitesse composée demandée reste
sous le F max de chaque axe pris séparément — un bloc qui demande 400 mm/min en
X et 3000 °/min en C simultanément peut dépasser la capacité de C sans dépasser
aucune limite prise isolément.

---

### Brique 4 — `Clearance` : la collision volumique

Les briques 0 et 3 empêchent de sortir de la course. Elles n'empêchent pas
l'outil de percuter le berceau, le plateau ou le bridage.

**Modèle volontairement grossier pour commencer** — et suffisant :

- outil = cylindre (Ø et longueur viennent de `Tool`, qui les porte déjà) ;
- porte-outil = cylindre plus gros au-dessus (un seul paramètre à ajouter) ;
- berceau + plateau = deux cylindres et un pavé, dans le repère C, donc mobiles
  avec A et C ;
- test = distance point-segment à chaque point du parcours, marge configurable.

Un modèle grossier qui tourne vaut mieux qu'un maillage exact qui n'existe pas.
Le faux positif (il refuse un parcours qui serait passé) est acceptable ; le faux
négatif ne l'est pas — donc les cylindres sont majorés, jamais minorés.

**Vit** en Python, dans le pipeline (`pipeline/clearance.py`), pour être appelable
avant même que le G-code existe, et testable sans la machine.

**On sait qu'elle marche quand** : une pièce haute inclinée à −80° est refusée,
et la même à −40° passe — vérifié à la main sur la machine, moteurs coupés.

---

### Brique 5 — `Orientation` : préférer 3+2 au 5 axes continu

C'est ici que se trouve le gros du temps, et c'est la conséquence directe du
tableau d'accélération : **une réorientation de 1° coûte 0,28 s**. Un parcours
qui réoriente à chaque point paie cette seconde-tiers des milliers de fois.

**Rend**, pour une surface donnée, un petit nombre d'orientations A/C fixes qui
la couvrent entièrement (chaque zone usinable en 3 axes depuis une orientation),
plutôt qu'une orientation continue.

Le gain est double et il est structurel :
- les rotations disparaissent du temps de coupe (quelques indexations au lieu de
  milliers de micro-rotations) ;
- en 3 axes, le plafond ForceGuard passe de **500 à 2000 mm/min** et la
  profondeur de passe de 0,3 à 2 mm (`MachiningMode`) — soit un régime de coupe
  quatre à six fois plus productif, sur une machine dont c'est justement le
  point faible.

**Méthode de départ** : grouper les normales de la surface par un k-means sur la
sphère (k petit, 3 à 6), retenir les orientations atteignables (brique 3) et sans
collision (brique 4), puis générer un parcours 3 axes par orientation.

**On sait qu'elle marche quand** : sur une pièce test, le temps mesuré est réduit
d'au moins moitié à état de surface équivalent. Si le gain est plus faible, c'est
que le découpage crée trop de raccords — et c'est la brique suivante à améliorer,
sans toucher au reste.

**Version suivante** : lissage des orientations à l'intérieur d'une zone quand le
continu est inévitable (SLERP à jerk limité, cf. `PLAN-IA.md` §1).

---

### Brique 6 — `Schedule` : trajets à vide et démarrages de broche

Une fois l'horloge juste (brique 1), ce qui reste visible en tête de profil se
range en trois postes :

1. **Les trajets à vide.** Ordonner les zones/perçages par un parcours court
   (plus proche voisin puis 2-opt — quelques dizaines de points, le calcul est
   instantané). Le gain est réel mais modeste : les rapides sont eux aussi
   plafonnés à 500 mm/min.
2. **La hauteur de dégagement.** Chaque remontée-descente coûte
   `2 × (hauteur / 5 mm/s)` plus 1,25 mm d'accélération. Descendre le plan de
   dégagement de 10 mm à 3 mm sur 200 perçages économise plusieurs minutes.
   À arbitrer avec la brique 4 : c'est exactement le réglage qui crée les
   collisions.
3. **Les démarrages de broche.** 2 s par cycle M3/M5, plus l'appel de courant sur
   une alimentation déjà limite. Regrouper les opérations qui partagent un outil
   et laisser la broche tourner entre elles.

**On sait qu'elle marche quand** : le profil de la brique 1 montre la part « hors
coupe » avant et après, et elle baisse. Sans ce profil, toute cette brique est
une opinion.

---

### Brique 7 — `ThermalBudget` : découper avant que la carte ne redémarre

La contrainte est dure : redémarrages observés vers 25–35 min, drivers jamais
désactivés (`idle_ms: 255`).

**Rend** un découpage du programme en tranches dont la durée estimée (brique 1,
donc juste) reste sous un budget configurable, avec pour chaque tranche une
reprise propre : retour au plan de dégagement, arrêt broche, et un point de
reprise en coordonnées machine.

**Deux choses à faire côté matériel, qui valent plus que le logiciel** :
ventiler l'armoire, et abaisser `idle_ms` pour que les drivers se coupent entre
les tranches. Le logiciel contourne le problème ; il ne le règle pas. À noter
tel quel dans le mémoire : c'est une limite du banc, pas une limite de la méthode.

**On sait qu'elle marche quand** : un programme de 90 min estimées s'exécute
entièrement en quatre tranches, sans redémarrage, avec une reprise qui ne laisse
pas de marque à la jonction.

---

## 3. Ordre de réalisation

Il n'est pas négociable : les trois premières se conditionnent.

| # | Brique | Pourquoi à ce rang |
|---|---|---|
| 1 | Mesure : 3 programmes chronométrés + calibration C | Sans référence, aucun gain n'est démontrable |
| 2 | **Brique 0** — limites | Tout le reste compare à des limites |
| 3 | **Brique 1** — horloge | Tout le reste se mesure en temps |
| 4 | **Brique 3** — enveloppe | Supprime les alarmes en cours d'usinage (sécurité avant gain) |
| 5 | **Brique 2** — avance réelle | Gain immédiat, indépendant du reste |
| 6 | **Brique 4** — collision volumique | Débloque la brique 5 |
| 7 | **Brique 5** — orientation 3+2 | Le gros du gain de temps |
| 8 | **Brique 6** — ordonnancement | Ce qui reste une fois le gros pris |
| 9 | **Brique 7** — tranches thermiques | Utile dès que les programmes s'allongent |

Les briques 0, 1, 2, 3 sont du calcul pur : testables sans machine, donc
développables et vérifiées par des tests avant d'approcher l'atelier.

---

## 4. Ce qu'on n'essaie pas, et pourquoi

| Piste | Pourquoi non |
|---|---|
| Optimiser la vitesse de broche | Elle n'existe pas : relais tout-ou-rien, `speed_map 0/100 %`. Tant que le MOSFET n'est pas posé (cf. `PLAN-IA.md` §2), cette variable est fictive. |
| Adapter l'avance à la charge en temps réel | Demande une mesure de charge que la machine n'a pas encore (`PLAN-IA.md` Phase 1). La perception vient avant. |
| Augmenter les accélérations dans la config | Tentant — c'est le paramètre qui commande tout. Mais un TB6600 qui décroche perd des pas en silence, et sans capteur de position on ne s'en aperçoit qu'à la pièce ratée. À n'ouvrir qu'avec un protocole de mesure du décrochage. |
| Confier l'optimisation au modèle de langage | Même position que `PLAN-IA.md` : l'agent juge et relance, il ne calcule pas de coordonnées. Chaque brique lui rend un verdict structuré avec un remède exploitable, comme le fait déjà `GcodeCritic`. |
| Un optimiseur global unique | Impossible à améliorer sans tout casser, et impossible à mesurer brique par brique. |

---

## 5. Ce qui se mesure

Aucun de ces critères n'est une impression :

| Critère | Aujourd'hui | Cible |
|---|---|---|
| Écart entre durée estimée et durée réelle | facteur 3 à 17 | < 15 % |
| Alarmes soft-limit en cours d'usinage | non comptées | 0 sur 20 programmes |
| Avance linéaire réelle sur bloc mixte | jusqu'à 8 % du F écrit | > 90 % |
| Temps de finition d'une pièce test | référence à établir | −50 % |
| Programmes allant jusqu'au bout sans redémarrage | à mesurer | 100 % |

Le journal d'activité collecte déjà les actions et les alarmes : les deux
premiers critères sont lisibles sans rien instrumenter de plus.

---

## 6. Risques

**Le risque principal est de construire sur l'horloge fausse.** Toute brique
d'optimisation écrite avant la brique 1 optimisera une grandeur qui n'est pas le
temps réel, et le gain mesuré sera un artefact.

**Le second est la calibration de C.** Si l'écart de 19 % est réel, les briques 4
et 5 raisonneront sur un berceau qui n'est pas où elles le croient — et une
brique de collision qui se trompe de position est pire que pas de brique du tout.
Cette mesure est le tout premier geste à faire.

**Le troisième est le matériel.** Trois des contraintes les plus dures — broche
tout-ou-rien, alimentation sous-dimensionnée, redémarrages thermiques — sont des
limites du banc. Le logiciel peut les contourner, pas les supprimer. Elles
doivent apparaître comme telles dans le mémoire, sans quoi les résultats
paraîtront médiocres alors qu'ils seront bons **pour cette machine-là**.
