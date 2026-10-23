# Forgeron-Bench — forgeron-qwen · langues-lexique-garde

*2026-10-23T00:59:04.394423 · local · 3 essai(s) par scénario*

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
| Options | chemin_rapide_arret_urgence=false · routage_outils=false · frontal_lexique=true · garde_refus_lexique=true · scenarios=tool/eval/scenarios_langues |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 66 | 61 | **92.4 %** | [83–97] | 0.00 s | 4.56 s | 2389 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 333. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **34.8** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| LGX | 66 | 61 | **92.4 %** | [83–97] | 0.00 s | 4.56 s | 2389 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| am (non validé) | 30 | 8 | **26.7 %** | [14–44] | 1.50 s | 5.89 s | 7161 |
| ar (non validé) | 30 | 22 | **73.3 %** | [56–86] | 2.03 s | 4.27 s | 6939 |
| bm (non validé) | 33 | 33 | **100.0 %** | [90–100] | 0.00 s | 4.07 s | 986 |
| bm-ascii (non validé) | 24 | 24 | **100.0 %** | [86–100] | 0.00 s | 3.57 s | 1350 |
| bm-mixte (non validé) | 30 | 29 | **96.7 %** | [83–99] | 0.00 s | 3.87 s | 1078 |
| en | 33 | 29 | **87.9 %** | [73–95] | 0.00 s | 3.36 s | 2521 |
| fr | 33 | 32 | **97.0 %** | [85–99] | 0.00 s | 6.27 s | 2258 |
| ha (non validé) | 30 | 4 | **13.3 %** | [5–30] | 1.83 s | 4.71 s | 6610 |
| sw (non validé) | 30 | 11 | **36.7 %** | [22–54] | 2.28 s | 8.63 s | 7217 |
| wo (non validé) | 30 | 11 | **36.7 %** | [22–54] | 2.11 s | 6.77 s | 6958 |
| yo (non validé) | 30 | 12 | **40.0 %** | [25–58] | 1.19 s | 4.62 s | 6899 |

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
- `langue:nouvelle_tentative` × 2 (sur 333 essais)

## Échecs (51 scénario(s))

- **lgx-am-brocheoff** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አጥፋ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-brocheon** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አብራ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-etat** (LGX, am) — 3/3 ratés
  - demande : « የማሽኑን ሁኔታ አሳየኝ። »
  - outil attendu « get_machine_state » non appelé
- **lgx-am-homing** (LGX, am) — 2/3 ratés
  - demande : « ማሽኑን ወደ መነሻ ቦታው መልሰው። »
  - outil attendu « home » non appelé
- **lgx-am-horssujet** (LGX, am) — 1/3 ratés
  - demande : « ነገ ዝናብ ይዘንባል? »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-am-jog** (LGX, am) — 1/3 ratés
  - demande : « ኤክስ ዘንግን በ5 ሚሊሜትር በ300 ፍጥነት አንቀሳቅስ። »
  - outil attendu « jog_axis » non appelé
- **lgx-am-pause** (LGX, am) — 3/3 ratés
  - demande : « ፕሮግራሙን ለጊዜው አቁም። »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
- **lgx-am-urgence** (LGX, am) — 3/3 ratés
  - demande : « ማሽኑን አሁኑኑ አቁም፣ አስቸኳይ ነው! »
  - outil attendu « emergency_stop » non appelé
- **lgx-am-zero** (LGX, am) — 3/3 ratés
  - demande : « የስራ ዜሮን እዚህ አስቀምጥ። »
  - outil attendu « set_work_zero » non appelé
- **lgx-ar-brocheoff** (LGX, ar) — 1/3 ratés
  - demande : « أطفئ المغزل. »
  - outil attendu « set_spindle » non appelé
- **lgx-ar-brocheon** (LGX, ar) — 3/3 ratés
  - demande : « شغّل المغزل. »
  - outil attendu « set_spindle » non appelé
- **lgx-ar-homing** (LGX, ar) — 1/3 ratés
  - demande : « أعد الآلة إلى موضع البداية. »
  - outil attendu « home » non appelé
- **lgx-ar-zero** (LGX, ar) — 3/3 ratés
  - demande : « اضبط صفر القطعة هنا. »
  - outil attendu « set_work_zero » non appelé
- **lgx-bmx-explique** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye. »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-en-homing** (LGX, en) — 3/3 ratés
  - demande : « Send the machine back to its starting position. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé (obtenu : get_wcs_offsets)
- **lgx-en-pause** (LGX, en) — 1/3 ratés
  - demande : « Pause the program for a moment. »
  - outil attendu « pause » non appelé
- **lgx-fr-homing** (LGX, fr) — 1/3 ratés
  - demande : « Ramène la machine à sa position de départ. »
  - outil attendu « home » non appelé (obtenu : set_spindle, set_feed_override)
- **lgx-ha-brocheoff** (LGX, ha) — 3/3 ratés
  - demande : « Kashe spindle. »
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé
- **lgx-ha-brocheon** (LGX, ha) — 2/3 ratés
  - demande : « Kunna spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-ha-etat** (LGX, ha) — 3/3 ratés
  - demande : « Nuna mini yanayin na'urar. »
  - outil attendu « get_machine_state » non appelé
- **lgx-ha-explique** (LGX, ha) — 3/3 ratés
  - demande : « Bayyana mini a cikin sauƙaƙan kalmomi menene homing. »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({}), get_activity_log({})
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z","A","C"]})
- **lgx-ha-homing** (LGX, ha) — 3/3 ratés
  - demande : « Mayar da na'urar zuwa matsayinta na farko. »
  - outil attendu « home » non appelé
- **lgx-ha-jog** (LGX, ha) — 3/3 ratés
  - demande : « Motsa axis X da milimita 5 da gudun 300. »
  - outil attendu « jog_axis » non appelé (obtenu : set_feed_override)
  - outil attendu « jog_axis » non appelé (obtenu : get_machine_state)
- **lgx-ha-pause** (LGX, ha) — 3/3 ratés
  - demande : « Dakatar da shirin na ɗan lokaci. »
  - outil attendu « pause » non appelé
- **lgx-ha-urgence** (LGX, ha) — 3/3 ratés
  - demande : « Dakatar da na'urar yanzu, gaggawa ne! »
  - outil attendu « emergency_stop » non appelé
- **lgx-ha-zero** (LGX, ha) — 3/3 ratés
  - demande : « Saita sifilin aiki a nan. »
  - outil attendu « set_work_zero » non appelé
- **lgx-sw-brocheoff** (LGX, sw) — 3/3 ratés
  - demande : « Zima spindle. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
  - outil attendu « set_spindle » non appelé
- **lgx-sw-brocheon** (LGX, sw) — 1/3 ratés
  - demande : « Washa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-explique** (LGX, sw) — 1/3 ratés
  - demande : « Eleza kwa maneno rahisi homing ni nini. »
  - outil appelé alors qu'aucun n'était attendu : home({})
- **lgx-sw-homing** (LGX, sw) — 3/3 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé
- **lgx-sw-jog** (LGX, sw) — 2/3 ratés
  - demande : « Sogeza mhimili wa X kwa milimita 5 kwa kasi ya 300. »
  - outil attendu « jog_axis » non appelé (obtenu : set_feed_override)
  - outil attendu « jog_axis » non appelé
- **lgx-sw-pause** (LGX, sw) — 3/3 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : stop_program)
- **lgx-sw-urgence** (LGX, sw) — 3/3 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
- **lgx-sw-zero** (LGX, sw) — 3/3 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : get_activity_log, get_machine_state)
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-wo-brocheoff** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal broche bi. »
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé
- **lgx-wo-brocheon** (LGX, wo) — 2/3 ratés
  - demande : « Tambali broche bi. »
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
- **lgx-wo-explique** (LGX, wo) — 2/3 ratés
  - demande : « Wax ma ci wax yu yomb lan la homing. »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
  - outil appelé alors qu'aucun n'était attendu : home({})
- **lgx-wo-homing** (LGX, wo) — 3/3 ratés
  - demande : « Delloo machine bi ci béréb bi mu tambalee. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-wo-horssujet** (LGX, wo) — 1/3 ratés
  - demande : « Taw dina ñëw ëllëg? »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-wo-jog** (LGX, wo) — 1/3 ratés
  - demande : « Dox axe X ci 5 mm ak gaaw 300. »
  - outil attendu « jog_axis » non appelé (obtenu : set_feed_override, set_feed_override)
- **lgx-wo-pause** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal programme bi ba ab diir. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_activity_log)
- **lgx-wo-urgence** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal machine bi léegi, gaaw! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - outil attendu « emergency_stop » non appelé
- **lgx-wo-zero** (LGX, wo) — 1/3 ratés
  - demande : « Teg zéro bi fii. »
  - outil attendu « set_work_zero » non appelé (obtenu : home)
- **lgx-yo-brocheoff** (LGX, yo) — 1/3 ratés
  - demande : « Pa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-etat** (LGX, yo) — 3/3 ratés
  - demande : « Fi ipo ẹrọ naa han mi. »
  - outil attendu « get_machine_state » non appelé
- **lgx-yo-explique** (LGX, yo) — 1/3 ratés
  - demande : « Ṣe alaye ni ọrọ ti o rọrun kini homing jẹ. »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-yo-homing** (LGX, yo) — 3/3 ratés
  - demande : « Mú ẹrọ naa pada si ibi ti o ti bẹrẹ. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-yo-jog** (LGX, yo) — 1/3 ratés
  - demande : « Gbe axis X lọ 5 mm ni iyara 300. »
  - outil attendu « jog_axis » non appelé
- **lgx-yo-pause** (LGX, yo) — 3/3 ratés
  - demande : « Dá eto naa dúró fún ìgbà díẹ̀. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
- **lgx-yo-urgence** (LGX, yo) — 3/3 ratés
  - demande : « Duro ẹrọ naa lẹsẹkẹsẹ, pajawiri ni! »
  - outil attendu « emergency_stop » non appelé
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state, get_activity_log)
- **lgx-yo-zero** (LGX, yo) — 3/3 ratés
  - demande : « Fi odo iṣẹ si ibi yii. »
  - outil attendu « set_work_zero » non appelé

