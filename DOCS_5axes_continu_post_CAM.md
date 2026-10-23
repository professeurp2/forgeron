# Usinage 5 axes **continu** — Configuration du post SolidWorks CAM

*PFE ENI — Forgeron CNC. Complément à `DOCS.md`. Voir aussi le 3+2 déjà validé.*

---

## 1. Le principe (à comprendre avant tout)

La machine tourne sous **FluidNC en cinématique `Cartesian`**. FluidNC **ne fait
pas de RTCP** (Remote Tool Center Point / TCPM) : il exécute les coordonnées
telles quelles, sans recalculer la position du pivot quand la table s'incline.

> **Conséquence unique et non négociable : le post SolidWorks CAM doit sortir des
> COORDONNÉES MACHINE déjà « cuites ».** C'est lui qui fait le RTCP, en tenant
> compte de la géométrie réelle du trunnion. Forgeron ne fait **que** nettoyer,
> valider, simuler et streamer — il **ne transforme aucune coordonnée**.

En 3+2 positionnel on contournait ça par un re-zérotage G54 à chaque
orientation. **En continu c'est impossible** (A et C bougent pendant la coupe) →
il n'y a pas d'échappatoire : la transfo doit être dans le post.

---

## 2. Prérequis (déjà en place, à ne pas casser)

- **Homing 4 axes** OK (A homé, A=0 = horizontale répétable). Homer à chaque
  démarrage (soft-limits).
- **Calibration** : X `steps_per_mm=264`, Y/Z=400, A et C=16,667 °/pas.
  Vérifs : `G91 G0 X50`=50 mm, `G91 G0 C360`=1 tour.
- **Signe A inversé côté CAO** (« Axe d'inclinaison » → *Inverser direction*) :
  +A CAO doit regarder la broche. **Ne pas toucher** le `direction_pin` FluidNC
  (ça casserait le homing A).
- **Compensation de rayon = « Ordinateur »** (comme en 3+2) → pas de G41/G42.

---

## 3. Géométrie du trunnion à saisir dans la **définition machine** SolidWorks CAM

Ces valeurs sont ce qui permet au post de calculer les coords machine. Elles
viennent des mesures CAO (repère CAO, **pas** un `mpos`) :

| Grandeur | Valeur | Remarque |
|---|---|---|
| Centre de rotation A (pivot), repère CAO | **X 80 · Y 100 · Z 300** | Le pivot est **sous la table** (d'où Z élevé). |
| Distance pivot → plateau (`d`) | **8 mm** | Le pivot est sous la surface du plateau. |
| Longueur d'outil | **18 mm** (exemple) | Par outil ; à mesurer/renseigner réellement. |
| Axe A (berceau) | rotation autour de **X** | Plage utile −90…+90 (physique −95…+90). |
| Axe C (plateau) | rotation autour de **Z** | Continu (peut s'enrouler >360°). |
| 0° de A | table **horizontale** (plan XY) | |

Dans SolidWorks CAM, renseigner l'axe rotatif (**Axe de rotation = C = Z**), l'axe
d'inclinaison (**A = X**, 0°=plan XY, limites A −90/+90), et les **offsets du
pivot** dans la définition de la machine / du post multi-axes. La chaîne
cinématique physique est : `pièce → machine = T(Pivot)·Rx(A)·T(0,0,8)·Rz(C)`.

---

## 4. Réglages de **sortie du post** (le cœur de l'Option A)

Objectif : que le fichier `.nc` contienne, sur chaque bloc de coupe, des
`G1 X.. Y.. Z.. A.. C.. F..` en **coordonnées machine**, sans aucun code de
transformation temps réel.

1. **Programmation en bout d'outil / TCP / TCPM : DÉSACTIVÉE.**
   C'est le réglage décisif. Selon le post, il s'appelle *Tool tip programming*,
   *TCP output*, *TCPM*, *Multi-axis output = Machine*. Il **ne doit PAS** produire
   `G43.4` / `G43.5`. La sortie doit être « rotary + linéaire en position machine ».
2. **Pas de transformation contrôleur.** Le fichier ne doit contenir **ni**
   `TRAORI/TRANSMIT/TRACYL` (Siemens) **ni** `M128/FUNCTION TCPM` (Heidenhain).
   *(Si tu pars d'un post Siemens/Heidenhain, c'est le mauvais dialecte pour cette
   machine — vise un post ISO/Fanuc sortant XYZAC machine.)*
3. **Compensation de rayon = Ordinateur** (opération → onglet CN) → pas de
   `G41/G42 D`. Le parcours sort déjà décalé.
4. **Linéarisation des mouvements 5 axes** : activer, avec une **tolérance de
   linéarisation** serrée (ex. 0,01–0,02 mm). Le post découpe les arcs 5 axes en
   petits segments `G1` — c'est ce qui rend la transfo « endpoint par endpoint »
   suffisamment précise sans RTCP à l'exécution.
5. **Mode d'avance** : privilégier le **temps-inverse `G93`** pour les blocs
   simultanés (l'avance devient exacte sur la trajectoire, indépendamment du
   mélange mm/degrés). FluidNC (base grbl 1.1) supporte G93/G94 — **à confirmer
   sur ta version**. Si tu restes en `G94` (mm/min), sache que GRBL calcule
   l'avance sur la norme combinée linéaire+rotative → l'avance réelle dérive quand
   la part rotative domine ; garde alors des avances prudentes.
6. **Unités : G21 (mm)**, absolu **G90**.

---

## 5. Ce que Forgeron gère **automatiquement** (rien à faire dans le post)

L'adaptateur (`GcodeAdapter`) nettoie au chargement — inutile de bidouiller le
post pour ça :

- `%`, numéros `O`/`N` → supprimés ;
- **`G28`/`G30`** (retour référence) → **retirés** (le zéro machine est aux
  capteurs → G28 y enverrait l'axe = crash switch) ;
- `G43/G44/H`, `G49` statiques → retirés (longueur prise via Z/WCS) ;
- `M6` (changement d'outil) → `M0` pause (reprise manuelle) ;
- cycles fixes `G81/G82/G83` → développés en `G0/G1/G4`.

---

## 6. Ce que Forgeron **REFUSE** (= ton post est mal réglé)

Au chargement, si l'adaptateur affiche **bloquant (rouge)**, le streaming est
**interdit**. Les causes et le correctif sont **côté post** :

| Détecté | Signification | Correctif |
|---|---|---|
| `G43.4` / `G43.5` | RTCP Fanuc actif | Désactiver TCP (§4.1) |
| `TRAORI/TRANSMIT/TRACYL` | Transfo Siemens (repère pièce) | Post en coords machine (§4.2) |
| `M128` / `FUNCTION TCPM` | TCPM Heidenhain | Post en coords machine (§4.2) |
| `G41` / `G42` | Compensation rayon **machine** | Compensation = Ordinateur (§4.3) |

> C'est la **boucle de contrôle** : tu postes, tu charges dans Forgeron, et le
> blocage te dit immédiatement si le post produit du repère-pièce au lieu de
> coords machine.

---

## 7. Procédure de validation (avant toute coupe)

1. **Poster** le parcours 5 axes continu (réglages §3–§4).
2. **Charger** le `.nc` dans Forgeron → l'adaptateur doit annoncer
   **`blocking = false`** (aucun avertissement rouge). Sinon → §6.
3. **Simuler** : vérifier dans le simulateur 3D que l'enlèvement matière A+C
   simultané correspond à la pièce voulue, et que rien ne plonge dans le plateau.
   *(⚠️ le simulateur n'est pas encore calibré au millimètre près — c'est un
   contrôle de bon sens, pas une garantie métrique — voir §8.)*
4. **Air-cut** : lancer **sans brut**, table en mouvement, vérifier les
   basculements A et l'absence de collision / hors-course (soft-limits).
5. **Première coupe** : brut tendre, profondeur faible, avances réduites.

---

## 8. Points ouverts / risques connus

- **Post tutoriel Fanuc m5axis** : il peut **coder en dur** `G43.4` (TCPM). Si le
  test §7.2 bloque toujours malgré TCP désactivé, il faudra soit un post qui sort
  vraiment des coords machine, soit (dernier recours) éditer le post — ce qu'on
  voulait éviter. À vérifier tôt sur un petit parcours.
- **Support `G93`** sur ta build FluidNC : à confirmer (§4.5).
- **Calibration métrique du simulateur** : ses offsets pivot sont décoratifs.
  La fidélité exacte dépend du montage (position pivot machine + zéro pièce G54),
  qui est une **calibration de montage**, pas une constante — non traité pour
  l'instant.
- **Précision globale** : en l'absence de RTCP à l'exécution, la précision repose
  entièrement sur (a) la justesse de la géométrie saisie au §3 et (b) la finesse
  de linéarisation au §4.4. Segments trop longs = erreur de corde sur les zones
  très inclinées.

---

## 9. Checklist express

- [ ] Géométrie pivot saisie dans la définition machine (§3)
- [ ] TCP/TCPM **désactivé** (pas de G43.4/TRAORI/M128) (§4.1–4.2)
- [ ] Compensation rayon = **Ordinateur** (pas de G41/G42) (§4.3)
- [ ] Linéarisation 5 axes activée, tolérance serrée (§4.4)
- [ ] Mode d'avance choisi (G93 si supporté) (§4.5)
- [ ] Chargé dans Forgeron → **blocking = false** (§7.2)
- [ ] Simulation A+C simultané cohérente (§7.3)
- [ ] Air-cut OK avant coupe (§7.4)
