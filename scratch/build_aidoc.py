#!/usr/bin/env python3
"""Génère le doc 'Agent IA + 50 Q/R' pour l'entretien (HTML autonome)."""
import base64, pathlib, html
root = pathlib.Path(__file__).resolve().parent.parent
logo_uri = "data:image/png;base64," + base64.b64encode((root / "assets/logo.png").read_bytes()).decode()

TOOLS = [
    ("get_machine_state","Lit l'état complet (position, WCS, avance, broche, alarme)","Lecture — jamais bloqué"),
    ("jog_axis","Déplace un axe (X/Y/Z mm, A/C degrés) d'une distance à une vitesse","Mouvement"),
    ("home","Prise d'origine (homing) d'un ou tous les axes","Mouvement"),
    ("emergency_stop","Arrêt d'urgence immédiat (soft reset + purge)","Toujours exécuté, sans confirmation"),
    ("set_feed_override","Règle l'override d'avance (10–200 %)","Mouvement"),
    ("set_spindle_override","Règle l'override de broche (10–200 %)","Broche / arrosage"),
    ("select_wcs","Change le système de coordonnées actif (G54–G59)","WCS / outil"),
    ("set_wcs_offset","Définit l'offset d'un WCS (G10 L2)","WCS / outil"),
    ("send_gcode","Envoie une ligne de G-code ponctuelle","Streaming"),
    ("pause","Met en pause le programme (feed hold)","Streaming"),
    ("resume","Reprend un programme en pause (cycle start)","Streaming"),
    ("reset","Réinitialise le contrôleur (soft reset)","Streaming"),
]

QA = [
 ("Produit & problème", [
  ("C'est quoi Forgeron en une phrase ?","Un contrôleur CNC 5-axes de grade industriel qui tourne sur un microcontrôleur ESP32 à ~8 $ et se pilote depuis un téléphone — avec un agent IA qui l'opère en langage naturel. Pensé pour les ateliers africains."),
  ("Quel problème résous-tu ?","Un contrôleur CNC 5-axes industriel coûte 5 000–50 000 $, est fermé, et exige un opérateur très qualifié. Résultat : les ateliers, fablabs et PME africains sont exclus de la fabrication de précision et importent leurs pièces."),
  ("Pour qui, précisément ?","Ateliers d'usinage, fablabs/makerspaces, écoles techniques (TVET) et PME manufacturières en Afrique. Puis les fabricants de kits CNC."),
  ("Pourquoi 5 axes et pas 3 ?","Le 5-axes permet des pièces complexes (moules, prothèses, pièces aéronautiques) en une seule prise. C'est là que la valeur est la plus forte — et là que le verrou de coût/compétence est le plus dur. C'est notre différenciation."),
  ("Comment est-ce possible pour ~8 $ ?","Le firmware open-source FluidNC tourne sur un ESP32 (~8 $) et pilote des drivers pas-à-pas bon marché (TB6600). L'intelligence est dans notre application et notre agent IA, pas dans un boîtier propriétaire coûteux."),
  ("Ce n'est pas juste FluidNC alors ?","Non. FluidNC est le firmware qui bouge les moteurs. Forgeron, c'est la couche au-dessus : l'application de contrôle industrielle, l'agent IA, la sécurité (validation de trajectoire), et l'UX. FluidNC seul n'a ni IA, ni interface industrielle, ni validation anti-collision."),
  ("Pourquoi l'Afrique ?","Le matériel est devenu bon marché, le besoin d'industrialisation est énorme, et la barrière de compétence est réelle. On démocratise la fabrication de précision là où elle est aujourd'hui inaccessible."),
  ("À quel stade es-tu ?","MVP : la machine physique 5-axes est construite et fonctionnelle, l'application et l'agent IA marchent, démontrés de bout en bout (vidéo + code open-source)."),
 ]),
 ("L'agent IA — technique", [
  ("Comment marche ton agent IA, concrètement ?","L'utilisateur écrit ou dicte une intention. On envoie son message à un grand modèle de langage (Gemini) avec le catalogue de nos outils. Le modèle répond par un ou plusieurs appels d'outils structurés ; l'application les exécute sur la machine, renvoie le résultat au modèle, et la boucle continue jusqu'à une réponse finale en clair."),
  ("C'est quoi le « function calling » ?","On décrit au modèle des fonctions (nom, description, paramètres attendus). Au lieu de répondre par du texte libre, il renvoie un appel structuré en JSON — par ex. jog_axis({axis:'Z', distance:10, feed:500}). C'est notre code déterministe qui exécute ensuite la vraie fonction."),
  ("Quel modèle utilises-tu ?","Gemini via l'API Google (Flash Lite par défaut), choisi pour son palier gratuit et son support du function calling. Le modèle est interchangeable — on bascule automatiquement entre plusieurs."),
  ("Donc c'est juste un wrapper autour de Gemini ?","Non. La valeur n'est pas le modèle, c'est la couche autour : 12 outils machine sûrs, un système de permissions, la validation de trajectoire, et la résilience réseau. Le modèle est un composant remplaçable ; notre IP est le contrôle industriel sûr."),
  ("Combien d'outils, et lesquels ?","12 outils : lire l'état machine, jog, homing, arrêt d'urgence, override d'avance et de broche, sélection et réglage de WCS, envoi de G-code, pause, reprise, reset. Voir le tableau plus haut."),
  ("Le LLM contrôle-t-il directement les moteurs ?","Jamais. Le modèle ne fait qu'émettre des appels d'outils. C'est l'application (code déterministe) qui parle au firmware FluidNC via WebSocket. Le LLM ne touche pas le matériel — il propose, l'app dispose."),
  ("Comment l'app parle-t-elle à la machine ?","En WebSocket (ws://IP:80) vers l'ESP32/FluidNC, protocole GRBL. Un parseur lit les rapports d'état en temps réel ; le streaming G-code utilise le « character-counting » pour ne jamais saturer le buffer de 128 octets."),
  ("Et le temps réel ? L'IA n'est pas trop lente ?","La boucle de contrôle moteur est gérée par FluidNC (temps réel matériel). L'IA agit au niveau haut (intentions, séquences). Les commandes critiques (arrêt jog, pause) court-circuitent le buffer et sont instantanées."),
  ("Ça marche sans Internet ?","Le contrôle de la machine est 100 % local (WiFi de la machine), sans Internet. Seul l'agent IA a besoin du réseau — et on résout ça avec le routage cellulaire."),
  ("Explique le routage cellulaire.","Le téléphone est connecté au point d'accès WiFi de l'ESP32, qui n'a pas d'Internet. Un pont natif Android force les appels de l'IA à passer par les données mobiles (4G/5G), pendant que le WiFi reste dédié à la machine. L'IA marche donc même sans Internet sur le WiFi."),
  ("Combien coûte l'IA à l'usage ?","≈ 0 pour l'utilisateur : on enchaîne les paliers gratuits de plusieurs modèles (~560 requêtes/jour cumulées). À terme, on vise de l'IA embarquée (edge/on-device) pour être totalement indépendant du réseau."),
  ("Que se passe-t-il si le quota est atteint ?","Sur un code 429 (quota épuisé), on bascule automatiquement vers le modèle suivant. Si tout est épuisé, l'utilisateur garde le contrôle manuel complet de la machine — l'IA est un plus, pas un point de défaillance."),
  ("L'IA garde-t-elle le contexte de la conversation ?","Oui. L'historique (format protocole + affichage) est persisté localement et survit au redémarrage de l'app, pour que l'agent ne perde jamais le fil."),
  ("Pourquoi une IA plutôt qu'une UI à boutons ?","Elle abaisse la barrière de compétence. Un opérateur peu formé exprime une intention (« palpe le centre de la pièce puis lance à 80 % d'avance ») et l'agent orchestre plusieurs étapes. C'est ça, le « next leap »."),
  ("Peux-tu joindre une image à l'IA ?","Oui, l'agent accepte une image jointe (ex. montrer une pièce ou un écran). L'image est envoyée au modèle mais n'est pas stockée, pour ne pas gonfler le stockage local."),
  ("Le modèle peut-il enchaîner plusieurs actions seul ?","Oui : c'est une boucle agentique. Il peut demander get_machine_state, puis home, puis select_wcs, puis jog — chaque résultat le renseigne pour l'étape suivante, jusqu'à finir la tâche."),
 ]),
 ("Sécurité", [
  ("Comment garantis-tu qu'un LLM ne casse pas la machine ?","Défense en couches : (1) permissions par catégorie d'action (confirmation demandée par défaut) ; (2) validation de trajectoire avant usinage ; (3) l'arrêt d'urgence toujours prioritaire ; (4) les limites logicielles et le watchdog de FluidNC. Le modèle est aussi instruit de demander une précision en cas d'ambiguïté."),
  ("C'est quoi la validation « lookahead » ?","Avant d'usiner un programme G-code, on simule tout le parcours d'outil contre les limites mécaniques réelles de la machine (course Z, plage angulaire A…). Si une ligne dépasse une limite, on refuse et on indique la ligne fautive — aucun mouvement dangereux n'est envoyé."),
  ("Comment fonctionnent les permissions ?","Chaque outil appartient à une catégorie (mouvement, broche, WCS, streaming). Par défaut chaque catégorie est en « confirmation requise » : l'app demande le feu vert de l'utilisateur avant d'exécuter. On peut passer une catégorie en autonome, au choix de l'utilisateur."),
  ("L'arrêt d'urgence passe-t-il par l'IA ?","Non. Il s'exécute immédiatement, sans confirmation, quels que soient les réglages. Techniquement il n'est rattaché à aucune catégorie gatée — c'est un impératif de sécurité."),
  ("Et si le réseau tombe en pleine action ?","Le contrôle local de la machine n'est pas affecté. Pour l'IA, l'action est ré-armée et repart automatiquement au retour de la 4G ; l'utilisateur peut aussi reprendre la main à tout moment."),
  ("Qui est responsable en cas d'accident ?","L'opérateur garde le contrôle : les actions sensibles sont confirmées, l'IA est un assistant et non un pilote autonome. On empile garde-fous logiciels et matériels pour rendre l'erreur difficile."),
  ("Et la confidentialité des données ?","La conversation est stockée localement sur l'appareil, pas sur un serveur. Les images ne sont pas persistées. Seul l'appel au modèle sort de l'appareil, en HTTPS chiffré."),
 ]),
 ("Marché & business", [
  ("Quelle est la taille du marché ?","Estimations à valider : TAM ~15 Mds FCFA/an (Afrique), SAM ~1,5 Md (Afrique de l'Ouest francophone), SOM ~30 M sur 2 ans. Aujourd'hui, ~0 % du marché est servi par une solution locale abordable."),
  ("Comment gagnes-tu de l'argent ?","Application freemium pour l'adoption, abonnement Pro (agent IA, multi-machines, analytics), bundles hardware certifiés (ESP32 + drivers pré-calibrés), puis une marketplace de configurations."),
  ("Tes prix ?","Application gratuite ; Pro ≈ ⟦__⟧ FCFA/an ; bundle hardware ≈ ⟦__⟧ FCFA. À affiner pendant le customer discovery."),
  ("Qui sont tes premiers clients ?","Fablabs, écoles techniques et ateliers d'usinage. Kouratechnique s'est déjà montré intéressé pour tester et adopter."),
  ("Combien de clients en année 1 ?","Objectif d'amorçage ≈ ⟦__⟧ (SOM ~300 unités sur 2 ans), en commençant par le Mali."),
  ("Comment acquiers-tu les clients ?","Démonstrations et vidéos courtes, partenariats institutionnels (écoles, hubs), bouche-à-oreille, et les bundles certifiés comme porte d'entrée hardware."),
  ("Quelle marge / coût d'acquisition ?","Marge logicielle élevée + marge sur le hardware ; le freemium réduit le coût d'acquisition. Les chiffres précis font partie de ce que je veux établir pendant Wadhwani."),
  ("Pourquoi maintenant ?","Deux courbes se croisent : le hardware CNC est devenu quasi gratuit (FluidNC/ESP32) et le function-calling des LLM rend le pilotage en langage naturel fiable."),
  ("Comment ça devient rentable ?","Revenu récurrent (Pro) + hardware, avec un coût d'infrastructure IA très faible (paliers gratuits aujourd'hui, edge demain)."),
 ]),
 ("Concurrence", [
  ("Qui sont tes concurrents ?","Les contrôleurs propriétaires (Fanuc, Heidenhain, Siemens) : puissants mais chers et fermés. Les « senders » GRBL gratuits : bon marché mais sans vrai 5-axes ni IA. Mach3/LinuxCNC : puissants mais liés au PC et complexes."),
  ("Qu'est-ce qui t'empêche d'être copié ?","La couche de sécurité (validation lookahead + permissions), les configurations machines certifiées, et les données d'usinage réelles qui améliorent l'agent. Ça prend du temps à construire."),
  ("Un gros acteur (Fanuc) peut-il faire pareil ?","Leur modèle repose sur du matériel cher et fermé ; ils ont peu d'intérêt à casser leurs propres prix. Moi je pars du low-cost + IA + terrain africain — un angle qu'ils ne servent pas."),
  ("Et si Gemini ou OpenAI ajoutent le contrôle machine ?","Ils font le modèle, pas l'intégration hardware + sécurité + terrain. Forgeron est la couche verticale qui rend un LLM sûr et utile sur une vraie machine — c'est justement ce qui manque."),
 ]),
 ("Équipe, exécution, programme", [
  ("Qui es-tu, et ton équipe ?","Lamine SACKO, fondateur et ingénieur : j'ai construit Forgeron de bout en bout (firmware, protocole temps réel, application, agent IA). Aboubacar DIAMOUTÉNÉ, technicien électronique et assemblage. Un poste business/commercial est ouvert."),
  ("Tu es surtout technique — et le côté business ?","J'en suis conscient, et c'est une raison d'être ici : le parcours Wadhwani et un profil commercial. J'ai déjà fait les premiers pas (conversation avec Kouratechnique)."),
  ("Combien de temps pour construire la machine ?","⟦à compléter⟧ — et coût de construction ≈ ⟦__⟧ FCFA."),
  ("Pourquoi ce programme ?","Le prototype existe ; il faut bâtir la venture. Le skilling IA (Ethiopian AI Institute) pour durcir l'agent, le parcours Wadhwani pour valider le marché et l'investment readiness, et le réseau timbuktoo."),
  ("Que feras-tu du soutien / financement ?","Durcir l'agent IA (edge), déployer des pilotes terrain (Kouratechnique + ateliers), mener le customer discovery, et — si financement — hardware pour pilotes, développement IA et fonds de roulement."),
  ("Où sera Forgeron dans 3 ans ?","Des contrôleurs Forgeron dans les ateliers d'Afrique de l'Ouest et de l'Est, produisant localement ce qui est aujourd'hui importé — et créant des emplois qualifiés."),
 ]),
]

def esc(s): return html.escape(s)

tools_rows = "".join(
  f'<tr><td class="tname">{esc(n)}</td><td>{esc(d)}</td><td class="tcat">{esc(c)}</td></tr>'
  for (n,d,c) in TOOLS)

qa_html=""; qn=0
for section, items in QA:
    qa_html += f'<h2 class="sec">{esc(section)}</h2>'
    for q,a in items:
        qn+=1
        qa_html += (f'<div class="qa"><div class="q"><span class="num">{qn}</span>{esc(q)}</div>'
                    f'<div class="a">{esc(a)}</div></div>')

HTML = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<title>Forgeron — Agent IA & 50 Q/R</title>
<style>
  :root{{--ink:#16202b;--ink2:#39434f;--mut:#6b7686;--forge:#d2560f;--forge2:#ff6a1a;
    --line:#e4e8ee;--soft:#f6f8fb;--ai:#0e5bd8;--ai-soft:#eef4fe;--ok:#0f9d58;--ok-soft:#e9f7ef;--steel:#1f2733;}}
  *{{box-sizing:border-box;margin:0;padding:0;}}
  html,body{{color:var(--ink);font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;background:#fff;}}
  @page{{size:A4;margin:14mm 13mm;}}
  .top{{display:flex;align-items:center;gap:12px;border-bottom:3px solid var(--forge);padding-bottom:10px;margin-bottom:14px;}}
  .top img{{width:44px;height:44px;border-radius:10px;}}
  h1{{font-size:21px;}} .top .sub{{font-size:11px;color:var(--mut);text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-top:2px;}}
  h2{{font-size:15px;color:var(--forge);margin:18px 0 9px;padding-bottom:4px;border-bottom:1px solid var(--line);}}
  h2.sec{{color:#fff;background:var(--steel);border:none;border-radius:8px;padding:7px 12px;margin:20px 0 10px;font-size:13px;text-transform:uppercase;letter-spacing:.6px;}}
  h3{{font-size:13px;color:var(--steel);margin:12px 0 5px;}}
  p{{margin-bottom:8px;color:var(--ink2);}} b{{color:var(--ink);}}
  .lead{{font-size:13px;background:var(--soft);border:1px solid var(--line);border-radius:10px;padding:11px 13px;margin-bottom:10px;}}
  ol.flow{{margin:6px 0 10px 20px;}} ol.flow li{{margin-bottom:5px;color:var(--ink2);}}
  table{{width:100%;border-collapse:collapse;margin:8px 0 12px;font-size:11px;}}
  th{{background:var(--steel);color:#fff;text-align:left;padding:6px 8px;font-size:10px;text-transform:uppercase;letter-spacing:.4px;}}
  td{{border:1px solid var(--line);padding:5px 8px;vertical-align:top;color:var(--ink2);}}
  td.tname{{font-family:'Courier New',monospace;font-weight:700;color:var(--forge);white-space:nowrap;}}
  td.tcat{{color:var(--mut);white-space:nowrap;}}
  .box{{border:1px solid var(--line);border-left:3px solid var(--ai);border-radius:8px;padding:10px 12px;margin:8px 0;background:var(--ai-soft);}}
  .box.ok{{border-left-color:var(--ok);background:var(--ok-soft);}}
  .box b{{color:var(--ink);}}
  .qa{{border:1px solid var(--line);border-radius:8px;padding:8px 11px;margin-bottom:7px;page-break-inside:avoid;}}
  .qa .q{{font-weight:700;color:var(--ink);font-size:12px;}}
  .qa .q .num{{display:inline-block;min-width:20px;height:18px;background:var(--forge);color:#fff;border-radius:5px;text-align:center;font-size:10px;line-height:18px;margin-right:7px;}}
  .qa .a{{font-size:11.5px;color:var(--ink2);margin-top:4px;}}
  .foot{{margin-top:14px;padding-top:8px;border-top:1px solid var(--line);font-size:9.5px;color:var(--mut);}}
  .partsplit{{page-break-before:always;}}
</style></head><body>

<div class="top"><img src="{logo_uri}" alt="Forgeron">
  <div><h1>Agent IA de Forgeron — fonctionnement & 50 Q/R</h1>
    <div class="sub">Préparation entretien UNIPOD AI · Lamine SACKO</div></div></div>

<h2>PARTIE 1 — Comment fonctionne l'agent IA (concrètement)</h2>
<div class="lead"><b>En une phrase :</b> l'agent est un <b>grand modèle de langage (Gemini) branché sur la machine via le « function calling »</b> — l'utilisateur exprime une intention en langage naturel, le modèle choisit des <b>outils</b>, et notre application (code déterministe) les exécute sur la CNC, en toute sécurité.</div>

<h3>Le flux, étape par étape</h3>
<ol class="flow">
  <li>L'utilisateur écrit/dicte : «&nbsp;<i>fais l'origine, sélectionne G54, puis monte Z de 10&nbsp;mm à 500&nbsp;</i>&nbsp;».</li>
  <li>L'app envoie ce message à Gemini <b>avec le catalogue des 12 outils</b> et un <i>system prompt</i> (rôle : assistant CNC prudent, concis, qui confirme et demande en cas d'ambiguïté).</li>
  <li>Le modèle répond par un ou plusieurs <b>appels d'outils structurés</b> (JSON), pas du texte libre — ex. <code>home()</code>, puis <code>select_wcs(&#123;wcs:'G54'&#125;)</code>, puis <code>jog_axis(&#123;axis:'Z',distance:10,feed:500&#125;)</code>.</li>
  <li>Pour chaque appel, la <b>porte de permission</b> vérifie la catégorie : si « confirmation requise », l'app demande le feu vert de l'utilisateur avant d'exécuter.</li>
  <li>L'app exécute l'outil (envoi de la vraie commande à FluidNC en WebSocket) et renvoie le <b>résultat</b> au modèle (<code>functionResponse</code>).</li>
  <li>La boucle recommence : le modèle enchaîne les étapes jusqu'à produire une <b>réponse finale en clair</b> résumant ce qui a été fait.</li>
</ol>

<h3>Les 12 outils exposés au modèle</h3>
<table><thead><tr><th>Outil</th><th>Ce qu'il fait</th><th>Catégorie / permission</th></tr></thead>
<tbody>{tools_rows}</tbody></table>

<h3>La sécurité — défense en couches</h3>
<div class="box"><b>1. Garde-fous de l'agent.</b> Chaque outil a une catégorie (mouvement, broche, WCS, streaming) en <b>« confirmation requise » par défaut</b>. L'<b>arrêt d'urgence n'est jamais bloqué</b> : il s'exécute immédiatement. Le modèle est instruit de <b>demander une précision</b> plutôt que de deviner (position inconnue, jog important, changement d'origine…).</div>
<div class="box ok"><b>2. Sécurité machine.</b> Avant d'usiner un programme, la <b>validation « lookahead »</b> simule tout le parcours contre les limites mécaniques réelles (course Z, plage A) et <b>refuse</b> en indiquant la ligne fautive. S'ajoutent les <b>limites logicielles</b>, le <b>watchdog</b> (heartbeat 2&nbsp;s) et le character-counting de FluidNC. <b>Le LLM ne pilote jamais les moteurs directement</b> : il propose des appels, l'app déterministe décide et exécute.</div>

<h3>Connectivité & coût</h3>
<ol class="flow">
  <li><b>Contrôle 100&nbsp;% local</b> de la machine (WiFi de l'ESP32), sans Internet.</li>
  <li><b>Routage cellulaire :</b> le téléphone reste sur le WiFi machine, les appels IA sont forcés sur la 4G/5G par un pont natif → l'IA marche même sans Internet sur le WiFi.</li>
  <li><b>Coût ≈ 0 :</b> bascule automatique entre plusieurs modèles pour cumuler les paliers gratuits (~560&nbsp;requêtes/jour). Objectif : IA embarquée (edge).</li>
  <li><b>Résilience :</b> réponses en streaming (SSE), repli automatique, historique persisté localement.</li>
</ol>

<h3>Ce que l'agent NE fait pas (honnêteté)</h3>
<p>Il ne remplace pas la boucle de contrôle temps réel (gérée par FluidNC), il n'exécute pas d'action sensible sans permission, et il n'est pas un pilote autonome : c'est un <b>copilote</b> qui abaisse la barrière de compétence tout en gardant l'humain aux commandes.</p>

<div class="partsplit"></div>
<div class="top"><img src="{logo_uri}" alt="Forgeron">
  <div><h1>PARTIE 2 — 50 questions / réponses</h1>
    <div class="sub">À réviser avant l'entretien · réponds court, puis stoppe</div></div></div>
<p style="margin-bottom:10px;color:var(--mut);font-size:11px;">Les ⟦…⟧ sont tes vrais chiffres à compléter. Réponds en 2-3 phrases, avec assurance, et relie toujours à l'impact + le business.</p>
{qa_html}

<div class="foot">Forgeron · Préparation entretien UNIPOD AI Innovation Pipeline (timbuktoo / UNDP) — Lamine SACKO. Document de travail personnel.</div>
</body></html>"""

out = root / "scratch/aidoc.html"
out.write_text(HTML, encoding="utf-8")
print("written", out, len(HTML), "| questions:", qn)
