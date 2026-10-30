# Documentation Technique Générale et par Fonctionnalité — Forgeron CNC 5-Axes

*Projet de Fin d'Études (PFE) — ENI*  
*Version du système : 1.0.0 — Dernière mise à jour : Mai 2026*

---

# 📚 SECTION 1 : ARCHITECTURE GÉNÉRALE ET DÉSIGNS SYSTÈME

## 1.1 Modèle Architectural (Clean Architecture + Riverpod)
L'application **Forgeron** est construite selon une version adaptée de la **Clean Architecture**, organisée en quatre couches strictement étanches pour garantir la testabilité, la réactivité et la pérennité du code :

```
lib/
├── domain/        # Modèles immutables (Freezed), Enums CNC & Contrats Repositories
├── data/          # Websocket FluidNC, Parsers GRBL, Repositories Réels & Mocks
├── application/   # Providers Riverpod (State Management) & Services Métier (AI, CAM)
├── core/          # Thème Material 3 / Glassmorphism, Utilitaires G-Code, i18n
└── presentation/  # Écrans Desktop/Mobile, Pupitre FANUC, Visualiseur 3D, Widgets
```

- **Domain Layer** : Ne contient aucune dépendance vers Flutter ou des bibliothèques externes. Les structures `MachineState`, `JogCommand`, `Tool`, `Wcs`, `Macro` sont générées avec `Freezed` pour garantir l'immutabilité.
- **Data Layer** : Implémente la communication brute avec l'ESP32 via `web_socket_channel`. Contient les parsers réguliers (`GrblParser`) capables d'extraire l'état modal, les positions machine/pièce, la vitesse réelle de broche et les erreurs.
- **Application Layer** : Orchestre les états de l'interface et du streaming G-code. Riverpod (`flutter_riverpod` 2.6.1) gère la propagation réactive des modifications vers l'UI sans re-renders inutiles.
- **Presentation Layer** : Interface adaptative supportant le mode Bureau (Windows/Linux/macOS) et le mode Mobile (Android/iOS).

---

## 1.2 Architecture Multi-Fenêtres & Moteurs Flutter Distincts
Pour permettre l'affichage d'un aperçu 3D ou de la console d'Agent IA sur un second moniteur sans ralentir l'interface principale du pupitre, Forgeron utilise `desktop_multi_window` (0.2.1) :

- **Moteur Principal (Engine 0)** : Héberge la connexion WebSocket avec l'ESP32, le moteur de streaming G-code et les états globaux (`aiArtifactsProvider`, `machineStateProvider`).
- **Moteur Secondaire (Sub-window)** : Exécute sa propre instance de moteur Flutter. La communication entre les fenêtres s'effectue exclusivement par émission de messages légers via le canal `AiWindowChannel`.
- **Gestion Unifiée WebView2** : Sur Windows, l'environnement WebView2 est partagé via un fork local (`third_party/webview_windows`) pour éviter les conflits d'instances `DispatcherQueueController` entre fenêtres.

---

# 🔌 SECTION 2 : COMMUNICATION BAS NIVEAU ET PROTOCOLE FLUIDNC

## 2.1 Communication WebSocket & Frames Binaires
Le contrôleur FluidNC v3.7+/v4.0+ émet ses réponses en **frames binaires WebSocket**. Le décodage UTF-8 explicite est géré au point d'entrée de la connexion :

```dart
// lib/data/fluidnc/fluidnc_connection.dart
void _handleIncomingMessage(dynamic message) {
  String msg;
  if (message is List<int>) {
    msg = String.fromCharCodes(message).trim(); // Décodage binaire UTF-8
  } else {
    msg = message.toString().trim();
  }
  _processMessage(msg);
}
```

- **Exigence d'URL** : L'URL WebSocket doit obligatoirement être formée sous la forme `ws://<IP>:80/` (le slash final `/` est requis par le serveur HTTP de FluidNC pour l'upgrade du protocole).

---

## 2.2 Algorithme de Streaming Character-Counting (Buffer RX 127 Octets)
Le microcontrôleur ESP32 dispose d'un buffer de réception série/WebSocket de **128 octets**. L'envoi aveugle de fichiers G-code volumineux provoque des pertes de caractères et des plantages d'usinage.

Forgeron implémente l'algorithme **Character-Counting** (`streaming_service.dart`) :

1. **Incrémentation** : Avant de transmettre une ligne G-code, la taille de la chaîne (incluant `\n`) est ajoutée à la variable `currentBufferSize`.
2. **Contrainte** : Si `currentBufferSize + nouvelle_ligne.length > 127`, l'envoi est mis en attente dans la file d'attente FIFO.
3. **Décrémentation** : À chaque réception du mot-clé `ok` ou d'un message d'erreur `error:N` en provenance de FluidNC, la longueur du plus ancien bloc transmis est soustraite de `currentBufferSize`, déclenchant l'envoi du bloc suivant.

---

## 2.3 Injection Directe de Commandes Temps Réel
Certaines actions d'urgence ou d'ajustement ne doivent **jamais** attendre dans la file du buffer G-code :

| Commande | Octet / Chaîne | Canal d'envoi | Effet sur le Contrôleur |
| :--- | :--- | :--- | :--- |
| **Stop Jog** | `0x85` (`\x85`) | `sendRaw()` | Arrêt immédiat et propre du mouvement manuel |
| **Pause (Feed Hold)** | `!` | `sendRaw()` | Décélération sur la trajectoire sans perte de pas |
| **Reprise (Cycle Start)** | `~` | `sendRaw()` | Reprise progressive de l'usinage interrompu |
| **Soft Reset** | `0x18` (`\x18`) | `sendRaw()` | Réinitialisation logicielle de l'ESP32 / Purge buffer |
| **Unlock Alarm** | `$X` | `sendGCode()` | Levée de l'état d'alarme après vérification |
| **Heartbeat Ping** | `?` | `sendRaw()` | Demande de rapport d'état synchrone (toutes les 2s) |

---

# 🧠 SECTION 3 : ADAPTATION CAM, CINÉMATIQUE 5-AXES ET SÉCURITÉ

## 3.1 Adaptateur G-Code CAM (`gcode_adapter.dart`)
Les post-processeurs commerciaux (SolidWorks CAM, Mastercam, Fanuc ISO) génèrent souvent des codes incompatibles avec GRBL/FluidNC. L'adaptateur de Forgeron applique automatiquement la transformation au chargement :

1. **Suppression des Préfixes Incompatibles** : Retrait automatique des numéros de bloc (`N10`), numéros de programme (`O0001`), et retours aux origines machine non gérés (`G28`).
2. **Développement des Cycles Fixes (Canned Cycles)** : Transformation des cycles de perçage `G81` (perçage simple), `G82` (perçage avec temporisation) et `G83` (perçage débourrage) en séquences explicites d'instructions `G0` et `G1`.
3. **Gestion des Remplacements Outils** : Détection des instructions `G43 H...` et `M6` traduites en pauses opérationnelles intelligentes (`M0`) avec invite à l'écran.

---

## 3.2 Sécurité RTCP et Filtrage Anti-Collision (`gcode_critic.dart`)
FluidNC fonctionne en coordonnées cartésiennes pures et **ne gère pas le RTCP (Tool Center Point Management) matériel**. L'exécution d'un fichier écrit en repère pièce sans post-processeur machine provoquerait une collision majeure.

**Système de blocage strict** :
- **Commandes bloquées** : `G43.4`, `G43.5` (Fanuc RTCP), `TRAORI`, `TRANSMIT` (Siemens), `M128`, `FUNCTION TCPM` (Heidenhain).
- **Compensation de Rayon** : `G41` et `G42` sont bloqués s'ils sont configurés pour être calculés par la machine.
- **Vérification des Butées Angulars** :
  - Axe **A** (Inclinaison du berceau) : Validé sur l'intervalle strict **[-90.0°, +90.0°]**.
  - Axe **C** (Table tournante) : Géré sur le cycle complet **[0.0°, 360.0°]**.

---

## 3.3 Physique de l'Avance G94 en 5-Axes
En mode `G94` (avance par minute), lorsqu'un mouvement combine des axes linéaires (mm) et rotatifs (degrés), le contrôleur applique la vitesse $F$ sur le vecteur composite.  
- *Constat d'atelier* : Un code programmé à $F600$ produit une vitesse linéaire réelle d'environ $200\text{ mm/min}$ à la pointe de l'outil. Forgeron informe l'opérateur de cet écart lors du calcul d'ETA.

---

# ⚡ SECTION 4 : SCHÉMA MATÉRIEL, ÉLECTRONIQUE ET SÉCURITÉ FAIL-SAFE

## 4.1 Brochage GPIO ESP32 DevKit V1 (30 broches)
L'unité de commande est reliée aux 5 drivers TB6600 et aux composants de puissance selon l'affectation suivante :

| Fonction / Axe | Signal GPIO | Type / Configuration | Remarques Matérielles |
| :--- | :--- | :--- | :--- |
| **Axe X** | STEP: GPIO 26 / DIR: GPIO 27 | Sortie 3.3V / Pulses | Moteur pas-à-pas NEMA 17/23 |
| **Axe Y** | STEP: GPIO 25 / DIR: GPIO 33 | Sortie 3.3V / Pulses | Moteur pas-à-pas NEMA 17/23 |
| **Axe Z** | STEP: GPIO 32 / DIR: GPIO 23 | Sortie 3.3V / Pulses | Moteur pas-à-pas NEMA 17/23 avec frein/vis |
| **Axe A** | STEP: GPIO 19 / DIR: GPIO 18 | Sortie 3.3V / Pulses | Berceau Trunnion (Réducteur) |
| **Axe C** | STEP: GPIO 17 / DIR: GPIO 16 | Sortie 3.3V / Pulses | Plateau rotatif (Réducteur) |
| **ENABLE (Tous)**| GPIO 22 | Sortie partagée ×5 | Activation commune des TB6600 |
| **Fin de course X**| GPIO 4 | Entrée `gpio.4:high:pu` | Switch **NC** vers GND (Fail-safe) |
| **Fin de course Y**| GPIO 13 | Entrée `gpio.13:high:pu` | Switch **NC** vers GND (Fail-safe) |
| **Fin de course Z**| GPIO 14 | Entrée `gpio.14:high:pu` | Switch **NC** vers GND (Fail-safe) |
| **Homing Axe A** | GPIO 5 | Entrée `gpio.5:high:pu` | Switch **NC** vers GND (Capteur -88°) |
| **E-STOP** | GPIO 15 | Entrée `gpio.15:high:pu` | Bouton Coup-de-poing **NF** |
| **Broche DC 775** | GPIO 21 | Sortie Relais / MOSFET | `M3`=ON, `M5`=OFF (Tout-ou-rien) |

---

## 4.2 Configuration des Drivers TB6600 & Réglages Microstepping
- **Microstepping préconisé** : **1/16** (Commutateurs DIP : DIP4=ON, DIP5=ON, DIP6=OFF).
- **Calcul des pas par millimètre (Axes Linéaires X, Y, Z)** :
  $$\text{steps\_per\_mm} = \frac{\text{Pas Moteur (200)} \times \text{Microstepping (16)}}{\text{Pas de la vis (mm)}}$$
  - Vis T8 (Pas 2mm) : $1600 \text{ steps/mm}$
  - Vis pas 3mm (Axe X spécifique) : $1066.67 \text{ steps/mm}$
- **Calcul des pas par degré (Axes Rotatifs A, C)** :
  $$\text{steps\_per\_degree} = \frac{\text{Pas Moteur (200)} \times \text{Microstepping (16)} \times \text{Rapport Réduction}}{360^\circ}$$

---

## 4.3 Chîne d'Alimentation Industrielle & Boucle Sécurité NC
1. **Alimentation Principale** : Bloc ATX HP Delta DPS-475CB-1 A (Rail **12V / ~38A**). Le fil vert `PS_ON` est relié à la masse `GND` (noir) pour le démarrage permanent.
2. **Architecture Fail-Safe (Normally Closed)** :
   - Tous les capteurs de fins de course et le bouton d'Arrêt d'Urgence sont câblés en **Normalement Fermé (NC / NF)** vers la masse.
   - En cas de rupture de câble, de connecteur débranché ou de fil arraché, le circuit s'ouvre, ce qui déclenche immédiatement une alarme `ALARM:1` / `ALARM:11` dans FluidNC, stoppant tout mouvement.
3. **Double Sécurité Broche** : Pour pallier un éventuel gel du microcontrôleur, le bouton d'arrêt d'urgence intègre un second contact NF inséré directement en série sur la ligne d'alimentation 12V du relais de la broche.

---

# 🎛️ SECTION 5 : PUPITRE DE COMMANDE FANUC ET ERGONOMIE UI

## 5.1 Composants Physiques Virtuels (`cnc_panel_widgets.dart`)
- **Écran LCD Cathodique (`CncLcdScreen`)** : Simule le rendu d'un moniteur CNC industriel FANUC avec dégradé radial, fond vert phosphoreux sombre et trame de scanlines horizontales dessinées sur Canvas CustomPainter.
- **Volant Rotatif Tactile (`CncJogDial`)** :
  - Permet le réglage manuel des axes A et C.
  - Calcul trigonométrique `atan2(dy, dx)` pour mesurer la vitesse de rotation du doigt.
  - Seuil angulaire fixé à $15^\circ$ ($0.2618\text{ rad}$) par impulsion de pas avec retour haptique vibrant (`HapticFeedback.lightImpact()`).
- **Touches Biseautées Enfonçables (`CncKeyButton`)** :
  - Effet 3D avec biseau lumineux en haut et ombre portée projetée.
  - Animation de translation verticale de $+2.5\text{ px}$ lors de la pression.

---

## 5.2 Thème Visual & Glassmorphic System
L'UI s'appuie sur une palette industrielle sombre (`forgeronDarkColors`) et claire (`forgeronLightColors`) :
- **Panneau Translucide (`GlassPanel`)** : Filtre d'arrière-plan `BackdropFilter` avec flou gaussien ($\sigma_x=\sigma_y=12.0$), gradient de fond biseauté et indicateur latéral ambre (`#FF6B35`).
- **Wordmark Animé (`ForgeronWordmark`)** : Balayage lumineux par masque de dégradé glissant (`ShaderMask` + `GradientTransform`) simulant le reflet du métal en fusion.

---

# 🤖 SECTION 6 : AGENT IA GEMINI MULTIMODAL ET DIALOGUE NATUREL

## 6.1 Moteur d'Intelligence Artificielle & Contextualisation
L'Agent IA embarqué (`AiAgentService`) repose sur les modèles Gemini via l'API REST officielle. Il dispose d'un accès en temps réel au contexte d'usinage :

1. **Journal d'Activité Opérateur (`activityLogProvider`)** : Enregistre automatiquement les 50 dernières actions effectuées sur l'IHM (lancement de code, réglage de WCS, modifications de vitesse, déclenchements d'alarme).
2. **Entrées Multimodales (Vision & Audio)** :
   - Prise de photo directe via `image_picker` (analyse de l'état des outils, de l'état de surface d'une pièce ou d'un message d'erreur physique).
   - Reconnaissance vocale (STT via `speech_to_text`) et réponse synthétisée vovale (TTS via `flutter_tts`).
3. **Lexique Local & Fallback Hors-Ligne (`command_understanding.dart`)** :
   - Analyseur syntaxique par règles d'expressions régulières capable d'exécuter des ordres fondamentaux (E-STOP, Pause, Demande d'état, Allumage broche, Déplacement d'axe) en français, anglais et bambara sans connexion Internet.

---

## 6.2 Recherche Documentaire RAG (`docCorpusProvider`)
L'assistant intègre un moteur de recherche RAG (Retrieval-Augmented Generation) basé sur le fichier de fiches techniques `assets/docs/fiches.json` et le catalogue dynamique des alarmes FluidNC :
- Indexation par mots-clés et empreinte digitale JSON (`fingerprint`).
- Injection automatique des extraits de fiches pertinents dans le prompt système avant la génération de réponse par Gemini.

---

# 🧊 SECTION 7 : VISUALISATION 3D THREE.JS ET CINÉMATIQUE

## 7.1 Intégration WebGL & Three.js
- La vue 3D temps réel repose sur une scène Three.js embarquée (`web/three_viewer.html`).
- Chargement dynamique des maillages STL/OBJ du berceau Trunnion, du plateau tournant, de la broche et de la pièce.
- Contrôle de la caméra via `OrbitControls` (rotation, panoramique, zoom lissé).

---

## 7.2 Animation Synchronisée des Os Cinématiques
À chaque réception d'un Status Report FluidNC (`<Idle|MPos:X,Y,Z,A,C>`), l'application transmet les coordonnées au moteur WebGL :
- **Axe Z** : Translation verticale de la tête de broche.
- **Axes X, Y** : Translations combinées de la table de travail.
- **Axe A** : Rotation de la structure du berceau autour de son axe pivot horizontal.
- **Axe C** : Rotation du plateau circulaire au centre du berceau.

---

# 📷 SECTION 8 : SCAN 3D ET "PHOTO VERS USINAGE"

## 8.1 Pipeline de Reconstruction 3D (`reco3d_client.dart`)
1. **Acquisition** : Prise de vue guidée de la pièce brute ou du modèle sous plusieurs angles.
2. **Communication Repos** : Transmission au serveur de traitement 3D (`prismatic_pipeline_service.dart` / `step_pipeline_service.dart`).
3. **Génération de Primitives** : Identification des géométries prismatiques (plans, cylindres, perçages, évidements).
4. **Synthèse G-Code** : Création automatique du parcours d'outil 5-axes optimisé et vérifié par l'analyseur cinématique.

---

# 🔍 SECTION 9 : GUIDE DE DÉPANNAGE ET CODES D'ALARME

| Code Alarme | Intitulé GRBL / FluidNC | Cause Probable | Action Corrective Recommandée |
| :--- | :--- | :--- | :--- |
| **ALARM:1** | Hard limit triggered | Un contacteur de fin de course NC s'est ouvert en cours de mouvement. | 1. Cliquer sur **Récupération Limites**.<br>2. Envoyer `$X` pour déverrouiller.<br>3. Effectuer un jog lent à l'opposé du capteur.<br>4. Relancer le Homing `$H`. |
| **ALARM:2** | Soft limit target exceeded | Le G-code demande un déplacement hors des courses max configurées. | 1. Vérifier le WCS actif (`G54`).<br>2. Vérifier les dimensions du fichier dans l'adaptateur CAM.<br>3. Reposer l'origine pièce correctement. |
| **ALARM:3** | Abort during cycle | Annulation du programme par Soft Reset (`Ctrl-X`) ou coupure. | 1. Vérifier l'état de l'outil et de la pièce.<br>2. Faire remonter Z en mode manuel.<br>3. Relancer la prise d'origine. |
| **ALARM:8** | Homing fail direction | Le capteur de fin de course ne s'est pas déclenché pendant la recherche. | 1. Vérifier le câblage du switch.<br>2. Vérifier la direction de homing `$Hx/search_velocity` dans le YAML. |
| **ALARM:11**| Emergency Stop active | Le bouton coup-de-poing E-STOP (GPIO 15) est enfoncé ou débranché. | 1. Déverrouiller physiquement le bouton d'arrêt d'urgence.<br>2. Envoyer `$X` pour réinitialiser le contrôleur. |

---

*Documentation technique d'ingénierie — Référence officielle pour le projet Forgeron CNC 5-Axes.*
