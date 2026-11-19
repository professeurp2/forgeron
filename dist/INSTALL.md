# Guide d'Installation — Forgeron CNC 5-Axes

Ce document décrit pas à pas la procédure d'installation et de mise en route du logiciel **Forgeron CNC 5-Axes** sur un ordinateur équipé de **Windows 10 ou 11 (64 bits)**.

---

## 💿 1. Format de Distribution — Fichier Unique `.ISO`

Pour une simplicité maximale de transfert et de déploiement en atelier, l'intégralité du système est désormais livrée en **un seul fichier autonome** :

📁 **`Forgeron_CNC_5Axis_v1.0.iso`** (~14,5 Go)

### Pourquoi une image disque `.ISO` ?
- **Un seul fichier à copier :** Finis les risques d'oubli ou d'égarement du fichier archive `.bin`. Vous ne transférez qu'un seul fichier sur votre clé USB ou disque externe.
- **Ouverture native sous Windows 10 et 11 :** Aucun logiciel tiers (type Daemon Tools ou WinRAR) n'est nécessaire. Un simple **double-clic** sur le `.iso` l'ouvre instantanément comme un lecteur DVD virtuel.
- **Intégration d'autorun et d'icône :** Le lecteur virtuel apparaît avec l'icône officielle de Forgeron et le nom `FORGERON_CNC`.
- **Contenu embarqué à 100 % hors-ligne :**
  - L'application cliente native Flutter Release (64 bits) avec ses dépendances C++ (MSVCP140, VCRUNTIME140).
  - L'environnement portable complet Python 3.12 (moteur géométrique OpenCASCADE/OCP, solveurs cinématiques, Uvicorn, FastAPI, Trimesh, Scipy).
  - Le moteur d'intelligence artificielle locale **Ollama** avec ses bibliothèques d'accélération matérielle (CUDA, Vulkan, DirectML).
  - Les modèles d'IA embarqués : **`forgeron-qwen`** (7B) et **`gemma3n`** (vision).
  - Le service de reconstruction 3D photogrammétrique **Reco3D** et **Meshroom**.

*(Pour les environnements nécessitant des fichiers séparés, la paire `Forgeron_CNC_5Axis_Setup_v1.0.exe` et `Forgeron_CNC_5Axis_Setup_v1.0-1.bin` reste également disponible dans `dist/`).*

---

## ⚙️ 2. Configuration Requise

- **Système d'exploitation :** Windows 10 (version 1903+) ou Windows 11 — 64 bits uniquement.
- **Processeur (CPU) :** Intel Core i5 / AMD Ryzen 5 ou supérieur recommandé.
- **Mémoire vive (RAM) :** 16 Go recommandés (8 Go minimum).
- **Espace disque libre :** Au moins **25 Go libres** sur le disque d'installation (SSD très fortement recommandé).
- **Carte graphique (GPU) :**
  - NVIDIA GeForce GTX 1060 / RTX ou plus récent avec pilotes à jour (recommandé pour l'accélération CUDA).
  - À défaut, le calcul CPU + Vulkan est automatiquement utilisé en mode dégradé mais fonctionnel.
- **Composants système :**
  - *Microsoft Visual C++ 2015-2022 Redistributable (x64) :* Inclus et configuré automatiquement par l'installateur et embarqué dans le dossier d'application.
  - *Microsoft Edge WebView2 Runtime :* Requis pour la visualisation 3D interactive (généralement préinstallé sur Windows 10/11 ; installable gratuitement si manquant).

---

## 🚀 3. Étapes d'Installation Simplifiées

1. **Copie du fichier :**  
   Copiez le fichier unique **`Forgeron_CNC_5Axis_v1.0.iso`** sur le PC cible (via clé USB, disque externe ou réseau).

2. **Montage du disque virtuel :**  
   Faites un **double-clic** sur le fichier `Forgeron_CNC_5Axis_v1.0.iso`.  
   Windows l'ouvre immédiatement comme un nouveau lecteur de disque nommé **`FORGERON_CNC`**.

3. **Lancement de l'installateur :**  
   Double-cliquez sur :
   - **`Forgeron_CNC_5Axis_Setup_v1.0.exe`** ou sur **`INSTALLER_FORGERON.cmd`**.
   - Si Windows SmartScreen affiche un filtre de protection, cliquez sur **Informations complémentaires** puis sur **Exécuter quand même**.

4. **Assistant d'installation :**  
   - Choisissez la langue d'installation (**Français** ou **English**).
   - Choisissez le dossier de destination (par défaut : `C:\Program Files\Forgeron\`).
   - Cochez l'option pour créer une icône sur le **Bureau** (recommandé).
   - Cliquez sur **Installer**.

5. **Décompression et intégration :**  
   Pendant l'extraction des fichiers (~2 à 4 minutes), un **carrousel visuel interactif** présente les points forts et capacités industrielles du projet Forgeron (fraisage 5 axes accessible, IA locale bilingue français/bambara, jumeau numérique 3D temps réel, sécurité active ForceGuard).

6. **Fin de l'installation :**  
   - Une fois l'installation terminée, cochez **Lancer Forgeron** puis cliquez sur **Terminer**.
   - Vous pouvez ensuite faire un clic-droit sur le lecteur virtuel dans l'explorateur Windows et cliquer sur **Éjecter**.

---

## 🤖 4. Fonctionnement Automatique des Services Intégrés

**Vous n'avez pas besoin d'ouvrir de terminal, ni de lancer Ollama ou Python manuellement.**

Dès que vous démarrez `forgeron.exe` (ou via le raccourci Bureau) :
1. **Superviseur en arrière-plan (`forgeron_services.py`) :**  
   Il s'exécute silencieusement (sans fenêtre d'invite de commandes).
2. **Serveur Ollama Embarqué :**  
   - Il démarre sur le port standard local `127.0.0.1:11434`.
   - Le modèle de pilotage CNC **`forgeron-qwen`** et le modèle de vision **`gemma3n`** sont immédiatement disponibles.
   - Les autorisations d'écriture sont gérées automatiquement par redirection dynamique (`%LOCALAPPDATA%\Forgeron\ollama\models`) si le dossier d'installation est verrouillé par Windows.
3. **Serveur Scan 3D / Reco3D :**  
   - Le service local de reconstruction photogrammétrique démarre sur le port `8765`.
4. **Arrêt Propre :**  
   Lorsque vous quittez Forgeron, le superviseur détecte la fermeture de l'application et arrête automatiquement Ollama et Reco3D pour libérer instantanément la mémoire vive (RAM) et la mémoire graphique (VRAM).

---

## 🔍 5. Vérification du Bon Fonctionnement

Après le premier lancement :

1. **Vérifier l'IA Locale :**
   - Ouvrez l'onglet **Assistant IA** dans Forgeron.
   - Dans l'en-tête de la discussion, observez la pastille verte :  
     `LOCAL · forgeron-qwen:latest ⇄`
   - Tapez simplement : `salut` ou `bonjour`. L'agent doit répondre immédiatement en français.
2. **Vérifier la Connexion CNC :**
   - Rendez-vous dans **Connexion**.
   - Cliquez sur **Scanner** pour découvrir votre machine FluidNC sur le réseau local ou entrez l'adresse IP de l'ESP32.

---

## 📂 6. Emplacement des Données et Fichiers de Journalisation

- **Dossier d'installation principal :**  
  `C:\Program Files\Forgeron\` (ou dossier choisi lors de l'installation)
- **Journaux d'activité (logs) :**  
  `%LOCALAPPDATA%\Forgeron\logs\`  
  - `startup.log` : Journal exhaustif de chaque étape de démarrage natif C++ et Dart.
  - `services.log` : Journal du superviseur Python (lancement/arrêt des serveurs).
  - `ollama.log` : Journal du serveur d'inférence IA locale.
- **Stockage temporaire des reconstructions 3D :**  
  `%LOCALAPPDATA%\Forgeron\reco3d\storage\`
- **Préférences et réglages opérateur :**  
  Stockés dans les profils locaux sécurisés de Windows (`SharedPreferences` protégées par `PrefsFileGuard`).

---

## 🛠️ 7. Dépannage Fréquent

### Q : L'application se ferme automatiquement quelques secondes après le lancement sur un nouveau PC.
- **Causes et solutions :**
  1. **Composants Visual C++ :** Les bibliothèques requises (`msvcp140.dll`, `vcruntime140.dll`, etc.) sont intégrées directement à côté de `forgeron.exe` et déployées par l'installateur.
  2. **Diagnostic immédiat :** Ouvrez le dossier `%LOCALAPPDATA%\Forgeron\logs\` (tapez cette adresse dans l'explorateur Windows) et consultez le fichier `startup.log`. Toutes les étapes de démarrage du moteur Flutter et de l'initialisation Dart y sont tracées avec l'heure exacte et le message d'erreur précis le cas échéant.
  3. **Composant WebView2 :** Si la fenêtre principale s'affiche mais que la vue 3D affiche « Simulateur 3D indisponible », installez le composant gratuit [Microsoft Edge WebView2 Evergreen Runtime](https://go.microsoft.com/fwlink/p/?LinkId=2124703).

### Q : L'agent IA indique une erreur de connexion au serveur local (HTTP 500 ou 503).
- **Solution :**
  1. Attendez 5 à 10 secondes après le démarrage de l'application (le temps que le modèle de 4,5 Go soit monté en VRAM par Ollama).
  2. Si un serveur Ollama externe tournait déjà sur le PC avant le lancement de l'app, quittez-le depuis la barre des tâches pour laisser Forgeron gérer son instance dédiée.
  3. Consultez le fichier journal `%LOCALAPPDATA%\Forgeron\logs\services.log`.

### Q : Comment désinstaller l'application ?
- Rendez-vous dans **Paramètres Windows** > **Applications** > **Applications installées**, cherchez **Forgeron CNC 5-Axes** et cliquez sur **Désinstaller**.
- Vous pouvez également exécuter directement `unins000.exe` situé dans le dossier d'installation `C:\Program Files\Forgeron\`.

---

*Développé dans le cadre du Projet Forgeron — Fabrication numérique 5 axes industrielle et accessible.*
