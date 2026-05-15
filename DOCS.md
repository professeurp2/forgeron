# Documentation Technique — Forgeron CNC 5-Axes

*Dernière mise à jour : Mai 2026 — PFE ENI*

---

## 1. Connexion WebSocket FluidNC

### Problème résolu : frames binaires
FluidNC v3.7+ envoie les données via WebSocket en **frames binaires** (pas en texte). 
Le décodage est effectué dans `FluidNCConnection._handleIncomingMessage()` :

```dart
void _handleIncomingMessage(dynamic message) {
  String msg;
  if (message is List<int>) {
    msg = String.fromCharCodes(message).trim(); // ← Fix critique
  } else {
    msg = message.toString().trim();
  }
  ...
}
```

### URL WebSocket correcte
```
ws://<IP>:80/     ← Port 80, slash final OBLIGATOIRE
```
Sans le slash, le serveur HTTP de FluidNC refuse l'upgrade WebSocket.

### Commandes temps-réel vs G-Code
Les commandes **temps-réel** (jog, stop, pause) doivent **bypasser le buffer** :

| Type | Commande | Méthode à utiliser |
|------|----------|--------------------|
| Jog `$J=` | `$J=G91 G21 X10 F1000\n` | `sendRaw()` directement |
| Stop Jog | `0x85` | `sendRaw('\x85')` |
| Pause | `!` | `sendRaw('!')` |
| Reprise | `~` | `sendRaw('~')` |
| Soft Reset | `0x18` | `sendRaw('\x18')` |
| Unlock Alarm | `$X` | `sendGCode('\$X')` |
| G-Code normal | `G0 X10\n` | `sendGCode()` avec buffer tracking |

---

## 2. Architecture de la Connexion

### Fichiers clés

| Fichier | Rôle |
|---------|------|
| `lib/data/fluidnc/fluidnc_connection.dart` | WebSocket raw, heartbeat, buffer GRBL |
| `lib/data/fluidnc/fluidnc_machine_repository.dart` | Implémentation MachineRepository |
| `lib/data/fluidnc/grbl_parser.dart` | Parser status reports FluidNC |
| `lib/application/providers/machine_provider.dart` | Provider Riverpod, mode Sim/Prod |
| `lib/application/providers/jog_provider.dart` | Contrôle jog 5 axes |
| `lib/application/services/auto_discovery_service.dart` | Scan réseau HTTP |

### Cycle de vie de la connexion
```
App start → isSimulationMode=true → MockMachineRepository
    ↓
User clique "Connecter" (IP, port 80) → FluidNCMachineRepository
    ↓
FluidNCConnection.connect() → ws://IP:80/
    ↓
Handshake OK → _startHeartbeat() (? toutes les 2s)
    ↓
Stream de status reports → GrblParser.parse() → MachineState
    ↓
Riverpod machineStateProvider → rebuild UI
```

### Gestion de l'alarme
Si la machine est en `Alarm` :
1. Envoyer `$X\n` pour déverrouiller
2. Attendre 300-500ms
3. Envoyer la commande souhaitée

---

## 3. Protocole GRBL/FluidNC — Messages supportés

| Message reçu | Parser | Action |
|-------------|--------|--------|
| `<Idle\|MPos:X,Y,Z\|FS:f,s>` | `parseStatusReport()` | Mise à jour état machine |
| `<Jog\|MPos:...>` | `parseStatusReport()` | Status pendant jog |
| `ALARM:N` | `parseAlarm()` | Passage en mode alarme |
| `[GC:G0 G54 T1 ...]` | `parseModalState()` | WCS, outil, avance active |
| `[PRB:X,Y,Z:1]` | `parseProbeReport()` | Résultat palpage |
| `ok` | Buffer tracking | Libère 1 slot dans le buffer |
| `error:N` | Buffer tracking | Libère 1 slot, log l'erreur |
| `PING` | Ignoré | Keep-alive FluidNC |

---

## 4. Streaming G-Code (Character-Counting)

Le buffer RX de FluidNC est limité à **128 octets**. L'algorithme :

```
Buffer max = 128 octets
Avant chaque envoi :
  if (currentBufferSize + len <= 128) → envoyer + mémoriser len
  else → mettre en queue (attendre un 'ok')

À chaque 'ok' reçu :
  currentBufferSize -= sentLengths.removeFirst()
  processQueue() → envoyer la commande en attente
```

---

## 5. Configuration FluidNC pour l'Hardware

### Fichiers de configuration

| Fichier | Usage |
|---------|-------|
| `scratch/current_config.yaml` | Sauvegarde config originale ESP32 |
| `scratch/config_5axes.yaml` | Test Forgeron (null_motor — pas de vrais signaux) |
| `scratch/config_5axes_production.yaml` | **Production** (TB6600 sur GPIO réels) |

### GPIO ESP32 DevKit V1 (30 pins) → 5× TB6600

```
AXE X : STEP=GPIO26, DIR=GPIO27
AXE Y : STEP=GPIO25, DIR=GPIO33
AXE Z : STEP=GPIO32, DIR=GPIO23
AXE A : STEP=GPIO19, DIR=GPIO18  (tilt broche Trunnion)
AXE C : STEP=GPIO17, DIR=GPIO16  (rotation plateau)
ENA   : GPIO22 (partagé tous les drivers)
```

### Réglages TB6600 recommandés
- Microstepping : **1/16** (DIP4=ON, DIP5=ON, DIP6=OFF)
- Courant : selon le moteur (voir tableau DIP SW1-SW3)
- steps_per_mm linéaire : `200 × 16 / pas_vis_mm` (ex: T8=8mm → 400 steps/mm)
- steps_per_degree rotatif : `200 × 16 × ratio_reduction / 360`

### Calibration
Après câblage, lancer depuis le terminal MDI :
```gcode
G91 G21 X100 F500    ← Jog de 100mm
; Mesurer la distance réelle et calculer :
; steps_per_mm = (400 × 100) / distance_mesurée
```

---

## 6. Stratégie de Résilience Réseau

- **Exponential Backoff** : reconnexions à 1s, 2s, 4s... plafonné à 30s
- **Heartbeat Watchdog** : `?` toutes les 2s, timeout déconnexion à **10s**
  - 10s (pas 5s) pour ne pas déconnecter pendant les longs jogs
- **Détection de perte** : si `_lastResponseTime` > 10s sans message → `_handleDisconnect()`

---

## 7. Boutons et Commandes — Référence rapide

| Bouton | Commande envoyée |
|--------|-----------------|
| REPRENDRE | `~` (real-time) |
| PAUSE | `!` (real-time) |
| ARRÊT | `\x18` (soft reset) |
| RESET | `\x18` + `$X` après 500ms |
| ORIGINE TOUS | `$X` + `$H` après 300ms |
| ALLER ZÉRO | `G90 G0 X0 Y0 Z0` |
| JOG X+ | `$J=G91 G21 X10.000 F1000\n` (sendRaw) |
| JOG STOP | `\x85` (real-time, sendRaw) |
| HOME AXE Z | `$HZ` |
| G54 / G55 / G56 | `G54` / `G55` / `G56` |
| ARRÊT D'URGENCE | `\x18` (Ctrl-X) |

---

*Maintenance : Pour ajuster les vitesses et accélérations, modifier `scratch/config_5axes_production.yaml` et uploader sur l'ESP32 via `http://IP/` → Files → Upload.*
