# 3.3.3 Dimensionnement de l'axe Z (mouvement vertical)

L’axe **Z** joue un rôle essentiel dans la qualité d’usinage, car il détermine directement la profondeur de passe, la stabilité de la broche et la précision du contact outil-matière. Son dimensionnement doit donc garantir à la fois la **résistance mécanique**, la **sécurité verticale** et l’**absence de chute intempestive** de la broche.

La transmission retenue est identique à celle des axes **X** et **Y**, à savoir une **vis trapézoïdale T8**. Toutefois, la course de l’axe **Z** est plus courte :
$L_Z = 120 \text{ mm}$

> Les caractéristiques de la vis T8 sont identiques à celles utilisées pour les axes X et Y.

---

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

---

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

---

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

---

### Irréversibilité de l’axe Z

L’irréversibilité conditionne la **sécurité verticale** : la broche doit rester en position même en cas de coupure d'alimentation.

- Angle d’hélice : $\lambda = \arctan(\frac{p}{\pi D_m}) = \arctan(\frac{2}{\pi \times 7,25}) = 5,02^\circ$
- Angle de frottement : $\varphi = \arctan(\frac{\mu}{\cos \beta}) = \arctan(\frac{0,10}{\cos 15^\circ}) = 5,91^\circ$

Condition d’irréversibilité : $\lambda < \varphi$.
Or, $5,02^\circ < 5,91^\circ$. **La vis T8 est donc irréversible (auto-bloquante).**

Rendement direct : $\eta = \frac{\tan \lambda}{\tan(\lambda + \varphi)} = \frac{\tan(5,02^\circ)}{\tan(5,02^\circ + 5,91^\circ)} = 0,455 \text{ (soit 45,5 %)}$
Rendement inverse : $\eta_{inv} = \frac{\tan(\lambda - \varphi)}{\tan \lambda} = \frac{\tan(5,02^\circ - 5,91^\circ)}{\tan(5,02^\circ)} = -0,177$
$\eta_{inv} \leq 0$ confirme l’**irréversibilité**.

**Avantages pour la sécurité :**
- Pas de chute spontanée de la broche.
- Aucun frein électromagnétique requis.
- Pas de couple moteur permanent à l’arrêt.

---

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

---

### Vitesse critique

- Vitesse max rotation : $N = \frac{V_f}{p} = \frac{3000}{2} = 1500 \text{ tr/min}$
- Vitesse critique calculée : $N_{cr,Z} = 52470 \text{ tr/min}$
Rapport $\frac{N_{cr,Z}}{N_{max}} = 34,98$. La vis fonctionne très loin de sa vitesse critique.

---

### Vérification des roulements et guidages

**Roulements :**
$L_{10h,nom} = 4,77 \times 10^6 \text{ h}$ (Validé).
$L_{10h,extreme} = 48,3 \text{ h}$ (Non admissible en prolongé).

**Guidages (4 patins sur 2 rails) :**
Données : $C = 16600 \text{ N}$, $C_0 = 23400 \text{ N}$, $f_w = 1,2$.
- **Durée de vie nominale :** $L_{10h,nom} = 3,21 \times 10^{10} \text{ h}$.
- **Coefficient statique extrême :** $f_{s,extreme} = 23,48$ (Bien supérieur au critère $f_s \geq 4$).

**Guidages de l'axe Z validés en configuration verticale.**

---

### Synthèse globale des trois axes linéaires

| Paramètre | Axe X | Axe Y | Axe Z |
| :--- | :--- | :--- | :--- |
| **Masse portée** | $7,5 \text{ kg}$ | $11 \text{ kg}$ | $1,5 \text{ kg}$ |
| **Course** | $150 \text{ mm}$ | $300 \text{ mm}$ | $120 \text{ mm}$ |
| **Charge nominale $F_{tot}$** | $93,75 \text{ N}$ | $175,5 \text{ N}$ | $70,45 \text{ N}$ |
| **Charge extrême** | $3675,75 \text{ N}$ | $7340,5 \text{ N}$ | $2219,45 \text{ N}$ |
| **$n_{traction}$ nominal** | $96,6$ | $51,6$ | $128,6$ |
| **$n_{flambement}$ nominal** | $71,27$ | $9,52$ | $148,2$ |
| **$n_{flambement}$ extrême** | $1,82$ | $0,23$ | $4,70$ |
| **Pression matage nominale** | $0,61 \text{ MPa}$ | $1,14 \text{ MPa}$ | $0,46 \text{ MPa}$ |
| **Pression matage extrême** | $23,91 \text{ MPa}$ | $47,75 \text{ MPa}$ | $14,44 \text{ MPa}$ |
| **Couple total nominal** | $0,111 \text{ Nm}$ | $0,169 \text{ Nm}$ | $0,093 \text{ Nm}$ |
| **Marge moteur nominale** | $11,34$ | $7,45$ | $13,51$ |
