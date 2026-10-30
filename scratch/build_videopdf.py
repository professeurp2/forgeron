#!/usr/bin/env python3
"""Build the GABI video shooting script as a print-ready A4 PDF."""
import html
import subprocess
from pathlib import Path

OUT = Path("/tmp/claude-0/-home-user-forgeron/f115b2cf-c02c-5ae4-8f73-96461eacf843/scratchpad")
OUT.mkdir(parents=True, exist_ok=True)
CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"

# ---------------------------------------------------------------- helpers

def say(*lines, opt=False):
    """A spoken line, verbatim. opt=True marks it as cuttable."""
    cls = "say opt" if opt else "say"
    mark = "<span class='scissors'>&#9986;</span>" if opt else ""
    body = "".join("<p>" + mark + l + "</p>" for l in lines)
    return '<div class="' + cls + '">' + body + "</div>"


def act(text):
    return f'<div class="act"><span class="acthd">Action</span>{text}</div>'


def pause(text):
    return f'<div class="pausebox">&#9724;&nbsp; {text}</div>'


def note(text):
    return f'<div class="note">{text}</div>'


def block(num, title, tc, inner, why=None, keep=False):
    w = f'<div class="why"><b>Pourquoi &ccedil;a marche&nbsp;:</b> {why}</div>' if why else ""
    return f"""
<section class="blk{' keep' if keep else ''}">
  <div class="blkhd">
    <span class="bnum">{num}</span>
    <h2>{title}</h2>
    <span class="tc">{tc}</span>
  </div>
  {inner}{w}
</section>"""


# ---------------------------------------------------------------- content

B1 = block("1", "L'ACCROCHE", "0:00 &rarr; 0:25",
    act("La machine <b>tourne</b>. Plan serr&eacute; sur l'outil. "
        "<b>3&nbsp;secondes sans parler</b> &mdash; juste le son de la machine. "
        "Puis tu entres dans le cadre, debout &agrave; c&ocirc;t&eacute; d'elle.")
    + say(
        "This machine has five axes. It was built here, in Bamako, Mali.",
        "An imported one costs about forty thousand dollars. This one costs fifteen.",
        "And you don&rsquo;t program it. You talk to it.",
        "My name is Lamine SACKO. I am a mechatronics engineer from Mali, at UniPod Mali, in ENI-ABT.",
        "My team and I built this. Let me show you how it works.")
    ,
    why="En 25&nbsp;secondes la salle a le produit, le prix, la rupture, ton nom et ton pays. "
        "Le guide dit que les 10 premi&egrave;res secondes d&eacute;cident si on continue &agrave; regarder.")

B2 = block("2", "LE PROBL&Egrave;ME", "0:25 &rarr; 1:05",
    act("Toi face cam&eacute;ra, dans l'atelier. Si tu as le temps&nbsp;: 2&ndash;3&nbsp;s d'un atelier de Bamako, "
        "un tour manuel, une pi&egrave;ce cass&eacute;e dans une main.")
    + say(
        "In Bamako, I have watched this happen many times.",
        "A customer walks into a workshop with a broken part.",
        "The owner looks at it, turns it in his hand, and says: I cannot make this one.",
        "The surface is curved. It needs a five-axis machine.",
        "So the customer imports the part. He waits three weeks. He pays three times more.",
        "The workshop loses the job. The machinist loses the work. And the money leaves the country.")
    + say("Africa produces less than two percent of the world&rsquo;s manufactured goods.",
          "This is one of the reasons why.", opt=True)
    + say("And this is personal for me. I studied engineering here, in Bamako.",
          "I did not want to design machines that we would still have to import.")
    ,
    why="Le guide dit qu'un exemple r&eacute;el bat les statistiques. On raconte <b>une sc&egrave;ne</b>, "
        "et le chiffre UNIDO arrive <b>apr&egrave;s</b>&nbsp;: il conclut l'histoire au lieu de la remplacer. "
        "Les deux derni&egrave;res phrases r&eacute;pondent au &laquo;&nbsp;why it matters to you personally&nbsp;&raquo; "
        "que le guide exige.")

# --- DEMO -------------------------------------------------------------

D_INTRO = f"""
<div class="setup">
  <div class="setuphd">&#9654;&nbsp; LE DISPOSITIF &mdash; un seul plan, t&eacute;l&eacute;phone et machine ensemble</div>
  <div class="setupbody">
    <p>Cam&eacute;ra sur tr&eacute;pied, <b>en paysage</b>, &agrave; environ 2&nbsp;m. Dans le m&ecirc;me cadre&nbsp;:
    le <b>t&eacute;l&eacute;phone sur un support</b>, l&eacute;g&egrave;rement de biais vers l'objectif, au premier plan
    &agrave; gauche &mdash; et la <b>machine</b> derri&egrave;re, au centre&nbsp;/&nbsp;&agrave; droite.</p>
    <p><b>Tout le bloc 3 se filme en une seule prise continue.</b> C'est ton arme la plus forte&nbsp;:
    personne ne peut soup&ccedil;onner un montage. On voit le doigt toucher l'&eacute;cran, et la machine bouger,
    dans la m&ecirc;me image.</p>
    <p class="warn"><b>Le seul vrai risque&nbsp;: le texte du t&eacute;l&eacute;phone sera illisible sur un projecteur
    depuis 2&nbsp;m.</b> Trois parades, de la meilleure &agrave; la plus simple&nbsp;:</p>
    <ol>
      <li><b>Duplique l'&eacute;cran du t&eacute;l&eacute;phone sur un laptop</b> pos&eacute; &agrave; c&ocirc;t&eacute; de la machine.
          Grand texte, m&ecirc;me cadre, probl&egrave;me r&eacute;gl&eacute;. <b>&Agrave; privil&eacute;gier.</b></li>
      <li>Aboubacar fait un <b>lent zoom avant</b> sur le t&eacute;l&eacute;phone au moment o&ugrave; tu tapes, puis ressort.</li>
      <li><b>Dans tous les cas&nbsp;: lis &agrave; voix haute tout ce qui s'affiche.</b>
          Ne compte jamais sur la salle pour lire l'&eacute;cran.</li>
    </ol>
    <p class="warn"><b>Le son&nbsp;:</b> la machine couvrira ta voix. Le script est &eacute;crit pour &ccedil;a &mdash;
    <b>tu parles quand elle est &agrave; l'arr&ecirc;t, tu te tais quand elle bouge.</b> Les silences sont voulus&nbsp;:
    ils laissent entendre la machine, et c'est exactement ce qu'on veut entendre.</p>
    <p><b>R&eacute;p&egrave;te 3 fois, filme 4 prises.</b> Une petite h&eacute;sitation dans un plan continu fait plus vrai
    qu'un montage parfait. Ne cherche pas la perfection, cherche la continuit&eacute;.</p>
  </div>
</div>"""

B3 = block("3", "LA D&Eacute;MO &mdash; UN SEUL PLAN", "1:05 &rarr; 3:05", D_INTRO
    + '<div class="beat">3.1 &mdash; On pose le cadre <span class="btc">1:05</span></div>'
    + say("What you see now is one single shot.",
          "The phone, and the machine, in the same frame. Nothing is cut between them.",
          "When I touch the screen, you will see the machine move. Live.")
    + note("Cette phrase-l&agrave; vaut de l'or devant cette salle. Elle dit &laquo;&nbsp;c'est r&eacute;el&nbsp;&raquo; "
           "sans avoir &agrave; demander qu'on te croie.")

    + '<div class="beat">3.2 &mdash; La connexion <span class="btc">1:20</span></div>'
    + act("Tu montres l'app &agrave; l'&eacute;cran. Le DRO affiche les positions en direct.")
    + say("This is our app. It is connected to the machine over WiFi.",
          "These five numbers are the five axes, in real time. Three linear, two rotary.")
    + say("When the machine moves, these numbers move with it.", opt=True)

    + '<div class="beat">3.3 &mdash; La vraie barri&egrave;re <span class="btc">1:35</span></div>'
    + say("Now, normally, to cut a part on a machine like this, you need a CNC programmer.",
          "Someone who writes G-code, line by line.",
          "In Mali, those people are rare, and they are expensive.",
          "That is the real reason small workshops never buy these machines.",
          "It is not only the price of the machine. It is the price of the person who runs it.")
    + note("La derni&egrave;re phrase est la plus importante de toute la vid&eacute;o pour un public non technique. "
           "C'est elle qui explique pourquoi baisser le prix de la machine ne suffisait pas.")

    + '<div class="beat">3.4 &mdash; On parle &agrave; la machine <span class="btc">1:55</span></div>'
    + say("So instead, I simply tell it what I want.")
    + act("Tu tapes ta commande. <b>Lis-la &agrave; voix haute pendant que tu tapes.</b>")
    + say("I am typing: &#10214;&nbsp;ta commande r&eacute;elle, en anglais, une phrase simple&nbsp;&#10215;")
    + say("And here is the part that matters.",
          "It does not just do it.")
    + act("Tu montres la demande de confirmation &agrave; l'&eacute;cran, et tu la lis.")
    + say("It tells me exactly what it is about to do, and it waits for me to say yes.",
          "It is asking me for permission. I read it. And I confirm.")
    + act("Tu confirmes. <b>La machine part.</b>")
    + pause("<b>TAIS-TOI 5&nbsp;SECONDES.</b> On regarde la machine travailler, avec le son r&eacute;el. "
            "C'est le plan le plus fort de ta vid&eacute;o &mdash; ne parle pas par-dessus.")
    + say("That is it. No G-code. No programmer. One sentence.")

    + '<div class="beat">3.5 &mdash; La s&eacute;curit&eacute; <span class="btc">2:25</span></div>'
    + say("Now, a machine like this can destroy itself in one second. And it can hurt someone.",
          "So before any movement, the system simulates the whole path first.",
          "Let me ask it to do something unsafe.")
    + act("Tu envoies une commande dangereuse (trajectoire qui taperait la table, ou hors course). "
          "<b>Lis le refus &agrave; voix haute.</b>")
    + say("It refuses. It tells me why. And you can see the machine did not move.")

    + '<div class="beat">3.6 &mdash; L&rsquo;arr&ecirc;t d&rsquo;urgence <span class="btc">2:45</span></div>'
    + act("Ta main se pose sur le bouton d'arr&ecirc;t d'urgence physique. Plan serr&eacute; si possible.")
    + say("And this button always works.",
          "The AI can never block it, never delay it, never overrule it.",
          "The AI is not in control. The operator is.",
          "The AI only removes the barrier.")
    + note("C'est le passage qui va rassurer les gens s&eacute;rieux dans la salle. Une IA qui pilote une machine "
           "qui coupe de l'acier, &ccedil;a inqui&egrave;te &mdash; jusqu'&agrave; ce que tu montres qui garde la main.")

    + '<div class="beat">3.7 &mdash; On conclut la d&eacute;mo <span class="btc">2:57</span></div>'
    + say("So a workshop owner who has never written a line of code can run a five-axis machine.",
          "That is the whole idea."),
    why="Le guide interdit explicitement les slides avec voix off &agrave; la place d'une d&eacute;mo, et demande "
        "<b>un seul cas d'usage, du d&eacute;but &agrave; la fin, comme un vrai utilisateur le vivrait</b>. "
        "C'est exactement ce bloc &mdash; et en une prise continue, c'est imparable.")

B4 = block("4", "O&Ugrave; ON EN EST", "3:05 &rarr; 3:35",
    act("Toi et Aboubacar devant la machine. On voit le vrai atelier. "
        "<b>Demande son accord avant de le filmer</b> &mdash; le guide l'exige.")
    + say("Where we are today, honestly.",
          "The machine is built and it runs. What you just saw is not a render. It is in our workshop.",
          "The app and the AI agent work on real hardware, not in a simulation.")
    + say("The code is open source. Anyone can look at it.", opt=True)
    + say("We are two people. Me, and Aboubacar Diamout&eacute;n&eacute;, our electronics and assembly technician.",
          "And we have had our first conversation with a machine shop here in Bamako, Kouratechnique, "
          "about testing it in real production.",
          "That is where we are. A working machine, and our first customer conversations."),
    why="Le guide est cat&eacute;gorique&nbsp;: &laquo;&nbsp;Tested with 40 farmers in two districts&nbsp;&raquo; bat "
        "&laquo;&nbsp;impacting thousands&nbsp;&raquo;. Tu ne pr&eacute;tends pas avoir des clients payants&nbsp;; "
        "tu dis exactement ce que tu as. Et ce que tu as est d&eacute;j&agrave; rare. "
        "Dans cette salle, quelqu'un saura faire la diff&eacute;rence.")

B5 = block("5", "UNIPODS &amp; METI", "3:35 &rarr; 3:58",
    say("We were selected for cohort one of the METI AI UniPods programme. "
        "670 applications, 24 countries.")
    + say("I am doing the MIT Emerging Talent course and the Wadhwani entrepreneurship programme, "
          "and the AI Institute training in Addis Ababa is coming.", opt=True)
    + say("And here is what it has changed for me.",
        "I am an engineer. Building the machine was never the hard part.",
        "What I could not do was talk to customers, size a market, explain the business.",
        "That is exactly what this programme is forcing me to learn.",
        "It is uncomfortable. That is how I know it is working."),
    why="Le guide demande express&eacute;ment ce bloc &mdash; c'est leur &eacute;v&eacute;nement, leur programme, "
        "ne le saute pas. Tout le monde va dire que le programme est formidable. Toi tu dis "
        "<b>pr&eacute;cis&eacute;ment ce que tu ne savais pas faire</b>. C'est la phrase que la salle retiendra, "
        "et elle sert le programme mille fois mieux qu'un compliment.")

B6 = block("6", "LA CL&Ocirc;TURE", "3:58 &rarr; 4:20",
    act("Cadre un peu plus serr&eacute;, machine visible derri&egrave;re toi. <b>Regarde l'objectif.</b>")
    + say("My vision is simple.",
          "Every workshop in Africa able to make any part it is asked for. Here. Not imported.",
          "To get there, I need three things.",
          "Workshops willing to pilot the machine.",
          "Manufacturing partners to help us build the first production batch.",
          "And investors who understand that African industry starts with African machines.",
          "My name is Lamine SACKO. This is Forgeron. Thank you.")
    + act("Dernier plan&nbsp;: la machine qui tourne, 2&nbsp;secondes. Puis noir. "
          "<b>Pas de musique.</b>"),
    why="Le guide demande &laquo;&nbsp;your vision in one sentence, and what would help you grow&nbsp;&raquo;. "
        "Trois demandes pr&eacute;cises valent mieux qu'un &laquo;&nbsp;nous cherchons des partenaires&nbsp;&raquo; "
        "vague&nbsp;: dans cette salle, quelqu'un peut cocher l'une des trois.", keep=True)

# --- back matter ------------------------------------------------------

CUTS = """
<section class="blk keep">
  <div class="blkhd"><span class="bnum">&#9986;</span><h2>SI TU D&Eacute;PASSES 4:30, COUPE DANS CET ORDRE</h2></div>
  <div class="cutbody">
    <p>Le maximum absolu est <b>5&nbsp;minutes</b> &mdash; au-del&agrave;, la vid&eacute;o n'est m&ecirc;me pas
    examin&eacute;e. Chronom&egrave;tre-toi avant de monter. Les quatre passages marqu&eacute;s
    <span class="scissors">&#9986;</span> dans le script sautent sans rien casser. Ordre de sacrifice&nbsp;:</p>
    <ol>
      <li><b>Bloc&nbsp;2</b> &mdash; &laquo;&nbsp;Africa produces less than two percent&hellip;&nbsp;&raquo; + &laquo;&nbsp;This is one of the reasons why.&nbsp;&raquo; <i>(~8&nbsp;s)</i></li>
      <li><b>Bloc&nbsp;3.2</b> &mdash; &laquo;&nbsp;When the machine moves, these numbers move with it.&nbsp;&raquo; <i>(~4&nbsp;s)</i></li>
      <li><b>Bloc&nbsp;5</b> &mdash; la liste des formations (MIT, Wadhwani, Addis). Tu gardes le &laquo;&nbsp;670 applications&nbsp;&raquo; et toute la chute. <i>(~10&nbsp;s)</i></li>
      <li><b>Bloc&nbsp;4</b> &mdash; &laquo;&nbsp;The code is open source.&nbsp;&raquo; <i>(~4&nbsp;s)</i></li>
    </ol>
    <p>&Ccedil;a te rend environ <b>25&nbsp;secondes</b>. Si ce n'est toujours pas assez, dernier recours&nbsp;:
    supprime <b>une</b> des trois demandes du bloc&nbsp;6 &mdash; mais garde-en au moins deux.</p>
    <p class="warn"><b>Ne coupe jamais&nbsp;:</b> les 25 premi&egrave;res secondes, le silence de 5&nbsp;s pendant que
    la machine bouge, le refus de la commande dangereuse, et la phrase sur l'arr&ecirc;t d'urgence.</p>
  </div>
</section>"""

SHOTS = """
<section class="blk keep">
  <div class="blkhd"><span class="bnum">&#9635;</span><h2>LISTE DE TOURNAGE</h2></div>
  <table class="tbl">
    <tr><th>&nbsp;</th><th>Plan</th><th>Note</th></tr>
    <tr><td class="ck"></td><td><b>A</b> &mdash; Machine qui usine, plan serr&eacute; sur l'outil</td><td>Le plan d'ouverture. Soigne-le. Son r&eacute;el.</td></tr>
    <tr><td class="ck"></td><td><b>B</b> &mdash; Toi debout &agrave; c&ocirc;t&eacute; de la machine</td><td>Blocs 1, 3.7, 4</td></tr>
    <tr><td class="ck"></td><td><b>C</b> &mdash; Toi face cam&eacute;ra, plan poitrine</td><td>Blocs 2 et 6, fond propre</td></tr>
    <tr><td class="ck"></td><td><b>D</b> &mdash; <b>LA D&Eacute;MO EN UN SEUL PLAN</b> (t&eacute;l&eacute;phone + machine)</td><td><b>Le plan cl&eacute;. 4 prises minimum.</b></td></tr>
    <tr><td class="ck"></td><td><b>E</b> &mdash; Plan serr&eacute; sur le bouton d'arr&ecirc;t d'urgence</td><td>Secours si le plan D ne le montre pas bien</td></tr>
    <tr><td class="ck"></td><td><b>F</b> &mdash; Toi + Aboubacar devant la machine</td><td>Bloc 4 &mdash; avec son accord</td></tr>
    <tr><td class="ck"></td><td><b>G</b> &mdash; L'atelier en large</td><td>Plan de respiration</td></tr>
    <tr><td class="ck"></td><td><b>H</b> &mdash; <i>(bonus)</i> Atelier de Bamako / pi&egrave;ce cass&eacute;e</td><td>Seulement si tu as le temps</td></tr>
  </table>
  <p class="tip">Filme chaque bloc <b>3 fois de suite</b> sans t'arr&ecirc;ter. La 3<sup>e</sup> prise est presque
  toujours la meilleure, et tu ne veux pas avoir &agrave; retourner &agrave; l'atelier demain matin.</p>
</section>"""

TECH = """
<section class="blk keep">
  <div class="blkhd"><span class="bnum">&#9881;</span><h2>CHECKLIST TECHNIQUE</h2></div>
  <div class="two">
    <div>
      <table class="tbl">
        <tr><td class="ck"></td><td><b>Paysage, jamais portrait</b> &mdash; v&eacute;rifie avant chaque prise</td></tr>
        <tr><td class="ck"></td><td><b>1080p minimum</b> &mdash; r&eacute;gle la cam&eacute;ra avant de commencer</td></tr>
        <tr><td class="ck"></td><td><b>Le son compte plus que l'image</b> &mdash; pi&egrave;ce calme, ventilateurs coup&eacute;s</td></tr>
        <tr><td class="ck"></td><td>Micro pr&egrave;s de toi, ou micro-cravate &agrave; 5&nbsp;000&nbsp;FCFA</td></tr>
        <tr><td class="ck"></td><td><b>Face &agrave; la fen&ecirc;tre</b>, jamais la fen&ecirc;tre derri&egrave;re toi</td></tr>
        <tr><td class="ck"></td><td>Cam&eacute;ra sur tr&eacute;pied ou pile de livres &mdash; jamais &agrave; la main</td></tr>
        <tr><td class="ck"></td><td>Mode avion pendant la d&eacute;mo &mdash; z&eacute;ro notification</td></tr>
        <tr><td class="ck"></td><td>Texte zoom&eacute; &mdash; pense &agrave; un projecteur, salle de 300 personnes</td></tr>
        <tr><td class="ck"></td><td>Anglais &middot; <b>MP4</b> &middot; <b>5&nbsp;min maximum</b></td></tr>
      </table>
    </div>
    <div class="avoid">
      <div class="avoidhd">&#10060;&nbsp; &Agrave; &Eacute;VITER (liste du guide)</div>
      <ul>
        <li>Des slides avec voix off &agrave; la place d'une d&eacute;mo</li>
        <li>De la musique qui couvre ta voix &rarr; <b>le plus simple&nbsp;: aucune musique</b></li>
        <li>Des donn&eacute;es personnelles &agrave; l'&eacute;cran</li>
        <li>Musique, images ou logos dont tu n'as pas les droits</li>
        <li>Filmer quelqu'un sans son accord</li>
      </ul>
      <div class="avoidhd2">&#9888; Ta vid&eacute;o YouTube actuelle est un <b>Short</b>, donc verticale.
      Elle est <b>inutilisable</b> telle quelle. Il faut refilmer en paysage.</div>
    </div>
  </div>
</section>"""

PLAN = """
<section class="blk keep">
  <div class="blkhd"><span class="bnum">&#9201;</span><h2>LE PLANNING</h2>
  <span class="tc">&#233;ch&#233;ance&nbsp;: 12h00 Bamako</span></div>
  <table class="tbl sched">
    <tr><th>Quand</th><th>Quoi</th><th>Dur&eacute;e</th></tr>
    <tr class="tonight"><td>Ce soir 18h00</td><td>Relis le script 3 fois &agrave; voix haute. Chronom&egrave;tre-toi.</td><td>30 min</td></tr>
    <tr class="tonight"><td>18h30</td><td>Pr&eacute;pare l'atelier&nbsp;: lumi&egrave;re, rangement, machine pr&ecirc;te, batteries</td><td>30 min</td></tr>
    <tr class="tonight"><td>19h00</td><td><b>Le plan D&nbsp;: la d&eacute;mo en une prise. 4 prises minimum.</b></td><td>1 h 30</td></tr>
    <tr class="tonight"><td>20h30</td><td>Tous les autres plans (A, B, C, E, F, G)</td><td>1 h 15</td></tr>
    <tr class="tonight"><td>21h45</td><td>Revois les rushes. <b>Il manque quoi&nbsp;?</b> Tu es encore &agrave; l'atelier.</td><td>30 min</td></tr>
    <tr><td>Demain 06h30</td><td>Montage</td><td>2 h 30</td></tr>
    <tr><td>09h00</td><td>Regarde en entier. Chronom&egrave;tre. <b>Montre-la &agrave; quelqu'un hors du m&eacute;tier.</b></td><td>45 min</td></tr>
    <tr><td>09h45</td><td>Corrections</td><td>45 min</td></tr>
    <tr><td>10h30</td><td>Export MP4, renommage, upload Drive, partage public</td><td>45 min</td></tr>
    <tr class="send"><td>11h15</td><td><b>Envoie l'email</b></td><td>15 min</td></tr>
    <tr class="buf"><td>11h30 &rarr; 12h00</td><td>&#128739; <b>Marge de s&eacute;curit&eacute;. Ne la consomme pas.</b></td><td>&mdash;</td></tr>
  </table>
  <p class="tip"><b>Montage&nbsp;: le minimum vital.</b> CapCut sur t&eacute;l&eacute;phone ou Clipchamp sur PC suffisent.
  Tu fais trois choses&nbsp;: coller les meilleures prises dans l'ordre des blocs, couper les silences et
  h&eacute;sitations en d&eacute;but et fin de prise, v&eacute;rifier que le son est r&eacute;gulier d'un plan &agrave; l'autre.
  <b>Pas de transitions, pas d'effets, pas de musique.</b> Le contenu porte tout seul.</p>
</section>"""

SUBMIT = """
<section class="blk keep">
  <div class="blkhd"><span class="bnum">&#9993;</span><h2>NOM DU FICHIER &amp; EMAIL DE SOUMISSION</h2></div>
  <p class="fname">Mali_Forgeron_LamineSACKO.mp4</p>
  <p class="tip"><b>&Agrave;&nbsp;:</b> unipods.regional@undp.org &nbsp;&middot;&nbsp;
  <b>Objet&nbsp;:</b> Video submission &mdash; Mali &mdash; Forgeron &mdash; Lamine SACKO</p>
  <pre class="mail">Dear UniPods team,

Please find below my video submission for the "Building the Workforce
of the Future" segment at GABI Unstoppable Africa.

Video link (anyone with the link can view):
&#10214; LIEN GOOGLE DRIVE &#10215;

Full name:     Lamine SACKO
Country:       Mali
UniPod:        UniPod Mali &mdash; &Eacute;cole Nationale d'Ing&eacute;nieurs Abderhamane
               Baba Tour&eacute; (ENI-ABT), Bamako
Solution name: Forgeron
One-line description:
    Forgeron is an affordable 5-axis CNC machine, built in Mali,
    that a workshop operates in plain language through an AI agent
    &mdash; no CNC programmer required.
Email:         sackolamine994@gmail.com
Phone:         &#10214; +223 &hellip; &#10215;

Duration: &#10214; 4:18 &#10215; &middot; Format: MP4 &middot; 1080p &middot; landscape

Thank you for the opportunity.

Best regards,
Lamine SACKO
Founder &amp; Engineer, Forgeron
Cohort 1 &mdash; METI AI UniPods Programme</pre>
  <div class="warnbox">
    <b>&#9888; Deux choses &agrave; ne pas rater.</b>
    <b>1.</b> Le partage Drive doit &ecirc;tre <b>&laquo;&nbsp;Anyone with the link can view&nbsp;&raquo;</b> &mdash;
    c'est exactement ce qui avait bloqu&eacute; les photos de la machine. <b>Teste le lien en navigation
    priv&eacute;e avant d'envoyer.</b>
    <b>2.</b> Mets ton num&eacute;ro <b>avec l'indicatif +223</b>.
  </div>
</section>"""

KEY = """
<section class="blk keep">
  <div class="blkhd"><span class="bnum">&#9733;</span><h2>LES SIX PHRASES &Agrave; SAVOIR PAR C&OElig;UR</h2></div>
  <p class="tip">Si tu ne retiens rien d'autre, retiens celles-l&agrave;. Elles portent toute la vid&eacute;o.</p>
  <ol class="key">
    <li>An imported one costs about forty thousand dollars. This one costs fifteen.</li>
    <li>You don&rsquo;t program it. You talk to it.</li>
    <li>It is not only the price of the machine. It is the price of the person who runs it.</li>
    <li>It tells me exactly what it is about to do, and it waits for me to say yes.</li>
    <li>The AI is not in control. The operator is. The AI only removes the barrier.</li>
    <li>Building the machine was never the hard part. Talking to customers was.</li>
  </ol>
  <div class="edge">
    <b>Ton vrai avantage.</b> La plupart des candidats vont envoyer un &eacute;cran&nbsp;: une app, une d&eacute;mo
    logicielle. Toi, tu as <b>une machine en m&eacute;tal qui coupe de l'acier, film&eacute;e dans ton atelier &agrave;
    Bamako, dans le m&ecirc;me plan que l'IA qui la pilote.</b> Dans une salle o&ugrave; l'on parle de
    &laquo;&nbsp;workforce of the future&nbsp;&raquo;, c'est le plan qu'on n'oublie pas.
    <b>Filme la machine. Longtemps. Avec le son.</b>
  </div>
</section>"""

# ---------------------------------------------------------------- shell

HEAD = """
<header class="hero">
  <div class="kicker">timbuktoo UniPods &middot; GABI Unstoppable Africa &middot; New York, UNGA</div>
  <h1>Script de tournage &mdash; vid&eacute;o GABI</h1>
  <div class="sub">FORGERON &middot; Lamine SACKO &middot; Mali &middot; UniPod Mali (ENI-ABT)</div>
  <div class="deadline">
    <span class="dl1">&#9200; Date limite &mdash; vendredi 18 septembre</span>
    <span class="dl2">14h00 CAT = <b>12h00 &agrave; Bamako</b></span>
    <span class="dl3">Le CAT est UTC+2, le Mali UTC+0. Tu as jusqu'&agrave; <b>midi</b>, pas 14h.</span>
  </div>
  <div class="rules">
    <div class="rule"><b>1</b><span>Les <b>10 premi&egrave;res secondes</b> d&eacute;cident si on continue &agrave; regarder. On ouvre sur la machine qui tourne.</span></div>
    <div class="rule"><b>2</b><span>Une <b>d&eacute;mo</b>, pas des slides. Le guide l'interdit explicitement &mdash; et la machine existe.</span></div>
    <div class="rule"><b>3</b><span><b>Paysage</b>, 1080p, MP4, <b>5&nbsp;min max</b>. Cible&nbsp;: 4&nbsp;min 20.</span></div>
    <div class="rule"><b>4</b><span>Ne le lis <b>pas</b> mot &agrave; mot. Lis-le 3&ndash;4 fois, retiens l'id&eacute;e de chaque bloc, puis <b>parle</b>.</span></div>
  </div>
</header>"""

LEGEND = """
<div class="legend">
  <span><i class="lg-say"></i> Ce que tu dis, mot pour mot (anglais)</span>
  <span><i class="lg-act"></i> Ce que tu fais / ce qu'on voit</span>
  <span><i class="lg-cut"></i> Ligne coupable si tu d&eacute;passes</span>
</div>"""

CSS = """
@page { size: A4; margin: 13mm 14mm 12mm 14mm; }
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body {
  font-family: "DejaVu Sans", "Liberation Sans", sans-serif;
  color: #1f2733; margin: 0; font-size: 9.2pt; line-height: 1.45;
}
h1, h2 { margin: 0; }

/* ---- hero ---- */
.hero { border-bottom: 3px solid #c8551a; padding-bottom: 9px; margin-bottom: 11px; }
.kicker { font-size: 7.4pt; letter-spacing: .14em; text-transform: uppercase;
          color: #8b7a6a; font-weight: bold; }
.hero h1 { font-size: 21pt; letter-spacing: -.01em; margin: 3px 0 2px; }
.sub { font-size: 9.6pt; color: #5a6675; font-weight: bold; letter-spacing: .02em; }
.deadline { margin-top: 9px; background: #fff3ec; border: 1.5px solid #c8551a;
            border-radius: 4px; padding: 7px 10px; }
.dl1 { display: block; font-weight: bold; color: #a8410f; font-size: 10.4pt; }
.dl2 { display: block; font-size: 12pt; font-weight: bold; margin-top: 1px; }
.dl3 { display: block; font-size: 8.4pt; color: #6b5c4e; margin-top: 2px; }
.rules { display: grid; grid-template-columns: 1fr 1fr; gap: 5px 12px; margin-top: 9px; }
.rule { display: flex; gap: 7px; align-items: flex-start; font-size: 8.4pt; }
.rule > b { flex: 0 0 15px; height: 15px; border-radius: 50%; background: #1f2733;
            color: #fff; text-align: center; line-height: 15px; font-size: 7.6pt; }

/* ---- legend ---- */
.legend { display: flex; gap: 16px; font-size: 7.6pt; color: #6b7686;
          border-bottom: 1px solid #e4e8ee; padding-bottom: 6px; margin-bottom: 12px; }
.legend span { display: flex; align-items: center; gap: 5px; }
.legend i { width: 13px; height: 9px; border-radius: 2px; display: inline-block; }
.lg-say { background: #fff; border-left: 3px solid #c8551a; border-top: 1px solid #ddd;
          border-right: 1px solid #ddd; border-bottom: 1px solid #ddd; }
.lg-act { background: #eef1f5; }
.lg-cut { background: #fff; border: 1px dashed #b9a48f; }

/* ---- blocks ---- */
.blk { margin-bottom: 15px; }
.blk.keep { break-inside: avoid; }
.blkhd { display: flex; align-items: center; gap: 9px; margin-bottom: 7px;
         border-bottom: 1.5px solid #1f2733; padding-bottom: 4px;
         break-after: avoid; break-inside: avoid; }
.bnum { flex: 0 0 auto; min-width: 21px; height: 21px; padding: 0 5px; background: #c8551a; color: #fff;
        border-radius: 3px; text-align: center; line-height: 21px;
        font-weight: bold; font-size: 10.5pt; }
.blkhd h2 { font-size: 12.4pt; letter-spacing: .02em; flex: 1; }
.tc { font-family: "DejaVu Sans Mono", monospace; font-size: 8.4pt; color: #fff;
      background: #1f2733; padding: 2px 7px; border-radius: 3px; white-space: nowrap; }

/* ---- spoken ---- */
.say { border-left: 3px solid #c8551a; background: #fffdfb; padding: 6px 10px 6px 11px;
       margin: 6px 0; break-inside: avoid; }
.say p { margin: 0 0 4px; font-size: 10.6pt; line-height: 1.5; }
.say p:last-child { margin-bottom: 0; }
.say.opt { border-left-style: dashed; border-left-color: #b9a48f; background: #fbfaf8; }
.scissors { color: #b9a48f; margin-right: 5px; }

/* ---- action ---- */
.act { background: #eef1f5; border-radius: 3px; padding: 5px 9px; margin: 6px 0;
       font-size: 8.5pt; color: #3d4a5a; break-inside: avoid; }
.acthd { display: inline-block; font-size: 6.8pt; font-weight: bold; letter-spacing: .12em;
         text-transform: uppercase; color: #8894a5; margin-right: 7px; }
.pausebox { background: #1f2733; color: #fff; border-radius: 3px; padding: 7px 10px;
            margin: 6px 0; font-size: 9pt; break-inside: avoid; }
.note { font-size: 8.3pt; color: #6b5c4e; background: #fdf8f2; border-radius: 3px;
        padding: 5px 9px; margin: 5px 0; break-inside: avoid; }
.why { font-size: 8.3pt; color: #4a5568; border-top: 1px dotted #c9d0da;
       padding-top: 5px; margin-top: 7px; break-inside: avoid; break-before: avoid; }
.beat { font-size: 9.6pt; font-weight: bold; color: #a8410f; margin: 11px 0 3px;
        letter-spacing: .01em; display: flex; align-items: baseline; gap: 8px;
        break-after: avoid; break-inside: avoid; }
.btc { font-family: "DejaVu Sans Mono", monospace; font-size: 7.6pt; color: #8894a5;
       font-weight: normal; }

/* ---- setup box ---- */
.setup { border: 1.5px solid #1f2733; border-radius: 4px; margin: 4px 0 10px; break-inside: avoid; }
.setuphd { background: #1f2733; color: #fff; font-weight: bold; font-size: 9.4pt;
           padding: 5px 10px; }
.setupbody { padding: 8px 11px; font-size: 8.7pt; }
.setupbody p { margin: 0 0 6px; }
.setupbody ol { margin: 4px 0 6px; padding-left: 18px; }
.setupbody li { margin-bottom: 3px; }
.warn { color: #a8410f; }

/* ---- tables ---- */
.tbl { width: 100%; border-collapse: collapse; font-size: 8.4pt; margin: 5px 0; }
.tbl th { text-align: left; font-size: 7.2pt; letter-spacing: .1em; text-transform: uppercase;
          color: #8894a5; border-bottom: 1px solid #c9d0da; padding: 3px 6px; }
.tbl td { padding: 4px 6px; border-bottom: 1px solid #edf0f4; vertical-align: top; }
.ck { width: 15px; }
.ck::before { content: ""; display: block; width: 9px; height: 9px; border: 1.2px solid #8894a5;
              border-radius: 2px; margin-top: 2px; }
.sched td:first-child { font-family: "DejaVu Sans Mono", monospace; font-size: 7.8pt;
                        white-space: nowrap; color: #5a6675; }
.sched td:last-child { text-align: right; color: #8894a5; font-size: 7.8pt; white-space: nowrap; }
.tonight td { background: #fffaf5; }
.send td { background: #ffe9dc; font-weight: bold; }
.buf td { background: #eef1f5; }

/* ---- misc ---- */
.two { display: grid; grid-template-columns: 1.25fr 1fr; gap: 12px; align-items: start; }
.avoid { border: 1.5px solid #c8551a; border-radius: 4px; padding: 7px 10px; background: #fff7f2; }
.avoidhd { font-weight: bold; font-size: 8.6pt; color: #a8410f; margin-bottom: 4px; }
.avoid ul { margin: 0; padding-left: 15px; font-size: 8.2pt; }
.avoid li { margin-bottom: 2px; }
.avoidhd2 { margin-top: 7px; padding-top: 6px; border-top: 1px solid #f0cdb8;
            font-size: 8.2pt; color: #a8410f; }
.tip { font-size: 8.4pt; color: #4a5568; margin: 6px 0; }
.cutbody { font-size: 8.6pt; }
.cutbody ol { margin: 5px 0; padding-left: 18px; }
.cutbody li { margin-bottom: 2px; }
.fname { font-family: "DejaVu Sans Mono", monospace; font-size: 11.5pt; font-weight: bold;
         background: #1f2733; color: #fff; padding: 7px 11px; border-radius: 3px;
         margin: 6px 0; letter-spacing: .01em; }
.mail { font-family: "DejaVu Sans Mono", monospace; font-size: 7.5pt; line-height: 1.38;
        background: #f7f9fb; border: 1px solid #dde3ea; border-radius: 3px;
        padding: 8px 10px; white-space: pre-wrap; margin: 5px 0; }
.warnbox { background: #fff3ec; border-left: 3px solid #c8551a; padding: 6px 10px;
           font-size: 8.3pt; border-radius: 0 3px 3px 0; }
.key { margin: 5px 0; padding-left: 20px; }
.key li { font-size: 10.2pt; margin-bottom: 5px; }
.edge { margin-top: 9px; background: #1f2733; color: #fff; border-radius: 4px;
        padding: 9px 12px; font-size: 8.8pt; line-height: 1.5; }
.pb { break-before: page; }
"""

DOC = f"""<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<title>Forgeron &mdash; Script vid&eacute;o GABI</title>
<style>{CSS}</style></head><body>
{HEAD}
{LEGEND}
{B1}
{B2}
{B3}
{B4}
{B5}
{B6}
{CUTS}
{SHOTS}
{TECH}
{PLAN}
{SUBMIT}
{KEY}
</body></html>"""

html_path = OUT / "gabi_script.html"
html_path.write_text(DOC, encoding="utf-8")

pdf_path = Path("/home/user/forgeron/scratch/Forgeron_Video_Script_GABI.pdf")
subprocess.run([
    CHROME, "--headless", "--disable-gpu", "--no-sandbox",
    "--no-pdf-header-footer", f"--print-to-pdf={pdf_path}",
    f"file://{html_path}",
], check=True, capture_output=True)
print("PDF:", pdf_path, pdf_path.stat().st_size, "bytes")
