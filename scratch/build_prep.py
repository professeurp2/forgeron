#!/usr/bin/env python3
"""Generate the Forgeron interview prep sheet (self-contained HTML)."""
import base64, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
logo_uri = "data:image/png;base64," + base64.b64encode((root / "assets/logo.png").read_bytes()).decode()

QA = [
    ("1 · “Tell us about yourself and Forgeron.”",
     "Ouverture — enchaîne directement sur ton pitch 60 s, en version courte.",
     "I'm Lamine SACKO, an engineer from Mali and founder of Forgeron. I built it end-to-end — "
     "the firmware, the real-time protocol, the app and the AI agent. Forgeron turns a cheap "
     "microcontroller into an AI-piloted 5-axis CNC controller, and I've already built a full "
     "working machine to prove it."),
    ("2 · “What problem are you solving, and for whom?”",
     "Coût + compétence. Reste concret et humain.",
     "Industrial 5-axis CNC controllers cost 5,000 to 50,000 dollars, are closed, and need highly "
     "trained operators. So African workshops, fablabs and manufacturing SMEs are locked out of "
     "precision manufacturing — and keep importing tooling, molds, prosthetics and spare parts that "
     "could be made locally."),
    ("3 · “How does the AI work — isn't it just a wrapper around Gemini?”  ★ LA question clé",
     "NE PANIQUE PAS — tu as la meilleure réponse du lot. L'IP, c'est la couche de sécurité, pas le modèle.",
     "The model is Gemini, but the value isn't the model — it's the safe control layer around it. "
     "The agent has 12 machine tools with per-tool permissions, and a lookahead validator that "
     "simulates the full toolpath against the machine's real mechanical limits BEFORE any motion, so "
     "the AI physically cannot cause a collision. I also route AI calls over mobile data while the "
     "phone stays on the machine's Wi-Fi, with multi-model fallback — built for African connectivity "
     "and cost. That safe industrial-control layer is the real IP."),
    ("4 · “What have you actually built? What's your traction?”",
     "Ta force = une VRAIE machine. Dis-le avec fierté, sans surpromettre.",
     "A fully built, working physical 5-axis machine — not a concept: ESP32, FluidNC, five stepper "
     "drivers, three linear plus two rotary Trunnion axes. Plus the functional app and AI agent, a "
     "demo video, and an open GitHub repo. I've had a first conversation with Kouratechnique, who are "
     "interested in testing and adopting it. We're a team of two."),
    ("5 · “Who is your customer and how big is the opportunity?”",
     "Tête de pont claire, puis élargis.",
     "Beachhead: machine shops, fablabs, technical schools and manufacturing SMEs across Africa that "
     "can't afford proprietary controllers. Then CNC-kit and desktop-CNC builders who need a "
     "controller layer. The maker and local-industrialization movement is growing fast across the "
     "continent."),
    ("6 · “What's your business model?”",
     "Simple, en escalier.",
     "Freemium app to drive adoption, a Pro subscription for the AI assistant and multi-machine "
     "management, certified hardware bundles as a hardware-attach line, and later a marketplace of "
     "verified machine configs."),
    ("7 · “Who competes with you? Why can't a big player just do this?”",
     "Positionne-toi entre le cher-fermé et le gratuit-limité.",
     "On one side, proprietary controllers — powerful but expensive and closed. On the other, free "
     "GRBL senders — cheap but no true 5-axis and no AI safety. Forgeron sits in the gap: affordable, "
     "5-axis, and safe natural-language control. My moat is the safety layer plus real machining data "
     "and certified configs, which take time to build."),
    ("8 · “Why do you need this programme, and what will you do with it?”",
     "Relie explicitement aux deux volets du programme.",
     "The prototype exists; I need to build the venture. The Ethiopian AI Institute skilling would "
     "help me harden the agent and move it toward on-device AI. The Wadhwani track is exactly my gap: "
     "customer discovery, business model, go-to-market and investment readiness — plus the Addis "
     "bootcamp and the timbuktoo network."),
    ("9 · “Can you fully commit — weekly training and travel to Addis Ababa?”",
     "Oui, franc et net. Tu as le passeport.",
     "Yes — I'm fully available for the weekly training and I hold a valid passport, so I can travel "
     "to Addis if selected. My technical teammate supports the build remotely."),
    ("10 · “Where will Forgeron be in 2–3 years?”",
     "Vision concrète, pas rêveuse.",
     "Forgeron controllers running in workshops across West and East Africa — a small company shipping "
     "the controller software and certified hardware kits, so local makers can produce precision parts "
     "that are imported today, creating skilled jobs."),
]

qa_html = "".join(
    f'<div class="qa"><div class="q">{q}</div>'
    f'<div class="coach">🎯 {c}</div>'
    f'<div class="ans">{a}</div></div>'
    for (q, c, a) in QA
)

HTML = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Forgeron — Interview Prep</title>
<style>
  :root {{
    --ink:#14181f; --ink2:#39434f; --muted:#6b7686;
    --steel:#1f2733; --steel2:#2b3644;
    --forge:#ff6a1a; --forge2:#ff8c42;
    --line:#e4e8ee; --soft:#f6f8fb;
    --ai:#0e5bd8; --ai-soft:#eef4fe;
    --ok:#0f9d58; --ok-soft:#e9f7ef; --warn:#c0392b; --warn-soft:#fdecea;
  }}
  * {{ box-sizing:border-box; margin:0; padding:0; }}
  html,body {{ color:var(--ink); font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
    -webkit-print-color-adjust:exact; print-color-adjust:exact; background:#fff; font-size:12px; line-height:1.5; }}
  @page {{ size:A4; margin:14mm 13mm; }}
  h1 {{ font-size:22px; letter-spacing:.3px; }}
  .top {{ display:flex; align-items:center; gap:12px; border-bottom:3px solid var(--forge); padding-bottom:10px; margin-bottom:12px; }}
  .top img {{ width:44px; height:44px; border-radius:10px; }}
  .top .sub {{ font-size:11px; color:var(--muted); text-transform:uppercase; letter-spacing:1px; font-weight:600; margin-top:2px; }}
  h2 {{ font-size:13px; text-transform:uppercase; letter-spacing:.8px; color:var(--forge); margin:16px 0 8px;
    display:flex; align-items:center; gap:8px; }}
  h2::before {{ content:""; width:14px; height:14px; background:var(--forge); border-radius:4px; display:inline-block; }}
  .logi {{ background:var(--steel); color:#fff; border-radius:11px; padding:12px 15px; display:flex; flex-wrap:wrap;
    gap:6px 22px; align-items:center; }}
  .logi b {{ color:var(--forge2); }}
  .logi .big {{ font-size:15px; font-weight:800; }}
  .pitch {{ display:grid; grid-template-columns:1fr 1fr; gap:10px; }}
  .pitch .card {{ border:1px solid var(--line); border-radius:11px; padding:11px 13px; background:var(--soft); }}
  .pitch .card.en {{ border-color:#cfe0fb; background:var(--ai-soft); }}
  .pitch h3 {{ font-size:10.5px; text-transform:uppercase; letter-spacing:.6px; color:var(--ai); margin-bottom:5px; }}
  .pitch .card.fr h3 {{ color:var(--muted); }}
  .pitch p {{ font-size:11.5px; line-height:1.55; }}
  .flow {{ display:flex; gap:8px; }}
  .flow .step {{ flex:1; border:1px solid var(--line); border-radius:10px; padding:9px 11px; background:#fff; }}
  .flow .step .t {{ font-size:9px; font-weight:800; color:var(--forge); text-transform:uppercase; letter-spacing:.5px; }}
  .flow .step .d {{ font-size:11px; margin-top:3px; color:var(--ink2); }}
  .flow .step .m {{ font-size:9px; color:var(--muted); margin-top:3px; }}
  .qa {{ border:1px solid var(--line); border-left:3px solid var(--ai); border-radius:9px; padding:9px 12px;
    margin-bottom:8px; background:#fff; page-break-inside:avoid; }}
  .qa .q {{ font-weight:800; font-size:12px; color:var(--ink); }}
  .qa .coach {{ font-size:10px; color:var(--warn); font-style:italic; margin:3px 0 5px; }}
  .qa .ans {{ font-size:11.5px; line-height:1.55; color:var(--ink2); }}
  .cols {{ display:grid; grid-template-columns:1fr 1fr; gap:10px; }}
  .box {{ border:1px solid var(--line); border-radius:11px; padding:11px 13px; page-break-inside:avoid; }}
  .box.show {{ border-color:#bfe6cd; background:var(--ok-soft); }}
  .box.avoid {{ border-color:#f2c7c1; background:var(--warn-soft); }}
  .box h3 {{ font-size:11px; text-transform:uppercase; letter-spacing:.6px; margin-bottom:6px; }}
  .box.show h3 {{ color:var(--ok); }} .box.avoid h3 {{ color:var(--warn); }}
  .box ul {{ list-style:none; }}
  .box li {{ font-size:11px; line-height:1.45; padding-left:16px; position:relative; margin-bottom:4px; color:var(--ink2); }}
  .box.show li::before {{ content:"✓"; position:absolute; left:0; color:var(--ok); font-weight:800; }}
  .box.avoid li::before {{ content:"✕"; position:absolute; left:0; color:var(--warn); font-weight:800; }}
  .box b {{ color:var(--ink); }}
  /* cheat sheet */
  .cheat {{ page-break-before:always; }}
  .cheat .grid {{ display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:6px; }}
  .cheat .cell {{ border:1px solid var(--line); border-radius:11px; padding:12px 14px; }}
  .cheat .cell.full {{ grid-column:1/-1; }}
  .cheat .cell h3 {{ font-size:10.5px; text-transform:uppercase; letter-spacing:.6px; color:var(--forge); margin-bottom:6px; }}
  .cheat .one {{ font-size:15px; font-weight:800; line-height:1.35; }}
  .cheat .one b {{ color:var(--forge); }}
  .cheat ul {{ list-style:none; }}
  .cheat li {{ font-size:12px; line-height:1.5; padding-left:15px; position:relative; margin-bottom:3px; color:var(--ink2); }}
  .cheat li::before {{ content:"▹"; position:absolute; left:0; color:var(--forge); font-weight:800; }}
  .cheat li b {{ color:var(--ink); }}
  .nums {{ display:flex; gap:8px; }}
  .nums .n {{ flex:1; text-align:center; background:var(--soft); border:1px solid var(--line); border-radius:9px; padding:8px 4px; }}
  .nums .n .v {{ font-size:16px; font-weight:800; color:var(--steel); }}
  .nums .n .l {{ font-size:8px; text-transform:uppercase; letter-spacing:.3px; color:var(--muted); margin-top:2px; }}
  .foot {{ margin-top:12px; padding-top:8px; border-top:1px solid var(--line); font-size:9.5px; color:var(--muted); }}
</style></head><body>

  <div class="top">
    <img src="{logo_uri}" alt="Forgeron">
    <div><h1>Fiche d'entretien — UniPods AI</h1>
      <div class="sub">Forgeron · Lamine SACKO · à relire avant le jour J</div></div>
  </div>

  <div class="logi">
    <span class="big">🎤 Lundi 31 août 2026 · <b>14h15</b> (heure Bamako, UTC+0)</span>
    <span>Durée <b>15 min</b> (~12 min d'entretien)</span>
    <span>Rejoins <b>5 min en avance</b></span>
  </div>

  <h2>Le pitch — 60 secondes (à savoir par cœur)</h2>
  <div class="pitch">
    <div class="card en">
      <h3>🇬🇧 English (version à réciter)</h3>
      <p>“Hi, I'm Lamine SACKO, an engineer from Mali and founder of Forgeron. Industrial 5-axis CNC
      controllers cost 5,000 to 50,000 dollars and need highly trained operators — so African workshops
      and manufacturing SMEs are locked out of precision manufacturing and keep importing tooling, molds
      and parts. Forgeron turns an 8-dollar microcontroller into an industrial-grade 5-axis controller you
      run from a phone. And its core is an AI agent — a large language model with function calling that
      drives the machine in plain language and validates every toolpath before it moves, so it can't cause
      a collision. I've already built and tested a full working 5-axis machine. My goal here is to move
      from a working prototype to a venture that democratizes precision manufacturing across Africa.”</p>
    </div>
    <div class="card fr">
      <h3>🇫🇷 Français (si tu préfères, ou en secours)</h3>
      <p>« Bonjour, je suis Lamine SACKO, ingenieur malien et fondateur de Forgeron. Les contrôleurs CNC
      5-axes industriels coûtent 5 000 à 50 000 dollars et exigent des opérateurs très qualifiés — les
      ateliers et PME africaines sont exclus de la fabrication de précision et importent outillage, moules
      et pièces. Forgeron transforme un microcontrôleur à 8 dollars en contrôleur 5-axes industriel, piloté
      depuis un téléphone. Son cœur, c'est un agent IA — un modèle de langage en function calling qui pilote
      la machine en langage naturel et valide chaque trajectoire avant tout mouvement, pour éviter toute
      collision. J'ai déjà construit et testé une machine 5-axes complète. Mon objectif : passer du prototype
      à une entreprise qui démocratise la fabrication de précision en Afrique. »</p>
    </div>
  </div>
  <p style="font-size:10.5px;color:var(--muted);margin-top:6px;">💡 Tu peux, poliment, demander au début : <i>“Would it be OK to do the interview in French?”</i> si tu es plus à l'aise. Sinon, l'anglais ci-dessus suffit largement.</p>

  <h2>Déroulé des 15 minutes (garde le rythme)</h2>
  <div class="flow">
    <div class="step"><div class="t">0–1 min · Pitch</div><div class="d">Ton pitch 60 s, avec énergie.</div><div class="m">Accroche + IA + machine réelle.</div></div>
    <div class="step"><div class="t">1–4 min · Démo</div><div class="d">Montre l'app + la machine (voir plus bas).</div><div class="m">Cours, net ; vidéo en secours.</div></div>
    <div class="step"><div class="t">4–13 min · Q&amp;R</div><div class="d">Réponses courtes, puis tu t'arrêtes.</div><div class="m">Relie tout à l'impact + business.</div></div>
    <div class="step"><div class="t">13–15 · Clôture</div><div class="d">Remercie, redis “l'ask”, propose la suite.</div><div class="m">Souris, contact caméra.</div></div>
  </div>

  <h2>Questions probables &amp; réponses</h2>
  {qa_html}

  <div class="cols">
    <div class="box show">
      <h3>🖥️ Ce qu'il faut MONTRER (démo ~2–3 min)</h3>
      <ul>
        <li><b>Prépare avant :</b> machine visible, app ouverte en <b>mode simulation</b>, bonne lumière, lien vidéo prêt.</li>
        <li><b>1.</b> Le <b>DRO live</b> 5 axes (X/Y/Z/A/C).</li>
        <li><b>2.</b> L'<b>agent IA</b> : tape une commande en langage naturel (ex. <i>“home all axes, select G54, then jog Z +10 at 500”</i>) → montre l'exécution + la demande de permission.</li>
        <li><b>3. (le moment fort)</b> Une commande dangereuse → la <b>validation lookahead refuse</b> avant tout mouvement.</li>
        <li><b>Secours :</b> si le live plante, lance la <b>vidéo de 60 s</b>. Zéro stress.</li>
      </ul>
    </div>
    <div class="box avoid">
      <h3>⚠️ Pièges à éviter</h3>
      <ul>
        <li><b>Ne pas monologuer</b> — réponds, puis stoppe. 15 min, c'est court.</li>
        <li><b>Ne pas sur-vendre</b> — pas de faux utilisateurs/revenus. Tu es un MVP : l'honnêteté est une force.</li>
        <li><b>Pas de technique “hors-sol”</b> — relie chaque réponse à l'impact Afrique + au business.</li>
        <li><b>Ne pas te figer</b> sur “c'est juste un wrapper Gemini” → réponse = la couche de sécurité (Q3).</li>
        <li><b>Test technique</b> avant : internet, caméra, micro, machine alimentée.</li>
        <li><b>Énergie</b> : souris, regarde la caméra, parle avec conviction.</li>
      </ul>
    </div>
  </div>

  <div class="foot">Forgeron · préparation d'entretien UniPods AI Innovation Pipeline (timbuktoo / UNDP) — usage personnel, Lamine SACKO.</div>

  <!-- ===== PAGE 2 : FICHE EXPRESS ===== -->
  <div class="cheat">
    <div class="top">
      <img src="{logo_uri}" alt="Forgeron">
      <div><h1>Fiche express — 30 secondes avant</h1>
        <div class="sub">Un coup d'œil juste avant de rejoindre</div></div>
    </div>

    <div class="grid">
      <div class="cell full">
        <h3>En une phrase</h3>
        <div class="one">Un microcontrôleur à <b>8 $</b> transformé en <b>contrôleur CNC 5-axes piloté par IA</b>, pour les ateliers africains.</div>
      </div>

      <div class="cell full">
        <h3>Tes chiffres qui claquent</h3>
        <div class="nums">
          <div class="n"><div class="v">~8 $</div><div class="l">vs 5 000–50 000 $</div></div>
          <div class="n"><div class="v">5</div><div class="l">axes (X Y Z A C)</div></div>
          <div class="n"><div class="v">12</div><div class="l">outils IA sûrs</div></div>
          <div class="n"><div class="v">1</div><div class="l">machine réelle construite</div></div>
          <div class="n"><div class="v">2</div><div class="l">personnes (équipe)</div></div>
        </div>
      </div>

      <div class="cell">
        <h3>L'IA en une phrase</h3>
        <div class="one" style="font-size:12.5px;">Un agent LLM (function calling) + validation <b>lookahead</b> = une machine qu'on pilote en parlant, et qui <b>ne peut pas se casser</b>.</div>
      </div>
      <div class="cell">
        <h3>“L'ask”</h3>
        <ul>
          <li><b>Skilling IA</b> (Ethiopian AI Institute) → durcir l'agent, edge.</li>
          <li><b>Wadhwani</b> → prototype → venture (customers, GTM, investment).</li>
          <li><b>Réseau timbuktoo</b> + bootcamp Addis.</li>
        </ul>
      </div>

      <div class="cell">
        <h3>Montrer (3 choses)</h3>
        <ul>
          <li>DRO 5 axes en direct</li>
          <li>Commande IA exécutée (+ permission)</li>
          <li>Refus lookahead d'un mouvement dangereux</li>
        </ul>
      </div>
      <div class="cell">
        <h3>Éviter (3 choses)</h3>
        <ul>
          <li>Monologuer / dépasser le temps</li>
          <li>Sur-vendre (faux users/revenus)</li>
          <li>Technique sans lien impact/business</li>
        </ul>
      </div>

      <div class="cell full" style="background:var(--steel);color:#fff;border-color:var(--steel);">
        <h3 style="color:var(--forge2);">Logistique</h3>
        <div class="one" style="font-size:13px;">🎤 Lundi 31 août · <b style="color:var(--forge2);">14h15</b> Bamako · 15 min · rejoins 5 min avant · machine + app prêtes · vidéo en secours.</div>
      </div>
    </div>
    <div class="foot">Respire. Souris. Tu as construit une vraie machine 5-axes pilotée par IA — peu de candidats peuvent en dire autant. 🔥</div>
  </div>

</body></html>"""

out = root / "scratch/prep.html"
out.write_text(HTML, encoding="utf-8")
print("written", out, len(HTML))
