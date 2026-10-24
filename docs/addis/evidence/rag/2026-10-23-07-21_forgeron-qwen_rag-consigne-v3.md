# Forgeron-Bench — forgeron-qwen · rag-consigne-v3

*2026-10-23T07:21:15.847840 · local · 5 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.40.9 |
| Contexte | 16384 tokens |
| Prompt système | `b134c3d31a68f9a3` |
| 39 outils | `e9d3981db29f15d9` |
| Scénarios | `a9568ba904d0f342` |
| Commit | `a5b761e+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=true · routage_outils=false |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 40 | 25 | **62.5 %** | [47–76] | 2.87 s | 9.81 s | 12533 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 40. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **39.0** sur 39.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| DOC | 40 | 25 | **62.5 %** | [47–76] | 2.87 s | 9.81 s | 12533 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| en | 5 | 3 | **60.0 %** | [23–88] | 5.75 s | 7.67 s | 13468 |
| fr | 35 | 22 | **62.9 %** | [46–77] | 2.87 s | 10.01 s | 12400 |

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 2 (sur 40 essais)
- `langue:nouvelle_tentative` × 2 (sur 40 essais)

## Échecs (5 scénario(s))

- **doc-02** (DOC, fr) — 2/5 ratés
  - demande : « Comment on allume la broche en G-code sur cette machine ? »
  - outil attendu « search_docs » non appelé
- **doc-03** (DOC, fr) — 4/5 ratés
  - demande : « Pourquoi la broche fait des étincelles ? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « alimentation »
- **doc-04** (DOC, fr) — 3/5 ratés
  - demande : « Quelle est la procédure pour changer l'huile de la broche ? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « (ne trouve|pas de fiche|aucune|n'ai pas) »
- **doc-07** (DOC, en) — 2/5 ratés
  - demande : « What does G10 L20 do? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « (work|zero|origin) »
- **doc-08** (DOC, fr) — 4/5 ratés
  - demande : « L'ESP32 a planté et la broche tourne toujours, que dois-je faire ? »
  - aucun de search_docs / get_machine_state appelé (obtenu : emergency_stop)
  - aucun de search_docs / get_machine_state appelé (obtenu : emergency_stop, get_diagnostics, unlock_alarm, set_spindle)
  - la réponse finale ne correspond pas à « (aliment|coup|couper) »

