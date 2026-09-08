# Plan IA — une machine qui sent ce qu'elle coupe

État au 8 septembre 2026. Horizon : sélection des 50 solutions, dernière
semaine de novembre 2026.

Complète [`ARCHITECTURE.md`](ARCHITECTURE.md), qui décrit la frontière entre
l'IA et le calcul déterministe.

---

## 1. Le changement d'axe

**Avant.** Une IA qui parle à une CNC : un agent conversationnel, 33 outils,
du function calling. C'est ce que font 187 des 244 solutions de la cohorte,
dans d'autres secteurs. Notre avantage n'est pas là.

**Maintenant.** Une CNC qui **perçoit ce qu'elle fait** : charge de coupe,
géométrie réelle du brut, dérive thermique, écart entre le prévu et le réel.
L'IA exploite ces signaux. Le modèle de langage redevient ce qu'il doit être —
une interface, pas le produit.

Ce que la machine ne mesure pas, aucun modèle ne peut le deviner. **La
perception vient donc avant l'intelligence.**

### Pourquoi cet axe et pas la génération de G-code par le modèle

La question est tranchée par la littérature, pas par une préférence. `GLLM`
(*Self-Corrective G-Code Generation using LLMs*) fait exactement cela ; les
travaux sur le sujet documentent les hallucinations sémantiques, les erreurs de
syntaxe et l'absence de garantie d'exécution. Le parallèle avec les automates
industriels est explicite : du code généré par LLM qui pilote des machines
critiques manque de garanties et peut conduire à des situations dangereuses.

**Position définitive : l'agent ne produit aucune coordonnée.**

---

## 2. Sécurité — préalable non négociable

Le passage du relais au **MOSFET** est justifié : il ouvre le PWM, donc la
vitesse de broche variable, donc le contrôle adaptatif complet. Mais il change
le mode de défaillance.

> **Un relais qui lâche s'ouvre. Un MOSFET qui claque reste passant.**

L'arrêt d'urgence est aujourd'hui logiciel : un ESP32 planté laisse la broche
tourner. Avec un MOSFET, ce défaut devient une panne franche.

**Le contact NF de l'arrêt d'urgence doit être en série sur la puissance de la
broche avant toute mise sous tension du nouveau montage.** Aucun développement
logiciel de ce plan ne passe avant.

---

## 3. Les quatre couches

| Couche | Rôle | État |
|---|---|---|
| **0. Perception** | mesurer : courant broche, géométrie du brut, température | **à construire** |
| **1. Décision déterministe** | générateurs, validateurs, contrôle adaptatif | partielle |
| **2. Apprentissage** | signature normale, anomalie, recommandation | à construire |
| **3. Interface** (LLM) | intention → stratégie ; explication ; pédagogie | **finie** |

La couche 3 n'a besoin d'aucun outil supplémentaire.

---

## 4. Phases

### Phase 0 — Collecter (immédiat, ~1 semaine)

Sans matériel, dès le prochain usinage. **Le seul poste où le retard est
irrécupérable** : les données non collectées en septembre n'existeront jamais.

Une **fiche d'usinage** persistée par programme : identité et empreinte du
G-code ; intention (outil, matériau, `ap`/`ae`/`F`, lus dans l'en-tête que les
générateurs écrivent déjà) ; prévision (durée, enveloppe) ; réel (durée, ligne
atteinte, cause d'arrêt) ; incidents (alarmes, blocages, redémarrages,
**overrides avec leur valeur**) ; verdict opérateur.

Deux correctifs au journal :
[`activity_log_provider.dart:61`](lib/application/providers/activity_log_provider.dart:61)
enregistre `'Override modifié'` **sans la valeur**, et la ligne 42 fait taire le
journal pendant tout l'usinage — précisément la fenêtre utile.

### Phase 1 — Sentir la coupe (octobre)

Le courant de broche est le signal le moins cher et le plus temps-réel pour
surveiller un outil. Un capteur à effet Hall (ACS712, quelques euros) sur la
ligne d'alimentation suffit.

- **Acquisition sur un microcontrôleur dédié**, pas dans FluidNC : on ne
  fragilise pas le contrôleur qui fonctionne. Même schéma que l'ESP32-CAM.
- **Détection de casse** : effondrement du courant → arrêt immédiat.
- **Détection d'usure** : dérive du courant à conditions égales.
- **Signature par couple outil/matériau**, enregistrée dans la fiche d'usinage.

Priorité assumée : dans un atelier où une fraise met trois semaines à arriver,
**ne pas casser l'outil vaut plus que gagner 10 % de temps de cycle**.

### Phase 2 — Reconnaître le brut (octobre-novembre)

Objectif : poser le zéro et **garantir qu'aucun mouvement ne sortira des
courses** avant de lancer.

Deux capteurs, deux rôles — l'un ne remplace pas l'autre :

| | Rôle | Précision |
|---|---|---|
| **Caméra** (ESP32-CAM, déjà en place) | présence, forme, centre approximatif, orientation | ~1–2 mm après calibration |
| **Palpeur** (`G38.2`, déjà dans l'app) | zéro pièce, hauteur, arêtes | 0,01–0,02 mm |

**Les ultrasons ne conviennent pas à cet usage** : résolution 3 mm, précision
±3 mm, cône d'émission de 15° qui couvre le brut entier. Utiles pour détecter
une présence ou un obstacle, pas pour poser une origine — l'écart avec le
palpage est d'un facteur 150 à 300.

Séquence visée : la caméra estime où est la matière → le palpage confirme aux
points utiles → l'origine est posée → le validateur compare l'enveloppe du
programme aux courses **et au brut réel** → refus motivé si ça ne rentre pas.

C'est le garde-fou qui manque aujourd'hui : le validateur connaît les courses
machine, pas la pièce posée.

### Phase 3 — Contrôle adaptatif (novembre)

Une fois la signature normale connue, ajuster **l'avance en temps réel** pour
maintenir une charge de coupe constante — c'est le principe du contrôle
adaptatif industriel. Le mécanisme existe déjà : les overrides GRBL, que l'app
envoie et que le journal intercepte.

Avec le MOSFET, la **vitesse de broche** devient un second levier.

Gains rapportés dans la littérature industrielle : 10 à 30 % de temps de cycle
en moins, **+40 % de durée de vie d'outil**. À vérifier sur notre machine, pas à
reprendre comme promesse.

### Phase 4 — Apprendre (novembre et au-delà)

**Détection d'anomalie entraînée uniquement sur des signaux normaux.** C'est le
cadre qui convient à notre situation : on n'aura jamais cinquante exemples de
fraise cassée — et on ne veut pas les provoquer — mais on peut accumuler des
heures de coupe normale. Cette approche résout le déséquilibre de classes.

Puis : recommandation de conditions de coupe par l'historique, écart prévu/réel
comme signal de bridage, alerte thermique avant redémarrage (les données
existent : 24 min avec broche, 35 min sans, aucun en environnement refroidi).

---

## 5. Ce qui rend cet axe défendable

Le contrôle adaptatif et la surveillance d'outil existent en industriel, à des
prix industriels. Sur un contrôleur ouvert à 8 $, la combinaison capteur de
courant + GRBL/ESP32 + avance adaptative est décrite comme un projet spécialisé
qui demanderait des modifications de firmware — **autrement dit, elle n'existe
pas.**

Et elle répond aux contraintes réelles du contexte visé, dans l'ordre :

1. survivre aux interruptions (électricité) ;
2. ne pas casser l'outil (consommables rares et chers) ;
3. s'adapter à *cette* machine (matériel hétérogène, aucune table ne la décrit) ;
4. former l'opérateur ;
5. se passer de CAO.

---

## 6. Critères de succès — fin novembre

| Critère | Cible |
|---|---|
| Fiches d'usinage | ≥ 30, dont ≥ 10 avec verdict opérateur |
| Casse d'outil détectée | arrêt automatique démontré sur essai provoqué |
| Reconnaissance de brut | origine posée sans intervention, refus motivé si hors course |
| Autonomie réseau | démonstration complète sans Internet |
| Sécurité | E-STOP matériel câblé en série sur la puissance |
| Tests | maintenus au vert (253 aujourd'hui) |

---

## 7. Ce qu'on arrête

- Ajouter des outils à l'agent — 33 suffisent, chacun coûte du contexte.
- Ajouter des fonctionnalités à l'application.
- Chercher à faire produire du G-code par le modèle.

---

## 8. Risques

| Risque | Parade |
|---|---|
| MOSFET claqué = broche incontrôlable | E-STOP matériel **avant** la mise sous tension |
| Le temps est absorbé par MIT et Wadhwani | La phase 0 est courte et se suffit ; les autres sont indépendantes |
| Trop peu de données pour apprendre | Collecte immédiate ; 30 fiches suffisent à démontrer |
| Le capteur de courant bruite ou sature | Étalonner à vide d'abord ; le signal utile est la *variation*, pas la valeur absolue |
| Redémarrages thermiques | Refroidissement ; sinon `tool/split_program.dart` |

---

## Références

- [GLLM: Self-Corrective G-Code Generation using LLMs](https://www.researchgate.net/publication/388495250_GLLM_Self-Corrective_G-Code_Generation_using_Large_Language_Models_with_User_Feedback)
- [Deep Anomaly Detection for CNC Cutting Tool Using Spindle Current Signals](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7506642/)
- [CNC Tool Wear Monitoring Methods: Load, Acoustic, and Probe](https://industrialmonitordirect.com/blogs/knowledgebase/cnc-tool-wear-monitoring-methods-load-acoustic-and-probe)
- [Tool Wear Condition Monitoring Systems — Caron Engineering](https://www.caroneng.com/tool-wear-condition-monitoring-systems/)
- [L'IA dans l'usinage CNC — StyleCNC](https://fr.stylecnc.com/blog/ai-powered-cnc-machining.html)
