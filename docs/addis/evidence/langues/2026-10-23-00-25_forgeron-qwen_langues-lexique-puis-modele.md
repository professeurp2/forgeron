# Forgeron-Bench — forgeron-qwen · langues-lexique-puis-modele

*2026-10-23T00:25:48.675737 · local · 3 essai(s) par scénario*

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
| Options | chemin_rapide_arret_urgence=false · routage_outils=false · frontal_lexique=true · scenarios=tool/eval/scenarios_langues |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 66 | 62 | **93.9 %** | [85–98] | 0.00 s | 4.02 s | 2525 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 333. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **38.0** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| LGX | 66 | 62 | **93.9 %** | [85–98] | 0.00 s | 4.02 s | 2525 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| am (non validé) | 30 | 9 | **30.0 %** | [17–48] | 1.27 s | 3.98 s | 6921 |
| ar (non validé) | 30 | 26 | **86.7 %** | [70–95] | 0.83 s | 4.37 s | 7358 |
| bm (non validé) | 33 | 32 | **97.0 %** | [85–99] | 0.00 s | 2.79 s | 1261 |
| bm-ascii (non validé) | 24 | 21 | **87.5 %** | [69–96] | 0.00 s | 2.38 s | 1732 |
| bm-mixte (non validé) | 30 | 29 | **96.7 %** | [83–99] | 0.00 s | 2.34 s | 1384 |
| en | 33 | 31 | **93.9 %** | [80–98] | 0.00 s | 3.11 s | 2524 |
| fr | 33 | 31 | **93.9 %** | [80–98] | 0.00 s | 4.28 s | 2526 |
| ha (non validé) | 30 | 5 | **16.7 %** | [7–34] | 1.61 s | 6.62 s | 6957 |
| sw (non validé) | 30 | 14 | **46.7 %** | [30–64] | 2.69 s | 7.93 s | 7020 |
| wo (non validé) | 30 | 10 | **33.3 %** | [19–51] | 1.88 s | 4.23 s | 7161 |
| yo (non validé) | 30 | 12 | **40.0 %** | [25–58] | 1.00 s | 3.35 s | 7340 |

> Les langues « non validé » n'ont pas de relecteur natif : les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 3 (sur 333 essais)
- `frontal_lexique:brocheoff` × 12 (sur 333 essais)
- `frontal_lexique:brocheon` × 15 (sur 333 essais)
- `frontal_lexique:etat` × 15 (sur 333 essais)
- `frontal_lexique:homing` × 9 (sur 333 essais)
- `frontal_lexique:jog` × 24 (sur 333 essais)
- `frontal_lexique:pause` × 9 (sur 333 essais)
- `frontal_lexique:urgence` × 15 (sur 333 essais)
- `frontal_lexique:zero` × 12 (sur 333 essais)
- `langue:nouvelle_tentative` × 5 (sur 333 essais)

## Échecs (46 scénario(s))

- **lgx-am-brocheoff** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አጥፋ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-brocheon** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አብራ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-etat** (LGX, am) — 1/3 ratés
  - demande : « የማሽኑን ሁኔታ አሳየኝ። »
  - outil attendu « get_machine_state » non appelé
- **lgx-am-homing** (LGX, am) — 3/3 ratés
  - demande : « ማሽኑን ወደ መነሻ ቦታው መልሰው። »
  - outil attendu « home » non appelé
- **lgx-am-horssujet** (LGX, am) — 2/3 ratés
  - demande : « ነገ ዝናብ ይዘንባል? »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-am-pause** (LGX, am) — 3/3 ratés
  - demande : « ፕሮግራሙን ለጊዜው አቁም። »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
- **lgx-am-urgence** (LGX, am) — 3/3 ratés
  - demande : « ማሽኑን አሁኑኑ አቁም፣ አስቸኳይ ነው! »
  - outil attendu « emergency_stop » non appelé
- **lgx-am-zero** (LGX, am) — 3/3 ratés
  - demande : « የስራ ዜሮን እዚህ አስቀምጥ። »
  - outil attendu « set_work_zero » non appelé
- **lgx-ar-brocheon** (LGX, ar) — 3/3 ratés
  - demande : « شغّل المغزل. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_activity_log)
- **lgx-ar-homing** (LGX, ar) — 1/3 ratés
  - demande : « أعد الآلة إلى موضع البداية. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-bm-explique** (LGX, bm) — 1/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye ni kuma nɔgɔman ye. »
  - outil appelé alors qu'aucun n'était attendu : get_diagnostics({})
- **lgx-bma-explique** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Homing ye mun ye, a nyefo n ye ni kuma nogoman ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({}), get_activity_log({})
- **lgx-bmx-explique** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z","A","C"]})
- **lgx-en-homing** (LGX, en) — 2/3 ratés
  - demande : « Send the machine back to its starting position. »
  - outil attendu « home » non appelé (obtenu : get_activity_log)
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-fr-homing** (LGX, fr) — 2/3 ratés
  - demande : « Ramène la machine à sa position de départ. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé
- **lgx-ha-brocheoff** (LGX, ha) — 3/3 ratés
  - demande : « Kashe spindle. »
  - set_spindle.state = "cw", attendu "off"
  - outil attendu « set_spindle » non appelé
- **lgx-ha-brocheon** (LGX, ha) — 3/3 ratés
  - demande : « Kunna spindle. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics, get_wcs_offsets, get_axis_kinematics, get_config)
- **lgx-ha-etat** (LGX, ha) — 3/3 ratés
  - demande : « Nuna mini yanayin na'urar. »
  - outil attendu « get_machine_state » non appelé
- **lgx-ha-explique** (LGX, ha) — 1/3 ratés
  - demande : « Bayyana mini a cikin sauƙaƙan kalmomi menene homing. »
  - outil appelé alors qu'aucun n'était attendu : home({})
- **lgx-ha-homing** (LGX, ha) — 3/3 ratés
  - demande : « Mayar da na'urar zuwa matsayinta na farko. »
  - outil attendu « home » non appelé
- **lgx-ha-jog** (LGX, ha) — 3/3 ratés
  - demande : « Motsa axis X da milimita 5 da gudun 300. »
  - outil attendu « jog_axis » non appelé
  - outil attendu « jog_axis » non appelé (obtenu : get_config)
- **lgx-ha-pause** (LGX, ha) — 3/3 ratés
  - demande : « Dakatar da shirin na ɗan lokaci. »
  - outil attendu « pause » non appelé
- **lgx-ha-urgence** (LGX, ha) — 3/3 ratés
  - demande : « Dakatar da na'urar yanzu, gaggawa ne! »
  - outil attendu « emergency_stop » non appelé
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
- **lgx-ha-zero** (LGX, ha) — 3/3 ratés
  - demande : « Saita sifilin aiki a nan. »
  - outil attendu « set_work_zero » non appelé
- **lgx-sw-brocheoff** (LGX, sw) — 3/3 ratés
  - demande : « Zima spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-brocheon** (LGX, sw) — 1/3 ratés
  - demande : « Washa spindle. »
  - outil attendu « set_spindle » non appelé (obtenu : send_gcode)
- **lgx-sw-etat** (LGX, sw) — 1/3 ratés
  - demande : « Nionyeshe hali ya mashine. »
  - outil attendu « get_machine_state » non appelé
- **lgx-sw-homing** (LGX, sw) — 2/3 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé
- **lgx-sw-pause** (LGX, sw) — 3/3 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé (obtenu : list_workspace_files)
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state, get_activity_log)
- **lgx-sw-urgence** (LGX, sw) — 3/3 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - outil attendu « emergency_stop » non appelé
- **lgx-sw-zero** (LGX, sw) — 3/3 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state, get_diagnostics)
  - outil attendu « set_work_zero » non appelé (obtenu : get_activity_log)
- **lgx-wo-brocheoff** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal broche bi. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-wo-brocheon** (LGX, wo) — 3/3 ratés
  - demande : « Tambali broche bi. »
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé
- **lgx-wo-explique** (LGX, wo) — 1/3 ratés
  - demande : « Wax ma ci wax yu yomb lan la homing. »
  - outil appelé alors qu'aucun n'était attendu : set_work_zero({"axes":["X","Y","Z"]})
- **lgx-wo-homing** (LGX, wo) — 3/3 ratés
  - demande : « Delloo machine bi ci béréb bi mu tambalee. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé
- **lgx-wo-horssujet** (LGX, wo) — 1/3 ratés
  - demande : « Taw dina ñëw ëllëg? »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-wo-jog** (LGX, wo) — 1/3 ratés
  - demande : « Dox axe X ci 5 mm ak gaaw 300. »
  - outil attendu « jog_axis » non appelé (obtenu : get_axis_kinematics)
- **lgx-wo-pause** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal programme bi ba ab diir. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
- **lgx-wo-urgence** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal machine bi léegi, gaaw! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - outil attendu « emergency_stop » non appelé
- **lgx-wo-zero** (LGX, wo) — 2/3 ratés
  - demande : « Teg zéro bi fii. »
  - outil attendu « set_work_zero » non appelé
- **lgx-yo-etat** (LGX, yo) — 3/3 ratés
  - demande : « Fi ipo ẹrọ naa han mi. »
  - outil attendu « get_machine_state » non appelé
- **lgx-yo-explique** (LGX, yo) — 3/3 ratés
  - demande : « Ṣe alaye ni ọrọ ti o rọrun kini homing jẹ. »
  - outil appelé alors qu'aucun n'était attendu : home({})
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z","A","C"]})
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
- **lgx-yo-homing** (LGX, yo) — 3/3 ratés
  - demande : « Mú ẹrọ naa pada si ibi ti o ti bẹrẹ. »
  - outil attendu « home » non appelé
- **lgx-yo-pause** (LGX, yo) — 3/3 ratés
  - demande : « Dá eto naa dúró fún ìgbà díẹ̀. »
  - outil attendu « pause » non appelé
- **lgx-yo-urgence** (LGX, yo) — 3/3 ratés
  - demande : « Duro ẹrọ naa lẹsẹkẹsẹ, pajawiri ni! »
  - outil attendu « emergency_stop » non appelé
- **lgx-yo-zero** (LGX, yo) — 3/3 ratés
  - demande : « Fi odo iṣẹ si ibi yii. »
  - outil attendu « set_work_zero » non appelé

