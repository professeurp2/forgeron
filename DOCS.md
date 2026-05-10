# Documentation Technique - Forgeron

Cette documentation détaille les aspects algorithmiques et structurels du projet Forgeron.

## 1. Moteur Cinématique (KinematicsService)

La machine utilise une configuration **Trunnion** (Berceau). 
- **A-Axis** : Rotation autour de l'axe X.
- **C-Axis** : Rotation autour de l'axe Z (fixé sur l'axe A).

### RTCP (Remote Tool Center Point)
L'implémentation du RTCP permet de maintenir la pointe de l'outil à une position constante par rapport à la pièce, même lors des rotations des axes A et C. 
La formule utilisée dans `calculateMachinePosition` effectue :
1. Une transformation matricielle (Rotation C puis A).
2. Une compensation du décalage du pivot (`pivotToTableOffset`).

## 2. Communication & Parsing (FluidNC)

La classe `GrblParser` est responsable de la désérialisation des flux textuels provenant de FluidNC.

### Formats de Statut
L'application écoute les rapports de statut `<State|...>` et met à jour le `MachineState` via Riverpod. Elle gère :
- Les positions Machine (`MPos`) et Travail (`WPos`).
- Les décalages d'origine (`WCO`).
- Les vitesses d'avance (`Feedrate`) et de broche (`Spindle`).
- L'état des broches de fin de course (`Lim`).

## 3. Gestion d'État (Riverpod)

L'état est segmenté par domaine pour éviter les reconstructions inutiles :
- `machineProvider` : État temps réel de la CNC.
- `gcodeProvider` : Flux de streaming G-Code et progression.
- `fileProvider` : Liste des fichiers sur la carte SD de la machine.
- `configProvider` : Paramètres de connexion et de machine.

## 4. Interface Utilisateur

L'UI utilise un thème personnalisé `AppTheme.darkTheme` basé sur des couleurs sombres (fond `#0F172A`) et des effets de transparence (Glassmorphism) pour une esthétique moderne et moins fatigante en atelier.

### Visualiseur Trunnion
Le composant `TrunnionVisualizer` utilise `vector_math` pour représenter graphiquement les mouvements de la machine en 3D, permettant à l'opérateur de valider les trajectoires avant l'usinage.

## 5. Maintenance & Évolutions

Pour ajouter un nouveau modèle de données :
1. Créer le fichier `.dart` dans `lib/domain/models/`.
2. Définir la classe avec `@freezed`.
3. Lancer `flutter pub run build_runner build`.
