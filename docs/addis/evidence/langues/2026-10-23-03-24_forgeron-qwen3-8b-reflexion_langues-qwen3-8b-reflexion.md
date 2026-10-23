# Forgeron-Bench — forgeron-qwen3-8b-reflexion · langues-qwen3-8b-reflexion

*2026-10-23T03:24:01.557495 · local · 1 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen3-8b-reflexion` (empreinte `75b2aaf62291`) |
| Serveur | Ollama 0.34.2 |
| Contexte | 8192 tokens |
| Prompt système | `855ed8d8138e2a7a` |
| 38 outils | `96c7b6fbf64b7d59` |
| Scénarios | `8fc726bdea554f2b` |
| Commit | `52e53ef+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=false · routage_outils=false · scenarios=tool/eval/scenarios_langues |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 0 | 0 | **0.0 %** | [0–100] | — | — | 0 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 31. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **0.0** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| bm (non validé) | 11 | 4 | **36.4 %** | [15–65] | 7.47 s | 11.54 s | 7121 |
| bm-mixte (non validé) | 10 | 9 | **90.0 %** | [60–98] | 3.90 s | 8.78 s | 7041 |
| sw (non validé) | 10 | 5 | **50.0 %** | [24–76] | 7.89 s | 19.98 s | 7206 |

> Les langues « non validé » n'ont pas de relecteur natif : les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.

## Garde-fous déclenchés

Aucun : toutes les réponses sont arrivées telles quelles.

## Échecs (13 scénario(s))

- **lgx-bm-brocheoff** (LGX, bm) — 1/1 ratés
  - demande : « Broche dabila. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
- **lgx-bm-brocheon** (LGX, bm) — 1/1 ratés
  - demande : « Broche daminɛ. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
- **lgx-bm-explique** (LGX, bm) — 1/1 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye ni kuma nɔgɔman ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
  - la réponse finale ne correspond pas à « .{30,} »
- **lgx-bm-homing** (LGX, bm) — 1/1 ratés
  - demande : « Mashini segin a daminɛ yɔrɔ la. »
  - outil attendu « home » non appelé
- **lgx-bm-jogmots** (LGX, bm) — 1/1 ratés
  - demande : « X taa milimɛtɛri duuru la, teliya kɛmɛ saba. »
  - outil attendu « jog_axis » non appelé (obtenu : get_machine_state)
- **lgx-bm-pause** (LGX, bm) — 1/1 ratés
  - demande : « Porogaramu jɔ dɔɔnin. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
- **lgx-bm-urgence** (LGX, bm) — 1/1 ratés
  - demande : « Mashini jɔ sisan, joona! »
  - outil attendu « emergency_stop » non appelé
- **lgx-bmx-explique** (LGX, bm-mixte) — 1/1 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
  - la réponse finale ne correspond pas à « .{30,} »
- **lgx-sw-brocheoff** (LGX, sw) — 1/1 ratés
  - demande : « Zima spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-homing** (LGX, sw) — 1/1 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-sw-pause** (LGX, sw) — 1/1 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé (obtenu : set_feed_override)
- **lgx-sw-urgence** (LGX, sw) — 1/1 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
- **lgx-sw-zero** (LGX, sw) — 1/1 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)

