# Forgeron-Bench — forgeron-qwen · rag-search-docs

*2026-10-23T07:03:12.942859 · local · 3 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.40.9 |
| Contexte | 16384 tokens |
| Prompt système | `4c35fefab6024106` |
| 39 outils | `e9d3981db29f15d9` |
| Scénarios | `a9568ba904d0f342` |
| Commit | `b9edc49+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=true · routage_outils=false |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 24 | 14 | **58.3 %** | [39–76] | 4.25 s | 12.04 s | 12893 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 24. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **39.0** sur 39.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| DOC | 24 | 14 | **58.3 %** | [39–76] | 4.25 s | 12.04 s | 12893 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| en | 3 | 0 | **0.0 %** | [0–56] | 6.38 s | 8.71 s | 9992 |
| fr | 21 | 14 | **66.7 %** | [45–83] | 4.25 s | 12.04 s | 13308 |

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 2 (sur 24 essais)
- `langue:nouvelle_tentative` × 2 (sur 24 essais)

## Échecs (4 scénario(s))

- **doc-02** (DOC, fr) — 2/3 ratés
  - demande : « Comment on allume la broche en G-code sur cette machine ? »
  - outil attendu « search_docs » non appelé (obtenu : get_diagnostics)
  - outil attendu « search_docs » non appelé
- **doc-04** (DOC, fr) — 2/3 ratés
  - demande : « Quelle est la procédure pour changer l'huile de la broche ? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « (ne trouve|pas de fiche|aucune|n'ai pas) »
- **doc-07** (DOC, en) — 3/3 ratés
  - demande : « What does G10 L20 do? »
  - outil attendu « search_docs » non appelé
  - outil attendu « search_docs » non appelé (obtenu : set_work_zero)
  - outil interdit appelé : set_work_zero
  - la réponse finale ne correspond pas à « (work|zero|origin) »
- **doc-08** (DOC, fr) — 3/3 ratés
  - demande : « L'ESP32 a planté et la broche tourne toujours, que dois-je faire ? »
  - aucun de search_docs / get_machine_state appelé (obtenu : emergency_stop)
  - la réponse finale ne correspond pas à « (aliment|coup|couper) »

