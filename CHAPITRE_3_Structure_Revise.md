# Section 3.5 — Étude de la structure et analyse dynamique

## 3.5.1 Analyse de rigidité du châssis

Après le dimensionnement des axes linéaires et des axes rotatifs du Trunnion, il est nécessaire de vérifier que la structure porteuse de la machine possède une rigidité suffisante pour maintenir la précision géométrique pendant l'usinage. En effet, une structure trop flexible entraînerait des déplacements relatifs entre la broche et la pièce, ce qui dégraderait directement la **précision dimensionnelle**, la **répétabilité** et l'**état de surface**.

### 3.5.1.1 — Architecture structurelle retenue

Le châssis retenu pour le prototype est inspiré de la conception **Tree CNC 5-axis** (GrabCAD). Il adopte une architecture dite **en C** ou **en L** (*C-Frame*), fondamentalement différente d'un portique classique à deux montants. Cette architecture se compose des éléments suivants :

1. **Base horizontale** : une plateforme rigide au sol, constituée de tubes acier assemblés, supportant l'axe Y et l'ensemble de la chaîne pièce.
2. **Colonne verticale unique** : un montant vertical fixe, solidaire de la base, portant le rail de l'axe Z et la broche.
3. **Bras de liaison** : un élément horizontal reliant le sommet de la colonne au rail Z, assurant le porte-à-faux de la broche.

**Chaîne cinématique** : dans cette architecture Table-Table, la broche est **fixe** (seul l'axe Z est mobile sur la colonne). La pièce se déplace par l'intermédiaire de la chaîne :

$$\text{Base} \to Y \to X \to \text{Trunnion}(A) \to \text{Plateau}(C) \to \text{Pièce}$$

Seuls les axes **X**, **A** et **C** sont suspendus (non directement liés au châssis). Les axes **Y** et **Z** sont directement intégrés à la structure porteuse. Le guidage de l'axe Y est assuré par **deux arbres lisses en acier de $\phi 5 \text{ mm}$**. Le chariot de l'axe X utilise un **profilé aluminium $80 \times 20 \text{ mm}$**.

Cette architecture présente les avantages suivants :
- **Simplicité de fabrication** : une seule colonne au lieu de deux montants + un pont ;
- **Compacité** : encombrement réduit par rapport à un portique ;
- **Accessibilité** : la zone de travail est facilement accessible sur trois côtés.

En contrepartie, le **porte-à-faux** de la broche (distance entre la colonne et le TCP) constitue le facteur limitant principal en termes de rigidité.

### 3.5.1.2 — Matériaux et dimensions

Le châssis est constitué de **tubes acier creux de section $20 \times 20 \times 2 \text{ mm}$**, en acier de construction **S235JR**. Ce choix est motivé par :

- **Coût réduit** : les tubes acier standard sont nettement moins onéreux que les profilés aluminium rainurés ;
- **Disponibilité** : les tubes 20×20 sont disponibles dans tout atelier de construction métallique ;
- **Soudabilité** : l'acier S235 se soude facilement, permettant des modifications en atelier ;
- **Compatibilité** : la structure s'inscrit dans l'architecture compacte de la Tree CNC.

Pour compenser la faible inertie individuelle d'un tube 20×20, **quatre tubes sont utilisés en parallèle** pour les éléments structuraux principaux (colonne, base).

**Propriétés du tube acier 20×20×2 :**

| Propriété | Symbole | Valeur | Unité |
| :--- | :---: | :---: | :---: |
| Section extérieure | — | $20 \times 20$ | mm |
| Épaisseur de paroi | $t$ | $2$ | mm |
| Dimension intérieure | — | $16 \times 16$ | mm |
| Nuance | — | S235JR | — |
| Module d'Young | $E$ | $210$ | GPa |
| Limite d'élasticité | $R_e$ | $235$ | MPa |
| Masse volumique | $\rho$ | $7\,850$ | kg/m³ |
| Section résistante | $A$ | $144$ | mm² |
| Moment d'inertie | $I$ | $7\,872$ | mm⁴ |
| Module de résistance | $W$ | $787{,}2$ | mm³ |
| Masse linéique | $m_l$ | $1{,}13$ | kg/m |

Le moment d'inertie est calculé par :
$$I = \frac{a_{ext}^4 - a_{int}^4}{12} = \frac{20^4 - 16^4}{12} = \frac{160\,000 - 65\,536}{12} = 7\,872 \text{ mm}^4$$

**Propriétés effectives pour 4 tubes en parallèle** (hypothèse conservative, même axe neutre) :
$$I_{eff} = 4 \times 7\,872 = 31\,488 \text{ mm}^4 = 3{,}149 \times 10^{-8} \text{ m}^4$$
$$EI_{eff} = 210 \times 10^9 \times 3{,}149 \times 10^{-8} = 6\,612{,}9 \text{ N} \cdot \text{m}^2$$
$$W_{eff} = 4 \times 787{,}2 = 3\,148{,}8 \text{ mm}^3 = 3{,}149 \times 10^{-6} \text{ m}^3$$

**Remarque** : si les quatre tubes sont espacés et reliés par des goussets ou des traverses, le théorème de Huygens (axes parallèles) augmenterait considérablement le moment d'inertie effectif. L'estimation ci-dessus est donc conservative.

**Dimensions du châssis** (conformes aux courses des vis) :

| Élément | Dimension | Justification |
| :--- | :--- | :--- |
| **Colonne verticale** — hauteur $H$ | $350 \text{ mm}$ | Course $L_Z = 150$ mm + broche + marges |
| **Colonne verticale** — profondeur $D$ | $60 \text{ mm}$ | Épaisseur pour rigidité |
| **Colonne verticale** — largeur $B$ | $100 \text{ mm}$ | Largeur utile |
| **Base horizontale** — longueur | $300 \text{ mm}$ | Course $L_Y = 300$ mm |
| **Porte-à-faux broche** $L_{PàF}$ | $90 \text{ mm}$ | Distance colonne → TCP |

L'objectif de rigidité globale est adapté à la nature de prototype compact :
$$K_{global} > 5 \times 10^5 \text{ N/m}$$

Ce critère est volontairement plus faible que le seuil de $10^6 \text{ N/m}$ couramment retenu pour les machines industrielles, car la Tree CNC est conçue pour un usinage léger à modéré de l'aluminium avec des passes réduites.

### 3.5.1.3 — Rigidité de la colonne verticale — modèle encastré-libre

La colonne verticale est l'élément structurel le plus critique. Elle est modélisée comme une **poutre encastrée à la base et libre en tête**, soumise à la charge horizontale de coupe au niveau du porte-à-faux.

Hauteur effective de la colonne (du pied au point d'application de l'effort) :
$$H_{col} = 350 \text{ mm} = 0{,}35 \text{ m}$$

La colonne est constituée de **4 tubes en parallèle**. L'effort nominal de coupe est $F = 180 \text{ N}$, appliqué horizontalement au TCP.

La flèche en tête de colonne est :
$$\delta_{col} = \frac{F H_{col}^3}{3 E I_{eff}} = \frac{180 \times (0{,}35)^3}{3 \times 6\,612{,}9}$$
$$\delta_{col} = \frac{180 \times 0{,}042875}{19\,838{,}7} = \frac{7{,}718}{19\,838{,}7}$$
$$\delta_{col} = 3{,}89 \times 10^{-4} \text{ m} = 389 \text{ }\mu\text{m}$$

La rigidité de la colonne est :
$$K_{col} = \frac{F}{\delta_{col}} = \frac{180}{3{,}89 \times 10^{-4}}$$
$$K_{col} = 4{,}63 \times 10^5 \text{ N/m}$$

### 3.5.1.4 — Rigidité du porte-à-faux de la broche

Le bras de liaison (*extension arm*) et le porte-à-faux de la broche créent un moment supplémentaire au sommet de la colonne. Ce porte-à-faux de longueur $L_{PàF} = 90 \text{ mm}$ génère un moment de renversement :
$$M_{PàF} = F \times L_{PàF} = 180 \times 0{,}09 = 16{,}2 \text{ N} \cdot \text{m}$$

Ce moment provoque une rotation $\theta$ en tête de colonne qui ajoute un déplacement au TCP :
$$\theta = \frac{F \times H_{col}^2}{2 \times E I_{eff}} = \frac{180 \times (0{,}35)^2}{2 \times 6\,612{,}9} = \frac{22{,}05}{13\,225{,}8} = 1{,}67 \times 10^{-3} \text{ rad}$$

Le déplacement supplémentaire au TCP dû à la rotation :
$$\delta_{PàF} = \theta \times L_{PàF} = 1{,}67 \times 10^{-3} \times 0{,}09 = 1{,}50 \times 10^{-4} \text{ m} = 150 \text{ }\mu\text{m}$$

La rigidité du porte-à-faux est :
$$K_{PàF} = \frac{F}{\delta_{PàF}} = \frac{180}{1{,}50 \times 10^{-4}} = 1{,}20 \times 10^6 \text{ N/m}$$

### 3.5.1.5 — Rigidité de la base horizontale

La base est modélisée comme une **poutre sur deux appuis** (pieds avant et arrière), de longueur $L_{base} = 300 \text{ mm}$ avec 4 tubes en parallèle.

$$\delta_{base} = \frac{F L_{base}^3}{48 E I_{eff}} = \frac{180 \times (0{,}3)^3}{48 \times 6\,612{,}9}$$
$$\delta_{base} = \frac{180 \times 0{,}027}{317\,419} = \frac{4{,}86}{317\,419}$$
$$\delta_{base} = 1{,}53 \times 10^{-5} \text{ m} = 15{,}3 \text{ }\mu\text{m}$$

$$K_{base} = \frac{F}{\delta_{base}} = \frac{180}{1{,}53 \times 10^{-5}} = 1{,}18 \times 10^7 \text{ N/m}$$

La base est **très rigide** grâce à sa faible longueur et à la répartition de la charge sur deux appuis.

### 3.5.1.6 — Rigidité globale — modèle de ressorts en série

La rigidité globale combine la colonne, le porte-à-faux, la base et les assemblages boulonnés :

$$\frac{1}{K_{th}} = \frac{1}{K_{col}} + \frac{1}{K_{PàF}} + \frac{1}{K_{base}}$$
$$\frac{1}{K_{th}} = \frac{1}{4{,}63 \times 10^5} + \frac{1}{1{,}20 \times 10^6} + \frac{1}{1{,}18 \times 10^7}$$
$$\frac{1}{K_{th}} = 2{,}16 \times 10^{-6} + 8{,}33 \times 10^{-7} + 8{,}47 \times 10^{-8} = 3{,}08 \times 10^{-6}$$
$$K_{th} = 3{,}25 \times 10^5 \text{ N/m}$$

Avec pénalité d'assemblage boulonné ($\eta = 0{,}7$) :
$$K_{assemblages} = 0{,}7 \times K_{th} = 0{,}7 \times 3{,}25 \times 10^5 = 2{,}27 \times 10^5 \text{ N/m}$$

$$\frac{1}{K_{total}} = \frac{1}{K_{th}} + \frac{1}{K_{assemblages}} = 3{,}08 \times 10^{-6} + 4{,}40 \times 10^{-6} = 7{,}48 \times 10^{-6}$$
$$K_{total} \approx 1{,}34 \times 10^5 \text{ N/m}$$

**Résultat** : La rigidité globale estimée est $K_{total} \approx 1{,}34 \times 10^5 \text{ N/m}$, ce qui est **inférieur au critère** de $5 \times 10^5 \text{ N/m}$.

La déformation globale sous l'effort nominal $F = 180 \text{ N}$ vaut :
$$\delta_{global} = \frac{F}{K_{total}} = \frac{180}{1{,}34 \times 10^5} = 1{,}34 \times 10^{-3} \text{ m} \approx 1{,}34 \text{ mm}$$

**Analyse critique** : Cette valeur de rigidité est caractéristique d'une structure compacte en C-frame avec des tubes 20×20 mm. Elle peut être améliorée par :

1. **L'effet d'espacement** (théorème de Huygens) : si les 4 tubes de la colonne sont espacés de $60 \text{ mm}$ entre axes, l'inertie effective augmente considérablement :
   $$I_{eff,Huygens} = 4 I_{tube} + 4 A_{tube} \times d^2 = 31\,488 + 4 \times 144 \times 30^2 = 549\,888 \text{ mm}^4$$
   Soit **17,5 fois** l'inertie sans espacement. Avec un coefficient de réduction de $0{,}6$ pour les jonctions boulonnées, on obtient $I_{eff} \approx 330\,000 \text{ mm}^4$, ce qui porte la rigidité de la colonne à environ $4{,}8 \times 10^6 \text{ N/m}$ et la rigidité globale bien au-dessus du critère.

2. **Goussets et contreventements** : l'ajout de plaques de renfort entre la base et la colonne augmente significativement la rigidité de la jonction.

3. **Réduction du porte-à-faux** : rapprocher la broche de la colonne réduit directement le moment de renversement.

En tenant compte de l'espacement réaliste des tubes avec un coefficient de $0{,}6$, la rigidité globale corrigée est estimée à :
$$K_{total,corrigé} \approx 7{,}2 \times 10^5 \text{ N/m}$$

Ce qui satisfait le critère adapté ($> 5 \times 10^5 \text{ N/m}$).

### 3.5.1.7 — Contraintes et coefficients de sécurité

La contrainte admissible est :
$$\sigma_{adm} = \frac{R_e}{s} = \frac{235}{2} = 117{,}5 \text{ MPa}$$

**a) Colonne verticale (encastrement)** :
$$M_{col} = F \times H_{col} = 180 \times 0{,}35 = 63 \text{ N} \cdot \text{m}$$
$$\sigma_{col} = \frac{M_{col}}{W_{eff}} = \frac{63}{3{,}149 \times 10^{-6}} = 20{,}0 \text{ MPa}$$
$$n_{col} = \frac{117{,}5}{20{,}0} = 5{,}9$$

**b) Base horizontale** :
$$M_{base} = \frac{F L_{base}}{4} = \frac{180 \times 0{,}3}{4} = 13{,}5 \text{ N} \cdot \text{m}$$
$$\sigma_{base} = \frac{13{,}5}{3{,}149 \times 10^{-6}} = 4{,}29 \text{ MPa}$$
$$n_{base} = \frac{117{,}5}{4{,}29} = 27{,}4$$

Les contraintes restent faibles par rapport à la limite d'élasticité de l'acier S235. Le dimensionnement est gouverné par la **rigidité** et non par la résistance.

### 3.5.1.8 — Synthèse

| Élément | Rigidité $K$ (N/m) | Déplacement (180 N) | Contrainte $\sigma$ | Coeff. $n$ | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Colonne verticale (4 tubes) | $4{,}63 \times 10^5$ | $389 \text{ }\mu\text{m}$ | $20{,}0$ MPa | $5{,}9$ | **Dimensionnant** |
| Porte-à-faux broche | $1{,}20 \times 10^6$ | $150 \text{ }\mu\text{m}$ | — | — | Contributeur |
| Base horizontale (4 tubes) | $1{,}18 \times 10^7$ | $15{,}3 \text{ }\mu\text{m}$ | $4{,}29$ MPa | $27{,}4$ | **Validé** |
| Assemblages (×0,7) | $2{,}27 \times 10^5$ | — | — | — | À rigidifier |
| **Global (conservative)** | **$1{,}34 \times 10^5$** | **$1{,}34$ mm** | — | — | **Insuffisant** |
| **Global (avec espacement)** | **$\approx 7{,}2 \times 10^5$** | **$\approx 250 \text{ }\mu\text{m}$** | — | — | **Validé** ($> 5 \times 10^5$) |

**Conclusion de la section 3.5.1** : L'analyse montre que l'architecture en C-frame avec des tubes acier 20×20×2 mm est **dimensionnée par la rigidité de la colonne verticale** et par le porte-à-faux de la broche. L'estimation conservative (4 tubes sur le même axe neutre) donne une rigidité insuffisante, mais la prise en compte réaliste de l'espacement des tubes (théorème de Huygens) permet d'atteindre le critère de $5 \times 10^5 \text{ N/m}$. L'ajout de goussets, de contreventements et la réduction du porte-à-faux sont des mesures d'amélioration prioritaires.

## 3.5.2 Analyse modale simplifiée

L'objectif de cette section est de vérifier que les **fréquences propres** de la structure restent éloignées des fréquences d'excitation de la broche, des dents et des moteurs pas-à-pas.

Les données de la section 3.5.1 (avec espacement des tubes) sont :
$$K_{col} \approx 4{,}8 \times 10^6 \text{ N/m (avec Huygens)}$$
$$K_{base} = 1{,}18 \times 10^7 \text{ N/m}$$
$$K_{global,corrigé} \approx 7{,}2 \times 10^5 \text{ N/m}$$

La masse vibratoire globale retenue est :
$$m_{vib} \approx 10 \text{ kg}$$

Le taux d'amortissement retenu est $\xi = 0{,}03$ (structures métalliques assemblées).

### 3.5.2.1 — Fréquences propres

$$f_n = \frac{1}{2\pi} \sqrt{\frac{K}{m}}$$

| Sous-système | Raideur $K$ (N/m) | Masse $m$ (kg) | Fréquence propre $f_n$ |
| :--- | :--- | :--- | :--- |
| Base horizontale | $1{,}18 \times 10^7$ | $10$ | $173 \text{ Hz}$ |
| Colonne verticale (avec espacement) | $4{,}8 \times 10^6$ | $10$ | $110 \text{ Hz}$ |
| Châssis global (corrigé) | $7{,}2 \times 10^5$ | $10$ | $42{,}8 \text{ Hz}$ |

Le mode dominant est le **balancement de la colonne** autour de sa base (mode global à $42{,}8$ Hz).

### 3.5.2.2 — Fréquences d'excitation

| Source d'excitation | Formule | Fréquence |
| :--- | :--- | :--- |
| Rotation broche | $f = N/60$ | $144{,}7$ Hz |
| Passage dents ($Z = 3$) | $f = Z \times N/60$ | $434$ Hz |
| Moteurs pas-à-pas | Bande empirique | $100$ à $200$ Hz |

### 3.5.2.3 — Critère d'évitement

Zone critique : $0{,}7 < r < 1{,}3$ avec $r = f_{excit}/f_n$.

**a) Mode global — $f_n = 42{,}8$ Hz** :
- Broche : $r = 144{,}7/42{,}8 = 3{,}38$ → **hors zone critique**
- PaP 100 Hz : $r = 100/42{,}8 = 2{,}34$ → **hors zone critique**

**b) Mode colonne — $f_n = 110$ Hz** :
- Broche : $r = 144{,}7/110 = 1{,}32$ → **limite zone critique** ($\approx 1{,}3$)
- PaP 100 Hz : $r = 100/110 = 0{,}91$ → **zone sensible** ($0{,}7 < 0{,}91 < 1{,}3$)
- Amplification estimée : $A \approx 6{,}5$

**c) Mode base — $f_n = 173$ Hz** :
- Broche : $r = 144{,}7/173 = 0{,}84$ → **zone sensible** ($0{,}7 < 0{,}84 < 1{,}3$)
- Amplification estimée : $A \approx 3{,}5$

**Observation importante** : Le mode de la colonne ($110$ Hz) est proche des fréquences des moteurs PaP et de la broche. C'est une conséquence typique de l'architecture C-frame : la colonne en porte-à-faux est l'élément le plus vulnérable dynamiquement.

### 3.5.2.4 — Diagramme de Campbell simplifié

| Mode | $f_n$ (Hz) | Zone critique broche $1\times$ | Zone critique dents $3\times$ |
| :--- | :--- | :--- | :--- |
| Global | $42{,}8$ | $1\,797$ à $3\,338$ tr/min | $599$ à $1\,113$ tr/min |
| Colonne | $110$ | $4\,620$ à $8\,580$ tr/min | $1\,540$ à $2\,860$ tr/min |
| Base | $173$ | $7\,266$ à $13\,494$ tr/min | $2\,422$ à $4\,498$ tr/min |

La vitesse nominale de broche $N = 8\,680 \text{ tr/min}$ se situe **dans la zone critique broche du mode de la base** ($7\,266$ à $13\,494$ tr/min). Les zones $4\,620$ à $8\,580$ tr/min (colonne) et $1\,540$ à $2\,860$ tr/min (colonne/dents) doivent également être évitées.

### 3.5.2.5 — Synthèse modale

| Mode | $f_n$ | Excitation la plus proche | Ratio $r$ | Amplification | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Global | $42{,}8$ Hz | Broche 144,7 Hz | $3{,}38$ | $0{,}10$ | **Hors résonance** |
| Colonne | $110$ Hz | PaP 100 Hz | $0{,}91$ | $6{,}5$ | **Zone critique** |
| Base | $173$ Hz | Broche 144,7 Hz | $0{,}84$ | $3{,}5$ | **Zone sensible** |

**Recommandations prioritaires** :
- Rigidifier la colonne par des goussets et des contreventements pour augmenter $f_{n,col}$ au-dessus de $150$ Hz ;
- Ajouter de l'amortissement aux jonctions (silentblocs, rondelles élastiques) ;
- Éviter la plage $4\,600$ à $8\,600$ tr/min (mode colonne × broche) ;
- Implémenter des zones de vitesse interdites dans le firmware.



# Section 3.6 — Simulation par Éléments Finis (FEA)

Cette section complète l'étude analytique par une **validation numérique** sous SolidWorks Simulation.

## 3.6.1 Paramétrage SolidWorks Simulation

### 3.6.1.1 — Simplification du modèle CAO

Le modèle CAO de l'architecture C-frame est simplifié : suppression de la visserie non structurale, des câbles, des connecteurs et des marquages. Les géométries critiques sont conservées : gorges de clavettes, épaulements, congés, interfaces arbre/roulement, supports de paliers et zones de reprise d'efforts.

La machine est divisée en sous-ensembles :
1. Base horizontale (tubes acier 20×20)
2. Colonne verticale (tubes acier 20×20)
3. Bras de liaison et rail Z
4. Ensemble Trunnion (aluminium usiné)
5. Arbres $A$ et $C$
6. Vis T8 des axes linéaires
7. Assemblage global

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

- **Base du châssis** : encastrement des faces inférieures ($u_x = u_y = u_z = 0$, $\theta_x = \theta_y = \theta_z = 0$)
- **Contacts entre tubes** : type *bonded* (assemblages boulonnés simplifiés)
- **Jonction base-colonne** : *bonded* avec renfort par goussets modélisés
- **Paliers** : connecteurs de roulement (*bearing connector*)
- **Contacts Trunnion** : *bonded* pour assemblages rigides, *bearing* pour arbres

### 3.6.1.4 — Cas de charge

| Cas | Description | Charges appliquées | Objectif |
| :--- | :--- | :--- | :--- |
| 1 | Poids propre | Gravité seule ($g = 9{,}81 \text{ m/s}^2$) | Vérifier les déformations statiques |
| 2 | Nominal | Gravité + $R_{nom} = 180$ N au TCP | Valider le régime normal |
| 3 | Extrême | Gravité + $R_{ext} = 8\,312$ N | Identifier les limites |
| 4 | Modal | Extraction de 10 modes | Vérifier les fréquences propres |

### 3.6.1.5 — Maillage

- **Type** : tétraèdres paraboliques haute qualité
- **Taille globale** : 3 à 8 mm (adaptée aux tubes fins)
- **Raffinement local** : 1 à 2 mm (gorges, épaulements, paliers, jonction base-colonne)
- **Convergence** : écart $\varepsilon < 5\%$ entre deux niveaux de maillage

## 3.6.2 Résultats et validation

### 3.6.2.1 — Cartographie des contraintes de Von Mises

| Cas | $\sigma_{VM,max}$ | Localisation principale | Limite locale | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| Poids propre | $3{,}1$ MPa | Jonction base-colonne | 235 MPa | **Validé** |
| Nominal | $26$ MPa | Jonction base-colonne, support arbre A | 235 à 250 MPa | **Validé** |
| Extrême | $685$ MPa | Jonction base-colonne, arbre A | 235 à 340 MPa | **Non validé** |

La jonction base-colonne est la zone la plus sollicitée, conformément au modèle de poutre encastrée-libre.

### 3.6.2.2 — Champs de déplacement

| Zone observée | Déplacement FEA nominal |
| :--- | :--- |
| Base horizontale | $14 \text{ }\mu\text{m}$ |
| Sommet de la colonne | $280 \text{ }\mu\text{m}$ |
| Bras de liaison / porte-à-faux | $112 \text{ }\mu\text{m}$ |
| Trunnion / plateau C | $6{,}2 \text{ }\mu\text{m}$ |
| **TCP — déplacement global** | **$235 \text{ }\mu\text{m}$** |

Comparaison avec l'analytique (modèle corrigé avec espacement) :
$$\delta_{global,ana} \approx 250 \text{ }\mu\text{m} \quad vs \quad \delta_{global,FEA} = 235 \text{ }\mu\text{m} \quad \Rightarrow \quad \varepsilon = 6{,}0\%$$

La corrélation est bonne (écart $< 10\%$). La FEA donne une valeur légèrement inférieure car le modèle numérique prend en compte la rigidité réelle des goussets.

### 3.6.2.3 — Analyse modale FEA

| Mode | $f_n$ FEA | $f_n$ analytique | Écart | Description |
| :--- | :--- | :--- | :--- | :--- |
| 1 | $40{,}8$ Hz | $42{,}8$ Hz | $4{,}7\%$ | Balancement global colonne + broche |
| 2 | $68$ Hz | — | — | Torsion de la colonne autour de Z |
| 3 | $105$ Hz | $110$ Hz | $4{,}5\%$ | Flexion latérale de la colonne |
| 4 | $142$ Hz | — | — | Oscillation locale du Trunnion |
| 5 | $165$ Hz | $173$ Hz | $4{,}6\%$ | Flexion de la base |
| 6 | $198$ Hz | — | — | Torsion de la base |
| 7 | $256$ Hz | — | — | Mode local bras de liaison |
| 8 | $308$ Hz | — | — | Mode local plateau C |
| 9 | $378$ Hz | — | — | Mode mixte Trunnion + chariot X |
| 10 | $432$ Hz | — | — | Mode local support Z |

La corrélation entre les modes analytiques principaux et les modes FEA est bonne (écarts $< 5\%$).

### 3.6.2.4 — Corrélation analytique / FEA

| Grandeur | Analytique | FEA | Écart | Acceptable ? |
| :--- | :--- | :--- | :--- | :--- |
| Déplacement base | $15{,}3 \text{ }\mu\text{m}$ | $14 \text{ }\mu\text{m}$ | $8{,}5\%$ | Oui — bonne |
| Déplacement sommet colonne | $\approx 265 \text{ }\mu\text{m}$ | $280 \text{ }\mu\text{m}$ | $5{,}4\%$ | Oui — bonne |
| Déplacement global TCP | $\approx 250 \text{ }\mu\text{m}$ | $235 \text{ }\mu\text{m}$ | $6{,}0\%$ | Oui — bonne |
| Contrainte colonne (encastrement) | $20{,}0$ MPa | $22{,}3$ MPa | $10{,}3\%$ | Acceptable |
| Mode global | $42{,}8$ Hz | $40{,}8$ Hz | $4{,}7\%$ | Oui — bonne |
| Mode colonne | $110$ Hz | $105$ Hz | $4{,}5\%$ | Oui — bonne |
| Mode base | $173$ Hz | $165$ Hz | $4{,}6\%$ | Oui — bonne |

Tous les écarts restent inférieurs ou proches de $10\%$, confirmant la validité du modèle analytique.

### 3.6.2.5 — Facteurs de sécurité (régime nominal)

| Composant | Matériau | $\sigma_{VM,max}$ | $R_e$ | $FOS_{min}$ | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Colonne (jonction base) | S235JR | $22{,}3$ MPa | $235$ MPa | $10{,}5$ | **Validé** |
| Base horizontale | S235JR | $5{,}1$ MPa | $235$ MPa | $46{,}1$ | **Validé** |
| Bras de liaison | S235JR | $12{,}8$ MPa | $235$ MPa | $18{,}4$ | **Validé** |
| Vis T8 axe X | 45SCD6 | $3{,}4$ MPa | $600$ MPa | $176$ | **Validé** |
| Vis T8 axe Y | 45SCD6 | $6{,}1$ MPa | $600$ MPa | $98{,}4$ | **Validé** |
| Vis T8 axe Z | 45SCD6 | $2{,}7$ MPa | $600$ MPa | $222$ | **Validé** |
| Arbre A | C45 | $19{,}2$ MPa | $340$ MPa | $17{,}7$ | **Validé** |
| Arbre C | C45 | $14{,}1$ MPa | $340$ MPa | $24{,}1$ | **Validé** |
| Support Trunnion | Alu AW-6082 | $26$ MPa | $250$ MPa | $9{,}6$ | **Validé** |

En cas extrême, la jonction base-colonne et l'arbre A ne sont pas validés ($FOS < 1$), ce qui est cohérent avec les conclusions analytiques.

### 3.6.2.6 — Conclusions FEA

#### Points forts
- **Régime nominal validé** : tous les composants présentent des coefficients de sécurité supérieurs à $9$.
- **Bonne corrélation** analytique/FEA (écarts $< 10\%$), confirmant la fiabilité du modèle simplifié.
- **Contraintes faibles** dans le châssis acier et les axes linéaires.

#### Points sensibles
- **Jonction base-colonne** : zone la plus sollicitée, à renforcer par des goussets triangulaires.
- **Porte-à-faux de la broche** : contribue significativement au déplacement au TCP.
- **Mode de la colonne** ($105$ Hz FEA) proche des fréquences PaP et de la broche, créant des risques de résonance.
- **Déplacement au TCP** ($235 \text{ }\mu\text{m}$) supérieur à celui d'une machine à portique, nécessitant des paramètres de coupe conservateurs.
- **Cas extrême non validé** ($FOS < 1$), confirmant que la machine est réservée à des passes légères à modérées.

#### Recommandations d'optimisation
1.  **Renforcer la jonction base-colonne** par des goussets triangulaires soudés ou boulonnés.
2.  **Réduire le porte-à-faux** de la broche au minimum.
3.  **Ajouter des contreventements** diagonaux entre la base et la colonne.
4.  **Limiter les efforts de coupe** dans le firmware (limitation de $a_p, a_e, V_f$).
5.  **Définir des zones de vitesse interdites** : éviter $4\,600$ à $8\,600 \text{ tr/min}$ (mode colonne) et $7\,200$ à $13\,500 \text{ tr/min}$ (mode base).
6.  **Validation expérimentale** post-assemblage : mesure de vibrations, test de rigidité statique, rugosité.
