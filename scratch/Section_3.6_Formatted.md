# Section 3.6 - Simulation par Éléments Finis (FEA)

Cette analyse confirme la nécessité de compléter l’étude analytique par une **simulation éléments finis modale**, afin d’obtenir des fréquences propres plus précises et d’identifier les formes modales réelles du châssis.

## 3.6.1 Paramétrage de la simulation (SolidWorks Simulation)

Les sections précédentes ont permis d’établir le dimensionnement analytique des sous-ensembles mécaniques principaux : axes linéaires ($X, Y, Z$), axes rotatifs ($A, C$), arbres, roulements et châssis. Ces calculs constituent une première validation, mais reposent sur des hypothèses simplificatrices (poutres idéalisées, appuis parfaits).

Une validation numérique est réalisée à l’aide du module **SolidWorks Simulation — Structural**. L’objectif est de vérifier la cohérence des résultats, d’identifier les concentrations de contraintes et de valider la rigidité globale.

La simulation est organisée autour de quatre cas principaux :
1. **Poids propre**
2. **Chargement nominal**
3. **Chargement extrême**
4. **Analyse modale**

### 3.6.1.1 Simplification du modèle CAO

La simplification est réalisée pour réduire le coût de calcul tout en conservant les géométries significatives.

*   **Suppression des détails non structuraux :** Câbles, connecteurs, visserie non structurale, petits chanfreins décoratifs, marquages et capots légers.
*   **Conservation des géométries critiques :** Gorges de clavettes, rainures fonctionnelles, épaulements d'arbres, congés de raccordement, interfaces arbre/roulement et zones d'encastrement.

#### Stratégie de simplification par sous-ensembles
La machine est divisée en plusieurs sous-ensembles :
1. Châssis
2. Ensemble Trunnion
3. Arbres $A$ et $C$
4. Vis T8 des axes linéaires
5. Assemblage global

#### Assignation des matériaux

| Composant | Matériau | Module $E$ | Limite élastique $R_e$ | Masse volumique $\rho$ |
| :--- | :--- | :--- | :--- | :--- |
| **Châssis (profilés 80x80)** | EN AW-6063-T5 | $69\text{ GPa}$ | $130\text{ MPa}$ | $2\,700\text{ kg/m}^3$ |
| **Arbres A et C** | Acier C45 | $210\text{ GPa}$ | $340\text{ MPa}$ | $7\,850\text{ kg/m}^3$ |
| **Vis T8** | Acier 45SCD6 | $210\text{ GPa}$ | $600\text{ MPa}$ | $7\,850\text{ kg/m}^3$ |
| **Plateau C / supports** | Aluminium usiné | $69$ à $72\text{ GPa}$ | Selon nuance | $2\,700$ à $2\,790\text{ kg/m}^3$ |
| **Pièce usinée** | AW-2017A | $72,5\text{ GPa}$ | $240\text{ MPa}$ | $2\,790\text{ kg/m}^3$ |
| **Clavettes** | E335 | $210\text{ GPa}$ | $335\text{ MPa}$ | $7\,850\text{ kg/m}^3$ |

### 3.6.1.2 Conditions aux limites

*   **Encastrement de la base :** La base du châssis est fixée ($u_x = u_y = u_z = 0$ et $\theta_x = \theta_y = \theta_z = 0$).
*   **Contacts entre profilés :** Modélisés par des contacts de type **Bonded** (collés) pour simuler une structure solidaire.
*   **Contacts au niveau des paliers :** Utilisation de **Bearing Connectors** (connecteurs de roulement) pour représenter l'appui arbre/logement.

### 3.6.1.3 Cas de charge

| Cas | Description | Charges appliquées | Objectif |
| :--- | :--- | :--- | :--- |
| **1** | **Poids propre** | Gravité seule ($g = 9,81\text{ m/s}^2$) | Vérifier les flèches statiques |
| **2** | **Nominal** | Gravité + Effort de coupe ($180\text{ N}$) | Valider le régime normal d'usinage |
| **3** | **Extrême** | Gravité + Effort maximal ($8\,312\text{ N}$) | Identifier les limites mécaniques |
| **4** | **Modal** | Extraction de 10 modes | Vérifier les fréquences propres |

### 3.6.1.4 Maillage

Le modèle est maillé avec des **tétraèdres paraboliques haute qualité** (second ordre), adaptés aux surfaces courbes.

*   **Taille globale ($h_{global}$)** : $5\text{ mm}$ à $10\text{ mm}$.
*   **Raffinement local ($h_{local}$)** : $1\text{ mm}$ à $2\text{ mm}$ dans les zones critiques (gorges, congés, paliers).

#### Étude de convergence
| Niveau | Taille globale | Taille locale | Objectif |
| :--- | :--- | :--- | :--- |
| **Maillage 1** | $10\text{ mm}$ | $2\text{ mm}$ | Calcul initial |
| **Maillage 2** | $7\text{ mm}$ | $1,5\text{ mm}$ | Raffinement intermédiaire |
| **Maillage 3** | $5\text{ mm}$ | $1\text{ mm}$ | Calcul final |

Le critère de convergence est un écart relatif $\varepsilon < 5\%$ sur les grandeurs principales ($\sigma_{VM}$, $u_{max}$, $f_1$).

---

## 3.6.2 Résultats et Validation Finale

### 3.6.2.1 Analyse des contraintes de Von Mises ($\sigma_{VM}$)

*   **Cas 1 - Poids propre :** $\sigma_{VM,max} = 3,2\text{ MPa}$. Sollicitation négligeable devant la limite élastique ($R_e = 130\text{ MPa}$), $FOS \approx 40$.
*   **Cas 2 - Chargement nominal ($180\text{ N}$) :** $\sigma_{VM,max} = 21,8\text{ MPa}$. Localisée au support du Trunnion (arbre A). $FOS \approx 15,6$. **Validé.**
*   **Cas 3 - Chargement extrême ($8\,312\text{ N}$) :** $\sigma_{VM,max} = 612\text{ MPa}$. Dépasse largement la limite de l'acier C45 ($340\text{ MPa}$). $FOS = 0,56$. **Non validé.**

#### Synthèse des contraintes
| Cas de charge | $\sigma_{VM,max}$ | Localisation principale | Limite matériau | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Poids propre** | $3,2\text{ MPa}$ | Pieds de montants | $130$ à $340\text{ MPa}$ | **Validé** |
| **Nominal** | $21,8\text{ MPa}$ | Support arbre A, berceau | $340\text{ MPa}$ | **Validé** |
| **Extrême** | $612\text{ MPa}$ | Arbre A, support Trunnion | $340\text{ MPa}$ | **Non validé** |

### 3.6.2.2 Champs de déplacement ($u_{res}$)

*   **Cas 1 - Poids propre :** $u_{max} = 18\text{ }\mu m$ (au niveau du Trunnion).
*   **Cas 2 - Charge nominale :** $u_{max} = 118\text{ }\mu m$ au niveau du TCP.
*   **Cas 3 - Charge extrême :** $u_{max} = 5,42\text{ mm}$. Incompatible avec la précision requise.

#### Comparaison des déplacements partiels (Cas Nominal)
| Zone observée | Déplacement FEA |
| :--- | :--- |
| **Pont supérieur** | $6,2\text{ }\mu m$ |
| **Montants verticaux** | $49,8\text{ }\mu m$ |
| **Trunnion / plateau C** | $5,3\text{ }\mu m$ |
| **TCP (Global)** | $118\text{ }\mu m$ |

### 3.6.2.3 Analyse modale FEA

| Mode | $f_n$ FEA | $f_n$ Analytique | Écart | Description |
| :--- | :--- | :--- | :--- | :--- |
| **1** | $46,8\text{ Hz}$ | $49,1\text{ Hz}$ | $4,9\%$ | Balancement global base + Trunnion |
| **2** | $78,6\text{ Hz}$ | $81,2\text{ Hz}$ | $3,3\%$ | Flexion latérale des montants |
| **5** | $218\text{ Hz}$ | $229,8\text{ Hz}$ | $5,4\%$ | Flexion du pont supérieur |

La corrélation est excellente ($\text{écart} < 10\%$). Les fréquences d'excitation identifiées ($\text{broche } 144,7\text{ Hz}$, $\text{dents } 434\text{ Hz}$) doivent être surveillées, notamment autour des modes 3 ($132\text{ Hz}$) et 10 ($468\text{ Hz}$).

### 3.6.2.4 Comparaison Globale Analytique vs FEA

| Grandeur | Analytique | FEA | Écart | Acceptable ? |
| :--- | :--- | :--- | :--- | :--- |
| **Flèche pont nominale** | $5,76\text{ }\mu m$ | $6,2\text{ }\mu m$ | $7,1\%$ | Oui |
| **Déplacement montants** | $46,1\text{ }\mu m$ | $49,8\text{ }\mu m$ | $7,4\%$ | Oui |
| **Déplacement global TCP** | $126\text{ }\mu m$ | $118\text{ }\mu m$ | $6,8\%$ | Oui |
| **Contrainte arbre A (nom)** | $16,2\text{ MPa}$ | $18,1\text{ MPa}$ | $10,5\%$ | Acceptable |
| **Mode global ($f_1$)** | $49,1\text{ Hz}$ | $46,8\text{ Hz}$ | $4,9\%$ | Oui |

### 3.6.2.5 Facteurs de sécurité (FOS) en régime nominal

| Composant | Matériau | $\sigma_{VM,max}$ | $R_e$ | $FOS_{min}$ | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Châssis (profilés)** | EN AW-6063-T5 | $1,68\text{ MPa}$ | $130\text{ MPa}$ | $77,4$ | **Validé** |
| **Vis T8 (Axe Y)** | 45SCD6 | $6,1\text{ MPa}$ | $600\text{ MPa}$ | $98,4$ | **Validé** |
| **Arbre A** | C45 | $18,1\text{ MPa}$ | $340\text{ MPa}$ | $18,8$ | **Validé** |
| **Support Trunnion** | Aluminium | $21,8\text{ MPa}$ | $240\text{ MPa}$ | $11,0$ | **Validé** |

---

## 3.6.2.6 Conclusions et Recommandations

### Points Forts
*   **Rigidité globale** validée en régime nominal ($K_{global} > 10^6\text{ N/m}$).
*   **Contraintes faibles** dans le châssis et les axes linéaires.
*   **Excellente corrélation** entre les modèles analytiques et numériques.

### Points Sensibles
*   **Concentration de contraintes** au support de l'axe A.
*   **Vulnérabilité aux efforts extrêmes** (risque de plastification).
*   **Déplacement au TCP ($118\text{ }\mu m$)** nécessitant des stratégies d'usinage adaptées.

### Recommandations d'optimisation
1.  **Renforcer le support de l'axe A** (nervures, épaisseur accrue).
2.  **Rigidifier les jonctions du châssis** (goussets, double boulonnage).
3.  **Limiter les efforts de coupe** dans le firmware (limitation de $a_p, a_e, V_f$).
4.  **Définir des zones de vitesse interdites** pour éviter les résonances ($3\,200$ à $6\,300\text{ tr/min}$).
5.  **Validation expérimentale** post-assemblage (mesure de vibrations et rugosité).
