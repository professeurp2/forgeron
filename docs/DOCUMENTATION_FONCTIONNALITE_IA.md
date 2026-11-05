# Documentation Spécialisée et Ultra-Détaillée : Architecture Multi-Agents et Modèles Locaux Ollama

*Projet de Fin d'Études (PFE) — ENI*  
*Modules clés : `lib/application/services/local_ai_agent_service.dart`, `lib/application/services/ollama_discovery.dart`, `lib/application/services/tool_router.dart`, `lib/application/providers/ai_lexicon_front.dart`*  
*Dernière mise à jour : Mai 2026*

---

# 🎯 1. STRATÉGIE DE TRANSITION : DU CLOUD EN-LIGNE AUX AGENTS LOCAUX OLLAMA

## 1.1 Pourquoi le Passage au Tout-Local sur l'Atelier ?
L'intégration initiale d'API distantes Cloud (ex. Gemini) présentait deux verrous majeurs en environnement industriel :
1. **Isollement Réseau de la CNC** : L'ESP32 FluidNC crée son propre réseau WiFi local d'atelier sans accès Internet.
2. **Confidentialité & Résilience Réseau** : Les fichiers CAO/STEP, pièces clients et données d'usinage ne doivent pas quitter l'atelier, et l'assistant doit fonctionner à 100% sans connexion 4G/5G ni clé API payante.

Forgeron est donc désormais structuré autour d'un **moteur local d'inférence Ollama** (`LocalAiAgentService`), exécutant des modèles personnalisés légers (ex. `forgeron-qwen` dérivé de `qwen2.5` via `tool/ollama/Modelfile`) directement sur un PC ou serveur d'atelier sur le port `11434`.

---

# 🤖 2. ARCHITECTURE MULTI-AGENTS SPÉCIALISÉS

Plutôt que de confier l'ensemble des tâches à un prompt monolithique lourd qui saturerait la fenêtre de contexte du modèle local (ex. 4096 jetons par défaut sur Ollama), Forgeron s'appuie sur une **Architecture Multi-Agents distribuée et spécialisée** :

```
                               ┌───────────────────────────┐
                               │     Opérateur / IHM       │
                               └─────────────┬─────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       ▼                                           ▼
          ┌───────────────────────────┐               ┌───────────────────────────┐
          │  1. Agent Gardien Front   │               │   2. Agent Vision VLM     │
          │  (Lexique / Sécurité)     │               │   (Inspection Visuelle)   │
          └────────────┬──────────────┘               └────────────┬──────────────┘
                       │                                           │
                       ▼                                           ▼
          ┌───────────────────────────┐               ┌───────────────────────────┐
          │  3. Agent Routeur d'Outils│               │  5. Agent Scan 3D / CAM   │
          │     (ToolRouter)          │               │  (Reconstruction STEP)    │
          └────────────┬──────────────┘               └───────────────────────────┘
                       │
                       ▼
          ┌───────────────────────────┐
          │  4. Agent Orchestrateur   │
          │   CNC (Local LLM Ollama)  │
          └───────────────────────────┘
```

---

## 2.1 Description des 5 Agents Spécialisés

### 🛡️ Agent 1 : Gardien Front & Filtre de Sécurité (`ai_lexicon_front.dart`)
- **Type** : Agent Déterministe / Analyseur Syntaxique Multilingue (15 langues dont le Français, l'Anglais et le Bambara).
- **Rôle** : Intercepte TOUS les messages de l'opérateur **avant** de consulter le modèle LLM.
- **Fonctionnalités** :
  - **Circuit Court E-STOP** : Si l'opérateur demande un arrêt d'urgence, l'Agent Gardien déclenche immédiatement l'arrêt matériel sans consulter de réseau de neurones.
  - **Détection Question / Négation** : Si le message est une question ("Quelle est la position ?") ou une négation ("Ne fais pas de homing"), l'Agent verrouille le tour en **Lecture Seule (`_readOnlyTurn = true`)** : aucun outil de mouvement/modification ne sera accessible à l'Agent Orchestrateur pour ce tour.
  - **Génération de Carte de Confirmation (`AiPendingToolCall`)** : Exige une validation explicite de l'opérateur pour toute action à risque, en affichant l'explication traduite dans sa langue.

### 🧭 Agent 3 : Routeur Dynamique d'Outils (`ToolRouter` - `tool_router.dart`)
- **Problématique** : Déclarer les 38+ outils de l'application à un modèle local consomme ~4800 jetons de contexte fixes par tour, ce qui dépasse le contexte alloué par Ollama (4096 jetons).
- **Rôle** : L'Agent Routeur analyse la demande de l'opérateur et **sélectionne dynamiquement un sous-ensemble d'outils pertinents** (Groupes d'outils) pour le tour en cours.
- **Résultat** : La taille du prompt d'outils est divisée par 4, permettant au modèle local de répondre avec une vitesse élevée et une précision maximale.

### ⚙️ Agent 4 : Orchestrateur CNC Principal (`LocalAiAgentService` / `forgeron-qwen`)
- **Type** : Modèle LLM Local servi par Ollama (ex. `forgeron-qwen` / `qwen2.5:7b`).
- **Rôle** : Reçoit le contexte réducteur du Routeur d'Outils, analyse l'état réel de la machine (`liveStateBlock`), consulte les fiches RAG (`docCorpusProvider`) et orchestre la gestion des fichiers G-code, le diagnostic des alarmes et l'assistance à l'usinage.

### 👁️ Agent 2 : Inspection Visuelle & Vision VLM (`_ensureVisionService()`)
- **Type** : Modèle VLM Local (ex. `llava`, `qwen2-vl` ou `bakllava` servi par Ollama).
- **Rôle** : Dédié spécifiquement au traitement des images (photos prises par la caméra de l'ESP32-CAM ou téléversées par l'opérateur).
- **Isolation** : S'exécute sur son propre pipeline pour ne pas encombrer le fil de discussion textuel standard.

### 📐 Agent 5 : Reconstruction 3D & Synthèse CAM (`Reco3dClient` / `step_pipeline_service.dart`)
- **Type** : Agent Géométrique & Pipeline Python/OpenCASCADE (`pipeline/*.py`).
- **Rôle** :
  - Analyse les fichiers CAD 3D `.step` ou les nuages de points issus de la numérisation en machine (`start_machine_scan`).
  - Extrait les primitives géométriques (surfaces de révolution, poches, perçages).
  - Synthétise automatiquement le parcours d'outil 5-axes optimisé sans solliciter le LLM pour le calcul des coordonnées.

---

# 🔎 3. DÉCOUVERTE AUTOMATIQUE ET DIAGNOSTIC DES SERVEURS OLLAMA

Pour simplifier l'installation en atelier sans configuration IP complexe, Forgeron intègre le service `OllamaDiscovery` (`lib/application/services/ollama_discovery.dart`) :

## 3.1 Découverte Réseau Récursive (`scan()`)
- Scanne les adresses du sous-réseau local (port `11434`) à la recherche de serveurs Ollama actifs.
- Interroge l'endpoint `/api/tags` pour dresser la liste des modèles installés sur le PC de l'atelier.

## 3.2 Diagnostic et Recommandation Automatique
- **`diagnose()`** : Analyse la joignabilité du serveur, la présence de la variable d'environnement `OLLAMA_HOST=0.0.0.0` et vérifie si la taille du contexte allouée par Ollama est suffisante.
- **`recommend()`** : Identifie automatiquement le meilleur modèle installé (priorité à `forgeron-qwen` ou `qwen2.5`).
- **`recommendVision()`** : Identifie le modèle de vision le plus adapté parmi les modèles Ollama disponibles.

---

# 🛡️ 4. SÉCURITÉ ET GARDE-FOUS DES MODÈLES LOCAUX

L'utilisation de modèles locaux plus légers (ex. 7 milliards de paramètres) a nécessité la mise en place de garde-fous spécifiques dans `LocalAiAgentService` contre 4 défaillances mesurées :

1. **Dérive Linguistique (Rappel au Français / Langue Active)** : Si un modèle local dérive vers du texte en chinois ou anglais, l'adaptateur détecte le saut et rappelle la directive linguistique active.
2. **Appels d'Outils Écrits en Texte Brut** : Si le modèle écrit l'appel de fonction sous forme de texte ("J'appelle l'outil jog_axis...") au lieu de produire la structure JSON `functionCall`, l'adaptateur `LocalAiAgentService` intercepte la chaîne par regex et la convertit en vrai appel d'outil structurel.
3. **Prévention des Données Périmées (`liveStateBlock`)** : Le prompt système est reconstruit à chaque tour avec les coordonnées et le statut machine de l'instant T. L'agent est contraint de rappeler un outil de lecture s'il a besoin d'une confirmation de mouvement.
4. **Validation des Butées Machine** : Tout appel d'outil de mouvement généré par un agent est filtré par `TrajectoryValidator` et `ForceGuard` avant envoi à l'ESP32.

---

# 📊 5. TABLEAU COMPARATIF DES AGENTS MULTI-AGENTS

| Agent | Module Dart / Service | Modèle / Technologie | Rôle Principal |
| :--- | :--- | :--- | :--- |
| **Agent 1 : Gardien Front** | `ai_lexicon_front.dart` | Lexique Déterministe 15 Langues | Circuit court E-STOP, filtrage question/négation, confirmation action. |
| **Agent 2 : Vision VLM** | `ai_agent_service.dart` | Local VLM (LLaVA / Qwen2-VL) | Inspection photo des outils, copeaux, pièces et alarmes. |
| **Agent 3 : Routeur Outils** | `tool_router.dart` | Algorithme de filtrage contextuel | Réduction de la taille du prompt d'outils (~4800 → ~1000 tokens). |
| **Agent 4 : Orchestrateur** | `local_ai_agent_service.dart` | Ollama (`forgeron-qwen` / `qwen2.5`) | Raisonnement CNC, diagnostic, assistance et gestion de fichiers. |
| **Agent 5 : Scan 3D / CAM** | `step_pipeline_service.dart` | OpenCASCADE / Python Pipeline | Extraction géométrique STEP et génération de parcours 5-axes. |

---

# ⚙️ 6. PARAMÈTRES TECHNIQUES D'INFÉRENCE, DÉTERMINISME ET ANTI-HALLUCINATION

Pour garantir une exploitation sécurisée en environnement industriel de précision (fraisage 5-axes, commande numérique FluidNC), le système d'inférence de Forgeron applique une calibration stricte des hyperparamètres d'échantillonnage et un faisceau de garde-fous déterministes.

---

## 6.1 Calibration des Hyperparamètres d'Échantillonnage

Les coordonnées cartésiennes ($X, Y, Z, A, C$), les numéros d'outil ($T1 \dots T12$) et les codes d'alarme GRBL ($1 \dots 11$) exigent un déterminisme rigoureux : une variation stochastique pourrait entraîner une collision outil-matière.

| Paramètre | Fournisseur Distant (Gemini) | Moteur Local (Ollama / llama.cpp) | Justification Technique |
| :--- | :--- | :--- | :--- |
| **`temperature`** | `0.10` | `0.20` | Évite toute invention stochastique de cotes ou de statuts machines tout en évitant le gel d'inférence. |
| **`top_p` (Nucleus)** | `0.90` | `0.90` | Restreint l'échantillonnage à la masse de probabilité cumulée des 90% meilleurs tokens. |
| **`frequency_penalty`** | — | `0.50` | Pénalise proportionnellement les tokens déjà apparus dans la réponse courante. |
| **`presence_penalty`** | — | `0.30` | Pénalise l'apparition de tout token déjà vu, favorisant la progression de la phrase. |
| **`repeat_penalty`** | — | `1.18` (options Ollama) | Pénalité multiplicative sur les 64 derniers tokens (`repeat_last_n: 64`). |
| **`max_tokens`** | `2048` | `1024` | Borne supérieure évitant l'emballement d'inférence en tâche de fond. |

---

## 6.2 Garde-fou Anti-Dégénérescence : Rupture des Boucles de Répétition

Sur des modèles quantifiés légers exécutés localement (ex. Qwen-2.5 7B en Q4_K_M), un échantillonnage à basse température sans pénalité peut provoquer un effondrement du modèle dans un cycle argmax infini (ex. *« kuma ko kuma ko kuma ko... »* ou *« cnc cnc cnc... »*).

Forgeron intègre un détecteur et disjoncteur algorithmique dans `LocalAiAgentService` :
1. **Détection en Streaming Continu (`findRepetitionLoop`)** :
   À chaque fragment de texte émis en direct, l'algorithme recherche tout motif textuel de longueur comprise entre 2 et 60 caractères se répétant consécutivement au moins 3 fois.
2. **Disjonction Immédiate du Flux (`_stream`)** :
   Dès détection d'une 3ème répétition, la requête streaming HTTP est immédiatement annulée (`break`), la queue dégénérée est élaguée pour ne conserver qu'une seule occurrence propre, et la notification `finishReason = 'STOP'` est émise.
3. **Nettoyage Post-Inférence (`cleanRepetitiveDegeneration`)** :
   Toute réponse globale non-streamée est épurée avant transmission à l'IHM avec la note `'repetition:interrompue'`.

---

## 6.3 Normalisation Acoustique STT & Corpus Waxal (`WaxalVoiceEngine`)

La dictée vocale en atelier bruyant et dans les langues africaines peu dotées induit souvent des confusions phonétiques dans les moteurs STT généralistes du système hôte :

- **Réparation Acoustique CNC** : `WaxalVoiceEngine.normalizeSttInput` répare les artefacts phonétiques français :
  - *« home in »* / *« oミング »* $ightarrow$ `homing`
  - *« j'ai 54 »* $ightarrow$ `G54`
  - *« pal page »* $ightarrow$ `palpage`
  - *« fluid NC »* / *« fluidité »* $ightarrow$ `FluidNC`
- **Réparation Acoustique Bambara / Langues Locales** :
  - *« inicié »* $ightarrow$ `I ni ce`
  - *« josissant »* $ightarrow$ `jɔ sisan` (Arrêt immédiat)
  - *« d'amener »* $ightarrow$ `daminɛ` (Démarrer)
  - *« d'habilla »* $ightarrow$ `dabila` (Annuler / Arrêter)
- **Circuit d'Urgence Déterministe E-STOP ($0\text{ ms}$)** :
  L'expression `jɔ sisan` ou `dabila sisan` déclenche instantanément le circuit court d'arrêt d'urgence (`emergency_intent.dart`) sans aucune dépendance envers le réseau de neurones.

---

## 6.4 Parler d'Atelier & Ancrage Déterministe en Sandwich

Les mesures sur le banc d'évaluation (`conversation_langues_test.dart`) démontrent qu'en bambara pur, un modèle local ne comprend que 19 % des ordres techniques, mais atteint **83 %** de compréhension dès lors que le vocabulaire d'atelier est maintenu en français (`"Homing kɛ"`, `"Broche allumer sisan"`).

1. **Règle du Parler d'Atelier (`atelierRule`)** :
   Informe le modèle que les mots techniques CNC (broche, jog, homing, origine, palpage, G54, etc.) doivent impérativement rester en français d'atelier dans sa réponse.
2. **Directive de Réponse Directe** :
   Interdit formellement au modèle d'expliquer ses règles de traduction ou de commenter sa méta-consigne à l'opérateur (évite les déclarations artificielles telles que *« Mo ni haoussa »*).
3. **Ancre de Fin Sandwich (`trailingPromptAnchor`)** :
   Rappel placé en fin absolue de prompt système verrouillant la langue active et interdisant la fabrication de données imaginaires.

---

## 6.5 Synchronisation Temps Réel du Brouillon Opérateur (`aiPromptDraftProvider`)

Pour assurer une continuité ergonomique totale :
- Un notifier Riverpod dédié (`AiPromptDraftNotifier`) synchronise en temps réel le brouillon de saisie utilisateur (`_inputCtrl` / `_input`).
- Tout texte tapé ou dicté vocalement dans la fenêtre omniprésente d'atelier (`OmnipresentAiShell`) apparaît instantanément si l'opérateur ouvre la page plein écran Agent IA (`AiConsoleScreen` sur Desktop ou `AiAssistantScreen` sur Mobile), et vice-versa.
- Lors de l'envoi du message ou de la sélection d'une puce, le brouillon partagé est atomiquement réinitialisé.

---

## 6.6 Traduction Dynamique des Composants d'Interface

- **Sous-titre de la Fenêtre Forgeron IA** : La fenêtre active de l'opérateur (ex. *Tableau de bord*, *Palpage*, *Magasin d'outils*) est traduite à la volée dans la langue active (ex. en Haoussa : `DASHBOARD`, `AUNAWA DA MAFARI`, etc.).
- **Puces de Suggestions Contextuelles (`SuggestedNextAction`)** :
  Le champ `localizedLabel` résout dynamiquement la table de traduction de la langue choisie au moment du rendu graphique (ex. *« État de la machine »* devient *« Yanayin injin »* en Haoussa et *« Mansin cogoya »* en Bambara).

*Documentation spécialisée mise à jour — Référence officielle de l'Architecture Multi-Agents et Modèles Locaux Ollama dans Forgeron.*
