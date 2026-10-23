# Forgeron-Bench — forgeron-qwen3-8b-nothink · langues-qwen3-8b-sans-reflexion

*2026-10-23T03:11:27.781648 · local · 3 essai(s) par scénario*

| | |
|---|---|
| Modèle | `forgeron-qwen3-8b-nothink` (empreinte `b54079155175`) |
| Serveur | Ollama 0.34.2 |
| Contexte | 8192 tokens |
| Prompt système | `855ed8d8138e2a7a` |
| 38 outils | `96c7b6fbf64b7d59` |
| Scénarios | `3e4679992c323888` |
| Commit | `52e53ef+modifications` |
| GPU | NVIDIA GeForce RTX 3070 Laptop GPU, 8192 MiB |
| Options | chemin_rapide_arret_urgence=false · routage_outils=false · scenarios=tool/eval/scenarios_langues |

**Énergie (GPU)** : moyenne 91 W · pic 125 W · 20.55 Wh pour 333 requêtes (6.17 Wh pour 100) · mémoire max 6075 Mo.

## Chiffre vedette

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| **tous scénarios retenus** | 66 | 66 | **100.0 %** | [94–100] | 0.55 s | 3.22 s | 6855 |

> Scénarios retenus : français et anglais, statut `relu` ou `brouillon`. Essais relus par un humain : 0 / 333. Les scénarios dans une langue sans relecteur natif sont **à part** (plus bas).

Outils déclarés par tour (moyenne) : **38.0** sur 38.

## Par catégorie

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| LGX | 66 | 66 | **100.0 %** | [94–100] | 0.55 s | 3.22 s | 6855 |

## Par langue

| | essais | réussis | réussite | IC 95 % | latence p50 | latence p95 | tokens/tour |
|---|---:|---:|---:|:---:|---:|---:|---:|
| am (non validé) | 30 | 12 | **40.0 %** | [25–58] | 0.67 s | 9.37 s | 6663 |
| ar (non validé) | 30 | 27 | **90.0 %** | [74–97] | 0.52 s | 3.80 s | 6866 |
| bm (non validé) | 33 | 4 | **12.1 %** | [5–27] | 1.53 s | 5.56 s | 6922 |
| bm-ascii (non validé) | 24 | 6 | **25.0 %** | [12–45] | 1.25 s | 5.00 s | 6909 |
| bm-mixte (non validé) | 30 | 14 | **46.7 %** | [30–64] | 0.78 s | 3.03 s | 6871 |
| en | 33 | 33 | **100.0 %** | [90–100] | 0.55 s | 3.22 s | 6847 |
| fr | 33 | 33 | **100.0 %** | [90–100] | 0.56 s | 3.64 s | 6862 |
| ha (non validé) | 30 | 6 | **20.0 %** | [10–37] | 1.25 s | 3.54 s | 6892 |
| sw (non validé) | 30 | 6 | **20.0 %** | [10–37] | 1.31 s | 3.76 s | 6900 |
| wo (non validé) | 30 | 8 | **26.7 %** | [14–44] | 1.39 s | 7.00 s | 6921 |
| yo (non validé) | 30 | 8 | **26.7 %** | [14–44] | 1.63 s | 104.37 s | 6706 |

> Les langues « non validé » n'ont pas de relecteur natif : les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.

## Garde-fous déclenchés

Aucun : toutes les réponses sont arrivées telles quelles.

## Échecs (62 scénario(s))

- **lgx-am-brocheoff** (LGX, am) — 1/3 ratés
  - demande : « ስፒንድሉን አጥፋ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-brocheon** (LGX, am) — 3/3 ratés
  - demande : « ስፒንድሉን አብራ። »
  - outil attendu « set_spindle » non appelé
- **lgx-am-explique** (LGX, am) — 3/3 ratés
  - demande : « ሆሚንግ ምን እንደሆነ በቀላል ቃላት አብራራልኝ። »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
  - la réponse finale ne correspond pas à « .{30,} »
- **lgx-am-jog** (LGX, am) — 2/3 ratés
  - demande : « ኤክስ ዘንግን በ5 ሚሊሜትር በ300 ፍጥነት አንቀሳቅስ። »
  - jog_axis.axis = "Z", attendu "X"
  - jog_axis.distance = -5, attendu 5
- **lgx-am-pause** (LGX, am) — 3/3 ratés
  - demande : « ፕሮግራሙን ለጊዜው አቁም። »
  - outil attendu « pause » non appelé
- **lgx-am-urgence** (LGX, am) — 3/3 ratés
  - demande : « ማሽኑን አሁኑኑ አቁም፣ አስቸኳይ ነው! »
  - outil attendu « emergency_stop » non appelé
  - outil attendu « emergency_stop » non appelé (obtenu : get_machine_state)
- **lgx-am-zero** (LGX, am) — 3/3 ratés
  - demande : « የስራ ዜሮን እዚህ አስቀምጥ። »
  - outil attendu « set_work_zero » non appelé
  - outil attendu « set_work_zero » non appelé (obtenu : get_machine_state)
- **lgx-ar-brocheon** (LGX, ar) — 3/3 ratés
  - demande : « شغّل المغزل. »
  - outil attendu « set_spindle » non appelé
- **lgx-bm-brocheoff** (LGX, bm) — 3/3 ratés
  - demande : « Broche dabila. »
  - outil attendu « set_spindle » non appelé
- **lgx-bm-brocheon** (LGX, bm) — 3/3 ratés
  - demande : « Broche daminɛ. »
  - outil attendu « set_spindle » non appelé
- **lgx-bm-etat** (LGX, bm) — 2/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bm-explique** (LGX, bm) — 3/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye ni kuma nɔgɔman ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
  - la réponse finale ne correspond pas à « .{30,} »
- **lgx-bm-homing** (LGX, bm) — 3/3 ratés
  - demande : « Mashini segin a daminɛ yɔrɔ la. »
  - outil attendu « home » non appelé (obtenu : get_machine_state)
  - outil attendu « home » non appelé
- **lgx-bm-jog** (LGX, bm) — 3/3 ratés
  - demande : « X taa mm 5 la, teliya 300. »
  - outil attendu « jog_axis » non appelé
  - outil attendu « jog_axis » non appelé (obtenu : get_machine_state)
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
- **lgx-bma-brocheon** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Broche damine. »
  - outil attendu « set_spindle » non appelé
- **lgx-bma-etat** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini cogoya jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bma-homing** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini segin a damine yoro la. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state)
- **lgx-bma-jogmots** (LGX, bm-ascii) — 3/3 ratés
  - demande : « X taa milimetri duuru la, teliya keme saba. »
  - outil attendu « jog_axis » non appelé
- **lgx-bma-pause** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Porogaramu jo doonin. »
  - outil attendu « pause » non appelé
- **lgx-bma-urgence** (LGX, bm-ascii) — 3/3 ratés
  - demande : « Mashini jo sisan, joona! »
  - outil attendu « emergency_stop » non appelé
- **lgx-bmx-brocheoff** (LGX, bm-mixte) — 3/3 ratés
  - demande : « Broche éteindre sisan. »
  - outil attendu « set_spindle » non appelé
- **lgx-bmx-brocheon** (LGX, bm-mixte) — 3/3 ratés
  - demande : « Broche allumer sisan. »
  - outil attendu « set_spindle » non appelé
- **lgx-bmx-etat** (LGX, bm-mixte) — 3/3 ratés
  - demande : « Mashini état jira n ye. »
  - outil attendu « get_machine_state » non appelé
- **lgx-bmx-explique** (LGX, bm-mixte) — 1/3 ratés
  - demande : « Homing ye mun ye, a ɲɛfɔ n ye. »
  - outil appelé alors qu'aucun n'était attendu : home({"axes":["X","Y","Z"]})
  - la réponse finale ne correspond pas à « .{30,} »
- **lgx-bmx-pause** (LGX, bm-mixte) — 3/3 ratés
  - demande : « Programme pause kɛ. »
  - outil attendu « pause » non appelé
- **lgx-bmx-zero** (LGX, bm-mixte) — 3/3 ratés
  - demande : « Zéro pièce da yan. »
  - outil attendu « set_work_zero » non appelé
- **lgx-ha-brocheoff** (LGX, ha) — 3/3 ratés
  - demande : « Kashe spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-ha-brocheon** (LGX, ha) — 3/3 ratés
  - demande : « Kunna spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-ha-etat** (LGX, ha) — 3/3 ratés
  - demande : « Nuna mini yanayin na'urar. »
  - outil attendu « get_machine_state » non appelé
- **lgx-ha-homing** (LGX, ha) — 3/3 ratés
  - demande : « Mayar da na'urar zuwa matsayinta na farko. »
  - outil attendu « home » non appelé
- **lgx-ha-jog** (LGX, ha) — 3/3 ratés
  - demande : « Motsa axis X da milimita 5 da gudun 300. »
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
  - outil attendu « set_spindle » non appelé
- **lgx-sw-brocheon** (LGX, sw) — 3/3 ratés
  - demande : « Washa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-sw-etat** (LGX, sw) — 3/3 ratés
  - demande : « Nionyeshe hali ya mashine. »
  - outil attendu « get_machine_state » non appelé
- **lgx-sw-homing** (LGX, sw) — 3/3 ratés
  - demande : « Rudisha mashine kwenye nafasi ya mwanzo. »
  - outil attendu « home » non appelé
- **lgx-sw-jog** (LGX, sw) — 3/3 ratés
  - demande : « Sogeza mhimili wa X kwa milimita 5 kwa kasi ya 300. »
  - outil attendu « jog_axis » non appelé (obtenu : get_machine_state)
  - outil attendu « jog_axis » non appelé
- **lgx-sw-pause** (LGX, sw) — 3/3 ratés
  - demande : « Sitisha programu kwa muda. »
  - outil attendu « pause » non appelé
- **lgx-sw-urgence** (LGX, sw) — 3/3 ratés
  - demande : « Simamisha mashine sasa hivi, ni dharura! »
  - outil attendu « emergency_stop » non appelé
- **lgx-sw-zero** (LGX, sw) — 3/3 ratés
  - demande : « Weka sifuri ya kazi hapa. »
  - outil attendu « set_work_zero » non appelé
- **lgx-wo-brocheoff** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal broche bi. »
  - outil attendu « set_spindle » non appelé
- **lgx-wo-brocheon** (LGX, wo) — 3/3 ratés
  - demande : « Tambali broche bi. »
  - outil attendu « set_spindle » non appelé
- **lgx-wo-etat** (LGX, wo) — 3/3 ratés
  - demande : « Wone ma ni machine bi nekk. »
  - outil attendu « get_machine_state » non appelé
- **lgx-wo-homing** (LGX, wo) — 3/3 ratés
  - demande : « Delloo machine bi ci béréb bi mu tambalee. »
  - outil attendu « home » non appelé
  - outil attendu « home » non appelé (obtenu : get_machine_state, get_diagnostics)
- **lgx-wo-jog** (LGX, wo) — 1/3 ratés
  - demande : « Dox axe X ci 5 mm ak gaaw 300. »
  - outil attendu « jog_axis » non appelé
- **lgx-wo-pause** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal programme bi ba ab diir. »
  - outil attendu « pause » non appelé
- **lgx-wo-urgence** (LGX, wo) — 3/3 ratés
  - demande : « Taxawal machine bi léegi, gaaw! »
  - outil attendu « emergency_stop » non appelé
- **lgx-wo-zero** (LGX, wo) — 3/3 ratés
  - demande : « Teg zéro bi fii. »
  - outil attendu « set_work_zero » non appelé
- **lgx-yo-brocheoff** (LGX, yo) — 3/3 ratés
  - demande : « Pa spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-brocheon** (LGX, yo) — 3/3 ratés
  - demande : « Tan spindle. »
  - outil attendu « set_spindle » non appelé
- **lgx-yo-etat** (LGX, yo) — 3/3 ratés
  - demande : « Fi ipo ẹrọ naa han mi. »
  - outil attendu « get_machine_state » non appelé
- **lgx-yo-homing** (LGX, yo) — 3/3 ratés
  - demande : « Mú ẹrọ naa pada si ibi ti o ti bẹrẹ. »
  - outil attendu « home » non appelé
- **lgx-yo-jog** (LGX, yo) — 1/3 ratés
  - demande : « Gbe axis X lọ 5 mm ni iyara 300. »
  - outil attendu « jog_axis » non appelé
- **lgx-yo-pause** (LGX, yo) — 3/3 ratés
  - demande : « Dá eto naa dúró fún ìgbà díẹ̀. »
  - outil attendu « pause » non appelé
- **lgx-yo-urgence** (LGX, yo) — 3/3 ratés
  - demande : « Duro ẹrọ naa lẹsẹkẹsẹ, pajawiri ni! »
  - outil attendu « emergency_stop » non appelé
  - erreur : TimeoutException after 0:03:00.000000: Future not completed
- **lgx-yo-zero** (LGX, yo) — 3/3 ratés
  - demande : « Fi odo iṣẹ si ibi yii. »
  - outil attendu « set_work_zero » non appelé

