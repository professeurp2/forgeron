# Section 3.3.2 - Axe Y (Portique longitudinal)

Cette section constitue le modèle méthodologique appliqué pour le dimensionnement de l'**axe Y**. Contrairement à l'axe X, dont la longueur libre de vis est de 150 mm, l'**axe Y** possède une course utile de **300 mm**, soit une longueur libre deux fois plus importante.

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

---

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
