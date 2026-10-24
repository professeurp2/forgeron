# Forgeron-Bench — forgeron-qwen · rag-prefetch

*2026-10-23T07:25:37.093377 · local · 5 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.40.9 |
| Contexte | 16384 tokens |
| Prompt système | `b134c3d31a68f9a3` |
| 39 outils | `e9d3981db29f15d9` |
| Scénarios | `0ffdf258fa86fb2a` |
| Commit | `a5b761e+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=true · routage_outils=false · scenarios=tool/eval/scenarios_docs |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 50 | 31 | **62.0 %** | [48–74] | 2.77 s | 8.41 s | 11458 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 50. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **39.0** sur 39.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| DOC | 50 | 31 | **62.0 %** | [48–74] | 2.77 s | 8.41 s | 11458 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| en | 5 | 1 | **20.0 %** | [4–62] | 3.03 s | 4.17 s | 9152 |
| fr | 45 | 30 | **66.7 %** | [52–79] | 2.77 s | 8.41 s | 11714 |

## Garde-fous déclenchés

- `langue:nouvelle_tentative` × 2 (sur 50 essais)

## Échecs (7 scénario(s))

- **pf-01** (DOC, fr) — 3/5 ratés
  - demande : « C'est quoi l'alarme 9 ? »
  - la réponse finale ne correspond pas à « capteur »
- **pf-02** (DOC, fr) — 2/5 ratés
  - demande : « Comment on allume la broche en G-code sur cette machine ? »
  - la réponse finale ne correspond pas à « M3 S\d+ »
- **pf-03** (DOC, fr) — 1/5 ratés
  - demande : « Pourquoi la broche fait des étincelles ? »
  - la réponse finale ne correspond pas à « alimentation »
- **pf-04** (DOC, fr) — 4/5 ratés
  - demande : « Quelle est la procédure pour changer l'huile de la broche ? »
  - la réponse contient « (litre|millilitre| ml |vidange tous|étape 1|1\.) »
- **pf-07** (DOC, en) — 4/5 ratés
  - demande : « What does G10 L20 do? »
  - la réponse finale ne correspond pas à « (work|zero|origin) »
- **pf-08** (DOC, fr) — 2/5 ratés
  - demande : « L'ESP32 a planté et la broche tourne toujours, que dois-je faire ? »
  - la réponse finale ne correspond pas à « (aliment|coup|couper) »
- **pf-09** (DOC, fr) — 3/5 ratés
  - demande : « Pourquoi l'axe X ne se comporte pas comme Y pour les pas par millimètre ? »
  - la réponse finale ne correspond pas à « (3 mm|pas de 3|vis) »

