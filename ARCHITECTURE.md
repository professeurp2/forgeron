# Forgeron — architecture

Forgeron pilote une fraiseuse CNC 5 axes depuis un téléphone Android, **sans
connexion Internet**.

Ce document dit où passe la frontière entre ce que décide un modèle de langage
et ce que calcule du code déterministe, pourquoi cette frontière est placée là,
et ce qui est démontré sur machine réelle plutôt que projeté. Chaque affirmation
renvoie à un fichier ou à une mesure : tout est vérifiable dans le dépôt.

---

## 1. Fonctionner sans Internet n'est pas une intention, c'est l'état du code

L'atelier visé n'a pas de réseau fiable. La machine elle-même n'en a pas du
tout : l'ESP32 crée son propre point d'accès WiFi, sans accès extérieur. Le
téléphone qui pilote la machine est donc, par construction, hors ligne.

Audit des dépendances externes du code applicatif :

```
grep -rnoE "https?://" --include="*.dart" lib
```

Une seule URL externe subsiste : `generativelanguage.googleapis.com`, dans
[`ai_agent_service.dart`](lib/application/services/ai_agent_service.dart) — le
fournisseur d'IA distant, **optionnel**. Les autres occurrences sont des liens
de documentation dans du code généré, jamais appelés à l'exécution.

Tout le reste est local ou embarqué :

| Composant | Où |
|---|---|
| Contrôleur machine | WebSocket sur l'AP de l'ESP32 |
| Caméra de supervision | ESP32-CAM, IP fixe sur ce même AP |
| Visualiseur 3D | `three.min.js` et `OrbitControls.js` **embarqués en assets**, injectés dans la WebView au chargement — aucun CDN |
| Polices, images, sons | embarqués (`pubspec.yaml`) |
| Programmes, origines, réglages | stockage local du téléphone |

Depuis [`26bdd95`](.), l'agent peut tourner sur un **modèle local** posé sur le
réseau de l'atelier (Ollama, llama.cpp, LM Studio). Renseigner l'URL du serveur
suffit à basculer : plus de clé API, plus de quota, plus de latence cellulaire.

Configuration de référence validée : Qwen2.5-7B quantisé Q4_K_M sur une RTX 3070
Laptop 8 Go, entièrement en VRAM.

> **Piège documenté.** Le prompt système et les 33 déclarations d'outils pèsent
> ~3 100 tokens par requête. Ollama plafonne le contexte à 4 096 par défaut,
> quelle que soit la capacité du modèle : le plancher occuperait 77 % de la
> fenêtre avant la première question. Il faut un modèle dérivé avec
> `PARAMETER num_ctx 16384`.

---

## 2. Ce que l'IA ne fait jamais

**L'agent ne produit aucune coordonnée.**

Ce n'est pas une limite du modèle local, c'est un choix d'architecture qui vaut
pour n'importe quel modèle. Une trajectoire d'usinage compte des milliers de
lignes ; un modèle qui les produit token par token se trompera quelque part, et
l'erreur restera invisible jusqu'à ce que la fraise entre dans la pièce ou dans
le montage. Le dôme de référence fait 2 970 lignes — il est sorti d'un
générateur de 250 lignes, pas d'un modèle.

Répartition des rôles :

| | Décide | Calcule |
|---|---|---|
| **Modèle de langage** | la stratégie, ses paramètres, l'ordre des opérations | rien |
| **Générateurs** (`tool/gen_*.dart`) | rien | toute la géométrie, les avances, l'enveloppe |
| **Validateurs** | rien | la conformité aux courses et aux limites machine |

L'agent choisit *« finition sphérique, R20, fraise boule Ø6, pas 0,4 mm »*. Le
générateur produit le parcours. Un validateur le refuse s'il sort des courses.
L'opérateur confirme. Ensuite seulement un axe bouge.

---

## 3. Les garde-fous, et ce qui les a motivés

Chacun vient d'une panne réelle, pas d'une précaution théorique.

**Avance mixte millimètres/degrés.** GRBL calcule une seule distance par bloc en
mettant les millimètres et les degrés dans la même racine carrée. Un bloc
`G2 <arc> C360 F120` passe 99,99 % de son temps en rotation : l'avance linéaire
réelle tombe à 2,6 mm/min au lieu de 120, soit un facteur 45. Les générateurs
n'émettent donc **jamais** un bloc mêlant un mot linéaire et un mot rotatif, et
calculent F en °/min pour les blocs de rotation.

**ForceGuard** ([`force_guard_service.dart`](lib/application/services/force_guard_service.dart))
bride l'avance selon le mode d'usinage, et verrouille A et C en mode 3 axes.

**Watchdog de streaming** ([`streaming_service.dart`](lib/application/services/streaming_service.dart)).
Si la carte cesse d'acquitter, le programme est suspendu — sans quoi l'écran
resterait sur « RUN » devant une machine morte. Il connaît les temporisations
qu'il vient d'envoyer et leur accorde leur durée : un `G4 P3` durait exactement
son timeout, et un démarrage sur deux échouait au hasard de l'arrivée d'un
rapport d'état.

**Adaptateur G-code** ([`gcode_adapter.dart`](lib/core/utils/gcode_adapter.dart)).
Traduit le G-code CAM vers le dialecte FluidNC, développe les cycles fixes,
convertit M6 en pause, **retire les retours G28/G30** — sur cette machine le
zéro machine est à la position des capteurs, un G28 y enverrait l'axe. Il
**bloque** ce qu'il ne peut pas assumer (RTCP G43.4, compensation de rayon
machine G41/G42) au lieu de le laisser passer en silence.

**253 tests** couvrent ces comportements.

---

## 4. Apprendre de ses propres pièces

La boucle qui remplace la CAO pour les pièces de révolution :

```
G-code d'une pièce  →  profil 2D  →  modifié en langage naturel  →  régénéré
```

[`extract_profile.dart`](tool/extract_profile.dart) remonte du parcours vers la
géométrie. Le G-code donne la pointe de l'outil ; le centre de la bille est à
`(X, Z+ρ)` ; la surface est l'offset intérieur de la courbe des centres, à
distance ρ le long de sa normale. Aucune hypothèse de forme : la méthode vaut
pour tout profil de révolution.

**Mesure sur `dome_r20.nc`** — 79 points comparés au cercle théorique :

| | |
|---|---|
| Écart moyen | **0,3 µm** |
| Écart maximal | **0,6 µm** |
| Crête laissée par la fraise entre deux passes | 6,6 µm |

La rétro-ingénierie est dix fois plus fine que ce que l'outil lui-même laisse.

**Pourquoi passer par le profil et non par le G-code.** Mettre un dôme R20 à
l'échelle 1,25 pour obtenir un R25 donne `k(R+ρ)·sinθ` là où il faut
`(kR+ρ)·sinθ` : le rayon de la fraise ne grandit pas avec la pièce. L'écart
atteint 0,75 mm et **varie avec l'angle** — 0,375 mm à 30°, 0,750 mm à
l'équateur — donc aucune correction globale ne le rattrape.

En parallèle, chaque programme exécuté laisse des paramètres validés par le réel
(profondeur de passe, engagement, avance, durée, verdict de l'opérateur). Le
modèle n'invente pas ses conditions de coupe : il puise dans ce qui a déjà
fonctionné sur cette machine.

---

## 5. Ce qui est démontré sur machine réelle

- **Un dôme hémisphérique R20 usiné en 3 h 35**, dans un brut de 65×65×50.
  Ébauche 3 axes en 50 couches, finition 5 axes en turn-milling sur 79 niveaux.
  **Cette pièce n'a jamais existé en CAO** : elle est née d'une phrase.
- **Le profil de cette pièce retrouvé depuis son seul G-code**, à 0,3 µm.
- **Trois pannes profondes diagnostiquées et corrigées** : l'avance mixte, le
  watchdog contre les temporisations, et des redémarrages de carte identifiés
  comme **thermiques** — 24 min avec broche, 35 min sans, aucun redémarrage en
  environnement refroidi, programme complet terminé.

---

## 6. Limites assumées

- **La CAO reste plus rapide pour une pièce mécanique quelconque** — un carter,
  un support avec perçages fonctionnels et tolérances. Le langage naturel gagne
  sur les pièces de révolution et le 2.5D. Viser le cas général serait le
  meilleur moyen de n'avoir rien qui fonctionne.
- **Pas de RTCP.** FluidNC est en cinématique cartésienne : il ne recalcule pas
  la position machine quand les axes rotatifs bougent. Le 5 axes continu au-delà
  de l'équateur exige que le post-processeur sorte des coordonnées machine.
- **L'arrêt d'urgence est logiciel.** Un ESP32 planté laisse la broche tourner.
  Le correctif est un contact NF en série sur la puissance — matériel, pas
  logiciel. Voir `hardware/`.
- **Le refroidissement de l'armoire conditionne les usinages longs.** Sans lui,
  `tool/split_program.dart` découpe un programme en tranches autonomes.
