# Documentation Technique — Moteurs Industriels

Cette documentation détaille les implémentations critiques de l'application Forgeron.

## 1. Moteur de Streaming (Character-Counting)

L'implémentation dans `GCodeStreamingService` suit strictement le protocole GRBL :
- **Buffer Tracking** : Un compteur `bytesInFlight` suit exactement le nombre d'octets présents dans la file d'attente de l'ESP32.
- **FIFO Ack** : Chaque `ok` reçu décrémente le compteur de la taille de la commande la plus ancienne via une `Queue<int>`.
- **Zéro Saccade** : Le buffer machine est maintenu saturé (127 octets) pour garantir que le planificateur de mouvement ne soit jamais vide.

## 2. Cinématique & RTCP (Remote Tool Center Point)

Le `KinematicsService` effectue les transformations matricielles nécessaires :
- **Forward Kinematics** : Transforme MPos [X,Y,Z,A,C] en repère pièce via des rotations inverses (Matrix4).
- **Inverse RTCP** : Calcule les déplacements machine pour maintenir la pointe de l'outil sur la trajectoire programmée, compensant les mouvements des axes rotatifs.
- **Singularity Management** : `calculateSingularityRisk` utilise une courbe exponentielle pour détecter l'approche de l'axe A vers 0°, évitant les vitesses de rotation infinies de l'axe C.

## 3. Architecture des Données Massives

Pour supporter des fichiers G-Code de 10 Mo sans geler l'interface :
- **Parsing** : Exécuté via `compute()` (Isolate), retournant un objet `AnalyzedGCode`.
- **Provider de Fenêtrage** : `LargeGCodeState` n'instancie pas de widgets pour tout le fichier. Il expose une `sublist` (±50 lignes) autour de l'exécution actuelle.
- **Virtualisation** : `ListView.builder` avec `itemExtent` fixe garantit que la complexité du rendu est O(1) par rapport à la taille du fichier.

## 4. Stratégie de Résilience Réseau

- **Exponential Backoff** : Les tentatives de reconnexion suivent une suite géométrique (1s, 2s, 4s...) plafonnée à 30s.
- **Heartbeat ( Watchdog)** : La commande `?` est envoyée cycliquement. Si aucun retour n'est détecté sous 2 secondes, le streaming est suspendu et une alerte critique est levée.

---
*Maintenance : Pour ajuster les limites de sécurité, modifier `TrajectoryValidator.minZ` et `TrajectoryValidator.maxA`.*
