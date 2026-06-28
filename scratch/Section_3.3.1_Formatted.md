### 3.3.1 Dimensionnement de l'axe X (Chariot transversal)

L'axe **X** assure le déplacement transversal du chariot supportant l'unité **Trunnion**. Dans l'architecture retenue, il porte le chariot X, le berceau Trunnion, le plateau rotatif C, ainsi que la pièce et son système de bridage. Il est donc directement impliqué dans la précision de positionnement latéral et dans les compensations imposées par la cinématique 5 axes.

Le dimensionnement de cet axe repose sur les charges suivantes :
- **Charge nominale équivalente** : $F_{X, tot} \approx 95 \text{ N}$
- **Cas extrême (pleine matière)** : $F_{X, extre\hat{me}} = 3\,676 \text{ N}$

---

#### 1. Vérification en traction — Critère de Von Mises

La section résistante de la vis est calculée au diamètre de noyau ($d_n = 6,2 \text{ mm}$) :
$$A = \frac{\pi}{4} d_n^2$$
$$A = \frac{\pi}{4} \times (0,0062)^2 = 3,019 \times 10^{-5} \text{ m}^2$$

La contrainte normale $\sigma$ doit respecter : $\sigma \le \sigma_{adm} = \frac{R_e}{s} = 300 \text{ MPa}$ (avec $R_e = 600 \text{ MPa}$ et $s = 2$).

| Cas | Force $F$ (N) | Contrainte $\sigma$ (MPa) | Verdict |
| :--- | :--- | :--- | :--- |
| **Nominal** | $93,75$ | $3,11$ | **Validé** ($\ll 300 \text{ MPa}$) |
| **Extrême** | $3\,675,75$ | $121,75$ | **Validé** ($< 300 \text{ MPa}$) |

---

#### 2. Diamètre minimal théorique

Le diamètre minimal est donné par :
$$d_{min} = \sqrt{\frac{4Fs}{\pi R_e}}$$

- **Cas nominal** : $d_{min, nom} = 0,63 \text{ mm}$
- **Cas extrême** : $d_{min, extre\hat{me}} = 3,95 \text{ mm}$

Le diamètre de noyau réel étant $d_n = 6,2 \text{ mm}$, la condition $d_n > d_{min}$ est satisfaite dans tous les cas.

---

#### 3. Vérification au flambement — Formule d’Euler

La vis est assimilée à une colonne comprimée en montage **pivot-pivot** ($K = 1$).
Le moment quadratique est : $I = \frac{\pi d_n^4}{64} = 7,253 \times 10^{-11} \text{ m}^4$.

La charge critique d'Euler est :
$$F_{cr} = \frac{\pi^2 E I}{(KL)^2} = \frac{\pi^2 \times 210 \times 10^9 \times 7,253 \times 10^{-11}}{(1 \times 0,15)^2} = 6\,681 \text{ N}$$

**Coefficient de sécurité au flambement ($n_{flamb} = \frac{F_{cr}}{F}$)** :
- **Cas nominal** : $n_{flamb, nom} = 71,27$ (Largement satisfait)
- **Cas extrême** : $n_{flamb, extre\hat{me}} = 1,82$ (**Limite**, critère $s \ge 2$ non respecté)

---

#### 4. Pression de matage vis/écrou

Vérification de la pression de contact acier/bronze.
- Nombre de filets en prise : $n_{filets} = \frac{L_{\text{écrou}}}{p} = \frac{15}{2} = 7,5$
- Surface de contact projetée : $S_{contact} = 153,74 \text{ mm}^2$
- Limite admissible : $P_{adm} = 5 \text{ à } 7 \text{ MPa}$

| Cas | Pression $P$ (MPa) | Verdict |
| :--- | :--- | :--- |
| **Nominal** | $0,61$ | **Validé** ($< 5 \text{ MPa}$) |
| **Extrême** | $23,91$ | **Non admissible** ($> 7 \text{ MPa}$) |

---

#### 5. Rendement et irréversibilité de la vis

- **Angle d'hélice** : $\lambda = 5,02^\circ$
- **Angle de frottement** : $\phi = 5,91^\circ$
- **Rendement direct** : $\eta = 45,5 \%$

La condition d'irréversibilité **$\lambda < \phi$** ($5,02^\circ < 5,91^\circ$) est satisfaite. Aucun frein dédié n'est requis sur cet axe.

---

#### 6. Couple moteur et puissance (NEMA 23, 1,26 Nm)

Le couple total requis $T_{total} = T_{charge} + T_{acc}$ (avec $T_{acc} = 0,045 \text{ Nm}$).

| Cas | Couple de charge (Nm) | Couple total (Nm) | Marge ($T_m / T_{total}$) | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Nominal** | $0,066$ | $0,111$ | **11,34** | **Validé** ($> 2$) |
| **Extrême** | $2,57$ | $2,62$ | **0,48** | **Insuffisant** |

**Puissance mécanique** (à $1\,500 \text{ tr/min}$) :
- **Nominale** : $17,45 \text{ W}$ (Compatible)
- **Extrême** : $411 \text{ W}$ (Incompatible)

---

#### 7. Vitesse critique de la vis

$$N_{cr} = 33\,581 \text{ tr/min}$$
Comparaison avec $N_{max} = 1\,500 \text{ tr/min}$ : la marge est de **22,4**. Aucun risque de fouettement de la vis T8.

---

#### 8. Dimensionnement des guidages linéaires (HGR15)

L’axe X utilise deux rails **HGR15** et quatre patins **HGH15CA**.
- **Charge nominale dynamique** : $C = 16\,600 \text{ N}$
- **Charge statique** : $C_0 = 23\,400 \text{ N}$

| Cas | Charge équiv. $P_e$ (N) | Durée de vie $L_{10h}$ (h) | Sécurité statique $F_s$ | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Nominal** | $72,73$ | $3,30 \times 10^9$ | $386$ | **Validé** |
| **Extrême** | $2\,099$ | $137\,327$ | $13,38$ | **Validé** |

---

#### 9. Synthèse et tableau récapitulatif

| Critère | Valeur | Seuil | Coeff. Sécu | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Traction vis (Nominal)** | $\sigma = 3,11 \text{ MPa}$ | $300 \text{ MPa}$ | $96,6$ | **Validé** |
| **Traction vis (Extrême)** | $\sigma = 121,75 \text{ MPa}$ | $300 \text{ MPa}$ | $2,46$ | **Validé** |
| **Flambement vis (Nominal)** | $n_{flamb} = 71,27$ | $\ge 2$ | $71,27$ | **Validé** |
| **Flambement vis (Extrême)** | $n_{flamb} = 1,82$ | $\ge 2$ | $1,82$ | **Limite** |
| **Matage vis/écrou (Nominal)** | $0,61 \text{ MPa}$ | $5 \text{ à } 7 \text{ MPa}$ | $> 8$ | **Validé** |
| **Matage vis/écrou (Extrême)** | $23,91 \text{ MPa}$ | $5 \text{ à } 7 \text{ MPa}$ | $< 1$ | **Non validé** |
| **Couple moteur (Nominal)** | $0,111 \text{ Nm}$ | $1,26 \text{ Nm}$ | $11,34$ | **Validé** |
| **Couple moteur (Extrême)** | $2,62 \text{ Nm}$ | $1,26 \text{ Nm}$ | $0,48$ | **Non validé** |
| **Durée de vie guidages (Nominal)** | $3,30 \times 10^9 \text{ h}$ | $> 20\,000 \text{ h}$ | Très élevé | **Validé** |
| **Roulements d'appui (Nominal)** | $1,84 \times 10^6 \text{ h}$ | $> 20\,000 \text{ h}$ | $92$ | **Validé** |

**Conclusion** : L'axe X est parfaitement dimensionné pour un régime de fonctionnement **nominal** (passes modérées aluminium). Le cas **extrême** (pleine matière sévère) dépasse les capacités de la transmission T8 actuelle (matage, couple moteur, roulements).
