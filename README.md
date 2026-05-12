# Forgeron — Contrôleur CNC 5-Axes Industriel

<p align="center">
  <img src="assets/logo.png" width="200" alt="Forgeron Logo">
</p>

**Forgeron** est une application Flutter de grade industriel conçue pour le pilotage haute performance de machines CNC 5-axes (configuration Trunnion X,Y,Z,A,C). Optimisée pour le firmware **FluidNC**, elle garantit un usinage sans saccades et une sécurité matérielle accrue.

## 🚀 Fonctionnalités Avancées

### 1. Rendu 3D Accéléré (GPU)
- **Moteur Haute Performance** : Utilisation de `flutter_cube` pour une visualisation fluide à 60 FPS.
- **Digital Twin** : Représentation cinématique réelle de la machine (Berceau, Plateau, Broche).
- **Gestion massive du Toolpath** : Supporte des trajectoires de +100 000 points via des meshes optimisés.

### 2. Streaming & Résilience (Industrial Grade)
- **Algorithme Character-Counting** : Gestion précise du buffer RX (127 octets) pour un streaming continu sans micro-arrêts.
- **Watchdog de Communication** : Surveillance temps réel avec mise en sécurité automatique en cas de perte réseau (>2s).
- **Reconnexion Intelligente** : Stratégie d'Exponential Backoff pour une résilience maximale en environnement industriel bruyant.

### 3. Sécurité & Lookahead
- **Validation Préventive** : Analyse complète du G-Code avant usinage pour détecter les collisions (Z < -5mm) et les dépassements de limites angulaires.
- **Détection de Singularité** : Calcul du risque de *Gimbal Lock* (Axe A ≈ 0°) avec alertes graduelles.
- **RTCP (G43.4)** : Moteur cinématique complet gérant les offsets pivot et la longueur d'outil.

### 4. Optimisation Mémoire
- **Isolate Parsing** : Analyse des fichiers lourds (10Mo+) dans des threads séparés.
- **Virtualisation UI** : Console G-Code avec fenêtre glissante (Sliding Window) pour une navigation fluide dans des millions de lignes.

## 📦 Installation & Lancement

1.  **Dépendances** : `flutter pub get`
2.  **Build** : `flutter build windows` (ou `web`)
3.  **Lancement** : `flutter run -d windows`

---
*Projet de Fin d'Études (PFE) — Configuration Trunnion Spécifique.*
