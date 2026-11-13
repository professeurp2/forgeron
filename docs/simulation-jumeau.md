# Simulation jumelle — le simulateur suit la carte ESP32

État au 13 novembre 2026. Complète `ARCHITECTURE.md` et `docs/backoffice.md`.

## 1. Deux simulations, deux questions

| | Lecture (existante) | **Jumeau** (nouveau) |
|---|---|---|
| Question | *Que fera ce programme ?* | *Que fait la machine, là, maintenant ?* |
| Source des positions | parcours G-code estimé, joué à ×1…×100 | rapports d'état de la carte (`<Run\|MPos:…>`) |
| Ligne courante | calculée sur une table temporelle | `activeLineIndex`, la ligne **acquittée** par FluidNC |
| Matière enlevée | le long du parcours prévu | au point **réel** de l'outil, entre deux rapports |
| Quand | avant l'usinage | pendant l'usinage, le jog, le homing |

Le jumeau n'estime rien. Chaque chose affichée vient d'un rapport de la carte
(règle « jamais de données inventées »). La seule interpolation est celle du
mouvement **entre deux rapports réels**, sur la durée mesurée entre eux.

## 2. Ce qui a été ajouté

**Cadence des rapports** ([`fluidnc_machine_repository.dart`](../lib/data/fluidnc/fluidnc_machine_repository.dart)) :
le `?` passait toutes les 2 s. Dès que la carte annonce `Run`, `Home`, `Hold`
ou `Check`, le dépôt le descend à **250 ms** ; il remonte à 2 s au repos. Un
`?` est une commande temps réel de GRBL, sans effet sur le planificateur.
Tout l'affichage en profite, jumeau ou pas : DRO, jauge de course, 3D.

**Interpolation côté page 3D** ([`three_viewer.html`](../web/three_viewer.html)) :
une position marquée `smooth` ne fait plus sauter l'outil ; il glisse de la
position précédente à la nouvelle sur la durée écoulée entre les deux
rapports (bornée 60–600 ms), et la matière est enlevée le long de ce
glissement. Le simulateur hors ligne, cadencé à 30 Hz, garde le chemin
immédiat.

**Le mode `live`** ([`simulation_provider.dart`](../lib/application/providers/simulation_provider.dart)) :
`followMachine()` arrête la lecture, remet le brut à neuf, demande la cadence
rapide et s'abonne à l'état machine ; `stopFollowing()` rend la cadence au
repos. À chaque rapport : position, ligne acquittée, avancement (ligne / total),
statut de la carte, et — quand la carte exécute — l'**écart XYZ** entre la
position réelle et le point du parcours attendu à cette ligne. Au-delà de
2 mm, un problème `ecart` est posé (un seul à la fois, retiré dès que la
machine revient sur le parcours). Lecture et jumeau s'excluent.

**Dans l'interface** : bouton **JUMEAU** dans la barre de simulation (tableau
de bord PC, panneau 3D mobile, console IA). Il pulse tant que le suivi est
actif, affiche `ÉCART x mm` en orange au-delà de la tolérance, et reste
grisé carte hors ligne. Le curseur temporel est désactivé en jumeau : la
position vient de la carte, on ne la tire pas.

**Pour l'agent IA** : `control_simulation` accepte `follow_machine` et
`stop_follow`, répond `mode: jumeau` avec statut machine, ligne réelle et
écart, et **refuse** carte hors ligne (« rien à suivre »). Le rapport de
`run_machining_simulation` / `analyzeCurrentProgram` dit le mode.

## 3. Mesures

`test/simulation_twin_test.dart` (6 tests) : rapports → position/ligne/
avancement ; écart de 7 mm mesuré, signalé « ligne 3 », retiré au retour sur
le parcours, non mesuré à l'arrêt ; exclusion lecture/jumeau et retour de la
cadence au repos ; outil IA (enclenche, arrête, refuse hors ligne) ; table de
cadence par statut.

Non mesuré ici : la fidélité visuelle sur la carte réelle (nécessite la
machine). À vérifier à l'atelier : un jog de 10 mm en X doit déplacer l'outil
du jumeau de 10 mm, sans à-coups, et le brut doit se creuser pendant un
programme réel.

## 4. Revue graphique et animations (même chantier)

`test/layout_sweep_test.dart` monte l'application entière à sept tailles
(téléphone, paysage, tablette, portable, fenêtre basse, grand écran), dans les
deux thèmes, sur les huit pages, le mode atelier et onze écrans poussés, et
relève chaque débordement avec le fichier et la ligne du widget. Première
passe : **258 défauts, 41 emplacements** ; après corrections : **0**. Les
corrections les plus visibles :

- le pupitre CNC rétrécit d'un bloc sous 1 500 × 860 au lieu de déborder
  rangée par rangée (jusqu'à 584 px sur tablette) ;
- l'écran Palpage s'empile sous 1 000 px au lieu de trois colonnes de 170 px ;
- les en-têtes de section du tableau de bord débordaient de 12 px sur tous
  les postes ;
- barre mobile, en-tête PC, diagnostics, console IA, connexion, réglages,
  assistant de mise en route : libellés qui cèdent la place au lieu de
  déborder.

Animations ([`animated_number.dart`](../lib/core/widgets/animated_number.dart)) :
les cotes (DRO PC, DRO géant atelier, LCD du pupitre) glissent d'une valeur
à la suivante ; les compteurs du backoffice changent en fondu ; chaque ligne de
journal entre en fondu ; les cartes de chaîne et les boutons de simulation
s'animent à la sélection ; le bouton JUMEAU pulse.
