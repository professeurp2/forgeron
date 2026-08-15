# Forgeron — Contrôleur CNC 5-Axes Industriel

<p align="center">
  <img src="assets/logo.png" width="200" alt="Forgeron Logo">
</p>

**Forgeron** est une application Flutter de grade industriel conçue pour le pilotage haute performance de machines CNC 5-axes (configuration Trunnion X,Y,Z,A,C). Optimisée pour le firmware **FluidNC v3.7+**, elle garantit un usinage sans saccades et une sécurité matérielle accrue.

## 🔌 Connexion à l'ESP32 FluidNC

### Protocole WebSocket
- **URL** : `ws://<IP_ESP32>:80/` (port 80, slash final obligatoire)
- **Format** : FluidNC envoie des **frames binaires WebSocket** (pas du texte) → décodage UTF-8 automatique dans l'application
- **Heartbeat** : commande `?` toutes les 2s, timeout déconnexion à 10s

### Découverte automatique
1. Aller dans **Connexion** → cliquer **SCANNER**
2. L'application scanne le sous-réseau local (priorité aux IPs .200, .100, .1...)
3. Cliquer **CONNECTER** sur le device trouvé
4. L'état passe à **EN LIGNE** avec l'IP affichée dans la barre du haut

### Configuration manuelle
- Entrer l'IP manuellement dans le champ **Adresse IP**
- Port par défaut : **80**
- URL WebSocket calculée automatiquement : `ws://IP:80/`

---

## 🚀 Fonctionnalités

### 1. Contrôle machine temps réel
- **DRO Live** : X, Y, Z, A, C mis à jour depuis les status reports FluidNC `<Idle|MPos:...>`
- **JOG 5 axes** : boutons X±/Y±/Z± et A±/C± avec pas configurable (0.001 → 100mm)
- **Commandes temps réel** : STOP jog (`0x85`), PAUSE (`!`), REPRISE (`~`), RESET (`Ctrl-X`)
- **Alarme** : déverrouillage automatique via `$X` avant les commandes critiques

### 2. Macros multi-lignes
Les macros G-Code multi-lignes sont envoyées ligne par ligne avec 200ms d'intervalle :
- PALPAGE CENTRE A, CHANGEMENT OUTIL, NETTOYAGE PLATEAU, WARMUP BROCHE

### 3. WCS (Systèmes de coordonnées)
- Cliquer sur G54/G55/G56 dans l'onglet Palpage & Origines envoie la commande à la machine

### 4. Streaming G-Code
- **Character-Counting** : gestion du buffer RX (127 octets) pour streaming continu
- **Virtualisation UI** : ListView avec `itemExtent` fixe pour des fichiers de millions de lignes

### 5. Résilience réseau
- **Reconnexion Exponential Backoff** : 1s, 2s, 4s... plafonné à 30s
- **Heartbeat Watchdog** : `?` toutes les 2s, timeout à 10s (assez long pour les jogs)

### 6. Adaptateur G-code CAM & 5 axes
- **Adaptation automatique** au chargement : traduit le G-code SolidWorks CAM / Fanuc-ISO pour FluidNC (retire O/N/G28/G43/H, développe les cycles fixes G81/G82/G83, `M6`→pause `M0`).
- **Sécurité RTCP** : **bloque** le G-code en repère pièce que FluidNC (Cartesian) ne peut pas exécuter — Fanuc `G43.4/.5`, Siemens `TRAORI/TRANSMIT`, Heidenhain `M128/FUNCTION TCPM` — ainsi que la compensation de rayon machine `G41/G42`.
- **3+2 positionnel** validé sur machine ; **5 axes continu** via post en coordonnées machine (générateur de parcours dôme : `tool/gen_5axes_dome.dart`).
- **Aperçu 3D fidèle** : interpolation des arcs G2/G3 + reconstruction cinématique de la pointe d'outil dans le repère pièce.

### 7. Sécurité
- **Récupération d'alarme fiable** : `$X` lève l'alarme sans relancer le programme dans la butée (purge du streaming à l'entrée en ALARM).
- **Notifications** : alerte au dépassement de fin de course, sans rafale pendant le homing.
- **must_home** (optionnel) + **soft_limits** : refus d'exécuter un parcours hors-course.

---

## 🔧 Hardware Cible — Prototype PFE

| Composant | Référence |
|-----------|-----------|
| Contrôleur | ESP32 DevKit V1 (30 broches) |
| Firmware | FluidNC (testé sur **v4.0.3**) |
| Drivers moteur | 5× TB6600 (STEP/DIR) |
| Axes | X, Y, Z (linéaires) + A, C (rotatifs Trunnion) |
| **Alimentation moteurs** | **Alim ATX de bureautique HP** (Delta DPS-475CB-1 A, **12 V / ~38 A**) |
| Broche | Moteur DC **775** (12 V, 200 W, 15 000 tr/min) |

### Câblage GPIO ESP32 → TB6600

| Axe | STEP GPIO | DIR GPIO |
|-----|-----------|----------|
| X   | GPIO 26   | GPIO 27  |
| Y   | GPIO 25   | GPIO 33  |
| Z   | GPIO 32   | GPIO 23  |
| A   | GPIO 19   | GPIO 18  |
| C   | GPIO 17   | GPIO 16  |
| ENA (partagé ×5) | **GPIO 22** | — |

### Alimentation

L'alimentation des moteurs est une **alim ATX de bureautique HP** (Delta **DPS-475CB-1 A**, rail **12 V / ~38 A**), qui a **remplacé le chargeur PC 65 W** (3,33 A, trop faible → décrochage des moteurs et de la broche).

- **Démarrage** : c'est une alim propriétaire → relier **PS_ON (fil vert) → GND (noir)** pour l'allumer ; brochage propriétaire, prendre le 12 V sur les connecteurs **Molex/SATA** (jaune = +12 V, noir = GND).
- **⚠️ Fusible** en série sur le 12 V (obligatoire — l'alim peut débiter 38 A sans limite).

### Fins de course, E-STOP & broche

| Fonction | GPIO | Câblage / config |
|----------|------|------------------|
| Fin de course X | GPIO 4  | switch **NC** → GND, pull-up (`gpio.4:high:pu`) — **fail-safe** |
| Fin de course Y | GPIO 13 | switch **NC** → GND (`gpio.13:high:pu`) |
| Fin de course Z | GPIO 14 | switch **NC** → GND (`gpio.14:high:pu`) |
| Fin de course / homing **A** | GPIO 5 | switch **NC** → GND (`gpio.5:high:pu`) ; capteur à **-88°** → A=0 = horizontale |
| **ARRÊT D'URGENCE** | GPIO 15 | bouton **NF** → GND, pull-up interne (`estop_pin: gpio.15:high:pu`) — fail-safe, sans résistance externe |
| Broche DC | GPIO 21 | module relais tout-ou-rien (`Relay: output_pin`). `M3`=ON, `M5`=OFF |

> **Fins de course en NC (fail-safe)** : un fil coupé/débranché déclenche une **alarme** au lieu de désactiver la sécurité en silence. `hard_limits` **réactivés** (les faux déclenchements venaient du bruit, réglé par un **câblage propre en coffret** — fils capteurs séparés des fils moteurs).
>
> **Broche** : le relais 10 A est **sous-dimensionné** pour le 775 (~17 A) → migration prévue vers un **MOSFET logic-level (IRLB8721) + diode de roue libre + fusible** (commande on/off + vitesse PWM). E-STOP à téléverser **seulement une fois le bouton câblé** (sinon ALARM:11).

**Config FluidNC** : `scratch/config_5axes_production.yaml`

---

## 📦 Installation & Lancement

```bash
flutter pub get
flutter run -d windows    # Application bureau Windows
```

> ⚠️ Le message "Nuget is not installed" lors du build Windows est bénin et n'empêche pas la compilation.

---

## 📁 Structure du projet

```
lib/
├── application/
│   ├── providers/          # Riverpod providers (machine, jog, gcode...)
│   └── services/           # Auto-découverte mDNS/HTTP
├── data/
│   ├── fluidnc/            # Connexion WebSocket + parser GRBL
│   └── mock/               # Repository simulation (mode hors connexion)
├── domain/
│   ├── models/             # MachineState, JogCommand, Macro...
│   └── repositories/       # Interface MachineRepository
└── presentation/
    ├── screens/            # Dashboard, Palpage, Terminal MDI...
    └── widgets/            # Visualiseur 3D Trunnion, GlassPanel...

scratch/
├── config_5axes.yaml            # Config FluidNC test (null_motor)
├── config_5axes_production.yaml # Config FluidNC production (TB6600 réel)
├── current_config.yaml          # Sauvegarde config originale ESP32
└── demo_dome_5axes_continu.nc   # Parcours 5 axes continu de démo (air-cut)

tool/
├── gen_5axes_dome.dart          # Générateur de parcours 5 axes continu (dôme)
└── scale_gcode.dart             # Mise à l'échelle des dimensions d'un G-code

DOCS_5axes_continu_post_CAM.md   # Guide de config du post SolidWorks CAM (coords machine)
```

---
*Projet de Fin d'Études (PFE) — ENI — Configuration Trunnion 5-Axes.*
