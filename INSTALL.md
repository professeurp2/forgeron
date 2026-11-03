# Guide d'Installation — Forgeron CNC 5-Axes (Windows)

Ce guide décrit la procédure complète pour installer et exécuter l'application industrielle **Forgeron CNC 5-Axes** sur un poste de travail Windows (atelier ou bureau d'études).

Le paquet d'installation fourni est **100 % autonome et hors-ligne** : il intègre l'ensemble du système (interface utilisateur, moteurs de calcul géométrique OpenCASCADE, scan 3D Meshroom, serveur d'inférence IA Ollama et modèles pré-calibrés). Aucune connexion Internet n'est requise.

---

## 📋 1. Configuration Système Requise

| Composant | Configuration Minimale | Configuration Recommandée |
| :--- | :--- | :--- |
| **Système d'exploitation** | Windows 10 (64-bit) version 1909+ | Windows 11 (64-bit) |
| **Processeur (CPU)** | Intel Core i5 / AMD Ryzen 5 (4 cœurs) | Intel Core i7 / AMD Ryzen 7 (8 cœurs ou plus) |
| **Mémoire vive (RAM)** | 8 Go | 16 Go à 32 Go |
| **Carte Graphique (GPU)** | GPU intégré (Intel UHD / Iris Xe) avec support Vulkan | GPU dédié NVIDIA (RTX 3060, 3070, 4060 ou supérieur) avec 6 à 8 Go VRAM pour l'IA en temps réel |
| **Espace disque libre** | 25 Go sur le disque cible | 35 Go (SSD NVMe fortement recommandé) |
| **Ports de communication** | Wi-Fi ou Ethernet (liaison réseau vers l'ESP32 FluidNC) | Wi-Fi + Ethernet dédié atelier |

---

## 📦 2. Fichiers Requis pour l'Installation

Le paquet d'installation autonome se compose de **deux fichiers indissociables** situés dans le dossier `dist/` (ou sur votre clé USB d'installation) :

1. **`Forgeron_CNC_5Axis_Setup_v1.0.exe`** (~3,6 Mo)  
   L'exécutable d'installation contenant le programme d'assistant, l'interface graphique et le carrousel de présentation.
2. **`Forgeron_CNC_5Axis_Setup_v1.0-1.bin`** (~14,5 Go)  
   L'archive de données compressée contenant l'intégralité du système embarqué (Frontend Flutter, Python 3.12, noyau CAO OpenCASCADE, photogrammétrie Meshroom, Ollama et modèles IA `forgeron-qwen` + `gemma3n`).

> [!IMPORTANT]
> Les fichiers `.exe` et `.bin` **doivent obligatoirement se trouver dans le même dossier** lors du lancement de l'installation. Ne renommez aucun des deux fichiers.

---

## 🚀 3. Procédure d'Installation Pas à Pas

### Étape 1 : Préparation
- Copiez le dossier contenant `Forgeron_CNC_5Axis_Setup_v1.0.exe` et `Forgeron_CNC_5Axis_Setup_v1.0-1.bin` sur le disque dur du PC (par exemple sur le *Bureau* ou dans vos *Téléchargements*).

### Étape 2 : Lancement de l'installateur
- Faites un double-clic sur **`Forgeron_CNC_5Axis_Setup_v1.0.exe`**.
- Si Windows affiche l'écran de protection **Windows Defender SmartScreen** (*« Windows a protégé votre ordinateur »*) :
  1. Cliquez sur le lien **« Informations complémentaires »**.
  2. Cliquez sur le bouton **« Exécuter quand même »**.
  *(Ce message est normal pour les exécutables industriels récents n'utilisant pas de certificat commercial tiers).*
- Cliquez sur **« Oui »** à la demande d'élévation Administrateur (UAC).

### Étape 3 : Choix de la langue
- Sélectionnez la langue de l'assistant (**Français** ou **English**), puis cliquez sur **OK**.

### Étape 4 : Choix du dossier d'installation
- L'emplacement par défaut est :  
  `C:\Program Files\Forgeron`  
  *(Vous pouvez choisir un autre lecteur, par exemple `D:\Forgeron`, si votre disque C: manque d'espace).*
- Cliquez sur **Suivant**.

### Étape 5 : Options de raccourcis
- Laissez cochée la case **« Créer une icône sur le Bureau »** pour un accès rapide.
- Cliquez sur **Suivant**, puis sur **Installer**.

### Étape 6 : Extraction et Défilement du Carrousel
- Pendant l'extraction (environ 3 à 5 minutes selon les performances de votre disque SSD) :
  - Observez le **carrousel promotionnel intégré** qui présente les fonctionnalités majeures de Forgeron (Fraiseuse 5 axes, Agent IA vocal en Bambara et Français, Jumeau numérique 3D temps réel, Sécurité ForceGuard et Fabrication locale à Bamako).
  - La rotation s'effectue automatiquement toutes les 4 secondes.

### Étape 7 : Fin de l'installation
- Une fois l'extraction achevée, cochez **« Lancer Forgeron CNC 5-Axes »** et cliquez sur **Terminer**.

---

## ⚙️ 4. Fonctionnement Automatique des Services Arrière-Plan

Dès que vous démarrez l'application Forgeron :

1. **Superviseur Transparent :**  
   L'application lance automatiquement en tâche de fond le superviseur silencieux (`runtime/forgeron_services.py` via `pythonw.exe`). Aucune fenêtre noire de terminal ne s'affiche.
2. **Serveur IA Local (Ollama) :**  
   - Ollama démarre automatiquement sur le port local `11434`.
   - Le modèle de pilotage CNC **`forgeron-qwen`** (Qwen 2.5 7B calibré avec contexte étendu 16 384 tokens) et le modèle de vision **`gemma3n`** sont immédiatement chargés.
   - Les permissions d'écriture sont gérées automatiquement (redirection dynamique avec jonction NTFS vers `%LOCALAPPDATA%\Forgeron\ollama\models` si le dossier d'installation est verrouillé en écriture par Windows).
3. **Serveur Scan 3D / Reco3D :**  
   - Le service local de reconstruction photogrammétrique démarre sur le port `8765`.
4. **Arrêt Propre :**  
   Lorsque vous quittez l'application Forgeron, le superviseur détecte la fermeture et arrête automatiquement Ollama et Reco3D pour libérer instantanément la mémoire vive (RAM) et la mémoire graphique (VRAM) du PC.

---

## 🔍 5. Vérification du Bon Fonctionnement

Après le premier lancement de l'application :

1. **Vérifier l'IA Locale :**
   - Ouvrez l'onglet **Assistant IA** dans l'application Forgeron.
   - Dans l'en-tête de la discussion, vous devez voir la pastille verte :  
     `LOCAL · forgeron-qwen:latest ⇄`
   - Tapez simplement : `salut` ou `bonjour`.
   - L'agent doit répondre immédiatement en français sans afficher d'erreur.
2. **Vérifier la Connexion CNC :**
   - Rendez-vous dans **Connexion**.
   - Cliquez sur **Scanner** pour découvrir votre machine FluidNC sur le réseau local ou entrez directement l'adresse IP de l'ESP32.

---

## 📂 6. Emplacement des Données et Fichiers de Journalisation

- **Dossier d'installation principal :**  
  `C:\Program Files\Forgeron\` (ou dossier personnalisé choisi lors de l'installation)
- **Journaux d'activité (logs) :**  
  `%LOCALAPPDATA%\Forgeron\logs\`  
  *(Contient `services.log`, `ollama.log` et les sorties des modules CAO).*
- **Stockage temporaire des reconstructions 3D :**  
  `%LOCALAPPDATA%\Forgeron\reco3d\storage\`
- **Préférences et réglages opérateur :**  
  Stockés dans les profils sécurisés locaux de Windows (`SharedPreferences` protégées par `PrefsFileGuard`).

---

## 🛠️ 7. Dépannage Fréquent

### Q : L'installateur indique que le fichier `.bin` est introuvable.
- **Solution :** Assurez-vous que le fichier `Forgeron_CNC_5Axis_Setup_v1.0-1.bin` se trouve exactement dans le même répertoire que `Forgeron_CNC_5Axis_Setup_v1.0.exe`.

### Q : L'agent IA indique une erreur de connexion au serveur local.
- **Solution :**
  1. Attendez 5 à 10 secondes après le démarrage de l'application (le temps que le modèle de 4,5 Go soit monté en VRAM par Ollama).
  2. Si un serveur Ollama externe tournait déjà sur le PC avant le lancement de l'app, fermez-le depuis la barre des tâches pour laisser Forgeron gérer son instance dédiée.
  3. Consultez le fichier journal `%LOCALAPPDATA%\Forgeron\logs\services.log` pour diagnostiquer l'état du démarrage.

### Q : Comment désinstaller l'application ?
- Rendez-vous dans **Paramètres Windows** > **Applications** > **Applications installées**, cherchez **Forgeron CNC 5-Axes** et cliquez sur **Désinstaller**.
- Vous pouvez également exécuter directement `unins000.exe` situé dans le dossier d'installation `C:\Program Files\Forgeron\`.

---

*Développé dans le cadre du Projet Forgeron — Fabrication numérique 5 axes industrielle et accessible.*
