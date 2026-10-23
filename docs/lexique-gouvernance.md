# Lexique de commandes — gouvernance

Le lexique (`assets/lexicon/lexique.json`) est la **porte d'entrée de l'assistant** : il lit chaque message avant le modèle de langage. C'est de la donnée relue par des personnes, pas du code ; ce document dit qui la change, comment, et ce que l'application en fait.

## 1. Ce que l'application fait d'un message

| Le lexique comprend… | Décision |
|---|---|
| un arrêt d'urgence, sans réserve | exécuté **tout de suite**, quelle que soit la confiance dans la langue (même si l'assistant est occupé) |
| la lecture de l'état | exécutée tout de suite |
| un ordre qui agit (mouvement, broche, origine, pause, homing) | **carte de confirmation** si un mot vient d'une langue `brouillon`, ou si l'appariement est approximatif, ou si l'opérateur a réglé la catégorie sur « confirmer » (défaut). Exécuté directement seulement si les trois sont verts |
| un appariement approximatif (faute, dictée), quoi que ce soit | toujours une suggestion à confirmer, arrêt d'urgence compris |
| une question ou une négation (refus) | le modèle n'a plus que les outils de lecture pour ce tour, et un appel à un autre outil est bloqué |
| autre chose | le modèle prend la suite, comme avant |

Sans modèle (agent désactivé, hors ligne, sans clé) : les ordres compris marchent ; le reste reçoit un message d'aide qui dit pourquoi.
Le lexique ne produit jamais de coordonnée : il recopie les nombres écrits ou dits, ou refuse.
Réglage : *Paramètres > Agent IA > Compréhension des commandes*. Coupé, l'assistant se comporte comme avant.

## 2. Invariants (vérifiés au chargement et par les tests)

`lib/core/utils/lexicon_schema.dart` refuse le fichier entier (l'assistant retombe alors sur le comportement d'avant) si :
- un ordre qui agit tolère des mots inconnus (tolérance 0 obligatoire) ;
- une intention « lecture seule » vise un outil soumis à confirmation ;
- un mot d'alarme isolé vise autre chose que l'arrêt d'urgence ;
- un outil n'existe pas, ou ses arguments obligatoires ne sont pas fournis ;
- une langue passe à `relu` sans le nom d'**une personne** (un modèle ou un script est refusé) et une date ;
- deux mots confondables veulent dire autre chose ; un nombre est déclaré deux fois.

## 3. Cycle de vie d'une langue

1. **`brouillon`** : écrit sans relecteur nommé (c'est le cas de fr, en, bm aujourd'hui). Sources citées dans `sources`. Confirmation toujours demandée.
2. **Relecture** par un locuteur à partir de la feuille de la langue (`docs/addis/langues-locales/feuille-<langue>.md`). Pour le bambara, une deuxième personne d'une autre région relit les lignes d'urgence et de négation.
3. **`relu`** : renseigner `status`, `reviewed_by`, `reviewed_on` dans le fichier. Seules les langues `relu` peuvent fournir des phrases de réponse (`replies`) et dispenser de confirmation.
4. Un mot partagé entre deux langues est validé dès que l'une des deux est relue ; un énoncé mêlant une langue relue et un brouillon reste non fiable.

## 4. Contrôle des changements

Toute modification : incrémenter `version` (MAJEUR.MINEUR.CORRECTIF), puis `dart run tool/lexicon/lock.dart`, et committer `lexique.json` **et** `lexique.lock.json`. `test/lexicon_lock_test.dart` échoue sinon ; l'outil refuse de verrouiller un contenu changé sans nouvelle version. Le journal de l'agent (`ai_journal.jsonl`) note pour chaque tour la décision du lexique et `version/empreinte` — sans le texte du message.

| Version | Changement |
|---|---|
| 0.1.0 | prototype d'étude (fr, en, bm brouillons) |
| 0.2.0 | branché sur l'assistant ; bambara revérifié mot à mot dans le dictionnaire An ka taa (machine = *mansin*, gauche = *numan*, dizaines en un mot, unités retirées) |

## 5. Questions ouvertes

- *help* est un mot d'alarme anglais : un utilisateur qui tape « help » déclenche un arrêt d'urgence.
- Le français et l'anglais sont encore `brouillon` : un francophone peut les relire en une séance et les passer à `relu`.
- `segin` signifie « huit » et « revenir » en bambara : seul *seegin* est accepté comme nombre.
- Les messages de la machine en bambara ne sont pas affichés tant que la langue n'est pas relue.
