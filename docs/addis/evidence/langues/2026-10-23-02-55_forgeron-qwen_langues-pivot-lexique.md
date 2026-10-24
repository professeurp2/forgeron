# Forgeron-Bench — forgeron-qwen · langues-pivot-lexique

*2026-10-23T02:55:58.860371 · local · 3 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen` (empreinte `fa1d9250af60`) |
| Serveur | Ollama 0.34.2 |
| Contexte | 16384 tokens |
| Prompt système | `855ed8d8138e2a7a` |
| 38 outils | `96c7b6fbf64b7d59` |
| Scénarios | `3e4679992c323888` |
| Commit | `52e53ef+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=false · routage_outils=false · frontal_lexique=true · garde_refus_lexique=true · pivot_traduction=C:/Users/CITTUN~1/AppData/Local/Temp/claude/C--Users-CITT-Unipod-Documents-ENI-Mon-PFE-forgeron--claude-worktrees-new-ai-model-branch-5cbd5c/8cbeeab8-3435-4248-a058-8d9cd1745639/scratchpad/pivot_fr.json · scenarios=tool/eval/scenarios_langues |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 66 | 59 | **89.4 %** | [80–95] | 0.00 s | 4.03 s | 2381 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 333. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **34.8** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| LGX | 66 | 59 | **89.4 %** | [80–95] | 0.00 s | 4.03 s | 2381 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| am (non validé) | 30 | 25 | **83.3 %** | [66–93] | 0.74 s | 7.83 s | 4503 |
| ar (non validé) | 30 | 20 | **66.7 %** | [49–81] | 1.80 s | 6.11 s | 4625 |
| bm (non validé) | 33 | 15 | **45.5 %** | [30–62] | 1.76 s | 10.52 s | 7108 |
| bm-ascii (non validé) | 24 | 12 | **50.0 %** | [31–69] | 1.71 s | 4.32 s | 5673 |
| bm-mixte (non validé) | 30 | 30 | **100.0 %** | [89–100] | 0.00 s | 9.07 s | 1243 |
| en | 33 | 30 | **90.9 %** | [76–97] | 0.00 s | 3.43 s | 2520 |
| fr | 33 | 29 | **87.9 %** | [73–95] | 0.00 s | 4.72 s | 2242 |
| ha (non validé) | 30 | 17 | **56.7 %** | [39–73] | 1.58 s | 6.57 s | 5645 |
| sw (non validé) | 30 | 14 | **46.7 %** | [30–64] | 2.34 s | 6.61 s | 5277 |
| wo (non validé) | 30 | 6 | **20.0 %** | [10–37] | 2.87 s | 6.11 s | 7215 |
| yo (non validé) | 30 | 13 | **43.3 %** | [27–61] | 2.90 s | 6.26 s | 6082 |

> Les langues « non validé » n'ont pas de relecteur natif : les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 4 (sur 333 essais)
- `frontal_lexique:brocheoff` × 12 (sur 333 essais)
- `frontal_lexique:brocheon` × 12 (sur 333 essais)
- `frontal_lexique:etat` × 18 (sur 333 essais)
- `frontal_lexique:homing` × 3 (sur 333 essais)
- `frontal_lexique:jog` × 27 (sur 333 essais)
- `frontal_lexique:pause` × 6 (sur 333 essais)
- `frontal_lexique:urgence` × 15 (sur 333 essais)
- `frontal_lexique:zero` × 9 (sur 333 essais)
- `langue:nouvelle_tentative` × 14 (sur 333 essais)

## Échecs (47 scénario(s))

- **lgx-am-brocheon** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አብራ። »
  - outil attendu « set_spindle » non appelé (obtenu : home)
  - outil attendu « set_spindle » non appelé
- **lgx-am-homing** (LGX, am) — 2/3 ratés
  - demande : « ማሽኑን ወደ መነሻ ቦታው መልሰው። »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-ar-brocheoff** (LGX, ar) — 2/3 ratés
  - demande : « أطفئ المغزل. »
  - outil attendu « set_spindle » non appelé
- **lgx-ar-brocheon** (LGX, ar) — 3/3 ratés
  - demande : « شغّل المغزل. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
  - outil attendu « set_spindle » non appelé
- **lgx-ar-homing** (LGX, ar) — 1/3 ratés
  - demande : « أعد الآلة إلى موضع البداية. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-ar-pause** (LGX, ar) — 3/3 ratés
  - demande : « أوقف البرنامج مؤقتاً. »
  - outil attendu « pause » non appelé (obtenu : get_activity_log)
  - outil attendu « pause » non appelé
- **lgx-ar-zero** (LGX, ar) — 1/3 ratés
  - demande : « اضبط صفر القطعة هنا. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_activity_log)
- **lgx-bm-brocheon** (LGX, bm) — 3/3 ratés
  - demande : « Broche daminɛ. »
  - outil attendu « set_spindle » non appelé (obtenu : jog_axis)
  - outil attendu « set_spindle » non appelé
- **lgx-bm-etat** (LGX, bm) — 3/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bm-homing** (LGX, bm) — 3/3 ratés
  - demande : « Mashini segin a daminɛ yɔrɔ la. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-bm-pause** (LGX, bm) — 3/3 ratés
  - demande : « Porogaramu jɔ dɔɔnin. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
- **lgx-bm-urgence** (LGX, bm) — 3/3 ratés
  - demande : « Mashini jɔ sisan, joona! »
  - outil attendu « emergency_stop » non appelé
- **lgx-bm-zero** (LGX, bm) — 3/3 ratés
  - demande : « Zero in da yan. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_activity_log, get_diagnostics)
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé
- **lgx-bma-etat** (LGX, bm-ascii) — 2/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bma-homing** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini segin a damine yoro la. »
  - outil attendu « home » non appelé
- **lgx-bma-jogmots** (LGX, bm-ascii) — 2/3 ratés
  - demande : « X taa milimetri duuru la, teliya keme saba. »
  - jog_axis.distance = 0.005, attendu 5
  - jog_axis.feedrate = 3, attendu 300
- **lgx-bma-pause** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Porogaramu jo doonin. »
  - outil attendu « pause » non appelé
- **lgx-bma-urgence** (LGX, bm-ascii) — 2/3 ratés
  - demande : « Mashini jo sisan, joona! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - outil attendu « emergency_stop » non appelé
- **lgx-en-homing** (LGX, en) — 3/3 ratés
  - demande : « Send the machine back to its starting position. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé
- **lgx-fr-homing** (LGX, fr) — 3/3 ratés
  - demande : « Ramène la machine à sa position de départ. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-fr-pause** (LGX, fr) — 1/3 ratés
  - demande : « Mets le programme en pause un moment. »
  - outil attendu « pause » non appelé
- **lgx-ha-brocheoff** (LGX, ha) — 3/3 ratés
  - demande : « Kashe spindle. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-ha-brocheon** (LGX, ha) — 3/3 ratés
  - demande : « Kunna spindle. »
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé (obtenu : run_gcode_program)
  - outil attendu « set_spindle » non appelé
- **lgx-ha-homing** (LGX, ha) — 1/3 ratés
  - demande : « Mayar da na'urar zuwa matsayinta na farko. »
  - outil attendu « home » non appelé (obtenu : send_gcode)
- **lgx-ha-pause** (LGX, ha) — 3/3 ratés
  - demande : « Dakatar da shirin na ɗan lokaci. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
- **lgx-ha-zero** (LGX, ha) — 3/3 ratés
  - demande : « Saita sifilin aiki a nan. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé (obtenu : set_feed_override, set_spindle_override)
- **lgx-sw-brocheoff** (LGX, sw) — 3/3 ratés
  - demande : « Zima spindle. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-sw-brocheon** (LGX, sw) — 3/3 ratés
  - demande : « Washa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-homing** (LGX, sw) — 2/3 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé (obtenu : get_axis_kinematics)
- **lgx-sw-pause** (LGX, sw) — 3/3 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
- **lgx-sw-urgence** (LGX, sw) — 3/3 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé
  - outil attendu « emergency_stop » non appelé (obtenu : jog_axis)
- **lgx-sw-zero** (LGX, sw) — 2/3 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé
- **lgx-wo-brocheoff** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal broche bi. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : send_gcode)
- **lgx-wo-brocheon** (LGX, wo) — 3/3 ratés
  - demande : « Tambali broche bi. »
  - outil attendu « set_spindle » non appelé
- **lgx-wo-etat** (LGX, wo) — 2/3 ratés
  - demande : « Wone ma ni machine bi nekk. »
  - outil attendu « get_machine_state » non appelé
- **lgx-wo-homing** (LGX, wo) — 3/3 ratés
  - demande : « Delloo machine bi ci béréb bi mu tambalee. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-wo-horssujet** (LGX, wo) — 1/3 ratés
  - demande : « Taw dina ñëw ëllëg? »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-wo-jog** (LGX, wo) — 3/3 ratés
  - demande : « Dox axe X ci 5 mm ak gaaw 300. »
  - outil attendu « jog_axis » non appelé
  - outil attendu « jog_axis » non appelé (obtenu : set_feed_override)
- **lgx-wo-pause** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal programme bi ba ab diir. »
  - outil attendu « pause » non appelé (obtenu : get_activity_log)
  - outil attendu « pause » non appelé
- **lgx-wo-urgence** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal machine bi léegi, gaaw! »
  - outil attendu « emergency_stop » non appelé
- **lgx-wo-zero** (LGX, wo) — 3/3 ratés
  - demande : « Teg zéro bi fii. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : home)
- **lgx-yo-brocheoff** (LGX, yo) — 3/3 ratés
  - demande : « Pa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-brocheon** (LGX, yo) — 3/3 ratés
  - demande : « Tan spindle. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-yo-homing** (LGX, yo) — 2/3 ratés
  - demande : « Mú ẹrọ naa pada si ibi ti o ti bẹrẹ. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-yo-pause** (LGX, yo) — 3/3 ratés
  - demande : « Dá eto naa dúró fún ìgbà díẹ̀. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
- **lgx-yo-urgence** (LGX, yo) — 3/3 ratés
  - demande : « Duro ẹrọ naa lẹsẹkẹsẹ, pajawiri ni! »
  - outil attendu « emergency_stop » non appelé
- **lgx-yo-zero** (LGX, yo) — 3/3 ratés
  - demande : « Fi odo iṣẹ si ibi yii. »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : list_workspace_files, read_workspace_file, write_workspace_file)

