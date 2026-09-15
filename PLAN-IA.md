# Plan IA — une machine qui sent ce qu'elle coupe

État au 9 septembre 2026. Horizon court : sélection des 50 solutions, dernière
semaine de novembre 2026. Horizon long : le pipeline « du dessin au copeau ».

Complète [`ARCHITECTURE.md`](ARCHITECTURE.md), qui décrit la frontière entre
l'IA et le calcul déterministe.

---

## 1. Le fil conducteur

Deux mouvements, et tout le reste s'y rattache :

```
   PERCEVOIR                                    TRANSFORMER
   ce que la machine fait          géométrie  ←→  parcours d'outil
```

**Percevoir** — charge de coupe, géométrie réelle du brut, dérive thermique,
écart prévu/réel. Ce que la machine ne mesure pas, aucun modèle ne peut le
deviner : **la perception vient avant l'intelligence**.

**Transformer** — la chaîne entre une forme et un parcours, dans les deux sens.
Elle est déjà à moitié construite :

| Étape | État |
|---|---|
| paramètres → parcours | `gen_dome.dart`, `gen_sphere_finish.dart` ✔ |
| parcours → géométrie | `extract_profile.dart` ✔ — 0,3 µm |
| profil → parcours | **manquant** — le chaînon |
| STEP/STL → parcours | objectif « zéro-clic » |

Le pipeline « charger un dessin, obtenir du G-code » n'est donc pas un nouveau
projet : c'est le dernier maillon d'une chaîne aux trois quarts posée.

### Ce que le modèle de langage ne fait jamais

L'agent ne produit aucune coordonnée. Position tranchée par la littérature, pas
par préférence : `GLLM` (*Self-Corrective G-Code Generation using LLMs*) fait
exactement cela, et les travaux sur le sujet documentent hallucinations
sémantiques, erreurs de syntaxe et absence de garantie d'exécution — avec un
parallèle explicite aux automates industriels, où de telles erreurs sont
dangereuses.

Corollaire pour le pipeline : **lissage cinématique, calcul d'engagement et
détection de collision restent déterministes.** Ce sont des problèmes résolus
(splines, quaternions/SLERP, filtrage à jerk limité, géométrie exacte), avec
garanties — là où un réseau donnerait une probabilité, sans données pour
l'entraîner.

---

## 2. Sécurité — préalable non négociable

Le passage du relais au **MOSFET** est justifié : PWM, donc vitesse de broche
variable, donc contrôle adaptatif complet. Mais il change le mode de
défaillance.

> **Un relais qui lâche s'ouvre. Un MOSFET qui claque reste passant.**

**Le contact NF de l'arrêt d'urgence doit être en série sur la puissance avant
toute mise sous tension du nouveau montage.** Aucun développement de ce plan ne
passe avant.

---

## 3. Les quatre couches

| Couche | Rôle | État |
|---|---|---|
| **0. Perception** | courant broche, géométrie du brut, température | à construire |
| **1. Décision déterministe** | générateurs, validateurs, contrôle adaptatif, CAM | partielle |
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
surveiller un outil. Capteur à effet Hall (ACS712) sur la ligne d'alimentation.

- **Acquisition sur un microcontrôleur dédié**, pas dans FluidNC : on ne
  fragilise pas le contrôleur qui fonctionne. Même schéma que l'ESP32-CAM.
- Détection de **casse** (effondrement du courant) et d'**usure** (dérive à
  conditions égales).
- Signature par couple outil/matériau, enregistrée dans la fiche d'usinage.

Priorité assumée : dans un atelier où une fraise met trois semaines à arriver,
**ne pas la casser vaut plus que gagner 10 % de temps de cycle**.

### Phase 2 — Reconnaître le brut (octobre-novembre)

Poser le zéro et **garantir qu'aucun mouvement ne sortira des courses ni du
brut** avant de lancer.

| | Rôle | Précision |
|---|---|---|
| **Caméra** (ESP32-CAM, en place) | présence, forme, centre, orientation | ~1–2 mm |
| **Palpeur** (`G38.2`, dans l'app) | zéro pièce, hauteur, arêtes | 0,01–0,02 mm |

**Les ultrasons ne conviennent pas** : résolution 3 mm, précision ±3 mm, cône de
15° couvrant le brut entier — un facteur 150 à 300 face au palpage. Utiles pour
détecter une présence ou un obstacle, pas pour poser une origine.

Séquence : la caméra estime où est la matière → le palpage confirme aux points
utiles → l'origine est posée → le validateur compare l'enveloppe du programme
aux courses **et au brut réel** → refus motivé si ça ne rentre pas.

C'est le garde-fou manquant : le validateur connaît les courses machine, pas la
pièce posée.

### Phase 3 — Contrôle adaptatif (novembre)

Ajuster **l'avance en temps réel** pour maintenir une charge de coupe
constante. Le mécanisme existe déjà : les overrides GRBL, que l'app envoie et
que le journal intercepte. Avec le MOSFET, la vitesse de broche devient un
second levier.

Gains rapportés dans la littérature industrielle : 10 à 30 % de temps de cycle
en moins, +40 % de durée de vie d'outil. À vérifier sur notre machine, pas à
reprendre comme promesse.

### Phase 4 — Apprendre (novembre et au-delà)

**Détection d'anomalie entraînée uniquement sur des signaux normaux.** C'est le
cadre qui convient : on n'aura jamais cinquante exemples de fraise cassée — et
on ne veut pas les provoquer — mais on peut accumuler des heures de coupe
normale. Cette approche résout le déséquilibre de classes.

Puis : recommandation de conditions par l'historique, écart prévu/réel comme
signal de bridage, alerte thermique avant redémarrage.

### Phase 5 — Du dessin au copeau (décembre et au-delà)

Objectif : charger un `.step` ou `.stl` et obtenir un programme exécutable sans
intervention. **À faire après la sélection** — c'est un chantier de plusieurs
mois, et rien ici ne fait passer novembre.

Trois paliers, du plus court au plus général :

**5.a — Générateur à profil libre.** Remplacer, dans `gen_dome.dart`, la formule
de sphère par une interpolation dans une liste de points. Petit, et il ferme
enfin la boucle `G-code → profil → modification → G-code`. **C'est le chaînon
manquant, et il peut se faire dès que du temps se libère.**

**5.b — STEP de révolution → parcours.** Pour une pièce de révolution — le point
fort de la cinématique trunnion — le chemin est court : lire le STEP avec
pythonOCC, détecter l'axe de révolution, extraire le profil méridien, appeler
le générateur de 5.a. **Aucun moteur CAM générique n'est nécessaire.** C'est un
pipeline « zéro-clic » démontrable des mois avant le cas général.

**5.c — Cas général.** Reconnaissance de formes et stratégies multiples, via
FreeCAD CAM piloté en Python.

---

## 5. Architecture du pipeline CAO → parcours

### Ce qu'on n'utilise pas, et pourquoi

**SolidWorks CAM est écarté.** SOLIDWORKS CAM Standard est inclus avec une
licence CAD **sur abonnement actif** : chaque poste exigerait une licence à
plusieurs milliers d'euros par an, sans redistribution possible. C'est
incompatible avec la proposition du projet — un contrôleur à 8 $ pour
démocratiser la fabrication de précision. Un jury verrait la contradiction
immédiatement.

Accessoirement, le mode « headless » n'existe pas vraiment : masquer une
application desktop n'en fait pas un moteur serveur.

### Les briques retenues

| Besoin | Outil | Licence |
|---|---|---|
| STEP, géométrie exacte | **pythonOCC / OpenCASCADE** | LGPL |
| STL, maillage | **trimesh** | MIT |
| Parcours, cas général | **FreeCAD CAM** (`freecadcmd`) | LGPL |
| API Python sur Path | **ocp-freecad-cam** | open source |

FreeCAD CAM a un atout décisif ici : **ses post-processeurs sont des scripts
Python**, donc adaptables à notre dialecte FluidNC exact — avance en degrés,
courses réelles, absence de RTCP.

### Le pont Flutter ↔ Python

Réutilisable quel que soit le moteur géométrique, donc **la première brique à
construire quand la phase 5 démarre** — ou plus tôt, puisqu'elle sert aussi à
héberger le modèle local et le traitement d'image.

- **gRPC sur `localhost`**, en streaming pour les fichiers volumineux : un STL
  se découpe en messages plutôt que de saturer la mémoire.
- Le serveur Python est lancé comme processus enfant par l'application, et
  meurt avec elle.
- Packaging : PyInstaller en `--onedir` (pas `--onefile` : le démarrage est bien
  plus rapide, et les DLL natives d'OpenCASCADE et CUDA s'y comportent mieux),
  embarqué dans les assets Windows de Flutter.

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

La phase 5 ne figure pas dans ces critères — délibérément.

---

## 7. Ce qu'on arrête

- Ajouter des outils à l'agent — 33 suffisent, chacun coûte du contexte.
- Ajouter des fonctionnalités à l'application.
- Chercher à faire produire du G-code par le modèle.
- **Confier à un réseau ce qu'un algorithme déterministe résout mieux** :
  lissage, engagement, collision.

---

## 8. Risques

| Risque | Parade |
|---|---|
| MOSFET claqué = broche incontrôlable | E-STOP matériel **avant** la mise sous tension |
| Le temps est absorbé par MIT et Wadhwani | Phases 0 à 4 indépendantes ; la phase 5 attend décembre |
| Trop peu de données pour apprendre | Collecte immédiate ; 30 fiches suffisent à démontrer |
| Capteur de courant bruité ou saturé | Étalonner à vide ; le signal utile est la *variation* |
| Redémarrages thermiques | Refroidissement ; sinon `tool/split_program.dart` |
| La phase 5 dévore le temps des phases 0 à 4 | Elle est datée décembre, et hors critères de novembre |

---

## Références

- [GLLM: Self-Corrective G-Code Generation using LLMs](https://www.researchgate.net/publication/388495250_GLLM_Self-Corrective_G-Code_Generation_using_Large_Language_Models_with_User_Feedback)
- [Deep Anomaly Detection for CNC Cutting Tool Using Spindle Current Signals](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7506642/)
- [CNC Tool Wear Monitoring Methods](https://industrialmonitordirect.com/blogs/knowledgebase/cnc-tool-wear-monitoring-methods-load-acoustic-and-probe)
- [Tool Wear Condition Monitoring — Caron Engineering](https://www.caroneng.com/tool-wear-condition-monitoring-systems/)
- [L'IA dans l'usinage CNC — StyleCNC](https://fr.stylecnc.com/blog/ai-powered-cnc-machining.html)
- [SOLIDWORKS CAM Licensing](https://www.cati.com/blog/solidworks-cam-licensing/)
- [FreeCAD CAM — Path Workbench](https://freecad-app.com/cam/)
- [ocp-freecad-cam](https://pypi.org/project/ocp-freecad-cam)
