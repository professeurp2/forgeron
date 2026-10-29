# Étude : projets CNC + IA, SINDIT multi-agents, et ce qui s'adapte à Forgeron

Date : 25 octobre 2026.
Sources étudiées :

- `Forgeron_improvement_docs.pdf` : 3 pages, une réponse de Gemini qui recense 13 dépôts GitHub en 4 catégories ;
- `Search/Softward/LFLSINDIT20-main` : le code de SINDIT (SINTEF), lu en entier pour la couche IA (`src/sindit/llm/`, `knowledge_graph/`, `processing/`) ;
- l'IA de Forgeron telle qu'elle existe sur `claude/conception-photos-vers-step`, la branche la plus avancée (elle contient toutes les autres) : `ai_agent_provider.dart`, `tool_router.dart`, `ai_agent_service.dart`, `local_ai_agent_service.dart`, `gcode_critic.dart`, `docs_prefetch.dart`, `ARCHITECTURE.md`, `tool/eval/`.

> **Sur le PDF.** C'est une réponse de Gemini, pas une revue vérifiée. Je n'ai pas
> ouvert les 12 autres dépôts : leur existence et ce qu'ils font réellement
> restent à confirmer avant d'en citer un dans le mémoire ou au bootcamp. Seul
> SINDIT a été lu ligne à ligne.

---

## 1. Les 13 projets du PDF, vus depuis Forgeron

| Catégorie | Projets | Ce que Forgeron a déjà | Intérêt pour Forgeron |
|---|---|---|---|
| **1. Assistants / RAG** | SINDIT (multi-agents), Vicomtech/CNC-Assist (corpus de questions-réponses CNC) | Agent à 38 outils, fiches + `docs_prefetch`, `search_docs` | **Fort** : SINDIT pour l'architecture (§2-4). CNC-Assist comme source de scénarios de banc et de fiches, si sa licence le permet |
| **2. IA générative CAO/FAO** | freecad-mcp (×3), gpt-to-svg-gcode-ai, handcode | Générateurs déterministes `tool/gen_*.dart`, pipeline STEP, critique G-code | **Moyen pour freecad-mcp** : c'est le même principe que Forgeron (le modèle pilote un moteur de FAO, il n'écrit pas les coordonnées), mais FreeCAD tourne sur PC, pas sur le téléphone. **Faible pour les deux autres** : texte → image → vecteur → G-code de gravure, qui dépend d'API cloud (DALL-E) |
| **3. Maintenance prédictive** | Tool-Wear-Prediction, boschresearch/CNC_Machining, CNC-Predictive-Maintenance, cnc-maintenance-predictor, Few-Shot tool monitoring | Rien | **Prématuré** : ces modèles apprennent sur des accéléromètres, le courant moteur ou le couple. Forgeron n'a aucun de ces capteurs ni d'historique enregistré. Un seul cas utile tout de suite : les **redémarrages thermiques** (mémoire du projet), qui appellent une sonde de température d'armoire et une règle, pas un modèle appris |
| **4. Vision** | EasyCNC (photo des chutes + imbrication), CNC-Object-Segmentation (YOLOv8, usure de fraise) | ESP32-CAM OV2640, modèle de vision séparé pour les images | **Moyen** : l'imbrication sur chute est concrète en 3 axes. L'usure de fraise par YOLO demande des macros nettes de l'arête, ce que l'OV2640 à distance ne donnera probablement pas (à tester avant d'y investir) |

---

## 2. Ce que fait réellement le « multi-agents » de SINDIT

Ce n'est pas un essaim d'agents qui discutent entre eux. C'est un **routeur suivi
de spécialistes qui collectent du contexte, puis d'une synthèse** :

```
question
   │
   ▼
IntegratedAgent.classify_query_type()        (integrated_agent.py:300)
   0. raccourcis par mots-clés : méta-conversation → aucun agent ;
      « currently », « right now » → Monitoring seul
   1. similarité d'embeddings avec ~80 questions d'exemple par catégorie
      (MiniLM multilingue, cosinus, seuil 0,8 ; 2e catégorie > 0,72 activée aussi)
   2. sous 0,8 : le LLM classe, en JSON
   3. garde-fous : motifs temporels → Analytics ; pas d'OF cité → pas d'Analytics
   │
   ├── RetrieverAgent   : question → SPARQL (LLM) → GraphDB → réponse (LLM)
   ├── MonitoringAgent  : choix des signaux MQTT (LLM, sortie structurée)
   │                      → VALIDATION contre une liste blanche → collecte → réponse (LLM)
   ├── AnalyticsAgent   : Parquet → métriques pandas → graphique PNG → LLM de vision
   └── GreenAgent       : fichiers DPP (CO2) → texte ou graphique Plotly → LLM
   │
   ▼
un dernier appel LLM fusionne tous les contextes en une réponse   (integrated_agent.py:705)
```

Les spécialistes s'exécutent **l'un après l'autre**, ne se parlent pas, ne
planifient rien, et surtout **n'agissent jamais** : tout SINDIT est en lecture
seule. Aucun ne déplace un axe.

### Ce qui est bon, et transposable

1. **La cascade de routage** : raccourci déterministe → similarité sémantique →
   LLM seulement dans le doute. Le coût d'un appel LLM n'est payé que quand c'est
   nécessaire.
2. **La validation de la sortie du LLM contre une liste blanche**
   (`validate_mqtt_params`, `monitoring_agent.py:133`) : les signaux inconnus sont
   retirés, les durées bornées, un défaut sûr est pris si rien ne reste. C'est la
   même philosophie que Forgeron (le routeur d'outils ne peut que retirer, jamais
   inventer).
3. **Un spécialiste = une source de données + son prompt court.** Chacun ne voit
   que ce dont il a besoin.
4. **Graphique → image → modèle de vision** (`AnalyticsAgent`, `GreenAgent`) : la
   réponse s'appuie sur les chiffres ET sur la courbe.
5. **Le spécialiste ne connaît pas l'interface** (`last_figure` est un objet pur,
   l'appelant décide de l'afficher).

### Ce qui est faible, ou à ne pas copier

1. **4 à 6 appels LLM par question** (classement, SPARQL, réponse du graphe,
   synthèse, plus la vision). Sur Qwen 7B local, c'est autant de latence.
2. **Text-to-SPARQL avec un petit modèle** est fragile ; le code multiplie déjà
   les rustines dans le prompt (`CONTAINS(LCASE(...))` obligatoire, préfixes
   réinjectés).
3. **Tout est codé en dur** : les 5 pièces `OF10001`–`OF10005`, la fenêtre de
   dates, des listes de mots-clés en anglais seulement.
4. **Aucun test de la couche IA** (`src/tests/` ne couvre que les connecteurs et
   GraphDB) et l'interface Streamlit citée dans le README n'est pas dans le dépôt.
   Aucune mesure de la qualité du routage.
5. **Pile non transposable** : Python, LangChain, GraphDB (Java), Streamlit,
   Docker. Forgeron est en Flutter sur un téléphone hors ligne. **On reprend les
   motifs, pas le code.**

---

## 3. Forgeron a déjà la moitié de cette architecture

| Pièce SINDIT | Équivalent Forgeron | État |
|---|---|---|
| Raccourcis déterministes (étape 0) | lexique fermé `command_lexicon.dart` + raccourci d'arrêt d'urgence | branché |
| Classement par catégorie | `ToolRouter` : 9 groupes d'outils depuis l'ajout de `simulation` et `scan`, mots-clés FR/EN/swahili | **activé** (`_useToolRouting = true`) dans le code en cours, non commité au 29 oct. ; modèle local seulement |
| Repli « dans le doute, tout » | `ToolRouter.route` : rien de reconnu → les 38 outils | branché |
| RetrieverAgent | `docs_prefetch` + `search_docs` sur le corpus de fiches | branché |
| Agent de vision séparé | `_ensureVisionService` : un tour avec image va au modèle d'images, **sans outils**. Sur le PC : `gemma3n:latest`, qu'Ollama déclare bien capable de lire les images | branché, mais le relais vers le pilote est incomplet (§7) |
| Validation de la sortie du LLM | `GcodeCritic`, `TrajectoryValidator`, outils gatés avec confirmation | branché |
| MonitoringAgent (live) | `get_machine_state`, `get_diagnostics`, caméra | outils de l'agent unique |
| AnalyticsAgent (historique) | — | **absent** : je n'ai trouvé aucun enregistrement horodaté des rapports d'état pendant un usinage (seul `ai_turn_journal` journalise, et il journalise les tours de l'IA) |
| Mesure de la qualité | **Forgeron-Bench** (`tool/eval/`) | Forgeron est en avance : SINDIT n'en a pas |

Forgeron dépasse SINDIT sur un point décisif : **son agent agit**. C'est
précisément ce qui rend le multi-agents plus délicat chez nous que chez eux.

---

## 4. Faut-il un multi-agents dans Forgeron ? Oui, sous une forme précise

### Pourquoi c'est justifié — par les mesures de Forgeron, pas par la mode

`ARCHITECTURE.md` §1 donne trois chiffres qui plaident pour des spécialistes :

- les 38 déclarations d'outils pèsent **~4 800 des ~6 800 tokens fixes** de chaque tour ;
- le bon appel d'outil tombe de **29/30 à 18/30** quand l'historique passe de 12 000 à 22 000 caractères ;
- sur une discussion extrême, le modèle local reste autour de **50 %**.

Un spécialiste qui ne voit que 5 à 8 outils et un prompt court s'attaque
directement aux deux premiers. C'est une hypothèse, à vérifier au banc — mais
une hypothèse qui découle des mesures déjà faites.

### La forme proposée : superviseur déterministe + spécialistes à périmètre fermé

```
message de l'opérateur
   │
   ├─ arrêt d'urgence reconnu ──────────────► exécuté tout de suite, sans aucun agent
   │                                           (inchangé : ne JAMAIS faire passer
   │                                           l'arrêt par une chaîne d'agents)
   ▼
SUPERVISEUR (code, pas un LLM)
   1. lexique fermé : ordre compris sans réserve → exécuté
   2. ToolRouter : mots-clés → spécialiste(s)
   3. [plus tard] similarité d'embeddings via Ollama /api/embed
   4. doute → agent généraliste actuel, 38 outils (le filet d'aujourd'hui)
   │
   ├── Opérateur     : mouvement, broche, programme — SEUL à pouvoir agir, outils gatés
   ├── Surveillance  : état, diagnostics, journal, caméra — lecture seule
   ├── Documentaliste: fiches, search_docs — lecture seule, cite ses sources
   ├── FAO           : pipeline STEP, générateurs, boucle avec le critique (voir plus bas)
   └── Vision        : existe déjà
```

Règles de conception, chacune tirée de SINDIT ou de l'expérience Forgeron :

1. **Le superviseur est du code.** Le routage par un LLM ajoute un appel et une
   source d'erreur ; SINDIT ne l'utilise qu'en dernier recours, faisons de même.
2. **Un seul spécialiste peut agir** (Opérateur). Les autres n'ont que des outils
   de lecture : un mauvais routage vers eux ne peut rien casser. `isReadOnlyToolName`
   existe déjà pour l'imposer.
3. **Pas de synthèse finale systématique.** SINDIT fusionne toujours par un
   dernier appel ; chez nous, le spécialiste répond directement. On ne fusionne
   que si deux spécialistes ont été appelés.
4. **Le doute renvoie au généraliste**, jamais à un spécialiste « au hasard ».
5. **Chaque étape est mesurée au banc** avant d'être gardée (`BENCH_TAG`), comme
   l'a été le routage.

### Le seul vrai dialogue entre agents qui vaille la peine : générateur ↔ critique

`gcode_critic.dart` a été écrit pour ça (« rend un verdict exploitable par
l'agent »). La boucle :

```
FAO choisit les paramètres → générateur déterministe → G-code
      ↑                                                 │
      └── GcodeCritic : verdict structuré + remède ◄────┘
          (au plus N tours, puis l'opérateur tranche)
```

C'est le multi-agents utile : un LLM qui décide, du code qui calcule, du code
qui juge. Il respecte la règle « l'agent ne produit aucune coordonnée ».

---

## 5. Plan, du moins risqué au plus lourd

| Phase | Contenu | Coût estimé | Mesure de réussite |
|---|---|---|---|
| **0** | Rapport de référence au banc sur le routage actuel (`BENCH_TAG=reference-multiagent`) | ½ jour, surtout du temps machine | rapport daté |
| **1** | Spécialistes = un **profil** par groupe du `ToolRouter` : prompt court + sous-ensemble d'outils. Extension de `ToolGroup`, pas une réécriture : `_declarationsFor` et `_buildSystemPrompt` lisent le profil retenu | 2-3 jours | TS/AF au moins égaux à la phase 0, tokens par tour en baisse, aucune régression sécurité |
| **2** | Boucle FAO générateur ↔ critique, bornée en tours | 2-3 jours | scénarios MS du banc sur le pipeline STEP |
| **3** | Routage sémantique : quand les mots-clés ne reconnaissent rien, similarité avec des phrases d'exemple via `/api/embed` d'Ollama (le serveur de l'atelier, donc hors ligne) au lieu de « tous les outils » | 2 jours | part des messages routés en hausse, sans baisse de réussite ; à mesurer **langue par langue**, le bambara restant le cas difficile |
| **4** | Spécialiste « Historique » à la SINDIT : demande d'abord un **enregistreur d'usinage** (rapports `FS:` / position / avance / température horodatés dans un fichier par programme). Sans données enregistrées, cet agent n'aurait rien de vrai à dire | 1 semaine | données réelles d'au moins un usinage long ; sert aussi à documenter les redémarrages thermiques |

Les phases 0 et 1 tiennent avant le 8 novembre (fin de la fenêtre d'ingénierie
avant le bootcamp) et donnent une démonstration mesurée : « spécialistes contre
généraliste, même banc, même modèle ».

### À ne pas reprendre de SINDIT

- **GraphDB + Text-to-SPARQL** : lourd (serveur Java), fragile avec un modèle 7B,
  et le corpus de fiches de Forgeron est assez petit pour que le préchargement
  suffise.
- **GreenAgent** : aucune donnée de cycle de vie pour cette machine. Afficher une
  empreinte CO2 sans mesure irait contre la règle « jamais de données inventées ».
- **Le dernier appel de synthèse systématique**, pour la latence.

---

# Mise à jour du 29 octobre 2026

Relecture **en lecture seule** du code actuel (`claude/conception-photos-vers-step`
à `962849c` + 33 fichiers modifiés non commités + 3 nouveaux). Rien n'a été
modifié.

## 6. Ce qui a changé côté IA depuis le 25 octobre

- **48 outils** au lieu de 38 : `get_reco3d_status`, `discover_reco3d_server`,
  `start_machine_scan` (gaté « mouvement »), `get_scan_job_status`,
  `download_scan_result`, la simulation (`run_machining_simulation`,
  `control_simulation`, `switch_simulator_camera_tab`)… Le poids fixe des
  déclarations a donc encore augmenté, ce qui renforce l'argument du §4.
- **Le routage d'outils est activé** pour le modèle local, avec deux nouveaux
  groupes (`simulation`, `scan`). Au 25 octobre il était coupé « tant que
  Forgeron-Bench n'a pas montré qu'il ne dégrade rien ». Je n'ai pas trouvé de
  rapport de banc postérieur qui le justifie : la phase 0 du plan (mesure de
  référence) reste à faire, et elle porte maintenant sur le routage tel qu'il
  est activé.
- Le texte en flux est cadencé à 25 Hz (moins de reconstructions d'écran).
- Le bambara redevient une langue de réponse (`962849c`), et c'est la langue
  réglée sur le PC (`ai_agent_language = bm`).

## 7. « Que l'agent comprenne mes images » : la cause n'est pas le multi-agents

L'agent d'images **existe déjà** et il est réglé sur le PC (`gemma3n:latest`).
Le défaut est dans le **passage de relais** :

1. `_lastTurnHasImage()` ne regarde que le **dernier** message. Le tour qui porte
   la photo va bien à gemma3n.
2. Dès la question suivante (« et tu peux l'usiner ? »), c'est Qwen qui répond.
   Pour lui, `toOpenAiMessages` remplace l'image par `imageNote` : « tu ne peux
   pas la voir… préviens l'opérateur que tu n'as pas pu l'examiner ». **Le pilote
   reçoit donc l'ordre de dire qu'il n'a pas vu l'image**, alors que la
   description de gemma3n figure juste au-dessus dans l'historique.
3. Le tour d'image est **sans outils** : « regarde cette pièce et lance le scan »
   ne peut rien lancer.

C'est exactement là que l'architecture à spécialistes aide. Le spécialiste
Vision rend une **fiche d'image** (ce qui est visible, ce qui est incertain), et
c'est elle, pas `imageNote`, que le pilote reçoit ensuite à la place de
l'image. Le pilote garde ses outils et sait ce que contient la photo, sans
qu'aucun modèle n'invente ce qu'il n'a pas vu. Petit changement, fort effet :
c'est la première chose à faire en multi-agents.

À vérifier sur le téléphone : son réglage « Modèle d'images » peut être vide
(je n'ai lu que les réglages du PC). S'il est vide, aucune image n'est jamais
lue.

## 8. Le micro

Deux écrans ont chacun leur dictée (`ai_assistant_screen.dart` sur mobile,
`ai_console_screen.dart` sur desktop). Les deux appellent `speech_to_text` de la
même façon.

**Sur ce PC, l'environnement est bon** : reconnaisseur SAPI « Microsoft Speech
Recognizer 8.0 (French - France) » installé, micro Intel Smart Sound présent,
accès au micro autorisé pour les applications de bureau. Je n'ai donc pas de
cause certaine sans le message exact ni l'appareil.

Ce que le code fait mal, à coup sûr :

- **L'erreur réelle est jetée** : `onError: (_) { … }` dans les deux écrans.
  Permission refusée, réseau absent, langue inconnue : tout donne le même
  silence, ou sur desktop le même « Aucun micro détecté sur cet appareil »,
  **même quand un micro est présent**. Le message ment, et on ne peut pas
  diagnostiquer.
- **Sur Windows, la langue demandée est ignorée** : le greffon
  `speech_to_text_windows` 1.0.1 utilise SAPI avec le reconnaisseur par défaut,
  et sa liste de langues est codée en dur (`en-US`, `en-GB`). Avec l'agent en
  bambara ou en français, le code retombe sur `en-US`, ce qui n'a aucun effet
  réel mais montre que la dictée Windows n'est pas pilotable par langue.
- **Sur Android**, la reconnaissance Google a besoin d'Internet, sauf si le pack
  hors ligne de la langue est installé. Le téléphone est sur le WiFi de l'ESP32,
  qui n'a pas d'Internet. Selon l'état de la 4G, la dictée peut échouer en
  silence. Hypothèse à confirmer avec le code d'erreur.

Correctif proposé : afficher le code d'erreur réel (`SpeechRecognitionError.errorMsg`)
et un message par cause, puis décider du vrai remède. Si c'est le réseau sur
Android, la piste hors ligne est `onDevice: true` + pack de langue installé. Si
c'est Windows, ce sera un autre moteur (Whisper via le serveur de l'atelier, qui
tourne déjà pour Ollama et reco3d).

## 9. Design : pourquoi le PC affiche le mobile élargi

`ResponsiveLayout` (`lib/core/widgets/responsive_layout.dart`) classe l'appareil
**uniquement par le côté le plus court de la fenêtre**, sans regarder la
plateforme :

| Côté court | Mise en page |
|---|---|
| < 600 | **mobile** |
| 600 – 1023 | tablette = desktop avec barre latérale repliée |
| ≥ 1024 | desktop |

Sur ce PC (écran 1536×864 logiques, échelle 125 %), la fenêtre maximisée fait
au plus ~830 de haut : **la branche desktop n'est jamais atteinte**. Et dès que
la fenêtre est réduite sous 600 de haut ou de large (fenêtre ancrée sur un quart
d'écran, fenêtre de chat détachée), **Windows bascule sur la structure mobile
complète**, avec la barre d'onglets du téléphone. C'est ce que tu vois.

La règle avait été écrite pour qu'un téléphone en paysage garde le mobile. Elle
a raison pour le téléphone, tort pour le PC.

Direction proposée :

1. **La plateforme décide de la famille, la taille décide de la densité.** Sur
   Windows, toujours la famille desktop (barre de titre, barre latérale, menus,
   survol, raccourcis clavier), en mode compact quand la fenêtre est petite.
   Jamais l'écran du téléphone.
2. **Un vrai langage desktop**, au lieu d'agrandir le mobile : panneaux
   redimensionnables, fenêtres détachables (le mécanisme `desktop_multi_window`
   existe déjà pour l'IA), transitions d'apparition et de fermeture, animations
   qui profitent du GPU du PC, effets de matière (Mica/acrylique) via
   `flutter_acrylic` ou équivalent.
3. **L'agent IA présenté comme un poste de travail** sur PC : la console
   (`ai_console_screen.dart`, `ai_console_timeline.dart`) en est le point de
   départ, avec les étapes et les outils visibles, les aperçus 3D et les
   graphiques dans des volets ou des fenêtres, pas dans des bulles de chat.

C'est un chantier de conception à part entière : il mérite une maquette
validée avant d'écrire une ligne.

## 10. Chat synchronisé PC ↔ téléphone

Rien n'existe aujourd'hui : chaque appareil garde ses discussions dans ses
propres préférences locales. `AiWindowChannel` ne relie que les fenêtres d'un
même PC.

Le modèle à suivre est celui des agents de codage avec contrôle à distance :
**une seule session, deux vues**.

- **Un seul hôte fait tourner l'agent.** Le PC est l'hôte naturel : il porte déjà
  Ollama et reco3d, et l'application Windows peut ouvrir un petit serveur
  WebSocket local (`dart:io`, aucune nouvelle dépendance ; `web_socket_channel`
  est déjà là côté client).
- **Le téléphone découvre le PC** comme il découvre déjà reco3d (diffusion UDP,
  `b9d8b25`), puis s'abonne au fil : messages, texte en flux, appels d'outils,
  cartes de confirmation. Il envoie ses messages, ses photos et sa voix à
  l'hôte.
- **Le format existe déjà** : `_contents` (historique) et `messages`
  (affichage) sont du JSON. On synchronise des événements, pas des écrans.
- **Règles de sécurité à poser avant le code** :
  - l'arrêt d'urgence part toujours **localement**, de chaque appareil, et ne
    dépend jamais du lien entre les deux ;
  - une carte de confirmation s'affiche sur les deux, la première réponse gagne,
    et l'autre carte se ferme avec « confirmé depuis le téléphone » ou « depuis
    le PC » ;
  - si le lien tombe, aucune action en attente n'est exécutée par défaut.

Prérequis réseau : PC et téléphone sur le même réseau, ce qui est déjà le cas
pour joindre Ollama.

## 11. Ordre recommandé

1. **Commiter le travail en cours** (33 fichiers). Tant qu'il n'est pas commité,
   tout nouveau chantier risque d'entrer en conflit avec lui.
2. **Fiche d'image** (§7) : petit, premier vrai pas multi-agents, effet immédiat.
3. **Erreur réelle du micro** (§8) : petit, et sans lui on ne peut pas réparer la
   voix.
4. **Phase 0 du banc** sur le routage maintenant activé.
5. **Design desktop** (§9) : maquette d'abord.
6. **Synchronisation PC ↔ téléphone** (§10) : plus gros chantier, il dépend des
   règles de sécurité ci-dessus.
