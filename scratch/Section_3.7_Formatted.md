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
