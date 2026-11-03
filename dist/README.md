# Forgeron CNC 5-Axes — Guide de Distribution & Configuration Mobile

Ce dossier contient les livrables d'installation autonome, les commandes de génération et les procédures de mise en route de l'application **Forgeron CNC 5-Axes** (Windows et Android).

---

## 💿 1. Fichier Principal Recommandé : Image Disque Unique `.ISO`

Pour déployer l'application sur un autre PC Windows sans risque d'égarer des fichiers compagnons :

| Fichier | Taille | Rôle |
| :--- | :--- | :--- |
| **`Forgeron_CNC_5Axis_v1.0.iso`** | **~14,5 Go** | **Fichier unique complet autonome** (contient l'installateur, l'archive des modèles IA, les dépendances C++, Python/OCP et le lanceur automatique). |

### 🚀 Utilisation sur le PC cible :
1. Copiez **uniquement** le fichier `Forgeron_CNC_5Axis_v1.0.iso` sur une clé USB ou un disque externe.
2. Sur le PC hôte, faites un **simple double-clic** sur le fichier `.iso`. Windows l'ouvre immédiatement comme un lecteur virtuel nommé **`FORGERON_CNC`**.
3. Lancez l'installation en double-cliquant sur `Forgeron_CNC_5Axis_Setup_v1.0.exe` ou `INSTALLER_FORGERON.cmd`.
4. Une fois l'installation terminée, faites un clic droit sur le lecteur virtuel dans l'Explorateur Windows > **Éjecter**.

---

## 📦 2. Fichiers d'Installation Séparés (Alternative)

Pour les besoins où les fichiers doivent être manipulés hors conteneur ISO :

| Fichier | Taille | Rôle |
| :--- | :--- | :--- |
| **`Forgeron_CNC_5Axis_Setup_v1.0.exe`** | ~3,6 Mo | Programme d'installation avec carrousel promotionnel et vérification des prérequis. |
| **`Forgeron_CNC_5Axis_Setup_v1.0-1.bin`** | ~14,5 Go | Archive de données compressée contenant l'application et les modèles IA. |

> [!IMPORTANT]
> Si vous utilisez ce mode, le fichier `.exe` et le fichier `.bin` doivent impérativement se trouver dans le **même répertoire**.

---

## 📱 3. Application Mobile Android (.APK) — Installation & Configuration Initiale

L'application Forgeron est également disponible au format **APK** pour smartphones et tablettes Android d'atelier, permettant le pilotage tactile de la machine, la commande vocale et l'assistance par vision IA.

### A. Génération et Installation de l'APK
1. **Compilation (depuis le terminal du projet) :**
   ```bash
   flutter build apk --release
   ```
   *L'exécutable généré se trouve dans : `build/app/outputs/flutter-apk/app-release.apk`.*
2. **Transfert & Installation :**
   - Transférez le fichier `.apk` sur votre appareil Android (via câble USB, WhatsApp, Google Drive ou partage local).
   - Ouvrez le fichier sur votre appareil et autorisez *« L'installation depuis cette source »* si Android affiche une invite de sécurité.
   - Acceptez les autorisations au premier lancement :
     - 📷 **Appareil photo (Caméra) :** Pour l'analyse visuelle des pièces brutes, la vérification des outils et la détection d'usure.
     - 🎙️ **Microphone :** Pour la dictée et les commandes vocales en atelier (français / bambara).
     - 📡 **Réseau local (Wi-Fi) :** Pour communiquer avec l'ESP32 de la machine CNC (FluidNC).

---

### B. Configuration Initiale : Ajout de la Clé API Gemini

Pour activer l'intelligence artificielle avancée (analyse multimodale, compréhension du langage naturel, génération de code G assistée), l'application utilise l'API Google Gemini.

#### 🔑 Votre Clé API Gemini :
> Insérez votre clé API personnelle dans l'emplacement ci-dessous :
```text
CLE_API_GEMINI: VOTRE_CLE_API_ICI
```

*(Vous pouvez obtenir ou renouveler une clé gratuitement sur [Google AI Studio](https://aistudio.google.com/app/apikey)).*

---

#### 🛠️ Procédure pas à pas dans l'application :

1. **Ouvrir les Réglages :**  
   Depuis l'écran principal de l'application Forgeron sur votre téléphone, touchez l'icône **Réglages** (⚙️) située dans le coin supérieur droit ou dans le menu de navigation.

   <!-- Emplacement Capture d'écran 1 : Écran d'accueil et accès aux réglages -->
   ![Accès aux Réglages](docs/screenshots/android_01_menu_settings.png)

2. **Accéder à la section « Agent IA » :**  
   Dans la liste des réglages, sélectionnez le menu **Agent IA**.

   <!-- Emplacement Capture d'écran 2 : Menu Agent IA -->
   ![Menu Agent IA](docs/screenshots/android_02_ai_settings.png)

3. **Saisir la Clé API Gemini :**  
   - Faites défiler jusqu'à la section **Clé API Gemini**.
   - Collez votre clé API dans le champ de saisie textuel.
   - Appuyez sur le bouton **Enregistrer**.

   <!-- Emplacement Capture d'écran 3 : Saisie et enregistrement de la clé API -->
   ![Saisie de la Clé API Gemini](docs/screenshots/android_03_enter_gemini_key.png)

4. **Validation et Activation :**  
   - Un message de confirmation s'affiche : *« Clé API enregistrée »*.
   - La clé est chiffrée et conservée en toute sécurité dans le stockage matériel (*Android Keystore*).
   - L'agent bascule automatiquement sur le moteur Gemini.

   <!-- Emplacement Capture d'écran 4 : Confirmation et statut actif -->
   ![Confirmation de la Clé API](docs/screenshots/android_04_key_confirmed.png)

5. **Tester la discussion avec l'Agent :**  
   - Retournez sur l'onglet **Assistant IA**.
   - La pastille en haut confirme le statut actif de l'agent.
   - Envoyez un premier message (ex: *« Bonjour, peux-tu analyser l'état de ma fraiseuse ? »*) ou prenez une photo d'une pièce brute pour vérifier le bon fonctionnement.

   <!-- Emplacement Capture d'écran 5 : Discussion et vision active -->
   ![Test de l'Assistant IA Mobile](docs/screenshots/android_05_chat_test.png)

---

### C. Connexion à la CNC depuis l'APK
1. Connectez votre smartphone au réseau Wi-Fi de l'atelier (ou directement au point d'accès Wi-Fi de la machine émis par l'ESP32).
2. Rendez-vous dans l'onglet **Connexion** de l'application.
3. Touchez **Scanner le réseau** ou entrez l'adresse IP de la machine (ex: `192.168.4.1` ou `192.168.1.150`).
4. Touchez **Connecter** : la télémétrie en temps réel (coordonnées X/Y/Z/A/B, broche, alarmes) s'affiche immédiatement.

---

## 🛠️ 4. Commandes pour Générer le Build Windows et l'ISO

Toutes les commandes de build Windows s'exécutent depuis PowerShell à la racine du projet `forgeron` :

### A. Commande complète de bout en bout (Recommandée)
Recompile Flutter Windows Release, prépare l'environnement Python/OCP, intègre Ollama et les modèles IA, lance Inno Setup et génère automatiquement le fichier `.iso` unique :
```powershell
powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1
```

### B. Commande rapide (sans recompiler Flutter)
Si le code Flutter n'a pas changé et que vous souhaitez uniquement reconstruire l'installateur et l'image `.iso` :
```powershell
powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1 -SkipFlutterBuild
```

### C. Régénération express de l'image `.ISO` seule (~25 secondes)
Si l'installateur (`.exe` et `.bin`) est déjà présent dans ce dossier `dist/` et que vous souhaitez simplement recréer l'image disque `.iso` :
```powershell
powershell -ExecutionPolicy Bypass -File tool\create_iso.ps1
```

---

## 🔍 5. Dépannage Rapide

- **L'application Windows se ferme au lancement sur un nouveau PC :**  
  Les bibliothèques Microsoft Visual C++ 2015–2022 (`msvcp140.dll`, `vcruntime140.dll`, etc.) sont intégrées directement dans le paquet. En cas d'anomalie, consultez le journal de diagnostic :  
  `%LOCALAPPDATA%\Forgeron\logs\startup.log`
- **Simulation 3D Windows indisponible :**  
  Installez le composant gratuit [Microsoft Edge WebView2 Evergreen Runtime](https://go.microsoft.com/fwlink/p/?LinkId=2124703).
- **L'Agent IA Mobile n'obtient pas de réponse :**  
  Vérifiez que votre smartphone a bien accès à Internet (Wi-Fi ou données mobiles 4G/5G) pour joindre l'API Gemini, et que votre clé API n'a pas expiré.

---

*Projet Forgeron CNC 5-Axes — ENI Unipods Bamako.*
