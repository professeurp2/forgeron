# Backoffice — supervision de l'ensemble du logiciel

État au 12 novembre 2026. Écran **BACKOFFICE** (barre latérale PC ; sur
mobile, bouton « supervision » dans la barre de la page Agent IA).

Ce document dit ce que le backoffice observe, comment il relie les
événements entre eux, et ce qu'il ne fait volontairement pas.

---

## 1. Pourquoi : trois journaux qui ne se parlaient pas

Avant ce chantier, l'application savait déjà beaucoup — mais en trois
endroits qui s'ignoraient :

| Journal | Ce qu'il garde | Ce qui manquait |
|---|---|---|
| `AiTurnJournal` (`ai_journal.jsonl`) | un tour de modèle : fournisseur, modèle, issue, latence, tokens, **noms** d'outils, garde-fous | ni les arguments, ni le résultat, ni ce qui est parti vers la carte |
| `LoggerService` (tampon 5 000 lignes) | le trafic brut TX/RX de la carte | aucun lien avec l'outil de l'IA qui a envoyé la commande |
| `ActivityLog` (60 entrées) | des actions lisibles (« Jog manuel », « Broche ON ») | muet pendant tout l'usinage, pas de valeur d'override, rien sur le relais |

Et rien du tout sur le relais PC ↔ téléphone : on savait combien d'appareils
étaient reliés, pas qui avait confirmé quoi.

Les questions auxquelles on ne pouvait pas répondre après coup :

- *« Le modèle a demandé `jog_axis` : la commande est-elle vraiment partie, et
  la carte a-t-elle répondu `ok` ? »*
- *« Ce mouvement a été confirmé depuis le téléphone ou depuis le PC ? »*
- *« Combien de fois le garde-fou des commandes `$` a-t-il bloqué le modèle
  local ? »*
- *« Quand la carte est passée en alarme, qu'a répondu l'IA du veilleur ? »*

## 2. Ce qui a été construit

```
 agent IA ─┐
 relais ───┤                 ┌─ écran Backoffice (journal, chaînes, santé)
 carte ────┼─► BackofficeBus ┤
 veilleur ─┤   (tampon 4000) ├─ backoffice.jsonl (rotation 2 Mo × 3)
 gardes ───┘                 └─ export JSON + presse-papiers
```

### Le bus — `lib/application/services/backoffice_bus.dart`

Un tampon roulant d'événements, une écriture JSON-lignes en arrière-plan,
et la **fenêtre d'attribution** : le contrôleur de l'agent déclare « c'est
l'appel `jog_axis_3` qui agit » autour de chaque exécution d'outil, et la
sonde de la carte impute à cet appel toute commande qui part pendant cette
fenêtre. La fenêtre se referme à la fin de la boucle d'événements, pas tout
de suite — le flux de trafic est asynchrone, et sans ce délai la dernière
commande d'un outil n'aurait pas d'auteur (`test/backoffice_bus_test.dart`).

Règles : jamais bloquant, jamais fatal (un bus absent ou un disque plein
n'empêche ni l'agent ni le relais de fonctionner), borné en mémoire.

### L'événement — `lib/domain/models/backoffice_event.dart`

| Champ | Rôle |
|---|---|
| `source` | `ia`, `relais`, `firmware`, `garde`, `veilleur`, `systeme` |
| `kind` | type stable (`ia.tour`, `firmware.tx`, `garde.gcode`…) |
| `severity` | `info`, `notice`, `warning`, `critical` — les deux derniers sont des « problèmes » |
| `turnId` | le message d'opérateur dont tout découle |
| `callId` | l'appel d'outil — **le fil qui relie le modèle à la carte** |
| `origin` | qui a agi : `local`, `relais` (téléphone), `lexique`, `modele`, `operateur`, `veilleur` |

### Les sondes

**Agent IA** (`ai_agent_provider.dart`, `ai_lexicon_front.dart`) — émet
directement : `ia.message` (avec l'origine PC/téléphone et un aperçu de 160
caractères, jamais le message entier), `ia.tour` (la réaction du modèle :
issue, latence, tokens, outils demandés, garde-fous intervenus, version du
prompt), `ia.outil.demande` / `attente` / `confirme` / `refuse` / `execute`,
`ia.urgence`, `ia.erreur`, `ia.reprise_armee`, `ia.interrompu`, `ia.lexique`,
et les refus déterministes en `garde.*` (outil inconnu, tour en lecture seule,
résultat d'outil qui est un refus de garde-fou).

**Relais PC ↔ téléphone** (`chat_relay.dart`) — côté hôte : démarrage,
liaison (adresse), refus de code, message reçu (type, longueur, image),
déconnexion. Côté téléphone : connexion, refus, coupure, envoi, et l'arrêt
d'urgence **exécuté localement** sans passer par le lien. Les confirmations
venues du téléphone traversent le contrôleur avec `origin: relais`, donc
l'exécution et les commandes vers la carte le portent aussi.

**Carte FluidNC** (`backoffice_firmware_probe.dart`, branchée par
`backofficeProbesProvider`) — lit le `trafficStream` que le diagnostic
utilise déjà :

- `firmware.tx` : une commande hors usinage, attribuée à l'acteur courant
  (outil de l'IA) ou à l'opérateur ; le heartbeat `?` et les requêtes d'état
  internes sont ignorés ;
- `firmware.reponse` : `ok` ou `error:N`, relié à la commande en attente la
  plus ancienne (FluidNC acquitte dans l'ordre), avec la latence ; un `ok`
  n'est journalisé que s'il ferme une commande de l'IA ;
- `firmware.alarme`, `firmware.message`, `firmware.redemarrage` ;
- `firmware.tx_echec` (liaison coupée), `firmware.blocage` (watchdog),
  `firmware.urgence_non_transmise` — tous critiques ;
- pendant un usinage : **un** événement au départ (avec l'outil de l'IA qui l'a
  lancé, s'il y en a un), **un** à la fin avec les comptes (lignes, ok,
  erreurs), et seules les erreurs entre les deux ;
- `machine.statut` à chaque transition, `machine.urgence` sur front d'E-STOP.

**Veilleur** (`critical_event_provider.dart`) — `veilleur.alerte` (alarme,
E-STOP, surchauffe, fin de course en mouvement) puis `veilleur.ia` : la
réaction du modèle à l'événement de la carte, avec sa latence, ou « aucune
réponse » et pourquoi.

### L'écran — `lib/presentation/screens/backoffice_screen.dart`

- **Bandeau** : tours IA (ok/erreurs/vides, p50), appels d'outils (échecs,
  garde-fous), IA → carte (commandes, ok/erreurs, p50 d'acquittement),
  confirmations (ici / téléphone / refus), relais (état, appareils), machine
  (statut, alarmes, blocages, urgences), problèmes.
- **Journal** : tous les événements, du plus récent au plus ancien, filtres
  par source, « problèmes seulement », recherche texte ; une ligne dépliée
  montre le détail et un lien « voir toute la chaîne ».
- **Chaînes IA → carte** : par appel d'outil — demandé par qui, confirmé par
  qui, exécuté en combien de temps, commandes parties, réponses de la carte.
- **Santé** : fournisseur et modèle, lexique, portes de confirmation, usage du
  jour ; bilan du journal des tours (toutes sessions : réussite, p50/p95,
  garde-fous et outils les plus fréquents) ; relais ; liaison carte.
- **Exporter** écrit un JSON (événements + statistiques) dans le dossier de
  support de l'application et le copie dans le presse-papiers. **Vider**
  demande si le disque doit l'être aussi.

En dessous de 1 100 px (téléphone), les trois panneaux deviennent trois
onglets.

### Les modèles locaux, gemma compris

Le serveur Ollama est interrogé trois fois (`/api/tags`, `/api/show`,
`/api/ps`) pour dire, modèle par modèle : ce qu'il sait faire (outils,
vision, contexte), s'il est **chargé en mémoire** (et quelle part sur le
GPU), et le rôle que l'application lui donne — **pilote** (il commande la
machine), **images** (il lit les photos), ou aucun. Sans adresse réglée, c'est
le PC lui-même (`localhost:11434`) qui est interrogé : un gemma installé mais
jamais branché apparaît quand même.

Un modèle qui voit et ne sert à rien porte un bouton **BRANCHER** : il devient
le modèle d'images (`localVisionModel`), et, si aucun serveur n'était réglé,
l'adresse interrogée est posée en même temps (sinon le service d'images ne
serait jamais créé). C'est le seul geste que le backoffice s'autorise — un
réglage de l'application, tracé `systeme.reglage`, jamais une action machine.

Côté agent, trois événements disent ce que fait le modèle d'images :

| Événement | Quand |
|---|---|
| `ia.vision.tour` | une photo est confiée au modèle d'images (sans outils) |
| `ia.vision.relais` | photo + ordre : gemma a décrit, le pilote prend la main avec ses outils |
| `ia.vision.absente` | photo jointe, mais aucun modèle d'images branché : le pilote ne la verra pas (**problème**) |

Et chaque `ia.tour` porte son `role` (`images` ou `pilote`) et son `modele`,
d'où les comptes « tours par modèle » et « images » du panneau Santé.

## 3. Ce que le backoffice ne fait pas

- **Il n'agit jamais sur la machine.** Pas de bouton qui envoie quelque chose
  à la carte ou au modèle depuis cet écran. Son seul geste est un réglage
  (brancher un modèle d'images), tracé comme tel.
- **Il n'invente rien.** Chaque chiffre vient d'un événement enregistré ; une
  valeur absente s'affiche « — » (règle « jamais de données inventées »).
- **Il ne copie pas les conversations.** Un aperçu de 160 caractères par
  message d'opérateur, 400 par résultat d'outil ; la discussion entière est
  déjà dans ses propres fichiers.
- **Il ne remplace pas `AiTurnJournal`**, qui reste le journal partageable
  sans relecture (aucun contenu). Le backoffice le lit pour son panneau Santé.
- **Il ne voit que son appareil.** Le PC voit ce que le téléphone lui envoie
  par le relais ; les événements propres au téléphone (sa liaison, son arrêt
  d'urgence local) sont dans le backoffice du téléphone.

## 4. Mesures de la session de test

`flutter test` sur les trois fichiers concernés (`backoffice_bus_test`,
`backoffice_agent_test`, `chat_relay_test`) : 31 tests, tous verts. Ils
vérifient notamment que :

- une commande partie pendant un outil de l'IA porte le `callId` de l'outil,
  et la réponse `ok` de la carte aussi, avec sa latence ;
- une action confirmée depuis le téléphone est attribuée au téléphone jusqu'à
  la commande envoyée ;
- `$RST=*` demandé par le modèle est classé `garde.outil`, et rien ne part ;
- 200 lignes d'usinage donnent 3 événements, pas 400 ;
- un journal corrompu se relit sans tomber, et un bus redémarré reprend la
  numérotation là où le disque s'était arrêté.

## 5. Suites possibles

- Valeur des overrides dans `firmware.tx` (le journal d'activité ne la garde
  toujours pas — `PLAN-IA.md`, phase 0).
- Compteurs ForceGuard (lignes bridées / bloquées) au départ d'un programme :
  `StreamingController` les calcule déjà, il suffit de les émettre.
- Un bandeau « problème » hors de l'écran Backoffice quand un événement
  critique arrive (le bouton IA sait déjà badger ; même mécanisme).
