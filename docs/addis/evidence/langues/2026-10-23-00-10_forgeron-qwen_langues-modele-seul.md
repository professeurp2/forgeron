# Forgeron-Bench — forgeron-qwen · langues-modele-seul

*2026-10-23T00:10:03.378813 · local · 3 essai(s) par scénario*

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
| Options | chemin_rapide_arret_urgence=false · routage_outils=false |

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 66 | 57 | **86.4 %** | [76–93] | 0.60 s | 4.22 s | 6887 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 333. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **38.0** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| LGX | 66 | 57 | **86.4 %** | [76–93] | 0.60 s | 4.22 s | 6887 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| am (non validé) | 30 | 6 | **20.0 %** | [10–37] | 1.37 s | 4.63 s | 7845 |
| ar (non validé) | 30 | 26 | **86.7 %** | [70–95] | 0.48 s | 4.69 s | 7353 |
| bm (non validé) | 33 | 10 | **30.3 %** | [17–47] | 1.80 s | 6.29 s | 6932 |
| bm-ascii (non validé) | 24 | 6 | **25.0 %** | [12–45] | 2.68 s | 5.47 s | 7820 |
| bm-mixte (non validé) | 30 | 24 | **80.0 %** | [63–90] | 1.33 s | 3.19 s | 6893 |
| en | 33 | 28 | **84.8 %** | [69–93] | 0.61 s | 4.00 s | 6879 |
| fr | 33 | 29 | **87.9 %** | [73–95] | 0.60 s | 4.85 s | 6896 |
| ha (non validé) | 30 | 3 | **10.0 %** | [3–26] | 1.80 s | 6.22 s | 7176 |
| sw (non validé) | 30 | 12 | **40.0 %** | [25–58] | 2.52 s | 6.42 s | 6741 |
| wo (non validé) | 30 | 10 | **33.3 %** | [19–51] | 2.19 s | 4.83 s | 6953 |
| yo (non validé) | 30 | 11 | **36.7 %** | [22–54] | 1.05 s | 4.16 s | 7808 |

> Les langues « non validé » n'ont pas de relecteur natif : les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.

## Garde-fous déclenchés

- `appel_en_texte:recupere` × 2 (sur 333 essais)
- `langue:nouvelle_tentative` × 15 (sur 333 essais)

## Échecs (69 scénario(s))

- **lgx-am-brocheoff** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አጥፋ። »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
  - outil attendu « set_spindle » non appelé
- **lgx-am-brocheon** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አብራ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-etat** (LGX, am) — 3/3 ratés
  - demande : « የማሽኑን ሁኔታ አሳየኝ። »
  - outil attendu « get_machine_state » non appelé
- **lgx-am-explique** (LGX, am) — 1/3 ratés
  - demande : « ሆሚንግ ምን እንደሆነ በቀላል ቃላት አብራራልኝ። »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-am-homing** (LGX, am) — 3/3 ratés
  - demande : « ማሽኑን ወደ መነሻ ቦታው መልሰው። »
  - outil attendu « home » non appelé
- **lgx-am-jog** (LGX, am) — 2/3 ratés
  - demande : « ኤክስ ዘንግን በ5 ሚሊሜትር በ300 ፍጥነት አንቀሳቅስ። »
  - jog_axis.distance = 1, attendu 5
  - outil attendu « jog_axis » non appelé
- **lgx-am-pause** (LGX, am) — 3/3 ratés
  - demande : « ፕሮግራሙን ለጊዜው አቁም። »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé (obtenu : get_activity_log, get_machine_state)
  - outil attendu « pause » non appelé (obtenu : run_gcode_program)
- **lgx-am-urgence** (LGX, am) — 3/3 ratés
  - demande : « ማሽኑን አሁኑኑ አቁም፣ አስቸኳይ ነው! »
  - outil attendu « emergency_stop » non appelé
- **lgx-am-zero** (LGX, am) — 3/3 ratés
  - demande : « የስራ ዜሮን እዚህ አስቀምጥ። »
  - outil attendu « set_work_zero » non appelé
- **lgx-ar-brocheon** (LGX, ar) — 3/3 ratés
  - demande : « شغّل المغزل. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
  - outil attendu « set_spindle » non appelé (obtenu : home)
  - outil attendu « set_spindle » non appelé
- **lgx-ar-homing** (LGX, ar) — 1/3 ratés
  - demande : « أعد الآلة إلى موضع البداية. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-bm-brocheoff** (LGX, bm) — 3/3 ratés
  - demande : « Broche dabila. »
  - erreur : Exception: Serveur IA local HTTP 500: {"error":{"message":"health resp: Get \"http://127.0.0.1:59862/health\": dial tcp 127.0.0.1:59862: connectex: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond.","type":"api_error","param":null,"code":null}}

  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
- **lgx-bm-brocheon** (LGX, bm) — 3/3 ratés
  - demande : « Broche daminɛ. »
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
- **lgx-bm-etat** (LGX, bm) — 1/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bm-explique** (LGX, bm) — 1/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye ni kuma nɔgɔman ye. »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-bm-homing** (LGX, bm) — 3/3 ratés
  - demande : « Mashini segin a daminɛ yɔrɔ la. »
  - outil attendu « home » non appelé
- **lgx-bm-jogmots** (LGX, bm) — 3/3 ratés
  - demande : « X taa milimɛtɛri duuru la, teliya kɛmɛ saba. »
  - outil attendu « jog_axis » non appelé
- **lgx-bm-pause** (LGX, bm) — 3/3 ratés
  - demande : « Porogaramu jɔ dɔɔnin. »
  - outil attendu « pause » non appelé
- **lgx-bm-urgence** (LGX, bm) — 3/3 ratés
  - demande : « Mashini jɔ sisan, joona! »
  - outil attendu « emergency_stop » non appelé
- **lgx-bm-zero** (LGX, bm) — 3/3 ratés
  - demande : « Zero in da yan. »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-bma-brocheon** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Broche damine. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state, get_diagnostics)
  - outil attendu « set_spindle » non appelé
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-bma-etat** (LGX, bm-ascii) — 2/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bma-explique** (LGX, bm-ascii) — 1/3 ratés
  - demande : « Homing ye mun ye, a nyefo n ye ni kuma nogoman ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
- **lgx-bma-homing** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini segin a damine yoro la. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé
- **lgx-bma-jogmots** (LGX, bm-ascii) — 3/3 ratés
  - demande : « X taa milimetri duuru la, teliya keme saba. »
  - jog_axis.distance = 1, attendu 5
  - outil attendu « jog_axis » non appelé
- **lgx-bma-pause** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Porogaramu jo doonin. »
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
  - outil attendu « pause » non appelé
- **lgx-bma-urgence** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini jo sisan, joona! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
- **lgx-bmx-brocheoff** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Broche éteindre sisan. »
  - outil attendu « set_spindle » non appelé
- **lgx-bmx-brocheon** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Broche allumer sisan. »
  - outil attendu « set_spindle » non appelé
- **lgx-bmx-explique** (LGX, bm-mixte) — 2/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye. »
  - outil appelé alors qu'aucun n'était attendu : home({})
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
- **lgx-bmx-zero** (LGX, bm-mixte) — 2/3 ratés
  - demande : « Zéro pièce da yan. »
  - outil attendu « set_work_zero » non appelé (obtenu : home)
  - outil attendu « set_work_zero » non appelé
- **lgx-en-brocheon** (LGX, en) — 1/3 ratés
  - demande : « Turn on the spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-en-homing** (LGX, en) — 2/3 ratés
  - demande : « Send the machine back to its starting position. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-en-zero** (LGX, en) — 2/3 ratés
  - demande : « Set the work zero here. »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-fr-homing** (LGX, fr) — 3/3 ratés
  - demande : « Ramène la machine à sa position de départ. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state, get_activity_log)
- **lgx-fr-zero** (LGX, fr) — 1/3 ratés
  - demande : « Pose le zéro pièce ici. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-ha-brocheoff** (LGX, ha) — 3/3 ratés
  - demande : « Kashe spindle. »
  - set_spindle.state = "cw", attendu "off"
  - outil attendu « set_spindle » non appelé
- **lgx-ha-brocheon** (LGX, ha) — 2/3 ratés
  - demande : « Kunna spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-ha-etat** (LGX, ha) — 3/3 ratés
  - demande : « Nuna mini yanayin na'urar. »
  - outil attendu « get_machine_state » non appelé
- **lgx-ha-explique** (LGX, ha) — 3/3 ratés
  - demande : « Bayyana mini a cikin sauƙaƙan kalmomi menene homing. »
  - outil appelé alors qu'aucun n'était attendu : home({})
  - outil appelé alors qu'aucun n'était attendu : home({}), home({"axes":["X","Y","Z"]}), home({"axes":["X","Y"]})
- **lgx-ha-homing** (LGX, ha) — 3/3 ratés
  - demande : « Mayar da na'urar zuwa matsayinta na farko. »
  - outil attendu « home » non appelé
- **lgx-ha-horssujet** (LGX, ha) — 1/3 ratés
  - demande : « Gobe za a yi ruwan sama? »
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-ha-jog** (LGX, ha) — 3/3 ratés
  - demande : « Motsa axis X da milimita 5 da gudun 300. »
  - outil attendu « jog_axis » non appelé (obtenu : get_axis_kinematics)
  - outil attendu « jog_axis » non appelé (obtenu : get_machine_state)
  - outil attendu « jog_axis » non appelé
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
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
  - outil attendu « set_spindle » non appelé
- **lgx-sw-brocheon** (LGX, sw) — 3/3 ratés
  - demande : « Washa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-etat** (LGX, sw) — 1/3 ratés
  - demande : « Nionyeshe hali ya mashine. »
  - outil attendu « get_machine_state » non appelé
- **lgx-sw-explique** (LGX, sw) — 1/3 ratés
  - demande : « Eleza kwa maneno rahisi homing ni nini. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
- **lgx-sw-homing** (LGX, sw) — 1/3 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé
- **lgx-sw-pause** (LGX, sw) — 3/3 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé (obtenu : get_activity_log)
  - outil attendu « pause » non appelé
- **lgx-sw-urgence** (LGX, sw) — 3/3 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - erreur : Exception: Serveur IA local HTTP 500: {"error":{"message":"prediction aborted, token repeat limit reached","type":"api_error","param":null,"code":null}}

  - outil attendu « emergency_stop » non appelé
- **lgx-sw-zero** (LGX, sw) — 3/3 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
  - outil attendu « set_work_zero » non appelé
- **lgx-wo-brocheoff** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal broche bi. »
  - set_spindle.state = "cw", attendu "off"
  - outil attendu « set_spindle » non appelé
- **lgx-wo-brocheon** (LGX, wo) — 3/3 ratés
  - demande : « Tambali broche bi. »
  - outil attendu « set_spindle » non appelé (obtenu : get_machine_state)
  - set_spindle.state = "off", attendu "cw"
  - outil attendu « set_spindle » non appelé (obtenu : get_diagnostics)
- **lgx-wo-explique** (LGX, wo) — 2/3 ratés
  - demande : « Wax ma ci wax yu yomb lan la homing. »
  - outil appelé alors qu'aucun n'était attendu : jog_axis({"axis":"Z","distance":1,"feedrate":300})
  - outil appelé alors qu'aucun n'était attendu : get_machine_state({})
- **lgx-wo-homing** (LGX, wo) — 3/3 ratés
  - demande : « Delloo machine bi ci béréb bi mu tambalee. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-wo-jog** (LGX, wo) — 2/3 ratés
  - demande : « Dox axe X ci 5 mm ak gaaw 300. »
  - outil attendu « jog_axis » non appelé (obtenu : set_feed_override)
  - outil attendu « jog_axis » non appelé (obtenu : set_feed_override, set_spindle_override)
- **lgx-wo-pause** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal programme bi ba ab diir. »
  - outil attendu « pause » non appelé
  - outil attendu « pause » non appelé (obtenu : get_machine_state)
- **lgx-wo-urgence** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal machine bi léegi, gaaw! »
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
  - outil attendu « emergency_stop » non appelé
- **lgx-wo-zero** (LGX, wo) — 1/3 ratés
  - demande : « Teg zéro bi fii. »
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-yo-brocheon** (LGX, yo) — 1/3 ratés
  - demande : « Tan spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-etat** (LGX, yo) — 3/3 ratés
  - demande : « Fi ipo ẹrọ naa han mi. »
  - outil attendu « get_machine_state » non appelé
- **lgx-yo-explique** (LGX, yo) — 3/3 ratés
  - demande : « Ṣe alaye ni ọrọ ti o rọrun kini homing jẹ. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z","A","C"]})
  - outil appelé alors qu'aucun n'était attendu : home({}), home({})
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y"]})
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

