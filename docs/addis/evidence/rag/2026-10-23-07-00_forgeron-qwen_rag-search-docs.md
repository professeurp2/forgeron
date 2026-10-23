# Forgeron-Bench — forgeron-qwen · rag-search-docs

*2026-10-23T07:00:45.105790 · local · 3 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.40.9 |
| Contexte | 16384 tokens |
| Prompt système | `4c35fefab6024106` |
| 39 outils | `e9d3981db29f15d9` |
| Scénarios | `b469a1a63ea1511e` |
| Commit | `b9edc49+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=true · routage_outils=false |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 24 | 7 | **29.2 %** | [15–49] | 1.10 s | 8.16 s | 7602 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 24. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **39.0** sur 39.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| DOC | 24 | 7 | **29.2 %** | [15–49] | 1.10 s | 8.16 s | 7602 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| en | 3 | 0 | **0.0 %** | [0–56] | 5.58 s | 6.29 s | 7459 |
| fr | 21 | 7 | **33.3 %** | [17–55] | 0.93 s | 8.16 s | 7623 |

## Garde-fous déclenchés

- `langue:nouvelle_tentative` × 1 (sur 24 essais)

## Échecs (6 scénario(s))

- **doc-01** (DOC, fr) — 3/3 ratés
  - demande : « C'est quoi l'alarme 9 ? »
  - la réponse finale ne correspond pas à « capteur »
- **doc-02** (DOC, fr) — 2/3 ratés
  - demande : « Comment on allume la broche en G-code sur cette machine ? »
  - outil attendu « search_docs » non appelé (obtenu : get_config)
  - outil attendu « search_docs » non appelé
- **doc-03** (DOC, fr) — 3/3 ratés
  - demande : « Pourquoi la broche fait des étincelles ? »
  - la réponse finale ne correspond pas à « alimentation »
- **doc-04** (DOC, fr) — 3/3 ratés
  - demande : « Quelle est la procédure pour changer l'huile de la broche ? »
  - la réponse finale ne correspond pas à « (ne trouve|pas de fiche|aucune|n'ai pas) »
  - outil attendu « search_docs » non appelé
- **doc-07** (DOC, en) — 3/3 ratés
  - demande : « What does G10 L20 do? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « (work|zero|origin) »
- **doc-08** (DOC, fr) — 3/3 ratés
  - demande : « L'ESP32 a planté et la broche tourne toujours, que dois-je faire ? »
  - aucun de search_docs / get_machine_state appelé (obtenu : emergency_stop)
  - la réponse finale ne correspond pas à « (aliment|coup|couper) »
  - aucun de search_docs / get_machine_state appelé (obtenu : get_diagnostics, emergency_stop)

