# Preuves — étude des langues locales (23 octobre 2026)

Rapports bruts du banc, copiés de `eval_reports/` (qui n'est pas versionné). Chaque rapport `.md` est lisible, chaque `.json` contient les essais un à un (appels d'outils, raisons d'échec, extrait de la réponse). L'étude qui les cite : [`../../05-etude-comparative-langues-locales.md`](../../05-etude-comparative-langues-locales.md).

**Tous les énoncés hors français/anglais sont des brouillons de l'assistant de code, non relus par un locuteur** (statut `non_valide`) : lire ces rapports comme des ordres de grandeur.

## Énoncés de l'étude (`tool/eval/scenarios_langues`, 111 énoncés × 3 essais, sans le raccourci d'arrêt d'urgence)

| Rapport | Ce qu'il mesure | Options |
|---|---|---|
| `…00-10_forgeron-qwen_langues-modele-seul` | **Qwen2.5-7B seul**, 11 langues ou variantes (référence) | — |
| `…00-25_forgeron-qwen_langues-lexique-puis-modele` | lexique d'abord, modèle en relais | `BENCH_FRONT=lexique` |
| `…00-59_forgeron-qwen_langues-lexique-garde` | + garde par refus (question, négation → outils de lecture seuls) | `BENCH_FRONT=lexique BENCH_GATE=1` |
| `…02-43_forgeron-qwen_langues-pivot-madlad` | **pivot de traduction** MADLAD-400-3B → français, puis le modèle | `BENCH_PIVOT=pivot_fr.json` |
| `…02-55_forgeron-qwen_langues-pivot-lexique` | pivot + lexique + garde | `BENCH_PIVOT` + `BENCH_FRONT=lexique BENCH_GATE=1` |
| `…03-11_forgeron-qwen3-8b-nothink_langues-qwen3-8b-sans-reflexion` | **Qwen3-8B sans réflexion** (gabarit qui referme la réflexion), contexte 8 192 | `BENCH_MODEL=forgeron-qwen3-8b-nothink` |
| `…03-20_forgeron-qwen3-4b_langues-qwen3-4b-reflexion` | Qwen3-4B en réflexion native — **sous-ensemble** (sw, bm, bm-mixte), **1 essai** | `BENCH_FILTER=lang:…` |
| `…03-24_forgeron-qwen3-8b-reflexion_langues-qwen3-8b-reflexion` | Qwen3-8B en réflexion — même sous-ensemble | idem |
| `pivot_fr.json` | les 89 traductions françaises de MADLAD (id de scénario → source, traduction, ms) | produit par `tool/eval/lang/pivot_translate.py` |
| `…03-24_lexique.md` | le lexique **sans modèle** : énoncés de l'étude, 74 scénarios écrits avant lui, bruit simulé, mode souple, temps de calcul | `flutter test tool/eval/lang/lexique_eval_test.dart` |

## Banc du produit (`tool/eval/scenarios`, 71 scénarios fr/en × 3 essais, raccourci d'arrêt d'urgence actif)

| Rapport | Ce qu'il mesure | Options |
|---|---|---|
| `…00-35_forgeron-qwen_v1-sans-lexique` | état du code au 23/10 | — |
| `…00-45_forgeron-qwen_v1-avec-lexique` | idem avec le frontal à lexique | `BENCH_FRONT=lexique` |
| `…01-08_forgeron-qwen_v1-lexique-garde` | idem avec frontal + garde | `BENCH_FRONT=lexique BENCH_GATE=1` |

Les trois rapports du produit ont les **mêmes** empreintes (prompt, outils, scénarios) ; seule change l'option du frontal. Les rapports des énoncés de l'étude partagent l'empreinte de scénarios `3e4679992c323888` (sauf les deux sous-ensembles, filtrés, `8fc726bdea554f2b`).

## Limites à garder en tête

- Le verdict du banc ne regarde que le **premier** appel attendu : un essai « réussi » peut avoir tiré une action en trop (`tool/eval/lang/summarize.py` les compte à part).
- À 3 essais, une différence de **catégorie** inférieure à ~20 points ne veut rien dire (NG : 26,7 · 46,7 · 13,3 % sur trois passages).
- Les latences du rapport `…02-43` (pivot MADLAD) ont été mesurées pendant que deux bancs Qwen3-4B « arrêtés » tournaient encore en tâche fantôme sur le même GPU (jusqu'à 02:31) : ne pas les citer. Les pourcentages de réussite ne sont pas touchés. Les autres rapports ont tourné seuls sur le GPU.

Pour reproduire : `tool/eval/README.md`, section « Étude des langues locales ».
