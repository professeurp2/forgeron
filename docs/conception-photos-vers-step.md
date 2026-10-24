# De la photo au STEP — conception

*24 octobre 2026. Document de conception, **avant tout code**. Il décrit comment produire un fichier STEP à partir de photos, pour le remettre à l'adaptateur STEP→G-code déjà validé sur machine (3 axes et 3+2, essais à vide). Rien de ce qui suit n'est encore implémenté ; les versions des outils et les chiffres de performance seront **mesurés** au premier jalon, pas supposés ici.*

**Matériel de calcul retenu** : PC Windows avec GPU NVIDIA ≥ 8 Go de VRAM, sur le réseau local. **Les deux cas d'usage** sont visés (reproduire une pièce réelle *et* générer une forme depuis des images concept). Le téléphone se connecte directement au PC pour téléverser les images — pas de contrainte réseau, c'est déjà du tout-local.

---

## 0. Le problème, en une phrase

L'application sait déjà aller de **STEP → G-code**. Ce document ajoute l'amont manquant : **images → STEP**, pour fermer la chaîne *« je photographie une pièce (ou je dessine une forme) → je l'usine »*.

Le mobile reste le poste de l'opérateur ; le PC n'est qu'un **nœud de calcul** joignable sur le réseau local. On ne déplace pas l'application sur le PC : on déporte seulement le calcul lourd, comme pour l'agent IA.

---

## 1. Principe — le mobile capture, le PC calcule

```mermaid
flowchart LR
  subgraph Tel["Téléphone — application Forgeron"]
    CAP["Capture guidée<br/>photos + mire d'échelle"] --> UP["Téléversement"]
    SUIVI["Suivi du job<br/>+ aperçu du STEP"]
  end
  subgraph PC["PC Windows — service local reco3d (GPU ≥ 8 Go)"]
    API["API HTTP<br/>file de jobs, 1 GPU à la fois"]
    API --> PHOTO["Chaîne photogrammétrie<br/>Meshroom / COLMAP"]
    API --> GEN["Chaîne générative<br/>TRELLIS / SF3D"]
    PHOTO --> NET["Nettoyage maillage<br/>Open3D / MeshLab"]
    GEN --> NET
    NET --> STEP["Export STEP<br/>FreeCAD headless"]
  end
  UP -->|"WiFi local"| API
  STEP -->|"WiFi local"| SUIVI
  SUIVI --> ADAPT["Adaptateur STEP→G-code<br/>(existant, validé machine)"]
```

**Pourquoi déporter.** Aucun de ces moteurs (Meshroom, TRELLIS, SF3D, FreeCAD) ne tourne sur Android : ni VRAM, ni CUDA, ni FreeCAD. Le téléphone fait trois choses seulement — capturer, suivre, afficher — et remet ensuite le STEP à l'adaptateur existant.

**Phase indépendante du pilotage.** La capture→STEP se fait pendant que le téléphone est sur le réseau du PC ; l'usinage se fait plus tard sur l'AP de l'ESP32. Les deux phases ne cohabitent pas : pas de conflit réseau à gérer.

---

## 2. Pile technique retenue

| Besoin | Moteur | Pourquoi ce choix |
|---|---|---|
| **Pièce réelle (métrique)** | **Meshroom** (AliceVision, CLI `meshroom_batch`) + CUDA | 100 % mesure, n'invente aucune géométrie cachée → conforme à *« jamais de données inventées »*. Repli scriptable : **COLMAP + OpenMVS**. |
| **Forme depuis images concept** | **TRELLIS** (Microsoft) en primaire · **SF3D** (Stability) en mode rapide | TRELLIS = meilleure géométrie locale sur peu d'images ; SF3D quasi instantané pour les essais. Les deux tiennent dans 8 Go. |
| **Nettoyage du maillage** | **Open3D** / **MeshLab** (CLI) | Décimation, bouchage de trous, lissage, suppression des îlots avant la CAO. |
| **Maillage → STEP** | **FreeCAD 1.0 headless** (`freecadcmd` + script Python) | *shape-from-mesh* → solide → export STEP, sans interface. |
| **Service** | **FastAPI** (Python) sur le PC | API HTTP, file de jobs, un seul job GPU à la fois. |

*Les numéros de version exacts sont épinglés au jalon 0 (Meshroom, FreeCAD, TRELLIS, pilotes CUDA) et consignés dans le dépôt du service.*

---

## 3. Les deux chaînes

### 3.1 Chaîne photogrammétrie — reproduire une pièce réelle

Entrée : 20 à 40 photos qui tournent autour de l'objet, recouvrement ≥ 60 %, lumière diffuse, fond neutre, **une mire d'échelle** dans le champ.

```
photos ─▶ Meshroom (SfM → MVS → maillage dense) ─▶ maillage texturé .obj
      ─▶ Open3D (décimation, trous, lissage) ─▶ maillage propre
      ─▶ FreeCAD headless (shape-from-mesh → solide) ─▶ .step
```

- **Métrique** : AliceVision cale l'échelle réelle à partir de marqueurs (ArUco/CCTag) ou d'un segment de longueur connue. Sans mire, le STEP est **sans cote** et marqué comme tel.
- **Fidèle** : pas de géométrie inventée ; ce qui n'a pas été vu reste un trou, signalé, jamais comblé d'office.

### 3.2 Chaîne générative — une forme depuis des images concept

Entrée : 1 à 4 images (croquis, photo d'inspiration).

```
images ─▶ TRELLIS (ou SF3D) ─▶ maillage .glb
       ─▶ Open3D (nettoyage) ─▶ FreeCAD headless ─▶ .step
```

- **Rapide**, utile pour l'exploration de forme (usage forgeron : pièces organiques, ornements).
- **Forme inventée, sans échelle fiable** : la pièce est marquée **« forme approximative »**. L'opérateur fixe la cote réelle d'une arête dans Forgeron avant tout usinage. À ne pas utiliser pour une pièce fonctionnelle à cote.

---

## 4. Trois points durs (à ne pas se cacher)

### 4.1 Le STEP sera *facetté*, pas paramétrique

Reconstruire une vraie B-rep propre (faces planes, cylindres, congés identifiés) **en automatique n'existe pas en open-source**. Ce qu'on produit est un **solide tessellé** : la peau triangulée emballée en volume. C'est du STEP valide, mais lourd (des milliers de facettes).

**Risque** : l'adaptateur STEP→G-code pourrait refuser ce STEP ou sortir des parcours démesurés. **C'est la seule vraie inconnue du projet.** → Jalon 0 (spike) la tranche avant tout code dans l'application. Si le STEP facetté ne passe pas, on ajoute un **chemin maillage → STL → CAM direct**, sans passer par STEP.

### 4.2 L'échelle (vital pour usiner)

Une photo n'a pas de cote. En photogrammétrie, **mire imprimée** (ArUco/ChArUco) ou réglet dans la scène → échelle réelle automatique. En génératif, **pas d'échelle** : Forgeron demande la cote réelle d'une arête et marque la pièce « approximative ».

### 4.3 Le métal brillant

Les pièces de forgeron réfléchissent : la photogrammétrie y troue le maillage. **Matifier avant de photographier** (spray/poudre développante, talc) ; lumière diffuse, pas de reflet spéculaire. À documenter dans l'écran de capture comme consigne, pas comme option.

---

## 5. Règles d'honnêteté (alignées sur l'application)

- **Rien d'inventé affiché comme mesuré** : une pièce générative porte le marquage « forme approximative » ; une reconstruction sans mire porte « sans échelle ». Un trou non reconstruit est signalé, jamais comblé en silence.
- **Chaque STEP porte sa provenance** : chaîne utilisée (photogrammétrie / génératif), moteur + version, présence d'une mire, facteur d'échelle, nombre de photos. Écrit à côté du fichier, visible dans Forgeron.
- **Les chiffres de qualité seront mesurés** (écart dimensionnel sur une pièce étalon, taux de trous), pas affirmés.

---

## 6. Service `reco3d` — contrat d'API (ébauche)

Dossier séparé (p. ex. `tools/reco3d/`), **brique modulaire** améliorable seule, comme les skills de l'agent.

| Route | Rôle |
|---|---|
| `POST /jobs` | photos (ou images) + mode (`photo`/`gen`) + référence d'échelle → identifiant de job |
| `GET /jobs/{id}` | état et progression (file → SfM → MVS → maillage → STEP) |
| `GET /jobs/{id}/result` | le STEP + sa fiche de provenance |
| `GET /health` | le service et le GPU sont prêts |

File d'attente : **un seul job GPU à la fois** (les reconstructions saturent la VRAM). Les jobs et leurs entrées sont conservés pour rejouer et comparer.

---

## 7. Intégration côté Forgeron (mobile)

- **Écran « Scan 3D »** : capture guidée (orbite, nombre de photos, consigne matifiant + mire), téléversement, barre de progression, aperçu du STEP, puis **remise à l'adaptateur STEP→G-code existant**.
- **Client Dart** de l'API `reco3d` (adresse du PC réglable, comme l'IP de l'ESP32).
- **Mode génératif** : étape obligatoire « fixer la cote réelle » + marquage « approximative ».

---

## 8. Plan par phases

| Phase | Contenu | Sortie | Touche l'app ? |
|---|---|---|---|
| **0 — Spike anti-risque** | Une pièce réelle → Meshroom manuel → OBJ → FreeCAD → STEP → **adaptateur existant**. Mesurer : le STEP passe-t-il ? taille des parcours ? Épingler les versions. | **Décision** : STEP facetté viable, ou chemin mesh→CAM à ajouter | Non |
| **1 — Service, chaîne photo** | `meshroom_batch` + nettoyage + `freecadcmd` export STEP + FastAPI + file + échelle par mire | Service `reco3d` photogrammétrie | Non |
| **2 — Chaîne générative** | TRELLIS/SF3D ajouté comme 2ᵉ mode (GLB → même sortie), marquage « approximative » | Service à deux modes | Non |
| **3 — Intégration Forgeron** | Écran de capture + client API + progression + remise à l'adaptateur | Chaîne mobile de bout en bout | Oui |
| **4 — Durcissement** | Validation d'échelle sur étalon, cache des jobs, gestion du métal brillant, tolérances | Preuves chiffrées | Oui |

**On commence par la phase 0** : c'est rapide, ça ne touche pas l'application, et ça lève la seule vraie inconnue avant de construire dessus.

---

## 9. Critères d'acceptation

| Jalon | Critère |
|---|---|
| Phase 0 | Un STEP issu de photos est **ouvert et transformé en parcours** par l'adaptateur existant, OU l'échec est documenté et le chemin mesh→CAM décidé. Verdict écrit, avec la pièce test. |
| Phase 1 | Sur une pièce étalon avec mire : écart dimensionnel **mesuré** (mm) ; le STEP porte son facteur d'échelle. |
| Phase 3 | De bout en bout depuis le téléphone, sans ligne de commande, en moins de N minutes (N mesuré). |
| Toutes | Chaque STEP porte sa fiche de provenance ; aucune cote affichée comme sûre sans mire. |

---

## 10. Questions ouvertes

- **Meshroom CLI vs COLMAP+OpenMVS** : lequel donne le maillage le plus propre sur nos pièces (tranché au jalon 1 par mesure).
- **Tolérance de l'adaptateur au STEP facetté** : nombre de facettes acceptable avant explosion des parcours (jalon 0).
- **Mire** : format exact (ArUco seul, ou planche ChArUco), taille imprimée, procédure de pose.
- **Pièces fonctionnelles à cote serrée** : la chaîne facettée suffit-elle, ou faut-il une reprise manuelle de surfaces dans FreeCAD pour ces cas ? (à décider après le jalon 1, sur mesure réelle).
