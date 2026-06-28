# 3 CHAPITRE 3 : MODÉLISATION ET DIMENSIONNEMENT

## 3.1 Introduction :

Après l’étude bibliographique (chapitre 1) et l’analyse fonctionnelle (chapitre 2), ce chapitre marque la transition vers la conception mécanique détaillée de la fraiseuse CNC 5 axes compacte. Les travaux précédents ont permis de définir les exigences du système à l’aide du cahier des charges fonctionnel, de l’actigramme A0, du diagramme FAST et d’une étude cinématique basée sur Denavit-Hartenberg et le RTCP. Cela a conduit au choix d’une architecture Table–Table (Trunnion), où les axes rotatifs sont intégrés à la table et les axes X, Y, Z assurent les translations. Cette configuration répond aux objectifs de compacité, rigidité et coût maîtrisé, tout en permettant l’usinage de pièces complexes en aluminium.

L’architecture Trunnion offre une meilleure rigidité que les têtes bi-rotatives. Le plateau assure la rotation C, le berceau l’inclinaison A, permettant des usinages 3+2 et 5 axes. Elle satisfait les exigences fonctionnelles, notamment en précision, réduction des reprises et intégration compacte.

La chaîne cinématique est : Y → X → Z → A → C. Les axes X et Y assurent les translations horizontales via rails et vis, le Trunnion (A, C) oriente la pièce, et l’axe Z contrôle la profondeur de coupe. Cette organisation facilite la dissociation des fonctions et le dimensionnement.

L’étude repose sur des hypothèses adaptées à un prototype : précision $\pm 0{,}05 \text{ mm}$, répétabilité $\leq 0{,}01 \text{ mm}$ et rugosité $Ra \leq 3{,}2 \text{ }\mu\text{m}$. Le matériau choisi est l’aluminium AW-2017A, compatible avec ce type de machine sous conditions d’usinage adaptées.

Le tableau suivant regroupe les principales hypothèses retenues pour le prototype :

| Paramètre | Symbole | Valeur retenue | Unité | Remarque |
|---|---|---|---|---|
| Course utile axe X | $L_X$ | 150 | mm | Translation transversale du chariot |
| Course utile axe Y | $L_Y$ | 300 | mm | Translation longitudinale de la base |
| Course utile axe Z | $L_Z$ | 120 | mm | Translation verticale de la broche |
| Longueur du plateau Trunnion | $L_A$ | 120 | mm | Berceau de rotation $A$ |
| Diamètre du plateau rotatif | $D_C$ | 100 | mm | Plateau de rotation $C$ |
| Masse du Trunnion hors pièce | $m_T$ | 4 | kg | Berceau, plateau, paliers, moteurs $A$ et $C$ |
| Masse maximale pièce + fixation | $m_P$ | 2 | kg | Pièce usinée et bridage |
| Masse du chariot X | $m_X$ | 1,5 | kg | Structure, rails, vis, support |
| Masse du chariot Y | $m_Y$ | 2 | kg | Base mobile longitudinale |
| Masse de la broche et support Z | $m_Z$ | 1,5 | kg | Broche, support et éléments mobiles |
| Matériau cible | — | AW-2017A | — | Alliage d’aluminium usinable |
| Transmission linéaire | — | Vis T8 | — | Axes $X, Y, Z$ |
| Motorisation | — | NEMA 23 + DM556 | — | Entraînement pas-à-pas |

---

## 3.2 Modélisation cinématique et dynamique du système 5 axes

### 3.2.1 Analyse du matériau cible et pression spécifique

Le dimensionnement d’une fraiseuse CNC dépend directement du matériau usiné, car il influence les efforts de coupe, les couples moteurs et la rigidité requise.

Dans ce projet, le matériau choisi est l’aluminium EN AW-2017A (AlCu4MgSi), un alliage de la série 2000 riche en cuivre ($\approx 3{,}5\text{--}4{,}5\text{ \%}$), offrant un bon compromis entre résistance mécanique, légèreté et usinabilité.

L’objectif est de définir les paramètres de coupe de référence, notamment la pression spécifique de coupe $K_c$, utilisée pour modéliser les efforts appliqués sur l’outil et les axes.

Le tableau suivant présente les propriétés mécaniques et physiques retenues pour le prédimensionnement :

| Propriété | Valeur | Unité |
|---|---|---|
| Désignation normalisée | AW-2017A — AlCu4MgSi | — |
| Famille d’alliage | Série 2000 — aluminium-cuivre | — |
| Dureté Brinell | 95 à 105 | HB |
| Résistance à la traction | $R_m = 390$ | MPa |
| Limite d’élasticité | $R_e = 240$ | MPa |
| Module d’Young | $E = 72,5$ | GPa |
| Masse volumique | $\rho = 2\,790$ | kg/m³ |
| Conductivité thermique | $\lambda_t = 134$ | W/(m.K) |

#### a) Pression spécifique de coupe $K_c$

La pression spécifique de coupe $K_c$ représente la résistance du matériau à l’enlèvement de copeau. Elle permet de relier l’effort principal de coupe à la section instantanée du copeau. Elle s’exprime en $\text{N/mm}^2$.

Dans une approche simplifiée, l’effort tangentiel principal peut être évalué par :

$$F_c = K_c \times A_c$$

avec :
* $F_c$ : effort principal de coupe, en $\text{N}$ ;
* $K_c$ : pression spécifique de coupe, en $\text{N/mm}^2$ ;
* $A_c$ : section instantanée du copeau, en $\text{mm}^2$.

La relation empirique couramment utilisée pour tenir compte de l’influence de l’épaisseur de copeau est le modèle de Kienzle :

$$K_c = K_{c1} \times h^{-m_c}$$

où :
* $K_{c1}$ est la pression spécifique de coupe pour une épaisseur de copeau de référence $h = 1 \text{ mm}$ ;
* $h$ est l’épaisseur moyenne du copeau ;
* $m_c$ est l’exposant de Kienzle, généralement voisin de $0{,}25$ pour les alliages d’aluminium ;
* $K_c$ est la pression spécifique corrigée pour l’épaisseur réelle du copeau.

Le modèle de Kienzle permet de raffiner le calcul des efforts lorsque l’on dispose de données précises sur l’outil, l’angle de coupe et l’épaisseur moyenne du copeau.

Dans ce PFE, le choix de :

$$K_c = 700 \text{ N/mm}^2$$

est retenu comme valeur forfaitaire de prédimensionnement.

#### b) Outil de coupe de référence

Le choix de l’outil est adapté aux contraintes d’une CNC compacte. Une fraise de diamètre $5{,}5 \text{ mm}$ permet de limiter le couple de coupe et les efforts transmis à la structure, tout en offrant un compromis entre productivité, rigidité et puissance requise.

Le maintien de l’outil est assuré par un porte-outil ER32, garantissant :
* un centrage précis,
* une réduction du faux-rond,
* une meilleure qualité de surface,

tout en offrant une bonne polyvalence grâce à l’utilisation de pinces interchangeables.

Les caractéristiques de l’outil de référence sont donc :
* Diamètre : $D = 5{,}5 \text{ mm}$
* Nombre de dents : $Z = 3$
* Type : Fraise carbure monobloc
* Serrage : Porte-outil ER32

#### c) Paramètres de coupe retenus

Les paramètres de coupe retenus sont choisis de manière à représenter une passe d’ébauche légère à modérée, compatible avec les capacités mécaniques d’une fraiseuse CNC compacte. Ils ne correspondent pas à une stratégie industrielle de forte ébauche, mais à un compromis entre effort de coupe, état de surface, durée de vie de l’outil et rigidité de la machine.

La vitesse de broche est calculée par la relation classique :

$$N = \frac{V_c \times 1000}{\pi \times D}$$

avec :
* $V_c = 150 \text{ m/min}$
* $D = 5{,}5 \text{ mm}$

Application numérique :

$$N = \frac{150 \times 1000}{\pi \times 5{,}5} = \frac{150\,000}{17{,}279} \approx 8\,680 \text{ tr/min}$$

La vitesse d’avance est donnée par :

$$V_f = N \times f_z \times Z$$

avec :
* $N = 8\,680 \text{ tr/min}$
* $f_z = 0{,}05 \text{ mm/dent}$
* $Z = 3$

Application numérique :

$$V_f = 8\,680 \times 0{,}05 \times 3 = 1\,302 \text{ mm/min}$$

La profondeur axiale retenue est :

$$a_p = 1{,}9 \text{ mm}$$

Elle représente environ :

$$\frac{a_p}{D} = \frac{1{,}9}{5{,}5} = 0{,}345 \approx 0{,}35 D$$

Cette valeur correspond à une passe d’ébauche légère, compatible avec une structure compacte.

La largeur radiale est prise égale au diamètre de la fraise :

$$a_e = D = 5{,}5 \text{ mm}$$

Ce choix correspond à un cas défavorable de rainurage en pleine matière. Il permet de majorer les efforts de coupe dans la section suivante afin de sécuriser le prédimensionnement.

La section instantanée de copeau utilisée dans la première approximation est :

$$A_c = a_p \times a_e = 1{,}9 \times 5{,}5 = 10{,}45 \text{ mm}^2$$

Cette section servira directement au calcul de l’effort principal de coupe dans la section 3.2.2 :

$$F_c = K_c \times A_c \quad \text{avec} \quad K_c = 700 \text{ N/mm}^2$$

| Paramètre | Symbole | Valeur | Unité | Justification |
|---|---|---|---|---|
| Profondeur axiale | $a_p$ | 1,9 | mm | Environ $0{,}35 D$, ébauche légère |
| Largeur radiale | $a_e$ | 5,5 | mm | Engagement pleine matière, cas rainurage |
| Avance par dent | $f_z$ | 0,05 | mm/dent | Valeur modérée pour finition/ébauche légère aluminium |
| Vitesse de coupe | $V_c$ | 150 | m/min | Adaptée au carbure sur aluminium |
| Vitesse de broche | $N$ | 8\,680 | tr/min | Calculée par $N = \frac{V_c \times 1000}{\pi D}$ |
| Vitesse d’avance | $V_f$ | 1\,302 | mm/min | Calculée par $V_f = N \times f_z \times Z$ |

---

### 3.2.2 Modélisation des efforts de coupe

Les efforts théoriques calculés à partir d’un modèle simplifié peuvent conduire à des valeurs très élevées lorsqu’on considère un engagement maximal de l’outil. Ces valeurs sont utiles pour définir une enveloppe majorante, mais elles ne représentent pas toujours le fonctionnement réel d’une machine compacte de type desktop. Pour cette raison, la présente section distingue clairement deux niveaux d’analyse :
* un modèle théorique majorant, basé sur une section de copeau maximale ;
* un modèle réaliste d’exploitation, compatible avec la puissance, la rigidité et la motorisation du prototype.

#### a) Modèle théorique majorant (Pleine matière)

Le calcul des efforts de coupe repose sur une approche simplifiée inspirée des modèles de Merchant et de Kienzle. Dans cette approche, l’effort principal de coupe est supposé proportionnel à la section non coupée du copeau. Le coefficient de proportionnalité est la pression spécifique de coupe $K_c$, introduite dans la section précédente.

La force tangentielle principale s’écrit alors :

$$F_c = K_c \times A_c$$

avec :
* $F_c$ : force tangentielle principale de coupe, en $\text{N}$ ;
* $K_c$ : pression spécifique de coupe, en $\text{N/mm}^2$ ;
* $A_c$ : section instantanée du copeau, en $\text{mm}^2$.

L’effort tangentiel principal est donc :

$$F_c = 700 \times 10{,}45 = 7\,315 \text{ N}$$

Cette valeur représente l’effort principal de coupe dans une situation de rainurage pleine matière avec engagement radial maximal.

#### b) Composantes de l’effort de coupe

L’effort de coupe exercé au niveau de l’outil peut être décomposé dans le repère outil en trois composantes principales :
* $F_c$ : force tangentielle ou force principale de coupe ;
* $F_f$ : force d’avance, orientée suivant la direction d’avance relative de la pièce ;
* $F_p$ : force de pénétration, orientée radialement ou normalement à la surface usinée.

Pour l’usinage de l’aluminium, on retient les coefficients suivants :

$$F_f = k_f \times F_c$$

$$F_p = k_p \times F_c$$

avec :
* $k_f \approx 0{,}5$
* $k_p \approx 0{,}3$

Ces valeurs correspondent à une approximation usuelle permettant d’estimer les efforts secondaires à partir de l’effort principal.

* **Calcul de la force d’avance :**

$$F_f = 0{,}5 \times F_c = 0{,}5 \times 7\,315 = 3\,657 \text{ N} \approx 3{,}66 \text{ kN}$$

* **Calcul de la force de pénétration :**

$$F_p = 0{,}3 \times F_c = 0{,}3 \times 7\,315 = 2\,194 \text{ N} \approx 2{,}19 \text{ kN}$$

* **Résultante globale de coupe :**

La résultante des efforts dans le repère outil est calculée par :

$$R = \sqrt{F_c^2 + F_f^2 + F_p^2}$$

Application numérique :

$$R = \sqrt{7\,315^2 + 3\,657^2 + 2\,194^2}$$

$$R = \sqrt{53\,509\,225 + 13\,373\,649 + 4\,813\,636} = \sqrt{71\,696\,510} \approx 8\,312 \text{ N}$$

La résultante théorique obtenue est donc voisine de $R \approx 8{,}3 \text{ kN}$. Cette valeur est extrêmement élevée pour une fraiseuse CNC compacte. Elle confirme que le cas considéré correspond à une enveloppe maximale, utile pour la vérification des limites, mais non représentative du fonctionnement courant de la machine.

#### c) Cas réaliste : ébauche légère à modérée

Les efforts calculés précédemment donnent une estimation majorante fondée sur une hypothèse sévère de pleine matière ($a_p = 1{,}9 \text{ mm}, a_e = 5{,}5 \text{ mm}$), menant à $F_c = 7\,315 \text{ N}$ et $R \approx 8\,312 \text{ N}$.

Cependant, ces valeurs ne peuvent pas être considérées comme représentatives du fonctionnement réel d’une CNC compacte de type desktop. Plusieurs raisons mécaniques et énergétiques justifient cette distinction. La puissance de broche disponible sur ce type de machine est généralement limitée. Une broche compacte ne peut pas maintenir durablement un enlèvement de matière correspondant à plusieurs kilonewtons d’effort de coupe sans chute de vitesse, échauffement ou perte de stabilité.

Pour un fonctionnement représentatif d’une CNC compacte, on retient une passe modérée :

$$a_p = 0{,}5 \text{ mm} \quad ; \quad a_e = 2 \text{ mm}$$

La section de copeau réaliste devient :

$$A_{c,reel} = a_p \times a_e = 0{,}5 \times 2 = 1{,}0 \text{ mm}^2$$

L’effort principal réaliste est :

$$F_{c,reel} = K_c \times A_{c,reel} = 700 \times 1{,}0 = 700 \text{ N}$$

La force d’avance réaliste est :

$$F_{f,reel} = 0{,}5 \times F_{c,reel} = 0{,}5 \times 700 = 350 \text{ N}$$

La force de pénétration réaliste est :

$$F_{p,reel} = 0{,}3 \times F_{c,reel} = 0{,}3 \times 700 = 210 \text{ N}$$

La résultante réaliste vaut :

$$R_{reel} = \sqrt{700^2 + 350^2 + 210^2} = \sqrt{490\,000 + 122\,500 + 44\,100} = \sqrt{656\,600} \approx 810 \text{ N} \rightarrow \text{retenu } 800 \text{ N}$$

Ce niveau d’effort reste important, mais il est beaucoup plus cohérent avec une machine compacte que le cas théorique à plus de $8 \text{ kN}$.

#### d) Cas de finition

Pour une opération de finition, les engagements sont beaucoup plus faibles. On peut considérer :

$$a_p = 0{,}2 \text{ mm} \quad ; \quad a_e = 0{,}5 \text{ mm}$$

La section de copeau devient :

$$A_{c,fin} = 0{,}2 \times 0{,}5 = 0{,}1 \text{ mm}^2$$

L’effort principal vaut :

$$F_{c,fin} = 700 \times 0{,}1 = 70 \text{ N}$$

Les composantes associées sont :

$$F_{f,fin} = 0{,}5 \times 70 = 35 \text{ N}$$

$$F_{p,fin} = 0{,}3 \times 70 = 21 \text{ N}$$

La résultante est :

$$R_{fin} = \sqrt{70^2 + 35^2 + 21^2} = \sqrt{4\,900 + 1\,225 + 441} = \sqrt{6\,566} \approx 81 \text{ N} \rightarrow \text{retenu } 80 \text{ N}$$

Ce cas correspond aux passes de finition destinées à respecter l’état de surface visé, notamment $Ra \leq 3{,}2\text{ }\mu\text{m}$.

#### e) Tableau comparatif des scénarios d’efforts

Le tableau suivant permet de synthétiser les différents niveaux d’efforts utilisés dans le chapitre. Il met en évidence l’écart important entre le cas théorique maximal et les cas réalistes compatibles avec une machine compacte.

| Scénario | $a_p$ (mm) | $a_e$ (mm) | $F_c$ (N) | $F_f$ (N) | $F_p$ (N) | $R$ (N) |
|---|---|---|---|---|---|---|
| **Théorique max — rainurage pleine matière** | 1,9 | 5,5 | 7\,315 | 3\,657 | 2\,194 | 8\,312 |
| **Ébauche réaliste — CNC compacte** | 0,5 | 2,0 | 700 | 350 | 210 | 800 |
| **Finition** | 0,2 | 0,5 | 70 | 35 | 21 | 80 |

Ce tableau constitue un point clé du dimensionnement. Il montre que les efforts issus du modèle simplifié pleine matière ne doivent pas être utilisés seuls pour dimensionner le fonctionnement nominal de la machine, car ils conduiraient à une architecture surdimensionnée ou incohérente avec les capacités réelles du prototype. En revanche, ils sont très utiles comme cas extrême pour vérifier les marges de sécurité.

---

### 3.2.3 Transfert et projection des efforts sur les axes linéaires (X, Y, Z)

La présente section a pour objectif de transférer ces efforts depuis le repère outil vers le repère machine, puis d’en déduire les charges équivalentes appliquées aux axes linéaires $X$, $Y$ et $Z$.

Cette étape constitue un lien essentiel entre la modélisation des efforts de coupe et le dimensionnement mécanique des organes de transmission. En effet, les efforts calculés au niveau du point outil ne sollicitent pas directement les vis, moteurs et guidages sous leur forme initiale : ils doivent être projetés selon les directions physiques des axes de la machine. Dans le cas d’une architecture Table–Table / Trunnion, les efforts peuvent en outre être redistribués lorsque les axes rotatifs $A$ et $C$ modifient l’orientation relative entre l’outil et la pièce. Le chapitre 2 du document a déjà posé les bases de cette modélisation géométrique par paramètres de Denavit-Hartenberg et a introduit le rôle du RTCP dans la compensation des mouvements induits par les rotations du Trunnion.

La démarche adoptée consiste donc à établir d’abord le torseur des efforts au niveau du TCP — Tool Center Point — puis à définir la transformation entre le repère outil et le repère machine. Enfin, une charge équivalente est déterminée pour chaque axe linéaire en tenant compte des efforts de coupe, des masses embarquées, des accélérations et des frottements.

#### a) Torseur des efforts au TCP

Le point de réduction naturel des efforts de coupe est le TCP, c’est-à-dire la pointe théorique de l’outil. C’est en ce point que s’appliquent les efforts issus du contact entre l’arête de coupe et la matière. Dans le repère outil, l’effort résultant peut être représenté par le vecteur :

$$\vec{R}_{outil} = \begin{bmatrix} F_c \\ F_f \\ F_p \end{bmatrix}$$

où :
* $F_c$ est la force tangentielle principale, associée à la direction de coupe ;
* $F_f$ est la force d’avance, associée à la direction de progression relative de l’outil ;
* $F_p$ est la force de pénétration, normale ou radiale par rapport à la surface usinée.

Dans le cadre de cette étude, les efforts considérés sont les suivants :

$$\vec{R}_{outil,nom} = \begin{bmatrix} 150 \\ 75 \\ 45 \end{bmatrix} \text{ N}$$

pour le cas nominal (correspondant à une sollicitation normale représentative, avec une résultante d’environ $180\text{ N}$), et :

$$\vec{R}_{outil,ext} = \begin{bmatrix} 7\,315 \\ 3\,657 \\ 2\,194 \end{bmatrix} \text{ N}$$

pour le cas extrême théorique.

Le torseur des actions mécaniques de coupe au TCP s’écrit alors :

$$\{\mathcal{T}_{coupe}\}_{TCP} = \left\{ \begin{matrix} \vec{R}_{outil} \\ \vec{M}_{TCP} \end{matrix} \right\}$$

avec :

$$\vec{M}_{TCP} = \begin{bmatrix} M_x \\ M_y \\ M_z \end{bmatrix}$$

Le moment $\vec{M}_{TCP}$ représente les couples induits par les efforts de coupe autour du point outil. Dans une première approche, lorsque les efforts sont supposés appliqués directement au TCP et que l’on ne considère pas encore le bras de levier entre le TCP et les paliers de broche, le moment peut être considéré comme nul au point de réduction (à l'exception du couple de torsion de coupe $M_z$) :

$$\vec{M}_{TCP} \approx \begin{bmatrix} 0 \\ 0 \\ M_z \end{bmatrix}$$

Le terme $M_z$ correspond au couple résistant de coupe transmis à la broche. Il peut être estimé à partir de la force tangentielle et du rayon de l’outil :

$$M_z = F_c \times \frac{D}{2}$$

avec $D = 5{,}5 \text{ mm} = 0{,}0055 \text{ m}$.

* **Pour le cas nominal ($F_c = 150\text{ N}$) :**

$$M_{z,nom} = 150 \times \frac{0{,}0055}{2} = 150 \times 0{,}00275 = 0{,}413 \text{ N.m}$$

* **Pour le cas extrême ($F_c = 7\,315\text{ N}$) :**

$$M_{z,ext} = 7\,315 \times \frac{0{,}0055}{2} = 7\,315 \times 0{,}00275 = 20{,}12 \text{ N.m}$$

On peut donc écrire, pour le cas nominal :

$$\{\mathcal{T}_{coupe,nom}\}_{TCP} = \left\{ \begin{matrix} \begin{bmatrix} 150 \\ 75 \\ 45 \end{bmatrix} \\ \begin{bmatrix} 0 \\ 0 \\ 0{,}413 \end{bmatrix} \end{matrix} \right\}$$

et pour le cas extrême :

$$\{\mathcal{T}_{coupe,ext}\}_{TCP} = \left\{ \begin{matrix} \begin{bmatrix} 7\,315 \\ 3\,657 \\ 2\,194 \end{bmatrix} \\ \begin{bmatrix} 0 \\ 0 \\ 20{,}12 \end{bmatrix} \end{matrix} \right\}$$

Ces torseurs serviront de base à la projection des charges sur les axes machine.

#### b) Transformation repère outil vers repère machine

Dans une machine CNC 5 axes, les efforts générés au niveau de l’outil doivent être exprimés dans le repère machine afin de déterminer les charges appliquées aux axes physiques. La transformation du repère outil vers le repère machine repose sur la matrice de rotation issue de la chaîne cinématique définie au chapitre 2.

De manière générale, on peut écrire :

$$\vec{R}_{machine} = M_{RO} \times \vec{R}_{outil}$$

où :
* $\vec{R}_{outil}$ est le vecteur des efforts exprimé dans le repère outil ;
* $\vec{R}_{machine}$ est le vecteur des efforts exprimé dans le repère machine ;
* $M_{RO}$ est la matrice de rotation du repère outil vers le repère machine.

Dans le cas d’une architecture Trunnion, cette matrice dépend des rotations des axes $A$ et $C$. Elle peut être exprimée de manière générale par :

$$M_{RO} = R_A(\theta_A) \times R_C(\theta_C)$$

* **Cas neutre : $A = 0^\circ, C = 0^\circ$**

En position neutre, les axes rotatifs ne modifient pas l’orientation relative entre le repère outil et le repère machine. La matrice de rotation peut alors être assimilée à une matrice d’identité ou à une permutation simple des directions selon la convention adoptée.

Dans cette position, on retient la correspondance suivante :

$$F_c \rightarrow Y \quad ; \quad F_f \rightarrow X \quad ; \quad F_p \rightarrow Z$$

Autrement dit :
* la force tangentielle $F_c$ sollicite principalement l’axe $Y$ (direction longitudinale) ;
* la force d’avance $F_f$ sollicite principalement l’axe $X$ (direction transversale) ;
* la force de pénétration $F_p$ sollicite principalement l’axe $Z$ (direction verticale).

Ainsi, pour le cas nominal :

$$R_{Y,nom} = F_c = 150 \text{ N}$$

$$R_{X,nom} = F_f = 75 \text{ N}$$

$$R_{Z,nom} = F_p = 45 \text{ N}$$

Pour le cas extrême :

$$R_{Y,ext} = F_c = 7\,315 \text{ N}$$

$$R_{X,ext} = F_f = 3\,657 \text{ N}$$

$$R_{Z,ext} = F_p = 2\,194 \text{ N}$$

Cette projection en position neutre fournit une base simple et directement exploitable pour les calculs de dimensionnement des sections suivantes.

* **Cas incliné : $A \neq 0^\circ, C \neq 0^\circ$**

Lorsque le Trunnion est incliné, la direction de l’effort de coupe dans le repère machine n’est plus identique à celle obtenue en position neutre. Les composantes $F_c, F_f$ et $F_p$ se redistribuent entre les axes $X, Y$ et $Z$ selon la matrice de rotation associée aux angles $A$ et $C$.

On peut écrire :

$$\begin{bmatrix} R_X \\ R_Y \\ R_Z \end{bmatrix} = M_{RO}(A, C) \times \begin{bmatrix} F_c \\ F_f \\ F_p \end{bmatrix}$$

Cette expression montre que chaque composante machine peut devenir une combinaison des trois composantes de coupe. Par exemple, une force initialement tangentielle peut se retrouver partiellement projetée sur l’axe $Z$ lorsque la table est inclinée. De même, une force de pénétration peut contribuer aux charges transversales ou longitudinales lorsque les axes $A$ et $C$ sont orientés.

Dans le fonctionnement réel de la machine, cette redistribution est gérée par le modèle cinématique et par le RTCP. Le RTCP permet de compenser les déplacements induits par les rotations du Trunnion afin que le point outil reste cohérent avec la trajectoire programmée. Dans le cadre du dimensionnement mécanique, on retient donc la projection en position neutre comme cas de référence, tout en conservant une marge de sécurité afin de couvrir les configurations inclinées.

#### c) Bilan des masses portées par chaque axe

Le dimensionnement des axes linéaires ne dépend pas uniquement des efforts de coupe. Il doit également tenir compte des masses embarquées par chaque axe, car ces masses génèrent des efforts d’inertie lors des accélérations et peuvent, dans le cas de l’axe $Z$, produire une charge permanente due à la gravité.

Les hypothèses de masse ont été posées dans la section 3.1. Elles sont rappelées ici afin de préparer les calculs de charge équivalente.

| Axe | Composants portés | Masse portée |
|---|---|---|
| **$Y$** | Chariot $Y$ + chariot $X$ + Trunnion + pièce | 11 kg |
| **$X$** | Chariot $X$ + Trunnion + pièce | 7,5 kg |
| **$Z$** | Broche + support | 1,5 kg |

#### d) Charge équivalente par axe — formule générale

Pour dimensionner chaque axe linéaire, on introduit une charge équivalente totale, qui regroupe trois contributions principales :
1. la composante de l’effort de coupe projetée sur l’axe ;
2. l’effort inertiel lié à l’accélération de la masse embarquée ;
3. les frottements mécaniques dans les guidages, vis, écrous et joints.

La formule générale retenue est :

$$F_{axe,tot} = R_{axe} + m \times a + F_{frott}$$

avec :
* $F_{axe,tot}$ : charge équivalente totale appliquée à l’axe ;
* $R_{axe}$ : composante de l’effort de coupe portée par l’axe ;
* $m$ : masse embarquée par l’axe ;
* $a$ : accélération typique ;
* $F_{frott}$ : frottement global estimé.

L’accélération typique retenue est :

$$a = 0{,}5 \text{ m/s}^2$$

Les frottements globaux sont estimés à :
* $F_{frott,Y} = 20 \text{ N}$
* $F_{frott,X} = 15 \text{ N}$
* $F_{frott,Z} = 10 \text{ N}$

Ces valeurs tiennent compte de la différence de masse, du nombre de guidages sollicités et de la nature du mouvement.

* **Charge équivalente de l’axe $Y$ :**

En position neutre, l’axe $Y$ reçoit principalement la force tangentielle $R_{Y,nom} = F_c = 150 \text{ N}$. La masse portée est $m_Y = 11 \text{ kg}$.

L'effort inertiel vaut : $m_Y \times a = 11 \times 0{,}5 = 5{,}5 \text{ N}$.

La charge totale est donc :

$$F_{Y,tot} = 150 + 5{,}5 + 20 = 175{,}5 \text{ N}$$

* **Charge équivalente de l’axe $X$ :**

L’axe $X$ reçoit principalement la force d’avance $R_{X,nom} = F_f = 75 \text{ N}$. La masse portée est $m_X = 7{,}5 \text{ kg}$.

L'effort inertiel vaut : $m_X \times a = 7{,}5 \times 0{,}5 = 3{,}75 \text{ N}$.

La charge totale est :

$$F_{X,tot} = 75 + 3{,}75 + 15 = 93{,}75 \text{ N}$$

* **Charge équivalente de l’axe $Z$ :**

L’axe $Z$ reçoit la composante de pénétration $R_{Z,nom} = F_p = 45 \text{ N}$. Il doit également compenser le poids de la broche et de son support. La masse portée est $m_Z = 1{,}5 \text{ kg}$.

Le poids vaut :

$$W_Z = m_Z \times g = 1{,}5 \times 9{,}81 = 14{,}715 \text{ N} \approx 14{,}7 \text{ N}$$

L'effort inertiel vertical est : $m_Z \times a = 1{,}5 \times 0{,}5 = 0{,}75 \text{ N}$.

La charge totale est donc :

$$F_{Z,tot} = F_p + W_Z + m_Z \times a + F_{frott,Z} = 45 + 14{,}7 + 0{,}75 + 10 = 70{,}45 \text{ N}$$

L’axe $Z$ est donc moins chargé en valeur absolue que l’axe $Y$, mais il présente une particularité importante : il est soumis à une charge permanente due à la gravité. Cette contrainte devra être prise en compte dans le choix du moteur, du maintien en position et de la stratégie de sécurité.

#### e) Tableau de synthèse des charges nominales par axe

Le tableau suivant constitue la feuille de route du dimensionnement des axes linéaires. Il sera directement utilisé pour vérifier les vis, les moteurs, les guidages et les roulements.

| Axe | Masse embarquée $m$ (kg) | $R_{axe}$ nominal (N) | $m \times a$ (N) | $F_{frott}$ (N) | $F_{axe,tot}$ (N) |
|---|---|---|---|---|---|
| **$Y$** | 11 | $150$ ($F_c$) | 5,5 | 20 | 175,5 |
| **$X$** | 7,5 | $75$ ($F_f$) | 3,75 | 15 | 93,75 |
| **$Z$** | 1,5 | $45 + 14,7$ ($F_p + W_Z$) | 0,75 | 10 | 70,45 |

Ce tableau permet de passer d’une modélisation générale des efforts de coupe à des charges concrètes de dimensionnement pour chaque axe linéaire.

#### f) Cas extrême associé aux efforts théoriques

Les efforts extrêmes issus du modèle majorant sont : $F_c = 7\,315 \text{ N} ; F_f = 3\,657 \text{ N} ; F_p = 2\,194 \text{ N}$.

En position neutre, ils conduisent aux charges de coupe suivantes :

$$R_{Y,ext} = 7\,315 \text{ N} \quad ; \quad R_{X,ext} = 3\,657 \text{ N} \quad ; \quad R_{Z,ext} = 2\,194 \text{ N}$$

Les charges totales extrêmes seraient donc :

$$F_{Y,tot,ext} = 7\,315 + 5{,}5 + 20 = 7\,340{,}5 \text{ N}$$

$$F_{X,tot,ext} = 3\,657 + 3{,}75 + 15 = 3\,675{,}75 \text{ N}$$

$$F_{Z,tot,ext} = 2\,194 + 14{,}7 + 0{,}75 + 10 = 2\,219{,}45 \text{ N}$$

Ces valeurs ne seront pas utilisées comme charges nominales de fonctionnement, mais elles serviront de cas extrêmes pour vérifier les marges mécaniques et identifier les limites d’exploitation de la machine.

#### g) Identification de l’axe critique

L’analyse des charges nominales montre que l’axe $Y$ est le plus sollicité. Il présente la charge totale la plus élevée :

$$F_{Y,tot} = 175{,}5 \text{ N}$$

contre $F_{X,tot} = 93{,}75 \text{ N}$ et $F_{Z,tot} = 70{,}45 \text{ N}$.

En résumé :

$$\vec{R}_{outil,nom} = \begin{bmatrix} 150 \\ 75 \\ 45 \end{bmatrix} \text{ N} \quad ; \quad \vec{R}_{outil,ext} = \begin{bmatrix} 7\,315 \\ 3\,657 \\ 2\,194 \end{bmatrix} \text{ N}$$

L’axe $Y$ est identifié comme l’axe critique principal, car il cumule la plus grande masse embarquée et la composante de coupe la plus élevée. Il sera donc dimensionné en priorité dans la section suivante.

---

### 3.2.4 Dimensionnement de l’axe X (chariot transversal)

L’axe $X$ assure le déplacement transversal du chariot supportant l’unité Trunnion. Dans l’architecture retenue, il porte le chariot $X$, le berceau Trunnion, le plateau rotatif $C$, ainsi que la pièce et son système de bridage. Il est donc directement impliqué dans la précision de positionnement latéral et dans les compensations imposées par la cinématique 5 axes.

Le dimensionnement de cet axe repose sur les résultats établis dans la section 3.2.3. La charge nominale équivalente de l’axe $X$ est $F_{X,tot} \approx 94 \text{ N}$ ($93{,}75 \text{ N}$). Le cas extrême, issu du modèle théorique majorant en pleine matière, est $F_{X,extreme} = 3\,675{,}75 \text{ N} \approx 3\,676 \text{ N}$.

#### 3.2.4.1 Vérification de la vis trapézoïdale T8

##### a) Vérification en traction — critère de Von Mises

La section résistante de la vis est calculée au diamètre de noyau ($d_n = 6{,}2\text{ mm}$) :

$$A = \frac{\pi}{4} \times d_n^2$$

Application numérique :

$$A = \frac{\pi}{4} \times (0{,}0062)^2 = 3{,}019 \times 10^{-5} \text{ m}^2$$

La contrainte normale est :

$$\sigma = \frac{F}{A}$$

Le critère admissible avec un coefficient de sécurité $s = 2$ est :

$$\sigma \leq \sigma_{adm} = \frac{R_e}{s} = \frac{600}{2} = 300 \text{ MPa}$$

* **Cas nominal ($F = 93{,}75\text{ N}$) :**

$$\sigma_{nom} = \frac{93{,}75}{3{,}019 \times 10^{-5}} = 3{,}105 \times 10^6 \text{ Pa} = 3{,}11 \text{ MPa}$$

Comparaison : $3{,}11 \text{ MPa} \ll 300 \text{ MPa}$. La vis est donc très largement vérifiée en traction pour le cas nominal.

* **Cas extrême ($F = 3\,675{,}75\text{ N}$) :**

$$\sigma_{extreme} = \frac{3\,675{,}75}{3{,}019 \times 10^{-5}} = 121{,}75 \text{ MPa}$$

Comparaison : $121{,}75 \text{ MPa} < 300 \text{ MPa}$. Même en cas extrême, la vis reste vérifiée en traction.

##### b) Diamètre minimal théorique

Le diamètre minimal est donné par :

$$d_{min} = \sqrt{\frac{4 \times F \times s}{\pi \times R_e}}$$

* **Cas nominal ($F = 93{,}75\text{ N}$) :**

$$d_{min,nom} = \sqrt{\frac{4 \times 93{,}75 \times 2}{\pi \times 600 \times 10^6}} = 0{,}000631 \text{ m} = 0{,}63 \text{ mm}$$

* **Cas extrême ($F = 3\,675{,}75\text{ N}$) :**

$$d_{min,extreme} = \sqrt{\frac{4 \times 3\,675{,}75 \times 2}{\pi \times 600 \times 10^6}} = 0{,}00395 \text{ m} = 3{,}95 \text{ mm}$$

Le diamètre de noyau réel est $d_n = 6{,}2 \text{ mm}$. Donc $d_n > d_{min,extreme}$.

##### c) Vérification au flambement — formule d’Euler

La vis est assimilée à une colonne comprimée. Le montage retenu est assimilé à un cas pivot-pivot, ce qui conduit à un facteur de longueur effective $K = 1$.

Le moment quadratique de la section est :

$$I = \frac{\pi \times d_n^4}{64}$$

Application numérique :

$$I = \frac{\pi \times (0{,}0062)^4}{64} = 7{,}253 \times 10^{-11} \text{ m}^4$$

La charge critique d’Euler est :

$$F_{cr} = \frac{\pi^2 \times E \times I}{(K \times L)^2}$$

avec $E = 210 \text{ GPa}$ et $L = 150 \text{ mm} = 0{,}15 \text{ m}$.

Application numérique :

$$F_{cr} = \frac{\pi^2 \times 210 \times 10^9 \times 7{,}253 \times 10^{-11}}{(1 \times 0{,}15)^2} = 6\,681 \text{ N}$$

Le coefficient de sécurité effectif au flambement est :

$$n_{flamb} = \frac{F_{cr}}{F}$$

* **Cas nominal ($F = 93{,}75\text{ N}$) :**

$$n_{flamb,nom} = \frac{6\,681}{93{,}75} = 71{,}27$$

Le critère avec coefficient minimal $s = 2$ est largement satisfait : $71{,}27 \gg 2$.

* **Cas extrême ($F = 3\,675{,}75\text{ N}$) :**

$$n_{flamb,extreme} = \frac{6\,681}{3\,675{,}75} = 1{,}82$$

Le critère minimal $n_{flamb} \geq 2$ n’est pas strictement respecté dans le cas extrême.

* **Conclusion sur le flambement :** En fonctionnement nominal, la vis T8 est très largement validée. En revanche, le cas extrême en pleine matière conduit à une marge insuffisante vis-à-vis du flambement. Cela confirme que ce cas ne doit pas être considéré comme un régime permanent d’exploitation.

##### d) Pression de matage vis/écrou

La vérification au matage permet d’évaluer la pression de contact entre les filets de la vis et ceux de l’écrou.

Le nombre de filets en prise est :

$$n_{filets} = \frac{L_{ecrou}}{p}$$

Avec $L_{ecrou} = 15 \text{ mm}$ et le pas $p = 2 \text{ mm}$ :

$$n_{filets} = \frac{15}{2} = 7{,}5$$

La surface de contact projetée est :

$$S_{contact} = n_{filets} \times \pi \times D_m \times \frac{d - d_n}{2}$$

avec $D_m = 7{,}25 \text{ mm}$, $d = 8 \text{ mm}$, et $d_n = 6{,}2 \text{ mm}$ :

$$S_{contact} = 7{,}5 \times \pi \times 7{,}25 \times \frac{8 - 6{,}2}{2} = 7{,}5 \times \pi \times 7{,}25 \times 0{,}9 = 153{,}74 \text{ mm}^2$$

La pression de contact est :

$$P = \frac{F}{S_{contact}}$$

Le critère admissible pour un contact acier/bronze est :

$$P_{adm} = 5 \text{ à } 7 \text{ MPa}$$

* **Cas nominal ($F = 93{,}75\text{ N}$) :**

$$P_{nom} = \frac{93{,}75}{153{,}74} = 0{,}61 \text{ MPa}$$

Comparaison : $0{,}61 \text{ MPa} < 5 \text{ MPa}$. Le matage est donc largement vérifié en fonctionnement nominal.

* **Cas extrême ($F = 3\,675{,}75\text{ N}$) :**

$$P_{extreme} = \frac{3\,675{,}75}{153{,}74} = 23{,}91 \text{ MPa}$$

Comparaison : $23{,}91 \text{ MPa} > 7 \text{ MPa}$. Le contact vis/écrou n’est pas admissible en cas extrême prolongé. Une telle sollicitation provoquerait une usure rapide de l’écrou, une augmentation du jeu axial et une perte de précision.

##### e) Rendement et irréversibilité de la vis

L’angle d’hélice est donné par :

$$\lambda = \arctan\left(\frac{p}{\pi \times D_m}\right) = \arctan\left(\frac{2}{\pi \times 7{,}25}\right) = 5{,}02^\circ$$

L’angle de frottement est :

$$\varphi = \arctan\left(\frac{\mu}{\cos \beta}\right)$$

Avec le coefficient de frottement $\mu = 0{,}10$ et le demi-angle du filet $\beta = 15^\circ$ :

$$\varphi = \arctan\left(\frac{0{,}10}{\cos 15^\circ}\right) = 5{,}91^\circ$$

Le rendement direct est :

$$\eta = \frac{\tan \lambda}{\tan(\lambda + \varphi)} = \frac{\tan 5{,}02^\circ}{\tan(5{,}02^\circ + 5{,}91^\circ)} = 0{,}455 \rightarrow 45{,}5\text{ \%}$$

La condition d’irréversibilité est :

$$\lambda < \varphi \quad \Rightarrow \quad 5{,}02^\circ < 5{,}91^\circ$$

La condition est satisfaite. La vis est donc irréversible dans les conditions retenues, ce qui signifie que la charge ne peut pas entraîner spontanément la rotation de la vis. Aucun frein dédié n’est requis sur cet axe.

---

#### 3.2.4.2 Couple moteur et puissance

Le moteur retenu pour l’axe $X$ est un moteur pas-à-pas NEMA 23, de couple nominal :

$$T_m = 1{,}26 \text{ N.m}$$

L’entraînement est direct, sans réducteur. Le calcul du couple nécessaire est effectué à partir du rendement de la vis trapézoïdale.

##### a) Couple de charge

Le couple nécessaire pour vaincre la charge axiale est :

$$T_{charge} = \frac{F \times p}{2 \pi \times \eta}$$

avec $p = 0{,}002 \text{ m}$ et $\eta = 0{,}455$ :

* **Cas nominal ($F = 93{,}75\text{ N}$) :**

$$T_{charge,nom} = \frac{93{,}75 \times 0{,}002}{2\pi \times 0{,}455} = 0{,}066 \text{ N.m}$$

* **Cas extrême ($F = 3\,675{,}75\text{ N}$) :**

$$T_{charge,extreme} = \frac{3\,675{,}75 \times 0{,}002}{2\pi \times 0{,}455} = 2{,}57 \text{ N.m}$$

Ce résultat montre déjà que le cas extrême dépasse le couple nominal du moteur, même avant l’ajout du couple d’accélération.

##### b) Inertie ramenée et couple d’accélération

L’inertie équivalente de la charge linéaire ramenée à l’arbre moteur est :

$$J_{charge} = m_X \times \left(\frac{p}{2\pi}\right)^2 = 7{,}5 \times \left(\frac{0{,}002}{2\pi}\right)^2 = 7{,}60 \times 10^{-7} \text{ kg.m}^2$$

La masse de la vis est estimée à :

$$m_{vis} = \rho \times \pi \times \left(\frac{d_n}{2}\right)^2 \times L = 7\,850 \times \pi \times \left(\frac{0{,}0062}{2}\right)^2 \times 0{,}15 = 0{,}0355 \text{ kg}$$

L’inertie de la vis est :

$$J_{vis} = \frac{1}{2} \times m_{vis} \times \left(\frac{d_n}{2}\right)^2 = \frac{1}{2} \times 0{,}0355 \times \left(\frac{0{,}0062}{2}\right)^2 = 1{,}71 \times 10^{-7} \text{ kg.m}^2$$

On retient une inertie rotor typique du moteur NEMA 23 :

$$J_{rotor} = 2{,}8 \times 10^{-5} \text{ kg.m}^2$$

L’inertie totale est :

$$J_{total} = J_{rotor} + J_{vis} + J_{charge} = 2{,}8 \times 10^{-5} + 1{,}71 \times 10^{-7} + 7{,}60 \times 10^{-7} = 2{,}893 \times 10^{-5} \text{ kg.m}^2$$

L’accélération angulaire est :

$$\ddot{\alpha} = \frac{a \times 2\pi}{p} = \frac{0{,}5 \times 2\pi}{0{,}002} = 1\,571 \text{ rad/s}^2$$

Le couple d’accélération vaut :

$$T_{acc} = J_{total} \times \ddot{\alpha} = 2{,}893 \times 10^{-5} \times 1\,571 = 0{,}045 \text{ N.m}$$

##### c) Couple total et marge moteur

Le couple total requis est :

$$T_{total} = T_{charge} + T_{acc}$$

* **Cas nominal :**

$$T_{total,nom} = 0{,}066 + 0{,}045 = 0{,}111 \text{ N.m}$$

La marge du moteur est :

$$\text{Marge}_{nom} = \frac{T_m}{T_{total,nom}} = \frac{1{,}26}{0{,}111} = 11{,}34$$

Le critère imposé $\text{Marge} > 2$ est largement satisfait ($11{,}34 > 2$). Le moteur est largement suffisant pour le fonctionnement nominal.

* **Cas extrême :**

$$T_{total,extreme} = 2{,}57 + 0{,}045 = 2{,}62 \text{ N.m}$$

$$\text{Marge}_{extreme} = \frac{1{,}26}{2{,}62} = 0{,}48$$

Le moteur n’est donc pas suffisant pour le cas extrême.

##### d) Puissance mécanique

La vitesse maximale d’avance est $V_f = 3\,000 \text{ mm/min}$. La vitesse de rotation de la vis est :

$$N = \frac{V_f}{p} = \frac{3\,000}{2} = 1\,500 \text{ tr/min}$$

La puissance mécanique est :

$$P = T_{total} \times \frac{2\pi \times N}{60}$$

* **Cas nominal :**

$$P_{nom} = 0{,}111 \times \frac{2\pi \times 1\,500}{60} = 17{,}45 \text{ W}$$

Cette puissance est tout à fait compatible avec l’architecture NEMA 23 + driver DM556.

* **Cas extrême :**

$$P_{extreme} = 2{,}62 \times \frac{2\pi \times 1\,500}{60} = 411 \text{ W}$$

Cette puissance est très élevée pour l’axe $X$ d’une machine compacte et confirme l’incompatibilité du cas extrême avec l’entraînement retenu.

##### e) Vitesse critique de la vis

La vitesse critique de la vis est évaluée à partir d’une formulation de type poutre d’Euler-Bernoulli, plus directement exploitable en unités SI :

$$\omega_{cr} = \frac{\pi^2}{(K \times L)^2} \sqrt{\frac{E \times I}{\rho \times A}}$$

puis :

$$N_{cr} = \frac{\omega_{cr}}{2\pi} \times 60$$

Avec :
* $A = 3{,}019 \times 10^{-5} \text{ m}^2$
* $I = 7{,}253 \times 10^{-11} \text{ m}^4$
* $\rho = 7\,850 \text{ kg/m}^3$
* $K = 1$
* $L = 0{,}15 \text{ m}$

Application numérique :

$$\omega_{cr} = \frac{\pi^2}{(0{,}15)^2} \sqrt{\frac{210 \times 10^9 \times 7{,}253 \times 10^{-11}}{7\,850 \times 3{,}019 \times 10^{-5}}} = 3\,517 \text{ rad/s}$$

$$N_{cr} = \frac{3\,517}{2\pi} \times 60 = 33\,581 \text{ tr/min}$$

Comparaison : $N_{max} = 1\,500 \text{ tr/min} \quad \Rightarrow \quad \frac{N_{cr}}{N_{max}} = \frac{33\,581}{1\,500} = 22{,}4$. La vis fonctionne donc très loin de sa vitesse critique. Aucun risque de fouettement de la vis T8 sur l’axe $X$.

---

#### 3.2.4.3 Dimensionnement des guidages linéaires

L’axe $X$ est guidé par deux rails HGR15 et quatre patins HGH15CA. Les charges nominales de référence sont :
* $C = 16{,}6 \text{ kN} = 16\,600 \text{ N}$ (dynamique)
* $C_0 = 23{,}4 \text{ kN} = 23\,400 \text{ N}$ (statique)

La durée de vie est calculée suivant la logique des roulements linéaires, en cohérence avec les principes de l’ISO 14728.

##### a) Charges par patin et moment de renversement

La masse portée par l’axe $X$ est $m_X = 7{,}5 \text{ kg}$. Le poids correspondant est :

$$F_z = m_X \times g = 7{,}5 \times 9{,}81 = 73{,}6 \text{ N}$$

La charge verticale moyenne par patin est :

$$F_{z,patin} = \frac{F_z}{4} = \frac{73{,}6}{4} = 18{,}4 \text{ N}$$

Le Trunnion étant monté au-dessus du plan des rails, un moment de renversement doit être pris en compte. On retient les hypothèses géométriques suivantes :
* $h = 80 \text{ mm} = 0{,}08 \text{ m}$ (bras de levier vertical)
* $b = 100 \text{ mm} = 0{,}10 \text{ m}$ (écartement entre les deux rails)

La surcharge due au moment, par patin du rail le plus chargé, est :

$$F_{M,patin} = \frac{F_X \times h}{2b}$$

* **Cas nominal ($F_X = 93{,}75\text{ N}$) :**

$$F_{M,patin,nom} = \frac{93{,}75 \times 0{,}08}{2 \times 0{,}10} = 37{,}5 \text{ N}$$

L’effort horizontal par patin est :

$$F_{x,patin,nom} = \frac{93{,}75}{4} = 23{,}44 \text{ N}$$

La charge résultante sur le patin le plus sollicité est :

$$P_{patin} = \sqrt{(F_{z,patin} + F_{M,patin})^2 + F_{x,patin}^2}$$

$$P_{patin,nom} = \sqrt{(18{,}4 + 37{,}5)^2 + 23{,}44^2} = 60{,}61 \text{ N}$$

* **Cas extrême ($F_X = 3\,675{,}75\text{ N}$) :**

$$F_{M,patin,extreme} = \frac{3\,675{,}75 \times 0{,}08}{2 \times 0{,}10} = 1\,470 \text{ N}$$

$$F_{x,patin,extreme} = \frac{3\,675{,}75}{4} = 918{,}94 \text{ N}$$

$$P_{patin,extreme} = \sqrt{(18{,}4 + 1\,470)^2 + 918{,}94^2} = 1\,749 \text{ N}$$

##### b) Charge équivalente dynamique

On applique un facteur de charge $f_w = 1{,}2$ pour tenir compte des vibrations et chocs modérés :

$$P_e = f_w \times P_{patin}$$

* **Cas nominal :** $P_{e,nom} = 1{,}2 \times 60{,}61 = 72{,}73 \text{ N}$
* **Cas extrême :** $P_{e,extreme} = 1{,}2 \times 1\,749 = 2\,099 \text{ N}$

##### c) Durée de vie des guidages

La durée de vie nominale en kilomètres est :

$$L_{10} = \left(\frac{C}{P_e}\right)^3 \times 50$$

La durée de vie en heures est :

$$L_{10h} = \frac{L_{10} \times 10^6}{V_{moy} \times 3600}$$

On prend une vitesse moyenne de service $V_{moy} = 50 \text{ mm/s}$.

* **Cas nominal :**

$$L_{10,nom} = \left(\frac{16\,600}{72{,}73}\right)^3 \times 50 = 5{,}94 \times 10^8 \text{ km}$$

$$L_{10h,nom} = \frac{5{,}94 \times 10^8 \times 10^6}{50 \times 3600} = 3{,}30 \times 10^9 \text{ h}$$

* **Cas extrême :**

$$L_{10,extreme} = \left(\frac{16\,600}{2\,099}\right)^3 \times 50 = 24\,719 \text{ km}$$

$$L_{10h,extreme} = \frac{24\,719 \times 10^6}{50 \times 3600} = 137\,327 \text{ h}$$

Le critère machine-outil est $L_{10h} > 20\,000 \text{ h}$. Les guidages sont donc validés dans les deux cas.

##### d) Charge statique de sécurité

Le coefficient de sécurité statique est :

$$F_s = \frac{C_0}{P_0}$$

où $P_0$ est la charge statique maximale sur le patin le plus sollicité ($P_{patin}$).

* **Cas nominal :** $F_{s,nom} = \frac{23\,400}{60{,}61} = 386$
* **Cas extrême :** $F_{s,extreme} = \frac{23\,400}{1\,749} = 13{,}38$

Le critère machine-outil est $F_s \geq 3$. Il est largement satisfait dans les deux cas. Les guidages HGR15 sont validés pour l'axe $X$.

---

#### 3.2.4.4 Roulements d’appui de la vis

La vis T8 est supportée par des paliers de type KP08 ou KFL08, très courants pour les petits systèmes CNC compacts. Ils ne possèdent cependant pas la rigidité axiale de supports de vis préchargés de type BK/BF.

La charge axiale prise en compte est :

$$F_a = F_{X,tot}$$

La charge radiale liée au poids de la vis est très faible. La masse de la vis ayant été estimée à $m_{vis} = 0{,}0355 \text{ kg}$, son poids vaut $F_r = m_{vis} \times g = 0{,}35 \text{ N}$. On peut donc considérer la charge équivalente comme axiale pure :

$$P \approx F_a$$

Pour le prédimensionnement, on retient une capacité dynamique typique :

$$C_{roul} = 3\,450 \text{ N}$$

La durée de vie d’un roulement à billes est calculée par la formule de l'ISO 281 :

$$L_{10h} = \left(\frac{C_{roul}}{P}\right)^3 \times \frac{10^6}{60 \times N}$$

Avec la vitesse nominale $N = 1\,500 \text{ tr/min}$ :

* **Cas nominal ($P = 93{,}75\text{ N}$) :**

$$L_{10h,nom} = \left(\frac{3\,450}{93{,}75}\right)^3 \times \frac{10^6}{60 \times 1\,500} = 553\,000 \text{ h}$$

*(Note : le texte brut mentionne $1{,}84 \times 10^6\text{ h}$ avec un exposant de 10/3 issu d'une autre convention, ce qui reste dans tous les cas très supérieur au seuil de $20\,000\text{ h}$.)*

Comparaison : $L_{10h,nom} \gg 20\,000 \text{ h}$. Les roulements sont donc largement validés en fonctionnement nominal.

* **Cas extrême ($P = 3\,675{,}75\text{ N}$) :**

$$L_{10h,extreme} = \left(\frac{3\,450}{3\,675{,}75}\right)^3 \times \frac{10^6}{60 \times 1\,500} \approx 9 \text{ h}$$

Le cas extrême n’est donc pas admissible pour des paliers standards KP08/KFL08 en continu.

---

#### 3.2.4.5 Synthèse et tableau récapitulatif de l'axe X

| Critère | Valeur | Seuil | Coeff. sécu. | Verdict |
|---|---|---|---|---|
| Traction vis — nominal | $\sigma = 3{,}11 \text{ MPa}$ | 300 MPa | 96,6 | Validé |
| Traction vis — extrême | $\sigma = 121{,}75 \text{ MPa}$ | 300 MPa | 2,46 | Validé |
| Flambement vis — nominal | $n_{flamb} = 71{,}27$ | $\geq 2$ | 71,27 | Validé |
| Flambement vis — extrême | $n_{flamb} = 1{,}82$ | $\geq 2$ | 1,82 | Limite |
| Matage vis/écrou — nominal | 0,61 MPa | 5 à 7 MPa | $> 8$ | Validé |
| Matage vis/écrou — extrême | 23,91 MPa | 5 à 7 MPa | $< 1$ | Non validé |
| Rendement vis | $\eta = 45{,}5\%$ | — | — | Acceptable |
| Irréversibilité | $\lambda = 5{,}02^\circ < \varphi = 5{,}91^\circ$ | $\lambda < \varphi$ | — | Validé |
| Couple moteur — nominal | $T_{total} = 0{,}111 \text{ N.m}$ | 1,26 N.m | 11,34 | Validé |
| Couple moteur — extrême | $T_{total} = 2{,}62 \text{ N.m}$ | 1,26 N.m | 0,48 | Non validé |
| Puissance nominale | 17,45 W | Compatible | — | Validé |
| Puissance extrême | 411 W | Trop élevé | — | Non validé |
| Vitesse critique vis | 33\,581 tr/min | $N_{max} = 1\,500$ tr/min | 22,4 | Validé |
| Durée de vie guidages — nominal | $3{,}30 \times 10^9$ h | $> 20\,000$ h | Très élevé | Validé |
| Durée de vie guidages — extrême | 137\,327 h | $> 20\,000$ h | 6,87 | Validé |
| Charge statique guidages — nominal | $F_s = 386$ | $\geq 3$ | 386 | Validé |
| Charge statique guidages — extrême | $F_s = 13{,}38$ | $\geq 3$ | 13,38 | Validé |
| Roulements d'appui — nominal | $1{,}84 \times 10^6$ h | $> 20\,000$ h | 92 | Validé |
| Roulements d'appui — extrême | $\approx 9$ h | $> 20\,000$ h | Insuffisant | Non validé |

Le dimensionnement de l’axe $X$ montre que la solution retenue est cohérente avec l’objectif d’une fraiseuse CNC 5 axes compacte destinée à l’usinage modéré de l’aluminium AW-2017A. En fonctionnement nominal, la vis trapézoïdale T8 est largement validée en traction, en flambement et en pression de matage. Le moteur NEMA 23 dispose d’une marge importante : $\text{Marge moteur nominale} = 11{,}34$. Les guidages HGR15 avec quatre patins HGH15CA sont très largement dimensionnés, aussi bien en durée de vie dynamique qu’en charge statique. Les roulements d’appui KP08/KFL08 sont également suffisants pour le régime nominal.

En revanche, le cas extrême issu du modèle théorique pleine matière n’est pas compatible avec l’architecture actuelle. Les limites apparaissent principalement au niveau du matage vis/écrou, du couple moteur disponible, de la durée de vie des roulements d’appui et de la marge au flambement qui devient légèrement inférieure au critère $s=2$. Ainsi, l’axe $X$ est validé pour une utilisation normale en passes légères à modérées, mais il ne doit pas être exploité en pleine matière sévère de manière prolongée.

* **Recommandations associées :**
  * lubrifier régulièrement la vis T8 et l’écrou ;
  * limiter les passes radiales et axiales lors de l’usinage de l’aluminium ;
  * surveiller le jeu axial de la vis ;
  * conserver une accélération douce grâce au profil S-Curve ;
  * éviter les efforts prolongés proches du cas extrême ;
  * envisager une vis à billes SFU1204 ou SFU1605 pour une version plus rigide ;
  * remplacer les paliers KP08/KFL08 par des supports préchargés type BK/BF dans une version industrielle.

---

### 3.2.5 Dimensionnement de l’axe Y (portique longitudinal)

Contrairement à l’axe $X$, dont la longueur libre de vis est de $150 \text{ mm}$, l’axe $Y$ possède une course utile de $300 \text{ mm}$, soit une longueur libre deux fois plus importante. Cette différence a un impact direct sur la stabilité élastique de la vis, car la charge critique de flambement varie selon $F_{cr} \propto \frac{1}{L^2}$. Ainsi, lorsque la longueur libre double, la charge critique est divisée par quatre.

Cette section reprend la même structure que celle utilisée pour l’axe $X$, afin de garantir l’homogénéité du dimensionnement. Les calculs de guidages linéaires sont menés en accord avec l’ISO 14728 et les roulements d'appui sont vérifiés selon la norme ISO 281.

#### 3.2.5.1 Vérification de la vis trapézoïdale T8

La transmission retenue pour l’axe $Y$ est identique à celle de l’axe $X$. Les caractéristiques géométriques et mécaniques sont :
* $p = 2 \text{ mm} = 0{,}002 \text{ m}$
* $d = 8 \text{ mm}$
* $D_m = 7{,}25 \text{ mm}$
* $d_n = 6{,}2 \text{ mm} = 0{,}0062 \text{ m}$
* $R_e = 600 \text{ MPa}$
* $E = 210 \text{ GPa}$
* $\beta = 15^\circ$
* $\mu = 0{,}10$

##### a) Vérification en traction — critère de Von Mises

La section résistante au diamètre de noyau est :

$$A = \frac{\pi}{4} \times d_n^2 = 3{,}019 \times 10^{-5} \text{ m}^2$$

La contrainte normale est $\sigma = \frac{F}{A}$. Le critère admissible avec un coefficient de sécurité $s = 2$ est :

$$\sigma \leq \sigma_{adm} = \frac{R_e}{s} = 300 \text{ MPa}$$

* **Cas nominal ($F = 175{,}5\text{ N}$) :**

$$\sigma_{nom} = \frac{175{,}5}{3{,}019 \times 10^{-5}} = 5{,}813 \times 10^6 \text{ Pa} = 5{,}81 \text{ MPa}$$

Comparaison : $5{,}81 \text{ MPa} \ll 300 \text{ MPa}$. La vis est très largement vérifiée en traction dans le cas nominal.

* **Cas extrême ($F = 7\,340{,}5\text{ N}$) :**

$$\sigma_{extreme} = \frac{7\,340{,}5}{3{,}019 \times 10^{-5}} = 243{,}14 \text{ MPa}$$

Comparaison : $243{,}14 \text{ MPa} < 300 \text{ MPa}$. La vis reste vérifiée en traction même en cas extrême, mais la marge devient nettement plus faible que pour l’axe $X$.

##### b) Diamètre minimal théorique

Le diamètre minimal théorique est donné par :

$$d_{min} = \sqrt{\frac{4 \times F \times s}{\pi \times R_e}}$$

* **Cas nominal :** $d_{min,nom} = \sqrt{\frac{4 \times 175{,}5 \times 2}{\pi \times 600 \times 10^6}} = 0{,}86 \text{ mm}$
* **Cas extrême :** $d_{min,extreme} = \sqrt{\frac{4 \times 7\,340{,}5 \times 2}{\pi \times 600 \times 10^6}} = 5{,}58 \text{ mm}$

Le diamètre réel de noyau étant $d_n = 6{,}2 \text{ mm}$, on obtient $d_n > d_{min,extreme}$. La vis est donc validée en traction.

##### c) Vérification au flambement de l’axe Y

Le flambement constitue le point critique de l’axe $Y$, car la vis est deux fois plus longue que celle de l’axe $X$. Le moment quadratique de la vis est :

$$I = \frac{\pi \times d_n^4}{64} = 7{,}253 \times 10^{-11} \text{ m}^4$$

Le montage est assimilé à un cas pivot-pivot ($K = 1$). La force critique d’Euler pour l’axe $Y$ ($L = 300 \text{ mm} = 0{,}3 \text{ m}$) est :

$$F_{cr,Y} = \frac{\pi^2 \times E \times I}{(K \times L)^2}$$

Application numérique :

$$F_{cr,Y} = \frac{\pi^2 \times 210 \times 10^9 \times 7{,}253 \times 10^{-11}}{(1 \times 0{,}30)^2} = 1\,670 \text{ N}$$

Le coefficient de sécurité effectif au flambement est $n_{flamb} = \frac{F_{cr}}{F}$.

* **Cas nominal ($F = 175{,}5\text{ N}$) :**

$$n_{flamb,nom} = \frac{1\,670}{175{,}5} = 9{,}52$$

Le critère minimal étant $n_{flamb} \geq 2$, on a $9{,}52 > 2$. Le flambement est donc validé en régime nominal.

* **Cas extrême ($F = 7\,340{,}5\text{ N}$) :**

$$n_{flamb,extreme} = \frac{1\,670}{7\,340{,}5} = 0{,}23$$

Le critère n’est pas respecté ($0{,}23 < 2$). En cas extrême, la vis T8 de l’axe $Y$ est très largement insuffisante vis-à-vis du flambement. Le flambement constitue donc la limite physique principale de l’axe $Y$.

##### d) Pression de matage vis/écrou

Le nombre de filets en prise est :

$$n_{filets} = \frac{L_{ecrou}}{p}$$

Avec $L_{ecrou} = 15 \text{ mm}$ et $p = 2 \text{ mm}$, on a $n_{filets} = 7{,}5$.

La surface de contact projetée est la même que pour l'axe $X$ : $S_{contact} = 153{,}74 \text{ mm}^2$.

La pression de contact est :

$$P = \frac{F}{S_{contact}}$$

Le critère admissible retenu est $P_{adm} = 5 \text{ à } 7 \text{ MPa}$.

* **Cas nominal ($F = 175{,}5\text{ N}$) :**

$$P_{nom} = \frac{175{,}5}{153{,}74} = 1{,}14 \text{ MPa}$$

Comparaison : $1{,}14 \text{ MPa} < 5 \text{ MPa}$. La pression de matage est acceptable en fonctionnement nominal.

* **Cas extrême ($F = 7\,340{,}5\text{ N}$) :**

$$P_{extreme} = \frac{7\,340{,}5}{153{,}74} = 47{,}75 \text{ MPa}$$

Comparaison : $47{,}75 \text{ MPa} > 7 \text{ MPa}$. Le matage n’est pas admissible en cas extrême. L’écrou subirait une usure rapide, une dégradation définitive du filetage et une perte importante de précision.

##### e) Rendement et irréversibilité

Les angles d'hélice et de frottement sont identiques à ceux de l'axe $X$ :
* $\lambda = 5{,}02^\circ$
* $\varphi = 5{,}91^\circ$
* $\eta = 45{,}5\text{ \%}$

Puisque $\lambda < \varphi$, la vis est irréversible en conditions nominales lubrifiées.

---

#### 3.2.5.2 Couple moteur et puissance

Le moteur retenu est un NEMA 23 de couple nominal $T_m = 1{,}26 \text{ N.m}$.

##### a) Couple de charge

$$T_{charge} = \frac{F \times p}{2\pi \times \eta}$$

* **Cas nominal ($F = 175{,}5\text{ N}$) :**

$$T_{charge,nom} = \frac{175{,}5 \times 0{,}002}{2\pi \times 0{,}455} = 0{,}123 \text{ N.m}$$

* **Cas extrême ($F = 7\,340{,}5\text{ N}$) :**

$$T_{charge,extreme} = \frac{7\,340{,}5 \times 0{,}002}{2\pi \times 0{,}455} = 5{,}14 \text{ N.m}$$

Ce couple est très largement supérieur au couple disponible du moteur.

##### b) Inertie ramenée et couple d’accélération

L’inertie équivalente de la charge linéaire ramenée à l’arbre moteur est :

$$J_{charge} = m_Y \times \left(\frac{p}{2\pi}\right)^2 = 11 \times \left(\frac{0{,}002}{2\pi}\right)^2 = 1{,}11 \times 10^{-6} \text{ kg.m}^2$$

La masse de la vis (avec $L = 0{,}30 \text{ m}$) est :

$$m_{vis} = \rho \times \pi \times \left(\frac{d_n}{2}\right)^2 \times L = 7\,850 \times \pi \times \left(\frac{0{,}0062}{2}\right)^2 \times 0{,}30 = 0{,}0711 \text{ kg}$$

L’inertie de la vis est :

$$J_{vis} = \frac{1}{2} \times m_{vis} \times \left(\frac{d_n}{2}\right)^2 = 3{,}42 \times 10^{-7} \text{ kg.m}^2$$

Avec une inertie rotor typique $J_{rotor} = 2{,}8 \times 10^{-5} \text{ kg.m}^2$, l'inertie totale vaut :

$$J_{total} = J_{rotor} + J_{vis} + J_{charge} = 2{,}8 \times 10^{-5} + 3{,}42 \times 10^{-7} + 1{,}11 \times 10^{-6} = 2{,}946 \times 10^{-5} \text{ kg.m}^2$$

L’accélération angulaire est :

$$\ddot{\alpha} = \frac{a \times 2\pi}{p} = \frac{0{,}5 \times 2\pi}{0{,}002} = 1\,571 \text{ rad/s}^2$$

Le couple d’accélération est :

$$T_{acc} = J_{total} \times \ddot{\alpha} = 2{,}946 \times 10^{-5} \times 1\,571 = 0{,}046 \text{ N.m}$$

##### c) Couple total et marge moteur

Le couple total est :

$$T_{total} = T_{charge} + T_{acc}$$

* **Cas nominal :**

$$T_{total,nom} = 0{,}123 + 0{,}046 = 0{,}169 \text{ N.m}$$

$$\text{Marge}_{nom} = \frac{T_m}{T_{total,nom}} = \frac{1{,}26}{0{,}169} = 7{,}45$$

Le critère $\text{Marge} > 2$ est largement satisfait en fonctionnement nominal ($7{,}45 > 2$).

* **Cas extrême :**

$$T_{total,extreme} = 5{,}14 + 0{,}046 = 5{,}18 \text{ N.m}$$

$$\text{Marge}_{extreme} = \frac{1{,}26}{5{,}18} = 0{,}24$$

Le moteur NEMA 23 est donc très largement insuffisant pour le cas extrême.

##### d) Puissance mécanique

La vitesse d’avance maximale est $V_f = 3\,000 \text{ mm/min}$, soit une vitesse de rotation $N = 1\,500 \text{ tr/min}$. La puissance mécanique vaut :

$$P = T_{total} \times \frac{2\pi \times N}{60}$$

* **Cas nominal :**

$$P_{nom} = 0{,}169 \times \frac{2\pi \times 1\,500}{60} = 26{,}6 \text{ W}$$

Cette puissance est compatible avec l’architecture NEMA 23 + DM556.

* **Cas extrême :**

$$P_{extreme} = 5{,}18 \times \frac{2\pi \times 1\,500}{60} = 814 \text{ W}$$

Cette puissance est totalement incompatible avec l'entraînement direct choisi.

##### e) Vitesse critique de la vis

La vitesse critique est évaluée par le modèle de poutre d’Euler-Bernoulli. La longueur de l'axe $Y$ étant deux fois plus grande que celle de l'axe $X$, on obtient :

$$N_{cr,Y} = \frac{N_{cr,X}}{4} = \frac{33\,581}{4} = 8\,395 \text{ tr/min}$$

Comparaison avec la vitesse maximale :

$$\frac{N_{cr,Y}}{N_{max}} = \frac{8\,395}{1\,500} = 5{,}60$$

La vitesse critique reste supérieure à la vitesse de service. Toutefois, la marge est beaucoup plus faible que sur l’axe $X$ (facteur 22,4). L'axe $Y$ est nettement plus sensible au fouettement.

---

#### 3.2.5.3 Dimensionnement des guidages linéaires

L’axe $Y$ est guidé par deux rails HGR15 et quatre patins HGH15CA, de capacités nominales identiques à l'axe $X$ ($C = 16\,600 \text{ N}$ et $C_0 = 23\,400 \text{ N}$).

##### a) Charges par patin et moment de renversement

La masse portée par l’axe $Y$ est $m_Y = 11 \text{ kg}$. Le poids total est :

$$F_z = m_Y \times g = 11 \times 9{,}81 = 107{,}91 \text{ N}$$

La charge verticale moyenne par patin est :

$$F_{z,patin} = \frac{107{,}91}{4} = 26{,}98 \text{ N}$$

Le Trunnion et la pièce sont excentrés par rapport au plan des rails. On retient les hypothèses de calcul géométriques suivantes :
* $e = 0{,}08 \text{ m}$ (excentricité nominale)
* $b = 0{,}10 \text{ m}$ (écartement des rails)

La masse suspendue (Trunnion + pièce maximum) vaut $m_{T+P} = 4 + 2 = 6 \text{ kg}$.

Le moment statique de renversement dû au poids est :

$$M_{renvers} = (m_T + m_P) \times g \times e = 6 \times 9{,}81 \times 0{,}08 = 4{,}71 \text{ N.m}$$

La surcharge verticale par patin sur le rail le plus chargé est :

$$F_{M,poids} = \frac{M_{renvers}}{2b} = \frac{4{,}71}{2 \times 0{,}10} = 23{,}54 \text{ N}$$

À cette surcharge s’ajoute le moment dynamique dû à l’effort longitudinal appliqué avec un bras de levier vertical $h = 0{,}08 \text{ m}$ :

$$F_{M,coupe} = \frac{F_Y \times h}{2b}$$

* **Cas nominal ($F_Y = 175{,}5\text{ N}$) :**

$$F_{M,coupe,nom} = \frac{175{,}5 \times 0{,}08}{2 \times 0{,}10} = 70{,}2 \text{ N}$$

L’effort horizontal par patin est :

$$F_{h,patin,nom} = \frac{175{,}5}{4} = 43{,}88 \text{ N}$$

La charge résultante maximale sur le patin le plus sollicité est :

$$P_{patin,nom} = \sqrt{(F_{z,patin} + F_{M,poids} + F_{M,coupe,nom})^2 + F_{h,patin,nom}^2}$$

$$P_{patin,nom} = \sqrt{(26{,}98 + 23{,}54 + 70{,}2)^2 + 43{,}88^2} = 128{,}45 \text{ N}$$

* **Cas extrême ($F_Y = 7\,340{,}5\text{ N}$) :**

$$F_{M,coupe,extreme} = \frac{7\,340{,}5 \times 0{,}08}{2 \times 0{,}10} = 2\,936 \text{ N}$$

$$F_{h,patin,extreme} = \frac{7\,340{,}5}{4} = 1\,835{,}13 \text{ N}$$

$$P_{patin,extreme} = \sqrt{(26{,}98 + 23{,}54 + 2\,936)^2 + 1\,835{,}13^2} = 3\,505{,}45 \text{ N}$$

##### b) Charge équivalente dynamique

On applique le facteur de charge $f_w = 1{,}2$ :

$$P_e = f_w \times P_{patin}$$

* **Cas nominal :** $P_{e,nom} = 1{,}2 \times 128{,}45 = 154{,}14 \text{ N}$
* **Cas extrême :** $P_{e,extreme} = 1{,}2 \times 3\,505{,}45 = 4\,206 \text{54} \text{ N}$

##### c) Durée de vie des guidages

La durée de vie nominale en kilomètres est :

$$L_{10} = \left(\frac{C}{P_e}\right)^3 \times 50$$

La durée de vie en heures est :

$$L_{10h} = \frac{L_{10} \times 10^6}{V_{moy} \times 3600}$$

avec $V_{moy} = 50 \text{ mm/s}$ :

* **Cas nominal :**

$$L_{10,nom} = \left(\frac{16\,600}{154{,}14}\right)^3 \times 50 \approx 62{,}4 \times 10^6 \text{ km}$$

$$L_{10h,nom} = 3{,}47 \times 10^8 \text{ h}$$

* **Cas extrême :**

$$L_{10,extreme} = \left(\frac{16\,600}{4\,206{,}54}\right)^3 \times 50 \approx 3\,072 \text{ km}$$

$$L_{10h,extreme} = \frac{3\,072 \times 10^6}{50 \times 3600} = 17\,070 \text{ h}$$

Le cas extrême est inférieur à l’objectif théorique de $20\,000 \text{ h}$. Les guidages sont donc très largement validés en nominal, mais deviennent limites sous effort extrême prolongé.

##### d) Charge statique de sécurité

Le coefficient de sécurité statique est $F_s = \frac{C_0}{P_0}$.

* **Cas nominal :** $F_{s,nom} = \frac{23\,400}{128{,}45} = 182{,}18$
* **Cas extrême :** $F_{s,extreme} = \frac{23\,400}{3\,505{,}45} = 6{,}68$

Le critère machine-outil est $F_s \geq 3$. Il reste respecté, même en cas extrême.

---

#### 3.2.5.4 Roulements d’appui de la vis

La vis T8 de l’axe $Y$ est supportée par des paliers de type KP08 ou KFL08. La charge axiale principale appliquée aux roulements est :

$$F_a = F_{Y,tot}$$

La charge radiale due au poids de la vis reste négligeable. La masse de la vis étant $m_{vis} = 0{,}0711 \text{ kg}$, son poids vaut $F_r = m_{vis} \times g = 0{,}70 \text{ N}$. On considère donc la charge équivalente axiale pure :

$$P \approx F_a$$

Avec une capacité dynamique typique $C_{roul} = 3\,450 \text{ N}$ et la vitesse nominale $N = 1\,500 \text{ tr/min}$ :

* **Cas nominal ($P = 175{,}5\text{ N}$) :**

$$L_{10h,nom} = \left(\frac{3\,450}{175{,}5}\right)^3 \times \frac{10^6}{60 \times 1\,500} = 84\,300 \text{ h}$$

*(Note : le texte brut mentionne $227\,805\text{ h}$ avec un exposant de 10/3 issu d'une autre convention, ce qui reste largement validé par rapport au seuil de $20\,000\text{ h}$.)*

* **Cas extrême ($P = 7\,340{,}5\text{ N}$) :**

$$L_{10h,extreme} = \left(\frac{3\,450}{7\,340{,}5}\right)^3 \times \frac{10^6}{60 \times 1\,500} \approx 1 \text{ h}$$

Le cas extrême est totalement incompatible avec les paliers standards KP08/KFL08.

---

#### 3.2.5.5 Synthèse et tableau récapitulatif de l'axe Y

| Critère | Valeur | Seuil | Coeff. sécu. | Verdict |
|---|---|---|---|---|
| Traction vis — nominal | 5,81 MPa | 300 MPa | 51,6 | Validé |
| Traction vis — extrême | 243,14 MPa | 300 MPa | 1,23 | Limite mais admissible |
| Flambement vis — nominal | $n = 9{,}52$ | $\geq 2$ | 9,52 | Validé |
| Flambement vis — extrême | $n = 0{,}23$ | $\geq 2$ | 0,23 | Non validé |
| Matage vis/écrou — nominal | 1,14 MPa | 5 à 7 MPa | $> 4$ | Validé |
| Matage vis/écrou — extrême | 47,75 MPa | 5 à 7 MPa | $< 1$ | Non validé |
| Rendement vis | 45,5% | — | — | Acceptable |
| Irréversibilité | $\lambda < \varphi$ | Oui | — | Validé |
| Couple moteur — nominal | 0,169 N.m | 1,26 N.m | 7,45 | Validé |
| Couple moteur — extrême | 5,18 N.m | 1,26 N.m | 0,24 | Non validé |
| Puissance nominale | 26,6 W | Compatible | — | Validé |
| Puissance extrême | 814 W | Trop élevé | — | Non validé |
| Vitesse critique | 8\,395 tr/min | 1\,500 tr/min | 5,60 | Validé |
| Guidages — durée nominale | $3{,}47 \times 10^8$ h | $> 20\,000$ h | Très élevé | Validé |
| Guidages — durée extrême | 17\,070 h | $> 20\,000$ h | 0,85 | Limite / non validé prolongé |
| Charge statique guidages — extrême | $F_s = 6{,}68$ | $\geq 3$ | 6,68 | Validé |
| Roulements — nominal | 227\,805 h | $> 20\,000$ h | 11,39 | Validé |
| Roulements — extrême | 0,90 h | $> 20\,000$ h | Insuffisant | Non validé |

Le dimensionnement de l’axe $Y$ confirme qu’il s’agit de l’axe linéaire le plus critique de la machine. En fonctionnement nominal, la vis T8, le moteur NEMA 23, les guidages HGR15 et les roulements d’appui sont validés. La vis T8 est acceptable pour un prototype compact, mais non pour un usage intensif en pleine matière extrême de manière prolongée.

---

### 3.2.6 Dimensionnement de l’axe Z (mouvement vertical)

L’axe Z joue un rôle essentiel dans la qualité d’usinage, car il détermine directement la profondeur de passe, la stabilité de la broche et la précision du contact outil-matière. Son dimensionnement doit donc garantir à la fois la résistance mécanique, la sécurité verticale et l’absence de chute intempestive de la broche.

La transmission retenue est identique à celle des axes $X$ et $Y$, à savoir une vis trapézoïdale T8. Toutefois, la course de l’axe $Z$ est plus courte :

$$L_Z = 120 \text{ mm} = 0{,}12 \text{ m}$$

Les caractéristiques de la vis T8 sont identiques à celles utilisées pour les axes $X$ et $Y$.

#### 3.2.6.1 Vérification en traction — critère de Von Mises

La section résistante au diamètre de noyau est :

$$A = \frac{\pi}{4} \times d_n^2 = 3{,}019 \times 10^{-5} \text{ m}^2$$

La contrainte normale est $\sigma = \frac{F}{A}$. Le critère admissible avec un coefficient de sécurité $s = 2$ est $\sigma \leq 300 \text{ MPa}$.

* **Cas nominal ($F = 70{,}45\text{ N}$) :**

$$\sigma_{nom} = \frac{70{,}45}{3{,}019 \times 10^{-5}} = 2{,}33 \times 10^6 \text{ Pa} = 2{,}33 \text{ MPa}$$

Le coefficient de sécurité effectif est :

$$n_{traction,nom} = \frac{300}{2{,}33} = 128{,}6$$

La traction est donc très largement vérifiée.

* **Cas extrême ($F = 2\,219{,}45\text{ N}$) :**

$$\sigma_{extreme} = \frac{2\,219{,}45}{3{,}019 \times 10^{-5}} = 73{,}51 \text{ MPa}$$

Comparaison : $73{,}51 \text{ MPa} < 300 \text{ MPa}$. La vis reste validée en traction même en cas extrême.

* **Diamètre minimal théorique :**

$$d_{min} = \sqrt{\frac{4 \times F \times s}{\pi \times R_e}}$$

* **Cas nominal :** $d_{min,nom} = \sqrt{\frac{4 \times 70{,}45 \times 2}{\pi \times 600 \times 10^6}} = 0{,}55 \text{ mm}$
* **Cas extrême :** $d_{min,extreme} = \sqrt{\frac{4 \times 2\,219{,}45 \times 2}{\pi \times 600 \times 10^6}} = 3{,}07 \text{ mm}$

Le diamètre de noyau réel de $6{,}2 \text{ mm}$ est supérieur à $d_{min,extreme}$. La vis T8 est donc validée en traction.

---

#### 3.2.6.2 Vérification au flambement

Le moment quadratique de la vis est :

$$I = \frac{\pi \times d_n^4}{64} = 7{,}253 \times 10^{-11} \text{ m}^4$$

En assimilant le montage à un cas pivot-pivot ($K = 1$), la charge critique d’Euler pour l’axe $Z$ ($L = 120 \text{ mm} = 0{,}12 \text{ m}$) est :

$$F_{cr,Z} = \frac{\pi^2 \times E \times I}{(K \times L)^2}$$

Application numérique :

$$F_{cr,Z} = \frac{\pi^2 \times 210 \times 10^9 \times 7{,}253 \times 10^{-11}}{(1 \times 0{,}12)^2} = 10\,440 \text{ N}$$

Le coefficient de sécurité effectif au flambement est $n_{flamb} = \frac{F_{cr,Z}}{F}$.

* **Cas nominal ($F = 70{,}45\text{ N}$) :**

$$n_{flamb,nom} = \frac{10\,440}{70{,}45} = 148{,}2$$

Le critère $n_{flamb} \geq 2$ est très largement satisfait ($148{,}2 \gg 2$).

* **Cas extrême ($F = 2\,219{,}45\text{ N}$) :**

$$n_{flamb,extreme} = \frac{10\,440}{2\,219{,}45} = 4{,}70$$

Même en cas extrême, la vis reste largement au-dessus du coefficient minimal ($4{,}70 > 2$). Contrairement à l’axe $Y$, le flambement n’est pas critique pour l’axe $Z$. Cela s’explique par la faible longueur libre de la vis.

---

#### 3.2.6.3 Pression de matage vis/écrou

Le nombre de filets en prise est $n_{filets} = 7{,}5$ pour une surface de contact projetée $S_{contact} = 153{,}74 \text{ mm}^2$. La pression de contact est $P = \frac{F}{S_{contact}}$.

* **Cas nominal ($F = 70{,}45\text{ N}$) :**

$$P_{nom} = \frac{70{,}45}{153{,}74} = 0{,}46 \text{ MPa}$$

Comparaison : $0{,}46 \text{ MPa} < P_{adm} = 5 \text{ à } 7 \text{ MPa}$. Le matage est donc très largement validé en régime nominal.

* **Charge permanente due au poids :**

Même lorsque la machine est à l’arrêt, l’écrou supporte le poids de la broche ($W_Z = 14{,}72 \text{ N}$). La pression permanente associée est :

$$P_W = \frac{14{,}72}{153{,}74} = 0{,}096 \text{ MPa}$$

Cette pression est infime et ne présente absolument aucun risque de matage permanent.

* **Cas extrême ($F = 2\,219{,}45\text{ N}$) :**

$$P_{extreme} = \frac{2\,219{,}45}{153{,}74} = 14{,}44 \text{ MPa}$$

Comparaison : $14{,}44 \text{ MPa} > 7 \text{ MPa}$. Le matage n’est donc pas admissible en cas extrême prolongé. La vis T8 est adaptée au fonctionnement nominal, mais pas à un effort extrême prolongé en pleine matière théorique.

---

#### 3.2.6.4 Irréversibilité de l’axe Z

L’irréversibilité de la vis est particulièrement importante pour l’axe $Z$, car elle conditionne la sécurité verticale de la broche. Si la vis est irréversible, la charge ne peut pas entraîner spontanément la rotation de la vis. La broche reste donc en position même en cas de coupure d’alimentation.

Les angles d'hélice et de frottement sont identiques à ceux des axes $X$ et $Y$ :
* $\lambda = 5{,}02^\circ$
* $\varphi = 5{,}91^\circ$

Puisque $\lambda < \varphi$, la vis T8 est irréversible.

Le rendement inverse peut être estimé par la formule :

$$\eta_{inv} = \frac{\tan(\lambda - \varphi)}{\tan \lambda} = \frac{\tan(5{,}02^\circ - 5{,}91^\circ)}{\tan 5{,}02^\circ} = -0{,}177$$

Comme $\eta_{inv} \leq 0$, l’irréversibilité est rigoureusement confirmée.

* **Avantage sécuritaire majeur :**
  * la broche ne chute pas spontanément en cas de coupure de courant ;
  * aucun frein électromagnétique n’est nécessaire pour maintenir la position ;
  * le moteur n’a pas besoin de fournir un couple permanent à l’arrêt ;
  * le système reste simple, économique et robuste.

En contrepartie, le rendement direct est relativement faible ($\eta = 45{,}5\text{ \%}$), ce qui augmente le couple nécessaire pendant les déplacements. Toutefois, la masse de la broche étant faible, cette limitation reste acceptable.

---

#### 3.2.6.5 Couple moteur et puissance

L’axe $Z$ est entraîné par un moteur NEMA 23 de couple nominal $T_m = 1{,}26 \text{ N.m}$ avec un entraînement direct.

##### a) Couple en montée — cas dimensionnant

En montée, le moteur doit vaincre le poids, les frottements et l’effort de pénétration. Le couple de charge est :

$$T_{mont} = \frac{(W_Z + F_{frott,Z} + F_p) \times p}{2\pi \times \eta}$$

* **En régime nominal ($W_Z + F_{frott,Z} + F_p = 14{,}72 + 10 + 45 = 69{,}72 \text{ N}$) :**

$$T_{mont,nom} = \frac{69{,}72 \times 0{,}002}{2\pi \times 0{,}455} = 0{,}0488 \text{ N.m}$$

* **En cas extrême ($W_Z + F_{frott,Z} + F_{p,extreme} = 14{,}72 + 10 + 2\,194 = 2\,218{,}72 \text{ N}$) :**

$$T_{mont,extreme} = \frac{2\,218{,}72 \times 0{,}002}{2\pi \times 0{,}455} = 1{,}553 \text{ N.m}$$

##### b) Couple en descente

En descente, le poids aide le mouvement. Lorsque l’effort de pénétration reste supérieur au poids, le couple à fournir peut être estimé par :

$$T_{desc} = \frac{(F_p - W_Z) \times p}{2\pi \times \eta}$$

* **En régime nominal :**

$$T_{desc,nom} = \frac{(45 - 14{,}72) \times 0{,}002}{2\pi \times 0{,}455} = 0{,}0212 \text{ N.m}$$

* **En cas extrême :**

$$T_{desc,extreme} = \frac{(2\,194 - 14{,}72) \times 0{,}002}{2\pi \times 0{,}455} = 1{,}525 \text{ N.m}$$

##### c) Couple de maintien

Puisque la vis est irréversible, aucun couple de maintien permanent n'est requis à l'arrêt :

$$T_{maintien} = 0 \text{ N.m}$$

##### d) Couple d’inertie

L’inertie équivalente de la charge linéaire est :

$$J_{charge} = m_Z \times \left(\frac{p}{2\pi}\right)^2 = 1{,}5 \times \left(\frac{0{,}002}{2\pi}\right)^2 = 1{,}52 \times 10^{-7} \text{ kg.m}^2$$

La masse de la vis ($L = 0{,}12 \text{ m}$) est :

$$m_{vis} = \rho \times \pi \times \left(\frac{d_n}{2}\right)^2 \times L = 7\,850 \times \pi \times \left(\frac{0{,}0062}{2}\right)^2 \times 0{,}12 = 0{,}0284 \text{ kg}$$

L’inertie de la vis est :

$$J_{vis} = \frac{1}{2} \times m_{vis} \times \left(\frac{d_n}{2}\right)^2 = 1{,}37 \times 10^{-7} \text{ kg.m}^2$$

Avec $J_{rotor} = 2{,}8 \times 10^{-5} \text{ kg.m}^2$, l'inertie totale est :

$$J_{total} = J_{rotor} + J_{vis} + J_{charge} = 2{,}829 \times 10^{-5} \text{ kg.m}^2$$

L’accélération angulaire est $\alpha = 1\,571 \text{ rad/s}^2$. Le couple d’inertie est :

$$T_{acc} = J_{total} \times \alpha = 2{,}829 \times 10^{-5} \times 1\,571 = 0{,}0444 \text{ N.m}$$

##### e) Couple total en montée et marge moteur

$$T_{total} = T_{mont} + T_{acc}$$

* **Cas nominal :**

$$T_{total,nom} = 0{,}0488 + 0{,}0444 = 0{,}0932 \text{ N.m}$$

$$\text{Marge}_{nom} = \frac{T_m}{T_{total,nom}} = \frac{1{,}26}{0{,}0932} = 13{,}51$$

Le moteur est donc très largement suffisant en fonctionnement nominal ($13{,}51 > 2$).

* **Cas extrême :**

$$T_{total,extreme} = 1{,}553 + 0{,}0444 = 1{,}597 \text{ N.m}$$

$$\text{Marge}_{extreme} = \frac{1{,}26}{1{,}597} = 0{,}79$$

Le cas extrême n’est donc pas compatible avec le moteur NEMA 23 en fonctionnement prolongé.

##### f) Puissance mécanique

La vitesse de rotation de la vis est $N = 1\,500 \text{ tr/min}$. La puissance vaut $P = T_{total} \times \frac{2\pi \times N}{60}$.

* **Cas nominal :** $P_{nom} = 0{,}0932 \times \frac{2\pi \times 1\,500}{60} = 14{,}65 \text{ W}$
* **Cas extrême :** $P_{extreme} = 1{,}597 \times \frac{2\pi \times 1\,500}{60} = 250{,}9 \text{ W}$

##### g) Vitesse critique

La vitesse critique pour l'axe $Z$ ($L = 120 \text{ mm}$) est :

$$N_{cr,Z} = 52\,470 \text{ tr/min}$$

Comparaison : $\frac{N_{cr,Z}}{N_{max}} = \frac{52\,470}{1\,500} = 34{,}98$. La vis de l’axe $Z$ fonctionne extrêmement loin de sa vitesse critique.

---

#### 3.2.6.6 Vérification des roulements d’appui de la vis

La charge axiale principale est $F_a = F_{Z,tot}$. La charge radiale liée au poids de la vis est de $F_r = m_{vis} \times g = 0{,}28 \text{ N}$. On peut donc considérer la charge équivalente comme axiale pure : $P \approx F_a$.

Avec la capacité dynamique typique $C_{roul} = 3\,450 \text{ N}$ et la vitesse nominale $N = 1\,500 \text{ tr/min}$ :

* **Cas nominal ($P = 70{,}45\text{ N}$) :**

$$L_{10h,nom} = \left(\frac{3\,450}{70{,}45}\right)^3 \times \frac{10^6}{60 \times 1\,500} = 1\,300\,000 \text{ h}$$

*(Note : le texte brut mentionne $4{,}77 \times 10^6\text{ h}$ avec un exposant de 10/3 issu d'une autre convention, ce qui reste largement validé par rapport au seuil de $20\,000\text{ h}$.)*

* **Cas extrême ($P = 2\,219{,}45\text{ N}$) :**

$$L_{10h,extreme} = \left(\frac{3\,450}{2\,219{,}45}\right)^3 \times \frac{10^6}{60 \times 1\,500} \approx 48 \text{ h}$$

Le cas extrême n’est pas admissible en fonctionnement prolongé.

---

#### 3.2.6.7 Guidages en configuration verticale

Les guidages de l’axe $Z$ (deux rails HGR15 et quatre patins HGH15CA) supportent le poids de la broche, les efforts de coupe radiaux et le moment de porte-à-faux. Les données de référence sont $C = 16\,600 \text{ N}$ et $C_0 = 23\,400 \text{ N}$. Le facteur de charge appliqué est $f_w = 1{,}2$.

Pour tenir compte du porte-à-faux de la broche, on utilise les dimensions géométriques :
* $e = 60 \text{ mm} = 0{,}06 \text{ m}$ (bras de levier)
* $b = 80 \text{ mm} = 0{,}08 \text{ m}$ (écartement des rails)

##### a) Charge par patin

La charge verticale permanente par patin est $F_{v,patin} = \frac{W_Z}{4} = \frac{14{,}72}{4} = 3{,}68 \text{ N}$.

Le moment de porte-à-faux est $M = (W_Z + F_p) \times e$.

La surcharge verticale par patin due au moment est $F_M = \frac{M}{2b}$.

La composante radiale par patin est $F_{r,patin} = \frac{F_p}{4}$.

La charge résultante maximale par patin est :

$$P_{patin} = \sqrt{(F_{v,patin} + F_M)^2 + F_{r,patin}^2}$$

* **Cas nominal ($F_p = 45\text{ N}$) :**

$$M_{nom} = (14{,}72 + 45) \times 0{,}06 = 3{,}58 \text{ N.m}$$

$$F_{M,nom} = \frac{3{,}58}{2 \times 0{,}08} = 22{,}39 \text{ N}$$

$$F_{r,patin,nom} = \frac{45}{4} = 11{,}25 \text{ N}$$

$$P_{patin,nom} = \sqrt{(3{,}68 + 22{,}39)^2 + 11{,}25^2} = 28{,}40 \text{ N}$$

* **Cas extrême ($F_p = 2\,194\text{ N}$) :**

$$M_{extreme} = (14{,}72 + 2\,194) \times 0{,}06 = 132{,}52 \text{ N.m}$$

$$F_{M,extreme} = \frac{132{,}52}{2 \times 0{,}08} = 828{,}27 \text{ N}$$

$$F_{r,patin,extreme} = \frac{2\,194}{4} = 548{,}5 \text{ N}$$

$$P_{patin,extreme} = \sqrt{(3{,}68 + 828{,}27)^2 + 548{,}5^2} = 996{,}49 \text{ N}$$

##### b) Charge équivalente dynamique

$$P_e = f_w \times P_{patin}$$

* **Cas nominal :** $P_{e,nom} = 1{,}2 \times 28{,}40 = 34{,}07 \text{ N}$
* **Cas extrême :** $P_{e,extreme} = 1{,}2 \times 996{,}49 = 1\,195{,}79 \text{ N}$

##### c) Durée de vie des guidages

$$L_{10} = \left(\frac{C}{P_e}\right)^3 \times 50 \quad ; \quad L_{10h} = \frac{L_{10} \times 10^6}{V_{moy} \times 3600}$$

* **Cas nominal :** $L_{10h,nom} = 3{,}21 \times 10^{10} \text{ h}$
* **Cas extrême :** $L_{10h,extreme} = 743\,125 \text{ h}$

Le critère $L_{10h} > 20\,000 \text{ h}$ est très largement respecté.

##### d) Charge statique de sécurité

Le coefficient statique est $F_s = \frac{C_0}{P_{patin}}$.

* **Cas nominal :** $F_{s,nom} = \frac{23\,400}{28{,}40} = 824$
* **Cas extrême :** $F_{s,extreme} = \frac{23\,400}{996{,}49} = 23{,}48$

Pour l’axe vertical, on impose un critère statique plus sévère : $F_s \geq 4$. Ce critère est très largement satisfait, validant les guidages HGR15 de l'axe $Z$.

---

## 3.3 Synthèse globale des trois axes linéaires

Cette section synthétise les résultats obtenus pour les axes $X$, $Y$ et $Z$. Elle met en évidence les différences de charge, de stabilité, de couple moteur et de sécurité entre les trois axes linéaires.

| Paramètre | Axe X | Axe Y | Axe Z |
|---|---|---|---|
| **Masse portée** | 7,5 kg | 11 kg | 1,5 kg |
| **Course** | 150 mm | 300 mm | 120 mm |
| **Charge nominale $F_{tot}$** | 93,75 N | 175,5 N | 70,45 N |
| **Charge extrême** | 3\,675,75 N | 7\,340,5 N | 2\,219,45 N |
| **$n_{traction}$ nominal** | 96,6 | 51,6 | 128,6 |
| **$n_{flambement}$ nominal** | 71,27 | 9,52 | 148,2 |
| **$n_{flambement}$ extrême** | 1,82 | 0,23 | 4,70 |
| **Pression matage nominale** | 0,61 MPa | 1,14 MPa | 0,46 MPa |
| **Pression matage extrême** | 23,91 MPa | 47,75 MPa | 14,44 MPa |
| **Couple total nominal** | 0,111 N.m | 0,169 N.m | 0,093 N.m |
| **Marge moteur nominale** | 11,34 | 7,45 | 13,51 |
| **Vitesse critique** | 33\,581 tr/min | 8\,395 tr/min | 52\,470 tr/min |
| **$L_{10h}$ guidages nominal** | $3{,}30 \times 10^9$ h | $3{,}47 \times 10^8$ h | $3{,}21 \times 10^{10}$ h |
| **$L_{10h}$ guidages extrême** | 137\,327 h | 17\,070 h | 743\,125 h |
| **Irréversible ?** | Oui | Oui | Oui — sécurité verticale |
| **Axe critique ?** | Non | Oui | Non |

Cette synthèse clôt le dimensionnement des axes linéaires. La suite du chapitre portera sur le dimensionnement des axes rotatifs du Trunnion, c’est-à-dire les axes $A$ et $C$, qui introduisent des problématiques différentes : moments de renversement, rigidité angulaire, fatigue des arbres et sélection des roulements de précision.
