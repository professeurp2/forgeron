# Guide de saisie sous Fritzing 1.0.5

Compagnon de [`README.md`](README.md) (la conception) et de [`netlist.csv`](netlist.csv)
(les connexions). Toutes les pièces citées ici ont été **vérifiées dans la bibliothèque
installée** sur ce poste (`C:\Program Files\Fritzing\fritzing-parts`) : elles existent, ce
ne sont pas des suppositions.

---

## 1. Les trois limites de Fritzing, et comment on les contourne

### a) Il n'existe pas de barrette 15 points

La bibliothèque s'arrête à 2–12, puis 14, 16, 18, 20. Pas de 15.

> **Solution** : utiliser **« Generic female header - 16 pins »** pour J1 et J2, et laisser
> le 16ᵉ trou libre. Sur le PCB c'est un trou non connecté de plus par rangée, sans aucune
> conséquence — il peut même servir de point de test.

### b) Pas de plan de cuivre par net, et largeur de piste plafonnée

Fritzing ne sait pas faire de plan de cuivre sur un net quelconque (seulement un remplissage
de masse global), et le menu de largeur de piste s'arrête à *thick* = 48 mil ≈ 1,2 mm. En
35 µm, 1,2 mm porte ~3 A. On en demande **17**.

> **Solution** : sur la branche broche uniquement, on trace **trois pistes parallèles en
> 48 mil**, on ouvre le masque dessus, et **on soude un fil de cuivre étamé de 1,5 mm² le
> long des pistes**. C'est le fil qui conduit, la piste ne fait que le guider. Détail en §5.
>
> Conséquence heureuse : le cuivre 70 µm n'est plus indispensable, un PCB standard 35 µm
> suffit. **C'est moins cher que la solution KiCad.**

### c) Pas de porte-fusible à lame automobile

> **Solution** : le fusible 20 A de la broche part **hors carte**, en ligne sur le fil
> +12 V (porte-fusible à lame étanche, quelques euros). C'est électriquement meilleur :
> 17 A de moins à faire transiter par le circuit imprimé. Seul F2 (5×20, 2 A, branche
> logique) reste sur la carte.

---

## 2. Pièces à poser — noms exacts dans le bac « Core »

| Rep | Rôle | Pièce Fritzing (bac Core) | Réglage dans l'Inspecteur |
|---|---|---|---|
| J1, J2 | Support ESP32 DevKit | **Generic female header** | *pins* = **16** (15 utilisés) |
| J3, J5, J6, J16 | Borniers 2 points | **Camdenboss CTB0158-2** | pas 5,08 mm |
| J7–J10 | Fins de course (3 points) | **Camdenboss CTB0158-3** | — |
| J4, J11–J15 | Broche + drivers (4 points) | **Camdenboss CTB0158-4** | — |
| U1, U2, U3 | SN74AHCT125N | **IC** (générique) | *package* = **DIP**, *pins* = **14**, *chip label* = `74AHCT125` |
| U4 | Module buck | **Generic male header**, *pins* = 4 | étiqueter `MP1584 IN+ IN- OUT+ OUT-` |
| Q1 | MOSFET broche | **Basic FET N-Channel** | *package* = TO-220, étiquette `IRLB3034` |
| Q2, Q4 | MOSFET signal | **Basic FET N-Channel** | *package* = TO-92, étiquette `2N7002` |
| Q3 | NPN bus ENA | **NPN-Transistor** (TO-92, ECB) | étiquette `BC337` |
| D1, D2 | Schottky | **DIODE-SCHOTTKY** | `SS34` / `SB2040` |
| D3 | TVS | **Diode** | étiquette `SMBJ18A` |
| D4–D8 | Écrêtage | **Diode** ×2 par entrée | ou `BAT54S` si tu l'ajoutes en pièce perso |
| F2 | Fusible logique | **Fuse with Handler** | 5×20, 2 A |
| R… | Résistances | **Resistor** | valeur dans l'Inspecteur |
| C1, C2, C11 | Chimiques | **Electrolytic Capacitor** | 470 µF / 220 µF / 1000 µF |
| C3–C10, C12 | Céramiques | **Ceramic Capacitor** | 100 nF |
| LED1–LED4 | Voyants | **LED** | 3 mm, couleur au choix |
| JP1 | Sélecteur 5 V | **Generic male header**, *pins* = 3 | + cavalier |
| JP2–JP6 | Cavaliers | **Generic male header**, *pins* = 2 | + cavalier |
| TP1–TP4 | Points de test | **Generic male header**, *pins* = 1 | — |

**Attention à D4–D8** : la BAT54S est un boîtier à 3 pattes (deux diodes en série). Si tu ne
crées pas la pièce, pose **deux diodes de signal 1N4148 par entrée** — une vers 3V3, une vers
GND, cathodes/anodes selon le schéma §4-E du dossier. Fonctionnellement équivalent ici.

---

## 3. Ordre de construction

Fritzing partage les connexions entre les trois vues : ce que tu câbles en **Platine
d'essai** apparaît en chevelu dans la vue **PCB**. Donc on saisit **une seule fois**.

Travaille bloc par bloc, dans cet ordre — chaque bloc est autonome et testable :

1. **Alimentation** (§4-A du dossier) : J3, F2, D1, C1, D3, U4, JP1, J16, C2, LED1+R26.
2. **Support ESP32** : J1 et J2. Renomme **immédiatement** chaque broche avec son GPIO
   (double-clic sur l'étiquette) — c'est ce qui t'évitera 90 % des erreurs de câblage.
3. **Tampons** : U1, U2, U3 + C3–C5. Câble d'abord les 14 broches d'alimentation et de /OE,
   ensuite seulement les signaux.
4. **Sorties drivers** : R1–R10 puis J11–J15.
5. **Bus ENA** : R11, R12, Q3, R30, puis les 5 fils vers J11.3–J15.3.
6. **Entrées capteurs** : les 4 blocs identiques (R15–R18, R19–R22, C6–C9, diodes, JP2–JP5,
   J7–J10). Fais-en **un seul complet**, vérifie-le, puis copie-colle les trois autres.
7. **E-STOP** : J6, R23, R24, C10, D8, puis les trois départs (GPIO15, U3.10, U3.13, Q2).
8. **Broche** : J4, Q1, D2, C11, C12, R13, R14, LED4+R29.
9. **PS_ON et signalisation** : J5, JP6, LED2, LED3, Q4, R31, R25, R32.

Après chaque bloc, ouvre la vue **Schéma** et vérifie qu'il n'y a **aucun fil en pointillé**
(un pointillé = connexion non établie). C'est le seul contrôle d'erreurs que Fritzing t'offre
vraiment, ne le saute pas.

---

## 4. Réglages de la vue PCB

| Paramètre | Valeur |
|---|---|
| Forme de la carte | Rectangle, **100 × 100 mm** (Inspecteur de la carte) |
| Couches | **2 faces** (Double sided) |
| Largeur des pistes signal | *standard* — 24 mil (0,6 mm) |
| Largeur 5 V et 12 V logique | *thick* — 48 mil (1,2 mm) |
| Largeur branche broche | *thick* ×3 pistes parallèles (voir §5) |
| Remplissage de masse | **Ground Fill** sur les deux faces, **après** le routage |

Implantation : reprends le plan du §7 du dossier. **Signaux à gauche, puissance à droite.**
En pratique, place d'abord tous les borniers sur les bords (ils imposent la géométrie), puis
le DevKit au centre, puis les tampons entre le DevKit et les borniers drivers.

L'autorouteur de Fritzing s'en sortira sur les signaux. **Ne le laisse pas toucher à la
branche broche** : route ces quatre liaisons à la main *avant* de le lancer, il ne défera pas
les pistes existantes.

---

## 5. La branche broche — la seule partie délicate

Quatre liaisons portent 17 A. Aucune ne doit dépasser **15 mm**, ce qui impose de coller
J4, Q1, D2 et C11 les uns contre les autres, en bas à droite de la carte.

```
J4.1 (+12V_SP)  ---- 3 pistes 48 mil ----  J4.2 (MOT+)      <- 10 mm max
J4.3 (MOT-)     ---- 3 pistes 48 mil ----  DRAIN Q1         <- 10 mm max
SOURCE Q1       ---- 3 pistes 48 mil ----  J4.4 (PGND)      <- 10 mm max
J4.3 (MOT-)     ---- piste 48 mil ------- anode D2 ; cathode D2 -> J4.1
```

Procédure, dans l'ordre :

1. Route les trois liaisons **à la main**, en *thick*, en posant **trois pistes côte à côte**
   espacées de 0,5 mm. Elles doivent être **rectilignes** — pas de coude.
2. Dans Fritzing : clic droit sur chaque piste → **« Set Trace to Ground Fill Seed »** non,
   ce n'est pas ça — ce qu'il faut, c'est simplement **ne pas** poser de vernis épargne
   dessus. Fritzing ne gère pas l'ouverture de masque par piste : indique-le au fabricant en
   note de commande, **ou** laisse le masque et gratte-le au cutter à la réception (c'est ce
   que font la plupart des ateliers d'école, et ça marche très bien).
3. **À la soudure** : pose un **fil de cuivre étamé de 1,5 mm²** (fil rigide de câblage
   dénudé) le long de chaque groupe de trois pistes, et soude-le **sur toute sa longueur**.
   C'est lui qui porte les 17 A ; les pistes ne servent qu'à le positionner et à assurer la
   continuité si une soudure lâche.
4. Contrôle : après montage, fais tourner la broche une minute et **touche le fil** — il doit
   rester froid. S'il chauffe, une soudure est incomplète.

Le reste de la carte ne dépasse jamais 500 mA. Aucune précaution particulière.

---

## 6. Avant de commander

1. **Vue Schéma** : plus aucun fil en pointillé.
2. **Vue PCB** : lance `Routage → Vérifier les règles de conception (DRC)`. Zéro erreur.
   Fritzing signale surtout les pistes trop proches — tolérance minimale 0,25 mm.
3. **Recoupe la netlist** : ouvre [`netlist.csv`](netlist.csv) et pointe les 64 nets un par
   un dans la vue Schéma. C'est fastidieux, c'est une heure de travail, et c'est **beaucoup**
   moins cher qu'un deuxième tirage de PCB.
4. Vérifie les trois points « à mesurer » du dossier : écartement des rangées du DevKit
   (§3), pas des borniers (5,08 mm), encombrement du dissipateur de Q1 (§7).
5. **Export** : `Fichier → Exporter → pour la production → Gerber étendu (RS-274X)`.
   Ouvre les Gerber dans un visualiseur en ligne (JLCPCB en propose un à la commande) et
   regarde la couche cuivre : c'est le dernier filet avant la gravure.

---

## 7. Ce que Fritzing ne te dira pas

Fritzing n'a ni simulation ni contrôle électrique digne de ce nom. Les erreurs qu'il laisse
passer et qui coûtent cher sur cette carte-là :

* **Buck réglé à 12 V** en sortie d'usine → ESP32 détruit. Se règle **avant** insertion (§10.2
  du dossier).
* **AHC au lieu de AHCT** → la carte semble marcher puis rate des impulsions. Vérifie le
  marquage du boîtier à la loupe.
* **D2 montée à l'envers** → court-circuit franc sur le 12 V au premier `M3`. Bague = cathode
  = côté **+12 V**.
* **R14 (100 kΩ) oubliée** → la broche démarre toute seule au boot de l'ESP32. C'est la
  résistance la plus importante de la carte.
* **GND et PGND réunis à deux endroits** → boucle de masse, et retour des 17 A par la masse
  signal. Vérifie à l'ohmmètre **avant** de souder le point de jonction unique.

---

*Forgeron — PFE ENI — Guide de saisie Fritzing, carte d'interface Rev 2.0.*
