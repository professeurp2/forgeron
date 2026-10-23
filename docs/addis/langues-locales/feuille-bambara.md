# Feuille de relecture — bambara

> **À remplir par un locuteur du bambara.** C'est la seule pièce que l'assistant de code ne peut pas produire. Sans elle, tout chiffre sur le bambara dans l'étude (`../05-etude-comparative-langues-locales.md`) reste **indicatif** : les énoncés sont des brouillons écrits par quelqu'un qui n'est pas locuteur.

## Pourquoi cette feuille

Le banc de mesure de Forgeron (`tool/eval/`) range les énoncés en trois statuts :

| Statut | Ce que ça veut dire | Compte dans le chiffre officiel ? |
|---|---|---|
| `relu` | un locuteur nommé les a lus et corrigés | oui |
| `brouillon` | écrit par l'assistant, jamais relu | oui, mais annoncé |
| `non_valide` | langue sans relecteur natif | **non**, rapporté à part |

Tous les énoncés bambara actuels sont `non_valide`. Votre relecture les fait passer à `relu` — et surtout elle apporte **ce que vous diriez vraiment à l'atelier**, ce qu'aucun brouillon ne remplace.

## Comment remplir

- Écrivez **comme vous le diriez (ou le taperiez) à un apprenti**, pas comme dans un livre.
- **Gardez les mots français** que vous utilisez d'habitude au milieu de la phrase (« broche », « homing », « programme »…). C'est ce qui se passe réellement dans un atelier, et c'est ce que le système doit comprendre.
- Écrivez **tel que vous le taperiez sur un téléphone**. Si votre clavier n'a pas « ɛ », « ɔ », « ɲ », écrivez avec « e », « o », « ny » : c'est ce que les gens font, et le système doit s'y retrouver. Si vous avez les deux habitudes, donnez les deux.
- **Plusieurs façons de le dire** : mettez-en jusqu'à trois, dans « autre façon ».
- Si vous **ne diriez jamais** la phrase du brouillon, écrivez **✗** dans « Votre version » et dites ce que vous diriez à la place.
- Si l'ordre n'existe pas du tout en bambara dans votre pratique (vous le dites toujours en français), écrivez **« en français »** : c'est une information utile.
- Ne corrigez pas pour faire « plus joli » : on veut le **naturel**.

## 1. Les ordres

| # | À dire (français) | Brouillon de l'assistant — *à corriger* | Votre version | Autre façon |
|---|---|---|---|---|
| 1 | Montre-moi l'état de la machine. | Mashini cogoya jira n ye. | | |
| 2 | Où est la machine en ce moment ? (sa position) | — | | |
| 3 | **Arrête tout, tout de suite !** (urgence) | Mashini jɔ sisan, joona! | | |
| 4 | **Au secours, arrête la machine !** | — | | |
| 5 | Mets le programme en pause. | Porogaramu jɔ dɔɔnin. | | |
| 6 | Reprends le programme. | — | | |
| 7 | Arrête le programme (pas l'urgence). | — | | |
| 8 | Ramène la machine à sa position de départ (homing). | Mashini segin a daminɛ yɔrɔ la. | | |
| 9 | Pose le zéro pièce ici. | Zero in da yan. | | |
| 10 | Allume la broche. | Broche daminɛ. | | |
| 11 | Éteins la broche. | Broche dabila. | | |
| 12 | Déplace l'axe X de 5 mm à la vitesse 300. | X taa mm 5 la, teliya 300. | | |
| 13 | Déplace l'axe X de **cinq** millimètres à la vitesse **trois cents** (nombres en lettres). | X taa milimɛtɛri duuru la, teliya kɛmɛ saba. | | |
| 14 | Monte l'axe Z de 3 mm. | — | | |
| 15 | Descends l'axe Z de 3 mm. | — | | |
| 16 | Recule l'axe X de 10 mm. | — | | |
| 17 | **Ne** démarre **pas** la broche. | — | | |
| 18 | Démarre la broche **après** le homing. | — | | |
| 19 | C'est quoi le homing ? (une question, pas un ordre) | Homing ye mun ye, a ɲɛfɔ n ye ni kuma nɔgɔman ye. | | |
| 20 | Est-ce qu'il va pleuvoir demain ? (rien à voir avec la machine) | Sanji bɛna na sini wa? | | |
| 21 | Mets la vitesse à 80 %. | — | | |
| 22 | Montre-moi la zone de coupe (la caméra). | — | | |
| 23 | La machine est en alarme, qu'est-ce que je fais ? | — | | |
| 24 | Merci, c'est tout pour aujourd'hui. | — | | |

Les lignes **3 et 4** (urgence) et **17 et 18** (négation, condition) sont les plus importantes : une erreur sur ces phrases, c'est une machine qui ne s'arrête pas ou qui démarre alors qu'on a dit non.

## 2. Les nombres

La machine ne comprend un nombre dit en bambara que si on lui a donné **exactement** les mots. Une erreur ici = un déplacement faux. Écrivez les nombres tels qu'on les dit.

| Nombre | Brouillon — *à corriger* | Votre version |
|---:|---|---|
| 1 | kelen | |
| 2 | fila | |
| 3 | saba | |
| 4 | naani | |
| 5 | duuru | |
| 6 | wooro | |
| 7 | wolonwula | |
| 8 | seegin | |
| 9 | kɔnɔntɔn | |
| 10 | tan | |
| 11 | tan ni kelen | |
| 20 | mugan | |
| 25 | mugan ni duuru | |
| 30 | bi saba | |
| 35 | bi saba ni duuru | |
| 50 | bi duuru | |
| 100 | kɛmɛ | |
| 103 | kɛmɛ ni saba | |
| 200 | kɛmɛ fila | |
| 250 | kɛmɛ fila ni bi duuru | |
| 300 | kɛmɛ saba | |
| 1000 | waa kelen | |

Dites aussi : **en atelier, vous dites les nombres en bambara, en français, ou vous les tapez en chiffres ?** (une phrase suffit)

## 3. Les mots de l'atelier

| Idée | Brouillon — *à corriger* | Votre mot (ou « français ») |
|---|---|---|
| machine | mashini | |
| broche | broche (français) | |
| programme | porogaramu | |
| zéro pièce / origine pièce | zero | |
| homing / origine machine | segin a daminɛ yɔrɔ | |
| axe | axe (français) | |
| vitesse | teliya | |
| millimètre | milimɛtɛri | |
| état (de la machine) | cogoya | |
| urgence | — | |
| arrêter | jɔ, dabila | |
| démarrer | daminɛ | |
| pause / attendre un peu | jɔ dɔɔnin | |
| reprendre | — | |
| ici / maintenant / vite | yan / sisan / joona | |
| non, ne… pas (défense) | kana, tɛ | |
| haut / bas | yɛlɛn / jigin | |
| gauche / droite | kinin / numan | |
| avant / arrière | ɲɛfɛ / kɔfɛ | |
| oui / non | — | |

## 4. Les réponses de la machine

Ce que l'application devrait **dire** ou **afficher** en bambara. Ce sont des phrases **fixes** : on les écrit une fois, relues, et la machine ne les invente jamais (une phrase de sécurité inventée par un modèle, dans une langue qu'il parle mal, est un danger).

| # | Message (français) | Votre version en bambara |
|---|---|---|
| 1 | Arrêt d'urgence déclenché. | |
| 2 | La machine est en alarme. | |
| 3 | Mouvement refusé : hors course. | |
| 4 | La broche est allumée. | |
| 5 | La broche est éteinte. | |
| 6 | Je n'ai pas compris. Répétez, s'il vous plaît. | |
| 7 | Confirmez : déplacer l'axe X de 5 mm ? | |
| 8 | Oui / Non | |
| 9 | La machine n'est pas connectée. | |
| 10 | Le programme est terminé. | |

## 5. Qui a relu

| | |
|---|---|
| Nom du relecteur | |
| Date | |
| Variété de bambara (Bamako, Ségou, Sikasso, maninka, jula…) | |
| Langue maternelle ou seconde ? | |
| Autres langues que vous parlez et qui pourraient avoir leur propre feuille | |

> Une **deuxième personne** (autre région si possible) qui relit les lignes 3, 4, 17 et 18 rend les chiffres nettement plus solides : les mots d'urgence et de négation varient d'un parler à l'autre.

## Après la relecture

L'assistant de code :

1. met vos phrases dans `tool/eval/scenarios_langues/` avec le statut `relu` (nom du relecteur et date inclus) ;
2. corrige `assets/lexicon/lexique.json` d'après vos mots ;
3. relance les mesures (modèle seul, lexique, combiné) et met à jour l'étude avec des chiffres qui valent quelque chose.

Une feuille par langue : le fichier est copiable pour le fula, le songhaï, le soninké, le wolof, l'amharique… Le coût d'une langue est le temps d'une personne qui la parle.

## 6. Mots vérifiés dans un dictionnaire (pré-remplissage sourcé)

Source : dictionnaire *An ka taa* (dictionary.ankataa.com), consulté le 2026-10-23. **Attesté ne veut pas dire bien choisi** : à vous de dire si on le dit vraiment ainsi.

| Idée | Mot trouvé | Sens du dictionnaire (résumé) | Dans le lexique |
|---|---|---|---|
| machine | mansin | machine ; moulin | oui |
| arrêter | jɔ, dabila | arrêter ; cesser | oui |
| démarrer / allumer | daminɛ, mɛnɛ | commencer ; allumer | oui |
| attendre | makɔnɔ, kɔnɔ | attendre | makɔnɔ |
| montrer / regarder / dire | jira, lajɛ, fɔ | montrer ; observer ; dire | oui |
| aller | taa | aller, partir | oui |
| revenir | segin | revenir (aussi « huit ») | dans « segin a daminɛ yɔrɔ » |
| maintenant / vite | sisan, joona | maintenant ; rapidement | oui |
| aide / danger | dɛmɛ, fàràti | aide ; danger | mots d'alarme |
| gauche / droite | numan, kini (kinibolo) | gauche ; droite | refus « direction » |
| haut / bas | yɛlɛn (monter), jigin | monter ; descendre | refus « direction » |
| vitesse | teliya | rapidité | oui |
| zéro | fu | zéro | non (le mot « zero » français suffit) |
| 30 à 90 | bisaba, binaani, biduuru, biwɔɔrɔ, biwolonwula, bisegin, bikɔnɔntɔn | (un seul mot) | oui |
| **absents du dictionnaire** | broche, programme, homing, milimɛtɛri, santimɛtɛri, mashini | — | mots français conservés |

Corrections par rapport au premier brouillon : *mashini* → *mansin* ; *kinin* → *kini* ; *numan* est **gauche**.
Les cases « Votre version » restent à remplir par un locuteur : aucune base de données publique ne contient ces ordres de machine.
