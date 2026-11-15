#!/usr/bin/env python3
"""Fiche de préparation investisseurs — mardi 17 novembre 2026 (PAYF'26, Shared Table 6).

HTML -> PDF A4 via Playwright/Chromium. Polices Saira Condensed + Archivo embarquées
depuis FONTS (téléchargées de Google Fonts) ; à défaut, lien Google Fonts.
Chiffres : uniquement ceux du dépôt (docs/addis/02, workplan METI) — rien d'inventé.
"""
import base64
import subprocess
import sys
from pathlib import Path

FONTS = Path("/tmp/claude-0/-home-user-forgeron/f115b2cf-c02c-5ae4-8f73-96461eacf843/scratchpad/preview/fonts")
HTML_OUT = Path("/tmp/claude-0/-home-user-forgeron/f115b2cf-c02c-5ae4-8f73-96461eacf843/scratchpad/investor_prep.html")
PDF_OUT = Path("/home/user/forgeron/scratch/Forgeron_Investisseurs_Mardi17.pdf")
DECK = "claude.ai/artifact/37AgsYiZJpzCcX7tCtmcrG"


def font_css():
    faces = [("Saira Condensed", w, f"SairaCondensed-{w}.woff2") for w in (600, 700, 800)]
    faces.append(("Archivo", "400 600", "Archivo-400.woff2"))
    if not all((FONTS / f).exists() for _, _, f in faces):
        return ("@import url('https://fonts.googleapis.com/css2?family=Saira+Condensed:wght@600;700;800"
                "&family=Archivo:wght@400;500;600&display=swap');")
    out = []
    for fam, w, f in faces:
        b64 = base64.b64encode((FONTS / f).read_bytes()).decode()
        out.append(f"@font-face{{font-family:'{fam}';font-weight:{w};"
                   f"src:url(data:font/woff2;base64,{b64}) format('woff2');}}")
    return "\n".join(out)


def top(right_bold, right_sub):
    return (f'<div class="top"><div class="wm">FOR<span>GERON</span></div>'
            f'<div class="top-r"><b>{right_bold}</b><br>{right_sub}</div></div>')


QA = [
    ("How much are you raising?",
     "“About 14,400 dollars: 7,600 to build two production machines in Bamako, and the rest to equip "
     "the two workshops and run the pilot until April 2027. We prefer a grant, a pilot partnership or "
     "components in kind. After the pilot, we will raise a pre-seed round sized on its results.”", ""),
    ("What does the machine cost you to build? What is your margin?",
     "“About 3,800 dollars per production machine, our estimate from the design, including import "
     "duties and assembly. Supplier quotes are on the way. We plan to sell it at 10 million FCFA, "
     "about 16,000 dollars, a price that also has to cover installation, training and service.”",
     "Estimation détaillée en page 5. Remplace-la par ton chiffrage réel (mémoire, section 7.3) dès que tu l’as."),
    ("What is your impact?",
     "“Parts made here instead of imported, so the money and the work stay in the country. Workshop "
     "staff run a precision machine in their own language, without being programmers, and we build "
     "and repair the machines in Bamako. The pilot will measure parts made locally, money saved per "
     "part and people trained.”", ""),
    ("Has anyone paid you yet?",
     "“Not yet. That is exactly what the pilot is for: two shops, at least five real customer parts "
     "each, at a price they agree to pay.”",
     "Si la discussion avec Kouratechnique est toujours ouverte, ajoute : “Our first pilot "
     "discussion is with Kouratechnique in Bamako.”"),
    ("Imported machines keep getting cheaper. Why won’t they beat you?",
     "“They will get cheaper. What stays expensive is running them: a programmer, and repairs from "
     "abroad. Our edge is the operator side: plain language, offline, in 17 languages including 15 "
     "African ones, with a team in Bamako to fix the machine.”", ""),
    ("Which languages does it speak?",
     "“The app offers 17: French, English and 15 African languages, from Bambara and Wolof to Hausa, "
     "Swahili, Amharic and Zulu. Most are machine translations, and native speakers are reviewing "
     "them, starting with Bambara. In Bambara, the safety alarms stay in French until a native speaker "
     "has checked them.”", ""),
    ("How big is the market?",
     "“I won’t give you a number I can’t source. Our first market is the machine shops of Bamako. "
     "The pilot includes ten customer interviews, and they will tell us how many shops can pay, and "
     "how much.”", ""),
    ("What if the AI makes a mistake?",
     "“The AI doesn’t calculate the toolpath; deterministic code does. Every move is shown and waits "
     "for the operator’s yes, and the emergency stop never waits for the AI.”",
     "N’ajoute “and a physical emergency button cuts the spindle’s power” que si ce bouton est "
     "réellement installé sur la machine."),
    ("Does it need the internet?",
     "“No. The AI runs on a computer in the workshop. The internet only makes it stronger when it is "
     "there.”", ""),
    ("Who owns the technology? Is it open source?",
     "“We wrote all of it. The code is in a public repository without a licence today, so all rights "
     "remain ours. Choosing a licence and registering the Forgeron trademark with OAPI are part of "
     "the pilot.”", ""),
    ("What if the machine breaks during the pilot?",
     "“That is our biggest risk: we have one machine. The pilot budget includes a spare-parts kit, "
     "Aboubacar repairs it on site, and a second machine is the first thing a pre-seed round would "
     "pay for.”", ""),
    ("Why you?",
     "“In Bamako I designed parts that had to be made in India. So I built the machine that could "
     "make them, with my own money, and I wrote its software and its AI agent myself.”", ""),
    ("Why Japan? (visiteur japonais)",
     "“Japan sets the world standard in machine tools. We want Japanese partners for components and "
     "know-how, so that Africa’s version of this industry is built to that standard.”", ""),
    ("What about medical parts?",
     "“Later, and only after certification. Custom implants are a natural use of five-axis "
     "machining, but we won’t touch medical parts before the pilot proves the basics.”", ""),
]

DONT = [
    ("« ±0,1 mm »",
     "Jamais mesuré : nous n’avons pas d’instruments de mesure, ils sont dans le budget du pilote.",
     "<span class='say'>“Tolerance will be measured on the pilot parts.”</span>"),
    ("« We build it for $15,000 »",
     "Ambigu : 10 M FCFA est le prix de vente ; la fabrication est estimée à environ 3 800 $ par machine (page 5).",
     "<span class='say'>“We sell at 10 million FCFA. Building one costs us about 3,800 dollars.”</span>"),
    ("« 5-axis trunnion, G-code, LLM, 48 tools… »",
     "Tes interlocuteurs ne sont pas techniques : le jargon les perd.",
     "<span class='say'>“Parts made here, not imported. No programmer needed.”</span>"),
    ("« It cuts steel, brass, aluminium… »",
     "Aucun matériau usiné n’est documenté dans le dépôt.",
     "Cite seulement ce que tu as réellement usiné : <span class='ph'>⟦ ______ ⟧</span>"),
    ("« A hardware emergency stop »",
     "Pas encore réalisé au 22 octobre (docs/addis/02).",
     "Seulement s’il a été installé depuis."),
    ("« We have identified our customers »",
     "Zéro client payant et zéro entretien client documenté à ce jour (workplan METI).",
     "<span class='say'>“No paying customer yet. The pilot is where we test our price.”</span>"),
    ("« The market is worth X billion »",
     "Aucun chiffre de marché sourcé.",
     "<span class='say'>“I won’t give you a number I can’t source.”</span>"),
    ("« It speaks 15 African languages perfectly »",
     "Traductions produites par des outils, pas encore relues par des locuteurs natifs ; l’app marque "
     "elle-même 12 de ces langues comme « peu dotées ».",
     "<span class='say'>“The app offers 15 African languages; native speakers are reviewing the "
     "translations.”</span>"),
    ("« The emergency stop works in five languages »",
     "Dans le code, la règle d’arrêt est testée en français et en anglais ; le swahili et l’amharique "
     "y sont marqués « à relire par un locuteur natif ».",
     "<span class='say'>“The stop is a fixed rule outside the AI, tested in French and "
     "English.”</span>"),
]

CSS = r"""
@page { size: A4; margin: 13mm 15mm 17mm; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: 'Archivo', Arial, sans-serif; font-size: 9.6pt; line-height: 1.42; color: #3D4450; background: #FFFFFF; }
h1, h2, .wm, .lbl, .t, .goal, th { font-family: 'Saira Condensed', 'Arial Narrow', Arial, sans-serif; }
.top { display: flex; justify-content: space-between; align-items: flex-end; border-bottom: 2.5pt solid #FF6A1A; padding-bottom: 6pt; margin-bottom: 12pt; }
.wm { font-size: 22pt; font-weight: 800; letter-spacing: 1.5pt; line-height: 1; color: #14171C; }
.wm span { color: #FF6A1A; }
.top-r { text-align: right; font-size: 8.6pt; color: #5E6673; line-height: 1.35; }
.top-r b { color: #14171C; font-weight: 600; }
h1 { font-size: 20pt; font-weight: 700; line-height: 1.08; color: #14171C; margin-bottom: 5pt; }
h2 { font-size: 13pt; font-weight: 700; line-height: 1.15; color: #14171C; margin: 13pt 0 6pt; padding-bottom: 3pt; border-bottom: 1pt solid #D6CFC3; break-after: avoid; }
p + p { margin-top: 5pt; }
b { color: #14171C; font-weight: 600; }
.lead { font-size: 10pt; }
.small { font-size: 8.4pt; color: #5E6673; margin-top: 5pt; }
.lbl { display: block; font-size: 8.4pt; font-weight: 700; letter-spacing: 1.1pt; text-transform: uppercase; color: #B53A0B; margin-bottom: 4pt; }
.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 9pt; margin-top: 9pt; }
.box { border: 1pt solid #D6CFC3; border-radius: 4pt; padding: 8pt 10pt; break-inside: avoid; }
.box.tint { background: #F4F0E8; border-color: #F4F0E8; }
ul.tight { list-style: none; }
ul.tight li { position: relative; padding-left: 10pt; margin-top: 3pt; }
ul.tight li::before { content: ""; position: absolute; left: 0; top: 5.3pt; width: 4pt; height: 4pt; border-radius: 50%; background: #FF6A1A; }
.goal { margin: 12pt 0 0; font-size: 14.5pt; font-weight: 700; line-height: 1.2; color: #14171C; }
.say { font-style: italic; color: #14171C; }
.ph { color: #B53A0B; font-weight: 600; font-style: normal; }
table { width: 100%; border-collapse: collapse; font-size: 9.2pt; }
th { text-align: left; font-size: 8.6pt; font-weight: 700; letter-spacing: 0.9pt; text-transform: uppercase; color: #5E6673; padding: 4pt 6pt; border-bottom: 1.2pt solid #14171C; }
td { padding: 5pt 6pt; border-bottom: 0.8pt solid #D6CFC3; vertical-align: top; }
tr { break-inside: avoid; }
.t { display: block; font-size: 11pt; font-weight: 700; color: #B53A0B; white-space: nowrap; }
.cmd { font-family: 'DejaVu Sans Mono', 'Courier New', monospace; font-size: 8.6pt; color: #14171C; background: #F4F0E8; padding: 1.5pt 4pt; border-radius: 2pt; }
.cb { display: inline-block; width: 8.5pt; height: 8.5pt; border: 1pt solid #14171C; border-radius: 1.5pt; }
.check td { padding: 4.5pt 6pt; }
.qa { break-inside: avoid; margin-top: 4pt; font-size: 9.1pt; line-height: 1.36; }
.q { font-weight: 600; color: #14171C; }
.q .n { font-family: 'Saira Condensed', 'Arial Narrow', Arial, sans-serif; font-weight: 700; color: #B53A0B; margin-right: 4pt; }
.a { margin-top: 1pt; padding-left: 13pt; color: #14171C; font-style: italic; }
.a2 { margin-top: 1.5pt; padding-left: 13pt; font-size: 8.2pt; color: #5E6673; }
.pb { break-before: page; }
.r { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; }
th.r { text-align: right; }
.sub td { font-weight: 600; color: #14171C; background: #F4F0E8; }
.sheet td { height: 15.6mm; }
"""


def page_plan():
    return top("Investisseurs · mardi 17 novembre 2026", "PAYF’26 · siège de l’Union africaine · Shared Table 6") + f"""
<h1>Présentation et démonstration devant les investisseurs</h1>
<p class="lead">Le deck (11 slides en anglais, notes du présentateur incluses) : <b>{DECK}</b>.
Télécharge-le en PDF ou en PowerPoint avant de partir : le Wi-Fi d’un hall d’exposition n’est jamais fiable.
Cette fiche contient tout le reste.</p>

<div class="grid2">
 <div class="box">
  <span class="lbl">Ce qui est confirmé</span>
  <ul class="tight">
   <li>Expo PAYF’26, <b>Jour 2 : mardi 17 novembre</b>, 09:00–17:00, siège de l’UA.</li>
   <li><b>Shared Table 6, côté B.</b> Astou Diakhate a le côté A : une demi-table, prévois petit.</li>
   <li>Ton nom est sur la liste officielle des participants de l’UA (n° 113, Mali) : l’accès est couvert. Garde ton passeport sur toi.</li>
   <li>Le même jour, le bootcamp est au <b>Jour 7</b> (go-to-market, tables rondes avec des acheteurs). Fais valider ton absence par le coordinateur.</li>
  </ul>
 </div>
 <div class="box tint">
  <span class="lbl">Pourquoi mardi compte</span>
  <ul class="tight">
   <li><b>Mercredi 18</b> (Jour 8) : rendez-vous individuels avec des investisseurs, 15:15–16:30, puis rencontre investisseurs-fondateurs à 17:15.</li>
   <li><b>Vendredi 20</b> : Demo Day, avec un briefing fermé pour les investisseurs, des pitchs avec démo en direct et des rencontres en tête-à-tête.</li>
   <li>Mardi est ta répétition générale devant un vrai public. Chaque contact de mardi peut devenir un rendez-vous mercredi ou vendredi.</li>
  </ul>
  <p class="small">Horaires tirés de la note de concept de la résidence : vérifie l’agenda à jour.</p>
 </div>
</div>

<p class="goal">Mardi, on ne signe rien. On repart avec des noms, et un rendez-vous de 20 minutes avec chaque investisseur sérieux.</p>
<p class="lead" style="margin-top:4pt"><b>Tes interlocuteurs ne sont pas techniques.</b> Parle des problèmes résolus et de l’impact :
des pièces faites ici, de l’argent qui reste dans le pays, des gens formés. Jamais d’axes, de G-code ni de modèles d’IA.</p>

<h2>Trois versions du pitch</h2>
<table>
 <tr><th style="width:23%">Situation</th><th>Ce que tu fais</th></tr>
 <tr><td><span class="t">30 secondes</span>quelqu’un passe devant la table</td>
     <td><span class="say">“Hi, I’m Lamine from Mali. This is Forgeron, a five-axis machine that carves precise metal parts.
     We built it in Bamako. You don’t program it. You talk to it. Today our workshops turn those parts away and import them.
     Can I show you in one minute?”</span></td></tr>
 <tr><td><span class="t">3 minutes</span>quelqu’un s’arrête</td>
     <td>Suis le deck : slide 2, le problème (0:00) · slide 3, la solution (0:30) · slide 4, puis <b>la démo</b> (0:55) ·
     slide 5, l’impact (1:50) · slides 8 et 9, le pilote et la demande (2:20) · slide 11, le contact (2:50).
     Si le temps manque, saute les slides 6, 7 et 10.</td></tr>
 <tr><td><span class="t">10 à 15 minutes</span>rendez-vous assis, mercredi ou vendredi</td>
     <td>Tout le deck en 4 minutes, la démo en 3, puis leurs questions. Garde 2 minutes pour la suite :
     <span class="say">“What would you need to see to support the pilot?”</span></td></tr>
</table>

<h2>Sur la table</h2>
<table class="check">
 <tr><td style="width:5%"><span class="cb"></span></td><td>Laptop chargé et son chargeur</td>
     <td style="width:5%"><span class="cb"></span></td><td>Deck téléchargé en PDF, lisible hors ligne</td></tr>
 <tr><td><span class="cb"></span></td><td>Tablette : app à jour, mode simulation testé</td>
     <td><span class="cb"></span></td><td>Pièces usinées : le dôme, et la carte d’Afrique si elle est faite</td></tr>
 <tr><td><span class="cb"></span></td><td>Multiprise et adaptateur (prises C, F, L)</td>
     <td><span class="cb"></span></td><td>Cartes de visite et brochures</td></tr>
 <tr><td><span class="cb"></span></td><td>Casque micro, si tu fais la démo à la voix</td>
     <td><span class="cb"></span></td><td>Kakémono</td></tr>
 <tr><td><span class="cb"></span></td><td>Passeport, pour l’accès au siège de l’UA</td>
     <td><span class="cb"></span></td><td>Cette fiche et deux fiches contacts imprimées</td></tr>
</table>
"""


def page_demo():
    return '<div class="pb"></div>' + top("La démonstration", "Mardi 17 novembre · Shared Table 6") + """
<h1>La démonstration sur une demi-table</h1>
<p class="lead">Une seule règle : la démo doit marcher à chaque fois, devant n’importe qui. Prépare trois niveaux,
et passe au suivant sans t’excuser si quelque chose cloche.</p>

<table style="margin-top:8pt">
 <tr><th style="width:19%">Niveau</th><th>Quoi</th><th style="width:31%">Quand</th></tr>
 <tr><td><span class="t">1 · Machine</span></td>
     <td>La vraie machine, en mouvements à vide : déplacements d’axes, cycle sans outil dans la matière.
     <b>Pas de coupe de métal au milieu du public.</b></td>
     <td>Seulement si l’UA autorise la machine dans le hall et si le transport depuis l’Institut est sûr.</td></tr>
 <tr><td><span class="t">2 · Simulation</span></td>
     <td>L’application en mode simulation sur la tablette ou le laptop, avec l’agent IA local.
     Même conversation, même confirmation, sans matériel.</td>
     <td>Toujours prête, même quand la machine est là.</td></tr>
 <tr><td><span class="t">3 · Vidéo</span></td>
     <td>Le Short de la visite METI (QR code sur la dernière slide) et la vidéo explicative en boucle sur un deuxième écran.</td>
     <td>Quand il y a foule, ou si les niveaux 1 et 2 tombent.</td></tr>
</table>

<h2>Le script : 90 secondes, 3 commandes</h2>
<p>Parle à la machine en français : c’est la langue de l’atelier, et celle où l’agent est le plus solide.
Commente en anglais pour les investisseurs.</p>
<table style="margin-top:6pt">
 <tr><th style="width:35%">Tu tapes ou tu dis</th><th>Ce qui se passe</th><th style="width:31%">Tu dis aux investisseurs</th></tr>
 <tr><td><span class="cmd">Donne-moi l’état complet de la machine.</span></td>
     <td>L’agent appelle la fonction d’état et lit les positions, la broche et les alarmes.</td>
     <td class="say">“It reads the machine before it does anything.”</td></tr>
 <tr><td><span class="cmd">Avance X de 5 mm à 300.</span></td>
     <td>L’agent annonce le mouvement exact et attend. Tu montres l’écran, puis tu confirmes.</td>
     <td class="say">“It explains, and it waits for my yes.”</td></tr>
 <tr><td><span class="cmd">Arrêt d’urgence !</span></td>
     <td>Arrêt immédiat, sans demande de confirmation.</td>
     <td class="say">“And the stop never waits for the AI.”</td></tr>
</table>
<p class="small">Répète ces trois commandes lundi soir, sur le matériel exact de mardi.</p>
<p class="small"><b>Astuce Addis :</b> devant un visiteur éthiopien, kényan ou nigérian, passe l’interface en amharique,
en swahili, en haoussa ou en yoruba (réglage de langue), puis demande-lui ce qu’il pense de la traduction.
Tu obtiens une relecture par un locuteur natif, et la conversation démarre toute seule.</p>

<div class="grid2">
 <div class="box">
  <span class="lbl">À ne jamais faire pendant la démo</span>
  <ul class="tight">
   <li>Demander à l’agent d’écrire du G-code : c’est un point faible connu (un cycle de perçage incohérent a déjà été observé).</li>
   <li>Lancer un programme d’usinage complet dans le hall.</li>
   <li>Utiliser la voix dans le bruit sans casque : tape la commande.</li>
   <li>Laisser un visiteur manipuler la machine sous tension.</li>
  </ul>
 </div>
 <div class="box">
  <span class="lbl">Avant d’allumer</span>
  <ul class="tight">
   <li>Teste l’arrêt d’urgence une fois, devant toi.</li>
   <li>Broche à l’arrêt et aucun outil serré pour les mouvements à vide.</li>
   <li>Câbles scotchés au sol, zone dégagée autour de la machine.</li>
   <li>Vérifie que la tablette joint bien l’ESP32 avant l’arrivée du public.</li>
  </ul>
 </div>
</div>
"""


def page_qa():
    items = []
    for i, (q, a, note) in enumerate(QA, 1):
        extra = f'<p class="a2">{note}</p>' if note else ""
        items.append(f'<div class="qa"><p class="q"><span class="n">{i}.</span>{q}</p>'
                     f'<p class="a">{a}</p>{extra}</div>')
    return ('<div class="pb"></div>' + top("Questions des investisseurs", "Réponses en anglais, à dire telles quelles")
            + '<h1>Les questions difficiles, et des réponses honnêtes</h1>'
            + '<p class="lead">Réponds court, puis tais-toi. Un investisseur pardonne « pas encore », jamais un chiffre inventé.</p>'
            + "".join(items))


def page_dont():
    rows = "".join(f"<tr><td><b>{a}</b></td><td>{b}</td><td>{c}</td></tr>" for a, b, c in DONT)
    return '<div class="pb"></div>' + top("Ce qu’il ne faut plus dire", "Et le suivi après chaque rencontre") + f"""
<h1>Ce qu’il ne faut plus dire</h1>
<p class="lead">Ces phrases circulent dans nos anciens documents (dont la fiche METI Japan du 10 novembre) ou sur le site.
Elles ne sont pas vérifiées. Devant un investisseur, une seule affirmation fausse peut coûter toute ta crédibilité.</p>
<table style="margin-top:8pt">
 <tr><th style="width:25%">Ne dis pas</th><th style="width:37%">Pourquoi</th><th>Dis plutôt</th></tr>
 {rows}
</table>

<h2>Après chaque rencontre</h2>
<ul class="tight">
 <li>Note la personne tout de suite sur la fiche contacts (dernière page), pas le soir.</li>
 <li>Le soir même, envoie ce message à chaque contact sérieux, par WhatsApp, e-mail ou LinkedIn :</li>
</ul>
<div class="box tint" style="margin-top:7pt">
 <p class="say">“Dear <span class="ph">⟦Name⟧</span>, thank you for stopping at the Forgeron table at PAYF today.
 Here is a short video of the machine: youtube.com/shorts/5M-YDATpf7E.
 Could we take 20 minutes this week in Addis, on <span class="ph">⟦Wednesday 18 or Friday 20⟧</span>?
 Best regards, Lamine SACKO, Forgeron (Mali), +223 93 05 69 36.”</p>
</div>
<p class="small">Ces notes te servent aussi mercredi : au Jour 8, la résidence demande un relevé des retours
d’investisseurs et des prochaines étapes.</p>
"""


COST = [
    ("Structure", "profilés alu 80×80, plaques, équerres, visserie", 550),
    ("Mouvement linéaire X, Y, Z", "vis à billes SFU1605 et paliers, rails HGR15 et patins, accouplements", 400),
    ("Moteurs et drivers", "5 moteurs NEMA 23 et leurs drivers", 450),
    ("Axes rotatifs A et C", "courroies, poulies, roulements à contact oblique, plateau", 200),
    ("Broche", "broche d’environ 1,5 kW, variateur, support, pinces", 300),
    ("Électronique et sécurité", "ESP32, carte d’interface, alimentations, fins de course, arrêt d’urgence, câbles", 350),
    ("Capot de protection", "carter contre les copeaux", 200),
]
EXTRA = [
    ("Transport et douane jusqu’à Bamako", "environ 35 % du prix des pièces importées", 850),
    ("Usinage local, assemblage et réglage", "travail de l’équipe", 500),
]
ASK = [
    ("Construire deux machines de production", "l’estimation ci-dessus, deux fois", 7600),
    ("Équiper les deux ateliers", "workplan : ordinateur IA, onduleur, 2 tablettes, 2 casques (2 190) ; "
     "en plus : un 2ᵉ ordinateur IA (1 200) et un 2ᵉ onduleur (250), car les deux ateliers tournent en même temps", 3640),
    ("Sécurité, pièces de rechange, certification, marque", "workplan", 1230),
    ("Faire tourner le pilote", "workplan : métal, outils, mesure (910) ; caisse, transport, relecture bambara, données (540)", 1450),
    ("Trouver et signer les ateliers", "workplan : visites, mentors vente et prix", 520),
]


def usd(n):
    return f"{n:,}".replace(",", " ")


def page_cost():
    parts = sum(c for _, _, c in COST)
    per_machine = parts + sum(c for _, _, c in EXTRA)
    assert per_machine * 2 == ASK[0][2]
    rows = "".join(f"<tr><td><b>{a}</b></td><td>{b}</td><td class='r'>{usd(c)}</td></tr>" for a, b, c in COST)
    rows += f"<tr class='sub'><td>Sous-total des pièces</td><td></td><td class='r'>{usd(parts)}</td></tr>"
    rows += "".join(f"<tr><td><b>{a}</b></td><td>{b}</td><td class='r'>{usd(c)}</td></tr>" for a, b, c in EXTRA)
    rows += f"<tr class='sub'><td>Total par machine</td><td></td><td class='r'>{usd(per_machine)}</td></tr>"
    ask_rows = "".join(f"<tr><td><b>{a}</b></td><td>{b}</td><td class='r'>{usd(c)}</td></tr>" for a, b, c in ASK)
    total = sum(c for _, _, c in ASK)
    ask_rows += f"<tr class='sub'><td>Total de la demande</td><td></td><td class='r'>{usd(total)}</td></tr>"
    return '<div class="pb"></div>' + top("Combien coûte une machine", "Le détail derrière la slide 9") + f"""
<h1>Combien coûte une machine de production</h1>
<p class="lead">Estimation construite à partir de la conception de ton mémoire, avec des prix catalogue de fournisseurs en ligne.
<b>Ce sont des approximations</b> : remplace chaque ligne par ton chiffrage réel (mémoire, section 7.3) ou par un devis dès que possible.</p>
<table style="margin-top:8pt">
 <tr><th style="width:27%">Poste</th><th>Contenu</th><th style="width:12%" class="r">US$</th></tr>
 {rows}
</table>

<h2>Ce que ça donne dans la demande : {usd(total)} $</h2>
<table>
 <tr><th style="width:30%">Ligne de la slide 9</th><th>D’où vient le chiffre</th><th style="width:12%" class="r">US$</th></tr>
 {ask_rows}
</table>
<p class="small">Les 5 390 $ du workplan METI sont tous repris. S’y ajoutent les deux machines (7 600 $) et le second poste IA (1 450 $).
Ne présente pas l’écart entre 3 800 $ et 16 000 $ comme ta marge : l’installation, la formation, le service après-vente
et l’ordinateur IA livré avec chaque machine ne sont pas encore chiffrés.</p>
"""


def page_sheet():
    rows = "".join("<tr><td></td><td></td><td></td><td></td><td></td></tr>" for _ in range(12))
    return '<div class="pb"></div>' + top("Fiche contacts", "Mardi 17 novembre · Shared Table 6") + f"""
<h1>Fiche contacts</h1>
<p class="lead">Une ligne par personne. Type : I = investisseur, A = acheteur, P = partenaire.</p>
<table class="sheet" style="margin-top:8pt">
 <tr><th style="width:19%">Nom</th><th style="width:20%">Organisation</th><th style="width:7%">Type</th>
     <th style="width:25%">Ce qui l’intéresse</th><th>Prochaine étape et date</th></tr>
 {rows}
</table>
"""


html = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<title>Forgeron · Investisseurs · mardi 17 novembre</title>
<style>{font_css()}</style><style>{CSS}</style></head><body>
{page_plan()}{page_demo()}{page_qa()}{page_dont()}{page_cost()}{page_sheet()}
</body></html>"""

HTML_OUT.write_text(html, encoding="utf-8")
JS = ("const {chromium}=require('/opt/node-tools/node_modules/playwright');"
      "(async()=>{const [src,dst]=process.argv.slice(-2);const b=await chromium.launch();"
      "const p=await b.newPage();await p.goto('file://'+src);await p.waitForTimeout(900);"
      "await p.pdf({path:dst,format:'A4',printBackground:true,preferCSSPageSize:true});await b.close();})();")
subprocess.run(["node", "-e", JS, str(HTML_OUT), str(PDF_OUT)], check=True)
print("PDF :", PDF_OUT, f"({PDF_OUT.stat().st_size:,} octets)")
sys.exit(0)
