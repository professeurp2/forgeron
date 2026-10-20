#!/usr/bin/env python3
"""Fiche d'entretien 15 minutes — METI AI Innovation, entretien final."""
import subprocess
from pathlib import Path

OUT = Path("/tmp/claude-0/-home-user-forgeron/f115b2cf-c02c-5ae4-8f73-96461eacf843/scratchpad")
OUT.mkdir(parents=True, exist_ok=True)
CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"

def qa(num, question, secs, answer, note=None):
    n = f'<div class="note"><b>Attention&nbsp;:</b> {note}</div>' if note else ""
    body = "".join("<p>" + p + "</p>" for p in answer)
    return f"""
<section class="qa">
  <div class="qhd"><span class="qnum">{num}</span><h2>{question}</h2><span class="secs">{secs}</span></div>
  <div class="ans">{body}</div>{n}
</section>"""

Q1 = qa("1", "Pr&eacute;sentez-vous, et pr&eacute;sentez Forgeron.", "40 s",
    ["Je m'appelle Lamine SACKO, je suis ing&eacute;nieur en m&eacute;catronique, dipl&ocirc;m&eacute; de l'ENI-ABT &agrave; Bamako.",
     "Forgeron, c'est une <b>machine-outil CNC 5 axes</b> que nous avons con&ccedil;ue et construite au Mali. "
     "Elle co&ucirc;te environ <b>10 millions de FCFA</b>, contre 25 millions pour une machine import&eacute;e.",
     "Et surtout&nbsp;: <b>on ne la programme pas, on lui parle.</b> Un agent IA traduit une phrase en langage "
     "courant en mouvements machine s&ucirc;rs. Un atelier qui n'a jamais &eacute;crit une ligne de G-code peut donc "
     "produire des pi&egrave;ces complexes.",
     "<b>La machine est construite et elle fonctionne aujourd'hui.</b>"],
    note="C'est l'ouverture. Elle doit sortir sans h&eacute;sitation. Termine sur &laquo;&nbsp;elle fonctionne "
         "aujourd'hui&nbsp;&raquo; &mdash; c'est ce qui te distingue de la majorit&eacute; des candidats.")

Q2 = qa("2", "Concr&egrave;tement, o&ugrave; est l'IA dans votre produit&nbsp;?", "50 s",
    ["C'est un <b>agent</b>, pas un chatbot. Un grand mod&egrave;le de langage &agrave; qui on a donn&eacute; "
     "<b>12 outils de commande machine</b>, qu'il appelle lui-m&ecirc;me&nbsp;: d&eacute;placement, broche, "
     "arrosage, changement d'outil, origines pi&egrave;ce.",
     "Trois couches de s&eacute;curit&eacute; par-dessus&nbsp;:",
     "&mdash; Avant tout mouvement, le syst&egrave;me <b>simule la trajectoire enti&egrave;re</b>. Si l'outil "
     "heurterait la table ou sortait de la course, l'ordre est refus&eacute; et la machine ne bouge pas.",
     "&mdash; Un <b>syst&egrave;me de permissions</b>&nbsp;: l'agent propose, annonce ce qu'il va faire, et "
     "<b>attend la confirmation de l'op&eacute;rateur</b>.",
     "&mdash; <b>L'arr&ecirc;t d'urgence n'est jamais filtr&eacute; par l'IA.</b> Elle ne peut ni le bloquer, "
     "ni le retarder.",
     "<b>L'IA ne commande pas. L'op&eacute;rateur commande. L'IA enl&egrave;ve la barri&egrave;re.</b>"],
    note="C'est un programme <b>IA</b>&nbsp;: ils v&eacute;rifient que l'IA est r&eacute;elle, pas une &eacute;tiquette. "
         "Garde la derni&egrave;re phrase pour la fin, c'est elle qu'on retient.")

Q3 = qa("3", "O&ugrave; en &ecirc;tes-vous&nbsp;? Avez-vous des clients&nbsp;?", "45 s",
    ["Je vais &ecirc;tre pr&eacute;cis, et honn&ecirc;te.",
     "<b>Ce qui existe&nbsp;:</b> la machine 5 axes est construite et op&eacute;rationnelle. L'application et "
     "l'agent IA tournent sur le mat&eacute;riel r&eacute;el, pas en simulation. Le code est ouvert. Nous avons "
     "une vid&eacute;o de d&eacute;monstration de la machine en fonctionnement.",
     "<b>Ce qui n'existe pas encore&nbsp;:</b> nous n'avons <b>pas de client payant</b>. Nous avons eu une "
     "premi&egrave;re conversation avec un atelier de Bamako, Kouratechnique, pour un test en production r&eacute;elle.",
     "Donc&nbsp;: une machine qui marche, et nos premi&egrave;res conversations clients."],
    note="<b>Ne gonfle rien.</b> &Agrave; ce stade, ils v&eacute;rifient surtout ton honn&ecirc;tet&eacute;. "
         "Une machine qui fonctionne sans client vaut mieux qu'un chiffre invent&eacute; qu'on d&eacute;monte en deux questions.")

Q4 = qa("4", "&Ecirc;tes-vous disponible pour Addis-Abeba, du 9 au 20 novembre&nbsp;? "
             "Avez-vous un passeport&nbsp;?", "20 s",
    ["<b>Oui. Passeport en cours de validit&eacute;, et je suis enti&egrave;rement disponible sur ces dates.</b>",
     "J'ai d&eacute;j&agrave; commenc&eacute; &agrave; pr&eacute;parer les d&eacute;marches de visa pour l'&Eacute;thiopie."],
    note="Cette question est <b>quasi certaine</b> &mdash; ils te l'ont d&eacute;j&agrave; pos&eacute;e au premier "
         "entretien. R&eacute;ponds <b>court et net</b>. Aucune h&eacute;sitation, aucun &laquo;&nbsp;je pense "
         "que oui&nbsp;&raquo;. C'est une question &eacute;liminatoire d&eacute;guis&eacute;e en formalit&eacute;.")

Q5 = qa("5", "Comment gagnez-vous de l'argent&nbsp;?", "35 s",
    ["Deux sources.",
     "<b>La machine</b>&nbsp;: nous vendons la machine compl&egrave;te, 10 millions de FCFA, contre environ "
     "25 millions &agrave; l'import.",
     "<b>L'abonnement &agrave; l'agent IA</b>&nbsp;: 25&nbsp;000 FCFA par mois, soit 300&nbsp;000 par an et par machine.",
     "Notre avantage de co&ucirc;t vient de notre contr&ocirc;leur&nbsp;: il tourne sur un microcontr&ocirc;leur "
     "&agrave; environ <b>8 dollars</b>, l&agrave; o&ugrave; l'industrie utilise des baies de commande propri&eacute;taires."],
    note="Si on te parle du &laquo;&nbsp;contr&ocirc;leur &agrave; 8&nbsp;$&nbsp;&raquo;, la phrase de "
         "r&eacute;conciliation est&nbsp;: <b>&laquo;&nbsp;Le 8&nbsp;$, c'est notre co&ucirc;t de contr&ocirc;leur. "
         "Le client, lui, ach&egrave;te une machine compl&egrave;te &agrave; 10&nbsp;M au lieu de 25&nbsp;M.&nbsp;&raquo;</b>")

Q6 = qa("6", "Qu'attendez-vous du programme&nbsp;? Qu'est-ce qui vous bloque&nbsp;?", "40 s",
    ["Je suis ing&eacute;nieur. <b>Construire la machine n'a jamais &eacute;t&eacute; le plus difficile.</b>",
     "Ce que je ne savais pas faire, c'est <b>parler aux clients, dimensionner un march&eacute;, expliquer le "
     "mod&egrave;le &eacute;conomique</b>. C'est exactement ce que ce programme me force &agrave; apprendre.",
     "Ce dont j'ai besoin&nbsp;: des <b>ateliers pilotes</b>, des <b>partenaires industriels</b> pour produire "
     "une premi&egrave;re s&eacute;rie, et un <b>accompagnement commercial</b>.",
     "C'est inconfortable. C'est &agrave; &ccedil;a que je vois que &ccedil;a marche."],
    note="<b>La question la plus importante de l'entretien.</b> Tout le monde r&eacute;pond &laquo;&nbsp;du "
         "r&eacute;seau et du financement&nbsp;&raquo;. Toi, tu nommes pr&eacute;cis&eacute;ment ta faiblesse "
         "&mdash; et c'est ce qui te rendra cr&eacute;dible et m&eacute;morable.")

BONUS = """
<section class="bonus">
  <div class="bhd">&#43; Trois questions possibles &mdash; r&eacute;ponses en une phrase</div>
  <table>
    <tr><td class="bq">Qui est dans l'&eacute;quipe&nbsp;?</td>
        <td>Nous sommes deux&nbsp;: moi, et Aboubacar Diamout&eacute;n&eacute;, technicien &eacute;lectronique et
        assemblage. Le poste commercial est ouvert &mdash; c'est notre prochain recrutement.</td></tr>
    <tr><td class="bq">Qu'est-ce qui vous diff&eacute;rencie&nbsp;?</td>
        <td>Les autres baissent le prix de la machine. Nous, on supprime aussi le besoin d'un programmeur CNC
        &mdash; <b>ce n'est pas seulement le prix de la machine, c'est le prix de la personne qui la fait tourner.</b></td></tr>
    <tr><td class="bq">Et si quelqu'un copie&nbsp;?</td>
        <td>Le code est ouvert, oui. Ce qui ne se copie pas&nbsp;: la machine assembl&eacute;e, la cha&icirc;ne
        de montage locale, le service apr&egrave;s-vente au Mali, et les donn&eacute;es d'usage qui am&eacute;liorent l'agent.</td></tr>
  </table>
</section>"""

CSS = """
@page { size: A4; margin: 11mm 13mm; }
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: "DejaVu Sans","Liberation Sans",sans-serif; color:#1f2733; margin:0;
       font-size:9pt; line-height:1.4; }
h1,h2 { margin:0; }
.hero { border-bottom:3px solid #c8551a; padding-bottom:7px; margin-bottom:9px; }
.kick { font-size:7pt; letter-spacing:.14em; text-transform:uppercase; color:#8b7a6a; font-weight:bold; }
.hero h1 { font-size:18pt; margin:2px 0 1px; }
.sub { font-size:9pt; color:#5a6675; font-weight:bold; }
.alert { margin-top:7px; background:#1f2733; color:#fff; border-radius:4px; padding:7px 11px; }
.alert b { color:#ff9a5c; }
.a1 { font-size:12pt; font-weight:bold; display:block; }
.a2 { font-size:8.4pt; display:block; margin-top:2px; }
.three { display:grid; grid-template-columns:repeat(3,1fr); gap:7px; margin:8px 0 10px; }
.card { border:1.5px solid #c8551a; border-radius:4px; padding:6px 8px; background:#fff7f2; }
.cardhd { font-size:6.8pt; letter-spacing:.1em; text-transform:uppercase; color:#a8410f;
          font-weight:bold; margin-bottom:3px; }
.card p { margin:0; font-size:8.2pt; }
.qa { margin-bottom:10px; break-inside:avoid; }
.qhd { display:flex; align-items:center; gap:8px; border-bottom:1.5px solid #1f2733;
       padding-bottom:3px; margin-bottom:5px; }
.qnum { flex:0 0 auto; width:19px; height:19px; background:#c8551a; color:#fff; border-radius:3px;
        text-align:center; line-height:19px; font-weight:bold; font-size:10pt; }
.qhd h2 { font-size:11pt; flex:1; }
.secs { font-family:"DejaVu Sans Mono",monospace; font-size:8pt; color:#fff; background:#1f2733;
        padding:2px 6px; border-radius:3px; white-space:nowrap; }
.ans { border-left:3px solid #c8551a; background:#fffdfb; padding:5px 9px; }
.ans p { margin:0 0 3px; font-size:9.6pt; line-height:1.45; }
.ans p:last-child { margin-bottom:0; }
.note { font-size:8pt; color:#6b5c4e; background:#fdf8f2; border-radius:3px; padding:4px 8px; margin-top:4px; }
.bonus { border:1.5px solid #1f2733; border-radius:4px; margin-top:4px; break-inside:avoid; }
.bhd { background:#1f2733; color:#fff; font-weight:bold; font-size:9pt; padding:4px 10px; }
.bonus table { width:100%; border-collapse:collapse; font-size:8.4pt; }
.bonus td { padding:5px 9px; border-bottom:1px solid #edf0f4; vertical-align:top; }
.bq { width:27%; font-weight:bold; color:#a8410f; }
.foot { margin-top:9px; background:#fff3ec; border-left:3px solid #c8551a; padding:6px 10px;
        font-size:8.4pt; border-radius:0 3px 3px 0; break-inside:avoid; }
"""

DOC = f"""<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<title>Forgeron — Fiche entretien METI</title><style>{CSS}</style></head><body>
<header class="hero">
  <div class="kick">METI AI Innovation Programme &middot; UniPods / timbuktoo / PNUD &middot; Entretien final</div>
  <h1>Fiche d'entretien &mdash; 15 minutes</h1>
  <div class="sub">FORGERON &middot; Lamine SACKO &middot; mercredi 21 octobre 2026, 14h15 &agrave; Bamako &middot; Teams</div>
  <div class="alert">
    <span class="a1">&#9201; 15 minutes &mdash; soit 10 &agrave; 12 min utiles, 4 &agrave; 6 questions.</span>
    <span class="a2">R&eacute;ponds en <b>45 secondes</b>, puis <b>arr&ecirc;te-toi</b>. Le silence apr&egrave;s une
    r&eacute;ponse courte n'est pas un vide &agrave; combler &mdash; c'est eux qui encha&icirc;nent.
    Si tu parles 3 minutes sur la premi&egrave;re question, tu as br&ucirc;l&eacute; un quart de l'entretien.</span>
  </div>
</header>

<div class="three">
  <div class="card"><div class="cardhd">&#9679; &Agrave; faire passer 1</div>
    <p><b>La machine existe et elle tourne.</b> Une 5 axes qui coupe du m&eacute;tal &agrave; Bamako. Pas une maquette.</p></div>
  <div class="card"><div class="cardhd">&#9679; &Agrave; faire passer 2</div>
    <p><b>L'IA enl&egrave;ve la barri&egrave;re de l'op&eacute;rateur.</b> Pas seulement moins cher&nbsp;: utilisable sans programmeur CNC.</p></div>
  <div class="card"><div class="cardhd">&#9679; &Agrave; faire passer 3</div>
    <p><b>Disponible pour Addis, 9&ndash;20 novembre.</b> Passeport en main. Sans h&eacute;siter.</p></div>
</div>

{Q1}{Q2}{Q3}{Q4}{Q5}{Q6}{BONUS}

<div class="foot">
  <b>Les trois r&eacute;flexes.</b>
  <b>1.</b> Ne pr&eacute;pare pas une pr&eacute;sentation &mdash; au premier entretien, ils ne t'ont m&ecirc;me pas
  laiss&eacute; pitcher. Pr&eacute;pare des r&eacute;ponses.
  <b>2.</b> Si une question te surprend, prends deux secondes avant de r&eacute;pondre. Deux secondes de silence
  passent mieux qu'une minute de remplissage.
  <b>3.</b> Si &agrave; la fin ils ne t'ont pas pos&eacute; la question&nbsp;4 (Addis), <b>dis-le toi-m&ecirc;me
  avant de raccrocher</b>&nbsp;: &laquo;&nbsp;Je confirme que je suis disponible du 9 au 20 novembre.&nbsp;&raquo;
</div>
</body></html>"""

html_path = OUT / "fiche_meti.html"
html_path.write_text(DOC, encoding="utf-8")
pdf = Path("/home/user/forgeron/scratch/Forgeron_Fiche_Entretien_METI.pdf")
subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                "--no-pdf-header-footer", f"--print-to-pdf={pdf}", f"file://{html_path}"],
               check=True, capture_output=True)
print("PDF:", pdf, pdf.stat().st_size, "bytes")
