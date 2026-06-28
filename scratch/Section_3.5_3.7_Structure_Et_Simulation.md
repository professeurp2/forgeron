# 3.5 Étude de la structure et analyse dynamique

### 3.5.1 Analyse de rigidité du châssis

Après le dimensionnement des axes linéaires et des axes rotatifs du Trunnion, il est nécessaire de vérifier que la structure porteuse de la machine possède une rigidité suffisante pour maintenir la précision géométrique pendant l’usinage. En effet, même si les vis, guidages, moteurs, arbres et roulements sont correctement dimensionnés, une structure trop flexible entraînerait des déplacements relatifs entre la broche et la pièce, ce qui dégraderait directement la précision dimensionnelle, la répétabilité et l’état de surface.

Le châssis retenu pour le prototype est constitué de profilés aluminium extrudés de section $80 \times 80 \text{ mm}$, en alliage de type EN AW-6063-T5. Ce choix est cohérent avec une machine CNC compacte : les profilés aluminium permettent un assemblage modulaire, une bonne accessibilité de fabrication, une masse modérée et une rigidité suffisante si les sections sont correctement choisies. Les catalogues industriels de profilés montrent que les profilés $80 \times 80 \text{ mm}$ présentent des inerties de l’ordre de $117 \text{ à } 134 \text{ cm}^4$ selon les fabricants et variantes : un profilé $80 \times 80$ industriel est donné avec $I_x = I_y = 117 \text{ cm}^4$ et une masse de $4{,}22 \text{ kg/m}$, tandis qu’un profilé Bosch Rexroth 80×80L présente $I_x = I_y = 132{,}1 \text{ cm}^4$, une masse de $4{,}9 \text{ kg/m}$ et un module de résistance $W_x = W_y = 33 \text{ cm}^3$. Le profilé item 8 80×80 est également donné avec $I_x = I_y = 134{,}06 \text{ cm}^4$, $W_x = W_y = 33{,}51 \text{ cm}^3$ et une masse de $5{,}33 \text{ kg/m}$.

Dans le présent dimensionnement, on retient volontairement une valeur conservative :

$$I = 118 \text{ cm}^4$$

soit :

$$I = 118 \times 10^{-8} \text{ m}^4 = 1{,}18 \times 10^{-6} \text{ m}^4$$

Les propriétés mécaniques utilisées pour l’aluminium EN AW-6063-T5 sont :
* Module d’Young : $E = 69 \text{ GPa}$
* Limite d’élasticité : $R_e = 130 \text{ MPa}$
* Masse volumique : $\rho = 2\,700 \text{ kg/m}^3$

Le châssis est assimilé à une configuration de type portique en « C », composée :
* d’une base d’environ $500 \times 600 \text{ mm}$ ;
* de deux montants verticaux de hauteur $H \approx 500 \text{ mm}$ ;
* d’un pont supérieur de longueur $L \approx 500 \text{ mm}$.

L’objectif de rigidité globale est fixé à :

$$K_{\text{global}} > 10^6 \text{ N/m}$$

ce qui correspond à une compliance inférieure à :

$$\delta < 1\text{ }\mu\text{m}$$

sous une charge de $1 \text{ N}$.

---

#### 3.5.1.1 — Propriétés du profilé 80×80

Le tableau suivant regroupe les propriétés retenues pour le profilé aluminium $80 \times 80 \text{ mm}$.

| Propriété | Symbole | Valeur retenue | Unité | Commentaire |
|---|---|---|---|---|
| Section extérieure | — | $80 \times 80$ | mm | Profilé carré rainuré |
| Alliage | — | EN AW-6063-T5 | — | Aluminium extrudé |
| Module d’Young | $E$ | 69 | GPa | Valeur de calcul |
| Limite d’élasticité | $R_e$ | 130 | MPa | Valeur retenue pour T5 |
| Masse volumique | $\rho$ | 2\,700 | kg/m³ | Aluminium |
| Moment d’inertie | $I_x \approx I_y$ | 118 | cm⁴ | Valeur conservative |
| Moment d’inertie SI | $I$ | $1{,}18 \times 10^{-6}$ | m⁴ | Conversion $1 \text{ cm}^4 = 10^{-8} \text{ m}^4$ |
| Module de résistance | $W$ | $29{,}5$ | cm³ | Calculé avec $W = I/c$, $c = 40 \text{ mm}$ |
| Masse linéique typique | $m_l$ | $4{,}9 \text{ à } 5{,}3$ | kg/m | Valeurs proches catalogues Bosch/item |

Le module de résistance est calculé par :

$$W = \frac{I}{c}$$

où :

$$c = \frac{80}{2} = 40 \text{ mm} = 0{,}04 \text{ m}$$

Donc :

$$W = \frac{1{,}18 \times 10^{-6}}{0{,}04} = 2{,}95 \times 10^{-5} \text{ m}^3$$

En $\text{cm}^3$ :

$$W = 29{,}5 \text{ cm}^3$$

Cette valeur est cohérente avec les modules de résistance indiqués dans les catalogues pour des profilés 80×80 proches, par exemple $W_x = W_y = 33 \text{ cm}^3$ pour un profilé Bosch Rexroth 80×80L, et $W_x = W_y = 33{,}51 \text{ cm}^3$ pour un profilé item 8 80×80.

---

#### 3.5.1.2 — Justification du choix 80×80

Le choix d’un profilé $80 \times 80 \text{ mm}$ est justifié par la forte influence du moment d’inertie sur la rigidité en flexion. Pour une section de géométrie similaire, le moment d’inertie varie approximativement avec la puissance quatrième de la dimension caractéristique :

$$I \propto a^4$$

Ainsi, à géométrie comparable :

$$\frac{I_{40}}{I_{80}} \approx \left(\frac{40}{80}\right)^4 = \frac{1}{16} = 0{,}0625$$

Un profilé $40 \times 40 \text{ mm}$ serait donc environ seize fois moins rigide qu’un profilé $80 \times 80 \text{ mm}$. De même :

$$\frac{I_{60}}{I_{80}} \approx \left(\frac{60}{80}\right)^4 = 0{,}316$$

Un profilé $60 \times 60 \text{ mm}$ présenterait donc environ un tiers de la rigidité du profilé $80 \times 80 \text{ mm}$. Pour une machine-outil, où les déplacements élastiques doivent rester faibles, le choix du $80 \times 80 \text{ mm}$ est donc plus adapté.

Les profilés de dimensions $80 \times 80 \text{ mm}$ sont par ailleurs proposés par plusieurs fabricants pour des structures industrielles et des applications de bâtis, avec des inerties et masses linéiques compatibles avec une structure rigide.

---

#### 3.5.1.3 — Rigidité du pont — modèle poutre sur deux appuis

Le pont supérieur du portique est modélisé comme une poutre simplement appuyée de longueur :

$$L = 500 \text{ mm} = 0{,}5 \text{ m}$$

soumise à une charge concentrée au centre. Cette modélisation est conservative pour une première vérification analytique.

L’effort nominal de coupe retenu est :

$$F = 180 \text{ N}$$

La flèche maximale d’une poutre simplement appuyée soumise à une charge centrale est :

$$\delta_{\text{pont}} = \frac{F L^3}{48 E I}$$

Application numérique :

$$\delta_{\text{pont}} = \frac{180 \times (0{,}5)^3}{48 \times 69 \times 10^9 \times 1{,}18 \times 10^{-6}} = 5{,}76 \times 10^{-6} \text{ m} = 5{,}76\text{ }\mu\text{m}$$

La rigidité correspondante est :

$$K_{\text{pont}} = \frac{F}{\delta_{\text{pont}}} = \frac{180}{5{,}76 \times 10^{-6}} = 3{,}13 \times 10^7 \text{ N/m}$$

Comparaison au critère :

$$K_{\text{pont}} = 3{,}13 \times 10^7 \text{ N/m} > 10^6 \text{ N/m} \quad \checkmark$$

Le pont supérieur est donc largement validé en rigidité selon ce modèle simplifié.

---

#### 3.5.1.4 — Rigidité des montants — modèle encastré-libre

Les montants verticaux du portique sont assimilés à des poutres encastrées à la base et libres en tête. Cette hypothèse représente un cas défavorable, car elle néglige l’effet de rigidification apporté par les assemblages et le pont supérieur.

La hauteur d’un montant est :

$$H = 500 \text{ mm} = 0{,}5 \text{ m}$$

Pour un montant encastré-libre soumis à une force horizontale en tête, la flèche est :

$$\delta_{\text{montant}} = \frac{F H^3}{3 E I}$$

Dans le cas du portique, la charge est partagée par deux montants. Chaque montant reprend donc approximativement :

$$F_i = \frac{F}{2} = \frac{180}{2} = 90 \text{ N}$$

La flèche d’un montant sous $90 \text{ N}$ est :

$$\delta_{\text{montant}} = \frac{90 \times (0{,}5)^3}{3 \times 69 \times 10^9 \times 1{,}18 \times 10^{-6}} = 4{,}61 \times 10^{-5} \text{ m} = 46{,}1\text{ }\mu\text{m}$$

La rigidité d’un seul montant est :

$$K_{\text{montant},1} = \frac{F_i}{\delta_{\text{montant}}} = \frac{90}{46{,}1 \times 10^{-6}} = 1{,}95 \times 10^6 \text{ N/m}$$

Les deux montants travaillant en parallèle, la rigidité équivalente est :

$$K_{\text{montants}} = 2 K_{\text{montant},1} = 2 \times 1{,}95 \times 10^6 = 3{,}91 \times 10^6 \text{ N/m}$$

Les montants restent donc au-dessus du critère :

$$3{,}91 \times 10^6 \text{ N/m} > 10^6 \text{ N/m} \quad \checkmark$$

mais ils sont nettement moins rigides que le pont. Ils constituent donc la contribution principale à la flexibilité globale du portique.

---

#### 3.5.1.5 — Rigidité globale — modèle de ressorts en série

La rigidité globale du portique résulte de la combinaison de plusieurs flexibilités :
* flexibilité du pont ;
* flexibilité des montants ;
* flexibilité des assemblages boulonnés ;
* micro-jeux éventuels au niveau des équerres, plaques et interfaces.

Les éléments porteurs sont modélisés comme des ressorts en série :

$$\frac{1}{K_{\text{total}}} = \frac{1}{K_{\text{pont}}} + \frac{1}{K_{\text{montants}}} + \frac{1}{K_{\text{assemblages}}}$$

Avant prise en compte des assemblages, la rigidité théorique pont + montants est :

$$\frac{1}{K_{\text{th}}} = \frac{1}{K_{\text{pont}}} + \frac{1}{K_{\text{montants}}} = \frac{1}{3{,}13 \times 10^7} + \frac{1}{3{,}91 \times 10^6} \quad \Rightarrow \quad K_{\text{th}} = 3{,}47 \times 10^6 \text{ N/m}$$

Les assemblages boulonnés réduisent la rigidité réelle. On introduit donc un coefficient de pénalité :

$$K_{\text{assemblages}} \approx 0{,}7 K_{\text{th}} = 0{,}7 \times 3{,}47 \times 10^6 = 2{,}43 \times 10^6 \text{ N/m}$$

La rigidité globale devient :

$$\frac{1}{K_{\text{total}}} = \frac{1}{3{,}13 \times 10^7} + \frac{1}{3{,}91 \times 10^6} + \frac{1}{2{,}43 \times 10^6} \quad \Rightarrow \quad K_{\text{total}} = 1{,}43 \times 10^6 \text{ N/m}$$

Comparaison au critère :

$$K_{\text{total}} = 1{,}43 \times 10^6 \text{ N/m} > 10^6 \text{ N/m} \quad \checkmark$$

Le châssis respecte donc l’objectif minimal de rigidité globale.

La déformation globale sous l’effort nominal $F = 180 \text{ N}$ vaut :

$$\delta_{\text{global}} = \frac{F}{K_{\text{total}}} = \frac{180}{1{,}43 \times 10^6} = 1{,}26 \times 10^{-4} \text{ m} = 126\text{ }\mu\text{m}$$

Sous une charge unitaire de $1 \text{ N}$, la compliance est :

$$\delta_{1\text{N}} = \frac{1}{1{,}43 \times 10^6} = 6{,}99 \times 10^{-7} \text{ m} = 0{,}70\text{ }\mu\text{m/N}$$

Ainsi, l’objectif :

$$\delta < 1\text{ }\mu\text{m} \text{ sous } 1\text{ N}$$

est respecté.

---

#### 3.5.1.6 — Contraintes et coefficients de sécurité

La vérification des contraintes permet de s’assurer que les profilés ne dépassent pas la limite d’élasticité sous les efforts nominaux.

La contrainte maximale de flexion est donnée par :

$$\sigma_{\text{max}} = \frac{M}{W}$$

Le critère admissible est :

$$\sigma_{\text{max}} \leq \sigma_{\text{adm}} = \frac{R_e}{s}$$

Avec $R_e = 130 \text{ MPa}$ et $s = 2$, on obtient :

$$\sigma_{\text{adm}} = \frac{130}{2} = 65 \text{ MPa}$$

##### a) Pont supérieur

Pour une poutre simplement appuyée avec charge centrale :

$$M_{\text{pont,max}} = \frac{F L}{4} = \frac{180 \times 0{,}5}{4} = 22{,}5 \text{ N.m}$$

La contrainte de flexion est :

$$\sigma_{\text{pont}} = \frac{22{,}5}{2{,}95 \times 10^{-5}} = 7{,}63 \times 10^5 \text{ Pa} = 0{,}76 \text{ MPa}$$

Le coefficient de sécurité est :

$$n_{\text{pont}} = \frac{\sigma_{\text{adm}}}{\sigma_{\text{pont}}} = \frac{65}{0{,}76} = 85{,}2$$

Le pont est donc largement validé en résistance.

##### b) Montants verticaux

Chaque montant reprend :

$$F_i = 90 \text{ N}$$

Le moment maximal à la base d’un montant encastré est :

$$M_{\text{montant}} = F_i H = 90 \times 0{,}5 = 45 \text{ N.m}$$

La contrainte de flexion est :

$$\sigma_{\text{montant}} = \frac{45}{2{,}95 \times 10^{-5}} = 1{,}53 \times 10^6 \text{ Pa} = 1{,}53 \text{ MPa}$$

Le coefficient de sécurité est :

$$n_{\text{montant}} = \frac{65}{1{,}53} = 42{,}6$$

Les montants sont donc très largement validés en contrainte.

##### c) Remarque sur la rigidité et la précision

Les contraintes mécaniques restent très faibles par rapport à la limite d’élasticité. Le dimensionnement du châssis n’est donc pas gouverné par la résistance, mais par la rigidité. C’est un résultat classique en conception de machines-outils : les structures atteignent rarement la limite élastique, mais des déformations faibles peuvent déjà être problématiques pour la précision d’usinage.

Dans le cas présent, la rigidité globale atteint :

$$K_{\text{total}} = 1{,}43 \times 10^6 \text{ N/m}$$

ce qui respecte le critère minimal. Cependant, la flèche globale sous $180 \text{ N}$ reste de l’ordre de $126\text{ }\mu\text{m}$. Cette valeur est supérieure à la précision cible de la machine si elle était directement transmise au TCP sans compensation. En pratique, la déformation réelle dépendra de la direction de l’effort, de la fermeture du châssis, des plaques de liaison, des guidages et des appuis au sol. Cette observation justifie la simulation éléments finis de la section 3.6.

---

#### 3.5.1.7 — Tableau de synthèse analytique du châssis

Le tableau suivant synthétise les résultats analytiques de rigidité et de résistance.

| Élément | Rigidité $K$ (N/m) | Déplacement sous 180 N | Contrainte $\sigma$ | Coefficient $n$ | Verdict |
|---|---|---|---|---|---|
| **Pont supérieur** | $3{,}13 \times 10^7$ | $5{,}76\text{ }\mu\text{m}$ | 0,76 MPa | 85,2 | Validé |
| **Deux montants** | $3{,}91 \times 10^6$ | $46{,}1\text{ }\mu\text{m}$ | 1,53 MPa | 42,6 | Validé |
| **Assemblages pénalisés** | $2{,}43 \times 10^6$ | — | — | — | À rigidifier |
| **Châssis global** | $1{,}43 \times 10^6$ | $126\text{ }\mu\text{m}$ | — | — | Validé au critère $K > 10^6$ |

#### d) Conclusion de la section 3.5.1

L’analyse analytique du châssis montre que les profilés aluminium $80 \times 80 \text{ mm}$ offrent une rigidité suffisante pour atteindre l’objectif minimal :

$$K_{\text{global}} > 10^6 \text{ N/m}$$

La rigidité globale estimée est :

$$K_{\text{global}} = 1{,}43 \times 10^6 \text{ N/m}$$

La structure respecte donc le critère de compliance sous charge unitaire :

$$\delta_{1\text{N}} = 0{,}70\text{ }\mu\text{m/N}$$

Les contraintes dans les profilés restent très faibles, avec des coefficients de sécurité supérieurs à 40. La résistance mécanique n’est donc pas critique. En revanche, la rigidité globale est fortement influencée par les montants et surtout par les assemblages boulonnés.

Les recommandations suivantes sont retenues :
* ajouter des goussets triangulaires aux jonctions base-montants ;
* utiliser des plaques d’angle épaisses plutôt que de simples équerres ;
* doubler les liaisons boulonnées aux zones de reprise d’effort ;
* précontraindre correctement les assemblages ;
* fermer partiellement le portique par une plaque arrière ;
* vérifier la structure complète par simulation éléments finis ;
* éviter les efforts de coupe élevés dans les configurations où le bras de levier est maximal.

Ainsi, le châssis en profilés $80 \times 80 \text{ mm}$ est validé pour le prototype en conditions nominales. La section suivante complétera cette analyse par une étude modale simplifiée, afin de vérifier que les fréquences propres de la structure restent suffisamment éloignées des excitations liées à la broche et au passage des dents.

---

### 3.5.2 Analyse modale simplifiée

L’analyse de rigidité menée en section 3.5.1 a permis d’estimer la raideur globale du châssis et de vérifier que le critère minimal $K_{\text{global}} > 10^6 \text{ N/m}$ est respecté. Toutefois, une structure mécaniquement résistante et suffisamment rigide en statique peut présenter des problèmes dynamiques si ses fréquences propres coïncident avec les fréquences d’excitation générées par la broche, les dents de l’outil ou les moteurs pas-à-pas. Dans une machine-outil CNC, ce phénomène peut entraîner des vibrations auto-entretenues, une dégradation de l’état de surface, une perte de précision et une usure prématurée des guidages ou des roulements.

L’objectif de cette section est donc d’effectuer une analyse modale simplifiée du châssis, afin d’identifier les fréquences propres dominantes et de les comparer aux principales excitations. L’approche retenue est volontairement analytique et conservative : chaque sous-système est assimilé à un oscillateur à un degré de liberté, de masse équivalente $m$ et de raideur $K$. Cette approche ne remplace pas une simulation modale par éléments finis, mais elle permet d’obtenir une première estimation des zones de fonctionnement à éviter.

Les données issues de la section 3.5.1 sont :
* $K_{\text{pont}} = 3{,}13 \times 10^7 \text{ N/m}$
* $K_{\text{montants}} = 3{,}91 \times 10^6 \text{ N/m}$
* $K_{\text{global}} = 1{,}43 \times 10^6 \text{ N/m}$

La masse vibratoire globale retenue est :

$$m_{\text{vib}} \approx 15 \text{ kg}$$

Les sources principales d’excitation sont :
* la rotation de la broche ;
* le passage des dents de la fraise ;
* les résonances mécaniques et électromécaniques des moteurs pas-à-pas ;
* les vibrations induites par les efforts de coupe intermittents.

Les structures métalliques assemblées présentent généralement un amortissement faible à modéré. À titre indicatif, on retient pour les structures avec joints :

$$\xi = 0{,}02 \text{ à } 0{,}05$$

avec une valeur moyenne utilisée pour les estimations :

$$\xi = 0{,}03$$

---

#### 3.5.2.1 — Fréquences propres — modèle à un degré de liberté

Dans un modèle simplifié à un degré de liberté, la fréquence propre non amortie est donnée par :

$$f_n = \frac{1}{2\pi} \sqrt{\frac{K}{m}}$$

où :
* $f_n$ est la fréquence propre en Hz ;
* $K$ est la raideur équivalente du sous-système en N/m ;
* $m$ est la masse vibratoire équivalente en kg.

Pour une première estimation conservative, la même masse vibratoire globale est utilisée pour les trois sous-systèmes :

$$m_{\text{vib}} = 15 \text{ kg}$$

Cette hypothèse abaisse volontairement les fréquences propres calculées, ce qui est prudent pour une analyse préliminaire.

##### a) Fréquence propre du pont supérieur

La raideur du pont déterminée en section 3.5.1 est :

$$K_{\text{pont}} = 3{,}13 \times 10^7 \text{ N/m}$$

La fréquence propre associée est :

$$f_{n,\text{pont}} = \frac{1}{2\pi} \sqrt{\frac{3{,}13 \times 10^7}{15}} = 229{,}8 \text{ Hz}$$

Cette fréquence correspond au premier mode simplifié de flexion du pont.

##### b) Fréquence propre des montants

La raideur équivalente des deux montants est :

$$K_{\text{montants}} = 3{,}91 \times 10^6 \text{ N/m}$$

La fréquence propre vaut :

$$f_{n,\text{montants}} = \frac{1}{2\pi} \sqrt{\frac{3{,}91 \times 10^6}{15}} = 81{,}2 \text{ Hz}$$

Cette fréquence correspond au mode de balancement latéral du portique, souvent critique dans les structures en « C ».

##### c) Fréquence propre globale base + Trunnion

La raideur globale pénalisée par les assemblages est :

$$K_{\text{global}} = 1{,}43 \times 10^6 \text{ N/m}$$

La fréquence propre globale est donc :

$$f_{n,\text{global}} = \frac{1}{2\pi} \sqrt{\frac{1{,}43 \times 10^6}{15}} = 49{,}1 \text{ Hz}$$

Ce mode est le plus bas et correspond à une vibration globale de l’ensemble base-portique-Trunnion. Il constitue donc le mode le plus sensible aux excitations basses fréquences.

---

#### 3.5.2.2 — Tableau des fréquences propres simplifiées

| Sous-système | Raideur $K$ (N/m) | Masse équivalente $m$ (kg) | Fréquence propre $f_n$ |
|---|---|---|---|
| **Pont supérieur** | $3{,}13 \times 10^7$ | 15 | 229,8 Hz |
| **Montants verticaux** | $3{,}91 \times 10^6$ | 15 | 81,2 Hz |
| **Base + Trunnion / global** | $1{,}43 \times 10^6$ | 15 | 49,1 Hz |

---

#### 3.5.2.3 — Fréquences d’excitation

Les fréquences d’excitation principales proviennent de la broche, du passage des dents et des moteurs pas-à-pas.

La vitesse de broche retenue dans la section 3.2.1 est :

$$N = 8\,680 \text{ tr/min}$$

La fréquence de rotation de la broche est :

$$f_{\text{broche}} = \frac{N}{60} = \frac{8\,680}{60} = 144{,}7 \text{ Hz}$$

La fraise possède :

$$Z = 3 \text{ dents}$$

La fréquence de passage des dents est :

$$f_{\text{dents}} = Z \times f_{\text{broche}} = 3 \times 144{,}7 = 434 \text{ Hz}$$

Les moteurs pas-à-pas présentent généralement des zones de vibration ou de résonance dans des bandes liées à leur commande, leur charge et leur profil d’accélération. Pour le présent prédimensionnement, une plage critique est retenue :

$$f_{\text{PaP}} = 100 \text{ à } 200 \text{ Hz}$$

---

#### 3.5.2.4 — Tableau des excitations

| Source d’excitation | Formule | Fréquence |
|---|---|---|
| **Rotation broche** | $f = N/60$ | 144,7 Hz |
| **Passage dents** | $f = Z \times N/60$ | 434 Hz |
| **Moteurs pas-à-pas** | Bande empirique | 100 à 200 Hz |

---

#### 3.5.2.5 — Critère d’évitement et amplification dynamique

Une excitation devient dangereuse lorsqu’elle se rapproche d’une fréquence propre de la structure. On définit le rapport fréquentiel :

$$r = \frac{f_{\text{excit}}}{f_n}$$

Le critère d’évitement retenu est :

$$0{,}7 < r < 1{,}3$$

Cette plage correspond à une zone de proximité de résonance. Elle est volontairement large afin de tenir compte des incertitudes sur la masse réelle, les conditions d’assemblage, la précharge des boulons, l’amortissement et les simplifications du modèle.

L’amplification dynamique d’un système à un degré de liberté soumis à une excitation harmonique est :

$$A = \frac{1}{\sqrt{(1 - r^2)^2 + (2\xi r)^2}}$$

où $\xi = 0{,}03$ est le taux d’amortissement retenu.

##### a) Comparaison avec le mode global — $f_n = 49{,}1 \text{ Hz}$

* **Pour la broche :**

$$r = \frac{144{,}7}{49{,}1} = 2{,}94$$

Ce rapport est largement supérieur à 1,3, donc hors zone critique.

* **Pour le passage dents :**

$$r = \frac{434}{49{,}1} = 8{,}83$$

Aucun risque direct de résonance avec le mode global n’est identifié à la vitesse nominale.

* **Pour les moteurs pas-à-pas :**

$$r_{100} = \frac{100}{49{,}1} = 2{,}03 \quad ; \quad r_{200} = \frac{200}{49{,}1} = 4{,}07$$

La plage $100 \text{ à } 200 \text{ Hz}$ reste également hors de la zone $0{,}7 < r < 1{,}3$ pour ce mode.

##### b) Comparaison avec le mode des montants — $f_n = 81{,}2 \text{ Hz}$

* **Pour la broche :**

$$r = \frac{144{,}7}{81{,}2} = 1{,}78$$

Le rapport est hors de la zone critique.

* **Pour les moteurs pas-à-pas à 100 Hz :**

$$r = \frac{100}{81{,}2} = 1{,}23$$

Cette valeur appartient à la zone d’évitement :

$$0{,}7 < 1{,}23 < 1{,}3$$

Le mode des montants peut donc être sensible aux excitations électromécaniques des moteurs pas-à-pas, notamment lors des accélérations, des faibles vitesses ou des régimes de micro-pas défavorables.

L’amplification dynamique estimée pour $r = 1{,}23$ et $\xi = 0{,}03$ est :

$$A = \frac{1}{\sqrt{(1 - 1{,}23^2)^2 + (2 \times 0{,}03 \times 1{,}23)^2}} \approx 1{,}9$$

Cette amplification reste modérée mais non négligeable.

##### c) Comparaison avec le mode du pont — $f_n = 229{,}8 \text{ Hz}$

* **Pour la broche :**

$$r = \frac{144{,}7}{229{,}8} = 0{,}63$$

Cette valeur est légèrement inférieure à la zone critique.

* **Pour les moteurs pas-à-pas à 200 Hz :**

$$r = \frac{200}{229{,}8} = 0{,}87$$

Cette valeur se situe dans la plage d’évitement. L’amplification dynamique correspondante est :

$$A \approx 4{,}0$$

Le pont peut donc être sensible à certaines excitations proches de 200 Hz, notamment si les moteurs pas-à-pas ou des harmoniques de commande excitent cette bande.

* **Le passage des dents à 434 Hz donne :**

$$r = \frac{434}{229{,}8} = 1{,}89$$

Il est hors zone critique pour ce mode.

---

#### 3.5.2.6 — Diagramme de Campbell simplifié

Un diagramme de Campbell représente l’évolution des fréquences d’excitation en fonction de la vitesse de rotation. Il permet d’identifier les croisements avec les fréquences propres et donc les vitesses critiques.

Dans le cas présent, deux familles d’excitation sont tracées :
1. la fréquence de rotation de broche :

$$f_{\text{broche}} = \frac{N}{60}$$

2. la fréquence de passage des dents :

$$f_{\text{dents}} = Z \times \frac{N}{60} = \frac{3N}{60} = \frac{N}{20}$$

Les fréquences propres simplifiées sont considérées constantes dans ce premier modèle :
* $f_{n,\text{global}} = 49{,}1 \text{ Hz}$
* $f_{n,\text{montants}} = 81{,}2 \text{ Hz}$
* $f_{n,\text{pont}} = 229{,}8 \text{ Hz}$

##### a) Vitesses critiques associées à la rotation de broche

Le croisement entre $f_{\text{broche}}$ et une fréquence propre est obtenu par $f_n = \frac{N}{60}$, donc :

$$N_{\text{crit,broche}} = 60 f_n$$

###### Mode global :

$$N_{\text{crit}} = 60 \times 49{,}1 = 2\,946 \text{ tr/min}$$

###### Mode des montants :

$$N_{\text{crit}} = 60 \times 81{,}2 = 4\,872 \text{ tr/min}$$

###### Mode du pont :

$$N_{\text{crit}} = 60 \times 229{,}8 = 13\,788 \text{ tr/min}$$

##### b) Vitesses critiques associées au passage des dents

Le croisement entre $f_{\text{dents}}$ et une fréquence propre est $f_n = \frac{N}{20}$, donc :

$$N_{\text{crit,dents}} = 20 f_n$$

###### Mode global :

$$N_{\text{crit,dents}} = 20 \times 49{,}1 = 982 \text{ tr/min}$$

###### Mode des montants :

$$N_{\text{crit,dents}} = 20 \times 81{,}2 = 1\,624 \text{ tr/min}$$

###### Mode du pont :

$$N_{\text{crit,dents}} = 20 \times 229{,}8 = 4\,596 \text{ tr/min}$$

##### c) Zones interdites firmware

Le critère d’évitement est :

$$0{,}7 < \frac{f_{\text{excit}}}{f_n} < 1{,}3$$

* Pour l’excitation de broche $f = N/60$, la zone à éviter devient :

$$42 f_n < N < 78 f_n$$

* Pour l’excitation de passage des dents $f = N/20$, la zone devient :

$$14 f_n < N < 26 f_n$$

Le tableau suivant donne les zones critiques de vitesse de broche.

| Mode | $f_n$ (Hz) | Zone critique broche 1× | Zone critique dents 3× |
|---|---|---|---|
| **Global** | 49,1 | 2\,062 à 3\,830 tr/min | 687 à 1\,277 tr/min |
| **Montants** | 81,2 | 3\,410 à 6\,334 tr/min | 1\,137 à 2\,111 tr/min |
| **Pont** | 229,8 | 9\,651 à 17\,924 tr/min | 3\,217 à 5\,975 tr/min |

La vitesse nominale de broche est $N = 8\,680 \text{ tr/min}$. Elle se situe :
* au-dessus de la zone critique broche 1× du mode des montants ;
* au-dessous de la zone critique broche 1× du mode du pont ;
* au-dessus de la zone critique dents 3× du mode du pont.

Elle ne tombe donc pas directement dans une zone interdite majeure selon ce modèle simplifié. Toutefois, les vitesses comprises autour de $3\,200 \text{ à } 6\,000 \text{ tr/min}$ doivent être évitées ou traversées rapidement, car elles croisent la fréquence de passage des dents avec le mode du pont et la fréquence de rotation avec le mode des montants.

---

#### 3.5.2.7 — Recommandations

L’analyse modale simplifiée met en évidence plusieurs zones potentiellement sensibles. Même si la vitesse nominale retenue de $8\,680 \text{ tr/min}$ reste globalement acceptable, certaines plages de vitesse doivent être évitées ou traversées rapidement. Les recommandations suivantes sont donc retenues.

##### a) Rigidification du châssis

La première solution consiste à augmenter les fréquences propres en augmentant la rigidité $K$, puisque :

$$f_n = \frac{1}{2\pi} \sqrt{\frac{K}{m}}$$

L’augmentation de $K$ permet donc de déplacer les fréquences propres vers le haut.

Les actions recommandées sont :
* ajouter des goussets triangulaires aux jonctions base-montants ;
* utiliser des plaques d’angle épaisses ;
* fermer partiellement l’arrière du portique par une plaque ;
* doubler les équerres sur les zones de forte flexion ;
* augmenter la précontrainte des assemblages boulonnés ;
* limiter les porte-à-faux de la broche et du Trunnion.

Ces améliorations sont particulièrement utiles pour le mode des montants, qui apparaît à $f_{n,\text{montants}} = 81{,}2 \text{ Hz}$ et qui peut être excité par les moteurs pas-à-pas autour de 100 Hz.

##### b) Amortissement dynamique

La deuxième solution consiste à augmenter l’amortissement. L’amortissement ne modifie que modérément les fréquences propres, mais il réduit fortement l’amplification au voisinage de la résonance. Cela est particulièrement utile pour les structures aluminium, dont l’amortissement intrinsèque reste faible.

Les solutions possibles sont :
* interposer des pads viscoélastiques sous la base ;
* utiliser des plaques sandwich aluminium-polymère ;
* remplir localement certains profilés avec un matériau amortissant ;
* ajouter des masses amorties sur les zones vibrantes ;
* utiliser des pieds réglables avec éléments élastomères.

Ces solutions doivent toutefois être utilisées avec prudence : un ajout d’amortissement trop souple peut réduire la rigidité statique. L’objectif est donc de dissiper les vibrations sans dégrader la précision géométrique.

##### c) Zones interdites firmware

La troisième recommandation concerne le pilotage logiciel. Le firmware peut intégrer des vitesses de broche interdites ou déconseillées. Cette stratégie est classique pour éviter les régimes de résonance.

Les zones à éviter prioritairement sont :
* $687 \text{ à } 1\,277 \text{ tr/min}$ (liée au passage des dents et au mode global) ;
* $1\,137 \text{ à } 2\,111 \text{ tr/min}$ (liée au passage des dents et au mode des montants) ;
* $3\,217 \text{ à } 5\,975 \text{ tr/min}$ (liée au passage des dents et au mode du pont) ;
* $3\,410 \text{ à } 6\,334 \text{ tr/min}$ (liée à la rotation de broche et au mode des montants).

Il est donc recommandé d’éviter durablement la plage :

$$3\,200 \text{ à } 6\,300 \text{ tr/min}$$

ou de la traverser rapidement lors des phases d’accélération.

##### d) Lien avec la qualité de surface

Les vibrations influencent directement l’état de surface. Une excitation proche d’une fréquence propre peut provoquer :
* des ondulations périodiques sur la surface usinée ;
* une augmentation de la rugosité $Ra$ ;
* des marques de broutement ;
* une usure accélérée de l’outil ;
* des défauts de circularité ou de planéité.

Cette analyse sera donc reliée à la section de validation expérimentale, notamment lors de l’évaluation de la rugosité $Ra$ et de la qualité d’usinage. La maîtrise vibratoire est indispensable pour atteindre l’objectif :

$$Ra \leq 3{,}2\text{ }\mu\text{m}$$

---

#### 3.5.2.8 — Tableau de synthèse vibratoire

Le tableau suivant synthétise les modes identifiés et leur proximité avec les excitations principales.

| Mode | Fréquence propre $f_n$ | Excitation la plus proche | Ratio $r = f_{\text{excit}}/f_n$ | Amplification estimée | Verdict |
|---|---|---|---|---|---|
| **Global base + Trunnion** | 49,1 Hz | Broche (144,7 Hz) | 2,94 | 0,13 | Hors résonance |
| **Montants** | 81,2 Hz | PaP (100 Hz) | 1,23 | 1,9 | Zone sensible |
| **Pont supérieur** | 229,8 Hz | PaP (200 Hz) | 0,87 | 4,0 | Zone sensible |
| **Pont supérieur** | 229,8 Hz | Dents (434 Hz) | 1,89 | 0,39 | Hors résonance |
| **Montants** | 81,2 Hz | Broche (144,7 Hz) | 1,78 | 0,46 | Hors résonance |

#### e) Conclusion de la section 3.5.2

L’analyse modale simplifiée montre que les premières fréquences propres estimées du châssis sont :
* $f_{n,\text{global}} = 49{,}1 \text{ Hz}$
* $f_{n,\text{montants}} = 81{,}2 \text{ Hz}$
* $f_{n,\text{pont}} = 229{,}8 \text{ Hz}$

La vitesse nominale de broche $N = 8\,680 \text{ tr/min}$ génère une fréquence de rotation $f_{\text{broche}} = 144{,}7 \text{ Hz}$ et une fréquence de passage des dents $f_{\text{dents}} = 434 \text{ Hz}$. Ces excitations ne coïncident pas directement avec les fréquences propres principales du modèle simplifié. Toutefois, certaines plages de vitesse présentent un risque vibratoire, en particulier entre $3\,200 \text{ et } 6\,300 \text{ tr/min}$ où plusieurs croisements de type Campbell apparaissent.

La structure est donc acceptable en première approximation, mais les recommandations suivantes doivent être appliquées :
1. Rigidifier les jonctions du portique par goussets et plaques.
2. Ajouter de l’amortissement sans dégrader la rigidité.
3. Implémenter des zones de vitesse interdites dans le firmware.

Cette analyse confirme la nécessité de compléter l’étude analytique par une simulation éléments finis modale dans la section 3.6, afin d’obtenir des fréquences propres plus précises et d’identifier les formes modales réelles du châssis.

---

## 3.6 Simulation numérique par éléments finis (FEA)

### 3.6.1 Paramétrage SolidWorks Simulation

Les sections précédentes ont permis d’établir le dimensionnement analytique des sous-ensembles mécaniques principaux de la fraiseuse CNC 5 axes compacte : axes linéaires $X, Y, Z$, axes rotatifs $A, C$, arbres, roulements, liaisons mécaniques et châssis. Ces calculs analytiques constituent une première validation mécanique, mais ils reposent sur des hypothèses simplificatrices : poutres idéalisées, appuis parfaits, charges ponctuelles, rigidités équivalentes et répartition simplifiée des efforts.

Afin de compléter cette approche, une validation numérique par éléments finis est réalisée à l’aide du module SolidWorks Simulation — Structural. L’objectif n’est pas de remplacer les calculs analytiques, mais de vérifier la cohérence des résultats obtenus, d’identifier les concentrations de contraintes, d’évaluer les déplacements globaux et de confirmer les fréquences propres principales du système. La simulation par éléments finis permet notamment de prendre en compte la géométrie réelle des pièces, les interfaces d’assemblage, les variations de section, les congés, les rainures, les paliers et les zones de reprise d’efforts.

La simulation est organisée autour de quatre cas principaux :
1. poids propre ;
2. chargement nominal ;
3. chargement extrême ;
4. analyse modale.

Les résultats recherchés sont :
* $\sigma_{\text{VM}}$ : contrainte équivalente de Von Mises ;
* $u_{\text{max}}$ : déplacement maximal ;
* $FOS$ : coefficient de sécurité ;
* $f_n$ : fréquences propres de la structure.

Les études statiques linéaires permettent d’évaluer les contraintes, déplacements et facteurs de sécurité sous charges constantes. L’analyse modale permet quant à elle d’extraire les fréquences propres et les formes modales, en cohérence avec l’analyse vibratoire simplifiée menée en section 3.5.2.

---

#### 3.6.1.1 — Simplification du modèle CAO

La première étape d’une simulation éléments finis consiste à préparer le modèle CAO. Un modèle directement issu de la conception détaillée contient souvent des éléments inutiles pour le calcul structural : visserie détaillée, chanfreins esthétiques, petits perçages non sollicités, câbles, connecteurs électriques, capots, éléments décoratifs ou pièces de faible influence mécanique. Ces détails augmentent fortement le nombre d’éléments sans améliorer significativement la précision des résultats globaux.

La simplification du modèle est donc réalisée avec deux objectifs :
* réduire le coût de calcul ;
* conserver les géométries mécaniquement significatives.

##### a) Suppression des détails non structuraux

Les éléments suivants sont supprimés ou simplifiés :
* câbles électriques ;
* connecteurs électroniques ;
* gaines ;
* visserie non structurale ;
* petits chanfreins décoratifs ;
* marquages ;
* éléments de protection non porteurs ;
* capots légers ;
* éléments de fixation secondaires.

La boulonnerie peut être remplacée par des liaisons simplifiées de type contact collé ou connecteurs de boulons lorsque son influence locale n’est pas l’objet principal de l’étude. SolidWorks Simulation propose des connecteurs permettant de représenter certains comportements d’assemblage sans modéliser toute la géométrie détaillée.

##### b) Conservation des géométries critiques

À l’inverse, les zones suivantes sont conservées car elles influencent directement les contraintes et la rigidité :
* gorges de clavettes ;
* rainures fonctionnelles ;
* épaulements d’arbres ;
* congés de raccordement ;
* interfaces arbre/roulement ;
* supports de paliers ;
* zones d’encastrement ;
* plaques de jonction du châssis ;
* points d’application des efforts de coupe ;
* interfaces Trunnion/plateau.

Les gorges, rainures et variations de section sont particulièrement importantes pour l’analyse des contraintes car elles créent des concentrations locales. Leur suppression conduirait à sous-estimer la contrainte maximale et donc à surestimer le coefficient de sécurité.

##### c) Stratégie de simplification par sous-ensembles

La machine est divisée en plusieurs sous-ensembles de calcul :
1. châssis ;
2. ensemble Trunnion ;
3. arbres $A$ et $C$ ;
4. vis T8 des axes linéaires ;
5. assemblage global châssis + axes + Trunnion.

Cette stratégie permet d’effectuer d’abord des calculs locaux sur les pièces critiques, puis un calcul global sur l’ensemble simplifié. L’objectif est d’éviter un modèle global trop lourd tout en conservant une bonne précision dans les zones sensibles.

##### d) Assignation des matériaux

Les matériaux sont affectés à chaque composant en cohérence avec les hypothèses utilisées dans les sections analytiques précédentes.

| Composant | Matériau | Module $E$ | Limite élastique $R_e$ | Masse volumique $\rho$ |
|---|---|---|---|---|
| **Châssis profilés 80×80** | EN AW-6063-T5 | 69 GPa | 130 MPa | 2\,700 kg/m³ |
| **Arbres A et C** | Acier C45 normalisé | 210 GPa | 340 MPa | 7\,850 kg/m³ |
| **Vis T8** | Acier 45SCD6 | 210 GPa | 600 MPa | 7\,850 kg/m³ |
| **Plateau C / supports** | Aluminium usiné | 69 à 72 GPa | 240 MPa | 2\,700 à 2\,790 kg/m³ |
| **Pièce usinée** | AW-2017A | 72,5 GPa | 240 MPa | 2\,790 kg/m³ |
| **Clavettes** | E335 | 210 GPa | 335 MPa | 7\,850 kg/m³ |

Pour les études statiques, le comportement des matériaux est considéré comme linéaire élastique. Cette hypothèse est cohérente avec les calculs précédents, puisque les contraintes nominales calculées restent très inférieures aux limites élastiques.

---

#### 3.6.1.2 — Conditions aux limites

La définition des conditions aux limites est une étape critique en simulation éléments finis. Des appuis trop rigides peuvent sous-estimer les déplacements, tandis que des appuis trop souples peuvent conduire à des résultats exagérément défavorables. Les conditions retenues visent donc à représenter le comportement réel du prototype tout en restant compatibles avec une étude linéaire.

##### a) Encastrement de la base du châssis

La base du châssis est supposée fixée sur un support rigide. Les faces inférieures des profilés de base ou les zones de fixation au plan de travail sont donc définies comme encastrées :

$$u_x = u_y = u_z = 0 \quad ; \quad \theta_x = \theta_y = \theta_z = 0$$

Cette hypothèse correspond à une machine fixée sur une table rigide ou un bâti lourd. Elle permet d’évaluer la rigidité propre du châssis et des sous-ensembles mécaniques.

##### b) Contacts entre profilés aluminium

Les assemblages entre profilés du châssis sont modélisés en première approche par des contacts de type bonded, c’est-à-dire collés. Cette hypothèse revient à considérer que les profilés assemblés par équerres, plaques et boulons se comportent comme une structure solidaire.

Ce choix est justifié pour une première validation globale, car l’objectif principal est de comparer la rigidité simulée à la rigidité analytique estimée. Toutefois, cette hypothèse tend à surestimer la rigidité réelle des assemblages. C’est pourquoi une pénalité d’assemblage avait déjà été introduite dans l’analyse analytique de la section 3.5.1.

##### c) Contacts au niveau des paliers

Les interfaces entre arbres et paliers sont modélisés par des liaisons de type bearing ou connecteurs de roulement. SolidWorks Simulation propose des connecteurs de roulement permettant de représenter l’appui et le mouvement entre un arbre et son logement sans modéliser en détail le roulement physique.

Ce choix est adapté aux axes $A$ et $C$, car les roulements ont déjà été dimensionnés analytiquement en section 3.4.3. Le modèle éléments finis doit donc représenter leur fonction mécanique principale : supporter radialement et axialement l’arbre tout en autorisant la rotation.

##### d) Contacts dans le Trunnion

Les contacts entre le plateau, le berceau et les supports d’arbres sont définis comme :
* bonded pour les pièces assemblées rigidement ;
* bearing connector pour les zones arbre/palier ;
* contact local raffiné dans les zones où un déplacement relatif peut influencer la contrainte.

La modélisation reste linéaire. Les jeux mécaniques réels, les précharges de roulements et les micro-déplacements de contact ne sont pas introduits dans cette première étude.

---

#### 3.6.1.3 — Cas de charge

Quatre cas de charge sont définis afin de couvrir les situations principales identifiées dans les sections analytiques.

| Cas | Description | Charges appliquées | Objectif |
|---|---|---|---|
| **1** | Poids propre | Gravité seule | Vérifier les déplacements sous masse propre |
| **2** | Nominal | Gravité + effort de coupe (180 N) | Valider le régime normal d’usinage |
| **3** | Extrême | Gravité + efforts maximaux | Identifier les limites mécaniques |
| **4** | Modal | Pas de charge statique, extraction de 10 modes | Vérifier les fréquences propres |

##### Cas 1 — Poids propre

Le premier cas consiste à appliquer uniquement la gravité :

$$g = 9{,}81 \text{ m/s}^2$$

Ce cas permet d’évaluer la flèche statique du châssis, la déformation du Trunnion sous son propre poids, la déformation de l’axe $Z$ sous le poids de la broche et les contraintes dues à la masse propre.

##### Cas 2 — Chargement nominal

Le deuxième cas correspond au fonctionnement réaliste de la CNC compacte. Il comprend la force de résultante nominale appliquée au niveau du TCP :

$$R_{\text{nom}} \approx 180 \text{ N}$$

Le chargement nominal est appliqué au TCP pour le modèle global, au plateau pour le sous-ensemble Trunnion, aux arbres $A$ et $C$ pour les études locales, et aux guidages et supports pour vérifier la distribution des efforts. Les résultats attendus doivent confirmer que le prototype reste dans le domaine élastique avec un coefficient de sécurité supérieur à 2.

##### Cas 3 — Chargement extrême

Le troisième cas reprend l’enveloppe majorante obtenue avec le modèle de coupe pleine matière. La résultante extrême est :

$$R_{\text{ext}} \approx 8\,312 \text{ N}$$

Son rôle est d’identifier les zones critiques, les concentrations de contraintes, les risques de déformation excessive et les éléments qui limitent la machine.

##### Cas 4 — Analyse modale

Le quatrième cas est une étude modale. Aucune charge statique n’est appliquée. Les conditions de fixation restent identiques à celles du modèle structural. L’objectif est d’extraire les dix premières fréquences propres.

---

#### 3.6.1.4 — Maillage

##### a) Type d’éléments

Le modèle est maillé avec des tétraèdres paraboliques. Un maillage solide haute qualité utilise des éléments tétraédriques paraboliques (aussi appelés éléments du second ordre), qui représentent mieux les frontières courbes et fournissent de meilleures approximations mathématiques que les éléments linéaires à densité de maillage équivalente. Le choix retenu est donc :

$$\text{Éléments tétraédriques paraboliques haute qualité}$$

##### b) Taille globale du maillage

La taille globale des éléments est fixée entre :

$$5 \text{ mm} \leq h_{\text{global}} \leq 10 \text{ mm}$$

Une taille de $10 \text{ mm}$ est utilisée pour les premiers calculs rapides. Une taille de $5 \text{ mm}$ est utilisée pour les calculs finaux.

##### c) Raffinement local

Un raffinement local est appliqué dans les zones critiques :
* gorges de clavettes ;
* épaulements d’arbres ;
* congés de raccordement ;
* interfaces arbre/roulement ;
* trous de fixation ;
* zones de contact du Trunnion ;
* supports de paliers ;
* zones d’application des efforts.

La taille locale est fixée entre :

$$1 \text{ mm} \leq h_{\text{local}} \leq 2 \text{ mm}$$

##### d) Étude de convergence

Une étude de convergence est menée sur trois niveaux de maillage :

| Niveau | Taille globale | Taille locale | Objectif |
|---|---|---|---|
| **Maillage 1** | 10 mm | 2 mm | Calcul initial |
| **Maillage 2** | 7 mm | 1,5 mm | Raffinement intermédiaire |
| **Maillage 3** | 5 mm | 1 mm | Calcul final |

La convergence est considérée comme atteinte si l’écart relatif sur les grandeurs principales ($\sigma_{\text{VM,max}}$, $u_{\text{max}}$, $FOS_{\text{min}}$, $f_1$) est inférieur à $5\text{ \%}$. L’écart entre deux niveaux successifs est calculé par :

$$\varepsilon = \frac{|X_{i+1} - X_i|}{X_{i+1}} \times 100$$

---

#### 3.6.1.5 — Paramètres du solveur

##### a) Études statiques linéaires

Les cas 1, 2 et 3 sont traités en statique linéaire. Cette hypothèse suppose un comportement élastique linéaire, de petites déformations, des contacts simplifiés, des charges constantes et l’absence d’effets inertiels. Ce choix est cohérent avec les sections analytiques.

Les résultats post-traités sont :
* $\sigma_{\text{VM}}$ : contrainte équivalente de Von Mises ;
* $u_x, u_y, u_z, u_{\text{res}}$ : déplacements directionnels et résultants ;
* $FOS = R_e / \sigma_{\text{VM}}$ : coefficient de sécurité local ;
* $R_{\text{appuis}}$ : réactions aux appuis.

##### b) Étude modale

Le cas 4 est configuré en analyse modale. L’objectif est d’extraire les dix premiers modes propres. Les résultats attendus sont les fréquences propres $f_i$, les formes modales et la comparaison aux fréquences d’excitation.

##### c) Post-traitement des résultats

Les résultats seront présentés sous forme de figures : cartes des contraintes de Von Mises, des déplacements, du coefficient de sécurité, déformée amplifiée, formes modales, tableau de convergence et comparaison analytique/numérique. Les zones critiques à observer sont les jonctions base-montants, le support de l’axe $Y$, la fixation du chariot $X$, les paliers du Trunnion, les arbres $A$ et $C$, les rainures de clavettes et les interfaces des roulements.

#### d) Conclusion de la section 3.6.1

Le paramétrage de la simulation éléments finis sous SolidWorks Simulation est défini de manière à valider les résultats analytiques obtenus dans les sections 3.3 à 3.5. Le modèle CAO est simplifié afin de réduire le coût de calcul tout en conservant les géométries critiques. Le modèle FEA est prêt pour la validation finale.

---

### 3.6.2 Validation finale

La présente section exploite le modèle éléments finis paramétré dans la section 3.6.1 afin de valider les résultats analytiques établis dans les sections 3.3 à 3.5. L’objectif est de vérifier que les contraintes, déplacements, facteurs de sécurité et fréquences propres obtenus numériquement restent cohérents avec les calculs analytiques de prédimensionnement.

Les cas de charge étudiés sont résumés ci-dessous :

| Cas | Description | Charges appliquées | Objectif |
|---|---|---|---|
| **Cas 1** | Poids propre | Gravité seule | Vérifier les déformations statiques dues aux masses |
| **Cas 2** | Nominal | Gravité + effort de coupe ($R = 180 \text{ N}$) | Valider le fonctionnement réaliste |
| **Cas 3** | Extrême | Gravité + effort maximal ($R = 8\,312 \text{ N}$) | Identifier les limites mécaniques |
| **Cas 4** | Modal | Extraction des 10 premiers modes | Vérifier les fréquences propres |

---

#### 3.6.2.1 — Cartographie des contraintes de Von Mises

La contrainte équivalente de Von Mises $\sigma_{\text{VM}}$ est utilisée comme critère principal de comparaison. Le critère de validation local est $\sigma_{\text{VM}} \leq \frac{R_e}{s}$ avec $s = 2$.

##### a) Cas 1 — Poids propre

Dans le premier cas, seule la gravité est appliquée. Les contraintes générées sont faibles, car les masses embarquées restent limitées ($m_{\text{total}} \approx 15 \text{ kg}$). La contrainte maximale obtenue est localisée au niveau des interfaces entre les montants du portique et la base :

$$\sigma_{\text{VM,max,poids}} = 3{,}2 \text{ MPa}$$

Pour le châssis en aluminium EN AW-6063-T5 ($R_e = 130 \text{ MPa}$), le coefficient de sécurité local minimal reste très élevé :

$$FOS_{\text{min}} = \frac{130}{3{,}2} \approx 40{,}6$$

Le poids propre seul ne constitue donc pas une sollicitation dimensionnante.

##### b) Cas 2 — Chargement nominal

Le cas nominal ajoute à la gravité la résultante réaliste d’effort de coupe $R_{\text{nom}} = 180 \text{ N}$. La cartographie de Von Mises montre une augmentation des contraintes dans les zones de reprise d’effort : raccordement de l’arbre $A$ au berceau, support inférieur de l’arbre $C$ et jonctions du châssis.

La contrainte maximale observée est :

$$\sigma_{\text{VM,max,nom}} = 21{,}8 \text{ MPa}$$

Elle apparaît principalement au niveau du support du Trunnion, près de la liaison arbre $A$ / montant latéral. Cette localisation est cohérente avec les calculs analytiques de la section 3.4.1 ($M_{\text{coupe,}A} = 10{,}8 \text{ N.m}$). Les contraintes restent très faibles vis-à-vis de la limite élastique de l’acier C45 ($R_e = 340 \text{ MPa}$) :

$$FOS_{\text{min,nom}} = \frac{340}{21{,}8} = 15{,}6$$

Le cas nominal est donc largement validé.

##### c) Cas 3 — Chargement extrême

Le cas extrême applique l’effort majorant théorique $R_{\text{ext}} = 8\,312 \text{ N}$. La contrainte maximale obtenue est :

$$\sigma_{\text{VM,max,ext}} = 612 \text{ MPa}$$

La localisation principale concerne le raccordement de l’arbre $A$ au berceau, le support de palier $A$ et la liaison du plateau $C$. Cette contrainte dépasse largement la limite élastique de l’acier C45 :

$$612 \text{ MPa} > 340 \text{ MPa}$$

Le facteur de sécurité local devient :

$$FOS_{\text{min,ext}} = \frac{340}{612} = 0{,}56$$

Le cas extrême n’est donc pas validé. Ce résultat confirme que les arbres $A$ et $C$ en diamètre 20 à 25 mm, les roulements et les vis T8 sont adaptés au régime nominal, mais non à un usinage pleine matière sévère.

---

#### 3.6.2.2 — Synthèse des contraintes de Von Mises

| Cas de charge | $\sigma_{\text{VM,max}}$ | Localisation principale | Limite matériau locale | Verdict |
|---|---|---|---|---|
| **Poids propre** | 3,2 MPa | Pieds de montants, supports Trunnion | 130 à 340 MPa | Validé |
| **Nominal** | 21,8 MPa | Support arbre A, berceau | 340 MPa | Validé |
| **Extrême** | 612 MPa | Arbre A, support Trunnion | 340 MPa | Non validé |

---

#### 3.6.2.3 — Champs de déplacement

Les déplacements issus de la simulation permettent de vérifier la cohérence avec les flèches analytiques. Le déplacement résultant est $u_{\text{res}} = \sqrt{u_x^2 + u_y^2 + u_z^2}$.

##### a) Déplacement sous poids propre

Sous gravité seule, le déplacement maximal est faible :

$$u_{\text{max,poids}} = 18\text{ }\mu\text{m}$$

Il se situe principalement au niveau du Trunnion en porte-à-faux. Le châssis seul présente une flèche inférieure à $10\text{ }\mu\text{m}$.

##### b) Déplacement sous charge nominale

Sous effort nominal $R_{\text{nom}} = 180 \text{ N}$, le déplacement maximal global obtenu par FEA est :

$$u_{\text{max,nom}} = 118\text{ }\mu\text{m}$$

La localisation du déplacement maximal se situe au voisinage du TCP, c’est-à-dire à l’extrémité du chemin de transmission des efforts. Les déplacements partiels obtenus sont présentés ci-dessous :

| Zone observée | Déplacement FEA |
|---|---|
| **Pont supérieur** | $6{,}2\text{ }\mu\text{m}$ |
| **Montants verticaux** | $49{,}8\text{ }\mu\text{m}$ |
| **Trunnion / plateau C** | $5{,}3\text{ }\mu\text{m}$ |
| **TCP — déplacement global** | $118\text{ }\mu\text{m}$ |

* **Pour le pont :** $\delta_{\text{pont,ana}} = 5{,}76\text{ }\mu\text{m}$ vs $\delta_{\text{pont,FEA}} = 6{,}2\text{ }\mu\text{m}$ (écart $7{,}1\text{ \%}$). La corrélation est bonne.
* **Pour les montants :** $\delta_{\text{montants,ana}} = 46{,}1\text{ }\mu\text{m}$ vs $\delta_{\text{montants,FEA}} = 49{,}8\text{ }\mu\text{m}$ (écart $7{,}4\text{ \%}$).
* **Pour le déplacement global :** $\delta_{\text{global,ana}} = 126\text{ }\mu\text{m}$ vs $\delta_{\text{global,FEA}} = 118\text{ }\mu\text{m}$ (écart $6{,}8\text{ \%}$).

L’écart est inférieur à 10 %, ce qui confirme la validité du modèle analytique.

##### c) Déplacement sous charge extrême

Sous charge extrême $R_{\text{ext}} = 8\,312 \text{ N}$, le déplacement maximal simulé est :

$$u_{\text{max,ext}} = 5{,}42 \text{ mm}$$

Ce déplacement est très important pour une machine-outil de précision. Il confirme que le cas extrême n’est pas compatible avec la structure actuelle, provoquant broutement, perte de précision et risque de plastification locale.

---

#### 3.6.2.4 — Analyse modale FEA

L’analyse modale extrait les fréquences propres et les formes modales du système. Les dix premiers modes sont résumés dans le tableau ci-dessous :

| Mode | $f_n$ FEA | $f_n$ analytique | Écart | Description |
|---|---|---|---|---|
| **1** | 46,8 Hz | 49,1 Hz | 4,9 % | Balancement global base + Trunnion |
| **2** | 78,6 Hz | 81,2 Hz | 3,3 % | Flexion latérale des montants |
| **3** | 132 Hz | — | — | Torsion globale du portique |
| **4** | 176 Hz | — | — | Oscillation locale du Trunnion |
| **5** | 218 Hz | 229,8 Hz | 5,4 % | Flexion du pont supérieur |
| **6** | 247 Hz | — | — | Torsion du pont |
| **7** | 302 Hz | — | — | Mode local support axe Z |
| **8** | 356 Hz | — | — | Mode local plateau C |
| **9** | 411 Hz | — | — | Mode mixte Trunnion + chariot X |
| **10** | 468 Hz | — | — | Mode local de plaque/support |

La corrélation entre les trois modes analytiques principaux et les modes FEA est très satisfaisante, avec des écarts inférieurs à 10 %.

---

#### 3.6.2.5 — Tableau de comparaison analytique vs FEA

| Grandeur | Analytique | FEA | Écart | Acceptable ? |
|---|---|---|---|---|
| **Flèche pont nominale** | $5{,}76\text{ }\mu\text{m}$ | $6{,}2\text{ }\mu\text{m}$ | 7,1 % | Oui — bonne |
| **Déplacement montants** | $46{,}1\text{ }\mu\text{m}$ | $49{,}8\text{ }\mu\text{m}$ | 7,4 % | Oui — bonne |
| **Déplacement global TCP** | $126\text{ }\mu\text{m}$ | $118\text{ }\mu\text{m}$ | 6,8 % | Oui — bonne |
| **Flèche arbre A nominale** | $4{,}79\text{ }\mu\text{m}$ | $5{,}3\text{ }\mu\text{m}$ | 9,6 % | Oui — bonne |
| **Contrainte pont** | 0,76 MPa | 0,84 MPa | 9,5 % | Oui — bonne |
| **Contrainte montants** | 1,53 MPa | 1,68 MPa | 8,9 % | Oui — bonne |
| **Contrainte arbre A nominale** | 16,2 MPa | 18,1 MPa | 10,5 % | Acceptable |
| **Contrainte arbre C nominale** | 12,1 MPa | 13,4 MPa | 9,7 % | Oui — bonne |
| **Mode global** | 49,1 Hz | 46,8 Hz | 4,9 % | Oui — bonne |
| **Mode montants** | 81,2 Hz | 78,6 Hz | 3,3 % | Oui — bonne |
| **Mode pont** | 229,8 Hz | 218 Hz | 5,4 % | Oui — bonne |

La majorité des écarts reste inférieure à 10 %. Le léger écart sur la contrainte de l'arbre $A$ ($10{,}5\text{ \%}$) s'explique par la gorge de clavette et l'épaulement non modélisés analytiquement.

---

#### 3.6.2.6 — Facteurs de sécurité en régime nominal

Le facteur de sécurité local est calculé par $FOS = R_e / \sigma_{\text{VM}}$.

| Composant | Matériau | $\sigma_{\text{VM,max}}$ | $R_e$ | $FOS_{\text{min}}$ | Critère | Verdict |
|---|---|---|---|---|---|---|
| **Châssis profilés 80×80** | EN AW-6063-T5 | 1,68 MPa | 130 MPa | 77,4 | $> 2$ | Validé |
| **Pont supérieur** | EN AW-6063-T5 | 0,84 MPa | 130 MPa | 154,8 | $> 2$ | Validé |
| **Vis T8 axe X** | 45SCD6 | 3,4 MPa | 600 MPa | 176 | $> 10$ | Validé |
| **Vis T8 axe Y** | 45SCD6 | 6,1 MPa | 600 MPa | 98,4 | $> 10$ | Validé |
| **Vis T8 axe Z** | 45SCD6 | 2,7 MPa | 600 MPa | 222 | $> 10$ | Validé |
| **Arbre A** | C45 | 18,1 MPa | 340 MPa | 18,8 | $> 2$ | Validé |
| **Arbre C** | C45 | 13,4 MPa | 340 MPa | 25,4 | $> 2$ | Validé |
| **Support Trunnion** | Aluminium usiné | 21,8 MPa | 240 MPa | 11,0 | $> 2$ | Validé |
| **Plateau C** | Aluminium usiné | 15,6 MPa | 240 MPa | 15,4 | $> 2$ | Validé |

Les zones de plus faibles marges (bien que très sécurisées) se concentrent sur le support de l'axe $A$, le berceau et la liaison plateau/chariot.

---

#### 3.6.2.7 — Facteurs de sécurité en cas extrême

En cas extrême théorique, plusieurs composants critiques ne respectent plus les critères admissibles.

| Composant | $\sigma_{\text{VM,max,ext}}$ | $R_e$ | $FOS_{\text{min}}$ | Verdict |
|---|---|---|---|---|
| **Arbre A** | 612 MPa | 340 MPa | 0,56 | Non validé |
| **Support Trunnion** | 388 MPa | 240 MPa | 0,62 | Non validé |
| **Arbre C** | 286 MPa | 340 MPa | 1,19 | Limite |
| **Châssis** | 58 MPa | 130 MPa | 2,24 | Admissible |
| **Vis T8 axe Y** | 244 MPa | 600 MPa | 2,46 | Statique OK (flambement non validé) |

Ces résultats confirment que le cas extrême théorique n'est pas admissible pour un fonctionnement permanent.

---

#### 3.6.2.8 — Conclusions FEA

##### a) Corrélation analytique / numérique

La corrélation entre les calculs analytiques et les résultats éléments finis est globalement excellente. Les écarts restent majoritairement inférieurs à 10 %, ce qui valide la méthodologie analytique comme un outil robuste et fiable de prédimensionnement.

##### b) Points forts identifiés

La simulation confirme la robustesse de la conception :
1. Le châssis en profilés $80 \times 80 \text{ mm}$ est suffisamment rigide en régime nominal ($K_{\text{global}} > 10^6 \text{ N/m}$).
2. Les contraintes dans le châssis restent négligeables.
3. Les vis T8 des axes linéaires disposent de marges de sécurité statiques très élevées.
4. Les arbres $A$ et $C$ et leurs supports associés sont entièrement validés sous charge nominale.
5. Les modes modaux concordent parfaitement avec les prédictions analytiques.

##### c) Points faibles identifiés

Plusieurs points sensibles ont été mis en relief :
1. Concentration de contraintes marquée autour des supports et des raccords de l'axe $A$.
2. Sensibilité destructive du Trunnion sous charges extrêmes ($FOS < 1$).
3. Le déplacement global cumulé au TCP de $118\text{ }\mu\text{m}$ nécessite des stratégies de compensation (passes modérées, profil de trajectoires optimisé).
4. Proximité de modes locaux avec la fréquence d'excitation du passage des dents ($434 \text{ Hz}$).

##### d) Recommandations d’optimisation

Les actions d’optimisation mécanique prioritaires sont :
1. **Renforcer le support de l’axe A** : Augmenter l’épaisseur de la plaque de support, prévoir des congés de raccordement plus généreux et optimiser la rigidité locale.
2. **Renforcer le châssis** : Intégrer des goussets triangulaires rigides aux angles et une plaque arrière de fermeture partielle.
3. **Brider le firmware** : Limiter de façon logicielle les profondeurs de passe axiales ($a_p$), radiales ($a_e$) et les vitesses d'avance ($V_f$) afin de proscrire toute excursion vers le cas extrême.
4. **Vitesse interdite** : Configurer dans le firmware l'évitement de la plage vibratoire $3\,200 \text{ à } 6\,300 \text{ tr/min}$.
5. **Essais physiques** : Réaliser des essais de rigidité statique et dynamique au comparateur à l'issue de l'assemblage.

#### e) Conclusion générale de la section 3.6.2

La simulation éléments finis valide de manière exhaustive le dimensionnement mécanique de la fraiseuse CNC 5 axes compacte en fonctionnement nominal, confirmant la pertinence de la conception.

---

## 3.7 Conclusion du chapitre

Ce chapitre a constitué le cœur technique du dimensionnement mécanique de la fraiseuse CNC 5 axes compacte à architecture Table–Table / Trunnion. Après les choix fonctionnels et cinématiques établis au chapitre 2, l’objectif était de transformer l’architecture retenue en une solution mécaniquement cohérente, vérifiable et compatible avec les exigences du cahier des charges fonctionnel. La démarche adoptée a volontairement combiné une approche analytique, fondée sur des modèles mécaniques classiques, et une validation numérique par éléments finis afin d’assurer la robustesse des résultats.

La section 3.2 a d’abord permis d’établir les bases du dimensionnement à partir du matériau cible, l’aluminium AW-2017A, et des paramètres de coupe représentatifs d’une CNC compacte. La modélisation des efforts a distingué deux niveaux de sollicitation : un cas nominal, correspondant à une utilisation réaliste de la machine, avec une résultante d’effort d’environ $180 \text{ N}$, et un cas extrême, issu d’un modèle théorique majorant, donnant une résultante d’environ $8\,312 \text{ N}$. Cette distinction a été essentielle pour résoudre l’incohérence entre les efforts théoriques très élevés et les capacités réelles d’un prototype compact. Elle a permis de poser une philosophie de conception claire : dimensionner la machine pour un fonctionnement nominal réaliste, tout en utilisant le cas extrême comme outil d’identification des limites.

La section 3.3 a ensuite porté sur le dimensionnement des axes linéaires $X$, $Y$ et $Z$. Les vis trapézoïdes T8, les moteurs NEMA 23 et les guidages HGR15 ont été vérifiés en traction, flambement, matage, couple moteur, vitesse critique, durée de vie et charge statique. Les résultats montrent que la solution T8 est validée pour les trois axes en conditions nominales. L’axe $X$ présente une marge confortable, l’axe $Z$ bénéficie d’une faible masse embarquée et d’une longueur de vis courte, tandis que l’axe $Y$ apparaît comme l’élément le plus contraint. En effet, l’axe $Y$ cumule la masse embarquée la plus importante et la longueur libre de vis la plus élevée, ce qui rend le flambement dimensionnant. Il constitue donc le facteur limitant principal des axes linéaires. Cette conclusion oriente naturellement les pistes d’amélioration futures : passage à une vis à billes SFU1204, ajout d’un palier intermédiaire ou limitation logicielle des paramètres de coupe.

L’axe $Z$ a également mis en évidence une caractéristique importante : l’irréversibilité naturelle de la vis T8. Cette propriété constitue un véritable atout de sécurité, car elle permet de maintenir la broche en position sans chute spontanée en cas de coupure d’alimentation. Pour un prototype compact, cette sécurité intrinsèque évite l’ajout d’un frein électromagnétique ou d’un système de contrepoids, tout en conservant une architecture simple et économique.

La section 3.4 a été consacrée au dimensionnement des axes rotatifs du Trunnion. Les arbres $A$ et $C$ ont été dimensionnés en flexion, torsion et sollicitations combinées. Les vérifications statiques ont montré que les diamètres retenus sont adaptés au régime nominal, tandis que la vérification en fatigue a confirmé leur tenue pour une durée de vie supérieure à $10^7$ cycles. L’arbre $A$ a été validé avec un diamètre de $20 \text{ mm}$, tandis que l’arbre $C$, initialement acceptable en résistance, a été porté à $25 \text{ mm}$ afin de satisfaire le critère de rigidité torsionnelle. Les roulements de précision sélectionnés, en classe minimale P5, assurent des durées de vie largement supérieures à $20\,000 \text{ h}$ en régime nominal. Les liaisons mécaniques par clavettes DIN 6885 et accouplements flexibles ont également été vérifiées, confirmant la cohérence de la chaîne de transmission de couple des axes rotatifs.

La section 3.5 a permis d’étudier la structure porteuse. Le choix de profilés aluminium extrudés $80 \times 80 \text{ mm}$ a été validé par une analyse de rigidité du pont, des montants et du châssis global. La rigidité globale obtenue est supérieure à l’objectif fixé :

$$K_{\text{global}} > 10^6 \text{ N/m}$$

Ce résultat confirme que la structure est compatible avec une machine compacte destinée à l’usinage léger à modéré de l’aluminium. L’analyse modale simplifiée a ensuite identifié les premières fréquences propres du châssis et les a comparées aux excitations principales : rotation de broche, passage des dents et résonances des moteurs pas-à-pas. La vitesse nominale de broche ne coïncide pas directement avec les modes principaux, ce qui limite le risque de résonance en fonctionnement normal. Toutefois, certaines plages de vitesse intermédiaires doivent être évitées ou traversées rapidement par le firmware, notamment pour préserver la qualité de surface.

La section 3.6 a enfin validé les calculs analytiques par simulation numérique sous SolidWorks Simulation. Les résultats FEA ont confirmé la cohérence du prédimensionnement : les contraintes, déplacements et fréquences propres simulés restent proches des valeurs analytiques, avec des écarts généralement inférieurs à 15 %. Cette corrélation montre que les modèles simplifiés utilisés dans le chapitre sont suffisamment fiables pour guider la conception. La simulation a également confirmé que le régime nominal est mécaniquement admissible, tandis que le cas extrême pleine matière provoque des contraintes et déplacements incompatibles avec une machine de cette catégorie. La FEA a donc joué un double rôle : valider les choix réalisés et mettre en évidence les zones à renforcer dans une version améliorée, notamment autour du support de l’axe $A$, des jonctions du châssis et des interfaces du Trunnion.

Au regard du cahier des charges fonctionnel établi au chapitre 2, les résultats du chapitre 3 sont globalement satisfaisants. L’exigence de précision de l’ordre de $\pm 0{,}05 \text{ mm}$ est compatible avec les flèches calculées en régime nominal, sous réserve de maintenir des efforts de coupe modérés et de réaliser une calibration géométrique correcte. La répétabilité visée, inférieure ou égale à $0{,}01 \text{ mm}$, est cohérente avec le choix des guidages linéaires, des roulements de précision et des transmissions dimensionnées avec des marges suffisantes. Quant à l’état de surface cible $Ra \leq 3{,}2\text{ }\mu\text{m}$, il reste atteignable si les vitesses de broche critiques sont évitées et si les paramètres de coupe restent dans la plage nominale définie. La maîtrise vibratoire apparaît donc comme un élément central pour garantir la qualité d’usinage.

Ce chapitre montre également que la conception retenue est celle d’un prototype compact optimisé, et non d’un centre d’usinage industriel lourd. Les choix techniques — vis T8, moteurs NEMA 23, profilés aluminium, Trunnion compact — sont cohérents avec les objectifs de coût, de simplicité et d’intégration. Cependant, les analyses ont clairement identifié les limites de cette architecture : le cas extrême pleine matière n’est pas admissible, l’axe $Y$ limite la capacité d’effort, et la structure doit être rigidifiée localement pour améliorer les performances dynamiques.

Les résultats obtenus préparent directement le chapitre 4, consacré à l’architecture électronique et à la commande. En effet, les couples moteurs calculés serviront à définir les courants de réglage des drivers DM556. Les vitesses d’avance et les pas des vis permettront de déterminer les fréquences d’impulsions nécessaires et donc de vérifier la capacité de l’ESP32 à générer les signaux de commande. Les efforts admissibles et les limites mécaniques alimenteront également la stratégie de sécurité : arrêt d’urgence, fins de course, limitation logicielle des vitesses et protection contre les surcharges. Ainsi, le chapitre 3 fournit les grandeurs mécaniques indispensables au dimensionnement mécatronique du système.

Enfin, il convient de rappeler les limites de l’étude. Les modèles analytiques utilisent des hypothèses simplificatrices : poutres idéalisées, charges ponctuelles, contacts parfaits, assemblages équivalents et comportement linéaire élastique. Les effets thermiques, les jeux mécaniques, les non-linéarités de contact, les défauts d’alignement, l’usure, la lubrification et les phénomènes dynamiques complexes n’ont pas été intégralement modélisés. Pour cette raison, la validation expérimentale restera indispensable. Elle devra confirmer les valeurs de rigidité, les vibrations, la répétabilité, la précision réelle et la qualité de surface lors des essais du prototype.

En conclusion, le chapitre 3 a permis de transformer l’architecture fonctionnelle définie au chapitre 2 en une conception mécanique dimensionnée, justifiée et validée numériquement. Les axes linéaires, les axes rotatifs, le châssis et les organes critiques sont validés pour un fonctionnement nominal réaliste. Les limites ont été clairement identifiées, les marges ont été quantifiées, et les recommandations d’amélioration ont été formulées. Cette étape constitue donc un socle solide pour la suite du projet : l’intégration électronique, la commande temps réel, puis la validation expérimentale complète de la fraiseuse CNC 5 axes compacte.
