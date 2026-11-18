# Revue graphique — relecture à l'œil de toute l'application

État au 13 novembre 2026. Complète la section 4 de `docs/simulation-jumeau.md`
(balayage automatique des débordements).

## 1. Comment on regarde

Le build web de débogage se bloque au chargement et l'application Windows
ne se laisse pas capturer depuis une session distante. La relecture passe
donc par un **banc de capture** : `test/screenshots_test.dart` monte
l'application entière et chaque écran poussé, dans les vraies polices, et
écrit un PNG par écran dans `build/screens/`.

```bash
FORGERON_SCREENS=1 flutter test test/screenshots_test.dart --update-goldens
```

Quarante et une captures : les huit pages PC en sombre et en clair, le mode
atelier, six pages téléphone, et huit écrans poussés (paramètres, agent,
connexion, limites, calibration, chat distant, assistant, backoffice mobile)
en PC et en téléphone. Le banc n'est jamais lancé par la suite de tests :
il ne tourne qu'à la main, avec la variable d'environnement.

Fidélité du banc : polices embarquées (JetBrains Mono, Rajdhani) et icônes
Material chargées depuis le SDK ; la police par défaut du thème est chargée
depuis le système (Segoe UI) ; la plateforme est Windows pour les grandes
tailles, Android pour les petites ; la langue est le français ; la machine
est en ligne, posée sur une cote parlante, et non sur des zéros. Deux
limites : le visualiseur 3D (WebView) et le flux caméra n'existent pas en
test, et les glyphes absents de Rajdhani (flèches) s'affichent en carrés
alors que l'application retombe sur la police de l'OS.

## 2. Ce que la relecture a trouvé, et ce qui a changé

| Défaut vu | Correction |
|---|---|
| La police du thème (`RobotoMono`) n'est pas embarquée : chaque poste affichait sa police système, et Rajdhani, embarquée, ne servait nulle part. | **Rajdhani** devient la police de l'interface (titres, libellés, corps), avec repli sur Segoe UI / Roboto pour les glyphes qu'elle n'a pas. JetBrains Mono reste la police des données. La console Agent IA (Fluent) suit la même police. |
| Les libellés de la barre latérale n'héritaient d'aucune police (`AnimatedDefaultTextStyle` remplace le style par défaut au lieu de le compléter). | Famille dite explicitement, corps 13, graisse 600/700. |
| Tableau de bord PC : « QUICK ACTIONS », « JOG CONTROL », « CYCLE START », « FEED HOLD », « JOG STOP », « W-value − Target » en anglais au milieu du français. | Clés françaises (« ACTIONS RAPIDES », « CONTROLE JOG », « DÉPART CYCLE », « PAUSE AVANCE », « STOP JOG », « Cotes pièce (W) ») avec leur traduction anglaise. |
| Tableau de bord PC : les quatre actions rapides touchaient l'en-tête « Contrôle jog ». | Respiration et filet entre les deux sections. |
| Tableau de bord PC : 100 px de vide entre la barre de simulation et une carte « Programme » affaissée en une ligne. | La carte remplit sa hauteur ; état vide avec icône et consigne (« Ouvre un fichier .nc ou .gcode, ou demande un parcours à l'agent IA »). |
| Backoffice PC : sept cartes d'indicateurs, six sur la première rangée et une orpheline. | Rangées équilibrées (4 + 3). |
| Backoffice mobile : titre « BACKOFFICE » deux fois (barre + en-tête interne). | Un seul en-tête ; Exporter et Vider passent dans la barre. |
| Terminal mobile : le bouton d'arrêt d'urgence de la barre de navigation recouvrait le champ de saisie. | Champ dégagé de 44 px. |
| Chat distant sur PC : formulaire étiré sur 1 600 px. | Largeur de lecture de 640 px, centrée. |

Ce qui a été regardé et laissé tel quel, parce que c'est bien : la barre
d'en-tête et le pied de page PC ; les cinq afficheurs de cotes et leurs
jauges ; l'écran Palpage (carte de mode, liste des WCS, jog rotatif) ;
Diagnostics (capteurs, YAML, cinématique) ; les états vides d'Outils et
d'Espace de travail ; le mode atelier téléphone ; les écrans Paramètres,
Agent IA, Limites, Calibration et Mise en route ; le thème clair.

## 3. Recommandations non faites ici

- **Icône de l'agent** : le bouton flottant mobile montre un emoji (🤖) qui
  dépend de la police système ; une icône vectorielle serait stable partout.
- **Connexion** : le halo orange en fond est spectaculaire mais lourd sur
  un poste ; à décider à l'atelier, sur l'écran réel.
- **Carte ESP32-CAM et simulateur 3D** : non capturables ici ; à relire sur
  machine avec le jumeau actif (`docs/simulation-jumeau.md`).
