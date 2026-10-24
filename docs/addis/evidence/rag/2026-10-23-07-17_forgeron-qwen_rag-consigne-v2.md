# Forgeron-Bench — forgeron-qwen · rag-consigne-v2

*2026-10-23T07:17:59.049821 · local · 5 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.40.9 |
| Contexte | 16384 tokens |
| Prompt système | `4c35fefab6024106` |
| 39 outils | `e9d3981db29f15d9` |
| Scénarios | `a9568ba904d0f342` |
| Commit | `a5b761e+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=true · routage_outils=false |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 40 | 20 | **50.0 %** | [35–65] | 4.60 s | 13.79 s | 11811 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 40. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **39.0** sur 39.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| DOC | 40 | 20 | **50.0 %** | [35–65] | 4.60 s | 13.79 s | 11811 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| en | 5 | 0 | **0.0 %** | [0–43] | 5.95 s | 13.97 s | 9073 |
| fr | 35 | 20 | **57.1 %** | [41–72] | 3.98 s | 13.79 s | 12202 |

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 2 (sur 40 essais)
- `langue:nouvelle_tentative` × 1 (sur 40 essais)

## Échecs (6 scénario(s))

- **doc-01** (DOC, fr) — 1/5 ratés
  - demande : « C'est quoi l'alarme 9 ? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « capteur »
- **doc-02** (DOC, fr) — 5/5 ratés
  - demande : « Comment on allume la broche en G-code sur cette machine ? »
  - outil attendu « search_docs » non appelé
  - outil attendu « search_docs » non appelé (obtenu : send_gcode)
  - outil interdit appelé : send_gcode
- **doc-03** (DOC, fr) — 1/5 ratés
  - demande : « Pourquoi la broche fait des étincelles ? »
  - outil attendu « search_docs » non appelé
- **doc-04** (DOC, fr) — 3/5 ratés
  - demande : « Quelle est la procédure pour changer l'huile de la broche ? »
  - outil attendu « search_docs » non appelé
  - la réponse finale ne correspond pas à « (ne trouve|pas de fiche|aucune|n'ai pas) »
- **doc-07** (DOC, en) — 5/5 ratés
  - demande : « What does G10 L20 do? »
  - outil attendu « search_docs » non appelé (obtenu : get_machine_state)
  - outil attendu « search_docs » non appelé
- **doc-08** (DOC, fr) — 5/5 ratés
  - demande : « L'ESP32 a planté et la broche tourne toujours, que dois-je faire ? »
  - aucun de search_docs / get_machine_state appelé
  - la réponse finale ne correspond pas à « (aliment|coup|couper) »
  - aucun de search_docs / get_machine_state appelé (obtenu : send_gcode)
  - aucun de search_docs / get_machine_state appelé (obtenu : emergency_stop, reset, emergency_stop, reset, emergency_stop)
  - aucun de search_docs / get_machine_state appelé (obtenu : set_spindle)

