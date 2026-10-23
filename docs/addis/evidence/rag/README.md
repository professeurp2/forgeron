# Mesures du RAG minimal (search_docs) — forgeron-qwen, 23 octobre 2026

Scénarios `DOC` (8, puis 10 en mode récupération préalable). Chaque ligne = un banc complet.

| Rapport | Mode | Réussis |
|---|---|---|
| `rag-search-docs` (1re série) | outil seul, consigne au milieu du prompt, 1 tour | 7/24 (29 %) — 1 tour : la réponse finale n'était jamais lue (scénarios à corriger : `max_turns`) |
| `rag-search-docs` (2e série) | outil seul, 3 tours | 14/24 (58 %) |
| `rag-consigne-v2` | outil seul, 5 répétitions | 20/40 (50 %) |
| `rag-consigne-v3` | outil seul, consigne durcie en fin de prompt | 25/40 (62,5 %) |
| `rag-prefetch` | **récupération préalable** (l'application cherche et met les fiches dans le prompt) | 31/50 (62 %) — le banc ne simulait pas l'outil |
| `rag-final-prefetch` | récupération préalable, prompt final, 6 répétitions | **54/60 (90 %, IC95 80–95)** |

Entre les deux, des séries intermédiaires (non conservées) ont donné 76 à 84 % avec des variantes de l'« anti-hésitation » : le bruit d'une série à l'autre est d'environ ±7 points, donc **90 % est la meilleure mesure, pas une garantie**.

Ce que la mesure a appris :
- Le modèle local n'appelle pas l'outil de lui-même de façon fiable (1 à 3 fois sur 5 selon la question) et invente alors une procédure : d'où la récupération préalable.
- Le modèle écrit « Je ne trouve pas… » puis enchaîne « Cependant… » avec sa mémoire : la réponse est ramenée au refus quand elle ne cite aucune fiche (`enforceNoFicheReply`).
- Scénarios et prompt/outils changent l'empreinte de la version IA : aucune version n'est promue (`ai_release.json` absent).
- La charge utile du prompt (7 477 tokens sur 7 500) est à la limite : toute nouvelle consigne devra en retirer une autre.
