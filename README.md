# Forgeron — Contrôleur CNC 5-Axes Moderne

**Forgeron** est une application Flutter de pointe conçue pour le pilotage de machines CNC 5-axes (configuration Trunnion X,Y,Z,A,C). Optimisée pour le firmware **FluidNC**, elle offre une interface intuitive, fluide et performante pour les opérateurs et les ingénieurs.

## 🚀 Fonctionnalités Clés

- **Contrôle 5-Axes Temps Réel** : Visualisation et pilotage simultané des axes linéaires (X, Y, Z) et rotatifs (A, C).
- **Moteur Cinématique RTCP** : Support du Remote Tool Center Point (G43.4) pour une précision accrue lors des usinages complexes.
- **Gestionnaire de Fichiers** : Téléchargement, sélection et exécution de fichiers G-Code directement depuis l'interface.
- **Terminal MDI & Diagnostics** : Console de commande directe et monitoring précis de l'état de la machine (températures, buffers, fins de course).
- **Palpage (Probing) & Table d'Outils** : Assistants dédiés pour le réglage des origines et la gestion des correcteurs d'outils.
- **Design Adaptatif** : Interface "Glassmorphism" sombre optimisée pour les environnements industriels.

## 🛠 Architecture Technique

Le projet suit les principes de la **Clean Architecture** pour garantir une maintenabilité et une testabilité optimales :

- **Presentation** : UI construite avec des widgets personnalisés (GlassPanel, TrunnionVisualizer).
- **Application** : Logique métier orchestrée par **Riverpod** (Config, File, GCode, Jog, Machine).
- **Domain** : Modèles de données immuables générés avec **Freezed**.
- **Data** : Communication avec FluidNC via WebSocket et HTTP, parseur GRBL/FluidNC sur mesure.

## 📦 Installation

1.  **Prérequis** : Flutter SDK (^3.10.0)
2.  **Clonage** : `git clone https://github.com/votre-repo/forgeron.git`
3.  **Dépendances** : `flutter pub get`
4.  **Génération de code** : `flutter pub run build_runner build`
5.  **Lancement** : `flutter run -d windows` (ou votre plateforme cible)

## 📐 Spécifications de la Machine (Trunnion)

- **Pivot To Table Offset** : 45.0 mm (configurable)
- **Tool Length Compensation** : Gérée dynamiquement par le `KinematicsService`.
- **Système de Coordonnées** : Support complet des G54 à G59.3.

---
*Projet réalisé dans le cadre d'un Projet de Fin d'Études (PFE).*
