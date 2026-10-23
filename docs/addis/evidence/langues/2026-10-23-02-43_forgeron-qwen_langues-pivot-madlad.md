# Forgeron-Bench — forgeron-qwen · langues-pivot-madlad

*2026-10-23T02:43:55.271301 · local · 3 essai(s) par scénario*

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
| Options | chemin_rapide_arret_urgence=false · routage_outils=false · pivot_traduction=C:/Users/CITTUN~1/AppData/Local/Temp/claude/C--Users-CITT-Unipod-Documents-ENI-Mon-PFE-forgeron--claude-worktrees-new-ai-model-branch-5cbd5c/8cbeeab8-3435-4248-a058-8d9cd1745639/scratchpad/pivot_fr.json · scenarios=tool/eval/scenarios_langues |

**Énergie (GPU)** : moyenne 89 W · pic 91 W · 23.78 Wh pour 333 requêtes (7.14 Wh pour 100) · mémoire max 5375 Mo.

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 66 | 55 | **83.3 %** | [73–90] | 0.69 s | 3.96 s | 6771 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 333. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **38.0** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| LGX | 66 | 55 | **83.3 %** | [73–90] | 0.69 s | 3.96 s | 6771 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| am (non validé) | 30 | 23 | **76.7 %** | [59–88] | 1.09 s | 8.47 s | 6936 |
| ar (non validé) | 30 | 17 | **56.7 %** | [39–73] | 1.93 s | 5.89 s | 6939 |
| bm (non validé) | 33 | 15 | **45.5 %** | [30–62] | 1.61 s | 7.24 s | 7170 |
| bm-ascii (non validé) | 24 | 9 | **37.5 %** | [21–57] | 1.86 s | 9.48 s | 7256 |
| bm-mixte (non validé) | 30 | 19 | **63.3 %** | [46–78] | 1.74 s | 7.98 s | 7184 |
| en | 33 | 29 | **87.9 %** | [73–95] | 0.67 s | 2.83 s | 6868 |
| fr | 33 | 26 | **78.8 %** | [62–89] | 0.76 s | 46.47 s | 6675 |
| ha (non validé) | 30 | 18 | **60.0 %** | [42–75] | 1.48 s | 5.34 s | 7393 |
| sw (non validé) | 30 | 17 | **56.7 %** | [39–73] | 1.93 s | 4.65 s | 6941 |
| wo (non validé) | 30 | 7 | **23.3 %** | [12–41] | 2.32 s | 4.55 s | 6956 |
| yo (non validé) | 30 | 16 | **53.3 %** | [36–70] | 2.50 s | 7.89 s | 7203 |

> Les langues « non validé » n'ont pas de relecteur natif : les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 5 (sur 333 essais)
- `langue:nouvelle_tentative` × 6 (sur 333 essais)

## Échecs (62 scénario(s))

- **lgx-am-brocheoff** (LGX, am) — 1/3 ratés
  - demande : « ስፒንድሉን አጥፋ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-brocheon** (LGX, am) — 1/3 ratés
  - demande : « ስፒንድሉን አብራ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-etat** (LGX, am) — 2/3 ratés
  - demande : « የማሽኑን ሁኔታ አሳየኝ። »
  - outil attendu « get_machine_state » non appelé
- **lgx-am-homing** (LGX, am) — 2/3 ratés
  - demande : « ማሽኑን ወደ መነሻ ቦታው መልሰው። »
  - outil attendu « home » non appelé (obtenu : get_activity_log)
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-am-zero** (LGX, am) — 1/3 ratés
  - demande : « የስራ ዜሮን እዚህ አስቀምጥ። »
  - outil attendu « set_work_zero » non appelé (obtenu : home)
- **lgx-ar-brocheoff** (LGX, ar) — 2/3 ratés
  - demande : « أطفئ المغزل. »
  - outil attendu « set_spindle » non appelé (obtenu : send_gcode)
  - outil attendu « set_spindle » non appelé
- **lgx-ar-brocheon** (LGX, ar) — 3/3 ratés
  - demande : « شغّل المغزل. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_wcs_offsets)
- **lgx-ar-homing** (LGX, ar) — 3/3 ratés
  - demande : « أعد الآلة إلى موضع البداية. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé
- **lgx-ar-pause** (LGX, ar) — 3/3 ratés
  - demande : « أوقف البرنامج مؤقتاً. »
  - outil attendu « pause » non appelé (obtenu : get_diagnostics)
  - outil attendu « pause » non appelé
- **lgx-ar-urgence** (LGX, ar) — 1/3 ratés
  - demande : « أوقف الآلة فوراً، إنها حالة طوارئ! »
  - outil attendu « emergency_stop » non appelé
- **lgx-ar-zero** (LGX, ar) — 1/3 ratés
  - demande : « اضبط صفر القطعة هنا. »
  - outil attendu « set_work_zero » non appelé
- **lgx-bm-brocheoff** (LGX, bm) — 3/3 ratés
  - demande : « Broche dabila. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-bm-brocheon** (LGX, bm) — 3/3 ratés
  - demande : « Broche daminɛ. »
  - outil attendu « set_spindle » non appelé
- **lgx-bm-etat** (LGX, bm) — 2/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bm-homing** (LGX, bm) — 3/3 ratés
  - demande : « Mashini segin a daminɛ yɔrɔ la. »
  - outil attendu « home » non appelé
- **lgx-bm-pause** (LGX, bm) — 3/3 ratés
  - demande : « Porogaramu jɔ dɔɔnin. »
  - outil attendu « pause » non appelé
- **lgx-bm-urgence** (LGX, bm) — 3/3 ratés
  - demande : « Mashini jɔ sisan, joona! »
  - outil attendu « emergency_stop » non appelé
- **lgx-bm-zero** (LGX, bm) — 1/3 ratés
  - demande : « Zero in da yan. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-bma-brocheon** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Broche damine. »
  - outil attendu « set_spindle » non appelé
- **lgx-bma-etat** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bma-homing** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini segin a damine yoro la. »
  - outil attendu « home » non appelé
- **lgx-bma-pause** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Porogaramu jo doonin. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state, get_activity_log)
- **lgx-bma-urgence** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini jo sisan, joona! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - outil attendu « emergency_stop » non appelé
- **lgx-bmx-brocheoff** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Broche éteindre sisan. »
  - outil attendu « set_spindle » non appelé
- **lgx-bmx-brocheon** (LGX, bm-mixte) — 2/3 ratés
  - demande : « Broche allumer sisan. »
  - outil attendu « set_spindle » non appelé
- **lgx-bmx-etat** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Mashini état jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bmx-explique** (LGX, bm-mixte) — 2/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye. »
  - outil appelé alors qu'aucun n'était attendu : home({})
  - outil appelé alors qu'aucun n'était attendu : get_diagnostics({})
- **lgx-bmx-homing** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Homing kɛ. »
  - outil attendu « home » non appelé
- **lgx-bmx-jog** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Axe X taa 5 mm la, vitesse 300. »
  - outil attendu « jog_axis » non appelé
- **lgx-bmx-zero** (LGX, bm-mixte) — 3/3 ratés
  - demande : « Zéro pièce da yan. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé
- **lgx-en-homing** (LGX, en) — 3/3 ratés
  - demande : « Send the machine back to its starting position. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé (obtenu : get_activity_log)
- **lgx-en-zero** (LGX, en) — 1/3 ratés
  - demande : « Set the work zero here. »
  - outil attendu « set_work_zero » non appelé
- **lgx-fr-brocheon** (LGX, fr) — 1/3 ratés
  - demande : « Allume la broche. »
  - outil attendu « set_spindle » non appelé
- **lgx-fr-etat** (LGX, fr) — 1/3 ratés
  - demande : « Montre-moi l'état de la machine. »
  - erreur : TimeoutException after 0:03:00.000000: Future not completed
  - outil attendu « get_machine_state » non appelé
- **lgx-fr-homing** (LGX, fr) — 2/3 ratés
  - demande : « Ramène la machine à sa position de départ. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-fr-zero** (LGX, fr) — 3/3 ratés
  - demande : « Pose le zéro pièce ici. »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : home)
- **lgx-ha-brocheoff** (LGX, ha) — 3/3 ratés
  - demande : « Kashe spindle. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-ha-brocheon** (LGX, ha) — 3/3 ratés
  - demande : « Kunna spindle. »
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
- **lgx-ha-homing** (LGX, ha) — 1/3 ratés
  - demande : « Mayar da na'urar zuwa matsayinta na farko. »
  - outil attendu « home » non appelé
- **lgx-ha-pause** (LGX, ha) — 3/3 ratés
  - demande : « Dakatar da shirin na ɗan lokaci. »
  - outil attendu « pause » non appelé
- **lgx-ha-zero** (LGX, ha) — 2/3 ratés
  - demande : « Saita sifilin aiki a nan. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé
- **lgx-sw-brocheoff** (LGX, sw) — 3/3 ratés
  - demande : « Zima spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-brocheon** (LGX, sw) — 2/3 ratés
  - demande : « Washa spindle. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : send_gcode)
- **lgx-sw-homing** (LGX, sw) — 1/3 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé (obtenu : send_gcode)
- **lgx-sw-pause** (LGX, sw) — 3/3 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
- **lgx-sw-urgence** (LGX, sw) — 3/3 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé
  - outil attendu « emergency_stop » non appelé (obtenu : get_activity_log)
- **lgx-sw-zero** (LGX, sw) — 1/3 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-wo-brocheoff** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal broche bi. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-wo-brocheon** (LGX, wo) — 3/3 ratés
  - demande : « Tambali broche bi. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-wo-etat** (LGX, wo) — 1/3 ratés
  - demande : « Wone ma ni machine bi nekk. »
  - outil attendu « get_machine_state » non appelé
- **lgx-wo-explique** (LGX, wo) — 3/3 ratés
  - demande : « Wax ma ci wax yu yomb lan la homing. »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
- **lgx-wo-homing** (LGX, wo) — 3/3 ratés
  - demande : « Delloo machine bi ci béréb bi mu tambalee. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-wo-jog** (LGX, wo) — 1/3 ratés
  - demande : « Dox axe X ci 5 mm ak gaaw 300. »
  - outil attendu « jog_axis » non appelé
- **lgx-wo-pause** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal programme bi ba ab diir. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : list_workspace_files)
- **lgx-wo-urgence** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal machine bi léegi, gaaw! »
  - outil attendu « emergency_stop » non appelé
- **lgx-wo-zero** (LGX, wo) — 3/3 ratés
  - demande : « Teg zéro bi fii. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé
- **lgx-yo-brocheoff** (LGX, yo) — 3/3 ratés
  - demande : « Pa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-brocheon** (LGX, yo) — 2/3 ratés
  - demande : « Tan spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-etat** (LGX, yo) — 2/3 ratés
  - demande : « Fi ipo ẹrọ naa han mi. »
  - outil attendu « get_machine_state » non appelé
- **lgx-yo-homing** (LGX, yo) — 1/3 ratés
  - demande : « Mú ẹrọ naa pada si ibi ti o ti bẹrẹ. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-yo-pause** (LGX, yo) — 3/3 ratés
  - demande : « Dá eto naa dúró fún ìgbà díẹ̀. »
  - outil attendu « pause » non appelé (obtenu : list_workspace_files)
  - outil attendu « pause » non appelé (obtenu : get_machine_state, get_diagnostics)
  - outil attendu « pause » non appelé
- **lgx-yo-zero** (LGX, yo) — 3/3 ratés
  - demande : « Fi odo iṣẹ si ibi yii. »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : read_workspace_file)

