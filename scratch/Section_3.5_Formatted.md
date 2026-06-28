# Section 3.5 - Étude de la structure et analyse dynamique

## 3.5.1 Analyse de rigidité du châssis

Après le dimensionnement des axes linéaires et des axes rotatifs du Trunnion, il est nécessaire de vérifier que la structure porteuse de la machine possède une rigidité suffisante pour maintenir la précision géométrique pendant l’usinage. En effet, une structure trop flexible entraînerait des déplacements relatifs entre la broche et la pièce, ce qui dégraderait directement la **précision dimensionnelle**, la **répétabilité** et l'**état de surface**.

Le châssis retenu pour le prototype est constitué de **profilés aluminium extrudés** de section $80 \times 80 \text{ mm}$, en alliage de type **EN AW-6063-T5**.

### 3.5.1.1 — Propriétés du profilé 80×80

Le tableau suivant regroupe les propriétés retenues pour le profilé aluminium $80 \times 80 \text{ mm}$.

| Propriété | Symbole | Valeur retenue | Unité | Commentaire |
| :--- | :---: | :---: | :---: | :--- |
| Section extérieure | — | $80 \times 80$ | mm | Profilé carré rainuré |
| Alliage | — | EN AW-6063-T5 | — | Aluminium extrudé |
| Module d’Young | $E$ | $69$ | GPa | Valeur de calcul |
| Limite d’élasticité | $R_e$ | $130$ | MPa | Valeur retenue pour T5 |
| Masse volumique | $\rho$ | $2\,700$ | kg/m³ | Aluminium |
| Moment d’inertie | $I_x \approx I_y$ | $118$ | cm⁴ | Valeur conservative |
| Moment d’inertie SI | $I$ | $1,18 \times 10^{-6}$ | m⁴ | Conversion $1 \text{ cm}^4 = 10^{-8} \text{ m}^4$ |
| Module de résistance | $W$ | $29,5$ | cm³ | Calculé avec $W = I/c, c = 40 \text{ mm}$ |
| Masse linéique typique | $m_l$ | $4,9 \text{ à } 5,3$ | kg/m | Valeurs catalogues Bosch/item |

**Calcul du module de résistance :**
$$W = \frac{I}{c}$$
Avec $c = \frac{80}{2} = 40 \text{ mm} = 0,04 \text{ m}$ :
$$W = \frac{1,18 \times 10^{-6}}{0,04} = 2,95 \times 10^{-5} \text{ m}^3 = 29,5 \text{ cm}^3$$

**Justification du choix 80×80 :**
Le moment d'inertie varie avec la puissance quatrième de la dimension ($I \propto a^4$).
- Un profilé $40 \times 40$ serait **16 fois moins rigide** ($\frac{1}{16}$) qu'un $80 \times 80$.
- Un profilé $60 \times 60$ présenterait environ **un tiers de la rigidité** ($0,316$) du $80 \times 80$.

### 3.5.1.2 — Rigidité du pont — modèle poutre sur deux appuis

Le pont supérieur est modélisé comme une poutre simplement appuyée de longueur $L = 500 \text{ mm} = 0,5 \text{ m}$.
Effort nominal de coupe : $F = 180 \text{ N}$.

**Flèche maximale :**
$$\delta_{\text{pont}} = \frac{FL^3}{48EI}$$
$$\delta_{\text{pont}} = \frac{180 \times (0,5)^3}{48 \times 69 \times 10^9 \times 1,18 \times 10^{-6}} = 5,76 \times 10^{-6} \text{ m} = 5,76 \text{ µm}$$

**Rigidité :**
$$K_{\text{pont}} = \frac{F}{\delta_{\text{pont}}} = \frac{180}{5,76 \times 10^{-6}} = 3,13 \times 10^7 \text{ N/m}$$
Le pont est largement validé ($K > 10^6 \text{ N/m}$).

### 3.5.1.3 — Rigidité des montants — modèle encastré-libre

Hauteur d'un montant : $H = 500 \text{ mm} = 0,5 \text{ m}$.
Chaque montant reprend $F_i = \frac{F}{2} = 90 \text{ N}$.

**Flèche d'un montant :**
$$\delta_{\text{montant}} = \frac{F_i H^3}{3EI} = \frac{90 \times (0,5)^3}{3 \times 69 \times 10^9 \times 1,18 \times 10^{-6}} = 46,1 \text{ µm}$$

**Rigidité équivalente (2 montants en parallèle) :**
$$K_{\text{montants}} = 2 \times \frac{90}{46,1 \times 10^{-6}} = 3,91 \times 10^6 \text{ N/m}$$

### 3.5.1.4 — Rigidité globale — modèle de ressorts en série

Modèle de rigidité : $\frac{1}{K_{\text{total}}} = \frac{1}{K_{\text{pont}}} + \frac{1}{K_{\text{montants}}} + \frac{1}{K_{\text{assemblages}}}$.
En prenant une pénalité d'assemblage $K_{\text{assemblages}} \approx 0,7 K_{\text{th}}$ :

$$K_{\text{total}} = 1,43 \times 10^6 \text{ N/m}$$
**Déplacement global sous 180 N :** $\delta_{\text{global}} = 126 \text{ µm}$.
**Compliance :** $0,70 \text{ µm/N}$. L'objectif ($\delta < 1 \text{ µm}$ sous $1 \text{ N}$) est respecté.

### 3.5.1.5 — Contraintes et coefficients de sécurité

Limite admissible : $\sigma_{\text{adm}} = \frac{R_e}{s} = \frac{130}{2} = 65 \text{ MPa}$.

- **Pont :** $M_{\text{max}} = 22,5 \text{ Nm} \Rightarrow \sigma_{\text{pont}} = 0,76 \text{ MPa}$ ($n = 85,2$).
- **Montants :** $M_{\text{max}} = 45 \text{ Nm} \Rightarrow \sigma_{\text{montant}} = 1,53 \text{ MPa}$ ($n = 42,6$).

Le dimensionnement est gouverné par la **rigidité** et non par la résistance.

### 3.5.1.6 — Synthèse de rigidité

| Élément | Rigidité $K$ (N/m) | Déplacement (180 N) | Contrainte $\sigma$ | Coefficient $n$ | Verdict |
| :--- | :---: | :---: | :---: | :---: | :--- |
| Pont supérieur | $3,13 \times 10^7$ | $5,76 \text{ µm}$ | $0,76 \text{ MPa}$ | $85,2$ | Validé |
| Deux montants | $3,91 \times 10^6$ | $46,1 \text{ µm}$ | $1,53 \text{ MPa}$ | $42,6$ | Validé |
| Assemblages | $2,43 \times 10^6$ | — | — | — | À rigidifier |
| **Global** | **$1,43 \times 10^6$** | **$126 \text{ µm}$** | — | — | **Validé** |

---

## 3.5.2 Analyse modale simplifiée

L'objectif est de vérifier que les **fréquences propres** de la structure restent éloignées des excitations (broche, dents, moteurs).

**Paramètres retenus :**
- Masse vibratoire : $m_{\text{vib}} \approx 15 \text{ kg}$.
- Amortissement : $\xi = 0,03$.

### 3.5.2.1 — Fréquences propres — modèle à 1 DDL

Formule : $f_n = \frac{1}{2\pi} \sqrt{\frac{K}{m}}$

| Sous-système | Raideur $K$ (N/m) | Masse $m$ (kg) | Fréquence propre $f_n$ |
| :--- | :---: | :---: | :---: |
| Pont supérieur | $3,13 \times 10^7$ | $15$ | $229,8 \text{ Hz}$ |
| Montants verticaux | $3,91 \times 10^6$ | $15$ | $81,2 \text{ Hz}$ |
| Global (Base + Trunnion) | $1,43 \times 10^6$ | $15$ | $49,1 \text{ Hz}$ |

### 3.5.2.2 — Fréquences d’excitation

Vitesse nominale : $N = 8\,680 \text{ tr/min}$.

| Source d’excitation | Formule | Fréquence |
| :--- | :---: | :---: |
| Rotation broche | $f = N/60$ | $144,7 \text{ Hz}$ |
| Passage dents ($Z=3$) | $f = 3 \times N/60$ | $434 \text{ Hz}$ |
| Moteurs pas-à-pas | Bande empirique | $100 \text{ à } 200 \text{ Hz}$ |

### 3.5.2.3 — Critère d’évitement

Zone critique : $0,7 < r < 1,3$ avec $r = \frac{f_{\text{excit}}}{f_n}$.

- **Mode Montants ($81,2 \text{ Hz}$)** : Sensible aux moteurs PaP à $100 \text{ Hz}$ ($r = 1,23$). Amplification $A \approx 1,9$.
- **Mode Pont ($229,8 \text{ Hz}$)** : Sensible aux moteurs PaP à $200 \text{ Hz}$ ($r = 0,87$). Amplification $A \approx 4,0$.

### 3.5.2.4 — Zones critiques de vitesse (Diagramme de Campbell)

| Mode | $f_n$ (Hz) | Zone critique broche (1×) | Zone critique dents (3×) |
| :--- | :---: | :---: | :---: |
| Global | $49,1$ | $2\,064 \text{ à } 3\,834 \text{ tr/min}$ | $688 \text{ à } 1\,278 \text{ tr/min}$ |
| Montants | $81,2$ | $3\,412 \text{ à } 6\,337 \text{ tr/min}$ | $1\,137 \text{ à } 2\,112 \text{ tr/min}$ |
| Pont | $229,8$ | $9\,651 \text{ à } 17\,923 \text{ tr/min}$ | $3\,217 \text{ à } 5\,974 \text{ tr/min}$ |

La vitesse nominale ($8\,680 \text{ tr/min}$) ne tombe pas directement dans une zone interdite majeure.

### 3.5.2.6 — Synthèse vibratoire

| Mode | $f_n$ | Excitation proche | Ratio $r$ | Amplification | Verdict |
| :--- | :---: | :---: | :---: | :---: | :--- |
| Global | $49,1 \text{ Hz}$ | Broche ($144,7 \text{ Hz}$) | $2,94$ | $0,13$ | Hors résonance |
| Montants | $81,2 \text{ Hz}$ | PaP ($100 \text{ Hz}$) | $1,23$ | $1,9$ | **Zone sensible** |
| Pont | $229,8 \text{ Hz}$ | PaP ($200 \text{ Hz}$) | $0,87$ | $4,0$ | **Zone sensible** |
| Pont | $229,8 \text{ Hz}$ | Dents ($434 \text{ Hz}$) | $1,89$ | $0,39$ | Hors résonance |

## Conclusion de la section 3.5

L'étude montre que le châssis en profilés **80×80 mm** respecte l'objectif de rigidité globale ($K > 10^6 \text{ N/m}$). La résistance mécanique est largement assurée (coefficients $> 40$).
Sur le plan dynamique, il est recommandé d'éviter la plage **$3\,200$ à $6\,300$ tr/min** pour limiter les risques de résonance avec le mode des montants et du pont.
