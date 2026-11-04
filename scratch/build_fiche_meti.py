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
    ["<b>Oui. Passeport en cours de validit&eacute;, et je suis enti&egrave;rement disponible.</b>",
     "J'ai lu la note de cadrage&nbsp;: <b>arriv&eacute;e le dimanche 8 et d&eacute;part le samedi 21</b>, "
     "je suis disponible sur toute la p&eacute;riode.",
     "J'ai d&eacute;j&agrave; commenc&eacute; les d&eacute;marches de visa pour l'&Eacute;thiopie."],
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

NONTECH = """
<div class="pb"></div>
<section class="blk">
  <div class="blkhd"><span class="bnum">&#9888;</span><h2>FACE &Agrave; QUELQU'UN QUI NE CONNA&Icirc;T PAS L'USINAGE</h2></div>
  <div class="frame">
    <p>La derni&egrave;re fois, ton interlocuteur ne connaissait pas les machines-outils.
    <b>C'est le cas le plus probable demain aussi</b>, et ce n'est pas un accident&nbsp;: le jury
    s&eacute;lectionne sur 244 projets dont les th&egrave;mes dominants sont la sant&eacute;,
    l'&eacute;ducation et l'inclusion financi&egrave;re. Du logiciel, presque partout.</p>
    <p><b>Quelqu'un qui ne conna&icirc;t pas la CNC ne peut pas juger ta technologie.</b> Il juge donc
    autre chose&nbsp;: est-ce que tu es clair, est-ce que le mod&egrave;le tient debout, et est-ce qu'on a
    envie de travailler deux semaines avec toi &agrave; Addis. <b>Si ta frustration se voit, elle
    r&eacute;pond &laquo;&nbsp;non&nbsp;&raquo; &agrave; la troisi&egrave;me question.</b></p>
    <p class="hi">Et c'est exactement la comp&eacute;tence que tu dis vouloir acqu&eacute;rir. Si tu ne sais
    pas faire comprendre Forgeron &agrave; un non-sp&eacute;cialiste en 40 secondes, tu ne sauras le vendre
    ni &agrave; un acheteur, ni &agrave; un investisseur. <b>L'entretien de demain n'est pas un obstacle
    &agrave; ta pr&eacute;paration&nbsp;: il en fait partie.</b></p>
  </div>

  <div class="subhd">Traduis &mdash; ne dis pas &#8594; dis plut&ocirc;t</div>
  <table class="tr">
    <tr><th>Ne dis pas</th><th>Dis plut&ocirc;t</th></tr>
    <tr><td>Une CNC 5 axes</td><td>Une machine qui <b>taille une pi&egrave;ce complexe dans un bloc de m&eacute;tal</b>, &agrave; partir d'un dessin sur ordinateur</td></tr>
    <tr><td>Cinq axes</td><td>Elle attaque la pi&egrave;ce <b>sous tous les angles</b> &mdash; c'est ce qu'il faut pour les formes courbes. Une machine ordinaire ne fait que des formes simples.</td></tr>
    <tr><td>Du G-code</td><td>La langue de la machine&nbsp;: <b>des milliers de lignes de coordonn&eacute;es</b> qu'un sp&eacute;cialiste &eacute;crit &agrave; la main</td></tr>
    <tr><td>Un programmeur CNC</td><td>Un sp&eacute;cialiste <b>qu'on ne trouve presque pas au Mali</b>, et qu'un petit atelier ne peut pas payer</td></tr>
    <tr><td><i>Function calling</i>, agent LLM</td><td><b>On lui parle</b>, en fran&ccedil;ais ou en anglais, et elle ex&eacute;cute</td></tr>
    <tr><td>Validation <i>lookahead</i> de trajectoire</td><td>Avant de bouger, elle <b>simule le trajet entier</b>. Si l'outil allait taper, elle refuse.</td></tr>
    <tr><td>ESP32, FluidNC</td><td>Un <b>microcontr&ocirc;leur &agrave; 8 dollars</b>, au lieu d'une armoire de commande propri&eacute;taire</td></tr>
    <tr><td>Trunnion, axes A et C</td><td>Un <b>plateau qui fait pivoter la pi&egrave;ce</b> dans deux directions</td></tr>
  </table>

  <div class="two">
    <div class="box">
      <div class="boxhd">La r&egrave;gle des deux temps</div>
      <p>Apr&egrave;s chaque fait technique, dis <b>ce que &ccedil;a change pour l'argent ou le risque</b>. Jamais le fait tout seul.</p>
      <p>&laquo;&nbsp;Cinq axes&nbsp;&raquo; &#8594; <i>c'est le travail que les ateliers refusent aujourd'hui.</i></p>
      <p>&laquo;&nbsp;On lui parle&nbsp;&raquo; &#8594; <i>pas besoin d'embaucher un sp&eacute;cialiste introuvable.</i></p>
      <p>&laquo;&nbsp;Elle simule avant de bouger&nbsp;&raquo; &#8594; <i>un d&eacute;butant ne peut pas casser une machine &agrave; 10 millions.</i></p>
    </div>
    <div class="box">
      <div class="boxhd">L'image qui marche &agrave; tous les coups</div>
      <p>Quand tu sens qu'il ne suit pas, <b>n'ajoute pas de d&eacute;tail&nbsp;: enl&egrave;ves-en</b>, et reviens &agrave; un objet concret.</p>
      <p class="quote">&laquo;&nbsp;Une pi&egrave;ce de moto ou de pompe &agrave; eau qui casse. On ne la trouve pas au Mali. L'atelier d'&agrave; c&ocirc;t&eacute; ne sait pas la refaire. Il faut l'importer, attendre trois semaines, et payer trois fois le prix.&nbsp;&raquo;</p>
      <p>&Ccedil;a, <b>tout le monde le comprend</b> &mdash; y compris quelqu'un qui n'a jamais vu un atelier.</p>
    </div>
  </div>

  <div class="reflex">
    <b>&#9679; Ne dis jamais &laquo;&nbsp;comme je l'ai expliqu&eacute;&nbsp;&raquo;</b>, ne soupire pas, ne l&egrave;ve pas les yeux.
    Une question na&iuml;ve est une bonne question &mdash; traite-la comme telle.
    <b>&#9679; Garde le lien de ta vid&eacute;o ouvert.</b> &laquo;&nbsp;Je peux vous envoyer 30 secondes de la machine
    en fonctionnement&nbsp;&raquo; &mdash; et tu le colles dans le chat Teams. <b>Vingt secondes d'image valent mieux
    que deux minutes d'explication</b>, surtout avec quelqu'un qui n'arrive pas &agrave; se repr&eacute;senter l'objet.
  </div>
</section>

<section class="blk">
  <div class="blkhd"><span class="bnum">&#9733;</span><h2>CE QUE DIT LE PROGRAMME D'ADDIS &mdash; &agrave; utiliser demain</h2></div>
  <table class="tr arg">
    <tr><td class="an">1</td><td><b>Tu es le probl&egrave;me que le programme veut r&eacute;soudre.</b>
      Le document s'ouvre l&agrave;-dessus&nbsp;: beaucoup de comp&eacute;tences form&eacute;es, tr&egrave;s peu
      de produits que quelqu'un paie. Toi&nbsp;: machine construite, agent IA qui tourne, <b>z&eacute;ro client
      payant</b>. Tu n'es pas un candidat <i>malgr&eacute;</i> cette faiblesse &mdash; tu es leur cas d'usage.</td></tr>
    <tr><td class="an">2</td><td><b>Ta r&eacute;ponse &agrave; la question&nbsp;6 est align&eacute;e au mot pr&egrave;s.</b>
      Les fondateurs de la cohorte ont eux-m&ecirc;mes class&eacute; en t&ecirc;te de leurs besoins
      <b>la validation du mod&egrave;le &eacute;conomique</b> et <b>l'acc&egrave;s aux investisseurs</b>.
      C'est exactement ce que tu comptais dire. Ne change rien.</td></tr>
    <tr><td class="an">3</td><td><b>&#128273; Le laboratoire de robotique &mdash; ton argument unique.</b>
      Le UniPod d'Addis a du calcul GPU et un <b>laboratoire de robotique sur place</b>. Les th&egrave;mes
      dominants de la cohorte sont la sant&eacute;, l'&eacute;ducation, la finance &mdash; du logiciel.
      <b>Tu es l'un des tr&egrave;s rares &agrave; avoir du mat&eacute;riel r&eacute;el.</b>
      <span class="say2">&laquo;&nbsp;Il y a un laboratoire de robotique et du calcul sur place. Je suis
      l'un des rares de la cohorte &agrave; avoir une machine physique&nbsp;: je peux y optimiser le
      contr&ocirc;leur, tester la validation de trajectoire et faire tourner mon agent sur du vrai calcul.
      Cette infrastructure, je ne l'ai pas &agrave; Bamako.&nbsp;&raquo;</span></td></tr>
    <tr><td class="an">4</td><td><b>Les vraies dates&nbsp;: dimanche 8 &#8594; samedi 21 novembre.</b>
      L'email disait 9&ndash;20, mais le planning pr&eacute;voit l'arriv&eacute;e le <b>dim. 8</b> et les
      d&eacute;parts le <b>sam. 21</b> &mdash; <b>14 nuits</b>. Si on te parle logistique, montre que tu as
      lu le document&nbsp;: &ccedil;a se remarque.</td></tr>
  </table>
  <div class="odds"><b>Et garde &ccedil;a en t&ecirc;te sans le dire&nbsp;:</b> la r&eacute;sidence ne prend que
  <b>les 50 meilleures &eacute;quipes</b> sur les 244 de la cohorte &mdash; environ <b>7&nbsp;% des 670
  candidats de d&eacute;part</b>. L'entretien de demain, ce n'est pas une formalit&eacute;&nbsp;: c'est un
  entonnoir d'environ <b>1 sur 5</b>.</div>
</section>
"""

GRILLE = """
<div class="pb"></div>
<section class="blk">
  <div class="blkhd"><span class="bnum">&#9878;</span><h2>LA GRILLE DE NOTATION &mdash; ce sur quoi tu es jug&eacute;</h2></div>
  <div class="frame">
    <p>Le guide de s&eacute;lection donne le bar&egrave;me exact. <b>100 points en tout</b>&nbsp;:
    <b>50 pour ton effort sur le programme</b> (Wadhwani, MIT, Abaca) &mdash; <b>d&eacute;j&agrave; fig&eacute;,
    plus rien &agrave; y faire</b> &mdash; et <b>50 pour l'entretien</b>. Autrement dit&nbsp;:
    <b>la moiti&eacute; de ta note se joue en 10 minutes, cet apr&egrave;s-midi.</b></p>
  </div>
  <table class="tr grid">
    <tr><th>Crit&egrave;re de l'entretien</th><th class="pt">Points</th></tr>
    <tr><td>Maturit&eacute; de la solution</td><td class="pt">10</td></tr>
    <tr><td>Qualit&eacute; de la solution</td><td class="pt">10</td></tr>
    <tr><td>Rigueur technique</td><td class="pt">10</td></tr>
    <tr class="big"><td><b>Ce que l'&eacute;quipe va apporter au bootcamp</b></td><td class="pt">20</td></tr>
  </table>
  <div class="hi2"><b>&#9888; Le plus gros bloc n'est pas technique.</b> Il vaut <b>le double</b> de n'importe
  quel crit&egrave;re technique, et c'est celui que personne ne pr&eacute;pare. La question
  &laquo;&nbsp;qu'est-ce que vous apportez au bootcamp&nbsp;?&nbsp;&raquo; n'est pas une politesse de fin
  d'entretien&nbsp;: <b>c'est 40&nbsp;% de ta note.</b> Si on ne te la pose pas, <b>pose-la toi-m&ecirc;me.</b></div>

  <div class="subhd">Ta r&eacute;ponse aux 20 points &mdash; &agrave; placer absolument</div>
  <div class="say3">
    <p>&laquo;&nbsp;Trois choses, concr&egrave;tement.</p>
    <p><b>D'abord, le METI est le minist&egrave;re japonais de l'industrie &mdash; et le Japon est le
    leader mondial de la machine-outil et de la robotique industrielle.</b> Dans une cohorte de
    sant&eacute;, d'&eacute;ducation et de finance, Forgeron est le seul projet dont le secteur est
    exactement celui o&ugrave; les entreprises japonaises sont les meilleures. Pour vos mises en relation,
    je suis le partenaire &eacute;vident.</p>
    <p><b>Ensuite, j'apporte du mat&eacute;riel r&eacute;el.</b> Vous avez un laboratoire de robotique et
    du calcul &agrave; Addis. Je suis l'un des rares &agrave; avoir une machine physique&nbsp;: je vais
    r&eacute;ellement m'en servir, et les autres fondateurs verront ce que &ccedil;a veut dire de faire
    tourner de l'IA sur du mat&eacute;riel.</p>
    <p><b>Enfin, j'ai une IA critique pour la s&eacute;curit&eacute;, qui tourne d&eacute;j&agrave;.</b>
    Permissions, validation avant mouvement, arr&ecirc;t d'urgence jamais filtr&eacute;. Votre journ&eacute;e 5
    porte sur l'IA responsable&nbsp;: moi, je l'ai impl&eacute;ment&eacute;e, sur une machine qui peut blesser
    quelqu'un. C'est quelque chose que je peux partager avec la cohorte.&nbsp;&raquo;</p>
  </div>
  <div class="note2">Et si tu veux une quatri&egrave;me&nbsp;: <b>ton code est ouvert</b>, donc r&eacute;utilisable
  par les autres &mdash; et <b>une machine qui tourne est la d&eacute;mo la plus m&eacute;morable</b> du
  Demo Day devant les investisseurs et les partenaires japonais.</div>
</section>

<section class="blk">
  <div class="blkhd"><span class="bnum">&#8505;</span><h2>TROIS CORRECTIONS DE DERNI&Egrave;RE MINUTE</h2></div>
  <table class="tr arg">
    <tr><td class="an">1</td><td><b>Tes chances sont bien meilleures que ce que je t'avais dit.</b>
      Seules <b>les 100 meilleures</b> candidatures (sur ~250) sont convoqu&eacute;es en entretien
      &mdash; <b>tu es d&eacute;j&agrave; pass&eacute; par ce filtre</b>. Et 50 partent &agrave; Addis.
      Donc &agrave; ce stade&nbsp;: <b>environ 1 sur 2</b>, pas 1 sur 5. Oublie ce que je t'ai dit hier.</td></tr>
    <tr><td class="an">2</td><td><b>L'entretien dure 10 minutes, pas 15.</b> Le cr&eacute;neau r&eacute;serv&eacute;
      est de 15 min, mais le guide pr&eacute;voit 10 min d'entretien. <b>Pr&eacute;pare-toi pour 10.</b>
      La r&egrave;gle des 45 secondes devient encore plus vitale&nbsp;: tu n'auras le temps que de
      <b>4 ou 5 questions</b>.</td></tr>
    <tr><td class="an">3</td><td><b>Tu as le droit de venir avec Aboubacar.</b> Le guide l'autorise
      express&eacute;ment, et n'importe quel membre peut r&eacute;pondre. Avec 20 points sur
      &laquo;&nbsp;ce que l'&eacute;quipe apporte&nbsp;&raquo;, montrer une vraie &eacute;quipe peut aider.
      <b>Mais seulement s'il est disponible et bri&eacute;f&eacute;</b> &mdash; un second silencieux et mal
      pr&eacute;par&eacute; vaut moins qu'un fondateur seul et net. &Agrave; toi de juger ce matin.</td></tr>
  </table>
  <div class="odds"><b>Ce qui reste vrai&nbsp;:</b> ta phase&nbsp;1 est fig&eacute;e, tu ne peux plus rien y
  changer. <b>Le seul levier qu'il te reste, c'est l'entretien &mdash; et il p&egrave;se la moiti&eacute; du
  total.</b> Tout se joue cet apr&egrave;s-midi, en 10 minutes.</div>
</section>
"""

CSS = """
@page { size: A4; margin: 11mm 13mm; }
.pb { break-before: page; }
.grid td { font-size:9.4pt; }
.grid .pt { text-align:right; font-weight:bold; width:60px; font-family:"DejaVu Sans Mono",monospace; }
.grid .big td { background:#1f2733; color:#fff; font-size:10.4pt; }
.hi2 { margin-top:7px; background:#fff3ec; border-left:3px solid #c8551a; padding:6px 10px;
       font-size:8.6pt; border-radius:0 3px 3px 0; }
.say3 { border-left:3px solid #c8551a; background:#fffdfb; padding:6px 10px; }
.say3 p { margin:0 0 5px; font-size:9.4pt; line-height:1.45; }
.say3 p:last-child { margin-bottom:0; }
.note2 { font-size:8.2pt; color:#6b5c4e; background:#fdf8f2; border-radius:3px; padding:5px 9px; margin-top:5px; }
.blk { margin-bottom: 11px; }
.blkhd { display:flex; align-items:center; gap:8px; border-bottom:1.5px solid #1f2733;
         padding-bottom:3px; margin-bottom:6px; break-after:avoid; }
.bnum { flex:0 0 auto; min-width:19px; padding:0 4px; height:19px; background:#c8551a; color:#fff;
        border-radius:3px; text-align:center; line-height:19px; font-weight:bold; font-size:10pt; }
.blkhd h2 { font-size:11.5pt; flex:1; }
.frame { border:1.5px solid #1f2733; border-radius:4px; padding:7px 10px; font-size:8.6pt; }
.frame p { margin:0 0 5px; }
.frame p:last-child { margin-bottom:0; }
.hi { background:#fff3ec; border-left:3px solid #c8551a; padding:5px 8px; border-radius:0 3px 3px 0; }
.subhd { font-size:9.4pt; font-weight:bold; color:#a8410f; margin:9px 0 3px; }
.tr { width:100%; border-collapse:collapse; font-size:8.3pt; }
.tr th { text-align:left; font-size:6.8pt; letter-spacing:.1em; text-transform:uppercase; color:#8894a5;
         border-bottom:1px solid #c9d0da; padding:3px 7px; }
.tr td { padding:4px 7px; border-bottom:1px solid #edf0f4; vertical-align:top; }
.tr td:first-child { width:30%; color:#8894a5; }
.arg td:first-child { width:auto; }
.arg tr { break-inside: avoid; }
.odds { break-inside: avoid; }
.an { width:20px !important; font-weight:bold; color:#fff !important; background:#1f2733;
      text-align:center; border-radius:3px; }
.say2 { display:block; margin-top:4px; background:#fffdfb; border-left:3px solid #c8551a;
        padding:5px 8px; font-size:9.2pt; }
.two { display:grid; grid-template-columns:1fr 1fr; gap:9px; margin-top:9px; }
.box { border:1.5px solid #c8551a; border-radius:4px; padding:6px 9px; background:#fff7f2; font-size:8.2pt; }
.boxhd { font-weight:bold; color:#a8410f; font-size:8.8pt; margin-bottom:4px; }
.box p { margin:0 0 4px; }
.quote { background:#fff; border-radius:3px; padding:5px 7px; font-style:italic; }
.reflex { margin-top:9px; background:#1f2733; color:#fff; border-radius:4px; padding:7px 10px; font-size:8.3pt; }
.odds { margin-top:7px; background:#fff3ec; border-left:3px solid #c8551a; padding:6px 9px;
        font-size:8.4pt; border-radius:0 3px 3px 0; }
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
  avant de raccrocher</b>&nbsp;: &laquo;&nbsp;Je confirme que je suis disponible du 8 au 21 novembre.&nbsp;&raquo;
</div>
{NONTECH}
{GRILLE}
</body></html>"""

html_path = OUT / "fiche_meti.html"
html_path.write_text(DOC, encoding="utf-8")
pdf = Path("/home/user/forgeron/scratch/Forgeron_Fiche_Entretien_METI.pdf")
subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                "--no-pdf-header-footer", f"--print-to-pdf={pdf}", f"file://{html_path}"],
               check=True, capture_output=True)
print("PDF:", pdf, pdf.stat().st_size, "bytes")
