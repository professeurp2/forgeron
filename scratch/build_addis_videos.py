#!/usr/bin/env python3
"""Guide de tournage Addis — contenu de chaque vidéo. Versions FR et EN."""
import subprocess
from pathlib import Path

OUT = Path("/tmp/claude-0/-home-user-forgeron/f115b2cf-c02c-5ae4-8f73-96461eacf843/scratchpad")
CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"

CSS = """
@page { size: A4; margin: 12mm 13mm; }
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family:"DejaVu Sans","Liberation Sans",sans-serif; color:#1f2733; margin:0;
       font-size:9.2pt; line-height:1.45; }
h1,h2,h3 { margin:0; }
.hero { border-bottom:3px solid #c8551a; padding-bottom:8px; margin-bottom:10px; }
.kick { font-size:7.2pt; letter-spacing:.14em; text-transform:uppercase; color:#8b7a6a; font-weight:bold; }
.hero h1 { font-size:19pt; margin:3px 0 2px; }
.sub { font-size:9.4pt; color:#5a6675; font-weight:bold; }
.dl { margin-top:8px; background:#1f2733; color:#fff; border-radius:4px; padding:7px 11px; font-size:9pt; }
.dl b { color:#ff9a5c; }
.vs { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin:11px 0; }
.card { border:1.5px solid #1f2733; border-radius:4px; overflow:hidden; break-inside:avoid; }
.card.b { border-color:#c8551a; }
.cardhd { background:#1f2733; color:#fff; padding:5px 9px; font-weight:bold; font-size:9.6pt; }
.card.b .cardhd { background:#c8551a; }
.cardbody { padding:7px 9px; font-size:8.5pt; }
.cardbody p { margin:0 0 4px; }
.orient { display:inline-block; background:#ffe9dc; color:#a8410f; font-weight:bold;
          padding:2px 7px; border-radius:3px; font-size:9pt; margin-bottom:4px; }
.blk { margin-bottom:13px; }
.blkhd { display:flex; align-items:center; gap:8px; border-bottom:1.5px solid #1f2733;
         padding-bottom:4px; margin-bottom:6px; break-after:avoid; }
.bnum { min-width:20px; height:20px; padding:0 5px; background:#c8551a; color:#fff; border-radius:3px;
        text-align:center; line-height:20px; font-weight:bold; font-size:10pt; }
.blkhd h2 { font-size:12pt; flex:1; }
.tag { font-family:"DejaVu Sans Mono",monospace; font-size:8pt; color:#fff; background:#1f2733;
       padding:2px 7px; border-radius:3px; white-space:nowrap; }
.say { border-left:3px solid #c8551a; background:#fffdfb; padding:6px 10px; margin:5px 0; }
.say p { margin:0 0 4px; font-size:10pt; line-height:1.48; }
.say p:last-child { margin-bottom:0; }
table { width:100%; border-collapse:collapse; font-size:8.4pt; margin:5px 0; }
th { text-align:left; font-size:6.9pt; letter-spacing:.1em; text-transform:uppercase; color:#8894a5;
     border-bottom:1px solid #c9d0da; padding:3px 6px; }
td { padding:4px 6px; border-bottom:1px solid #edf0f4; vertical-align:top; }
.ck { width:14px; }
.ck::before { content:""; display:block; width:9px; height:9px; border:1.2px solid #8894a5;
              border-radius:2px; margin-top:2px; }
.note { font-size:8.3pt; color:#6b5c4e; background:#fdf8f2; border-radius:3px; padding:5px 9px; margin:5px 0; }
.warn { background:#fff3ec; border-left:3px solid #c8551a; padding:6px 10px; font-size:8.5pt;
        border-radius:0 3px 3px 0; margin:6px 0; break-inside:avoid; }
.two { display:grid; grid-template-columns:1fr 1fr; gap:11px; }
.avoid { border:1.5px solid #c8551a; border-radius:4px; padding:6px 9px; background:#fff7f2; font-size:8.3pt; }
.avoidhd { font-weight:bold; color:#a8410f; margin-bottom:3px; font-size:8.8pt; }
.avoid ul { margin:0; padding-left:15px; } .avoid li { margin-bottom:2px; }
.pb { break-before:page; }
"""

TXT = {
 "fr": dict(
  kick="timbuktoo · METI UniPods AI Bootcamp · Addis-Abeba, 9–20 novembre 2026",
  title="Les vidéos à tourner — guide de contenu",
  sub="FORGERON · Lamine SACKO · Mali · UniPod Mali (ENI-ABT)",
  dl="<b>⏰ Échéance : mercredi 28 octobre, fin de journée.</b> Les 4 photos, le formulaire de contenu "
     "et les clips du compte à rebours partent le même jour. Le chef d'équipe téléverse les 10 clips.",
  vshd="Deux vidéos différentes — et le piège est l'orientation",
  v1t="VIDÉO 1 — Clip du compte à rebours",
  v1o="📱 PORTRAIT (téléphone à la verticale)",
  v1b="<p>Une seule phrase : <b>ta réplique du script de ton équipe</b>.</p>"
      "<p>Montée avec les clips des 9 autres membres pour faire la vidéo du compte à rebours de l'équipe. "
      "Une équipe par jour, du 4 au 8 novembre.</p>"
      "<p><b>Aucun montage, aucun filtre, aucune musique.</b> Tu envoies le fichier tel quel à ton chef d'équipe.</p>",
  v2t="VIDÉO 2 — Ta vidéo d'innovateur",
  v2o="🖥️ PAYSAGE (téléphone à l'horizontale)",
  v2b="<p>Trois parties : <b>plan principal</b> (toi face caméra), <b>plans d'illustration</b> (toi au travail), "
      "et une <b>séquence</b> facultative montrant les étapes.</p>"
      "<p>Tu la montes toi-même : <b>30 à 60 secondes</b>, avec sous-titres et ton nom à l'écran.</p>"
      "<p>Tu l'envoies pour relecture <b>avant</b> publication.</p>",
  warn1="⚠️ <b>Ne confonds pas les deux.</b> Le clip du compte à rebours se filme <b>à la verticale</b>, "
        "ta vidéo d'innovateur <b>à l'horizontale</b>. Un clip tourné dans le mauvais sens est inutilisable, "
        "et il n'y aura pas le temps de refaire.",
  s1="LE CLIP DU COMPTE À REBOURS", s1tag="portrait · 1 phrase",
  s1i="Ta réplique figure dans le script de ton équipe. Place-la ici avant de filmer :",
  s1ph="⟦ TA RÉPLIQUE, RECOPIÉE DU SCRIPT DE L'ÉQUIPE ⟧",
  s1r=[("Tiens le téléphone <b>à la verticale</b>", "Vérifie avant chaque prise"),
       ("Regarde l'objectif et souris", "Pas l'écran — l'objectif"),
       ("Dis la phrase clé <b>lentement et distinctement</b>", "C'est le seul moment qui compte"),
       ("Parle avec énergie", "Le montage enchaîne 10 personnes : la tienne doit vivre"),
       ("Tes propres mots sont acceptés", "Tant que le message clé reste identique"),
       ("Envoie le fichier brut au chef d'équipe", "Aucun montage, aucun filtre, aucune musique")],
  s2="TA VIDÉO D'INNOVATEUR", s2tag="paysage · 30–60 s",
  s2a="Partie 1 — Le plan principal : ce que tu dis",
  s2ai="Toi face caméra : qui tu es, le problème que tu résous, ta solution. "
       "Voici le texte, prêt à dire — il tient en 45 secondes.",
  s2b="Partie 2 — Les plans d'illustration (B-roll)",
  s2bi="Plusieurs clips courts de quelques secondes, posés par-dessus ta voix au montage. "
       "Filme chacun <b>deux fois</b>.",
  s2c="Partie 3 — La séquence (facultative, mais c'est ton atout)",
  s2ci="Les étapes dans l'ordre, un clip court par étape. Chez toi, la séquence raconte toute la chaîne — "
       "c'est ce que personne d'autre dans la cohorte ne peut montrer.",
  s3="LE MONTAGE", s3tag="CapCut ou InShot",
  s4="LES RÈGLES COMMUNES AUX DEUX VIDÉOS",
  s5="ENVOI ET NOMMAGE",
  th_shot="Plan à filmer", th_why="Pourquoi",
  th_step="Étape", th_film="Ce que tu filmes",
 ),
 "en": dict(
  kick="timbuktoo · METI UniPods AI Bootcamp · Addis Ababa, 9–20 November 2026",
  title="The videos to film — content guide",
  sub="FORGERON · Lamine SACKO · Mali · UniPod Mali (ENI-ABT)",
  dl="<b>⏰ Deadline: Wednesday 28 October, end of day.</b> The 4 photos, the content form and the "
     "countdown clips all go on the same day. The team lead uploads all 10 clips.",
  vshd="Two different videos — and the trap is the orientation",
  v1t="VIDEO 1 — Countdown clip",
  v1o="📱 PORTRAIT (phone upright)",
  v1b="<p>One single line: <b>your line from your team script</b>.</p>"
      "<p>It is edited together with the clips of the other 9 members to make the team countdown video. "
      "One team per day, 4 to 8 November.</p>"
      "<p><b>No editing, no filters, no music.</b> You send the file exactly as it is to your team lead.</p>",
  v2t="VIDEO 2 — Your innovator video",
  v2o="🖥️ LANDSCAPE (phone sideways)",
  v2b="<p>Three parts: <b>main shot</b> (you facing the camera), <b>B roll</b> (you working), "
      "and an optional <b>sequence</b> showing the steps.</p>"
      "<p>You edit it yourself: <b>30 to 60 seconds</b>, with subtitles and your name on screen.</p>"
      "<p>You send it for comments <b>before</b> publishing.</p>",
  warn1="⚠️ <b>Do not mix the two up.</b> The countdown clip is filmed <b>upright</b>, your innovator video "
        "<b>sideways</b>. A clip shot the wrong way round is unusable, and there will be no time to reshoot.",
  s1="THE COUNTDOWN CLIP", s1tag="portrait · 1 line",
  s1i="Your line is in your team script. Write it here before you film:",
  s1ph="⟦ YOUR LINE, COPIED FROM THE TEAM SCRIPT ⟧",
  s1r=[("Hold the phone <b>upright</b>", "Check before every take"),
       ("Look into the lens and smile", "The lens, not the screen"),
       ("Say the key message <b>slowly and clearly</b>", "It is the only moment that counts"),
       ("Speak with energy", "The edit runs 10 people together — yours has to be alive"),
       ("Your own words are fine", "As long as the key message stays the same"),
       ("Send the raw file to your team lead", "No editing, no filters, no music")],
  s2="YOUR INNOVATOR VIDEO", s2tag="landscape · 30–60 s",
  s2a="Part 1 — The main shot: what you say",
  s2ai="You, facing the camera: who you are, the problem you solve, your solution. "
       "Here is the script, ready to say — it runs to 45 seconds.",
  s2b="Part 2 — B roll",
  s2bi="Several short clips of a few seconds each, laid over your voice when you edit. "
       "Film each one <b>twice</b>.",
  s2c="Part 3 — The sequence (optional, but it is your strongest card)",
  s2ci="The steps in order, one short clip per step. In your case the sequence tells the whole chain — "
       "and it is what nobody else in the cohort can show.",
  s3="THE EDIT", s3tag="CapCut or InShot",
  s4="THE RULES THAT APPLY TO BOTH VIDEOS",
  s5="UPLOAD AND FILE NAMING",
  th_shot="Shot to film", th_why="Why",
  th_step="Step", th_film="What you film",
 ),
}

SCRIPT = {
 "fr": ["«&nbsp;Je m'appelle Lamine SACKO, je suis ingénieur en mécatronique au Mali.",
        "Dans nos ateliers, quand un client arrive avec une pièce complexe à fabriquer, on lui dit non. "
        "La machine capable de la faire coûte environ quarante mille dollars à l'import, et il faut un "
        "programmeur spécialisé pour la piloter — au Mali, ces gens-là sont introuvables.",
        "Nous avons construit cette machine à Bamako, pour environ quinze mille dollars. Et on ne la "
        "programme pas&nbsp;: on lui parle. Vous dites ce que vous voulez en langage courant, l'IA vous "
        "montre ce qu'elle va faire, et attend votre accord avant de bouger.",
        "La machine est construite, elle fonctionne. Nous l'installons maintenant dans de vrais ateliers.&nbsp;»"],
 "en": ["&ldquo;My name is Lamine SACKO, I'm a mechatronics engineer from Mali.",
        "In our workshops, when a customer comes in with a complex part to make, we have to say no. "
        "The machine that could make it costs around forty thousand dollars imported, and you need a "
        "specialist programmer to run it — in Mali, those people are almost impossible to find.",
        "We built that machine in Bamako, for about fifteen thousand. And you don't program it. You talk "
        "to it. You say what you want in plain language, the AI shows you what it is about to do, and "
        "waits for you to agree before anything moves.",
        "The machine is built and it runs. We are now putting it into real workshops.&rdquo;"],
}

BROLL = {
 "fr": [("La machine en train d'usiner, plan serré sur l'outil", "Le plan le plus fort de ta vidéo"),
        ("Tes mains sur la tablette pendant que tu tapes la commande", "Montre le lien geste → machine"),
        ("L'écran de l'app : les cinq axes en direct", "Zoome, le texte doit être lisible"),
        ("Plan large de l'atelier", "Donne le contexte réel"),
        ("Toi et Aboubacar devant la machine", "Avec son accord"),
        ("La pièce finie dans ta main", "La preuve, en une seconde")],
 "en": [("The machine cutting, close on the tool", "The strongest shot in your video"),
        ("Your hands on the tablet as you type the command", "Shows the link from gesture to machine"),
        ("The app screen: the five axes, live", "Zoom in, the text must be readable"),
        ("Wide shot of the workshop", "Gives the real context"),
        ("You and Aboubacar in front of the machine", "With his agreement"),
        ("The finished part in your hand", "The proof, in one second")],
}

SEQ = {
 "fr": [("1", "La pièce à fabriquer — un dessin, ou une photo d'une pièce cassée"),
        ("2", "Toi qui demandes à l'app, en langage courant"),
        ("3", "L'agent qui annonce ce qu'il va faire et attend ta confirmation"),
        ("4", "La machine qui part — avec le son réel"),
        ("5", "La pièce finie, sortie de la machine")],
 "en": [("1", "The part to make — a drawing, or a photo of a broken part"),
        ("2", "You asking the app, in plain language"),
        ("3", "The agent announcing what it will do and waiting for your confirmation"),
        ("4", "The machine starting — with the real sound"),
        ("5", "The finished part, off the machine")],
}

EDIT = {
 "fr": ["Commence par le plan principal — garde ta meilleure prise",
        "Pose le B-roll par-dessus pendant que tu parles",
        "Ajoute la séquence (facultatif)",
        "<b>Ajoute les sous-titres</b> — pour ceux qui ne comprennent pas la langue",
        "Affiche ton nom et « Forgeron » à l'écran, au début",
        "<b>30 à 60 secondes. Pas plus.</b>"],
 "en": ["Start with the main shot — keep your best take",
        "Lay the B roll over it while you talk",
        "Add the sequence (optional)",
        "<b>Add subtitles</b> — for people who don't understand the language",
        "Put your name and &ldquo;Forgeron&rdquo; on screen at the start",
        "<b>30 to 60 seconds. No more.</b>"],
}

RULES = {
 "fr": [("Caméra arrière du téléphone", "Jamais la caméra selfie — la qualité n'y est pas"),
        ("Fais-toi filmer par quelqu'un", "Ou pose le téléphone sur un support stable"),
        ("Bonne lumière du jour", "Face à une fenêtre, ou dehors à l'ombre. Jamais la fenêtre derrière toi"),
        ("Endroit calme", "Le son compte plus que l'image"),
        ("Ni filtre, ni retouche", "Pas de lunettes de soleil, pas de casquette"),
        ("Envoie le fichier original", "Pas de capture ni de réenvoi WhatsApp — la qualité s'effondre")],
 "en": [("Use the phone's back camera", "Never the selfie camera — the quality isn't there"),
        ("Ask someone to film you", "Or rest the phone on something steady"),
        ("Good daylight", "Face a window, or outside in shade. Never with the window behind you"),
        ("Quiet place", "Sound matters more than picture"),
        ("No filters, no edits", "No sunglasses, no cap"),
        ("Send the original file", "Not a screenshot or a WhatsApp re-send — the quality collapses")],
}

UPLOAD = {
 "fr": "<b>Nomme tes fichiers avec ton nom complet et ton pays</b>, et numérote les photos de 1 à 4. "
       "Exemple&nbsp;: <code>Lamine_SACKO_Mali_1.jpg</code>. "
       "Téléverse les photos et le formulaire dans le dossier Drive partagé. "
       "<b>Le clip du compte à rebours part chez ton chef d'équipe</b>, pas sur le Drive&nbsp;: c'est lui "
       "qui téléverse les 10 clips ensemble.",
 "en": "<b>Name your files with your full name and country</b>, and number the photos 1 to 4. "
       "Example: <code>Lamine_SACKO_Mali_1.jpg</code>. "
       "Upload the photos and the form to the shared Drive folder. "
       "<b>The countdown clip goes to your team lead</b>, not to the Drive — he uploads all 10 clips "
       "together.",
}


def rows(items):
    return "".join(f"<tr><td>{a}</td><td>{b}</td></tr>" for a, b in items)


def checks(items):
    return "".join(f'<tr><td class="ck"></td><td>{i}</td></tr>' for i in items)


def build(lang):
    t = TXT[lang]
    script = "".join(f"<p>{p}</p>" for p in SCRIPT[lang])
    seq = "".join(f'<tr><td><b>{n}</b></td><td>{d}</td></tr>' for n, d in SEQ[lang])
    doc = f"""<!DOCTYPE html><html lang="{lang}"><head><meta charset="utf-8">
<title>Forgeron — {t['title']}</title><style>{CSS}</style></head><body>
<header class="hero">
  <div class="kick">{t['kick']}</div>
  <h1>{t['title']}</h1>
  <div class="sub">{t['sub']}</div>
  <div class="dl">{t['dl']}</div>
</header>

<div class="blkhd"><span class="bnum">!</span><h2>{t['vshd']}</h2></div>
<div class="vs">
  <div class="card"><div class="cardhd">{t['v1t']}</div>
    <div class="cardbody"><div class="orient">{t['v1o']}</div>{t['v1b']}</div></div>
  <div class="card b"><div class="cardhd">{t['v2t']}</div>
    <div class="cardbody"><div class="orient">{t['v2o']}</div>{t['v2b']}</div></div>
</div>
<div class="warn">{t['warn1']}</div>

<section class="blk">
  <div class="blkhd"><span class="bnum">1</span><h2>{t['s1']}</h2><span class="tag">{t['s1tag']}</span></div>
  <p style="font-size:8.6pt;margin:0 0 4px">{t['s1i']}</p>
  <div class="say"><p><b>{t['s1ph']}</b></p></div>
  <table><tr><th>&nbsp;</th><th>{t['th_shot']}</th><th>{t['th_why']}</th></tr>
  {"".join(f'<tr><td class="ck"></td><td>{a}</td><td>{b}</td></tr>' for a, b in t['s1r'])}</table>
</section>

<section class="blk">
  <div class="blkhd"><span class="bnum">2</span><h2>{t['s2']}</h2><span class="tag">{t['s2tag']}</span></div>

  <h3 style="font-size:9.6pt;color:#a8410f;margin:8px 0 3px">{t['s2a']}</h3>
  <p style="font-size:8.5pt;margin:0 0 4px">{t['s2ai']}</p>
  <div class="say">{script}</div>

  <h3 style="font-size:9.6pt;color:#a8410f;margin:10px 0 3px">{t['s2b']}</h3>
  <p style="font-size:8.5pt;margin:0 0 4px">{t['s2bi']}</p>
  <table><tr><th>&nbsp;</th><th>{t['th_shot']}</th><th>{t['th_why']}</th></tr>
  {"".join(f'<tr><td class="ck"></td><td>{a}</td><td>{b}</td></tr>' for a, b in BROLL[lang])}</table>

  <h3 style="font-size:9.6pt;color:#a8410f;margin:10px 0 3px">{t['s2c']}</h3>
  <p style="font-size:8.5pt;margin:0 0 4px">{t['s2ci']}</p>
  <table><tr><th>{t['th_step']}</th><th>{t['th_film']}</th></tr>{seq}</table>
</section>

<section class="blk">
  <div class="blkhd"><span class="bnum">3</span><h2>{t['s3']}</h2><span class="tag">{t['s3tag']}</span></div>
  <table>{checks(EDIT[lang])}</table>
</section>

<section class="blk">
  <div class="blkhd"><span class="bnum">4</span><h2>{t['s4']}</h2></div>
  <table><tr><th>&nbsp;</th><th>&nbsp;</th><th>&nbsp;</th></tr>
  {"".join(f'<tr><td class="ck"></td><td><b>{a}</b></td><td>{b}</td></tr>' for a, b in RULES[lang])}</table>
</section>

<section class="blk">
  <div class="blkhd"><span class="bnum">5</span><h2>{t['s5']}</h2></div>
  <div class="note">{UPLOAD[lang]}</div>
</section>
</body></html>"""
    html = OUT / f"addis_video_{lang}.html"
    html.write_text(doc, encoding="utf-8")
    pdf = Path(f"/home/user/forgeron/scratch/Forgeron_Videos_Addis_{lang.upper()}.pdf")
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                    "--no-pdf-header-footer", f"--print-to-pdf={pdf}", f"file://{html}"],
                   check=True, capture_output=True)
    print(f"{lang.upper()} : {pdf}  ({pdf.stat().st_size:,} octets)")


for lg in ("fr", "en"):
    build(lg)
