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



### 3.3.1 Dimensionnement de l'axe X (Chariot transversal)

L'axe **X** assure le déplacement transversal du chariot supportant l'unité **Trunnion**. Dans l'architecture retenue, il porte le chariot X, le berceau Trunnion, le plateau rotatif C, ainsi que la pièce et son système de bridage. Il est donc directement impliqué dans la précision de positionnement latéral et dans les compensations imposées par la cinématique 5 axes.

Le dimensionnement de cet axe repose sur les charges suivantes :
- **Charge nominale équivalente** : $F_{X, tot} \approx 95 \text{ N}$
- **Cas extrême (pleine matière)** : $F_{X, extre\hat{me}} = 3\,676 \text{ N}$
#### 1. Vérification en traction — Critère de Von Mises

La section résistante de la vis est calculée au diamètre de noyau ($d_n = 6,2 \text{ mm}$) :
$$A = \frac{\pi}{4} d_n^2$$
$$A = \frac{\pi}{4} \times (0,0062)^2 = 3,019 \times 10^{-5} \text{ m}^2$$

La contrainte normale $\sigma$ doit respecter : $\sigma \le \sigma_{adm} = \frac{R_e}{s} = 300 \text{ MPa}$ (avec $R_e = 600 \text{ MPa}$ et $s = 2$).

| Cas | Force $F$ (N) | Contrainte $\sigma$ (MPa) | Verdict |
| :--- | :--- | :--- | :--- |
| **Nominal** | $93,75$ | $3,11$ | **Validé** ($\ll 300 \text{ MPa}$) |
| **Extrême** | $3\,675,75$ | $121,75$ | **Validé** ($< 300 \text{ MPa}$) |
#### 2. Diamètre minimal théorique

Le diamètre minimal est donné par :
$$d_{min} = \sqrt{\frac{4Fs}{\pi R_e}}$$

- **Cas nominal** : $d_{min, nom} = 0,63 \text{ mm}$
- **Cas extrême** : $d_{min, extre\hat{me}} = 3,95 \text{ mm}$

Le diamètre de noyau réel étant $d_n = 6,2 \text{ mm}$, la condition $d_n > d_{min}$ est satisfaite dans tous les cas.
#### 3. Vérification au flambement — Formule d’Euler

La vis est assimilée à une colonne comprimée en montage **pivot-pivot** ($K = 1$).
Le moment quadratique est : $I = \frac{\pi d_n^4}{64} = 7,253 \times 10^{-11} \text{ m}^4$.

La charge critique d'Euler est :
🟢 $$F_{cr} = \frac{\pi^2 E I}{(KL)^2} = \frac{\pi^2 \times 210 \times 10^9 \times 7,253 \times 10^{-11}}{(1 \times 0,20)^2} = 3\,759 \text{ N}$$

**Coefficient de sécurité au flambement ($n_{flamb} = \frac{F_{cr}}{F}$)** :
- 🟢 **Cas nominal** : $n_{flamb, nom} = 40,09$ (Largement satisfait)
- 🟢 **Cas extrême** : $n_{flamb, extre\hat{me}} = 1,02$ (**Non validé**, critère $s \ge 2$ non respecté)
#### 4. Pression de matage vis/écrou

Vérification de la pression de contact acier/bronze.
- Nombre de filets en prise : $n_{filets} = \frac{L_{\text{écrou}}}{p} = \frac{15}{2} = 7,5$
- Surface de contact projetée : $S_{contact} = 153,74 \text{ mm}^2$
- Limite admissible : $P_{adm} = 5 \text{ à } 7 \text{ MPa}$

| Cas | Pression $P$ (MPa) | Verdict |
| :--- | :--- | :--- |
| **Nominal** | $0,61$ | **Validé** ($< 5 \text{ MPa}$) |
| **Extrême** | $23,91$ | **Non admissible** ($> 7 \text{ MPa}$) |
#### 5. Rendement et irréversibilité de la vis

- **Angle d'hélice** : $\lambda = 5,02^\circ$
- **Angle de frottement** : $\phi = 5,91^\circ$
- **Rendement direct** : $\eta = 45,5 \\%$

La condition d'irréversibilité **$\lambda < \phi$** ($5,02^\circ < 5,91^\circ$) est satisfaite. Aucun frein dédié n'est requis sur cet axe.
#### 6. Couple moteur et puissance (NEMA 23, 1,26 Nm)

🟢 Le couple total requis $T_{total} = T_{charge} + T_{acc}$ (avec $T_{acc} = 0,046 \text{ Nm}$).

| Cas | Couple de charge (Nm) | Couple total (Nm) | Marge ($T_m / T_{total}$) | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| 🟢 **Nominal** | $0,066$ | $0,112$ | **11,25** | **Validé** ($> 2$) |
| **Extrême** | $2,57$ | $2,62$ | **0,48** | **Insuffisant** |

**Puissance mécanique** (à $1\,500 \text{ tr/min}$) :
- 🟢 **Nominale** : $17,6 \text{ W}$ (Compatible)
- 🟢 **Extrême** : $412 \text{ W}$ (Incompatible)
#### 7. Vitesse critique de la vis

🟢 $$N_{cr} = 18\,890 \text{ tr/min}$$
🟢 Comparaison avec $N_{max} = 1\,500 \text{ tr/min}$ : la marge est de **12,6**. Aucun risque de fouettement de la vis T8.
#### 8. Dimensionnement des guidages linéaires (HGR15)

L’axe X utilise deux rails **HGR15** et quatre patins **HGH15CA**.
- **Charge nominale dynamique** : $C = 16\,600 \text{ N}$
- **Charge statique** : $C_0 = 23\,400 \text{ N}$

| Cas | Charge équiv. $P_e$ (N) | Durée de vie $L_{10h}$ (h) | Sécurité statique $F_s$ | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Nominal** | $72,73$ | $3,30 \times 10^9$ | $386$ | **Validé** |
| **Extrême** | $2\,099$ | $137\,327$ | $13,38$ | **Validé** |
#### 9. Synthèse et tableau récapitulatif

| Critère | Valeur | Seuil | Coeff. Sécu | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Traction vis (Nominal)** | $\sigma = 3,11 \text{ MPa}$ | $300 \text{ MPa}$ | $96,6$ | **Validé** |
| **Traction vis (Extrême)** | $\sigma = 121,75 \text{ MPa}$ | $300 \text{ MPa}$ | $2,46$ | **Validé** |
| 🟢 **Flambement vis (Nominal)** | $n_{flamb} = 40,09$ | $\ge 2$ | $40,09$ | **Validé** |
| 🟢 **Flambement vis (Extrême)** | $n_{flamb} = 1,02$ | $\ge 2$ | $1,02$ | **Non validé** |
| **Matage vis/écrou (Nominal)** | $0,61 \text{ MPa}$ | $5 \text{ à } 7 \text{ MPa}$ | $> 8$ | **Validé** |
| **Matage vis/écrou (Extrême)** | $23,91 \text{ MPa}$ | $5 \text{ à } 7 \text{ MPa}$ | $< 1$ | **Non validé** |
| 🟢 **Couple moteur (Nominal)** | $0,112 \text{ Nm}$ | $1,26 \text{ Nm}$ | $11,25$ | **Validé** |
| **Couple moteur (Extrême)** | $2,62 \text{ Nm}$ | $1,26 \text{ Nm}$ | $0,48$ | **Non validé** |
| **Durée de vie guidages (Nominal)** | $3,30 \times 10^9 \text{ h}$ | $> 20\,000 \text{ h}$ | Très élevé | **Validé** |
| **Roulements d'appui (Nominal)** | $1,84 \times 10^6 \text{ h}$ | $> 20\,000 \text{ h}$ | $92$ | **Validé** |

🟢 **Conclusion** : L'axe X est parfaitement dimensionné pour un régime de fonctionnement **nominal** (passes modérées aluminium). Le cas **extrême** (pleine matière sévère) dépasse les capacités de la transmission T8 actuelle (flambement, matage, couple moteur).



# Section 3.3.2 - Axe Y (Portique longitudinal)

🟢 Cette section constitue le modèle méthodologique appliqué pour le dimensionnement de l'**axe Y**. Contrairement à l'axe X, dont la longueur libre de vis est de 200 mm, l'**axe Y** possède une course utile de **300 mm**, soit une longueur libre 1,5 fois plus importante.

Cette différence a un impact direct sur la **stabilité élastique** de la vis, car la charge critique de flambement varie selon :
$F_{cr} \propto \frac{1}{L^2}$

Ainsi, lorsque la longueur libre double, la charge critique est divisée par quatre. Les calculs sont menés selon les normes **ISO 14728** (guidages linéaires), **ISO 281** (roulements) et **ISO 3408** (vis à billes, citée comme référence méthodologique).

## 1. Vérification de la vis trapézoïdale T8

La transmission retenue pour l'axe Y est identique à celle de l'axe X : une **vis trapézoïdale T8**.

### Caractéristiques géométriques et mécaniques
| Paramètre | Symbole | Valeur |
| :--- | :---: | :--- |
| Pas | $p$ | 2 mm ($0,002$ m) |
| Diamètre nominal | $d$ | 8 mm |
| Diamètre de noyau | $d_n$ | 6,2 mm |
| Matériau | - | Acier Inoxydable C45 |
| Limite élastique | $R_e$ | 600 MPa |

### Vérification à la traction
La section résistante au diamètre de noyau est :
$A = \frac{\pi}{4} d_n^2 = \frac{\pi}{4} (0,0062)^2 = 3,019 \times 10^{-5} \text{ m}^2$

La contrainte normale est : $\sigma = \frac{F}{A}$
Le critère admissible avec un coefficient de sécurité $s = 2$ est :
$\sigma_{adm} = \frac{R_e}{s} = \frac{600}{2} = 300 \text{ MPa}$

*   **Cas nominal :**
    $\sigma_{nom} = \frac{175,5}{3,019 \times 10^{-5}} = 5,81 \text{ MPa}$
    $5,81 \text{ MPa} \ll 300 \text{ MPa}$ (**Validé**)

*   **Cas extrême :**
    $\sigma_{ext} = \frac{7\,340,5}{3,019 \times 10^{-5}} = 243,14 \text{ MPa}$
    $243,14 \text{ MPa} < 300 \text{ MPa}$ (**Validé**, mais marge réduite)

### Diamètre minimal théorique
$d_{min} = \sqrt{\frac{4Fs}{\pi R_e}}$

*   **Cas nominal :** $d_{min, nom} = 0,86 \text{ mm}$
*   **Cas extrême :** $d_{min, ext} = 5,58 \text{ mm}$
Le diamètre réel ($d_n = 6,2 \text{ mm}$) étant supérieur, la vis est validée en traction.

## 2. Vérification au flambement de l'axe Y

Le flambement constitue le point critique de l'axe Y en raison de sa longueur ($L = 0,30 \text{ m}$).

**Moment quadratique :**
$I = \frac{\pi d_n^4}{64} = 7,253 \times 10^{-11} \text{ m}^4$

**Force critique d'Euler (cas pivot-pivot, $K=1$) :**
$F_{cr, Y} = \frac{\pi^2 EI}{(KL)^2} = \frac{\pi^2 \times 210 \times 10^9 \times 7,253 \times 10^{-11}}{(1 \times 0,30)^2} = 1\,670 \text{ N}$

*   **Cas nominal :**
    $n_{flamb} = \frac{1\,670}{175,5} = 9,52$
    $9,52 > 2$ (**Validé**)

*   **Cas extrême :**
    $n_{flamb} = \frac{1\,670}{7\,340,5} = 0,23$
    $0,23 < 2$ (**Non validé**)

**Conclusion flambement :** La vis T8 est insuffisante pour le cas extrême sur l'axe Y.

## 3. Pression de matage vis/écrou

*   **Nombre de filets en prise :** $n_{filets} = \frac{L_{écrou}}{p} = \frac{15}{2} = 7,5$
*   **Surface de contact projetée :** $S_{contact} = 153,74 \text{ mm}^2$
*   **Pression admissible :** $P_{adm} = 5 \text{ à } 7 \text{ MPa}$

*   **Cas nominal :** $P_{nom} = \frac{175,5}{153,74} = 1,14 \text{ MPa}$ (**Validé**)
*   **Cas extrême :** $P_{ext} = \frac{7\,340,5}{153,74} = 47,75 \text{ MPa}$ (**Non validé**)

## 4. Rendement et irréversibilité

*   **Angle d'hélice ($\lambda$) :** $5,02^\circ$
*   **Angle de frottement ($\phi$) :** $5,91^\circ$ (avec $\mu = 0,10$)
*   **Rendement ($\eta$) :** $\frac{\tan \lambda}{\tan(\lambda + \phi)} = 0,455$ (**45,5 %**)
*   **Irréversibilité :** $\lambda < \phi$ ($5,02^\circ < 5,91^\circ$). La vis est **irréversible**.

## 5. Couple moteur et puissance

Moteur retenu : **NEMA 23** ($T_m = 1,26 \text{ Nm}$).

### Couple de charge
$T_{charge} = \frac{Fp}{2\pi\eta}$
*   **Cas nominal :** $0,123 \text{ Nm}$ (**Validé**)
*   **Cas extrême :** $5,14 \text{ Nm}$ (**Non validé**, supérieur au couple moteur)

### Dynamique et Inertie
*   **Inertie totale ($J_{total}$) :** $2,946 \times 10^{-5} \text{ kg}\cdot\text{m}^2$
*   **Accélération angulaire ($\ddot{\alpha}$) :** $1\,571 \text{ rad/s}^2$
*   **Couple d'accélération ($T_{acc}$) :** $0,046 \text{ Nm}$

### Couple total et Marge
*   **Cas nominal :** $T_{total} = 0,169 \text{ Nm}$. Marge = $7,45 > 2$ (**Validé**)
*   **Cas extrême :** $T_{total} = 5,18 \text{ Nm}$. Marge = $0,24 < 2$ (**Non validé**)

### Puissance mécanique ($V_f = 3\,000 \text{ mm/min}$)
*   **Vitesse de rotation :** $1\,500 \text{ tr/min}$
*   **Puissance nominale :** $26,6 \text{ W}$ (**Validé**)
*   **Puissance extrême :** $814 \text{ W}$ (**Incompatible**)

## 6. Vitesse critique de la vis
$N_{cr, Y} = \frac{N_{cr, X}}{4} = \frac{33\,581}{4} = 8\,395 \text{ tr/min}$
Comparaison avec $N_{max} = 1\,500 \text{ tr/min}$ : ratio de **5,60**.
La vitesse critique est validée, mais l'axe Y est plus sensible au **fouettement** que l'axe X.

## 7. Dimensionnement des guidages linéaires
Guidage : 2 rails **HGR15** + 4 patins **HGH15CA**.
$C = 16\,600 \text{ N}$ ; $C_0 = 23\,400 \text{ N}$.

### Charges et Moments
*   **Poids total ($F_z$) :** $107,91 \text{ N}$
*   **Moment de renversement ($M_{renvers}$) :** $4,71 \text{ Nm}$
*   **Charge équivalente ($P_e$) :**
    *   **Nominal :** $154,14 \text{ N}$
    *   **Extrême :** $4\,206,54 \text{ N}$

### Durée de vie ($L_{10h}$)
*   **Cas nominal :** $3,47 \times 10^8 \text{ h} \gg 20\,000 \text{ h}$ (**Validé**)
*   **Cas extrême :** $17\,070 \text{ h} < 20\,000 \text{ h}$ (**Limite**)

### Sécurité statique ($f_s$)
*   **Cas extrême :** $6,68 \geq 3$ (**Validé**)

## 8. Roulements d'appui de la vis (KP08/KFL08)
*   **Cas nominal :** $L_{10h} = 227\,805 \text{ h}$ (**Validé**)
*   **Cas extrême :** $L_{10h} \approx 0,90 \text{ h}$ (**Incompatible**)
## 9. Synthèse du dimensionnement de l'axe Y

| Critère | Valeur | Seuil | Coeff. Sécu. | Verdict |
| :--- | :--- | :--- | :---: | :--- |
| **Traction vis — nominal** | 5,81 MPa | 300 MPa | 51,6 | **Validé** |
| **Traction vis — extrême** | 243,14 MPa | 300 MPa | 1,23 | **Limite** |
| **Flambement vis — nominal** | $n = 9,52$ | $\geq 2$ | 9,52 | **Validé** |
| **Flambement vis — extrême** | $n = 0,23$ | $\geq 2$ | 0,23 | **Échec** |
| **Matage vis/écrou — nominal** | 1,14 MPa | 5 à 7 MPa | > 4 | **Validé** |
| **Matage vis/écrou — extrême** | 47,75 MPa | 5 à 7 MPa | < 1 | **Échec** |
| **Rendement vis** | 45,5 % | - | - | **Acceptable** |
| **Irréversibilité** | $\lambda < \phi$ | Oui | - | **Validé** |
| **Couple moteur — nominal** | 0,169 Nm | 1,26 Nm | 7,45 | **Validé** |
| **Couple moteur — extrême** | 5,18 Nm | 1,26 Nm | 0,24 | **Échec** |
| **Puissance nominale** | 26,6 W | Compatible | - | **Validé** |
| **Puissance extrême** | 814 W | Trop élevé | - | **Échec** |
| **Vitesse critique** | 8 395 tr/min | 1 500 tr/min | 5,60 | **Validé** |
| **Guidages — durée nominale** | $3,47 \times 10^8$ h | $> 20\,000$ h | - | **Validé** |
| **Guidages — durée extrême** | $17\,070$ h | $> 20\,000$ h | 0,85 | **Limite** |
| **Sécurité statique guidages** | 6,68 | $\geq 3$ | 6,68 | **Validé** |
| **Roulements — nominal** | $227\,805$ h | $> 20\,000$ h | 11,39 | **Validé** |
| **Roulements — extrême** | 0,90 h | $> 20\,000$ h | - | **Échec** |

## Conclusion
L'axe Y est parfaitement dimensionné pour les efforts de service nominaux. Cependant, sa longueur accrue le rend vulnérable au **flambement** et au **matage** en cas d'efforts extrêmes. L'utilisation d'une vis à billes et de paliers préchargés serait nécessaire pour une version industrielle supportant des conditions extrêmes prolongées.



# 3.3.3 Dimensionnement de l'axe Z (mouvement vertical)

L’axe **Z** joue un rôle essentiel dans la qualité d’usinage, car il détermine directement la profondeur de passe, la stabilité de la broche et la précision du contact outil-matière. Son dimensionnement doit donc garantir à la fois la **résistance mécanique**, la **sécurité verticale** et l’**absence de chute intempestive** de la broche.

La transmission retenue est identique à celle des axes **X** et **Y**, à savoir une **vis trapézoïdale T8**. Toutefois, la course de l’axe **Z** est plus courte :
$L_Z = 120 \text{ mm}$

> Les caractéristiques de la vis T8 sont identiques à celles utilisées pour les axes X et Y.
### Vérification en traction — critère de Von Mises

La section résistante au diamètre de noyau est :
$A = \frac{\pi}{4} d_n^2 = \frac{\pi}{4} (0,0062)^2 = 3,019 \times 10^{-5} \text{ m}^2$

La contrainte normale est : $\sigma = \frac{F}{A}$
Le critère admissible est : $\sigma \leq \frac{R_e}{s}$ avec $s = 2$.
$\sigma_{adm} = \frac{600}{2} = 300 \text{ MPa}$

**Cas nominal :**
$\sigma_{nom} = \frac{70,45}{3,019 \times 10^{-5}} = 2,33 \times 10^6 \text{ Pa} = 2,33 \text{ MPa}$
Le coefficient de sécurité effectif est :
$n_{traction,nom} = \frac{300}{2,33} = 128,6$
**La traction est donc très largement vérifiée.**

**Cas extrême :**
$\sigma_{extreme} = \frac{2219,45}{3,019 \times 10^{-5}} = 73,51 \text{ MPa}$
Comparaison : $73,51 < 300$.
**La vis reste validée en traction même en cas extrême.**

**Diamètre minimal théorique :**
$d_{min} = \sqrt{\frac{4Fs}{\pi R_e}}$

- **Cas nominal :** $d_{min,nom} = \sqrt{\frac{4 \times 70,45 \times 2}{\pi \times 600 \times 10^6}} = 0,55 \text{ mm}$
- **Cas extrême :** $d_{min,extreme} = \sqrt{\frac{4 \times 2219,45 \times 2}{\pi \times 600 \times 10^6}} = 3,07 \text{ mm}$

Le diamètre de noyau réel est $d_n = 6,2 \text{ mm}$.
Puisque $d_n > d_{min,extreme}$, la **vis T8 est validée en traction**.
### Vérification au flambement

Le moment quadratique de la vis est :
$I = \frac{\pi d_n^4}{64} = \frac{\pi(0,0062)^4}{64} = 7,253 \times 10^{-11} \text{ m}^4$

En assimilant le montage à un cas **pivot-pivot** ($K = 1$), la charge critique d’Euler est :
$F_{cr} = \frac{\pi^2 EI}{(KL)^2}$
$F_{cr,Z} = \frac{\pi^2 \times 210 \times 10^9 \times 7,253 \times 10^{-11}}{(1 \times 0,12)^2} = 10440 \text{ N}$

- **Cas nominal :** $n_{flamb,nom} = \frac{F_{cr,Z}}{F_{Z,nom}} = \frac{10440}{70,45} = 148,2$ (Très largement satisfait).
- **Cas extrême :** $n_{flamb,extreme} = \frac{10440}{2219,45} = 4,70$

Même en cas extrême, le coefficient reste au-dessus du minimum ($4,70 > 2$). Contrairement à l’axe **Y**, le **flambement n’est pas critique** pour l’axe **Z** grâce à la faible longueur libre de la vis.

**Conclusion : Flambement largement validé pour l’axe Z.**
### Pression de matage vis/écrou

Nombre de filets en prise : $n_{filets} = \frac{L_{ecrou}}{p} = \frac{15}{2} = 7,5$
Surface de contact projetée :
$S_{contact} = n_{filets} \pi D_m \frac{d - d_n}{2} = 7,5 \times \pi \times 7,25 \times \frac{8 - 6,2}{2} = 153,74 \text{ mm}^2$

Pression de contact : $P = \frac{F}{S_{contact}}$

- **Cas nominal :** $P_{nom} = \frac{70,45}{153,74} = 0,46 \text{ MPa}$
- **Pression admissible :** $P_{adm} = 5 \text{ à } 7 \text{ MPa}$
Comparaison : $0,46 < 5$. **Le matage est très largement validé en régime nominal.**

**Charge permanente due au poids :**
Même à l’arrêt, l’écrou supporte le poids de la broche : $W = 14,72 \text{ N}$.
$P_W = \frac{14,72}{153,74} = 0,096 \text{ MPa}$ (Risque nul de matage permanent).

- **Cas extrême :** $P_{extreme} = \frac{2219,45}{153,74} = 14,44 \text{ MPa}$
Comparaison : $14,44 > 7$.
**Le matage n'est pas admissible en cas extrême prolongé.** La vis T8 est adaptée au nominal, mais pas à un effort maximal théorique en pleine matière.
### Irréversibilité de l’axe Z

L’irréversibilité conditionne la **sécurité verticale** : la broche doit rester en position même en cas de coupure d'alimentation.

- Angle d’hélice : $\lambda = \arctan(\frac{p}{\pi D_m}) = \arctan(\frac{2}{\pi \times 7,25}) = 5,02^\circ$
- Angle de frottement : $\varphi = \arctan(\frac{\mu}{\cos \beta}) = \arctan(\frac{0,10}{\cos 15^\circ}) = 5,91^\circ$

Condition d’irréversibilité : $\lambda < \varphi$.
Or, $5,02^\circ < 5,91^\circ$. **La vis T8 est donc irréversible (auto-bloquante).**

Rendement direct : $\eta = \frac{\tan \lambda}{\tan(\lambda + \varphi)} = \frac{\tan(5,02^\circ)}{\tan(5,02^\circ + 5,91^\circ)} = 0,455 \text{ (soit 45,5 \%)}$
Rendement inverse : $\eta_{inv} = \frac{\tan(\lambda - \varphi)}{\tan \lambda} = \frac{\tan(5,02^\circ - 5,91^\circ)}{\tan(5,02^\circ)} = -0,177$
$\eta_{inv} \leq 0$ confirme l’**irréversibilité**.

**Avantages pour la sécurité :**
- Pas de chute spontanée de la broche.
- Aucun frein électromagnétique requis.
- Pas de couple moteur permanent à l’arrêt.
### Couple moteur et puissance

Moteur **NEMA 23** ($T_m = 1,26 \text{ Nm}$), pas $p = 0,002 \text{ m}$, rendement $\eta = 0,455$.

**Couple en montée (Cas dimensionnant) :**
$T_{mont} = \frac{(W + F_{frott} + F_p)p}{2\pi\eta}$

- **Régime nominal :** $W + F_{frott} + F_p = 14,72 + 10 + 45 = 69,72 \text{ N}$
  $T_{mont,nom} = \frac{69,72 \times 0,002}{2\pi \times 0,455} = 0,0488 \text{ Nm}$
- **Cas extrême :** $W + F_{frott} + F_{p,extreme} = 2218,72 \text{ N}$
  $T_{mont,extreme} = \frac{2218,72 \times 0,002}{2\pi \times 0,455} = 1,553 \text{ Nm}$

**Couple en descente :**
$T_{desc} = \frac{(F_p - W)p}{2\pi\eta}$
- **Nominal :** $0,0212 \text{ Nm}$
- **Extrême :** $1,525 \text{ Nm}$

**Couple d’inertie :**
$J_{total} = J_{rotor} + J_{vis} + J_{charge} = 2,8 \times 10^{-5} + 1,37 \times 10^{-7} + 1,52 \times 10^{-7} = 2,829 \times 10^{-5} \text{ kg}\cdot\text{m}^2$
$\alpha = 1571 \text{ rad/s}^2 \implies T_{acc} = J_{total}\alpha = 0,0444 \text{ Nm}$

**Synthèse Couple / Marge :**
- **Total nominal :** $T_{total,nom} = 0,0932 \text{ Nm}$ (Marge = $13,51$). **Moteur largement suffisant.**
- **Total extrême :** $T_{total,extreme} = 1,597 \text{ Nm}$ (Marge = $0,79$). **Le moteur NEMA 23 ne peut pas supporter ce cas en continu.**
### Vitesse critique

- Vitesse max rotation : $N = \frac{V_f}{p} = \frac{3000}{2} = 1500 \text{ tr/min}$
- Vitesse critique calculée : $N_{cr,Z} = 52470 \text{ tr/min}$
Rapport $\frac{N_{cr,Z}}{N_{max}} = 34,98$. La vis fonctionne très loin de sa vitesse critique.
### Vérification des roulements et guidages

**Roulements :**
$L_{10h,nom} = 4,77 \times 10^6 \text{ h}$ (Validé).
$L_{10h,extreme} = 48,3 \text{ h}$ (Non admissible en prolongé).

**Guidages (4 patins sur 2 rails) :**
Données : $C = 16600 \text{ N}$, $C_0 = 23400 \text{ N}$, $f_w = 1,2$.
- **Durée de vie nominale :** $L_{10h,nom} = 3,21 \times 10^{10} \text{ h}$.
- **Coefficient statique extrême :** $f_{s,extreme} = 23,48$ (Bien supérieur au critère $f_s \geq 4$).

**Guidages de l'axe Z validés en configuration verticale.**
### Synthèse globale des trois axes linéaires

| Paramètre | Axe X | Axe Y | Axe Z |
| :--- | :--- | :--- | :--- |
| **Masse portée** | $7,5 \text{ kg}$ | $11 \text{ kg}$ | $1,5 \text{ kg}$ |
| 🟢 **Course** | $200 \text{ mm}$ | $300 \text{ mm}$ | $120 \text{ mm}$ |
| **Charge nominale $F_{tot}$** | $93,75 \text{ N}$ | $175,5 \text{ N}$ | $70,45 \text{ N}$ |
| **Charge extrême** | $3675,75 \text{ N}$ | $7340,5 \text{ N}$ | $2219,45 \text{ N}$ |
| **$n_{traction}$ nominal** | $96,6$ | $51,6$ | $128,6$ |
| 🟢 **$n_{flambement}$ nominal** | $40,09$ | $9,52$ | $148,2$ |
| 🟢 **$n_{flambement}$ extrême** | $1,02$ | $0,23$ | $4,70$ |
| **Pression matage nominale** | $0,61 \text{ MPa}$ | $1,14 \text{ MPa}$ | $0,46 \text{ MPa}$ |
| **Pression matage extrême** | $23,91 \text{ MPa}$ | $47,75 \text{ MPa}$ | $14,44 \text{ MPa}$ |
| 🟢 **Couple total nominal** | $0,112 \text{ Nm}$ | $0,169 \text{ Nm}$ | $0,093 \text{ Nm}$ |
| 🟢 **Marge moteur nominale** | $11,25$ | $7,45$ | $13,51$ |

# Section 3.5 — Étude de la structure et analyse dynamique (Structure révisée)

## 3.5.1 Analyse de rigidité du châssis

Après le dimensionnement des axes linéaires et des axes rotatifs du Trunnion, il est nécessaire de vérifier que la structure porteuse de la machine possède une rigidité suffisante pour maintenir la précision géométrique pendant l'usinage. En effet, une structure trop flexible entraînerait des déplacements relatifs entre la broche et la pièce, ce qui dégraderait directement la **précision dimensionnelle**, la **répétabilité** et l'**état de surface**.

Le châssis retenu pour le prototype est inspiré de la conception **Tree CNC 5-axis** (GrabCAD). Il est constitué de **tubes acier creux de section $20 \times 20 \times 2 \text{ mm}$**, en acier de construction **S235JR**. Ce choix se distingue des profilés aluminium extrudés habituels (80×80 mm) pour les raisons suivantes :

- **Coût réduit** : les tubes acier standard sont nettement moins onéreux que les profilés aluminium rainurés ;
- **Disponibilité** : les tubes 20×20 sont disponibles dans tout atelier de construction métallique ;
- **Soudabilité** : l'acier S235 se soude facilement, permettant des modifications en atelier ;
- **Compatibilité** : la structure s'inscrit dans l'architecture compacte de la Tree CNC, validée par de nombreuses réalisations communautaires.

Pour compenser la faible inertie individuelle d'un tube 20×20 par rapport à un profilé massif, **quatre tubes sont utilisés en parallèle** pour les éléments structuraux principaux (pont, montants). Cette stratégie multiplie par quatre le moment d'inertie effectif tout en conservant une structure légère et modulaire.

**Hiérarchie structurelle et axes suspendus** : dans l'architecture retenue, seuls les axes **X**, **A** et **C** sont suspendus (non directement liés au châssis). Les axes **Y** et **Z** sont directement intégrés à la structure porteuse. Le guidage de l'axe Y est assuré par **deux arbres lisses en acier de $\phi 5 \text{ mm}$**. Le chariot de l'axe X utilise un **profilé aluminium $80 \times 20 \text{ mm}$**.

Les dimensions du châssis sont conformes aux courses des vis, avec des marges pour les paliers et butées :
- **Pont** (direction X) : $L_{pont} = 300 \text{ mm}$ (pour une course $L_X = 200 \text{ mm}$)
- **Montants** (direction Z) : $H = 250 \text{ mm}$ (pour une course $L_Z = 150 \text{ mm}$)
- **Base** (direction Y) : $\approx 400 \text{ mm}$ (pour une course $L_Y = 300 \text{ mm}$)

L'objectif de rigidité globale est adapté à la nature de prototype compact :
$$K_{global} > 5 \times 10^5 \text{ N/m}$$

Ce critère est volontairement plus faible que le seuil de $10^6 \text{ N/m}$ couramment retenu pour les machines industrielles, car la Tree CNC est conçue pour un usinage léger à modéré de l'aluminium avec des passes réduites.

### 3.5.1.1 — Propriétés du tube acier 20×20×2

Le tableau suivant regroupe les propriétés retenues pour le tube acier creux.

| Propriété | Symbole | Valeur retenue | Unité | Commentaire |
| :--- | :---: | :---: | :---: | :--- |
| Section extérieure | — | $20 \times 20$ | mm | Tube carré creux |
| Épaisseur de paroi | $t$ | $2$ | mm | Standard commerce |
| Dimension intérieure | — | $16 \times 16$ | mm | $a - 2t$ |
| Nuance | — | S235JR | — | Acier de construction |
| Module d'Young | $E$ | $210$ | GPa | Acier |
| Limite d'élasticité | $R_e$ | $235$ | MPa | Norme NF EN 10219 |
| Masse volumique | $\rho$ | $7\,850$ | kg/m³ | Acier |
| Section résistante | $A$ | $144$ | mm² | $20^2 - 16^2$ |
| Moment d'inertie | $I$ | $7\,872$ | mm�� | $\frac{20^4 - 16^4}{12}$ |
| Moment d'inertie SI | $I$ | $7,872 \times 10^{-9}$ | m�� | — |
| Module de résistance | $W$ | $787,2$ | mm³ | $I/c$, $c = 10$ mm |
| Masse linéique | $m_l$ | $1,13$ | kg/m | $A \times \rho$ |

Le moment d'inertie est calculé par :
$$I = \frac{a_{ext}^4 - a_{int}^4}{12} = \frac{20^4 - 16^4}{12} = \frac{160\,000 - 65\,536}{12} = 7\,872 \text{ mm}^4$$

#### Propriétés effectives pour 4 tubes en parallèle

Pour les éléments porteurs (pont et montants), **quatre tubes** travaillent en parallèle. Dans l'hypothèse conservative de même axe neutre (sans bénéfice d'espacement), le moment d'inertie effectif est :
$$I_{eff} = 4 \times I_{tube} = 4 \times 7\,872 = 31\,488 \text{ mm}^4$$
$$I_{eff} = 3,149 \times 10^{-8} \text{ m}^4$$

Le produit de rigidité en flexion vaut :
$$EI_{eff} = 210 \times 10^9 \times 3,149 \times 10^{-8} = 6\,612{,}9 \text{ N} \cdot \text{m}^2$$

Le module de résistance effectif est :
$$W_{eff} = 4 \times 787,2 = 3\,148{,}8 \text{ mm}^3 = 3,149 \times 10^{-6} \text{ m}^3$$

**Remarque** : si les quatre tubes sont espacés et reliés par des goussets ou des traverses, le théorème de Huygens (axes parallèles) augmenterait considérablement le moment d'inertie effectif. L'estimation ci-dessus est donc conservative.

#### Comparaison avec le profilé aluminium 80×80

| Paramètre | Profilé alu 80×80 | 4 tubes acier 20×20×2 | Ratio |
| :--- | :--- | :--- | :--- |
| $I$ | $118 \text{ cm}^4$ | $3,15 \text{ cm}^4$ | $\div 37,5$ |
| $E$ | $69 \text{ GPa}$ | $210 \text{ GPa}$ | $\times 3,04$ |
| $EI$ | $8\,142 \text{ N} \cdot \text{m}^2$ | $6\,613 \text{ N} \cdot \text{m}^2$ | $\div 1,23$ |
| $R_e$ | $130 \text{ MPa}$ | $235 \text{ MPa}$ | $\times 1,81$ |
| Masse linéique | $\approx 5 \text{ kg/m}$ | $4 \times 1,13 = 4,52 \text{ kg/m}$ | $\times 0,90$ |

Le produit $EI$ effectif des 4 tubes acier atteint **81%** de celui du profilé aluminium 80×80. Le module d'Young de l'acier ($3\times$ supérieur) compense en grande partie la réduction d'inertie géométrique.

### 3.5.1.2 — Rigidité du pont — modèle poutre sur deux appuis

Le pont supérieur du portique est modélisé comme une poutre simplement appuyée de longueur :
$$L_{pont} = 300 \text{ mm} = 0,3 \text{ m}$$

soumise à une charge concentrée au centre. L'effort nominal de coupe retenu est $F = 180 \text{ N}$.

La flèche maximale est :
$$\delta_{pont} = \frac{FL^3}{48EI_{eff}}$$

*Application numérique :*
$$\delta_{pont} = \frac{180 \times (0,3)^3}{48 \times 6\,612{,}9} = \frac{180 \times 0,027}{317\,419} = \frac{4,86}{317\,419}$$
$$\delta_{pont} = 1,53 \times 10^{-5} \text{ m} = 15,3 \text{ }\mu\text{m}$$

La rigidité correspondante est :
$$K_{pont} = \frac{F}{\delta_{pont}} = \frac{180}{1,53 \times 10^{-5}}$$
$$K_{pont} = 1,176 \times 10^7 \text{ N/m}$$

Comparaison au critère :
$$K_{pont} > 5 \times 10^5 \text{ N/m}$$
$$1,176 \times 10^7 > 5 \times 10^5$$

Le pont est donc **largement validé** en rigidité. La longueur réduite ($300$ mm au lieu de $500$ mm) compense la perte d'inertie.

### 3.5.1.3 — Rigidité des montants — modèle encastré-libre

Les montants verticaux sont assimilés à des poutres encastrées à la base et libres en tête. La hauteur est :
$$H = 250 \text{ mm} = 0,25 \text{ m}$$

Chaque côté du portique est constitué de **4 tubes en parallèle**. La charge est partagée par deux côtés :
$$F_i = \frac{F}{2} = \frac{180}{2} = 90 \text{ N}$$

La flèche d'un côté (4 tubes) sous 90 N est :
$$\delta_{montant} = \frac{F_i H^3}{3 E I_{eff}} = \frac{90 \times (0,25)^3}{3 \times 6\,612{,}9}$$
$$\delta_{montant} = \frac{90 \times 0,015625}{19\,838{,}7} = \frac{1,406}{19\,838{,}7}$$
$$\delta_{montant} = 7,09 \times 10^{-5} \text{ m} = 70,9 \text{ }\mu\text{m}$$

La rigidité d'un côté est :
$$K_{montant,1} = \frac{F_i}{\delta_{montant}} = \frac{90}{7,09 \times 10^{-5}}$$
$$K_{montant,1} = 1,269 \times 10^6 \text{ N/m}$$

Les deux côtés travaillant en parallèle :
$$K_{montants} = 2 \times K_{montant,1} = 2 \times 1,269 \times 10^6$$
$$K_{montants} = 2,538 \times 10^6 \text{ N/m}$$

Les montants restent donc au-dessus du critère :
$$2,538 \times 10^6 > 5 \times 10^5$$

mais ils constituent la contribution principale à la flexibilité globale du portique.

### 3.5.1.4 — Rigidité globale — modèle de ressorts en série

La rigidité théorique pont + montants est :
$$\frac{1}{K_{th}} = \frac{1}{K_{pont}} + \frac{1}{K_{montants}} = \frac{1}{1,176 \times 10^7} + \frac{1}{2,538 \times 10^6}$$
$$\frac{1}{K_{th}} = 8,50 \times 10^{-8} + 3,94 \times 10^{-7} = 4,79 \times 10^{-7}$$
$$K_{th} = 2,088 \times 10^6 \text{ N/m}$$

Les assemblages boulonnés réduisent la rigidité réelle. On introduit un coefficient de pénalité :
$$K_{assemblages} = 0,7 \times K_{th} = 0,7 \times 2,088 \times 10^6$$
$$K_{assemblages} = 1,462 \times 10^6 \text{ N/m}$$

La rigidité globale devient :
$$\frac{1}{K_{total}} = \frac{1}{K_{pont}} + \frac{1}{K_{montants}} + \frac{1}{K_{assemblages}}$$
$$\frac{1}{K_{total}} = 8,50 \times 10^{-8} + 3,94 \times 10^{-7} + 6,84 \times 10^{-7} = 1,163 \times 10^{-6}$$
$$K_{total} = 8,60 \times 10^5 \text{ N/m}$$

Comparaison au critère :
$$K_{total} > 5 \times 10^5 \text{ N/m}$$
$$8,60 \times 10^5 > 5 \times 10^5$$

Le châssis respecte donc l'objectif de rigidité globale adapté au prototype.

La déformation globale sous l'effort nominal $F = 180 \text{ N}$ vaut :
$$\delta_{global} = \frac{F}{K_{total}} = \frac{180}{8,60 \times 10^5}$$
$$\delta_{global} = 2,09 \times 10^{-4} \text{ m} = 209 \text{ }\mu\text{m}$$

Sous une charge unitaire de 1 N :
$$\delta_{1N} = \frac{1}{8,60 \times 10^5} = 1,16 \text{ }\mu\text{m/N}$$

Cette valeur est supérieure à la compliance du châssis en profilé aluminium 80×80 ($0,70 \text{ }\mu\text{m/N}$), mais reste compatible avec un prototype destiné à des passes légères à modérées. La déformation réelle sera atténuée par les goussets, les plaques de renfort et la fermeture partielle du portique.

### 3.5.1.5 — Contraintes et coefficients de sécurité

La contrainte admissible est :
$$\sigma_{adm} = \frac{R_e}{s} = \frac{235}{2} = 117,5 \text{ MPa}$$

#### a) Pont supérieur

$$M_{pont,max} = \frac{FL}{4} = \frac{180 \times 0,3}{4} = 13,5 \text{ N} \cdot \text{m}$$

$$\sigma_{pont} = \frac{M_{pont,max}}{W_{eff}} = \frac{13,5}{3,149 \times 10^{-6}} = 4,29 \times 10^6 \text{ Pa} = 4,29 \text{ MPa}$$

$$n_{pont} = \frac{\sigma_{adm}}{\sigma_{pont}} = \frac{117,5}{4,29} = 27,4$$

Le pont est **largement validé** en résistance.

#### b) Montants verticaux

$$M_{montant} = F_i \times H = 90 \times 0,25 = 22,5 \text{ N} \cdot \text{m}$$

$$\sigma_{montant} = \frac{22,5}{3,149 \times 10^{-6}} = 7,14 \times 10^6 \text{ Pa} = 7,14 \text{ MPa}$$

$$n_{montant} = \frac{117,5}{7,14} = 16,5$$

Les montants sont **très largement validés** en contrainte.

#### Remarque

Les contraintes mécaniques restent très faibles par rapport à la limite d'élasticité de l'acier S235. Le dimensionnement du châssis n'est donc pas gouverné par la résistance, mais par la **rigidité**, conformément aux structures de machines-outils classiques. De plus, la limite élastique de l'acier S235 ($235 \text{ MPa}$) est supérieure à celle de l'aluminium 6063-T5 ($130 \text{ MPa}$), ce qui confère un avantage en résistance malgré des sections plus petites.

### 3.5.1.6 — Synthèse

| Élément | Rigidité $K$ (N/m) | Déplacement sous 180 N | Contrainte $\sigma$ | Coefficient $n$ | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Pont supérieur (4 tubes) | $1,176 \times 10^7$ | $15,3 \text{ }\mu\text{m}$ | $4,29$ MPa | $27,4$ | **Validé** |
| Deux côtés montants (4+4 tubes) | $2,538 \times 10^6$ | $70,9 \text{ }\mu\text{m}$ | $7,14$ MPa | $16,5$ | **Validé** |
| Assemblages pénalisés (×0,7) | $1,462 \times 10^6$ | — | — | — | À rigidifier |
| **Châssis global** | $8,60 \times 10^5$ | $209 \text{ }\mu\text{m}$ | — | — | **Validé** ($> 5 \times 10^5$) |

**Conclusion de la section 3.5.1** : L'analyse montre que le châssis en **tubes acier 20×20×2 mm** (4 en parallèle) respecte l'objectif de rigidité adapté au prototype ($K > 5 \times 10^5 \text{ N/m}$). La rigidité globale atteint $K_{total} = 8,60 \times 10^5 \text{ N/m}$. Les contraintes restent très faibles (coefficients de sécurité $> 16$). Les dimensions réduites du châssis ($L_{pont} = 300 \text{ mm}$, $H = 250 \text{ mm}$) compensent partiellement la perte d'inertie par rapport aux profilés 80×80 aluminium.

Les recommandations suivantes sont retenues :
- ajouter des goussets triangulaires aux jonctions base-montants ;
- doubler les boulons aux zones de reprise d'effort ;
- fermer partiellement l'arrière du portique par une plaque ;
- limiter les porte-à-faux de la broche et du Trunnion.

## 3.5.2 Analyse modale simplifiée

L'analyse de rigidité menée en section 3.5.1 a permis d'estimer la raideur globale du châssis. Toutefois, une structure mécaniquement résistante en statique peut présenter des problèmes dynamiques si ses **fréquences propres** coïncident avec les fréquences d'excitation générées par la broche, les dents de l'outil ou les moteurs pas-à-pas. L'objectif de cette section est d'effectuer une analyse modale simplifiée.

Les données de la section 3.5.1 sont :
$$K_{pont} = 1,176 \times 10^7 \text{ N/m}$$
$$K_{montants} = 2,538 \times 10^6 \text{ N/m}$$
$$K_{global} = 8,60 \times 10^5 \text{ N/m}$$

La masse vibratoire globale retenue est :
$$m_{vib} \approx 10 \text{ kg}$$

Cette valeur est inférieure aux 15 kg du châssis en profilé 80×80, car la structure en tubes acier est plus légère ($4 \times 1,13 = 4,52 \text{ kg/m}$ contre $\approx 5 \text{ kg/m}$) et le volume global du châssis est plus compact.

Le taux d'amortissement retenu est :
$$\xi = 0,03$$

### 3.5.2.1 — Fréquences propres — modèle à un degré de liberté

$$f_n = \frac{1}{2\pi} \sqrt{\frac{K}{m}}$$

#### a) Fréquence propre du pont supérieur

$$f_{n,pont} = \frac{1}{2\pi} \sqrt{\frac{1,176 \times 10^7}{10}} = \frac{1}{2\pi} \times 1\,084{,}8$$
$$f_{n,pont} = 172,6 \text{ Hz}$$

#### b) Fréquence propre des montants

$$f_{n,montants} = \frac{1}{2\pi} \sqrt{\frac{2,538 \times 10^6}{10}} = \frac{1}{2\pi} \times 503{,}8$$
$$f_{n,montants} = 80,2 \text{ Hz}$$

#### c) Fréquence propre globale

$$f_{n,global} = \frac{1}{2\pi} \sqrt{\frac{8,60 \times 10^5}{10}} = \frac{1}{2\pi} \times 293{,}3$$
$$f_{n,global} = 46,7 \text{ Hz}$$

#### Tableau des fréquences propres simplifiées

| Sous-système | Raideur $K$ (N/m) | Masse $m$ (kg) | Fréquence propre $f_n$ |
| :--- | :--- | :--- | :--- |
| Pont supérieur | $1,176 \times 10^7$ | $10$ | $172,6$ Hz |
| Montants verticaux | $2,538 \times 10^6$ | $10$ | $80,2$ Hz |
| Base + Trunnion / global | $8,60 \times 10^5$ | $10$ | $46,7$ Hz |

Les fréquences propres sont du même ordre de grandeur que celles obtenues avec le châssis en profilé 80×80 ($49,1$, $81,2$ et $229,8$ Hz), car la réduction de masse ($10$ vs $15$ kg) compense partiellement la réduction de rigidité. Le mode du pont est toutefois abaissé de $229,8$ à $172,6$ Hz.

### 3.5.2.2 — Fréquences d'excitation

| Source d'excitation | Formule | Fréquence |
| :--- | :--- | :--- |
| Rotation broche | $f = N/60$ | $144,7$ Hz |
| Passage dents ($Z = 3$) | $f = Z \times N/60$ | $434$ Hz |
| Moteurs pas-à-pas | Bande empirique | $100$ à $200$ Hz |

### 3.5.2.3 — Critère d'évitement et amplification dynamique

Le critère d'évitement retenu est : $0,7 < r < 1,3$ avec $r = f_{excit}/f_n$.

L'amplification dynamique est :
$$A = \frac{1}{\sqrt{(1 - r^2)^2 + (2\xi r)^2}}$$

#### a) Comparaison avec le mode global — $f_n = 46,7$ Hz

- Broche : $r = 144,7/46,7 = 3,10$ → **hors zone critique**
- Dents : $r = 434/46,7 = 9,29$ → **hors zone critique**
- PaP 100 Hz : $r = 100/46,7 = 2,14$ → **hors zone critique**

#### b) Comparaison avec le mode des montants — $f_n = 80,2$ Hz

- Broche : $r = 144,7/80,2 = 1,80$ → hors zone critique
- PaP 100 Hz : $r = 100/80,2 = 1,25$ → **zone sensible** ($0,7 < 1,25 < 1,3$)
- Amplification estimée : $A \approx 1,9$

#### c) Comparaison avec le mode du pont — $f_n = 172,6$ Hz

- Broche : $r = 144,7/172,6 = 0,84$ → **zone sensible** ($0,7 < 0,84 < 1,3$)
- Amplification estimée : $A \approx 3,5$
- PaP 200 Hz : $r = 200/172,6 = 1,16$ → **zone sensible** ($0,7 < 1,16 < 1,3$)
- Amplification estimée : $A \approx 2,3$
- Dents 434 Hz : $r = 434/172,6 = 2,51$ → hors zone critique

**Observation importante** : le mode du pont à $172,6$ Hz est désormais plus proche de la fréquence de broche ($144,7$ Hz) qu'avec le châssis 80×80. Ce rapprochement (ratio $r = 0,84$) implique une amplification non négligeable. Il sera essentiel de rigidifier le pont ou d'adapter la vitesse de broche.

### 3.5.2.4 — Diagramme de Campbell simplifié

Les zones critiques de vitesse de broche sont :

| Mode | $f_n$ (Hz) | Zone critique broche $1\times$ | Zone critique dents $3\times$ |
| :--- | :--- | :--- | :--- |
| Global | $46,7$ | $1\,961$ à $3\,643$ tr/min | $654$ à $1\,214$ tr/min |
| Montants | $80,2$ | $3\,368$ à $6\,256$ tr/min | $1\,123$ à $2\,085$ tr/min |
| Pont | $172,6$ | $7\,249$ à $13\,463$ tr/min | $2\,416$ à $4\,488$ tr/min |

La vitesse nominale de broche $N = 8\,680 \text{ tr/min}$ se situe **dans la zone critique broche 1× du mode du pont** ($7\,249$ à $13\,463$ tr/min). Ce résultat est une conséquence directe de l'abaissement de la fréquence propre du pont avec les tubes 20×20.

**Recommandations prioritaires** :
- Rigidifier le pont par des traverses et goussets afin d'augmenter $f_{n,pont}$ au-dessus de $200$ Hz ;
- Envisager une vitesse de broche réduite ($\leq 7\,000$ tr/min) ou une traversée rapide de la zone sensible ;
- Éviter la plage $3\,200$ à $6\,300$ tr/min (croisement montants/dents).

### 3.5.2.5 — Synthèse modale

| Mode | $f_n$ | Excitation la plus proche | Ratio $r$ | Amplification | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Global | $46,7$ Hz | Broche 144,7 Hz | $3,10$ | $0,12$ | **Hors résonance** |
| Montants | $80,2$ Hz | PaP 100 Hz | $1,25$ | $1,9$ | **Zone sensible** |
| Pont | $172,6$ Hz | Broche 144,7 Hz | $0,84$ | $3,5$ | **Zone sensible** |
| Pont | $172,6$ Hz | PaP 200 Hz | $1,16$ | $2,3$ | **Zone sensible** |

**Conclusion de la section 3.5.2** : L'analyse modale montre que le châssis en tubes acier 20×20 présente des fréquences propres comparables au châssis 80×80 pour les modes global et montants, mais un mode du pont significativement plus bas ($172,6$ vs $229,8$ Hz). Ce rapprochement avec la fréquence de broche nécessite une attention particulière lors de la conception des renforts et de la stratégie d'usinage.



# Section 3.6 — Simulation par Éléments Finis (FEA)

Cette section complète l'étude analytique par une **validation numérique** sous SolidWorks Simulation, afin de vérifier la cohérence des résultats, d'identifier les concentrations de contraintes et de confirmer les fréquences propres principales du système.

## 3.6.1 Paramétrage SolidWorks Simulation

### 3.6.1.1 — Simplification du modèle CAO

Le modèle CAO est simplifié : suppression de la visserie non structurale, des câbles, des connecteurs, des marquages et des éléments de protection. Les géométries critiques sont conservées : gorges de clavettes, épaulements, congés, interfaces arbre/roulement, supports de paliers et zones de reprise d'efforts.

La machine est divisée en sous-ensembles :
1. Châssis (tubes acier 20×20)
2. Ensemble Trunnion (aluminium usiné)
3. Arbres $A$ et $C$
4. Vis T8 des axes linéaires
5. Assemblage global

### 3.6.1.2 — Assignation des matériaux

| Composant | Matériau | Module $E$ | Limite élastique $R_e$ | $\rho$ |
| :--- | :--- | :--- | :--- | :--- |
| Châssis (tubes 20×20×2) | Acier S235JR | 210 GPa | 235 MPa | $7\,850$ kg/m³ |
| Chariot axe X | Alu 80×20 (AW-6063-T5) | 69 GPa | 130 MPa | $2\,700$ kg/m³ |
| Ensemble Trunnion | Aluminium usiné (AW-6082) | 70 GPa | 250 MPa | $2\,710$ kg/m³ |
| Arbres A et C | Acier C45 normalisé | 210 GPa | 340 MPa | $7\,850$ kg/m³ |
| Vis T8 | Acier 45SCD6 | 210 GPa | 600 MPa | $7\,850$ kg/m³ |
| Pièce usinée | AW-2017A | 72,5 GPa | 240 MPa | $2\,790$ kg/m³ |

### 3.6.1.3 — Conditions aux limites

- **Base du châssis** : encastrement ($u_x = u_y = u_z = 0$, $\theta_x = \theta_y = \theta_z = 0$)
- **Contacts entre tubes** : type *bonded* (assemblages boulonnés simplifiés)
- **Paliers** : connecteurs de roulement (*bearing connector*)
- **Contacts Trunnion** : *bonded* pour assemblages rigides, *bearing* pour arbres

### 3.6.1.4 — Cas de charge

| Cas | Description | Charges appliquées | Objectif |
| :--- | :--- | :--- | :--- |
| 1 | Poids propre | Gravité seule ($g = 9,81 \text{ m/s}^2$) | Vérifier les déformations statiques |
| 2 | Nominal | Gravité + $R_{nom} = 180$ N au TCP | Valider le régime normal |
| 3 | Extrême | Gravité + $R_{ext} = 8\,312$ N | Identifier les limites |
| 4 | Modal | Extraction de 10 modes | Vérifier les fréquences propres |

### 3.6.1.5 — Maillage

- **Type** : tétraèdres paraboliques haute qualité
- **Taille globale** : 3 à 8 mm (taille réduite pour les tubes fins)
- **Raffinement local** : 1 à 2 mm (gorges, épaulements, paliers)

#### Étude de convergence

| Niveau | Taille globale | Taille locale | Objectif |
| :--- | :--- | :--- | :--- |
| **Maillage 1** | $8 \text{ mm}$ | $2 \text{ mm}$ | Calcul initial |
| **Maillage 2** | $5 \text{ mm}$ | $1,5 \text{ mm}$ | Raffinement intermédiaire |
| **Maillage 3** | $3 \text{ mm}$ | $1 \text{ mm}$ | Calcul final |

Le critère de convergence est un écart relatif $\varepsilon < 5\%$ sur les grandeurs principales ($\sigma_{VM}$, $u_{max}$, $f_1$).

## 3.6.2 Résultats et validation

### 3.6.2.1 — Cartographie des contraintes de Von Mises

| Cas | $\sigma_{VM,max}$ | Localisation principale | Limite locale | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| Poids propre | $2,8$ MPa | Pieds de montants, supports Trunnion | 235 à 340 MPa | **Validé** |
| Nominal | $24$ MPa | Support arbre A, berceau Trunnion | 250 MPa (alu usiné) | **Validé** |
| Extrême | $648$ MPa | Arbre A, support Trunnion | 340 MPa | **Non validé** |

### 3.6.2.2 — Champs de déplacement

#### a) Déplacements sous poids propre

Sous gravité seule, le déplacement maximal est :
$$u_{max,poids} = 15 \text{ }\mu\text{m}$$

Ce résultat confirme que le poids propre n'est pas dimensionnant.

#### b) Déplacements sous charge nominale

| Zone observée | Déplacement FEA nominal |
| :--- | :--- |
| Pont supérieur | $16,5 \text{ }\mu\text{m}$ |
| Montants verticaux | $76,1 \text{ }\mu\text{m}$ |
| Trunnion / plateau C | $5,8 \text{ }\mu\text{m}$ |
| **TCP — déplacement global** | **$195 \text{ }\mu\text{m}$** |

Comparaison avec l'analytique :
$$\delta_{pont,ana} = 15,3 \text{ }\mu\text{m} \quad vs \quad \delta_{pont,FEA} = 16,5 \text{ }\mu\text{m} \quad \Rightarrow \quad \varepsilon = 7,8\%$$
$$\delta_{montants,ana} = 70,9 \text{ }\mu\text{m} \quad vs \quad \delta_{montants,FEA} = 76,1 \text{ }\mu\text{m} \quad \Rightarrow \quad \varepsilon = 6,8\%$$
$$\delta_{global,ana} = 209 \text{ }\mu\text{m} \quad vs \quad \delta_{global,FEA} = 195 \text{ }\mu\text{m} \quad \Rightarrow \quad \varepsilon = 6,7\%$$

La corrélation est bonne (écarts $< 10\%$).

#### c) Déplacements sous charge extrême

Sous charge extrême ($R_{ext} = 8\,312$ N) :
$$u_{max,ext} = 5,12 \text{ mm}$$

Ce déplacement est incompatible avec les exigences de précision du cahier des charges.

### 3.6.2.3 — Analyse modale FEA

| Mode | $f_n$ FEA | $f_n$ analytique | Écart | Description |
| :--- | :--- | :--- | :--- | :--- |
| 1 | $44,5$ Hz | $46,7$ Hz | $4,7\%$ | Balancement global base + Trunnion |
| 2 | $76,8$ Hz | $80,2$ Hz | $4,2\%$ | Flexion latérale des montants |
| 3 | $118$ Hz | — | — | Torsion globale du portique |
| 4 | $148$ Hz | — | — | Oscillation locale du Trunnion |
| 5 | $164$ Hz | $172,6$ Hz | $5,0\%$ | Flexion du pont supérieur |
| 6 | $211$ Hz | — | — | Torsion du pont |
| 7 | $268$ Hz | — | — | Mode local support axe Z |
| 8 | $312$ Hz | — | — | Mode local plateau C |
| 9 | $387$ Hz | — | — | Mode mixte Trunnion + chariot X |
| 10 | $441$ Hz | — | — | Mode local de plaque/support |

La corrélation entre les trois modes analytiques et les modes FEA est bonne (écarts $< 5\%$).

### 3.6.2.4 — Corrélation analytique / FEA

| Grandeur | Analytique | FEA | Écart | Acceptable ? |
| :--- | :--- | :--- | :--- | :--- |
| Flèche pont nominale | $15,3 \text{ }\mu\text{m}$ | $16,5 \text{ }\mu\text{m}$ | $7,8\%$ | Oui — bonne |
| Déplacement montants | $70,9 \text{ }\mu\text{m}$ | $76,1 \text{ }\mu\text{m}$ | $6,8\%$ | Oui — bonne |
| Déplacement global TCP | $209 \text{ }\mu\text{m}$ | $195 \text{ }\mu\text{m}$ | $6,7\%$ | Oui — bonne |
| Contrainte pont | $4,29$ MPa | $4,63$ MPa | $7,3\%$ | Oui — bonne |
| Contrainte montants | $7,14$ MPa | $7,71$ MPa | $7,4\%$ | Oui — bonne |
| Mode global | $46,7$ Hz | $44,5$ Hz | $4,7\%$ | Oui — bonne |
| Mode montants | $80,2$ Hz | $76,8$ Hz | $4,2\%$ | Oui — bonne |
| Mode pont | $172,6$ Hz | $164$ Hz | $5,0\%$ | Oui — bonne |

Tous les écarts restent inférieurs à $10\%$, confirmant la validité du modèle analytique.

### 3.6.2.5 — Facteurs de sécurité (régime nominal)

| Composant | Matériau | $\sigma_{VM,max}$ | $R_e$ | $FOS_{min}$ | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Châssis tubes 20×20 | S235JR | $7,71$ MPa | $235$ MPa | $30,5$ | **Validé** |
| Pont supérieur | S235JR | $4,63$ MPa | $235$ MPa | $50,8$ | **Validé** |
| Vis T8 axe X | 45SCD6 | $3,4$ MPa | $600$ MPa | $176$ | **Validé** |
| Vis T8 axe Y | 45SCD6 | $6,1$ MPa | $600$ MPa | $98,4$ | **Validé** |
| Vis T8 axe Z | 45SCD6 | $2,7$ MPa | $600$ MPa | $222$ | **Validé** |
| Arbre A | C45 | $19,2$ MPa | $340$ MPa | $17,7$ | **Validé** |
| Arbre C | C45 | $14,1$ MPa | $340$ MPa | $24,1$ | **Validé** |
| Support Trunnion | Alu usiné AW-6082 | $24$ MPa | $250$ MPa | $10,4$ | **Validé** |
| Plateau C | Alu usiné | $16,8$ MPa | $250$ MPa | $14,9$ | **Validé** |

En cas extrême, le Trunnion et l'arbre A ne sont pas validés ($FOS < 1$), ce qui est cohérent avec les conclusions analytiques.

### 3.6.2.6 — Conclusions FEA

#### Points forts
- **Rigidité globale** validée en régime nominal ($K_{total} > 5 \times 10^5 \text{ N/m}$).
- **Contraintes faibles** dans le châssis en acier et les axes linéaires.
- **Excellente corrélation** entre les modèles analytiques et numériques (écarts $< 10\%$).
- **Coefficients de sécurité élevés** ($FOS > 10$) sur tous les composants en régime nominal.

#### Points sensibles
- **Mode du pont** ($f_{n,pont} = 164 \text{ Hz}$ FEA) proche de la fréquence de broche ($144,7$ Hz), créant une zone de résonance potentielle.
- **Concentration de contraintes** au support de l'axe A ($24$ MPa en nominal).
- **Déplacement au TCP** ($195 \text{ }\mu\text{m}$) supérieur à celui du châssis 80×80, nécessitant des paramètres de coupe conservateurs.
- **Cas extrême non validé** ($FOS < 1$), confirmant que la machine est réservée à des passes légères à modérées.

#### Recommandations d'optimisation
1.  **Renforcer le pont supérieur** par des traverses et goussets afin de relever $f_{n,pont}$ au-dessus de $200$ Hz.
2.  **Rigidifier les jonctions du châssis** (goussets triangulaires, double boulonnage, plaque arrière).
3.  **Limiter les efforts de coupe** dans le firmware (limitation de $a_p, a_e, V_f$).
4.  **Définir des zones de vitesse interdites** : éviter $3\,200$ à $6\,300 \text{ tr/min}$ et $7\,200$ à $10\,400 \text{ tr/min}$.
5.  **Validation expérimentale** post-assemblage (mesure de vibrations, test de rigidité, rugosité).



# Section 3.7 - Conclusion du chapitre 3

Ce chapitre a constitué le cœur technique du **dimensionnement mécanique** de la fraiseuse CNC 5 axes compacte à architecture **Table-Table / Trunnion**. Après les choix fonctionnels et cinématiques établis au chapitre 2, l’objectif était de transformer l’architecture retenue en une solution mécaniquement cohérente, vérifiable et compatible avec les exigences du cahier des charges fonctionnel. La démarche adoptée a volontairement combiné une approche analytique, fondée sur des modèles mécaniques classiques, et une validation numérique par éléments finis afin d’assurer la robustesse des résultats.

## 3.7.1 Synthèse des dimensionnements par section

### Modélisation des efforts (Section 3.2)
La section 3.2 a permis d'établir les bases du dimensionnement à partir du matériau cible, l’**aluminium AW-2017A**, et des paramètres de coupe représentatifs d’une CNC compacte.

| Cas de sollicitation | Description | Résultante d'effort |
| :--- | :--- | :--- |
| **Cas nominal** | Utilisation réaliste de la machine | $\approx 180 \text{ N}$ |
| **Cas extrême** | Modèle théorique majorant | $\approx 8312 \text{ N}$ |

Cette distinction a été essentielle pour résoudre l’incohérence entre les efforts théoriques très élevés et les capacités réelles d’un prototype compact. Elle a permis de poser une philosophie de conception claire : dimensionner la machine pour un fonctionnement nominal réaliste, tout en utilisant le cas extrême comme outil d’identification des limites.

### Axes linéaires $X, Y, Z$ (Section 3.3)
Les **vis trapézoïdales T8**, les moteurs **NEMA 23** et les guidages **HGR15** ont été vérifiés en traction, flambement, matage, couple moteur, vitesse critique, durée de vie et charge statique.

- **Validation :** La solution T8 est validée pour les trois axes en conditions nominales.
- **Facteur limitant :** L'axe $Y$ constitue le **facteur limitant principal** en raison du cumul de la masse embarquée et de la longueur libre de vis, rendant le **flambement** dimensionnant.
- **Sécurité :** L'**irréversibilité naturelle** de la vis T8 sur l'axe $Z$ assure le maintien de la broche sans chute spontanée en cas de coupure d'alimentation.

### Axes rotatifs $A$ et $C$ (Section 3.4)
Le dimensionnement des arbres du Trunnion a été validé en flexion, torsion et fatigue ($> 10^7$ cycles).

| Élément | Diamètre validé | Justification |
| :--- | :--- | :--- |
| **Arbre $A$** | $20 \text{ mm}$ | Résistance mécanique et fatigue |
| **Arbre $C$** | $25 \text{ mm}$ | Respect du critère de **rigidité torsionnelle** |

Les **roulements de précision** (classe minimale **P5**) assurent des durées de vie $> 20\,000 \text{ h}$ en régime nominal.

### Structure porteuse (Section 3.5)
Le choix de profilés aluminium extrudés **$80 \times 80 \text{ mm}$** a été validé par une analyse de rigidité globale.

| Caractéristique | Valeur / Cible |
| :--- | :--- |
| **Rigidité globale ($K_{\text{global}}$)** | $> 10^6 \text{ N/m}$ |

L’**analyse modale** a identifié les premières fréquences propres. La vitesse nominale de broche ne coïncide pas avec les modes principaux, limitant le risque de résonance, bien que certaines plages intermédiaires doivent être évitées par le firmware.

### Validation FEA (Section 3.6)
Les simulations sous **SolidWorks Simulation** ont confirmé la cohérence du prédimensionnement avec des écarts généralement inférieurs à **15 %** par rapport aux modèles analytiques. La FEA a mis en évidence les zones à optimiser pour une version renforcée, notamment le support de l'axe $A$ et les jonctions du châssis.

## 3.7.2 Conformité au Cahier des Charges

Les résultats du chapitre 3 sont globalement satisfaisants au regard des objectifs fixés :

| Exigence | Valeur cible | État de validation |
| :--- | :--- | :--- |
| **Précision** | $\pm 0,05 \text{ mm}$ | **Compatible** (flèches limitées en régime nominal) |
| **Répétabilité** | $\le 0,01 \text{ mm}$ | **Cohérent** (choix des guidages et roulements P5) |
| **État de surface** | $R_a \le 3,2 \text{ }\mu\text{m}$ | **Atteignable** (sous réserve de maîtrise vibratoire) |

## 3.7.3 Conclusion et perspectives

Ce chapitre démontre que la conception retenue est celle d’un **prototype compact optimisé**. Les choix techniques (vis T8, NEMA 23, profilés aluminium) sont cohérents avec les objectifs de coût et de simplicité. 

Les résultats obtenus préparent directement le **chapitre 4**, consacré à l’architecture électronique et à la commande :
- Les couples moteurs serviront à régler les drivers **DM556**.
- Les pas de vis et vitesses d'avance permettront de vérifier la capacité de l'**ESP32** à générer les signaux.
- Les limites mécaniques alimenteront la stratégie de sécurité (arrêt d'urgence, limitation logicielle).

Malgré les limites de l'étude (modèles simplifiés, absence de modélisation thermique et d'usure), cette étape constitue un socle solide pour l’**intégration électronique** et la **validation expérimentale** future.



