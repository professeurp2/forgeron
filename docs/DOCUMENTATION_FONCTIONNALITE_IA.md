# Documentation Spécialisée et Ultra-Détaillée : Fonctionnalité Agent IA Multimodal de Forgeron

*Projet de Fin d'Études (PFE) — ENI*  
*Module : `lib/application/providers/ai_agent_provider.dart` & `lib/application/services/ai_agent_service.dart`*  
*Dernière mise à jour : Mai 2026*

---

# 🎯 1. PRINCIPES ET CONCEPTION DE L'AGENT IA

## 1.1 Frontière Réflexive / Déterministe
Dans l'application **Forgeron**, l'Agent IA est conçu selon un principe fondamental de sécurité industrielle :  
> **L'IA (Modèle de Langage / VLM) apporte l'intention, l'explication, l'analyse et la recommandation, mais NE GÉNÈRE JAMAIS DIRECTEMENT DE COORDONNÉES G-CODE BRUTES.**

La littérature scientifique (*GLLM: Self-Corrective G-Code Generation using LLMs*) démontre que les LLMs commettent des hallucinations sémantiques et des erreurs de coordonnées catastrophiques en usinage. Forgeron sépare donc strictement :
1. **Raisonnement Probabiliste (LLM / VLM)** : Compréhension des requêtes de l'opérateur, diagnostic des pannes, analyse des photos de pièces, guidage pas-à-pas et choix des stratégies.
2. **Calcul Déterministe (Pipelines Dart/Python/FluidNC)** : Calcul d'engagement, génération de parcours d'outils, lissage de trajectoires, validation des butées, gestion du buffer RX et contrôle temps réel.

---

# 🏗️ 2. ARCHITECTURE MULTI-FOURNISSEUR (DUAL BACKEND)

L'Agent IA s'appuie sur le contrat abstrait `AiBackend` (`lib/application/services/ai_agent_service.dart`) permettant de basculer de manière transparente entre un modèle Cloud puissant et un modèle Local 100% hors-ligne.

```
                        ┌───────────────────────────────┐
                        │      AiAgentController        │
                        └───────────────┬───────────────┘
                                        │
                         ┌──────────────┴──────────────┐
                         ▼                             ▼
             ┌──────────────────────┐      ┌──────────────────────┐
             │    AiAgentService    │      │ LocalAiAgentService  │
             │   (Gemini Cloud)     │      │   (Ollama / Local)   │
             └───────────┬──────────┘      └───────────┬──────────┘
                         │                             │
                 CellularHttpClient                LAN Atelier
                 (Force 4G / 5G)               (WiFi / Ethernet)
```

## 2.1 Gemini Cloud (`AiAgentService`)
- **Modèle par défaut** : `gemini-flash-lite-latest` (et modèles de secours paramétrables via `AiModelProvider`).
- **Contournement Réseau Mobiles (`CellularHttpClient`)** : L'ESP32 crée son propre point d'accès WiFi sans Internet. Sur Android, `CellularHttpClient` force les requêtes HTTPS vers les serveurs Google via l'interface de données mobiles (4G/5G) pendant que le socket WebSocket communique avec la machine sur l'interface WiFi.
- **Protocole SSE (Server-Sent Events)** : Réception streamée via `streamGenerateContent?alt=sse` pour un affichage en temps réel avec latence minimale.

## 2.2 Modèle Local / On-Premise (`LocalAiAgentService`)
- **Serveur local** : Compatible Ollama / LM Studio (API REST locale sur le réseau de l'atelier).
- **Zéro Clé / Zéro Internet** : Garantit la confidentialité totale des données CAO/FAO et le fonctionnement complet sans couverture réseau mobile.
- **Budget de Contexte Sévère** : La taille de l'historique est bornée via `historyBudgetChars` pour éviter le débordement de la fenêtre de contexte des modèles locaux.

## 2.3 Modèle de Vision Dédié (`_ensureVisionService()`)
Lorsqu'un message contient une image (photo de pièce, copeau, écran d'alarme), l'Agent peut basculer automatiquement sur un modèle VLM de vision dédié (`localVisionModel`) configuré dans les paramètres.

---

# 🔄 3. GESTION D'ÉTAT ET FLUX DE CONVERSATION (`AiAgentController`)

## 3.1 Structure du Message (`AiChatMessage`)
Chaque élément du fil de discussion est modélisé par la classe `AiChatMessage` :
- **`role`** : `'user'` (opérateur), `'assistant'` (IA) ou `'tool'` (étape d'exécution d'outil).
- **`text`** : Contenu textuel (supportant le Markdown enrichi).
- **`imageBytes`** : Miniature temporaire de l'image jointe (non persistée sur disque pour préserver l'espace de stockage).
- **`toolName`, `toolArgs`, `toolResult`, `toolDuration`** : Métadonnées structurées d'exécution d'outils. Un outil est publié dans l'UI **dès son démarrage** (`toolResult == null`), permettant à l'opérateur de visualiser l'action en cours.

## 3.2 Persistance et Multi-Discussions (`AiConversationMeta`)
L'historique des échanges est sauvegardé localement via `SharedPreferences` :
- **Index global** : Clé `ai_conversations_v2`.
- **Payloads individuels** : Clés `ai_conversation_<id>` contenant la liste des messages UI et le journal brut de protocole `_contents`.
- **Nettoyage Automatique** : Les images en base64 sont purgées des sauvegardes (`_sanitizeForStorage()`), et les fils de discussion vides sont automatiquement supprimés (`_pruneEmpty()`).
- **Isolation par Époque (`_epoch`)** : Chaque changement de discussion incrémente la variable `_epoch`. Les requêtes réseau asynchrones en cours vérifient cette époque à la réception pour éviter d'injecter une réponse dans un fil fermé.

## 3.3 Fréquence de Rendu Streamé (25 Hz)
Pendant la réception du flux SSE de l'IA, le texte partiel est mis à jour dans le state. Pour éviter d'engorger le thread principal avec 80 re-renders par seconde, l'émission des deltas vers l'UI est cadencée à **25 Hz (intervalle de 40 ms)** :

```dart
final now = DateTime.now();
if (now.difference(lastDeltaEmit).inMilliseconds >= 40) {
  lastDeltaEmit = now;
  state = state.copyWith(streamingText: partial);
}
```

---

# 🛡️ 4. SÉCURITÉ, LEXIQUE FERMÉ ET NIVEAUX D'AUTONOMIE

Le système applique trois niveaux de garde-fous avant d'exécuter la moindre action sur la machine CNC.

```
Message Opérateur
       │
       ├─► 1. Détection d'Urgence Immédiate (emergency_intent.dart) ──► Exec. 'emergency_stop' direct
       │
       ├─► 2. Analyse par Lexique Fermé (ai_lexicon_front.dart) ────► Bloque si question/négation
       │                                                             └─► Exige confirmation si action
       │
       └─► 3. Filtrage du Modèle IA (AiAgentSettingsProvider) ──────► 4 Niveaux d'autonomie
```

## 4.1 Circuit Court d'Arrêt d'Urgence (`emergency_intent.dart`)
Si l'opérateur écrit un mot-clé d'urgence ("Arrête tout", "E-STOP", "Coupe la machine"), la fonction `isEmergencyStopRequest` intercepte immédiatement le message :
- **Aucun appel LLM n'est effectué**.
- La commande `emergency_stop` est exécutée de façon déterministe en millisecondes.

## 4.2 Porte d'Entrée Lexique Fermé Multilingue (`ai_lexicon_front.dart`)
Le lexique fermé analyse la syntaxe du message dans 15 langues (Français, Anglais, Bambara, etc.) :
1. **Détection de Question / Négation** : Si le message est identifié comme une question ("Est-ce que le moteur tourne ?") ou une négation ("Ne fais pas de homing"), l'Agent passe en mode **Lecture Seule (`_readOnlyTurn = true`)**. Tous les outils d'écriture/mouvement sont masqués au modèle pour ce tour.
2. **Passe-droit avec Confirmation** : Si le lexique reconnaît une intention d'action formelle ("Allume la broche"), une carte de confirmation `AiPendingToolCall` est présentée à l'opérateur avec le libellé traduit et les raisons de sécurité.

## 4.3 Niveaux d'Autonomie Paramétrables (`AiActionCategory`)
Chaque outil est rattaché à une catégorie de sécurité configurables par l'utilisateur (`AiAgentSettingsScreen`) :
- `readOnly` : Exécution autonome immédiate (ex: lecture de position, diagnostic).
- `requireConfirmation` : Carte de confirmation obligatoire avant envoi à la machine (ex: lancement de programme, jog, WCS).
- `autonomous` : Exécution directe autorisée par l'opérateur.
- `disabled` : Désactivation totale de la catégorie d'outil.

---

# 📝 5. PROMPT ENGINEERING ET INJECTION DYNAMIQUE DE CONTEXTE

À chaque tour de conversation, le prompt système est reconstruit dynamiquement via `_buildSystemPrompt()` pour fournir au modèle une vision exacte de la machine à l'instant T :

## 5.1 Structure du Prompt Système Reconstruit
1. **Instructions Fixes (`baseSystemPrompt`)** : Identité de l'Agent, règles de courtoisie, interdiction de générer du G-code brut, règles d'explications pédagogiques.
2. **Spécificités Matérielles (`_machineSpecs`)** : Explication des particularités de la machine (Broche DC 775 sur relais Tout-ou-Rien GPIO 21, Pas de vis X 3mm vs Y/Z 2mm, Fins de course NC fail-safe, Homing Z vers le haut).
3. **Cinématique Réelle Configurée (`_kinematicsBlock()`)** : Courses réelles, pas/mm, vitesses max et accélérations lues dynamiquement dans la configuration FluidNC courante.
4. **État Machine Réel Instantané (`liveStateBlock`)** : Position `wPos`/`mPos`, statut (`Run`, `Idle`, `Alarm`), WCS actif, vitesse broche et avance réelle.
5. **Journal d'Activité Récent (`formatRecentActivity`)** : Historique des 50 dernières actions effectuées sur l'IHM par l'opérateur (mouvements, clics, alarmes).
6. **Extrait de Fiches RAG (`_docsBlockOrNull()`)** : Injection automatique des fiches de connaissances et règles d'alarmes pertinentes pour la requête.
7. **Directive Linguistique et Glossaires (`_glossaireBlockOrEmpty()`)** : Dictionnaire contextuel pour les langues à faibles ressources (ex: Bambara).

---

# 🧰 6. CATALOGUE COMPLET DES OUTILS (45+ TOOLS)

Chaque outil (`AiTool`) implémente un schéma de paramètres JSON compatible avec la déclaration de fonction Gemini (`FunctionDeclaration`).

### 6.1 Outils de Lecture et Diagnostic (Toujours Autorisés)
- `get_machine_state` : Lit le statut, les coordonnées WPOS/MPOS, le WCS et les alarmes.
- `get_diagnostics` : Récupère la température ESP32, le signal WiFi, l'état des GPIO et le temps d'exécution.
- `get_activity_log` : Lit le journal des actions récentes de l'opérateur.
- `get_wcs_offsets` : Renvoie la table des origines G54 à G59.
- `get_axis_kinematics` : Lit la configuration cinématique des axes X, Y, Z, A, C.
- `get_config` : Télécharge le fichier YAML de configuration FluidNC actif.
- `read_settings` : Lit les paramètres de l'application Forgeron.
- `get_camera_snapshot` : Récupère une capture photo en direct depuis l'ESP32-CAM.
- `search_docs` : Effectue une recherche par mots-clés dans les fiches RAG.

### 6.2 Outils de Gestion de Fichiers et Espace de Travail
- `list_workspace_files` : Liste les fichiers G-code et STEP présents dans le dossier de travail.
- `read_workspace_file` : Lit le contenu d'un fichier G-code.
- `write_workspace_file` : Écrit ou enregistre un fichier G-code modifié dans l'espace de travail.
- `analyze_gcode` : Analyse syntaxique d'un fichier G-code (détecte les blocs RTCP interdits, compte les lignes, estime le temps d'usinage).

### 6.3 Outils de Mouvement et Réglages Origines
- `jog_axis` : Exécute un déplacement relatif contrôlé sur un ou plusieurs axes.
- `home` : Lance la séquence de prise d'origine machine (`$H` ou `$HZ`).
- `goto_position` : Déplace la machine vers une position absolue ou relative.
- `set_work_zero` : Définit la position actuelle comme zéro pièce dans le WCS actif (`G10 L20`).
- `select_wcs` : Bascule vers le système de coordonnées spécifié (`G54` à `G59`).
- `set_wcs_offset` : Ajuste manuellement les décalages d'un WCS.
- `probe` : Lance une macro de palpage automatique (`G38.2`).

### 6.4 Outils d'Exécution et Contrôle Machine
- `send_gcode` : Transmet une ligne ou un bloc G-code direct au buffer.
- `run_program` : Lance l'exécution du programme G-code actuellement chargé.
- `run_gcode_program` : Charge et lance un programme G-code spécifié.
- `stop_program` : Interrompt le streaming G-code en cours.
- `pause` : Envoie la commande Feed Hold (`!`).
- `resume` : Envoie la commande Cycle Start (`~`).
- `reset` : Envoie un Soft Reset (`Ctrl-X`).
- `emergency_stop` : Déclenche l'Arrêt d'Urgence immédiat.
- `unlock_alarm` : Envoie la commande de déverrouillage d'alarme (`$X`).
- `set_spindle` : Allume (`M3 S1000`) ou éteint (`M5`) la broche.
- `set_coolant` : Active ou désactive l'arrosage (`M7`/`M8`/`M9`).
- `set_feed_override` : Ajuste le potentiomètre virtuel d'avance (0% à 200%).
- `set_spindle_override` : Ajuste le potentiomètre virtuel de vitesse de broche.

### 6.5 Outils de Génération 3D et Visualiseurs
- `run_step_pipeline` : Convertit un fichier 3D CAD `.step` en programme G-code 5-axes optimisé.
- `preview_step_file` : Ouvre la fenêtre d'aperçu 3D du fichier STEP.
- `open_toolpath_window` : Ouvre la fenêtre d'affichage du tracé de parcours d'outil.
- `open_chart_window` : Affiche les graphiques de télémétrie.
- `open_gcode_window` : Ouvre l'éditeur G-code avancé.

### 6.6 Outils de Numérisation & Scan 3D
- `get_reco3d_status` : Vérifie la disponibilité du serveur de reconstruction 3D.
- `discover_reco3d_server` : Scanne le réseau local à la recherche d'un serveur de numérisation.
- `start_machine_scan` : Pilote la rotation automatique des axes A et C pour capturer une série de photos multi-angles.
- `get_scan_job_status` : Suit la progression de la reconstruction 3D.
- `download_scan_result` : Télécharge le maillage 3D ou le fichier STEP reconstitué.

### 6.7 Outils de Simulation
- `run_machining_simulation` : Lance la simulation d'enlèvement de matière en temps réel.
- `control_simulation` : Contrôle la lecture (play, pause, vitesse, reset) du simulateur.
- `switch_simulator_camera_tab` : Modifie la vue caméra du simulateur.

---

# 📊 7. OBSERVABILITÉ ET JOURNALISATION DES TOURS (`AiTurnJournal`)

Chaque tour de conversation est consigné dans un fichier de journalisation structuré `record.jsonl` via `AiTurnJournal` (`lib/application/services/ai_turn_journal.dart`) :

```json
{
  "time": "2026-05-15T10:30:00.120Z",
  "backend": "gemini",
  "model": "gemini-flash-lite-latest",
  "outcome": "ok",
  "latencyMs": 1240,
  "tokens": 1420,
  "tools": ["get_machine_state", "read_workspace_file"],
  "declaredTools": 38,
  "release": "a1b2c3d4/e5f6g7h8",
  "front": "lexique:direct:readState"
}
```

- **Indicateurs clés mesurés** : Latence exacte (ms), consommation de jetons, outils appelés, statut de réussite (`ok`, `error`, `cancelled`, `empty`), et identifiant d'empreinte de version (`release`).
- Ce journal permet d'effectuer des audits hors-ligne et d'évaluer la qualité des réponses sur les bancs de tests.

---

# 🖥️ 8. COMPOSANTS D'INTERFACE UTILISATEUR (UI)

- **`AiConsoleScreen` (`lib/presentation/screens/desktop/ai_console_screen.dart`)** : Vue console bicolore pour ordinateur de bureau avec chronologie d'exécution des outils, volet d'artefacts 3D et saisie multimodale.
- **`AiAssistantScreen` (`lib/presentation/screens/ai_assistant_screen.dart`)** : Assistant sous forme de panneau latéral ou écran mobile avec bulles de dialogue, boutons de dictée vocale et cartes de confirmation d'action.
- **`_DraggableAiButton` (`lib/presentation/screens/main_scaffold.dart`)** : Bouton flottant représentant la tête du robot IA, aimanté sur les bords de l'écran, avec animation de respiration et pastille d'alerte en cas de problème.
