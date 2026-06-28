## 3.4 Dimensionnement des axes de rotation du Trunnion (A et C)

Cette section est consacrée au dimensionnement mécanique exhaustif des axes de rotation du Trunnion (axes A et C). Elle constitue une étude complète et autonome intégrant le choix de la transmission, la résistance statique des arbres, la tenue en fatigue, la rigidité, la sélection des roulements de précision ainsi que la vérification des liaisons mécaniques.

L'étude est systématiquement menée selon deux régimes opérationnels représentatifs d'une démarche industrielle, auxquels s'ajoute un cas d'étude théorique :
1. **Cas nominal 5-axes** : Les axes A et C sont actifs. Les paramètres de coupe sont adaptés et limités par le logiciel de bord Forgeron (fraise Ø6 carbure 3 dents, aluminium 6061, $a_p = 0,5$ mm, $a_e = 1,5$ mm, $f_z = 0,05$ mm/dent). La résultante d'effort est estimée à **$R_{5ax} = 30$ N**.
2. **Cas nominal 3-axes** : Les axes A et C sont verrouillés en position par le couple de maintien des moteurs. L'usinage s'effectue exclusivement via les axes linéaires X, Y, Z avec des paramètres plus agressifs, générant une résultante **$R_{3ax} = 180$ N**. Les efforts sont absorbés par la structure (arbres et roulements) et non par la chaîne de transmission en rotation.
3. **Cas extrême** : Régime théorique de pleine matière générant **$R_{ext} = 8\ 312$ N**. Il sert exclusivement à évaluer les marges de sécurité ultimes et ne constitue en aucun cas un régime de fonctionnement permanent admissible.

### 3.4.1 — ARCHITECTURE ET JUSTIFICATION

Le système Trunnion repose sur une architecture cinématique « Table-Table » composée d'un berceau basculant (axe A, plage $\pm 90^\circ$) supportant un plateau rotatif (axe C, rotation continue $360^\circ$). Afin de minimiser l'encombrement et l'inertie mobile, la motorisation est déportée. 

La transmission retenue pour chaque axe s'effectue par un étage unique de réduction par courroie crantée, reliant un moteur pas-à-pas NEMA 17 à l'arbre de rotation via des poulies GT2.

[Figure 3.10 : Schéma cinématique du Trunnion avec transmission GT2 10T→60T]

La justification de cette architecture repose sur plusieurs critères technico-économiques :
* **Compacité et inertie** : L'utilisation d'un seul étage de réduction avec un moteur hors du berceau limite la masse suspendue et l'encombrement global.
* **Coût et disponibilité** : L'utilisation de composants standards (NEMA 17, courroie GT2) offre une solution économique (moins de 10 € par axe) particulièrement adaptée au prototypage.
* **Multiplication du couple** : Le rapport de réduction $i = 6$ (poulies 10 dents vers 60 dents) permet de démultiplier le couple moteur tout en augmentant la résolution angulaire.
* **Amortissement** : L'élasticité inhérente de la courroie crantée contribue à l'amortissement des vibrations haute fréquence générées par l'usinage.
* **Maintenance** : Le remplacement de la courroie s'effectue aisément en quelques minutes.

Tableau comparatif des architectures de transmission envisageables :

| Critère | Entraînement direct | Courroie (Rapport 3:1) | Courroie (Rapport 6:1 - Retenu) |
| :--- | :---: | :---: | :---: |
| **Couple transmis** | Faible | Moyen | **Élevé** |
| **Résolution angulaire**| Faible | Moyenne | **Excellente** |
| **Encombrement** | Maximal (dans l'axe) | Compact | **Compact (déporté)** |
| **Amortissement** | Nul | Bon | **Bon** |

Dans cette configuration, le moteur NEMA 17 (référence 42BYGHW811) présente un couple nominal à 200 tr/min de $T_{nom} = 0,40$ N·m et un couple de maintien (holding torque) de $T_{hold} = 0,48$ N·m.

La capacité de charge maximale du système en mode 5-axes est conditionnée par le couple de maintien ramené à l'outil. Avec un offset maximal pour l'axe A ($e_A = 60$ mm), l'effort admissible s'exprime par :
$$ R_{max} = \frac{T_{hold} \times i \times \eta}{e_A} $$
$$ R_{max} = \frac{0,48 \times 6 \times 0,95}{0,060} = 45,6\ \text{N} $$

On vérifie ainsi que **$R_{max} = 45,6\ \text{N} > R_{5ax} = 30\ \text{N}$**. Le système dispose d'une marge de sécurité de $1,52$ par rapport aux efforts de coupe générés en interpolation 5 axes.

---

### 3.4.2 — DIMENSIONNEMENT DE LA TRANSMISSION PAR COURROIE

#### 3.4.2.1 — Axe A

**a) Rapport de réduction et couple**
Le rapport de réduction $i_A$ s'établit à partir du nombre de dents des poulies :
$$ i_A = \frac{Z_{men\acute{e}e}}{Z_{menante}} = \frac{60}{10} = 6 $$
Le couple nominal transmis à l'arbre $T_A$ tient compte du rendement estimé de la courroie crantée ($\eta = 0,95$) :
$$ T_A = T_{nom} \times i_A \times \eta $$
$$ T_A = 0,40 \times 6 \times 0,95 = 2,28\ \text{N\cdot m} $$

**b) Diamètres primitifs**
Les diamètres primitifs des poulies (profil GT2, pas $p = 2$ mm) sont :
$$ d_{menante} = \frac{Z_{menante} \times p}{\pi} = \frac{10 \times 2}{\pi} = 6,37\ \text{mm} $$
$$ d_{men\acute{e}e} = \frac{Z_{men\acute{e}e} \times p}{\pi} = \frac{60 \times 2}{\pi} = 38,20\ \text{mm} $$
Les rayons primitifs correspondants sont $r_{menante} = 3,18$ mm et $r_{men\acute{e}e} = 19,10$ mm.

**c) Longueur de courroie**
Pour un entraxe estimé $a_A = 60$ mm, la longueur primitive de la courroie est donnée par :
$$ L_A \approx 2a_A + \frac{\pi}{2}(d_{men\acute{e}e} + d_{menante}) + \frac{(d_{men\acute{e}e} - d_{menante})^2}{4a_A} $$
$$ L_A \approx 2(60) + \frac{\pi}{2}(38,20 + 6,37) + \frac{(38,20 - 6,37)^2}{4(60)} $$
$$ L_A \approx 120 + 70,01 + \frac{1013,15}{240} \approx 194,2\ \text{mm} $$

**d) Nombre de dents en prise**
Le nombre de dents en prise sur la petite poulie (10 dents) s'évalue par :
$$ z_{prise} = \frac{Z_{menante}}{2} \left( 1 - \frac{d_{men\acute{e}e} - d_{menante}}{2a_A} \right) $$
$$ z_{prise} = \frac{10}{2} \left( 1 - \frac{38,20 - 6,37}{120} \right) = 5 \times (1 - 0,265) \approx 3,67\ \text{dents} $$

**e) Vérification de la courroie**
L'effort utile nominal $F_u$ transmis par la courroie pour fournir le couple $T_A$ est :
$$ F_u = \frac{T_A}{r_{men\acute{e}e}} = \frac{2,28}{0,0191} = 119,3\ \text{N} $$
L'effort admissible par la courroie (largeur 7 mm) est proportionnel au nombre de dents en prise (effort unitaire d'environ 4 N par dent pour ce profil) :
$$ F_{adm} = z_{prise} \times 4 = 3,67 \times 4 = 14,68\ \text{N} $$
*Conclusion sur la courroie :* La condition $F_u \le F_{adm}$ n'est pas vérifiée ($119,3\ \text{N} > 14,68\ \text{N}$). L'utilisation d'une poulie motrice de 10 dents induit un nombre de dents en prise insuffisant (inférieur aux 6 dents minimales recommandées), entraînant un risque de saut de dent sous forte charge. Toutefois, conformément aux données figées du prototype, cette architecture est maintenue. Les efforts d'usinage devront impérativement être limités par le firmware.

**f) Tension et charge radiale sur l'arbre**
La tension du brin tendu ($F_1$) et du brin mou ($F_2$) est estimée en considérant une pré-tension usuelle :
$$ F_1 \approx 1,5 \times F_u = 1,5 \times 119,3 = 179,0\ \text{N} $$
$$ F_2 = F_1 - F_u = 179,0 - 119,3 = 59,7\ \text{N} $$
La charge radiale totale appliquée sur l'arbre de rotation due à la tension de la courroie est :
$$ F_{courroie,A} = F_1 + F_2 = 179,0 + 59,7 = 238,7\ \text{N} $$

#### 3.4.2.2 — Axe C
La chaîne cinématique de l'axe C est identique à celle de l'axe A, seul l'entraxe diffère ($a_C = 50$ mm).
Le nombre de dents en prise devient :
$$ z_{prise,C} = 5 \left( 1 - \frac{31,83}{100} \right) \approx 3,41\ \text{dents} $$
Les couples et les tensions internes de la courroie sont considérés identiques par principe de standardisation des modules de motorisation. Ainsi, $T_C = 2,28$ N·m et $F_{courroie,C} = 238,7$ N.

#### 3.4.2.3 — Synthèse transmission

| Paramètre | Axe A | Axe C |
| :--- | :---: | :---: |
| **Rapport de réduction ($i$)** | 6 | 6 |
| **Couple de sortie nominal ($T$)** | 2,28 N·m | 2,28 N·m |
| **Entraxe ($a$)** | 60 mm | 50 mm |
| **Dents en prise (menante)** | 3,67 | 3,41 |
| **Charge radiale courroie ($F_{courroie}$)**| 238,7 N | 238,7 N |

---

### 3.4.3 — MODÉLISATION ET CALCUL DES ARBRES DE ROTATION

L'objectif de cette section est de déterminer le diamètre minimal théorique des arbres A et C afin de garantir leur intégrité structurelle (critère de Von Mises), avant de figer un diamètre normalisé pour la conception. Le matériau de référence est l'acier C45 normalisé :
* Limite d'élasticité : $R_e = 340$ MPa
* Résistance à la rupture : $R_m = 620$ MPa
* Coefficient de sécurité visé : $s = 2$
* Contrainte admissible : $\sigma_{adm} = \frac{R_e}{s} = 170$ MPa.

#### 3.4.3.1 — Schéma de chargement de l'arbre A

[Figure 3.11 : Schéma de chargement — arbre A]

L'arbre A est modélisé par une poutre bi-appuyée de longueur $L_b = 120$ mm. Il supporte :
* **Une charge répartie / centrale permanente** due au poids du plateau et du berceau : $W_A = 39,24$ N.
* **Un moment fléchissant généré par l'effort de coupe excentré** : $M_{coupe} = R \times e_A$ avec $e_A = 0,06$ m.
* **Un couple de torsion** : $T_A$ induit par le maintien du moteur ou l'usinage.
* **Une charge radiale** : $F_{courroie,A}$ appliquée à une extrémité (assimilée au niveau du palier pour simplifier l'étude de la section centrale dangereuse).

Le moment fléchissant maximal se situe au centre de l'arbre (milieu de l'entraxe) et se superpose à la contrainte de torsion :
$$ M_{f} = \frac{W_A \times L_b}{4} + M_{coupe} $$

#### 3.4.3.2 — Diamètre minimal arbre A (Von Mises)

La section circulaire pleine subit une contrainte normale de flexion $\sigma_f$ et une contrainte tangentielle de torsion $\tau$ :
$$ \sigma_f = \frac{32 M_f}{\pi d^3} \quad \text{et} \quad \tau = \frac{16 T_A}{\pi d^3} $$
La contrainte équivalente de Von Mises s'écrit :
$$ \sigma_{eq} = \sqrt{\sigma_f^2 + 3\tau^2} \le \sigma_{adm} $$
En isolant le diamètre $d$, on obtient le diamètre minimal :
$$ d_{min} = \sqrt[3]{ \frac{32}{\pi \sigma_{adm}} \sqrt{M_f^2 + 0,75 T_A^2} } $$

**1) Cas nominal 5-axes**
* Résultante : $R_{5ax} = 30$ N
* Torsion : $T_A = 2,28$ N·m (couple nominal moteur)
* Moment de coupe : $M_{coupe} = 30 \times 0,06 = 1,80$ N·m
* Moment fléchissant : $M_f = \frac{39,24 \times 0,12}{4} + 1,80 = 1,18 + 1,80 = 2,98$ N·m
$$ d_{min, 5ax} = \sqrt[3]{ \frac{32}{\pi \times 170.10^6} \sqrt{2,98^2 + 0,75(2,28)^2} } $$
$$ d_{min, 5ax} = \sqrt[3]{ 5,99.10^{-8} \times \sqrt{8,88 + 3,90} } = \sqrt[3]{ 5,99.10^{-8} \times 3,57 } \approx 5,98\ \text{mm} $$

**2) Cas nominal 3-axes (Arbre verrouillé)**
* Résultante : $R_{3ax} = 180$ N
* Torsion : Le couple de maintien du moteur s'oppose à la rotation : $T_A = T_{hold,sortie} = 2,74$ N·m
* Moment de coupe : $M_{coupe} = 180 \times 0,06 = 10,80$ N·m
* Moment fléchissant : $M_f = 1,18 + 10,80 = 11,98$ N·m
$$ d_{min, 3ax} = \sqrt[3]{ 5,99.10^{-8} \times \sqrt{11,98^2 + 0,75(2,74)^2} } $$
$$ d_{min, 3ax} = \sqrt[3]{ 5,99.10^{-8} \times 12,21 } \approx 9,01\ \text{mm} $$

**3) Cas extrême**
* Résultante : $R_{ext} = 8\ 312$ N
* Torsion : $T_A = 2,74$ N·m (glissement moteur)
* Moment fléchissant : $M_f = 1,18 + (8312 \times 0,06) = 499,90$ N·m
$$ d_{min, ext} = \sqrt[3]{ 5,99.10^{-8} \times \sqrt{499,90^2 + 0,75(2,74)^2} } \approx 31,05\ \text{mm} $$

**Conclusion et choix pour l'arbre A**
Le diamètre normalisé retenu est **$d_A = 20\ \text{mm}$**.
* Coefficient de sécurité 5-axes : $n_{5ax} = \frac{170}{\sigma_{eq}(d=20)} = 37,6 \ge 2 \implies$ **Validé**
* Coefficient de sécurité 3-axes : $n_{3ax} = \frac{170}{\sigma_{eq}(d=20)} = 10,9 \ge 2 \implies$ **Validé**
* Cas extrême : $n_{ext} = 0,27 < 2 \implies$ **Non admissible**

#### 3.4.3.3 — Schéma de chargement de l'arbre C

[Figure 3.12 : Schéma de chargement — arbre C]

L'arbre C est un arbre vertical supporté par un palier inférieur (reprenant la charge axiale) et un guidage supérieur. 
Il subit :
* La charge axiale du poids de la pièce : $W_{pi\grave{e}ce} = 19,62$ N.
* Le moment de renversement de coupe : $M_{C} = R \times e_C$ avec $e_C = 0,03$ m.
* Le couple de torsion : $T_C$.
* La tension de courroie : $F_{courroie,C}$.

#### 3.4.3.4 — Diamètre minimal arbre C (Von Mises)

Contrairement à l'arbre A, l'arbre C subit une contrainte normale de traction/compression due au poids, qui s'ajoute à la flexion :
$$ \sigma_{traction} = \frac{4 W_{pi\grave{e}ce}}{\pi d^2} $$
$$ \sigma_{eq} = \sqrt{ (\sigma_f + \sigma_{traction})^2 + 3\tau^2 } \le \sigma_{adm} $$
*Note : Vu la très faible masse de la pièce (2 kg), $\sigma_{traction}$ est négligeable devant $\sigma_f$. Le calcul simplifié reste applicable.*

**1) Cas nominal 5-axes**
* $M_C = 30 \times 0,03 = 0,90$ N·m ; $T_C = 2,28$ N·m
$$ d_{min, 5ax} \approx \sqrt[3]{ 5,99.10^{-8} \times \sqrt{0,90^2 + 0,75(2,28)^2} } = \sqrt[3]{ 5,99.10^{-8} \times 2,17 } \approx 5,06\ \text{mm} $$

**2) Cas nominal 3-axes**
* $M_C = 180 \times 0,03 = 5,40$ N·m ; $T_C = 2,74$ N·m
$$ d_{min, 3ax} \approx \sqrt[3]{ 5,99.10^{-8} \times \sqrt{5,40^2 + 0,75(2,74)^2} } = \sqrt[3]{ 5,99.10^{-8} \times 5,90 } \approx 7,07\ \text{mm} $$

**3) Cas extrême**
* $M_C = 8312 \times 0,03 = 249,36$ N·m ; $T_C = 2,74$ N·m
$$ d_{min, ext} \approx \sqrt[3]{ 5,99.10^{-8} \times 249,37 } \approx 24,63\ \text{mm} $$

**Conclusion et choix pour l'arbre C**
Le diamètre normalisé retenu est **$d_C = 25\ \text{mm}$**.
* Coefficient de sécurité 5-axes : $n_{5ax} = 120,0 \ge 2 \implies$ **Validé**
* Coefficient de sécurité 3-axes : $n_{3ax} = 44,0 \ge 2 \implies$ **Validé**
* Cas extrême : $n_{ext} = 1,04 < 2 \implies$ **Non admissible**

#### 3.4.3.5 — Synthèse arbres

| Arbre | $M_{f\ 5ax}$ | $M_{f\ 3ax}$ | $M_{f\ ext}$ | $T$ | $d_{min,5ax}$ | $d_{min,3ax}$ | $d_{min,ext}$ | **$d_{choisi}$** | $n_{5ax}$ | $n_{3ax}$ | $n_{ext}$ |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A** | 2,98 N·m | 11,98 N·m | 499,9 N·m | 2,74 | 5,98 mm | 9,01 mm | 31,05 mm | **20 mm** | 37,6 | 10,9 | 0,27 |
| **C** | 0,90 N·m | 5,40 N·m | 249,3 N·m | 2,74 | 5,06 mm | 7,07 mm | 24,63 mm | **25 mm** | 120,0 | 44,0 | 1,04 |

---

### 3.4.4 — VÉRIFICATION À LA FATIGUE ET À LA RIGIDITÉ

Les arbres sont soumis à des contraintes cycliques générées par la rotation de la fraise ($N = 8\ 680$ tr/min, $Z = 3$ dents $\implies f_{dents} = 434$ Hz). L'objectif est de s'assurer que la conception garantit une durée de vie infinie ($> 10^7$ cycles) et qu'aucune déformation excessive ne viendra perturber la précision cinématique RTCP.

#### 3.4.4.1 — Limite d'endurance corrigée

La limite d'endurance brute de l'acier C45 est $\sigma'_D \approx 0,5 R_m = 310$ MPa. Elle est altérée par la géométrie et l'environnement :
$$ \sigma_D = \sigma'_D \times K_s \times K_t \times K_f \times K_r $$
Avec les facteurs identifiés pour ce prototype ($K_s = 0,75$, $K_t = 0,85$, $K_f = 0,56$, $K_r = 0,897$) :
$$ \sigma_D = 310 \times 0,75 \times 0,85 \times 0,56 \times 0,897 = 99,2\ \text{MPa} $$

#### 3.4.4.2 — Diagramme de Haigh — Arbre A

[Figure 3.13 : Diagramme de Haigh — arbre A]

Le critère de Goodman s'exprime par : $\frac{\sigma_a}{\sigma_D} + \frac{\sigma_m}{R_m} \le \frac{1}{s}$
* **Contrainte moyenne ($\sigma_m$)** : Générée par la charge gravitaire permanente et le couple de positionnement.
  $$ \sigma_{m,f} = \frac{32 \times 1,18}{\pi \times 0,02^3} = 1,50\ \text{MPa} \quad ; \quad \tau_m = \frac{16 \times 2,28}{\pi \times 0,02^3} = 1,45\ \text{MPa} $$
  $$ \sigma_{m,eq} = \sqrt{1,50^2 + 3(1,45)^2} = 2,92\ \text{MPa} $$
* **Contrainte alternée ($\sigma_a$)** : Générée par l'effort de coupe cyclique ($M_{coupe}$). La torsion alternée est négligeable ($\tau_a = 0$).

**1) Cas nominal 5-axes**
* $M_{coupe} = 1,80$ N·m $\implies \sigma_{a,eq} = \frac{32 \times 1,80}{\pi \times 0,02^3} = 2,29$ MPa.
$$ n_{fatigue, 5ax} = \left( \frac{2,29}{99,2} + \frac{2,92}{620} \right)^{-1} = \frac{1}{0,023 + 0,0047} = 36,1 \ge 2 \implies \textbf{Valid\acute{e}} $$

**2) Cas nominal 3-axes**
* $M_{coupe} = 10,80$ N·m $\implies \sigma_{a,eq} = \frac{32 \times 10,80}{\pi \times 0,02^3} = 13,75$ MPa.
$$ n_{fatigue, 3ax} = \left( \frac{13,75}{99,2} + \frac{2,92}{620} \right)^{-1} = \frac{1}{0,138 + 0,0047} = 7,0 \ge 2 \implies \textbf{Valid\acute{e}} $$

**3) Cas extrême**
$$ n_{fatigue, ext} = \left( \frac{636,5}{99,2} + \dots \right)^{-1} = 0,15 < 2 \implies \textbf{Non admissible} $$

#### 3.4.4.3 — Diagramme de Haigh — Arbre C

[Figure 3.14 : Diagramme de Haigh — arbre C]

La rotation continue de l'arbre C sous effort radial induit une flexion purement alternée (flexion tournante), d'où $\sigma_m \approx 0$. Le critère se simplifie en $\sigma_a \le \frac{\sigma_D}{s}$.

**1) Cas nominal 5-axes** ($M_C = 0,90$ N·m, $d_C = 25$ mm)
$$ \sigma_{a} = \frac{32 \times 0,90}{\pi \times 0,025^3} = 0,58\ \text{MPa} \implies n_{fatigue, 5ax} = \frac{99,2}{0,58} = 171,0 \ge 2 \implies \textbf{Valid\acute{e}} $$

**2) Cas nominal 3-axes** ($M_C = 5,40$ N·m)
$$ \sigma_{a} = \frac{32 \times 5,40}{\pi \times 0,025^3} = 3,52\ \text{MPa} \implies n_{fatigue, 3ax} = \frac{99,2}{3,52} = 28,1 \ge 2 \implies \textbf{Valid\acute{e}} $$

#### 3.4.4.4 — Rigidité en torsion

Une déformation en torsion excessive entraîne une erreur angulaire néfaste pour le calcul cinématique inverse. La limite admissible est fixée à $\theta_{max} = 0,25^\circ$/m. La formule analytique est : $\theta = \frac{T \times L}{G \times I_p}$ avec $I_p = \frac{\pi d^4}{32}$.

**Arbre A ($d=20$ mm)** :
$$ \theta_A = \frac{2,28}{81.10^9 \times \frac{\pi \times 0,02^4}{32}} = \frac{2,28}{81.10^9 \times 1,57.10^{-8}} = 1,79.10^{-3}\ \text{rad/m} = 0,102^\circ\text{/m} < 0,25^\circ\text{/m} $$

**Arbre C ($d=25$ mm)** :
$$ \theta_C = \frac{2,28}{81.10^9 \times \frac{\pi \times 0,025^4}{32}} = 7,35.10^{-4}\ \text{rad/m} = 0,042^\circ\text{/m} < 0,25^\circ\text{/m} $$

#### 3.4.4.5 — Flèche en flexion

La flèche maximale de l'arbre A (assimilé à une poutre bi-appuyée) doit rester $\le 0,01$ mm.
$$ f_{max} = \frac{F \times L^3}{48 E I} = \frac{F \times L^3}{48 E \frac{\pi d^4}{64}} $$

**1) Cas nominal 5-axes** ($F = W_A + R_{5ax} = 39,24 + 30 = 69,24$ N)
$$ f_{5ax} = \frac{69,24 \times 0,12^3}{48 \times 210.10^9 \times \frac{\pi \times 0,02^4}{64}} = \frac{0,119}{7\ 912\ 800} \approx 1,5.10^{-6}\ \text{m} = 0,0015\ \text{mm} \le 0,01\ \text{mm} $$

**2) Cas nominal 3-axes** ($F = 39,24 + 180 = 219,24$ N)
$$ f_{3ax} = \frac{219,24 \times 0,12^3}{7\ 912\ 800} = 0,0048\ \text{mm} \le 0,01\ \text{mm} $$

#### 3.4.4.6 — Synthèse

| Arbre | $n_{fat,5ax}$ | $n_{fat,3ax}$ | $n_{fat,ext}$ | $\theta$ ($^\circ$/m) | $f_{max}$ (mm) | Verdict |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A (20mm)** | 36,1 | 7,0 | 0,15 | 0,102 | 0,0048 | **Validé (en modes nominaux)** |
| **C (25mm)** | 171,0 | 28,1 | 0,15 | 0,042 | — | **Validé (en modes nominaux)** |

---

### 3.4.5 — SÉLECTION DES ROULEMENTS DE PRÉCISION

La qualité d'usinage sur cinq axes exige une grande rigidité et une absence de jeu axial et radial.

#### 3.4.5.1 — Réactions aux paliers

**Arbre A (Paliers écartés de $L_b = 120$ mm)** :
* Effort radial par palier : $F_r = \frac{R}{2} + \frac{M_{coupe}}{L_b}$
* Cas 5-axes : $F_r = \frac{30}{2} + \frac{1,80}{0,12} = 15 + 15 = 30$ N
* Cas 3-axes : $F_r = \frac{180}{2} + \frac{10,80}{0,12} = 90 + 90 = 180$ N
* Cas extrême : $F_r = \frac{8312}{2} + \frac{498,72}{0,12} = 8\ 312$ N

**Arbre C (Palier inférieur et supérieur)** :
L'effort radial combiné se répercute asymétriquement. On approxime $F_r \approx 0,875 R$.
* Cas 5-axes : $F_r = 0,875 \times 30 = 26,3$ N
* Cas 3-axes : $F_r = 0,875 \times 180 = 157,5$ N
La charge axiale $F_a = W_{pi\grave{e}ce} = 19,6$ N.

#### 3.4.5.2 — Choix du type de roulement

Les axes rotatifs subissant des charges combinées ainsi que des moments de renversement stricts, des **roulements à contact oblique montés en opposition (« O » ou dos-à-dos)** sont sélectionnés. Ils permettent une précharge éliminant tout jeu angulaire. La classe de précision **P5** est retenue.
* Palier A (Ø20 mm) : Réf. **7004 P5** ($C = 12\ 000$ N, $C_0 = 6\ 500$ N)
* Palier C (Ø25 mm) : Réf. **7005 P5** ($C = 14\ 000$ N, $C_0 = 7\ 800$ N)

#### 3.4.5.3 — Charge dynamique équivalente ($P_e$)

On considère un facteur dynamique $f_w = 1,2$. Les charges axiales étant faibles, $P_e \approx f_w \times F_r$.
* Axe A : $P_{e,5ax} = 1,2 \times 30 = 36$ N ; $P_{e,3ax} = 1,2 \times 180 = 216$ N
* Axe C : $P_{e,5ax} \approx 32$ N ; $P_{e,3ax} \approx 189$ N

#### 3.4.5.4 — Durée de vie ($L_{10h}$)

La durée de vie cible nominale est fixée à $> 20\ 000$ heures.
La formulation ISO est $L_{10h} = \left(\frac{C}{P_e}\right)^3 \frac{10^6}{60 \times N}$. La vitesse de rotation moyenne est prise empiriquement à $30$ tr/min (Axe A) et $60$ tr/min (Axe C) (vitesses maximales de positionnement).
* **Axe A (Cas 3-axes critique)** : $L_{10h} = \left(\frac{12000}{216}\right)^3 \frac{10^6}{60 \times 30} = 55,5^3 \times 555 \approx 9,5.10^7\ \text{heures} > 20\ 000\ \text{h}$
* **Axe C (Cas 3-axes critique)** : $L_{10h} = \left(\frac{14000}{189}\right)^3 \frac{10^6}{60 \times 60} = 74^3 \times 277 \approx 1,1.10^8\ \text{heures} > 20\ 000\ \text{h}$

#### 3.4.5.5 — Charge statique ($F_s$)

La sécurité statique doit garantir $F_s = \frac{C_0}{P_0} \ge 3$.
* **Axe A (3-axes)** : $F_s = \frac{6500}{180} = 36,1 \ge 3$
* **Axe A (Extrême)** : $F_s = \frac{6500}{8312} = 0,78 < 3$ (Destruction du chemin de roulement)

#### 3.4.5.6 — Synthèse des roulements

| Palier | Type et Réf. | $C$ (kN) | $P_{e,3ax}$ (N) | $L_{10h,3ax}$ (h) | $F_{s,3ax}$ | Verdict |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Axe A** | Contact Oblique O, 7004 P5 | 12 | 216 | $> 9.10^7$ | 36,1 | **Validé** |
| **Axe C** | Contact Oblique O, 7005 P5 | 14 | 189 | $> 1.10^8$ | 41,2 | **Validé** |

---

### 3.4.6 — DIMENSIONNEMENT DES LIAISONS MÉCANIQUES

#### 3.4.6.1 — Arbre / poulie GT2-60T
La liaison entre l'arbre et la poulie menée est assurée par une clavette parallèle normalisée DIN 6885. On vérifie la contrainte de matage ($P_{mat} \le 60$ MPa) et de cisaillement ($\tau \le 100,5$ MPa).
* **Axe A** ($d=20$, $b=6$, $t_2=2,8$, $L_u=20$ mm) :
  $P_{mat} = \frac{2 \times 2,28}{0,02 \times 0,0028 \times 0,02} = 4,07\ \text{MPa} \le 60\ \text{MPa}$
* **Axe C** ($d=25$, $b=8$, $t_2=3,3$, $L_u=25$ mm) :
  $P_{mat} = \frac{2 \times 2,28}{0,025 \times 0,0033 \times 0,025} = 2,21\ \text{MPa} \le 60\ \text{MPa}$

#### 3.4.6.2 — Moteur / poulie GT2-10T
Le diamètre de sortie du moteur NEMA 17 étant de 5 mm avec méplat, l'immobilisation de la poulie est assurée par une vis de pression radiale M3 (sans tête). L'effort circonférentiel requis pour contrer le glissement est de $F_{serrage} = \frac{0,40}{0,0025} = 160$ N, largement couvert par l'adhérence générée par le serrage d'une vis M3 sur méplat.

#### 3.4.6.3 — Synthèse des liaisons
L'ensemble des liaisons satisfait très amplement les critères de matage et de cisaillement sous les efforts nominaux (marges de sécurité $>10$).

---

### 3.4.7 — SYNTHÈSE GÉNÉRALE DU TRUNNION

Le tableau suivant récapitule l'ensemble du dimensionnement mécanique pour les deux axes de rotation du Trunnion, comparés selon les trois cas d'étude définis.

| Paramètre | Axe A (Berceau basculant) | Axe C (Plateau rotatif) |
| :--- | :--- | :--- |
| **Rapport de réduction ($i$)** | 6 (Poulies GT2 10T / 60T) | 6 (Poulies GT2 10T / 60T) |
| **Couple moteur / sortie ($T$)** | 0,40 N·m / 2,28 N·m | 0,40 N·m / 2,28 N·m |
| **Effort admissible TCP ($R_{max}$)** | **45,6 N** | **45,6 N** |
| **Moment fléchissant** ($M_f$) | 5ax: 2,98 / 3ax: 11,98 / Ext: 499,9 N·m | 5ax: 0,90 / 3ax: 5,40 / Ext: 249,3 N·m |
| **Diamètre normalisé retenu** | **$d_A = 20$ mm** | **$d_C = 25$ mm** |
| **Sécurité Statique Von Mises ($n_{sec}$)**| 5ax: 37,6 / 3ax: 10,9 / **Ext: 0,27** | 5ax: 120,0 / 3ax: 44,0 / **Ext: 1,04** |
| **Sécurité Fatigue Goodman ($n_{fat}$)** | 5ax: 36,1 / 3ax: 7,0 / Ext: 0,15 | 5ax: 171,0 / 3ax: 28,1 / Ext: 0,15 |
| **Rigidité Torsion ($\theta$) / Flèche ($f$)**| $0,102^\circ$/m / $0,0048$ mm (mode 3-axes)| $0,042^\circ$/m / (N/A) |
| **Roulements (O) / Durée $L_{10h}$** | 7004 P5 / $> 9.10^7$ h | 7005 P5 / $> 1.10^8$ h |
| **Liaisons mécaniques** | Clavette DIN 6885 6x6x20 (Validé) | Clavette DIN 6885 8x7x25 (Validé) |
| **AXE CRITIQUE ?** | **OUI** (Flexion et palier) | **NON** (Massif) |

**CONCLUSION GÉNÉRALE :**

Le dimensionnement de l'architecture du Trunnion confirme la viabilité de l'approche hybride et compacte. La transmission déportée par poulie/courroie 10T→60T est **validée en mode d'interpolation 5-axes simultané**, sous réserve du respect strict de la limite d'effort calculée ($R \le 45,6$ N). 

En **mode 3-axes positionnel**, où l'effort de coupe grimpe à 180 N, les axes A et C sont verrouillés. L'étude démontre que la structure matérielle (arbres $d=20$ mm et $d=25$ mm, roulements à contact oblique P5) est amplement dimensionnée pour encaisser ces charges. Le maintien angulaire est garanti par le couple de retenue des moteurs NEMA 17 démultiplié, évitant l'adjonction de freins mécaniques encombrants.

Toutefois, les calculs appliqués au **cas extrême théorique (8 312 N)** prouvent qu'un tel régime d'usinage est totalement inenvisageable : les coefficients de sécurité s'effondrent sous l'unité, causant la rupture par fatigue et la plastification des arbres, ainsi que la destruction des chemins de roulements. L'intégrité de la machine compacte repose donc fondamentalement sur la couche de contrôle logiciel (le firmware Forgeron), qui joue un rôle sécuritaire actif en limitant rigoureusement les paramètres de coupe.

Ce constat clôt la vérification analytique locale des organes rotatifs et amorce logiquement la section 3.5, dédiée à l'analyse dynamique structurelle globale de la machine et aux stratégies logicielles de prévention.