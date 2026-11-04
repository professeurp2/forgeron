# KALAN — Cahier des charges
**Assistant pédagogique IA, hors ligne, pour l'enseignement public malien**

Porteur : Lamine SACKO · Bamako, Mali · ENI-ABT / UniPod Mali
Cible : candidature **timbuktoo UniPods Cohorte 2** — date limite **30 octobre 2026**

> **Nom de travail : KALAN** (de *kalan*, « étudier / apprendre » en bambara).
> À valider par un locuteur natif — c'est toi. Alternatives : *Kalanso*, *Karamɔgɔ*, *Sɛbɛn*.

---

## 1. LE PROBLÈME

### 1.1 Ce qu'on ne cherche PAS à faire

**Kalan ne remplace pas l'enseignant.** Ce cadrage est abandonné dès le départ, pour deux raisons :

- Un enseignant fait de la discipline, de la motivation, de la relation, de la lecture de visages. Une IA ne rivalise pas là-dessus.
- Une école à qui on propose un remplaçant se ferme. Une école à qui on propose un renfort s'ouvre.

### 1.2 Le vrai problème

Dans l'enseignement public malien, **le problème n'est pas la compétence de l'enseignant : c'est le ratio.**

| # | Défaillance | Conséquence pour l'élève |
|---|---|---|
| **P1** | Effectifs très élevés par classe | Aucune attention individuelle possible — c'est physiquement impossible, pas un manque de volonté |
| **P2** | Enseignement en français, pensée en bambara | L'élève ne bute pas sur le concept, il bute sur la langue |
| **P3** | Pas d'aide après la classe | Parents souvent non scolarisés ; pas de cours particuliers accessibles |
| **P4** | Concepts abstraits sans support visuel | Peu de matériel, peu de laboratoires, surtout en sciences et technique |

> ⚠️ **À sourcer avant la candidature** : ratio élèves/enseignant au Mali, taux d'achèvement du fondamental, part des élèves dont le français n'est pas la langue première.
> Sources à utiliser : **UNESCO Institute for Statistics**, **annuaire statistique du Ministère de l'Éducation nationale du Mali**. Un chiffre officiel vaut dix affirmations.

### 1.3 La formulation qui porte le projet

> **L'IA ne remplace pas le professeur. Elle donne à chaque élève ce que le professeur n'a pas le temps de donner : quelqu'un à qui poser une question bête, dans sa langue, sans honte devant la classe.**

---

## 2. OBJECTIF

Construire un **assistant pédagogique vocal et visuel, fonctionnant entièrement hors ligne**, ancré sur le **programme scolaire officiel malien**, qui répond aux questions des élèves et **montre à l'écran** ce qu'il explique.

### Définition de « c'est fait »

Un élève de l'enseignement public pose une question à voix haute sur une leçon de son programme. En moins de 10 secondes, **sans aucune connexion Internet**, l'assistant répond à voix haute, **affiche et pointe le schéma correspondant à l'écran**, et cite le chapitre d'où vient la réponse.

### Critères de réussite

1. **Ça marche sans réseau.** C'est la condition non négociable du terrain malien.
2. **Les réponses sont ancrées sur le programme officiel** — pas sur la culture générale du modèle. Hors programme → « je ne sais pas ».
3. **L'élève comprend mieux qu'avec un manuel seul.** Mesuré, pas affirmé (§9).
4. **L'enseignant l'adopte** parce que ça lui enlève une charge, pas parce qu'on lui impose un outil.
5. **Aucune donnée d'enfant ne quitte l'appareil.**

---

## 3. UTILISATEURS

| Utilisateur | Besoin | Ce que Kalan lui apporte |
|---|---|---|
| **Élève** (cible principale) | Poser une question sans être jugé, à son rythme | Réponse vocale + visuelle, répétable à l'infini, sans honte |
| **Enseignant** | Gérer un effectif ingérable | Prend en charge les questions de rattrapage ; signale les notions qui bloquent la classe |
| **Établissement** | Résultats aux examens | Outil de soutien mutualisé, sans frais de connexion |
| **Ministère / bailleur** | Déploiement à l'échelle, souveraineté des données | Coût par appareil connu, fonctionne partout, données locales |

**Qui paie :** l'établissement, le ministère, ou un bailleur — pas l'élève. C'est un marché **B2G / B2B institutionnel**, avec des cycles longs et des appels d'offres. À intégrer dès le départ dans le modèle économique.

---

## 4. PÉRIMÈTRE

### 4.1 MUST — le MVP

| # | Exigence |
|---|---|
| **R1** | **Entrée vocale en français**, en conditions de classe (bruit de fond) |
| **R2** | **Sortie vocale en français**, naturelle et intelligible |
| **R3** | **Base de connaissances = programme scolaire officiel**, découpé, indexé, interrogeable |
| **R4** | **Réponse ancrée et citée** : chapitre, leçon, page |
| **R5** | **Refus explicite** hors programme : « ce n'est pas dans ton programme » — jamais d'invention |
| **R6** | **100 % hors ligne.** Aucun appel réseau nécessaire au fonctionnement |
| **R7** | **Affichage synchronisé** : pendant qu'il parle, l'écran montre le schéma et **pointe l'élément dont il parle** |

> **R7 est le cœur du produit.** C'est ce qui remplace le geste de l'enseignant, et c'est ce qui distingue Kalan d'un chatbot. Voix seule = assistant banal. Voix **synchronisée** avec un pointage à l'écran = explication.

### 4.2 SHOULD

- **R8** — Simulations interactives pour les sciences (circuit électrique, forces, construction géométrique)
- **R9** — Mode révision : l'assistant interroge l'élève au lieu de répondre
- **R10** — Tableau de bord enseignant : quelles notions reviennent le plus → ce qui bloque la classe
- **R11** — Mise à jour du programme par clé USB, sans réseau

### 4.3 NICE-TO-HAVE

- R12 — **Bambara** en entrée et en sortie *(voir §8 — décalé, pas abandonné)*
- R13 — Lecture d'un énoncé photographié (vision)
- R14 — Plusieurs niveaux scolaires
- R15 — Voix de l'avatar personnalisable

### 4.4 Hors périmètre

Notation officielle, remplacement d'un cours, réseau social entre élèves, **corps physique / robot** *(écarté — voir §7)*.

---

## 5. ARCHITECTURE — tout local

```
┌─────────────────────────────────────────────────┐
│  TABLETTE ANDROID (ou mini-PC)   — HORS LIGNE   │
│                                                 │
│   🎤 Micro                                      │
│      └─► STT local (Whisper small/tiny)         │
│             └─► Question en texte                │
│                   │                             │
│                   ▼                             │
│          ┌──────────────────────┐               │
│          │ RECHERCHE SÉMANTIQUE │               │
│          │ embeddings locaux    │               │
│          │ + index du programme │               │
│          └──────────┬───────────┘               │
│                     ▼                           │
│          ┌──────────────────────┐               │
│          │  LLM LOCAL           │               │
│          │  (Gemma 3n)          │               │
│          │  réponse + ancrage   │               │
│          │  + consigne visuelle │               │
│          └──────┬───────────┬───┘               │
│                 ▼           ▼                   │
│      TTS local (Piper)   Moteur d'affichage     │
│          🔊 Voix      +  📺 Schéma + pointeur   │
│                 └─── synchronisés ───┘          │
└─────────────────────────────────────────────────┘
          Aucune donnée ne sort de l'appareil
```

**Règle d'architecture : aucun composant ne doit exiger le réseau pour fonctionner.** Le réseau ne sert qu'aux mises à jour, et il est optionnel.

---

## 6. STACK TECHNIQUE

| Couche | Choix | Pourquoi |
|---|---|---|
| **Appareil** | **Tablette Android** 8 Go RAM | Écran + micro + haut-parleur + batterie dans un seul objet. **Aucun assemblage.** |
| **Application** | **Flutter** | Compétence déjà acquise sur Forgeron — zéro temps d'apprentissage |
| **LLM** | **Gemma 3n** via MediaPipe / LiteRT | Conçu pour l'embarqué, multimodal (texte, audio, image) → prépare R13 sans changer d'architecture |
| **STT** | **Whisper** small/tiny quantisé | Bon en français, tourne sur CPU |
| **TTS** | **Piper** | Léger, rapide, voix française correcte, entièrement local |
| **Embeddings** | `paraphrase-multilingual-MiniLM-L12-v2` | Multilingue, petit — prépare le bambara |
| **Index vectoriel** | SQLite + index vectoriel local | Pas de serveur, un fichier |
| **Affichage** | SVG animé piloté par la réponse | Le LLM renvoie quoi pointer et quand |

> ⚙️ **Décision à verrouiller tout de suite** : le modèle d'embedding **et sa dimension**. Identiques à l'indexation et à la requête. En changer plus tard = tout réindexer.

### Pourquoi la tablette plutôt qu'un boîtier sur mesure

| | Tablette | Boîtier (Pi / mini-PC) |
|---|---|---|
| Écran, micro, son, batterie | Intégrés | À assembler et à câbler |
| Compétence requise | Flutter — tu l'as | Électronique + intégration |
| Temps jusqu'au premier prototype | Jours | Semaines |
| Réparation sur le terrain | Standard | Artisanale |

Tu es mécatronicien, donc tu *peux* faire le boîtier. **La question n'est pas si tu peux, c'est si ça sert le produit.** Pour cette première version, non.

---

## 7. L'ÉCRAN PLUTÔT QUE LE CORPS — décision assumée

Le corps physique est **écarté pour cette version**, et c'est un choix défendable, pas un renoncement :

- Le geste de l'enseignant aide réellement à comprendre — **chez l'humain**. Que l'effet se transpose à un robot est bien moins établi qu'on ne le croit.
- Un humanoïde coûte des milliers de dollars, est fragile, et ne se déploie pas dans cinquante écoles.
- **Ce qui compte pédagogiquement, c'est le pointage synchronisé avec la parole** — et un écran le fait parfaitement, pour zéro franc de mécanique.

**Reformulé : on ne renonce pas au geste. On le déplace dans l'écran.**

---

## 8. LE BAMBARA — décalé, pas abandonné

Le français d'abord : les modèles existent, la qualité est là, on peut livrer vite.

**Mais il faut être lucide sur deux points :**

1. **Le bambara est la vraie barrière à l'entrée du projet.** N'importe qui peut brancher un RAG sur un LLM en français. Presque personne ne collectera des heures d'audio bambara transcrit. C'est lent, peu valorisant, et c'est exactement pour ça que ça protège.
2. **C'est un problème de données, pas de modèle.** Enregistrer, transcrire, aligner. Ça se commence en parallèle du développement français, dès maintenant, à petite échelle.

> 📍 **Le Jour 4 du bootcamp d'Addis (11 novembre) porte précisément sur ce sujet** : *« local-language and voice AI, data scarcity, multilingual evaluation, speech interfaces »*.
> **Arrives-y avec cette question préparée.** Tu auras une journée entière de spécialistes dessus, gratuitement.

---

## 9. PROUVER QUE ÇA MARCHE

C'est ce qui manquera à tous les autres candidats. **Prévois-le dès le cahier des charges.**

**Protocole minimal, réalisable avec une seule classe :**

1. Choisir **une leçon** du programme (ex. : une notion de physique de 9ᵉ année).
2. **Test avant** sur 20 élèves — 10 questions.
3. Moitié révise avec le manuel, moitié avec Kalan. 30 minutes.
4. **Test après**, mêmes questions.
5. Comparer les deux groupes.

Même avec 20 élèves, c'est **une preuve** — pas une promesse. Et c'est exactement le genre d'évidence que le programme réclame (« *startups completing buyer engagement and revising assumptions* »).

---

## 10. EXIGENCES NON FONCTIONNELLES

- **Hors ligne** : fonctionnement intégral sans réseau. Non négociable.
- **Latence** : réponse en moins de 10 secondes sur l'appareil cible.
- **Autonomie** : une journée de classe sans recharge.
- **Coût** : appareil sous **150 000 FCFA**, zéro coût récurrent par élève (pas d'API, pas de données).
- **Exactitude** : jamais d'invention. Pas de source dans le programme → « je ne sais pas ».
- **🔒 Protection des mineurs** : aucun enregistrement d'enfant ne quitte l'appareil ; audio brut non conservé par défaut ; effacement possible. **Le tout-local n'est pas qu'un choix technique, c'est l'argument de conformité auprès du ministère.**
- **Maintenance** : mise à jour du programme par clé USB, par un enseignant, sans technicien.

---

## 11. RISQUES

| Risque | Parade |
|---|---|
| **Accès au programme scolaire officiel** | Passer par UniPod Mali et l'ENI-ABT pour obtenir les manuels et une caution institutionnelle |
| Le LLM local est trop lent sur tablette | Mesurer **dès la semaine 1** sur l'appareil réel ; modèle plus petit, réponses plus courtes, pré-calcul |
| Qualité du STT en classe bruyante | Micro directionnel, bouton « appuyer pour parler » plutôt qu'écoute permanente |
| Réponses hors programme malgré l'ancrage | Prompt strict + seuil de similarité + refus par défaut |
| Rejet par les enseignants | Les associer dès le premier prototype ; positionner en renfort, jamais en remplaçant |
| Cycle de vente public très long | Viser d'abord un **pilote** dans un établissement, pas un marché national |
| Bambara trop coûteux | Décalé explicitement ; le produit tient debout en français seul |

---

## 12. PLAN — 8 jours jusqu'à la candidature

> **Date limite : vendredi 30 octobre 2026.** Départ pour Addis le **8 novembre**.

| Jour | Quoi | Résultat |
|---|---|---|
| **J1 — 22 oct** | ❓ **Vérifier l'éligibilité Cohorte 2** auprès de `unipods.regional@undp.org` (tu es déjà en Cohorte 1) | Réponse écrite |
| **J1** | Verrouiller le nom, les décisions du §6, constituer l'équipe | Décisions écrites |
| **J2 — 23 oct** | Sourcer les chiffres (UNESCO, ministère) + récupérer **un chapitre** de manuel | Un PDF, deux chiffres sourcés |
| **J3–J4** | **Prototype minimal sur ordinateur** : Whisper → RAG sur ce chapitre → Piper. Voix seulement. | On pose une question à voix haute, on obtient une réponse sourcée |
| **J5** | Ajouter l'affichage synchronisé sur **un seul schéma** | R7 démontrée une fois |
| **J6** | Filmer une démo de 90 secondes | Vidéo |
| **J7 — 28 oct** | Rédiger la candidature | Brouillon complet |
| **J8 — 29 oct** | Relire, faire relire, **soumettre** | ✅ Soumis **la veille** |

> ⏰ **Soumets le 29, pas le 30.** Tu connais la règle maintenant.

**La stratégie, en une phrase :** ta candidature Forgeron a été prise parce que tu avais **une machine qui tournait**, pas un beau dossier. Fais pareil ici. **Un prototype laid qui répond vraiment à une question battra dix concepts bien présentés.** Même s'il ne connaît qu'un seul chapitre.

---

## 13. CE QU'ON NE SAIT PAS ENCORE

À trancher avant ou pendant la rédaction :

1. **Éligibilité Cohorte 2** en tant que participant Cohorte 1 — bloquant.
2. **Qui porte la candidature** — toi, ou un coéquipier si l'éligibilité l'impose.
3. **L'équipe** — ce projet n'est pas celui de Forgeron ; il faut au moins un profil pédagogique (un enseignant).
4. **Niveau scolaire et matière visés** pour le MVP — commencer par **une** matière, **un** niveau.
5. **Accès légal aux manuels officiels** — droits de reproduction et d'indexation.
6. **Qui achète réellement**, et sur quelle ligne budgétaire.

---

*Cahier des charges — version 1, 22 octobre 2026.*
