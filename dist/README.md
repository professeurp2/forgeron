# Forgeron CNC 5-Axes — Guide de Distribution & Commandes de Build

Ce dossier contient les livrables d'installation autonome et d'exécution hors-ligne du logiciel **Forgeron CNC 5-Axes** (Version 1.0.0 pour Windows 10 / 11 64 bits).

---

## 💿 1. Fichier Principal Recommandé : Image Disque Unique `.ISO`

Pour déployer l'application sur un autre PC sans risque d'égarer des fichiers compagnons :

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

## 🛠️ 3. Commandes pour Générer le Build et l'ISO

Toutes les commandes s'exécutent depuis un terminal PowerShell à la racine du projet `forgeron` :

### A. Commande complète de bout en bout (Recommandée)
Recompile l'application Flutter en mode Release, prépare l'environnement autonome Python/OCP, intègre le serveur Ollama et ses modèles IA, exécute la compression Inno Setup et génère automatiquement le fichier `.iso` unique :
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

## 🔍 4. Dépannage Rapide

- **L'application se ferme au lancement sur un nouveau PC :**  
  Les bibliothèques Microsoft Visual C++ 2015–2022 (`msvcp140.dll`, `vcruntime140.dll`, etc.) sont désormais intégrées directement dans le paquet. En cas d'anomalie, consultez le fichier journal de diagnostic créé à cet effet :  
  `%LOCALAPPDATA%\Forgeron\logs\startup.log`
- **Simulation 3D indisponible :**  
  Installez le composant gratuit [Microsoft Edge WebView2 Evergreen Runtime](https://go.microsoft.com/fwlink/p/?LinkId=2124703).

---

*Projet Forgeron CNC 5-Axes — ENI Unipods Bamako.*
