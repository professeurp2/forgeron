================================================================================
           FORGERON CNC 5-AXES — GUIDE DE DISTRIBUTION & CONFIGURATION
================================================================================
Version : 1.0.0 (Production Windows & Android)
Éditeur : Projet Forgeron — ENI Unipods

--------------------------------------------------------------------------------
1. FICHIER PRINCIPAL RECOMMANDÉ : IMAGE DISQUE UNIQUE .ISO
--------------------------------------------------------------------------------

Pour déployer Forgeron sur un PC Windows sans risque d'égarer de fichier :

  -> dist\Forgeron_CNC_5Axis_v1.0.iso (~14,5 Go)

UTILISATION SUR LE PC CIBLE :
1. Copiez UNIQUEMENT "Forgeron_CNC_5Axis_v1.0.iso" sur votre clé USB.
2. Sur le PC hôte, faites un simple DOUBLE-CLIC sur le fichier .iso.
   Windows le monte automatiquement comme un lecteur virtuel "FORGERON_CNC".
3. Lancez "Forgeron_CNC_5Axis_Setup_v1.0.exe" ou "INSTALLER_FORGERON.cmd".
4. Une fois l'installation terminée, clic droit sur le lecteur > "Éjecter".

--------------------------------------------------------------------------------
2. FICHIERS SÉPARÉS ALTERNATIFS (WINDOWS)
--------------------------------------------------------------------------------

- Forgeron_CNC_5Axis_Setup_v1.0.exe      (~3,6 Mo)  : Programme d'installation
- Forgeron_CNC_5Axis_Setup_v1.0-1.bin   (~14,5 Go) : Archive de données unifiée
(Ces deux fichiers doivent obligatoirement rester dans le même répertoire).

--------------------------------------------------------------------------------
3. APPLICATION MOBILE ANDROID (.APK) — INSTALLATION & CONFIGURATION
--------------------------------------------------------------------------------

A. COMPILATION & INSTALLATION DE L'APK :
1. Pour compiler l'application Android :
   flutter build apk --release
   (Fichier généré : build/app/outputs/flutter-apk/app-release.apk)
2. Transférez le fichier .apk sur votre smartphone ou tablette d'atelier.
3. Autorisez l'installation d'applications inconnues si demandé.
4. Acceptez les autorisations au premier lancement :
   - Caméra     : Inspection visuelle des pièces brutes et outils par l'IA.
   - Microphone : Dictée et commandes vocales (français / bambara).
   - Wi-Fi      : Connexion directe à l'ESP32 FluidNC de la fraiseuse.

B. CONFIGURATION INITIALE DE LA CLÉ API GEMINI :

Pour bénéficier de l'IA multimodale distante (texte + vision), configurez votre
clé API personnelle Google Gemini (gratuite sur https://aistudio.google.com) :

----------------------------------------------------------------------
CLE_API_GEMINI: VOTRE_CLE_API_ICI
----------------------------------------------------------------------

PROCÉDURE DANS L'APPLICATION MOBILE :
1. Ouvrez l'application Forgeron sur votre téléphone / tablette.
2. Touchez l'icône "Réglages" (engrenage en haut à droite).
   [CAPTURE 1 : Accès aux réglages de l'application]
3. Sélectionnez le menu "Agent IA".
   [CAPTURE 2 : Menu Agent IA]
4. Faites défiler jusqu'à la section "Clé API Gemini".
5. Collez votre clé API dans le champ textuel et touchez "Enregistrer".
   [CAPTURE 3 : Saisie de la clé API Gemini]
6. Un message confirme : "Clé API enregistrée".
   La clé est chiffrée dans le trousseau sécurisé de l'appareil (Keystore).
   [CAPTURE 4 : Confirmation d'enregistrement]
7. Rendez-vous dans l'onglet "Assistant IA" et testez un message ou une photo.
   [CAPTURE 5 : Discussion et vision active avec l'agent]

C. CONNEXION À LA MACHINE CNC DEPUIS L'APK :
1. Connectez le smartphone au Wi-Fi de l'atelier ou au point d'accès de la CNC.
2. Ouvrez l'onglet "Connexion".
3. Touchez "Scanner" ou entrez l'adresse IP de la fraiseuse (ex: 192.168.4.1).
4. Touchez "Connecter" pour afficher la télémétrie en temps réel.

--------------------------------------------------------------------------------
4. COMMANDES POUR CONSTRUIRE LE BUILD WINDOWS ET L'IMAGE .ISO
--------------------------------------------------------------------------------

Toutes les commandes s'exécutent depuis PowerShell à la racine du projet :

A. COMMANDE COMPLÈTE DE BOUT EN BOUT (Recommandée) :
   Compile Flutter Release, prépare Python/OCP, intègre Ollama et les modèles IA,
   compresse l'installateur et crée le fichier unique .ISO :
   
   powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1

B. COMMANDE RAPIDE (Sans recompiler Flutter) :
   Génère l'installateur et l'image ISO avec les binaires déjà compilés :
   
   powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1 -SkipFlutterBuild

C. RÉGÉNÉRATION EXPRESS DE L'IMAGE .ISO SEULE (~25 secondes) :
   Recrée l'image ISO à partir des fichiers .exe et .bin déjà présents :
   
   powershell -ExecutionPolicy Bypass -File tool\create_iso.ps1

--------------------------------------------------------------------------------
5. DIAGNOSTIC ET DÉPANNAGE
--------------------------------------------------------------------------------

- Crash Windows au lancement : Les DLLs VC++ (msvcp140.dll...) sont embarquées.
  Consultez le journal : %LOCALAPPDATA%\Forgeron\logs\startup.log
- Simulation 3D Windows      : Requiert Microsoft Edge WebView2 Evergreen Runtime.
- Agent IA Mobile muet       : Vérifiez la connexion Internet du smartphone et
  la validité de la clé API Gemini saisie.

================================================================================
                        PROJET FORGERON — ENI UNIPODS
================================================================================
