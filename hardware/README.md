# Forgeron — Carte d'interface CNC 5 axes — Rev 2.0

Dossier de conception de la carte électronique du contrôleur **Forgeron** (PFE ENI).
Document indépendant de l'outil de CAO : il contient tout ce qu'il faut pour saisir le
schéma dans Fritzing, EasyEDA ou KiCad.

| | |
|---|---|
| **Rôle** | Interface entre l'ESP32 (FluidNC) et la partie puissance de la machine |
| **Format** | 100 × 100 mm, 2 couches, cuivre 35 µm standard (branche broche renforcée au fil soudé) |
| **Contrôleur** | ESP32 DevKit V1 30 broches, **sur barrettes femelles** (enfichable) |
| **Drivers** | 5 × TB6600 **externes** — la carte ne fait que les piloter |
| **Puissance moteurs** | ATX HP Delta DPS-475CB-1A, 12 V / ~38 A — **ne transite pas par la carte** |
| **Broche** | Moteur 775 (12 V, ~17 A) — étage MOSFET **sur la carte** |
| **Firmware** | `scratch/config_5axes_production.yaml` — **aucune modification nécessaire** |

Fichiers associés : [`netlist.csv`](netlist.csv) (connexions), [`bom.csv`](bom.csv)
(nomenclature), [`GUIDE_FRITZING.md`](GUIDE_FRITZING.md) (saisie pas à pas sous Fritzing).

---

## 1. Ce que corrige la Rev 2.0

| # | Défaut de la Rev 1.0 | Correction |
|---|---|---|
| 1 | Jack barillet 19 V (~5 A max) alors que la machine tourne sur ATX 12 V / 38 A | Entrée **12 V sur bornier à vis**, branches logique et broche **séparées et fusionnées** |
| 2 | 5 TB6600 dessinés sur la carte (empreintes A4988 — physiquement impossible) | TB6600 **externes** ; 5 borniers 4 points `PUL+ / DIR+ / ENA+ / GND`, un câble par driver |
| 3 | 1 × SN74AH**C**125N = 4 canaux pour 11 signaux | **3 × SN74AHC*T*125N** = 12 canaux. Le passage **AHC → AHCT** est le point critique : en AHC alimenté sous 5 V le seuil haut vaut ~0,7 × Vcc ≈ 3,5 V, soit **au-dessus** des 3,3 V de l'ESP32. En AHCT le seuil est TTL (2,0 V) |
| 4 | Aucune sortie broche (GPIO21 absent du bornier) | Étage **MOSFET logic-level + diode de roue libre + fusible 20 A**, en remplacement du relais 10 A sous-dimensionné |
| 5 | E-STOP sur un simple GPIO — ne coupe rien si l'ESP32 plante | Coup-de-poing **2 contacts NF** : contact 1 → GPIO15, contact 2 → **PS_ON de l'ATX**, plus inhibition **matérielle** des drivers et de la broche |
| 6 | 11 entrées de fin de course pour 4 GPIO réellement disponibles | 4 entrées (X, Y, Z, A) sur borniers 3 points permettant la **mise en série MIN + MAX** |
| 7 | Entrées capteurs nues → faux `ALARM:1` documentés dans le YAML | Sur chaque entrée : **1 kΩ série + 100 nF + rappel 10 kΩ + écrêtage BAT54S** |
| 8 | Module WROOM nu, sans USB-UART ni bouton BOOT → impossible à flasher | **DevKit V1 sur barrettes femelles** : USB conservé, module remplaçable, aucun circuit à concevoir |
| 9 | LED RUN/ERR sans GPIO libre pour les piloter | LED pilotées **par le matériel** (état du bus ENA, état E-STOP) — zéro GPIO consommé |
| 10 | Ni anti-inversion, ni réservoir, ni découplage, ni écrêtage | SS34 + TVS 18 V + 470 µF / 220 µF / 1000 µF + 100 nF par boîtier |

---

## 2. Architecture

```
        ATX HP  12 V / 38 A
         |             |
      [F2 2A]       [F1 20A]                         COFFRET
         |             |                         +--------------+
    +----+----+        |                         |  TB6600 X    |
    | SS34    |        |                    +--->|  TB6600 Y    |
    | Buck 5V |        |                    |    |  TB6600 Z    |--> moteurs
    +----+----+        |                    |    |  TB6600 A    |
         | 5 V         |                    |    |  TB6600 C    |
         v             v                    |    +--------------+
   +----------------------------------+     |
   |  CARTE FORGERON Rev 2.0          |-----+  5 cables PUL+/DIR+/ENA+/GND
   |                                  |
   |  ESP32 DevKit V1 (enfichable)    |          +-------------+
   |     | 12 signaux 3.3 V           |          | Moteur 775  |
   |     v                            |--------->| 12 V ~17 A  |
   |  3 x SN74AHCT125N  --> 5 V       |  MOSFET  +-------------+
   |     |                            |  IRLB3034 + roue libre
   |  Entrees filtrees  <-------------|<--------- 4 fins de course NF
   |  Chaine E-STOP     <-------------|<--------- coup-de-poing 2 NF
   +----------------------------------+
                 | PS_ON
                 v
            coupure ATX
```

---

## 3. Brochage ESP32 DevKit V1 (30 broches)

> **À vérifier au multimètre avant de graver.** Il existe plusieurs variantes de
> « DevKit V1 30 broches ». Contrôle deux choses : l'**écartement des deux rangées**
> (25,4 mm ou 22,86 mm selon le fabricant — mesure au pied à coulisse) et la
> **position de 3V3 / GND / VIN**. Le reste du dossier est indépendant de ce détail.

Rangée gauche (J1), USB vers le bas :

| J1 | Broche DevKit | Usage carte |
|----|---------------|-------------|
| 1 | EN | — |
| 2 | GPIO36 (VP) | libre (entrée seule) |
| 3 | GPIO39 (VN) | libre (entrée seule) |
| 4 | GPIO34 | libre (entrée seule) |
| 5 | GPIO35 | libre (entrée seule) |
| 6 | GPIO32 | **Z STEP** |
| 7 | GPIO33 | **Y DIR** |
| 8 | GPIO25 | **Y STEP** |
| 9 | GPIO26 | **X STEP** |
| 10 | GPIO27 | **X DIR** |
| 11 | GPIO14 | **Fin de course Z** |
| 12 | GPIO12 | ne rien câbler (strap MTDI) |
| 13 | GPIO13 | **Fin de course Y** |
| 14 | GND | masse |
| 15 | VIN | **entrée 5 V** (via JP1) |

Rangée droite (J2) :

| J2 | Broche DevKit | Usage carte |
|----|---------------|-------------|
| 1 | GPIO23 | **Z DIR** |
| 2 | GPIO22 | **ENA partagé** |
| 3 | GPIO1 (TX0) | réservé USB |
| 4 | GPIO3 (RX0) | réservé USB |
| 5 | GPIO21 | **Commande broche** |
| 6 | GPIO19 | **A STEP** |
| 7 | GPIO18 | **A DIR** |
| 8 | GPIO5 | **Fin de course A** (strap, voir §6) |
| 9 | GPIO17 (TX2) | **C STEP** |
| 10 | GPIO16 (RX2) | **C DIR** |
| 11 | GPIO4 | **Fin de course X** |
| 12 | GPIO2 | LED intégrée du DevKit — laisser libre |
| 13 | GPIO15 | **E-STOP** (strap, voir §6) |
| 14 | GND | masse |
| 15 | 3V3 | rappels des entrées (courant faible) |

**Bilan : 17 broches utilisées, 4 entrées seules libres (34 / 35 / 36 / 39)** pour une
extension future (palpeur, butées MAX). Attention : ces quatre-là n'ont **pas** de rappel
interne — il faudra un 10 kΩ externe et une déclaration `gpio.34:high` **sans** `:pu`.

---

## 4. Schéma de principe, bloc par bloc

### Bloc A — Alimentation logique

```
J3.1 (+12 V ATX) --[F2 2A]--|>|--+-- C1 470uF/25V ---- GND
                            SS34 |
                                 +-- D3 SMBJ18A ------ GND
                                 |
                                 +-- U4 (MP1584EN)  IN+
                                     U4 OUT+ --> JP1.1

JP1 :  1 = sortie buck   2 = +5V_SYS (commun)   3 = +5V_EXT (bornier J16)

+5V_SYS --+-- C2 220uF/16V -- GND
          +-- U1.14, U2.14, U3.14   (+ 100 nF au ras de chaque boitier)
          +-- J1.15 (VIN du DevKit)
```

Régler la sortie du buck à **5,00 V au multimètre, module débranché de la carte**, avant
tout autre branchement. Un MP1584 livré réglé à 12 V détruit l'ESP32 en une seconde.

JP1 offre deux câblages, à choisir consciemment :

* **JP1 en 1-2 (buck)** — tout vient de l'ATX. Un appui sur le coup-de-poing coupe l'ATX,
  donc aussi le contrôleur : redémarrage et **reprise d'origine obligatoire**. C'est un
  arrêt de catégorie 0, parfaitement légitime.
* **JP1 en 2-3 (5 V auxiliaire)** — le DevKit et les tampons sont alimentés par un
  chargeur USB séparé. L'E-STOP ne coupe que la puissance ; l'ESP32 survit, garde la
  liaison WebSocket et remonte l'alarme à l'application. Plus confortable au quotidien.

### Bloc B — Adaptation de niveau 3,3 V → 5 V

Trois **SN74AHCT125N** (DIP-14, montés sur support), 12 canaux pour 12 signaux :

| Boîtier | Canal | Entrée 3,3 V | Sortie 5 V | /OE |
|---|---|---|---|---|
| U1 | 1 | GPIO26 X STEP | R1 100 Ω → J11.1 | GND |
| U1 | 2 | GPIO27 X DIR | R2 → J11.2 | GND |
| U1 | 3 | GPIO25 Y STEP | R3 → J12.1 | GND |
| U1 | 4 | GPIO33 Y DIR | R4 → J12.2 | GND |
| U2 | 1 | GPIO32 Z STEP | R5 → J13.1 | GND |
| U2 | 2 | GPIO23 Z DIR | R6 → J13.2 | GND |
| U2 | 3 | GPIO19 A STEP | R7 → J14.1 | GND |
| U2 | 4 | GPIO18 A DIR | R8 → J14.2 | GND |
| U3 | 1 | GPIO17 C STEP | R9 → J15.1 | GND |
| U3 | 2 | GPIO16 C DIR | R10 → J15.2 | GND |
| U3 | 3 | GPIO22 ENA | R11 → base Q3 | **ESTOP** |
| U3 | 4 | GPIO21 BROCHE | R13 → grille Q1 | **ESTOP** |

Brochage du '125, identique pour U1 / U2 / U3 :

```
1 = /OE1   2 = A1   3 = Y1   4 = /OE2   5 = A2   6 = Y2   7 = GND
8 = Y3     9 = A3  10 = /OE3  11 = Y4  12 = A4  13 = /OE4  14 = VCC
```

Le `/OE` est **actif bas** : relié à la masse, le tampon est passant. Sur U3, les canaux 3
et 4 sont pilotés par le nœud **ESTOP** (haut = déclenché) : ils passent alors en **haute
impédance**, ce qui coupe moteurs et broche **sans passer par le logiciel** (§5).

Les 100 Ω série amortissent les réflexions sur les câbles allant aux TB6600. Si un driver
se montre paresseux, on les remplace par des straps — d'où le choix de résistances
traversantes, faciles à changer.

### Bloc C — Bus ENA (5 optocoupleurs en parallèle)

Une sortie de '125 ne fournit que 8 mA ; les 5 entrées ENA des TB6600 en réclament ~40 mA.
D'où un suiveur d'émetteur :

```
U3.8 --[R11 1k]--+---- base Q3 (BC337)
                 |
                 +---[R12 10k]--- +5V_SYS

collecteur Q3 --- +5V_SYS
emetteur   Q3 ---+--- ENA_BUS ---[R30 1k]--- GND
                 |
                 +--> J11.3, J12.3, J13.3, J14.3, J15.3   (ENA+ des 5 drivers)
                 +--> grille Q4 --> LED2 rouge "DRIVERS OFF"
```

**R12 est le point clé** : quand le tampon passe en haute impédance (E-STOP), la base est
tirée à 5 V, donc ENA_BUS **haut**, donc **drivers désactivés**. C'est l'état sûr.

### Bloc D — Étage de puissance broche

```
fil ATX +12 V --[F1 20 A lame, EN LIGNE, HORS CARTE]--> J4.1
                                      |
                                 J4.1 +--> J4.2 --> fil + du moteur 775
                                      +--- C11 1000uF/25V --- PGND
                                      +--- C12 100nF -------- PGND
                                      +--- cathode D2 (SB2040)

fil - du moteur --> J4.3 --+--- anode D2
                           +--- DRAIN Q1 (IRLB3034PbF)

SOURCE Q1 --> PGND --> J4.4 --> GND de l'ATX

grille Q1 <--[R13 22 Ohm]-- U3.11        R14 100k : grille --> PGND
```

* **R14 (100 kΩ) est obligatoire** : elle maintient la broche à l'arrêt pendant le boot de
  l'ESP32, quand GPIO21 est encore flottant.
* **D2 est obligatoire** : sans elle, la coupure d'un moteur à courant continu produit une
  surtension inductive qui perce le MOSFET au premier `M5`.
* La liaison J4.1 ↔ J4.2 est un **plan de cuivre**, pas une piste (§8).
* `M3 S1000` allume, `M5` éteint. **Aucun changement dans le YAML** : la ligne
  `Relay: output_pin: gpio.21` pilote le MOSFET exactement comme elle pilotait le relais.
* Souder un **100 nF céramique directement aux bornes du moteur**, côté moteur : les
  charbons d'un 775 génèrent énormément de parasites.

Bilan thermique : Rds(on) ≈ 2 mΩ sous 4,5 V de grille, soit 17² × 0,002 ≈ **0,6 W** en
régime établi. Un TO-220 nu suffirait ; le petit dissipateur clipsable est là pour absorber
les pointes de démarrage du moteur (plusieurs dizaines d'ampères pendant quelques dizaines
de millisecondes).

### Bloc E — Entrées fins de course (× 4 : X, Y, Z, A)

Schéma identique pour les quatre, exemple sur X :

```
                    +3V3
                      |
                   [R19 10k]
                      |
J7.1 (SIG) --[R15 1k]-+----------------> GPIO4
                      |
J7.2 (BOUCLE)      [C6 100nF]   [D4 BAT54S --> 3V3 / GND]
J7.3 (GND)            |
                     GND
```

Câblage du bornier 3 points :

* **Un seul capteur** (configuration actuelle) : capteur NF entre J7.1 et J7.2, **cavalier
  JP2 en place** (il ferme J7.2 sur la masse).
* **Deux capteurs MIN + MAX** : `J7.1 — capteur MIN — J7.2 — capteur MAX — J7.3`, **cavalier
  JP2 retiré**. Les deux contacts NF sont alors **en série** : l'ouverture de l'un ou de
  l'autre, ou un fil coupé, déclenche l'alarme. C'est exactement ce que décrit
  `limit_all_pin` dans le YAML — un seul GPIO couvre les deux butées.

Le rappel externe de 10 kΩ est bien plus raide que le rappel interne de l'ESP32 (~45 kΩ) :
c'est lui qui règle les faux `ALARM:1` documentés dans le YAML. Avec le 1 kΩ série, la
tension vue par le GPIO capteur fermé vaut 3,3 × 1/11 ≈ **0,3 V**, très en dessous du seuil
bas — la marge est confortable. La constante de temps du filtre RC vaut 100 µs, sans effet
sur la précision de la prise d'origine (100 mm/min = 1,7 µm pendant 100 µs).

### Bloc F — Entrée E-STOP

Même filtrage que les capteurs (R23 1 kΩ, R24 10 kΩ vers 3V3, C10 100 nF, D8 BAT54S). Le
nœud ESTOP part vers **trois** destinations :

1. **GPIO15** → FluidNC déclenche l'arrêt logiciel (`estop_pin: gpio.15:high:pu`) ;
2. **U3 broches 10 et 13** (/OE) → coupure matérielle des drivers et de la broche ;
3. **grille Q2** → LED3 rouge « E-STOP ».

Au repos, contact NF fermé → nœud à la masse → **bas** → inactif. Bouton enfoncé **ou fil
coupé** → rappel 10 kΩ → **haut** → déclenché. *Fail-safe.*

### Bloc G — Coupure de puissance (contact NF n° 2)

```
ATX fil vert (PS_ON) --> J5.1 --[JP6]--> J5.2 (GND)
```

Le **deuxième contact NF** du coup-de-poing s'insère **en série dans cette boucle**, côté
coffret. Bouton enfoncé → PS_ON relâché → **l'ATX se coupe** → drivers et broche hors
tension. JP6 permet de ponter la boucle pour les essais au banc, coup-de-poing pas encore
câblé.

### Bloc H — Signalisation

| LED | Couleur | Pilotage | Signification |
|---|---|---|---|
| LED1 | verte | +5V_SYS via R26 | Carte alimentée |
| LED2 | rouge | Q4, grille sur ENA_BUS | Drivers désactivés |
| LED3 | rouge | Q2, grille sur ESTOP | Arrêt d'urgence déclenché |
| LED4 | orange | R29 sur la grille de Q1 | Broche en marche |

Aucune de ces quatre LED ne consomme de GPIO. La LED bleue intégrée au DevKit (GPIO2) reste
disponible comme témoin « ESP32 vivant ».

---

## 5. Chaîne d'arrêt d'urgence — les trois niveaux

Un seul bouton coup-de-poing **à deux contacts NF** déclenche trois actions indépendantes.
C'est cette redondance qui fait la différence avec la Rev 1.0.

| Niveau | Chemin | Délai | Fonctionne même si… |
|---|---|---|---|
| 1 — matériel, drivers et broche | contact 1 → nœud ESTOP → /OE de U3 → sorties en haute impédance → ENA haut, grille à 0 V | < 1 µs | l'ESP32 est planté ou absent |
| 2 — matériel, puissance | contact 2 → boucle PS_ON ouverte → arrêt de l'ATX | ~20 ms | la carte entière est en panne |
| 3 — logiciel | contact 1 → GPIO15 → FluidNC → RESET, alarme remontée à l'application | ~1 ms | — (nécessite un ESP32 vivant) |

### Point de vigilance : chute de l'axe Z

Les trois niveaux **coupent le couple de maintien des moteurs**. Si l'axe Z n'est pas
irréversible, la broche descend par gravité au moment de l'arrêt d'urgence.

Sur la machine actuelle, Z est entraîné par une **vis trapézoïdale**, qui est auto-bloquante
— le risque ne se matérialise pas. Mais le jour où Z passerait sur une vis à billes ou une
courroie, il faudrait ajouter un **frein électromagnétique** ou un **contrepoids**. À
mentionner dans l'analyse de risques du rapport, c'est exactement le genre de point attendu
en soutenance.

---

## 6. Broches de strap — les deux pièges

L'ESP32 lit certaines broches au démarrage pour choisir son mode de boot. Deux d'entre elles
sont utilisées ici, et c'est **volontaire** : elles sont déjà validées sur la machine.

* **GPIO15 (E-STOP)** — au repos, le contact NF le met à la masse. C'est sans conséquence :
  GPIO15 bas au boot ne fait que masquer les traces ROM sur l'UART. En revanche, **le bouton
  doit être câblé avant de téléverser** : sans lui, le rappel lit « haut » → E-STOP actif →
  `ALARM:11` au démarrage. Sérigraphier l'avertissement à côté de J6.
* **GPIO5 (fin de course A)** — doit être **haut** au boot. Le rappel de 10 kΩ s'en charge,
  **à condition que le berceau ne repose pas sur le capteur au moment de la mise sous
  tension**. À noter dans le mode opératoire.

GPIO12 est laissé **délibérément non connecté** : mis au niveau haut au démarrage, il fait
croire à l'ESP32 que sa flash est en 1,8 V et empêche le boot.

---

## 7. Implantation sur 100 × 100 mm

Le principe directeur : **les signaux faibles à gauche, la puissance à droite**, pour que
les câbles capteurs n'aient jamais à croiser les câbles moteurs dans le coffret.

```
 0                                                            100 mm
 +--------------------------------------------------------------+ 0
 |  o                J11  J12  J13  J14  J15               o     |
 |          [ borniers 4 pts -> TB6600 X Y Z A C ]               |
 |  J6   +--------+  +--------+  +--------+                      |
 | ESTOP |   U1   |  |   U2   |  |   U3   |         J3  [F2]     | 20
 |  J7   +--------+  +--------+  +--------+       12V log       |
 |  LIM_X                                                        |
 |  J8      +--------------------------+          +----+         |
 |  LIM_Y   |                          |          | U4 |  JP1    | 40
 |  J9      |   ESP32 DevKit V1        |          |buck|   J16   |
 |  LIM_Z   |   (barrettes J1 / J2)    |          +----+         |
 |  J10     |                          |                         | 60
 |  LIM_A   +--------------------------+          Q3  R11  R12   |
 |                                                               |
 |  JP2..JP5      TP1 TP2 TP3 TP4                    D2         | 80
 |  J5 PS_ON   LED1 LED2 LED3 LED4     C11    Q1+HS1      J4     |
 |  o          JP6                                    (4 pts)    |
 +--------------------------------------------------------------+ 100
   ZONE SIGNAL <-------------------|-------------> ZONE PUISSANCE
                             coupure du plan de masse
```

* Les trous M3 (Ø 3,2 mm) sont aux quatre coins, à 5 mm des bords.
* J4, Q1, D2 et C11 forment un **îlot compact** en bas à droite, aucune liaison ne dépassant
  15 mm : plus le chemin du courant broche est court, moins il rayonne — et moins il y a de
  fil de renfort à souder. F1 est hors carte, en ligne sur le fil.
* Le DevKit est au centre pour que ses 12 sorties atteignent les tampons par des pistes
  courtes, et son connecteur USB doit dépasser vers un bord accessible.
* Prévoir la place du dissipateur de Q1 : ne rien mettre de haut dans un rayon de 15 mm.

---

## 8. Règles de routage

| Élément | Règle |
|---|---|
| Empilage | 2 couches, **cuivre 35 µm standard** — suffisant grâce au renfort au fil soudé de la branche broche (le 70 µm resterait préférable si tu peux te le permettre) |
| Signaux logiques | largeur 0,3 mm |
| Rails 5 V et 12 V logique | largeur 1 mm |
| **Branche broche 17 A** | liaisons **< 15 mm**, tracées en 3 pistes parallèles de 1,2 mm, puis **renforcées par un fil de cuivre étamé 1,5 mm² soudé sur toute leur longueur** — c'est le fil qui conduit. Procédure détaillée dans [`GUIDE_FRITZING.md`](GUIDE_FRITZING.md) §5 |
| Isolation 12 V puissance | ≥ 1 mm entre cuivres |
| Masses | plan de masse **fendu** : GND signal à gauche, PGND à droite, réunis en **un seul point**, sous J4. Ne jamais refermer la boucle ailleurs |
| Découplage | 100 nF à moins de 5 mm des broches 7 et 14 de chaque '125 |
| Entrées capteurs | pistes les plus courtes possible, **jamais parallèles** aux sorties STEP ; R et C au ras du bornier |
| Module buck | **aucune piste** ni plan sous U4 (il rayonne à ~500 kHz) |
| Sérigraphie | nom du signal à côté de chaque borne, plus les deux avertissements : « E-STOP : câbler avant de flasher » et « Régler le buck à 5,00 V avant d'insérer l'ESP32 » |

---

## 9. Câblage du coffret

| Liaison | Section | Remarque |
|---|---|---|
| ATX → J3 (12 V logique) | 0,75 mm² | fil **jaune** = +12 V, **noir** = GND, sur Molex ou SATA |
| ATX → J4.1 et J4.4 (broche) | **2,5 mm²** | le plus court possible |
| ATX → alimentation des TB6600 | 1,5 mm² | **en étoile depuis l'alim**, jamais en guirlande via la carte |
| ATX fil **vert** (PS_ON) → J5 | 0,25 mm² | passe par le contact NF n° 2 du coup-de-poing |
| Carte → TB6600 (J11..J15) | 0,25 mm² | un câble 4 conducteurs par driver |
| Capteurs → J7..J10 | 0,25 mm² **blindé ou torsadé** | blindage à la masse **côté carte uniquement** |
| Coup-de-poing → J6 | 0,25 mm² | contact NF n° 1 |
| Broche 775 | 2,5 mm² | 100 nF aux bornes du moteur |

Séparation physique : les câbles capteurs et les câbles moteurs doivent emprunter **deux
chemins distincts** dans le coffret. C'est la cause racine des faux `ALARM:1` déjà
diagnostiqués dans le YAML — le filtrage de la carte est un renfort, pas un substitut.

Bilan de courant sur le rail 12 V : 5 moteurs × ~1,5 A + broche 17 A ≈ **24,5 A**, sous les
38 A de l'ATX. La marge est correcte, mais elle interdit d'ajouter une deuxième broche ou un
aspirateur sur la même alimentation.

---

## 10. Mise en service — ordre à respecter

Chaque étape se termine par un contrôle. **Ne pas passer à la suivante si le contrôle échoue.**

1. **Carte nue, hors tension.** Contrôle visuel des soudures. Ohmmètre entre +5V et GND, +12V
   et GND, +3V3 et GND : aucun court-circuit. Vérifier que GND et PGND ne se rejoignent qu'en
   **un seul point**.
2. **Réglage du buck**, module **débranché de la carte**, alimenté seul en 12 V : régler à
   **5,00 V**. Contrôle : 4,95 – 5,05 V.
3. **Alimentation logique seule** (F2 en place, F1 retiré, DevKit et '125 non insérés).
   Contrôle : 5,00 V sur TP1, LED1 allumée, rien ne chauffe.
4. **Insertion des '125 et du DevKit.** Contrôle : 3,3 V sur TP2, le DevKit démarre, l'ESP32
   apparaît sur le réseau.
5. **Câblage du coup-de-poing** (contacts 1 et 2), **avant tout téléversement**. Contrôle sur
   l'écran Diagnostics de l'application, champ `Pn:` : E-STOP **inactif** au repos, **actif**
   quand on appuie. Vérifier aussi que l'appui coupe bien l'ATX.
6. **Fins de course.** Actionner chaque capteur à la main et vérifier `Pn:` axe par axe.
   Contrôle supplémentaire : **débrancher** un capteur doit déclencher l'alarme — c'est la
   preuve que le montage NF fail-safe fonctionne.
7. **Signaux STEP / DIR, drivers non alimentés.** Un jog lent doit produire des impulsions
   visibles à l'oscilloscope ou à la LED témoin sur les borniers J11..J15.
8. **Mise sous tension des drivers.** Prise d'origine à vide, axe par axe, main sur le
   coup-de-poing. Vérifier le sens de chaque axe **avant** `$H` — un `positive_direction`
   inversé envoie l'axe dans la butée.
9. **Broche, moteur débranché.** `M3 S1000` doit mettre la grille de Q1 à ~5 V et allumer
   LED4 ; `M5` doit la ramener à 0 V.
10. **Broche, moteur branché**, fusible 20 A en place, en présence de quelqu'un. Contrôle :
    température de Q1 après une minute de marche — il doit rester tiède.

---

## 11. Conformité avec la configuration FluidNC

**Aucune modification de `scratch/config_5axes_production.yaml` n'est nécessaire.** Le
brochage de la Rev 2.0 reprend exactement celui qui tourne aujourd'hui sur la machine :

* les 10 broches STEP / DIR sont inchangées ;
* `shared_stepper_disable_pin: gpio.22` pilote maintenant le bus ENA via le suiveur, avec la
  même polarité (haut = désactivé) ;
* `limit_all_pin` en `:high:pu` reste valide — le rappel externe de 10 kΩ vient en parallèle
  du rappel interne, ce qui ne change que l'impédance, pas la logique ;
* `estop_pin: gpio.15:high:pu` est inchangé ;
* `Relay: output_pin: gpio.21` pilote le MOSFET au lieu du module relais, même polarité
  active haute.

Le seul ajout envisageable : si tu câbles un palpeur sur GPIO34, il faudra `probe: pin:
gpio.34:low` **sans** `:pu`, plus un rappel de 10 kΩ sur la carte (broche d'entrée seule).

---

## 12. Limites connues et évolutions

| Sujet | État Rev 2.0 | Évolution possible |
|---|---|---|
| Isolation galvanique des entrées | filtrage RC + écrêtage, masse commune | optocoupleurs PC817 avec alimentation séparée — la solution proprement industrielle |
| Vitesse de broche | tout ou rien | MLI sur GPIO21 + driver de grille TC4427 ; le '125 ne suffit plus au-delà de quelques kHz |
| Coupure de puissance | via PS_ON de l'ATX | contacteur de puissance sur le 12 V, piloté par la boucle E-STOP — indépendant de l'alimentation |
| Nombre d'entrées | 4 fins de course + E-STOP | expandeur I²C (PCF8574) sur GPIO21/22 si le besoin dépasse les 4 entrées seules restantes |
| Axe C | sans fin de course | rien ne l'impose (`soft_limits: false`), mais un index optique permettrait une origine C répétable |
| Refroidissement | dissipateur clipsable sur Q1 | ventilateur 12 V du coffret, à prendre sur l'ATX et non sur la carte |

---

*Forgeron — PFE ENI — Carte d'interface CNC 5 axes Trunnion, Rev 2.0.*
