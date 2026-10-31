# Documentation Technique : Adaptabilité Médicale, Chaîne CAM STEP/STL, Exécution CNC & Gestion des Outils

*Projet de Fin d'Études (PFE) — ENI*  
*Modules : `pipeline/medical_implant.py`, `pipeline/gen_revolution.py`, `lib/core/utils/gcode_tool_extractor.dart`, `lib/presentation/screens/tool_table_screen.dart`, `lib/application/providers/ai_agent_provider.dart`*  
*Branche : `feat/implants-medicaux`*  
*Date : Octobre 2026*

---

# 🩺 1. ADAPTABILITÉ MÉDICALE & NORME ISO 13485

L'usinage d'implants médicaux (plaques crâniennes, inserts articulaires, guides de coupe chirurgicale) sur une micro-fraiseuse CNC 5 axes Trunnion impose des contraintes mécaniques, chimiques et réglementaires strictes.

```
       [Fichier 3D : STEP / STL]
                   │
                   ▼
       [Analyse Géométrique & Matériau]
         ├── Refus automatique métaux durs (Ti-6Al-4V, CoCrMo)
         └── Validation polymères biocompatibles (PEEK, UHMWPE, PMMA, Résine)
                   │
                   ▼
       [Génération CAM Spécifique]
         ├── Ébauche 3 axes surfacique par tranches (Drop-Cutter)
         ├── Finition 5 axes continu orientée normale de surface
         ├── Coupe à sec obligatoire (M9, pas de lubrifiant chimique)
         └── Émission formelle du changement d'outil (T1 M6)
                   │
                   ▼
       [Validation ForceGuard & Streaming FluidNC]
         └── Exécution directe et surveillance magasin d'outils
```

## 1.1 Matériaux et Garde-fous Biocompatibles
1. **Refus transparent des alliages réfractaires** :
   - Le titane médical (`Ti-6Al-4V ELI`, ISO 5832-3) et le cobalt-chrome (`CoCrMo`, ISO 5832-4) nécessitent une puissance de broche > 1,5 kW et une rigidité de bâti industrielle. Sur la broche DC 775 (200 W) de Forgeron, l'assistant refuse formellement l'usinage pour éviter l'écrouissage de la matière et la casse d'outil.
2. **Polymères biocompatibles autorisés** :
   - **PEEK médical** (ISO 10993 / ASTM F2026) : $ap \le 0{,}15\text{ mm}$, coupe à sec obligatoire $M9$, vitesse 18 000 tr/min.
   - **UHMWPE** (ISO 5834-2) : inserts articulaires, vitesses et avances modérées pour éviter l'échauffement plastique.
   - **PMMA & Résines biocompatibles** : guides chirurgicaux, implants temporaires.
3. **Dossier de traçabilité ISO 13485** :
   - Chaque génération produit un rapport complet avec hash SHA-256 du modèle 3D d'entrée, du G-code généré, identifiant de lot, tolérances crête calculées ($\mu\text{m}$) et engagement de l'opérateur.

---

# 📐 2. SUPPORT UNIFIÉ STEP (CAO B-Rep) & STL (Maillage)

L'importation de géométries 3D supporte à 100% les deux formats :
1. **Fichiers STEP (ISO 10303)** :
   - Prise en charge native via OpenCASCADE (`read_step_file`, facettisation contrôlée par déflexion métrique $\le 0{,}01\text{ mm}$).
   - Conservation de la topologie exacte et des surfaces analytiques.
2. **Fichiers STL** :
   - Triangulation optimisée, détection et orientation automatique à plat ($Z$ = épaisseur minimale, $Y$ = axe de plus grande course 150 mm, $X$ = course 88 mm).
   - Recentrage automatique du repère $G54$ ($X, Y$ centrés sur $0$, sommet de la pièce à $Z=0$).
   - Plafonnement cinématique des rotations du trunnion : limitation de l'axe $A$ à $\pm 65^\circ$ pour éviter les collisions avec le plateau et régularisation angulaire pour éliminer les à-coups aux singularités ($|A| < 5^\circ$).

---

# 🤖 3. CONVERSATIONNEL, AUTONOMIE & VERROUILLAGE LINGUISTIQUE

## 3.1 Exécution de Bout en Bout en Langage Naturel
Pour répondre aux besoins des utilisateurs non techniques, l'agent IA prend en charge la totalité du cycle sans obliger l'opérateur à taper des commandes console :
1. Analyse et prévisualisation du modèle 3D (`preview_step_file`).
2. Génération du G-code optimisé avec validation ForceGuard (`run_step_pipeline`).
3. Chargement automatique dans la machine et déclenchement de l'usinage via `run_program` (ou `start_stream`).

## 3.2 Verrouillage Anti-Dérive Linguistique (Français / Multilingue)
- **Positionnement terminal** : La règle linguistique (`_languageEnforcementBlock`) est placée à la fin absolue du prompt système, garantissant un poids maximal dans l'attention du modèle local Qwen2.5.
- **Interception `driftedToEnglish`** : Détection automatique des basculements en anglais après exécution d'outils techniques ou en cas d'erreurs/timeouts CAM, avec répétition automatique de la réponse dans la langue de l'opérateur.

---

# 🔧 4. GESTION DES OUTILS & SYNCHRONISATION DU MAGASIN D'OUTILS

## 4.1 Diagnostic du problème « 0 outils, alors qu'un programme était en cours »
L'opérateur constatait sur l'écran **Magasin d'Outils** l'affichage contradictoire :
- `PROGRAM TOOLS : 0 tool`
- `NO PROGRAM LOADED : Tools are read from the G-code. Load a program from the workspace...`
alors même qu'un usinage était activement en cours sur la CNC.

### Deux causes fondamentales ont été identifiées :
1. **Absence de syntaxe `T.. M6` dans les générateurs CAM** :
   - Les programmes de surfaçage ou d'implants médicaux ne comportaient que des commentaires comme `(OUTIL : FRAISE BOULE DIAM 3.0 MM)` ou `M0 (VERIFIER FRAISE BOULE...)` sans commande formelle `T1 M6`.
   - `GCodeToolExtractor.extract` exigeait obligatoirement la présence de `M6` pour créer un objet `ProgramTool`.
   - En conséquence, `programToolsProvider` renvoyait une liste vide `[]`.
2. **Absence de discernement dans l'état vide de l'UI** :
   - `ToolTableScreen` et `MobileToolTableScreen` testaient uniquement `tools.isEmpty`.
   - Dès que la liste était vide, ils affichaient sans nuance le panneau `"AUCUN PROGRAMME CHARGÉ"`, même si 3 000 lignes de G-code étaient chargées ou en train d'être exécutées par FluidNC.

---

## 4.2 Solutions Appliquées

### A. Émission formelle de `T1 M6` dans les générateurs CAM
- Dans `pipeline/medical_implant.py` et `pipeline/gen_revolution.py`, chaque programme généré déclare désormais formellement :
  ```gcode
  G21 G90 G94 G17 G40
  G54
  T1 M6 (FRAISE BOULE DIAM 3.0 MM - PEEK MEDICAL)
  M5
  M9 (INTERDICTION D ARROSAGE - BIOCOMPATIBILITE POLYMERE)
  G0 Z25.000
  ```
- `GcodeAdapter` transforme ce bloc en pause sécurisée `M0` pour FluidNC tout en maintenant la consigne d'outil actif.

### B. Extraction intelligente des programmes mono-outil dans `GCodeToolExtractor`
- Si un programme ne comporte pas de bloc `M6` explicite, mais dispose d'un en-tête d'outil `(OUTIL : ...)` ou `(TOOL: ...)`, l'extracteur déduit automatiquement un `ProgramTool` complet :
  - Numéro d'outil (1 ou numéro `T` présent dans le fichier).
  - Descriptif, diamètre ($\text{mm}$), forme géométrique (ex. hémisphérique `ballNose`).
  - Vitesse de broche déduite du mot $S$.

### C. États dynamiques et contextualisés de l'écran Magasin d'Outils
`ToolTableScreen` et `MobileToolTableScreen` gèrent désormais trois états bien distincts lorsque `tools.isEmpty` :
1. **Usinage en cours (`isRunning`)** :
   - Badge d'en-tête : `EN COURS` (orange/vert).
   - Message central : `PROGRAMME EN COURS D'EXÉCUTION`.
   - Affichage de l'outil monté dans la broche (`ACTIF : T1`) et du fichier/nombre de lignes en cours d'usinage.
2. **Programme chargé dans l'espace de travail (`hasProgram`)** :
   - Badge d'en-tête : `PROGRAMME ACTIF`.
   - Message central : `PROGRAMME CHARGÉ SANS OUTIL DÉCLARÉ`.
   - Explication claire : le programme ne contient pas de changement d'outil `T.. M6`, l'usinage s'effectuera avec l'outil déjà installé en broche.
3. **Machine au repos sans fichier (`aucun programme`)** :
   - Message traditionnel d'attente : `AUCUN PROGRAMME CHARGÉ`.

---

# ✅ 5. VALIDATION ET TESTS
- `test/gcode_tool_extractor_test.dart` : 14/14 tests passés avec succès (support des programmes mono-outil sans `M6`, en-têtes français et anglais).
- `test/program_tools_pipeline_test.dart` : vérification complète de la chaîne d'outils et de l'adaptation FluidNC.
- `pipeline/test_medical_implant.py` : 100% de réussite sur la chaîne complète PEEK, STEP, STL, cotes certifiées et garde-fous.
