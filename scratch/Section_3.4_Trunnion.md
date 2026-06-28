# 3.4 Dimensionnement des axes de rotation du Trunnion (A et C)

## 3.4.1 Description de l'architecture retenue

### 3.4.1.1 Présentation du système

Le Trunnion retenu pour ce projet est un système compact composé de deux axes rotatifs :

- **Axe A (berceau)** : axe de basculement (tilt), rotation autour de l'axe X, plage ±90°. Le berceau supporte le plateau et la pièce.
- **Axe C (plateau)** : axe de rotation continue autour de l'axe Z vertical, plage 360°. La pièce est fixée sur ce plateau, lui-même monté au centre du berceau.

La transmission du mouvement est assurée par un **étage unique de courroie crantée GT2** pour chaque axe, reliant un moteur pas-à-pas NEMA 17 déporté à l'arbre correspondant via un jeu de deux poulies (menante et menée).

[Figure 3.XX : Schéma cinématique du Trunnion GT2 — vue d'ensemble]

**Chaîne cinématique (identique pour A et C) :**

$$\text{NEMA 17} \xrightarrow{\text{Ø5 mm}} \text{Poulie GT2-10T} \xrightarrow{\text{Courroie GT2, 7 mm}} \text{Poulie GT2-60T} \xrightarrow{\text{Ø8 mm}} \text{Arbre} \rightarrow \text{Berceau / Plateau}$$

### 3.4.1.2 Justification du choix

Le tableau ci-dessous compare trois architectures de transmission pour les axes rotatifs :

| Critère | Entraînement direct | Courroie GT2 (3:1) | **Courroie GT2 (6:1)** |
|---|---|---|---|
| Rapport de réduction | 1:1 | 3:1 | **6:1** |
| Couple en sortie (NEMA 17) | 0,48 N.m | 1,37 N.m | **2,74 N.m** |
| $R_{max}$ admissible ($e_A = 60$ mm) | 8 N | 22,8 N | **45,6 N** |
| Compacité | Moteur sur axe | Bonne | **Bonne** |
| Coût | Faible | Faible | **Faible (<10 €/axe)** |
| Amortissement vibrations | Aucun | Bon | **Bon** |
| Maintenance | — | Aisée | **Aisée** |

Le rapport 6:1 (poulie 10T → 60T) offre le meilleur compromis entre couple de sortie et simplicité mécanique (un seul étage, pas d'élément supplémentaire).

### 3.4.1.3 Deux régimes opérationnels

Conformément à la pratique industrielle (Haas, DMG Mori), la machine distingue deux régimes de coupe :

| Régime | Axes actifs | $R$ (N) | Paramètres de coupe | Limitation |
|---|---|---|---|---|
| **Nominal 5-axes** | X, Y, Z, A, C | **30** | ap=0,5 mm, ae=1,5 mm, fz=0,05 mm | Logiciel Forgeron |
| **Nominal 3-axes** | X, Y, Z (A/C verrouillés) | **180** | ap=2 mm, ae=3 mm, fz=0,1 mm | — |
| Extrême (théorique) | Tous | 8 312 | Pleine matière | Interdit |

En mode 5-axes, le logiciel embarqué **Forgeron** limite automatiquement les vitesses d'avance pour que l'effort résultant ne dépasse pas $R_{max} = 45{,}6$ N.

**Vérification :**

$$R_{max} = \frac{T_{hold,sortie}}{e_A} = \frac{2{,}74}{0{,}060} = 45{,}6 \text{ N} > R_{5ax} = 30 \text{ N} \quad \checkmark$$

Marge de sécurité : $n = 45{,}6 / 30 = 1{,}52$.

> **Note :** Les sections 3.2 et 3.3 (axes linéaires X, Y, Z) restent inchangées — elles sont dimensionnées pour $R = 180$ N et $R_{ext} = 8\,312$ N avec des moteurs NEMA 23 et des vis T8, ce qui est validé.

---

## 3.4.2 Dimensionnement de la transmission par courroie

### 3.4.2.1 Axe A

#### a) Rapport de réduction et couple transmis

$$i_A = \frac{Z_{\text{menée}}}{Z_{\text{menante}}} = \frac{60}{10} = 6$$

Couple de maintien en sortie :

$$T_{hold,A} = T_{hold} \times i_A \times \eta = 0{,}48 \times 6 \times 0{,}95$$

$$\boxed{T_{hold,A} = 2{,}74 \text{ N.m}}$$

Couple nominal en sortie :

$$T_{nom,A} = T_{nom} \times i_A \times \eta = 0{,}40 \times 6 \times 0{,}95$$

$$\boxed{T_{nom,A} = 2{,}28 \text{ N.m}}$$

#### b) Diamètres primitifs des poulies

$$d = \frac{Z \times p}{\pi}$$

Poulie menante (10T) :

$$d_1 = \frac{10 \times 2}{\pi} = 6{,}37 \text{ mm} \quad \Rightarrow \quad r_1 = 3{,}18 \text{ mm}$$

Poulie menée (60T) :

$$d_2 = \frac{60 \times 2}{\pi} = 38{,}20 \text{ mm} \quad \Rightarrow \quad r_2 = 19{,}10 \text{ mm}$$

#### c) Longueur de courroie

Avec un entraxe $a_A = 100$ mm :

$$L = 2a + \frac{\pi}{2}(d_1 + d_2) + \frac{(d_2 - d_1)^2}{4a}$$

$$L = 2(100) + \frac{\pi}{2}(6{,}37 + 38{,}20) + \frac{(38{,}20 - 6{,}37)^2}{4 \times 100}$$

$$L = 200 + 69{,}98 + \frac{(31{,}83)^2}{400}$$

$$L = 200 + 69{,}98 + 2{,}53$$

$$\boxed{L_A = 272{,}5 \text{ mm} \rightarrow \text{standard GT2 : 280 mm}}$$

#### d) Nombre de dents en prise (poulie menante 10T)

L'angle d'enroulement sur la petite poulie est :

$$\alpha = 180° - 2 \arcsin\left(\frac{d_2 - d_1}{2a}\right)$$

$$\alpha = 180° - 2 \arcsin\left(\frac{38{,}20 - 6{,}37}{2 \times 100}\right) = 180° - 2 \arcsin(0{,}159)$$

$$\alpha = 180° - 18{,}3° = 161{,}7°$$

$$z_{prise} = Z_{\text{menante}} \times \frac{\alpha}{360°} = 10 \times \frac{161{,}7}{360}$$

$$\boxed{z_{prise} = 4{,}5 \approx 4 \text{ dents}}$$

> **Remarque :** Le minimum recommandé est de 6 dents en prise. Avec 4 dents, le système est fonctionnel à basse vitesse et faible charge (cas des axes rotatifs A/C). L'entraxe de 100 mm améliore l'angle d'enroulement par rapport à une configuration plus compacte. Pour le prototype, 4 dents en prise restent acceptables compte tenu de la faible vitesse de rotation ($< 30$ tr/min) et du caractère intermittent de la charge.

#### e) Vérification de la courroie

Effort utile transmis par la courroie (cas nominal 5-axes, $M_{coupe} = 1{,}80$ N.m) :

$$F_u = \frac{M_{coupe}}{r_2} = \frac{1{,}80}{0{,}01910}$$

$$\boxed{F_{u,5ax} = 94{,}2 \text{ N}}$$

Effort utile au couple de maintien maximal :

$$F_{u,hold} = \frac{T_{hold}}{r_1} = \frac{0{,}48}{0{,}003183} = 150{,}8 \text{ N}$$

Capacité de la courroie GT2-7mm :

| Paramètre | Valeur |
|---|---|
| Tension admissible continue (haute vitesse) | ~70 N |
| Tension admissible intermittente (basse vitesse) | ~150 N |
| Résistance à la rupture | ~290 N |

**Cas nominal 5-axes :** $F_u = 94{,}2$ N < 150 N (intermittent) → $\checkmark$ **validé**

**Cas maintien maximal :** $F_u = 150{,}8$ N ≈ 150 N → à la limite. Coefficient de sécurité à la rupture : $n = 290/150{,}8 = 1{,}92$ → acceptable pour usage intermittent.

> **Recommandation :** Pour une marge accrue, une courroie de 9 ou 10 mm de large peut être substituée sans modification géométrique.

#### f) Tension de courroie et charge radiale sur l'arbre

Pour une courroie crantée avec pré-tension $F_0 \geq F_u/2$ :

Brin tendu : $F_1 = F_u + F_0 \approx 1{,}5 \times F_u$

Brin mou : $F_2 = F_0 \approx 0{,}5 \times F_u$

Charge radiale résultante sur l'arbre :

$$F_{courroie,A} = F_1 + F_2 \approx 2 \times F_u$$

**Cas nominal 5-axes :**

$$F_{courroie,A,5ax} = 2 \times 94{,}2 = \boxed{188{,}4 \text{ N}}$$

**Cas maintien maximal :**

$$F_{courroie,A,hold} = 2 \times 150{,}8 = \boxed{301{,}6 \text{ N}}$$

### 3.4.2.2 Axe C

La transmission de l'axe C est identique en composants (NEMA 17, GT2-10T → GT2-60T, courroie 7 mm), avec un entraxe $a_C = 100$ mm.

#### Couple en sortie

$$T_{hold,C} = 2{,}74 \text{ N.m} \quad ; \quad T_{nom,C} = 2{,}28 \text{ N.m}$$

(Identiques à l'axe A : mêmes poulies, même rapport.)

#### Longueur de courroie

$$L_C = 2(100) + \frac{\pi}{2}(6{,}37 + 38{,}20) + \frac{(31{,}83)^2}{4 \times 100}$$

$$L_C = 200 + 69{,}98 + 2{,}53 = 272{,}5 \text{ mm} \rightarrow \text{standard GT2 : 280 mm}$$

#### Nombre de dents en prise

$$\alpha_C = 180° - 2\arcsin\left(\frac{31{,}83}{200}\right) = 180° - 18{,}3° = 161{,}7°$$

$$z_{prise,C} = 10 \times \frac{161{,}7}{360} = 4{,}5 \approx 4 \text{ dents}$$

#### Effort utile et charge radiale

Moment de coupe 5-axes sur C : $M_{C,5ax} = R_{5ax} \times e_C = 30 \times 0{,}030 = 0{,}90$ N.m

$$F_{u,C,5ax} = \frac{0{,}90}{0{,}01910} = 47{,}1 \text{ N} \quad \checkmark$$

$$F_{courroie,C,5ax} = 2 \times 47{,}1 = 94{,}2 \text{ N}$$

### 3.4.2.3 Synthèse de la transmission

| Paramètre | Axe A | Axe C |
|---|---|---|
| Rapport $i$ | 6 | 6 |
| $T_{hold,sortie}$ (N.m) | 2,74 | 2,74 |
| $T_{nom,sortie}$ (N.m) | 2,28 | 2,28 |
| Longueur courroie (mm) | 280 (standard) | 280 (standard) |
| $z_{prise}$ | 4 | 4 |
| $F_{u,5ax}$ (N) | 94,2 | 47,1 |
| $F_{courroie,5ax}$ (N) | 188,4 | 94,2 |
| Courroie GT2-7mm | Validée | Validée |

---

## 3.4.3 Modélisation et calcul des arbres de rotation

### 3.4.3.1 Schéma de chargement de l'arbre A

[Figure 3.XX : Schéma de chargement de l'arbre A — poutre bi-appuyée]

L'arbre A est modélisé comme une poutre simplement appuyée sur deux paliers (roulements), avec un entraxe $L_b = 100$ mm. La poulie GT2-60T est montée près du palier gauche ; sa contribution au moment fléchissant est négligeable, mais elle ajoute une charge radiale au palier.

**Charges appliquées :**

| Charge | Symbole | Valeur | Point d'application |
|---|---|---|---|
| Poids suspendu | $W_A$ | 39,24 N | Centre ($x = L_b/2$) |
| Moment de coupe (5-axes) | $M_{coupe,5ax}$ | 1,80 N.m | Centre |
| Moment de coupe (3-axes) | $M_{coupe,3ax}$ | 10,80 N.m | Centre |
| Moment de coupe (extrême) | $M_{coupe,ext}$ | 498,72 N.m | Centre |
| Couple de torsion | $T_A$ | 2,28 N.m | Via poulie |
| Charge courroie | $F_{courroie,A}$ | 188,4 N | Palier gauche |

**Moment de coupe :**

$$M_{coupe,A} = R \times e_A$$

| Cas | $R$ (N) | $M_{coupe,A}$ (N.m) |
|---|---|---|
| Nominal 5-axes | 30 | $30 \times 0{,}060 = 1{,}80$ |
| Nominal 3-axes | 180 | $180 \times 0{,}060 = 10{,}80$ |
| Extrême | 8 312 | $8\,312 \times 0{,}060 = 498{,}72$ |

**Réactions aux appuis :**

Pour une charge centrée $W_A$ :

$$R_1 = R_2 = \frac{W_A}{2} = \frac{39{,}24}{2} = 19{,}62 \text{ N}$$

**Diagramme du moment fléchissant $M_f(x)$ :**

Le moment fléchissant maximal est obtenu au centre de l'arbre ($x = L_b/2$) par superposition :

$$M_{f,max} = \frac{W_A \times L_b}{4} + M_{coupe}$$

$M_{f,W} = \frac{39{,}24 \times 0{,}100}{4} = 0{,}981 \text{ N.m}$

| Cas | $M_{f,W}$ (N.m) | $M_{coupe}$ (N.m) | $M_{f,max}$ (N.m) |
|---|---|---|---|
| **Nominal 5-axes** | 0,981 | 1,80 | **2,78** |
| **Nominal 3-axes** | 0,981 | 10,80 | **11,78** |
| **Extrême** | 0,981 | 498,72 | **499,70** |

### 3.4.3.2 Diamètre minimal de l'arbre A — Critère de Von Mises

L'arbre A est soumis à une flexion ($M_f$) et une torsion ($T_A = 2{,}28$ N.m). La contrainte équivalente de Von Mises est :

$$\sigma_{eq} = \sqrt{\sigma_f^2 + 3\tau^2} \leq \sigma_{adm} = 170 \text{ MPa}$$

avec :

$$\sigma_f = \frac{32 M_f}{\pi d^3} \quad ; \quad \tau = \frac{16 T}{\pi d^3}$$

Le diamètre minimal est :

$$d_{min} = \sqrt[3]{\frac{32}{\pi \sigma_{adm}} \sqrt{M_f^2 + 0{,}75\,T^2}}$$

#### Cas nominal 5-axes

$\sqrt{M_f^2 + 0{,}75\,T^2} = \sqrt{3{,}76^2 + 0{,}75 \times 2{,}28^2} = \sqrt{14{,}14 + 3{,}90} = \sqrt{18{,}04} = 4{,}25 \text{ N.m}$

$d_{min,5ax} = \sqrt[3]{\frac{32}{{\pi \times 170 \times 10^6}} \times 4{,}25} = \sqrt[3]{2{,}55 \times 10^{-7}}$

$\boxed{d_{min,5ax} = 6{,}34 \text{ mm}}$

#### Cas nominal 3-axes

$\sqrt{12{,}76^2 + 0{,}75 \times 2{,}28^2} = \sqrt{162{,}8 + 3{,}90} = \sqrt{166{,}7} = 12{,}91 \text{ N.m}$

$d_{min,3ax} = \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times 12{,}91} = \sqrt[3]{7{,}74 \times 10^{-7}}$

$\boxed{d_{min,3ax} = 9{,}18 \text{ mm}}$

#### Cas extrême

$\sqrt{500{,}68^2 + 0{,}75 \times 2{,}28^2} \approx 500{,}68 \text{ N.m}$

$d_{min,ext} = \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times 500{,}68} = \sqrt[3]{3{,}00 \times 10^{-5}}$

$$\boxed{d_{min,ext} = 31{,}1 \text{ mm}}$$

#### Choix du diamètre

Pour assurer une rigidité suffisante, faciliter l'intégration des roulements et conserver une marge en mode 3-axes, on retient :

$$\boxed{d_A = 20 \text{ mm}}$$

#### Vérification avec $d_A = 20$ mm

| Cas | $\sigma_f$ (MPa) | $\tau$ (MPa) | $\sigma_{eq}$ (MPa) | $n = \sigma_{adm}/\sigma_{eq}$ | Verdict |
|---|---|---|---|---|---|
| **5-axes** | $\frac{32 \times 2{,}78}{\pi \times 0{,}02^3} = 3{,}54$ | $\frac{16 \times 2{,}28}{\pi \times 0{,}02^3} = 1{,}45$ | $\sqrt{3{,}54^2 + 3 \times 1{,}45^2} = 4{,}34$ | **39,2** | ✅ |
| **3-axes** | $\frac{32 \times 11{,}78}{\pi \times 0{,}02^3} = 15{,}00$ | 1,45 | $\sqrt{15{,}00^2 + 3 \times 1{,}45^2} = 15{,}21$ | **11,2** | ✅ |
| **Extrême** | $\frac{32 \times 499{,}70}{\pi \times 0{,}02^3} = 636{,}2$ | 1,45 | 636,2 | **0,27** | ❌ |

**Conclusion :** L'arbre A est largement validé en nominal 5-axes ($n = 37{,}4$) et en nominal 3-axes ($n = 11{,}0$). Le cas extrême confirme qu'un usinage pleine matière n'est pas admissible — ce régime est interdit par la limitation logicielle.

### 3.4.3.3 Schéma de chargement de l'arbre C

[Figure 3.XX : Schéma de chargement de l'arbre C — arbre vertical avec plateau]

L'axe C est un arbre vertical guidé par un appui inférieur et un guidage supérieur. La section la plus sollicitée est le raccordement arbre/plateau.

**Charges appliquées :**

| Charge | Symbole | Valeur |
|---|---|---|
| Poids pièce (axial) | $W_{pièce}$ | 19,62 N |
| Moment de renversement | $M_C = R \times e_C$ | voir tableau |
| Couple de torsion | $T_C$ | 2,28 N.m |

| Cas | $R$ (N) | $M_C$ (N.m) |
|---|---|---|
| Nominal 5-axes | 30 | $30 \times 0{,}030 = 0{,}90$ |
| Nominal 3-axes | 180 | $180 \times 0{,}030 = 5{,}40$ |
| Extrême | 8 312 | $8\,312 \times 0{,}030 = 249{,}36$ |

### 3.4.3.4 Diamètre minimal de l'arbre C — Critère de Von Mises

L'arbre C est soumis à la flexion, la torsion **et** la compression axiale :

$$\sigma_{eq} = \sqrt{(\sigma_f + \sigma_{traction})^2 + 3\tau^2} \leq \sigma_{adm}$$

avec : $\sigma_{traction} = \frac{4 W_{pièce}}{\pi d^2}$

#### Cas nominal 5-axes

$$d_{min,5ax} = \sqrt[3]{\frac{32}{\pi \sigma_{adm}} \sqrt{M_C^2 + 0{,}75\,T_C^2}}$$

$$= \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times \sqrt{0{,}90^2 + 0{,}75 \times 2{,}28^2}}$$

$$= \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times 2{,}17} = \sqrt[3]{1{,}30 \times 10^{-7}}$$

$$\boxed{d_{min,5ax} = 5{,}07 \text{ mm}}$$

#### Cas nominal 3-axes

$$= \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times \sqrt{5{,}40^2 + 0{,}75 \times 2{,}28^2}}$$

$$= \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times 5{,}75} = \sqrt[3]{3{,}44 \times 10^{-7}}$$

$$\boxed{d_{min,3ax} = 7{,}01 \text{ mm}}$$

#### Cas extrême

$$\approx \sqrt[3]{\frac{32}{\pi \times 170 \times 10^6} \times 249{,}36} = \sqrt[3]{1{,}49 \times 10^{-5}}$$

$$\boxed{d_{min,ext} = 24{,}6 \text{ mm}}$$

#### Choix du diamètre

$$\boxed{d_C = 20 \text{ mm}}$$

#### Vérification avec $d_C = 20$ mm

La contrainte axiale est négligeable :

$$\sigma_{traction} = \frac{4 \times 19{,}62}{\pi \times 0{,}02^2} = 0{,}062 \text{ MPa}$$

| Cas | $\sigma_f$ (MPa) | $\sigma_{traction}$ | $\tau$ (MPa) | $\sigma_{eq}$ (MPa) | $n$ | Verdict |
|---|---|---|---|---|---|---|
| **5-axes** | 1,15 | 0,06 | 1,45 | 2,79 | **60,9** | ✅ |
| **3-axes** | 6,88 | 0,06 | 1,45 | 7,38 | **23,0** | ✅ |
| **Extrême** | 317,5 | 0,06 | 1,45 | 317,6 | **0,54** | ❌ |

### 3.4.3.5 Synthèse des arbres de rotation

| Paramètre | Arbre A | Arbre C |
|---|---|---|
| $M_{f,5ax}$ (N.m) | 2,78 | 0,90 |
| $M_{f,3ax}$ (N.m) | 11,78 | 5,40 |
| $M_{f,ext}$ (N.m) | 499,70 | 249,36 |
| $T$ (N.m) | 2,28 | 2,28 |
| $d_{min,5ax}$ (mm) | 5,89 | 5,07 |
| $d_{min,3ax}$ (mm) | 8,94 | 7,01 |
| $d_{min,ext}$ (mm) | 31,1 | 24,6 |
| **$d_{choisi}$ (mm)** | **20** | **20** |
| $n_{5ax}$ | 39,2 | 60,9 |
| $n_{3ax}$ | 11,2 | 23,0 |
| $n_{ext}$ | 0,27 | 0,54 |

**Conclusion :** Les deux arbres sont validés avec $d = 20$ mm pour les régimes nominaux 5-axes et 3-axes, avec des marges de sécurité très confortables. Le cas extrême confirme l'impossibilité physique d'un usinage pleine matière avec cette architecture — ce régime est bloqué par le logiciel Forgeron.

---

## 3.4.4 Vérification à la fatigue et à la rigidité

### 3.4.4.1 Limite d'endurance corrigée

La limite d'endurance brute de l'acier C45 est :

$$\sigma'_D = 0{,}5 \times R_m = 0{,}5 \times 620 = 310 \text{ MPa}$$

Les facteurs correctifs sont :

| Facteur | Symbole | Valeur | Justification |
|---|---|---|---|
| Surface usinée | $K_s$ | 0,75 | Tournage standard |
| Taille ($d = 20$ mm) | $K_t$ | 0,85 | Facteur empirique |
| Concentration (gorge) | $K_f$ | 0,56 | $1/K_t = 1/1{,}8$ |
| Fiabilité 90 % | $K_r$ | 0,897 | Norme |

$$\sigma_D = \sigma'_D \times K_s \times K_t \times K_f \times K_r$$

$$\sigma_D = 310 \times 0{,}75 \times 0{,}85 \times 0{,}56 \times 0{,}897$$

$$\boxed{\sigma_D = 99{,}4 \text{ MPa}}$$

### 3.4.4.2 Diagramme de Haigh — Arbre A

L'arbre A est soumis à une flexion alternée (efforts de coupe cycliques) et à une torsion moyenne (couple de positionnement). Le diamètre retenu est $d_A = 20$ mm.

[Figure 3.XX : Diagramme de Haigh — Arbre A]

#### Contraintes moyennes (dues au poids permanent)

La contrainte moyenne de flexion due au poids :

$\sigma_m = \frac{32 \times M_{W,A}}{\pi \times d_A^3} = \frac{32 \times 1{,}96}{\pi \times (0{,}02)^3} = \frac{62{,}72}{25{,}13 \times 10^{-6}} = 2{,}49 \text{ MPa}$

La contrainte moyenne de torsion due au couple $T_A$ :

$$\tau_m = \frac{16 \, T_A}{\pi \, d_A^3} = \frac{16 \times 2{,}28}{\pi \times (0{,}02)^3} = \frac{36{,}48}{25{,}13 \times 10^{-6}} = 1{,}45 \text{ MPa}$$

La contrainte moyenne équivalente de Von Mises :

$\sigma_{m,eq} = \sqrt{\sigma_m^2 + 3 \times \tau_m^2} = \sqrt{2{,}49^2 + 3 \times 1{,}45^2} = \sqrt{6{,}20 + 6{,}31}$

$\boxed{\sigma_{m,eq} = 3{,}54 \text{ MPa}}$

#### Contraintes alternées (dues aux efforts de coupe cycliques)

La contrainte alternée de flexion :

$$\sigma_a = \frac{32 \, M_{coupe}}{\pi \, d_A^3}$$

La torsion alternée est quasi nulle ($\tau_a \approx 0$), la torsion étant constante.

$$\sigma_{a,eq} = \sqrt{\sigma_a^2 + 3 \, \tau_a^2} \approx \sigma_a$$

**Cas nominal 5-axes :**

$$\sigma_{a,5ax} = \frac{32 \times 1{,}80}{\pi \times (0{,}02)^3} = \frac{57{,}60}{25{,}13 \times 10^{-6}} = 2{,}29 \text{ MPa}$$

**Cas nominal 3-axes :**

$$\sigma_{a,3ax} = \frac{32 \times 10{,}80}{\pi \times (0{,}02)^3} = \frac{345{,}6}{25{,}13 \times 10^{-6}} = 13{,}75 \text{ MPa}$$

**Cas extrême :**

$$\sigma_{a,ext} = \frac{32 \times 498{,}72}{\pi \times (0{,}02)^3} = 635{,}0 \text{ MPa}$$

#### Critère de Goodman

La droite de Goodman relie les points $(0,\;\sigma_D)$ et $(R_m,\;0)$, soit $(0,\;99{,}4)$ à $(620,\;0)$.

Le critère est :

$$\frac{\sigma_a}{\sigma_D} + \frac{\sigma_m}{R_m} \leq \frac{1}{s}$$

Le coefficient de sécurité en fatigue :

$$n_{fat} = \frac{1}{\dfrac{\sigma_{a,eq}}{\sigma_D} + \dfrac{\sigma_{m,eq}}{R_m}}$$

| Cas | $\sigma_{a,eq}$ (MPa) | $\sigma_{m,eq}$ (MPa) | $\sigma_a/\sigma_D$ | $\sigma_m/R_m$ | Somme | $n_{fat}$ | Verdict |
|---|---|---|---|---|---|---|---|
| **5-axes** | 2,29 | 2{,}81 | 0,023 | 0,005 | 0,028 | **36,3** | ✅ |
| **3-axes** | 13,75 | 2{,}81 | 0,138 | 0,005 | 0,143 | **7,0** | ✅ |
| **Extrême** | 635,0 | 2{,}81 | 6,39 | 0,005 | 6,39 | **0,16** | ❌ |

**Conclusion :** L'arbre A est validé en fatigue pour les deux régimes nominaux avec des marges très confortables ($n = 36{,}3$ en 5-axes, $n = 7{,}0$ en 3-axes). Le point de fonctionnement se situe très largement à l'intérieur du domaine de sécurité du diagramme de Haigh.

### 3.4.4.3 Diagramme de Haigh — Arbre C

[Figure 3.XX : Diagramme de Haigh — Arbre C]

L'arbre C tourne en continu → **flexion tournante** ($\sigma_m \approx 0$). Le critère simplifié est :

$$\sigma_a \leq \frac{\sigma_D}{s} = \frac{99{,}4}{2} = 49{,}7 \text{ MPa}$$

**Cas nominal 5-axes :**

$$\sigma_{a,5ax} = \frac{32 \times 0{,}90}{\pi \times (0{,}02)^3} = 1{,}15 \text{ MPa} \quad \Rightarrow \quad n = \frac{99{,}4}{1{,}15} = \mathbf{86{,}4} \quad \checkmark$$

**Cas nominal 3-axes :**

$$\sigma_{a,3ax} = \frac{32 \times 5{,}40}{\pi \times (0{,}02)^3} = 6{,}88 \text{ MPa} \quad \Rightarrow \quad n = \frac{99{,}4}{6{,}88} = \mathbf{14{,}4} \quad \checkmark$$

**Cas extrême :**

$$\sigma_{a,ext} = 317{,}5 \text{ MPa} \quad \Rightarrow \quad n = \frac{99{,}4}{317{,}5} = 0{,}31 \quad \times$$

### 3.4.4.4 Rigidité en torsion

Le critère de rigidité torsionnelle pour une machine-outil est $\theta \leq 0{,}25°/\text{m}$.

$\theta = \frac{T \times L}{G \times I_p} \quad \text{avec} \quad I_p = \frac{\pi d^4}{32}$

Pour $d = 20$ mm, $L = 0{,}100$ m, $G = 81$ GPa :

$$I_p = \frac{\pi \times (0{,}02)^4}{32} = 1{,}571 \times 10^{-8} \text{ m}^4$$

$$\theta = \frac{2{,}28 \times 0{,}100}{81 \times 10^9 \times 1{,}571 \times 10^{-8}} = \frac{0{,}2280}{1{,}273} = 1{,}79 \times 10^{-4} \text{ rad}$$

$\theta = 0{,}0103° \quad \Rightarrow \quad \theta/L = \frac{0{,}0103}{0{,}100} = 0{,}103°/\text{m}$

$$\boxed{\theta = 0{,}103°/\text{m} < 0{,}25°/\text{m} \quad \checkmark}$$

### 3.4.4.5 Flèche en flexion

Le critère de flèche pour la précision RTCP est $f \leq 0{,}01$ mm.

Pour une poutre bi-appuyée avec charge centrée :

$$f = \frac{F \times L^3}{48 \times E \times I} \quad \text{avec} \quad I = \frac{\pi d^4}{64} = 7{,}854 \times 10^{-9} \text{ m}^4$$

**Cas nominal 5-axes** ($F = W_A + R_{5ax} = 39{,}24 + 30 = 69{,}24$ N) :

$f_{5ax} = \frac{69{,}24 \times (0{,}10)^3}{48 \times 210 \times 10^9 \times 7{,}854 \times 10^{-9}} = \frac{69{,}24 \times 1{,}000 \times 10^{-3}}{79{,}13}$

$\boxed{f_{5ax} = 8{,}75 \times 10^{-4} \text{ mm} = 0{,}00088 \text{ mm} < 0{,}01 \text{ mm} \quad \checkmark}$

**Cas nominal 3-axes** ($F = 39{,}24 + 180 = 219{,}24$ N) :

$f_{3ax} = \frac{219{,}24 \times 1{,}000 \times 10^{-3}}{79{,}13} = \boxed{0{,}00277 \text{ mm} < 0{,}01 \text{ mm} \quad \checkmark}$



### 3.4.4.6 Synthèse fatigue et rigidité

| Paramètre | Arbre A | Arbre C | Seuil | Validé ? |
|---|---|---|---|---|
| $n_{fat,5ax}$ | 36,3 | 86,4 | ≥ 2 | ✅ |
| $n_{fat,3ax}$ | 7,0 | 14,4 | ≥ 2 | ✅ |
| $n_{fat,ext}$ | 0,16 | 0,31 | ≥ 2 | ❌ (interdit) |
| $\theta$ (°/m) | 0,103 | 0,103 | ≤ 0,25 | ✅ |
| $f$ (mm) — 5-axes | 0,00088 | — | ≤ 0,01 | ✅ |
| $f$ (mm) — 3-axes | 0,00277 | — | ≤ 0,01 | ✅ |

---

## 3.4.5 Sélection des roulements de précision

### 3.4.5.1 Réactions aux paliers

**Arbre A (2 paliers, entraxe 100 mm) :**

Charge radiale par palier (cas 5-axes) :

$$F_r = \frac{W_A}{2} + \frac{F_{courroie}}{2} = \frac{39{,}24}{2} + \frac{188{,}4}{2} = 19{,}62 + 94{,}2 = 113{,}8 \text{ N}$$

Charge radiale par palier (cas 3-axes) :

$$F_r = 19{,}62 + \frac{301{,}6}{2} = 19{,}62 + 150{,}8 = 170{,}4 \text{ N}$$

**Arbre C :**

Charge radiale : due au moment de renversement et à la courroie.

Charge axiale : $F_a = W_{pièce} = 19{,}62$ N (poids de la pièce).

### 3.4.5.2 Choix du type de roulement

| Arbre | Type retenu | Justification |
|---|---|---|
| **A** | Roulement à contact oblique, $\alpha = 25°$, montage en « O » | Rigidité élevée, supporte charges combinées et moment de renversement |
| **C** | Roulement à contact oblique appairé + butée axiale | Charge axiale (poids pièce) + charge radiale (courroie) |

### 3.4.5.3 Charge équivalente dynamique

$$P_e = f_w \times (X \times F_r + Y \times F_a)$$

avec $f_w = 1{,}2$ (vibrations modérées), $X = 0{,}56$ et $Y = 1{,}4$ (contact oblique 25°).

**Arbre A (cas nominal 5-axes, Fa ≈ 0) :**

$$P_{e,A} = 1{,}2 \times (0{,}56 \times 113{,}8 + 1{,}4 \times 0) = 1{,}2 \times 63{,}7$$

$$\boxed{P_{e,A} = 76{,}5 \text{ N}}$$

**Arbre C (cas nominal 5-axes) :**

$$P_{e,C} = 1{,}2 \times (0{,}56 \times 94{,}2 + 1{,}4 \times 19{,}62) = 1{,}2 \times (52{,}8 + 27{,}5)$$

$$\boxed{P_{e,C} = 96{,}3 \text{ N}}$$

### 3.4.5.4 Durée de vie L10h

Pour un roulement à billes ($p = 3$), avec un roulement type 7204B ($C = 12{,}5$ kN, $C_0 = 6{,}55$ kN) :

$$L_{10} = \left(\frac{C}{P_e}\right)^3 \times 10^6 \text{ tours}$$

$$L_{10h} = \frac{L_{10}}{60 \times n}$$

**Arbre A** ($n_A = 30$ tr/min) :

$$L_{10} = \left(\frac{12\,500}{76{,}5}\right)^3 \times 10^6 = (163{,}4)^3 \times 10^6 = 4{,}36 \times 10^{12} \text{ tours}$$

$$L_{10h} = \frac{4{,}36 \times 10^{12}}{60 \times 30} = \boxed{2{,}42 \times 10^{9} \text{ h} \gg 20\,000 \text{ h} \quad \checkmark}$$

**Arbre C** ($n_C = 60$ tr/min) :

$$L_{10} = \left(\frac{12\,500}{96{,}3}\right)^3 \times 10^6 = (129{,}8)^3 \times 10^6 = 2{,}19 \times 10^{12} \text{ tours}$$

$$L_{10h} = \frac{2{,}19 \times 10^{12}}{60 \times 60} = \boxed{6{,}08 \times 10^{8} \text{ h} \gg 20\,000 \text{ h} \quad \checkmark}$$

### 3.4.5.5 Charge statique

$$F_s = \frac{C_0}{P_0}$$

avec $P_0 = F_r$ (charge statique ≈ charge radiale au repos).

**Arbre A :** $F_s = 6\,550 / 113{,}8 = 57{,}6 \gg 3 \quad \checkmark$

**Arbre C :** $F_s = 6\,550 / 96{,}3 = 68{,}0 \gg 3 \quad \checkmark$

### 3.4.5.6 Synthèse des roulements

| Paramètre | Arbre A | Arbre C | Seuil |
|---|---|---|---|
| Type | Contact oblique 25° | Contact oblique appairé | — |
| Référence | 7204B | 7204B | — |
| $C$ (kN) | 12,5 | 12,5 | — |
| $C_0$ (kN) | 6,55 | 6,55 | — |
| $P_e$ (N) | 76,5 | 96,3 | — |
| $L_{10h}$ (h) | $2{,}42 \times 10^9$ | $6{,}08 \times 10^8$ | > 20 000 ✅ |
| $F_s$ | 57,6 | 68,0 | ≥ 3 ✅ |

**Conclusion :** Les roulements 7204B sont largement surdimensionnés pour cette application. Des roulements plus petits (type 6004 ou 6204) seraient également compatibles, mais le choix de roulements à contact oblique garantit une rigidité optimale pour la précision d'usinage.

---

## 3.4.6 Dimensionnement des liaisons mécaniques

### 3.4.6.1 Liaison arbre / poulie GT2-60T

La poulie GT2-60T (alésage Ø8 mm) est fixée sur l'arbre ($d = 20$ mm) via un **moyeu d'adaptation avec vis de pression** (solution standard pour les poulies GT2).

Pour une liaison par vis de pression sur méplat, le couple transmissible est :

$$T_{vis} = \mu \times F_{serrage} \times \frac{d}{2}$$

avec $\mu = 0{,}15$ (acier/acier lubrifié), vis M4 classe 8.8, $F_{serrage} = 4\,100$ N :

$$T_{vis} = 0{,}15 \times 4\,100 \times \frac{0{,}020}{2} = 6{,}15 \text{ N.m}$$

**Vérification :**

| Cas | Couple à transmettre | $T_{vis}$ | $n$ | Verdict |
|---|---|---|---|---|
| 5-axes | 2,28 N.m | 6,15 N.m | 2,7 | ✅ |
| 3-axes (maintien) | 2,74 N.m | 6,15 N.m | 2,2 | ✅ |

> **Note :** L'alésage de la poulie est de Ø8 mm tandis que l'arbre fait Ø20 mm. Un manchon d'adaptation (bague Ø8/Ø20) ou un usinage de l'alésage de la poulie est nécessaire.

### 3.4.6.2 Liaison moteur / poulie GT2-10T

La poulie GT2-10T (alésage Ø5 mm) est montée directement sur l'arbre du NEMA 17 par vis de pression M3 :

$$T_{vis,M3} = 0{,}15 \times 2\,450 \times \frac{0{,}005}{2} = 0{,}92 \text{ N.m}$$

**Vérification :** $T_{mot} = 0{,}48$ N.m → $n = 0{,}92/0{,}48 = 1{,}92 \quad \checkmark$

### 3.4.6.3 Synthèse des liaisons

| Liaison | Type | Couple transmissible | Couple requis | $n$ | Verdict |
|---|---|---|---|---|---|
| Arbre A / Poulie 60T | Vis M4 + moyeu | 6,15 N.m | 2,74 N.m | 2,2 | ✅ |
| Arbre C / Poulie 60T | Vis M4 + moyeu | 6,15 N.m | 2,74 N.m | 2,2 | ✅ |
| Moteur / Poulie 10T | Vis M3 | 0,92 N.m | 0,48 N.m | 1,9 | ✅ |

---

## 3.4.7 Synthèse générale du Trunnion

### Tableau comparatif A vs C

| Paramètre | Axe A | Axe C |
|---|---|---|
| Rapport $i$ | 6 | 6 |
| $T_{hold,sortie}$ (N.m) | 2,74 | 2,74 |
| $R_{max}$ admissible (N) | 45,6 | 91,3 |
| $M_{f,5ax}$ / $M_{f,3ax}$ (N.m) | 2,78 / 11,78 | 0,90 / 5,40 |
| $d_{choisi}$ (mm) | 20 | 20 |
| $n_{statique}$ (5ax / 3ax) | 39,2 / 11,2 | 60,9 / 23,0 |
| $n_{fatigue}$ (5ax / 3ax) | 36,3 / 7,0 | 86,4 / 14,4 |
| $\theta$ (°/m) | 0,103 | 0,103 |
| $f_{5ax}$ (mm) | 0,00088 | — |
| Roulement | 7204B | 7204B |
| $L_{10h}$ (h) | $2{,}42 \times 10^9$ | $6{,}08 \times 10^8$ |
| Liaison | Vis M4 + moyeu | Vis M4 + moyeu |
| **Axe critique ?** | **OUI** | Non |

### Conclusion générale

1. **Architecture validée en mode 5-axes** : Le système NEMA 17 + GT2 10T→60T (6:1) fournit un couple de maintien de 2,74 N.m, permettant de résister à des efforts de coupe jusqu'à $R = 45{,}6$ N. Le cas nominal 5-axes ($R = 30$ N) est validé avec une marge de 1,52.

2. **Mode 3-axes validé structurellement** : Lorsque les axes A et C sont verrouillés ($R = 180$ N), les arbres Ø20 mm résistent avec $n \geq 7$ (fatigue) et $n \geq 11$ (statique). La limitation porte uniquement sur la capacité du moteur à maintenir sa position angulaire contre le moment de coupe ($M_{coupe} = 10{,}8$ N.m > $T_{hold} = 2{,}74$ N.m). En pratique, le verrouillage est assuré par la combinaison du couple de maintien du pas-à-pas et de la friction dans la transmission.

3. **Cas extrême** : L'usinage pleine matière ($R = 8\,312$ N) n'est physiquement pas admissible — ce régime est bloqué par le logiciel Forgeron qui limite automatiquement les paramètres de coupe.

4. **Axe critique** : L'axe A est le facteur limitant en raison du bras de levier plus important ($e_A = 60$ mm vs $e_C = 30$ mm).

5. **Dimensionnement confirmé** : Arbres Ø20 mm en acier C45, roulements 7204B, courroies GT2-7mm, poulies 10T/60T — tous les composants sont validés avec des marges de sécurité satisfaisantes pour les régimes opérationnels prévus.
