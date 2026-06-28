# CHAPITRE 3 : MODÉLISATION ET DIMENSIONNEMENT

## 3.1 Introduction

Après l’étude bibliographique (chapitre 1) et l’analyse fonctionnelle (chapitre 2), ce chapitre marque la transition vers la conception mécanique détaillée de la fraiseuse CNC 5 axes compacte. Les travaux précédents ont permis de définir les exigences du système à l’aide du cahier des charges fonctionnel, de l’actigramme A0, du diagramme FAST et d’une étude cinématique basée sur **Denavit-Hartenberg** et le **RTCP**.

Cela a conduit au choix d’une architecture **Table–Table (Trunnion)**, où les axes rotatifs sont intégrés à la table et les axes X, Y, Z assurent les translations. Cette configuration répond aux objectifs de compacité, rigidité et coût maîtrisé, tout en permettant l’usinage de pièces complexes en aluminium.

L’architecture Trunnion offre une meilleure rigidité que les têtes bi-rotatives. Le plateau assure la rotation **C**, le berceau l’inclinaison **A**, permettant des usinages 3+2 et 5 axes. Elle satisfait les exigences fonctionnelles, notamment en précision, réduction des reprises et intégration compacte.

La chaîne cinématique est : **Y → X → Z → A → C**. Les axes X et Y assurent les translations horizontales via rails et vis, le Trunnion (A, C) oriente la pièce, et l’axe Z contrôle la profondeur de coupe. Cette organisation facilite la dissociation des fonctions et le dimensionnement.

L’étude repose sur des hypothèses adaptées à un prototype : précision **±0,05 mm**, répétabilité **≤0,01 mm** et rugosité **Ra ≤ 3,2 μm**. Le matériau choisi est l’aluminium **AW-2017A**, compatible avec ce type de machine sous conditions d’usinage adaptées.

Le tableau suivant regroupe les principales hypothèses retenues pour le prototype :

| Paramètre | Symbole | Valeur retenue | Unité | Remarque |
| :--- | :---: | :---: | :---: | :--- |
| Course utile axe X | $L_X$ | 150 | mm | Translation transversale du chariot |
| Course utile axe Y | $L_Y$ | 300 | mm | Translation longitudinale de la base |
| Course utile axe Z | $L_Z$ | 150 | mm | Course verticale de la broche |
| Précision de positionnement | — | ±0,05 | mm | Tolérance globale sur les pièces |
| Répétabilité | — | 0,01 | mm | Capacité de retour au même point |
| Matériau cible | — | AW-2017A | — | Alliage d’aluminium usinable |
| Transmission linéaire | — | Vis T8 | — | Axes $X, Y, Z$ |
| Motorisation | — | NEMA 23 + DM556 | — | Entraînement pas-à-pas |

---

## 3.2 Modélisation cinématique et dynamique du système 5 axes

### 3.2.1 Analyse du matériau cible et pression spécifique

Le dimensionnement d’une fraiseuse CNC dépend directement du matériau usiné, car il influence les **efforts de coupe**, les **couples moteurs** et la **rigidité requise**.

Dans ce projet, le matériau choisi est l’aluminium **EN AW-2017A (AlCu4MgSi)**, un alliage de la série 2000 riche en cuivre (≈ 3,5–4,5 %), offrant un bon compromis entre **résistance mécanique**, **légèreté** et **usinabilité**.

L’objectif est de définir les **paramètres de coupe de référence**, notamment la **pression spécifique de coupe $K_c$**, utilisée pour modéliser les efforts appliqués sur l’outil et les axes.

Le tableau suivant présente les propriétés mécaniques et physiques retenues pour le prédimensionnement :

| Propriété | Valeur | Unité |
| :--- | :--- | :---: |
| Désignation normalisée | AW-2017A | AlCu4MgSi |
| Famille d’alliage | Série 2000 | aluminium-cuivre |
| Dureté Brinell | 95 à 105 | HB |
| Résistance à la traction | $R_m = 390$ | MPa |
| Limite d’élasticité | $R_e = 240$ | MPa |
| Module d’Young | $E = 72,5$ | GPa |
| Masse volumique | $\rho = 2790$ | kg/m³ |
| Conductivité thermique | $\lambda_t = 134$ | W/(m·K) |

#### ➢ Pression spécifique de coupe $K_c$

La pression spécifique de coupe $K_c$ représente la résistance du matériau à l’enlèvement de copeau. Elle permet de relier l’effort principal de coupe à la section instantanée du copeau. Elle s’exprime en : **N/mm²**.

Dans une approche simplifiée, l’effort tangentiel principal peut être évalué par :
$$F_c = K_c \cdot A_c$$

avec :
* $F_c$ : effort principal de coupe, en N ;
* $K_c$ : pression spécifique de coupe, en N/mm² ;
* $A_c$ : section instantanée du copeau, en mm².

La relation empirique couramment utilisée pour tenir compte de l’influence de l’épaisseur de copeau est le **modèle de Kienzle** :
$$K_c = K_{c1} \cdot h^{-m_c}$$

où :
* $K_{c1}$ est la pression spécifique de coupe pour une épaisseur de copeau de référence $h = 1$ mm ;
* $h$ est l’épaisseur moyenne du copeau ;
* $m_c$ est l’exposant de Kienzle, généralement voisin de 0,25 pour les alliages d’aluminium ;
* $K_c$ est la pression spécifique corrigée pour l’épaisseur réelle du copeau.

Dans ce PFE, le choix de **$K_c = 700$ N/mm²** est retenu comme valeur forfaitaire de prédimensionnement.

#### ➢ Outil de coupe de référence

Le choix de l’outil est adapté aux contraintes d’une CNC compacte. Une fraise de **diamètre 5,5 mm** permet de limiter le couple de coupe et les efforts transmis à la structure, tout en offrant un compromis entre **productivité, rigidité** et **puissance requise**.

Le maintien de l’outil est assuré par un porte-outil **ER32**, garantissant :
* un **centrage précis**,
* une réduction du **faux-rond**,
* une meilleure **qualité de surface**,
* une bonne **polyvalence** grâce à l’utilisation de pinces interchangeables.

Les caractéristiques de l’outil de référence sont donc :
* $D = 5,5$ mm
* $Z = 3$
* Type : fraise carbure monobloc
* Serrage : porte-outil ER32

#### ➢ Paramètres de coupe retenus

Les paramètres de coupe retenus sont choisis de manière à représenter une passe d’ébauche légère à modérée, compatible avec les capacités mécaniques d’une fraiseuse CNC compacte.

**Vitesse de broche ($N$) :**
$$N = \frac{V_c \cdot 1000}{\pi \cdot D}$$
avec :
* $V_c = 150$ m/min
* $D = 5,5$ mm

*Application numérique :*
$$N = \frac{150 \cdot 1000}{\pi \cdot 5,5} \approx 8680 \text{ tr/min}$$

**Vitesse d’avance ($V_f$) :**
$$V_f = N \cdot f_z \cdot Z$$
avec :
* $N = 8680$ tr/min
* $f_z = 0,05$ mm/dent
* $Z = 3$

*Application numérique :*
$$V_f = 8680 \cdot 0,05 \cdot 3 = 1302 \text{ mm/min}$$

**Profondeur axiale ($a_p$) :**
$$a_p = 1,9 \text{ mm} \approx 0,35 D$$

**Largeur radiale ($a_e$) :**
$$a_e = D = 5,5 \text{ mm}$$ (Cas défavorable de rainurage en pleine matière)

**Section instantanée de copeau ($A_c$) :**
$$A_c = a_p \cdot a_e = 1,9 \cdot 5,5 = 10,45 \text{ mm²}$$

**Tableau de synthèse des paramètres de coupe :**

| Paramètre | Symbole | Valeur | Unité | Justification |
| :--- | :---: | :---: | :---: | :--- |
| Profondeur axiale | $a_p$ | 1,9 | mm | Environ $0,35D$, ébauche légère |
| Largeur radiale | $a_e$ | 5,5 | mm | Engagement pleine matière, cas rainurage |
| Avance par dent | $f_z$ | 0,05 | mm/dent | Valeur modérée pour finition/ébauche légère |
| Vitesse de coupe | $V_c$ | 150 | m/min | Adaptée au carbure sur aluminium |
| Vitesse de broche | $N$ | 8 680 | tr/min | Calculée par $N = \frac{V_c \cdot 1000}{\pi D}$ |
| Vitesse d’avance | $V_f$ | 1 302 | mm/min | Calculée par $V_f = N \cdot f_z \cdot Z$ |

---

### 3.2.2 Modélisation des efforts de coupe

Cette section distingue deux niveaux d’analyse :
* un **modèle théorique majorant**, basé sur une section de copeau maximale ;
* un **modèle réaliste d’exploitation**, compatible avec la puissance, la rigidité et la motorisation du prototype.

#### ➢ Modèle de calcul des efforts

La force tangentielle principale s’écrit :
$$F_c = K_c \cdot A_c$$

*Application (cas rainurage pleine matière) :*
$$F_c = 700 \cdot 10,45 = 7315 \text{ N}$$

#### ➢ Composantes de l’effort de coupe

L’effort de coupe est décomposé en trois composantes principales :
* $F_c$ : force tangentielle ou force principale de coupe ;
* $F_f$ : force d’avance, orientée suivant la direction d’avance ;
* $F_p$ : force de pénétration, normale à la surface usinée.

Approximations usuelles :
$$F_f = k_f \cdot F_c \text{ avec } k_f \approx 0,5 \Rightarrow F_f \approx 3657 \text{ N}$$
$$F_p = k_p \cdot F_c \text{ avec } k_p \approx 0,3 \Rightarrow F_p \approx 2194 \text{ N}$$

#### ➢ Résultante globale de coupe ($R$)

$$R = \sqrt{F_c^2 + F_f^2 + F_p^2}$$
*Application numérique :*
$$R = \sqrt{7315^2 + 3657^2 + 2194^2} \approx 8312 \text{ N}$$

Cette valeur de **8,3 kN** est une enveloppe maximale théorique.

#### ➢ Scénarios réalistes

**1. Cas réaliste : Ébauche légère à modérée**
* $a_p = 0,5$ mm, $a_e = 2$ mm
* $A_{c,réel} = 1,0$ mm²
* $F_{c,réel} = 700$ N
* $F_{f,réel} = 350$ N
* $F_{p,réel} = 210$ N
* **$R_{réel} \approx 800$ N**

**2. Cas de finition**
* $a_p = 0,2$ mm, $a_e = 0,5$ mm
* $A_{c,fin} = 0,1$ mm²
* $F_{c,fin} = 70$ N
* $F_{f,fin} = 35$ N
* $F_{p,fin} = 21$ N
* **$R_{fin} \approx 80$ N**

**Tableau comparatif des scénarios d’efforts :**

| Scénario | $a_p$ (mm) | $a_e$ (mm) | $F_c$ (N) | $F_f$ (N) | $F_p$ (N) | $R$ (N) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Théorique max** (Rainurage) | 1,9 | 5,5 | 7 315 | 3 657 | 2 194 | 8 312 |
| **Ébauche réaliste** | 0,5 | 2,0 | 700 | 350 | 210 | 800 |
| **Finition** | 0,2 | 0,5 | 70 | 35 | 21 | 80 |

---

### 3.2.3 Transfert et projection des efforts sur les axes linéaires (X, Y, Z)

L'objectif est de projeter les efforts du **repère outil** vers le **repère machine**.

#### ➢ Torseur des actions mécaniques de coupe au TCP

$$\{ \mathcal{T}_{coupe} \}_{TCP} = \{ \vec{R}_{outil}, \vec{M}_{TCP} \}$$

Le couple résistant de coupe $M_z$ est :
$$M_z = F_c \cdot \frac{D}{2}$$
* Cas nominal ($F_c = 150$ N) : $M_{z,nom} \approx 0,413$ N·m
* Cas extrême ($F_c = 7315$ N) : $M_{z,ext} \approx 20,12$ N·m

#### ➢ Transformation repère outil vers repère machine

$$\vec{R}_{machine} = M_{R/O} \cdot \vec{R}_{outil}$$
Dans une architecture Trunnion : $M_{R/O} = R_A(\theta_A) \cdot R_C(\theta_C)$.

**Cas neutre ($A=0^\circ, C=0^\circ$) :**
* $F_c \rightarrow Y$ (longitudinal)
* $F_f \rightarrow X$ (transversal)
* $F_p \rightarrow Z$ (vertical)

*Charges nominales (en position neutre) :*
* $R_{Y,nom} = 150$ N
* $R_{X,nom} = 75$ N
* $R_{Z,nom} = 45$ N

#### ➢ Bilan des masses portées par chaque axe

| Axe | Composants portés | Masse portée |
| :---: | :--- | :---: |
| **Y** | Chariot Y + chariot X + Trunnion + pièce | 11 kg |
| **X** | Chariot X + Trunnion + pièce | 7,5 kg |
| **Z** | Broche + support | 1,5 kg |

#### ➢ Charge équivalente par axe — Formule générale

$$F_{axe,tot} = R_{axe} + m \cdot a + F_{frott}$$

*Hypothèse d'accélération ($a$) :* $0,5$ m/s²
*Hypothèses de frottement ($F_{frott}$) :* $Y=20$ N, $X=15$ N, $Z=10$ N.

**Calculs des charges totales (Cas Nominal) :**

* **Axe Y :** $F_{Y,tot} = 150 + (11 \cdot 0,5) + 20 = 175,5$ N
* **Axe X :** $F_{X,tot} = 75 + (7,5 \cdot 0,5) + 15 = 93,75$ N
* **Axe Z :** Intègre le poids $W_Z = m_Z \cdot g = 1,5 \cdot 9,81 \approx 14,7$ N
  $$F_{Z,tot} = F_p + W_Z + m_Z \cdot a + F_{frott,Z}$$
  $$F_{Z,tot} = 45 + 14,7 + (1,5 \cdot 0,5) + 10 = 70,45 \text{ N}$$

**Tableau de synthèse des charges nominales par axe :**

| Axe | Masse $m$ (kg) | $R_{axe}$ nominal (N) | $m \cdot a$ (N) | $F_{frott}$ (N) | $F_{axe,tot}$ (N) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Y** | 11 | 150 ($F_c$) | 5,5 | 20 | **175,5** |
| **X** | 7,5 | 75 ($F_f$) | 3,75 | 15 | **93,75** |
| **Z** | 1,5 | 45 ($F_p$) + 14,7 ($W_Z$) | 0,75 | 10 | **70,45** |

**Cas extrême (Modèle majorant) :**
* $F_{Y,tot,ext} = 7315 + 5,5 + 20 = 7340,5$ N
* $F_{X,tot,ext} = 3657 + 3,75 + 15 = 3675,75$ N
* $F_{Z,tot,ext} = 2194 + 14,7 + 0,75 + 10 = 2219,45$ N
