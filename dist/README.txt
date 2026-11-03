================================================================================
           FORGERON CNC 5-AXES — GUIDE DE DISTRIBUTION & COMMANDES
================================================================================
Version : 1.0.0 (Production Windows 64-bit)
Éditeur : Projet Forgeron — ENI Unipods

--------------------------------------------------------------------------------
1. FICHIER PRINCIPAL RECOMMANDÉ : IMAGE DISQUE UNIQUE .ISO
--------------------------------------------------------------------------------

Pour déployer Forgeron sur un autre PC sans risque d'égarer de fichier :

  -> dist\Forgeron_CNC_5Axis_v1.0.iso (~14,5 Go)

UTILISATION SUR LE PC CIBLE :
1. Copiez UNIQUEMENT "Forgeron_CNC_5Axis_v1.0.iso" sur votre clé USB.
2. Sur le PC hôte, faites un simple DOUBLE-CLIC sur le fichier .iso.
   Windows le monte automatiquement comme un lecteur virtuel "FORGERON_CNC".
3. Lancez "Forgeron_CNC_5Axis_Setup_v1.0.exe" ou "INSTALLER_FORGERON.cmd".
4. Une fois l'installation terminée, clic droit sur le lecteur > "Éjecter".

--------------------------------------------------------------------------------
2. FICHIERS SÉPARÉS ALTERNATIFS (DANS CE DOSSIER)
--------------------------------------------------------------------------------

- Forgeron_CNC_5Axis_Setup_v1.0.exe      (~3,6 Mo)  : Programme d'installation
- Forgeron_CNC_5Axis_Setup_v1.0-1.bin   (~14,5 Go) : Archive de données unifiée
(Ces deux fichiers doivent obligatoirement rester dans le même répertoire).

--------------------------------------------------------------------------------
3. COMMANDES POUR CONSTRUIRE LE BUILD ET L'IMAGE .ISO
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
4. DIAGNOSTIC ET JOURNAUX D'ACTIVITÉ
--------------------------------------------------------------------------------

- Journal de diagnostic démarrage : %LOCALAPPDATA%\Forgeron\logs\startup.log
- Journal superviseur Python     : %LOCALAPPDATA%\Forgeron\logs\services.log
- Composant 3D requis             : Microsoft Edge WebView2 Evergreen Runtime

================================================================================
                        PROJET FORGERON — ENI UNIPODS
================================================================================
