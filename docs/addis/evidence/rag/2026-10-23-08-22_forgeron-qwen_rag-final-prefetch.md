# Forgeron-Bench — forgeron-qwen · rag-final-prefetch

*2026-10-23T08:22:06.369172 · local · 6 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.40.9 |
| Contexte | 16384 tokens |
| Prompt système | `aba57069762c49b7` |
| 40 outils | `2128446ac66fe03b` |
| Scénarios | `678e49fbe87a89d7` |
| Commit | `a5b761e+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=true · routage_outils=false · scenarios=tool/eval/scenarios_docs |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 60 | 54 | **90.0 %** | [80–95] | 3.76 s | 15.51 s | 10396 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 60. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **39.1** sur 40.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| DOC | 60 | 54 | **90.0 %** | [80–95] | 3.76 s | 15.51 s | 10396 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| en | 6 | 6 | **100.0 %** | [61–100] | 3.38 s | 5.71 s | 7533 |
| fr | 54 | 48 | **88.9 %** | [78–95] | 3.76 s | 16.72 s | 10714 |

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 1 (sur 60 essais)
- `langue:nouvelle_tentative` × 5 (sur 60 essais)

## Échecs (4 scénario(s))

- **pf-03** (DOC, fr) — 3/6 ratés
  - demande : « Pourquoi la broche fait des étincelles ? »
  - la réponse finale ne correspond pas à « alimentation »
- **pf-06** (DOC, fr) — 1/6 ratés
  - demande : « Merci, c'est tout pour aujourd'hui. »
  - outil appelé alors qu'aucun n'était attendu : reset({})
- **pf-08** (DOC, fr) — 1/6 ratés
  - demande : « L'ESP32 a planté et la broche tourne toujours, que dois-je faire ? »
  - la réponse finale ne correspond pas à « (aliment|coup|couper) »
- **pf-09** (DOC, fr) — 1/6 ratés
  - demande : « Pourquoi l'axe X ne se comporte pas comme Y pour les pas par millimètre ? »
  - la réponse finale ne correspond pas à « (3 mm|pas de 3|vis) »

