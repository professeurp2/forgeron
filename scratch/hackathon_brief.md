# Hackathon chatbot — Dossier de référence
**UniPods METI AI Innovation Programme · Cohorte 1**
Chef d'équipe : Lamine SACKO (Mali) · Fenêtre : **vendredi 18 → jeudi 24 septembre 2026** · Prix : **5 000 $**

> 📌 **Ce document remplace le choix « Telegram d'abord » du `hackathon_spec.md`.**
> La cible est **WhatsApp**. Toute l'architecture ci-dessous est repensée dans ce sens.

---

# 1. LE CONTEXTE

## 1.1 D'où ça vient

Le programme **METI AI UniPods** (financé par le METI japonais, opéré par timbuktoo / PNUD) a retenu **244 projets sur 670 candidatures, dans 24 pays africains**. Forgeron en fait partie — c'est la **cohorte 1**.

Pendant le programme, les 244 participants se retrouvent dans un **groupe de discussion commun** et lors de **sessions en visio** (formations, Q&R, annonces). C'est là que naît le problème.

## 1.2 Le problème réel que le hackathon veut résoudre

Ce n'est pas un sujet théorique : **c'est la douleur des organisateurs et des participants eux-mêmes.**

| # | Symptôme | Conséquence |
|---|---|---|
| **F1** | Le groupe est énorme et le trafic très élevé | Les messages importants passent à la trappe |
| **F2** | Le groupe n'a aucune mémoire | Les mêmes questions reviennent en boucle |
| **F3** | Des sessions sont manquées, les enregistrements jamais revus | Décisions et contexte perdus |

L'information est éclatée entre **les conversations** et **les appels**, et il n'existe aucun endroit où poser la question : *« qu'est-ce que j'ai raté ? »*

## 1.3 Ce que ça implique pour nous

**Le jury, ce sont les gens qui vivent ce problème.** Ils ne vont pas évaluer une démo abstraite : ils vont poser au bot une **vraie question sur leur propre groupe** et regarder si la réponse est juste.

C'est la chose la plus importante à comprendre sur ce hackathon. Tout le reste en découle.

---

# 2. L'OBJECTIF

> **Construire un chatbot WhatsApp qui absorbe les conversations du groupe et les enregistrements des sessions, et qui répond directement aux membres** — pour que personne n'ait plus à faire défiler, à re-demander, ou à re-regarder une visio.

**Définition de « c'est fait » :** un membre de la cohorte pose au bot, **sur WhatsApp**, une vraie question sur quelque chose qui a été dit dans le groupe, et obtient en quelques secondes une réponse **correcte et sourcée**.

## Les 5 critères de réussite

1. **Ça tourne vraiment.** En ligne, joignable, qui répond — pas une vidéo de démo.
2. **Les réponses sont ancrées.** Chaque réponse cite d'où elle vient (auteur, date, lien, horodatage).
3. **Ça résout *leur* douleur**, visiblement : « déjà répondu ici », « qu'est-ce que j'ai raté », résumés de session.
4. **N'importe qui peut le faire tourner.** Repo propre + notes d'installation qui marchent sur une machine neuve.
5. **Ça respecte le groupe.** Comportement clair sur les données, aucune fuite surprise.

---

# 3. ⚠️ LA CONTRAINTE CENTRALE — WhatsApp et les groupes

**C'est la décision technique qui structure tout le projet. À comprendre avant d'écrire une ligne de code.**

## 3.1 Le fait brut

**L'API officielle WhatsApp (Cloud API, de Meta) ne permet pas de lire les conversations de groupe.** Elle est conçue pour la messagerie **1:1** entre une entreprise et un client. Un bot branché dessus reçoit les messages qu'on lui envoie **en privé**, et rien d'autre.

Autrement dit : **on ne peut pas, officiellement, mettre un bot dans le groupe de la cohorte et lui faire lire ce qui s'y dit.**

Ce n'est pas un détail à contourner discrètement. C'est la contrainte du sujet — et la traiter intelligemment fait partie de ce qui sera jugé.

## 3.2 Les trois voies d'accès à WhatsApp

| Voie | Ce qu'elle permet | Officiel ? | Risque |
|---|---|---|---|
| **A — Cloud API (Meta)** | Recevoir et répondre en **1:1** (DM au bot) | ✅ Oui | Aucun |
| **B — Export de discussion** (`Exporter la discussion` → `.txt`) | Récupérer **tout l'historique** du groupe | ✅ Oui | Aucun |
| **C — Passerelle web** (Baileys, whatsapp-web.js) | **Lire et écrire dans le groupe**, en direct | ❌ Non | Contraire aux CGU, **numéro bannissable** |

## 3.3 🔑 L'idée qui débloque tout

**Ingérer et répondre sont deux problèmes séparés.** On a tendance à les confondre — et c'est là qu'on se bloque.

Le bot n'a **pas besoin de lire le groupe pour répondre**. Il a besoin d'**avoir ingéré** le groupe. Donc :

```
  INGESTION (comment le contenu entre)          RÉPONSE (où le bot parle)
  ├── Export .txt      → officiel, tout       ├── DM au bot via Cloud API → officiel, zéro risque
  │   l'historique, zéro risque               │
  └── Baileys en direct → non officiel,       └── Dans le groupe via Baileys → non officiel
      messages nouveaux
```

**Conséquence pratique : on peut livrer un produit 100 % WhatsApp, entièrement officiel, sans jamais toucher à Baileys** — historique par export, questions et réponses en DM via la Cloud API. Ça coche déjà tous les critères du sujet.

Baileys vient **après**, en bonus, pour le direct dans le groupe.

## 3.4 La stratégie retenue

**Chemin sûr d'abord, chemin impressionnant ensuite. Jamais l'inverse.**

| Phase | Quoi | Pourquoi dans cet ordre |
|---|---|---|
| **1 — Jours 1-3** | Cloud API en DM + ingestion par export `.txt` | **Officiel, zéro risque.** À la fin du jour 3 on a un produit livrable. |
| **2 — Jours 4-5** | Baileys sur un **numéro dédié jetable** : ingestion live + réponses dans le groupe | Le « waouh ». Si ça casse, la phase 1 tient toujours. |
| **Démo** | On montre ce qui est stable le jour J | L'architecture rend le choix trivial : c'est une config, pas une réécriture. |

> **Règle absolue : le composant risqué ne doit jamais bloquer le livrable.**
> Si Baileys se fait bannir le jour 6, le projet doit continuer à fonctionner sans lui.

## 3.5 Ce qu'il faut dire au jury

Ne cache pas la contrainte — **explique-la**. C'est un point fort, pas une faiblesse :

> *« L'API officielle WhatsApp ne lit pas les groupes. Nous avons donc séparé l'ingestion de la réponse : l'historique arrive par l'export officiel, les réponses partent par la Cloud API officielle. La lecture en direct du groupe passe par une passerelle non officielle, sur un numéro dédié, et c'est une option — si elle tombe, le produit continue de fonctionner. »*

Ça montre du **jugement d'ingénieur**. C'est exactement ce qu'un jury technique cherche.

## 3.6 Points pratiques Cloud API à ne pas découvrir le jour 5

- Il faut un **compte Meta Business** + l'app WhatsApp Business Platform.
- Meta fournit un **numéro de test gratuit et immédiat**, sans vérification d'entreprise. ✅ Parfait pour un hackathon.
- ⚠️ **Mais ce numéro de test ne peut écrire qu'à un petit nombre de destinataires pré-enregistrés (≈5).** → **Il faut enregistrer à l'avance les numéros des juges**, sinon ils ne pourront pas essayer le bot eux-mêmes. À anticiper dès le jour 1.
- Un vrai numéro de production demande une **vérification d'entreprise** — trop long pour la semaine, ne compte pas dessus.
- Le webhook exige une **URL publique HTTPS** → d'où l'hébergement dès le jour 1.
- La tarification Meta a changé récemment : vérifie l'allocation gratuite actuelle pour les conversations initiées par l'utilisateur.

---

# 4. LE PÉRIMÈTRE

## 4.1 MUST — le MVP (non négociable, bouclé jour 5)

| # | Exigence |
|---|---|
| **R1** | **Ingestion des conversations.** Importer l'historique du groupe, et continuer à ingérer les nouveaux messages. |
| **R2** | **Ingestion des appels.** Accepter un enregistrement (fichier ou lien), le transcrire, stocker la transcription avec horodatages et locuteurs si possible. |
| **R3** | **Base de connaissances.** Découper, vectoriser et indexer le tout (chats + transcriptions) avec les métadonnées : source, auteur, date, lien. |
| **R4** | **Réponse aux questions.** Un membre pose une question → réponse ancrée **avec ses sources**. |
| **R5** | **Canal direct.** Le bot répond **sur WhatsApp**, là où les gens sont déjà. |
| **R6** | **Comportement « je ne sais pas ».** Si la base n'a pas la réponse, le dire. **Jamais inventer.** |

## 4.2 SHOULD — ce qui fait gagner le vote (jours 5-6)

| # | Exigence |
|---|---|
| **R7** | **Détection de doublon.** Question ressemblant à une déjà répondue → « c'est déjà traité ici » + lien. |
| **R8** | **Digest de rattrapage.** `/catchup` ou « qu'est-ce que j'ai raté depuis lundi ? » → résumé des fils, décisions, échéances. |
| **R9** | **Résumé de session.** Pour chaque enregistrement : synthèse, décisions, actions, responsables. |
| **R10** | **Digest quotidien.** Un message programmé par jour : temps forts, questions ouvertes, échéances. |

## 4.3 NICE-TO-HAVE (seulement s'il reste du temps)

R11 recherche sémantique (`/search`) · R12 réponses bilingues **EN/FR** (la cohorte est anglophone **et** francophone) · R13 tableau de bord web · R14 rappels d'échéances extraits automatiquement.

## 4.4 Hors sujet

Réponses vocales, application mobile, fine-tuning d'un modèle, transcription d'appel en temps réel.

---

# 5. L'ARCHITECTURE

```
┌────────────────────────┐      ┌──────────────────────┐
│  GROUPE WHATSAPP       │      │  ENREGISTREMENTS     │
│  ├─ export .txt   ✅   │      │  (audio / vidéo)     │
│  └─ live Baileys  ⚠️   │      └──────────┬───────────┘
└──────────┬─────────────┘                 │
           │                               ▼
           │                    ┌──────────────────────┐
           │                    │   TRANSCRIPTION      │  faster-whisper
           │                    └──────────┬───────────┘
           ▼                               ▼
┌──────────────────────────────────────────────────────┐
│  INGESTION — normaliser → découper                   │
│  (auteur, horodatage, source, lien)                  │
└────────────────────────┬─────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────┐
│  BASE DE CONNAISSANCES                               │
│  Postgres + pgvector  (Supabase)                     │
└────────────────────────┬─────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────┐
│  RECHERCHE (sémantique + fraîcheur)                  │
│               ↓                                      │
│  RÉPONSE LLM — ancrée et sourcée                     │
└────────────────────────┬─────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────┐
│  ADAPTATEUR — couche fine, interchangeable           │
│  ├─ WhatsApp Cloud API (DM)      ✅ officiel         │
│  └─ WhatsApp Baileys (groupe)    ⚠️ non officiel     │
└──────────────────────────────────────────────────────┘
```

**Règle de conception : l'adaptateur est une couche fine et remplaçable.** Le cœur (ingérer → indexer → répondre) ne doit dépendre d'**aucun** canal. C'est ce qui permet de basculer Cloud API ↔ Baileys par une variable de configuration au lieu d'une réécriture.

---

# 6. LA STACK

Tout a un **niveau gratuit**. Coût cible pour la semaine : **0 $**.

| Couche | Outil | Pourquoi |
|---|---|---|
| **Langage** | Python 3.11+ | Meilleur écosystème IA, le plus rapide à livrer |
| **Backend** | FastAPI + Uvicorn | Minimal, async, webhooks simples |
| **LLM** | **Google Gemini** (Flash / Flash-Lite) | Niveau gratuit généreux, function calling — **l'équipe connaît déjà** |
| **Embeddings** | Gemini `text-embedding-004` *(repli : `sentence-transformers`, local et gratuit)* | Voir §7 sur l'indexation en masse |
| **Base + vecteurs** | **Supabase** (Postgres + pgvector) | Hébergé, gratuit, SQL et vecteurs au même endroit |
| **Transcription** | **faster-whisper** (local, gratuit) *ou* Gemini audio | Pas de coût à la minute |
| **WhatsApp — réponses** | **Cloud API** (Meta) | ✅ Officiel, zéro risque |
| **WhatsApp — historique** | **Parseur d'export `.txt`** | ✅ Officiel, 100 % fiable |
| **WhatsApp — groupe live** | **Baileys** (Node) | ⚠️ Non officiel, numéro dédié uniquement |
| **Planificateur** | APScheduler | Digest quotidien |
| **Hébergement** | Railway / Render / Fly.io | URL publique HTTPS obligatoire pour le webhook |
| **Repo** | **GitHub public** + `README.md` | Livrable exigé |
| **Tests** | `pytest` + jeu de questions fixe | Prouver la qualité objectivement |

### Arborescence proposée
```
group-memory-bot/
├── README.md              # notes d'installation (livrable exigé)
├── .env.example
├── requirements.txt
├── app/
│   ├── main.py            # FastAPI + webhook
│   ├── ingest/            # chat_import.py, transcribe.py, chunker.py
│   ├── kb/                # embeddings.py, store.py (pgvector), search.py
│   ├── answer/            # rag.py, prompts.py, citations.py
│   ├── adapters/          # whatsapp_cloud.py, whatsapp_baileys.py
│   └── jobs/              # digest.py, duplicate_check.py
├── scripts/               # import en masse, réindexation
└── tests/
```

---

# 7. LES DEUX DÉCISIONS À VERROUILLER MAINTENANT

Changer d'avis dessus plus tard coûte une **réindexation complète**.

| Décision | Défaut | Pourquoi c'est bloquant |
|---|---|---|
| **Modèle d'embedding + dimension** | `text-embedding-004` (768) **ou** `paraphrase-multilingual-MiniLM-L12-v2` (384) | Doit être **le même** à l'indexation et à la requête, **et** correspondre à la colonne `vector(n)` |
| **Langue des réponses** | Celle de la question (EN/FR) | La cohorte est bilingue |

> 💡 **Fais l'indexation en masse en local avec `sentence-transformers`.** Des milliers de messages passés par l'API brûleraient le quota gratuit en quelques minutes. Le mot « local » veut dire ici : le modèle tourne sur ta machine, gratuitement, sans appel réseau.

---

# 8. LES RÈGLES DU HACKATHON

## 8.1 L'équipe

| Règle | Détail |
|---|---|
| Taille | **5 personnes maximum** |
| 🚨 **Nationalités** | **Au moins 2 pays différents** |
| 🚨 **Mixité** | **Au moins 1 femme** |
| Déclaration | Email à envoyer avec l'objet **`UniPods Hackathon`**, listant chaque membre et son pays |

> ⚠️ **Les deux règles marquées 🚨 sont des blocages durs.** Une équipe 100 % malienne, ou 100 % masculine, est disqualifiée quelle que soit la qualité du bot. **À vérifier avant toute chose.**

## 8.2 Les livrables

1. ✅ Un **chatbot fonctionnel**, joignable en direct pendant le jugement.
2. ✅ Un **dépôt GitHub public** avec tout le code source.
3. ✅ Des **notes d'installation** dans le `README.md` : prérequis, variables d'environnement, installation, lancement, déploiement, comment ingérer un export et un enregistrement.
4. *(Bonus qui fait la différence)* Une vidéo de démo de 2 min + une page « comment ça marche ».

## 8.3 Répartition des rôles

| Rôle | Responsabilité |
|---|---|
| **Chef d'équipe / IA** (Lamine) | Architecture, RAG, prompts, démo finale |
| **Backend / données** | Parseur, schéma, indexation, jobs programmés |
| **Intégration / DevOps** | Adaptateurs WhatsApp, déploiement, disponibilité, logs |
| **Audio / ML** | Transcription, horodatages, locuteurs |
| **Produit / QA / docs** | Jeu de questions de test, README, vidéo, script de démo |

*Moins de 5 personnes ? On fusionne les rôles — mais **jamais** de déploiement ni de documentation sans propriétaire.*

---

# 9. LE PLAN 7 JOURS

| Jour | Objectif | État en fin de journée |
|---|---|---|
| **J1 · ven. 18** | Squelette déployé + **webhook Cloud API** qui répond | Un membre envoie un DM au bot → il répond. Depuis une URL publique, pas un laptop. |
| **J2 · sam. 19** | Ingestion : parseur d'export, découpage, schéma Supabase | Tout l'historique est indexé et cherchable |
| **J3 · dim. 20** | **Recherche + réponses ancrées avec citations** | **🚦 POINT GO/NO-GO** — le bot répond juste à une vraie question, avec sa source |
| **J4 · lun. 21** | Transcription + **Baileys sur numéro dédié** | Question sur une session → réponse depuis la transcription |
| **J5 · mar. 22** | **🔒 GEL DU MVP.** Détection de doublon + `/catchup` | R1–R8 terminés et déployés |
| **J6 · mer. 23** | Résumés de session, digest quotidien, robustesse, replis | Stable, ne casse pas sous charge |
| **J7 · jeu. 24** | README, vidéo, répétition, **soumission** | Soumis **le matin**, avec de la marge |

> **Deux règles qui gouvernent la semaine :**
> **1.** Déployer dès le jour 1 et rester en ligne. Un bot qu'on peut essayer bat un meilleur bot qui tourne sur un laptop.
> **2.** Si le jour 3 échoue, **on arrête d'ajouter des fonctionnalités** et on répare ça. Tout le reste ne vaut rien sans des réponses justes et sourcées.

---

# 10. LES RISQUES

| Risque | Parade |
|---|---|
| **Numéro banni / passerelle groupe bloquée** | Chemin officiel (export + DM Cloud API) livré **en premier** ; Baileys sur numéro jetable uniquement |
| **Le numéro de test Meta ne peut écrire qu'à ~5 destinataires** | **Enregistrer les numéros des juges à l'avance** ; prévoir un partage d'écran en secours |
| Quota LLM gratuit épuisé | Plusieurs clés (une par membre), repli multi-modèles, cache des réponses, limite par utilisateur |
| Mauvaise transcription | Modèle Whisper plus gros pour les fichiers de démo ; autoriser le dépôt d'une transcription manuelle |
| **Réponses inventées** | Prompt d'ancrage strict + « pas de source → pas de réponse » ; citations toujours affichées |
| Équipe sur plusieurs fuseaux | Point écrit asynchrone chaque matin + 30 min en visio par jour |
| Dérive du périmètre | MVP gelé le jour 5 ; tout le reste explicitement optionnel |

---

# 11. EXIGENCES NON FONCTIONNELLES

- **Coût :** 0 $ sur la semaine (niveaux gratuits uniquement).
- **Latence :** réponse en moins de 10 s.
- **Exactitude :** jamais d'invention. Pas de source → *« je n'ai pas cette information. »*
- **Confidentialité :** n'ingérer que le groupe qu'on est autorisé à utiliser ; rien de revendu ni envoyé ailleurs que vers le LLM ; documenter précisément ce qui est stocké ; fournir une commande d'effacement de l'index.
- **Fiabilité :** quota LLM atteint → basculer sur une autre clé/modèle et continuer à servir au moins les résultats de recherche.
- **Maintenabilité :** cloner, régler 5 variables d'environnement, lancer.

---

# 12. LA DÉMO (5 minutes, répétée)

1. **La douleur en une phrase** — *« quelqu'un a posé une question à laquelle on avait déjà répondu trois fois. »*
2. Un juge pose une **vraie question** depuis **son propre WhatsApp** → réponse ancrée **avec la source**.
3. *« Qu'est-ce que j'ai raté cette semaine ? »* → digest.
4. Une question dont la réponse n'existe **que dans un appel** → réponse tirée de la transcription.
5. **On repose une vieille question** → « c'est déjà traité ici » + lien.
6. On montre le **repo + README**, et on dit que c'est déployé et en train de tourner.

---

# 13. CE QUI FAIT GAGNER

- Ça **tourne en direct**, et les juges peuvent l'essayer **depuis leur propre WhatsApp**.
- Les réponses sont **sourcées** — la confiance, c'est tout le sujet.
- Ça résout **leur** douleur (répétitions, sessions manquées), pas une démo de chatbot générique.
- La contrainte WhatsApp est **traitée ouvertement**, avec une architecture qui y survit.
- N'importe qui peut **cloner et lancer**.

---

# 14. À FAIRE MAINTENANT

| # | Action | Bloquant ? |
|---|---|---|
| 1 | **Confirmer l'équipe** : ≥1 femme, ≥2 pays, ≤5 personnes | 🚨 **Éliminatoire** |
| 2 | **Envoyer l'email de déclaration** (objet `UniPods Hackathon`) | 🚨 **Éliminatoire** |
| 3 | Créer le **compte Meta Business** + récupérer le **numéro de test** | Bloque J1 |
| 4 | **Exporter la discussion du groupe** (`Exporter la discussion` → sans médias) | Bloque J2 |
| 5 | Créer le repo public + inviter l'équipe | Bloque J1 |
| 6 | Une **clé Gemini par membre** (mutualisation des quotas) | Bloque J3 |
| 7 | Projet **Supabase** + activer l'extension `vector` | Bloque J2 |
| 8 | Compte d'hébergement (Railway / Render) | Bloque J1 |
| 9 | Récupérer **1–2 enregistrements** de session | Bloque J4 |
| 10 | Verrouiller les décisions du **§7** et les écrire dans le repo | Bloque J2 |

> ⚠️ **Vérifie les points 1 et 2 auprès des organisateurs.** L'échéance de déclaration était fixée à hier soir (jeudi 17). Si l'email n'est pas parti, envoie-le **immédiatement** et signale le retard — mieux vaut un email en retard qu'une équipe non déclarée.

---

*Document de référence du hackathon — cohorte 1, UniPods METI AI.*
