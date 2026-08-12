#!/usr/bin/env python3
"""Génère le one-pager Forgeron (HTML autonome, logo embarqué en base64)."""
import base64, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
logo_b64 = base64.b64encode((root / "assets/logo.png").read_bytes()).decode()
logo_uri = f"data:image/png;base64,{logo_b64}"

HTML = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Forgeron — One Pager</title>
<style>
  :root {{
    --ink:#14181f; --ink2:#3a4453; --muted:#6b7686;
    --steel:#1f2733; --steel2:#2b3644;
    --forge:#ff6a1a; --forge2:#ff8c42; --ember:#ffb347;
    --line:#e4e8ee; --bg:#ffffff; --soft:#f6f8fb;
    --ai:#0e5bd8; --ai-soft:#eaf1fe;
    --ok:#0f9d58; --ok-soft:#e8f6ee;
  }}
  * {{ box-sizing:border-box; margin:0; padding:0; }}
  html,body {{ background:var(--bg); color:var(--ink);
    font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
    -webkit-print-color-adjust:exact; print-color-adjust:exact; }}
  @page {{ size:A4; margin:0; }}
  .page {{ width:210mm; height:297mm; padding:8mm 12mm 7mm; margin:0 auto;
    display:flex; flex-direction:column; overflow:hidden; }}

  /* Header */
  header {{ display:flex; align-items:center; gap:12px; padding-bottom:10px;
    border-bottom:3px solid var(--forge); }}
  .logo {{ width:52px; height:52px; border-radius:12px; object-fit:cover;
    box-shadow:0 2px 8px rgba(0,0,0,.15); }}
  .brand h1 {{ font-size:28px; letter-spacing:.5px; line-height:1; }}
  .brand .sub {{ font-size:11.5px; color:var(--muted); margin-top:3px; font-weight:600;
    text-transform:uppercase; letter-spacing:1.2px; }}
  .tags {{ margin-left:auto; text-align:right; display:flex; flex-direction:column; gap:5px; align-items:flex-end;}}
  .pill {{ display:inline-block; font-size:9.5px; font-weight:700; padding:4px 9px;
    border-radius:999px; letter-spacing:.4px; }}
  .pill.ai {{ background:var(--ai-soft); color:var(--ai); }}
  .pill.ok {{ background:var(--ok-soft); color:var(--ok); }}

  /* Hero */
  .hero {{ margin-top:9px; background:linear-gradient(115deg,var(--steel),var(--steel2));
    color:#fff; border-radius:13px; padding:12px 16px; position:relative; overflow:hidden; }}
  .hero::after {{ content:""; position:absolute; right:-40px; top:-40px; width:180px; height:180px;
    background:radial-gradient(circle,rgba(255,106,26,.35),transparent 70%); }}
  .hero .kicker {{ font-size:10.5px; font-weight:700; letter-spacing:1.5px;
    text-transform:uppercase; color:var(--ember); }}
  .hero h2 {{ font-size:18px; line-height:1.26; margin-top:4px; font-weight:750; max-width:92%; }}
  .hero h2 b {{ color:var(--forge2); }}

  /* Grid */
  .grid {{ margin-top:9px; display:grid; grid-template-columns:1fr 1fr; gap:8px; }}
  .card {{ border:1px solid var(--line); border-radius:11px; padding:9px 12px; background:#fff; }}
  .card h3 {{ font-size:12px; text-transform:uppercase; letter-spacing:.8px; color:var(--forge);
    display:flex; align-items:center; gap:7px; margin-bottom:6px; }}
  .card h3 .n {{ width:18px; height:18px; border-radius:6px; background:var(--forge); color:#fff;
    font-size:10px; display:inline-flex; align-items:center; justify-content:center; font-weight:800; }}
  .card p {{ font-size:11px; line-height:1.5; color:var(--ink2); }}
  .card p + p {{ margin-top:5px; }}
  .card b {{ color:var(--ink); }}

  /* AI highlighted card spans full width */
  .card.ai-card {{ grid-column:1 / -1; border-color:#cfe0fb; background:linear-gradient(180deg,#fbfdff,#f3f8ff); }}
  .card.ai-card h3 {{ color:var(--ai); }}
  .card.ai-card h3 .n {{ background:var(--ai); }}
  .ai-cols {{ display:grid; grid-template-columns:1.15fr 1fr; gap:14px; }}
  .ai-feats {{ list-style:none; display:flex; flex-direction:column; gap:6px; }}
  .ai-feats li {{ font-size:10.5px; line-height:1.4; color:var(--ink2); padding-left:16px; position:relative; }}
  .ai-feats li::before {{ content:"▹"; position:absolute; left:0; color:var(--ai); font-weight:700; }}
  .ai-feats b {{ color:var(--ai); }}

  /* Traction band */
  .traction {{ grid-column:1 / -1; display:grid; grid-template-columns:auto 1fr; gap:12px; align-items:center;
    border:1px solid var(--ok); background:var(--ok-soft); border-radius:11px; padding:9px 13px; }}
  .traction .badge {{ background:var(--ok); color:#fff; border-radius:10px; padding:9px 12px; text-align:center; }}
  .traction .badge .big {{ font-size:15px; font-weight:800; line-height:1.1; }}
  .traction .badge .small {{ font-size:8.5px; letter-spacing:.5px; text-transform:uppercase; margin-top:2px; opacity:.95; }}
  .traction p {{ font-size:10.5px; line-height:1.45; color:#256b45; }}
  .traction b {{ color:#0f5c34; }}

  /* Photo slot */
  .photo {{ grid-column:1 / -1; height:84px; border:1.5px dashed #c7d0dc; border-radius:12px;
    background:var(--soft); display:flex; align-items:center; justify-content:center; text-align:center; }}
  .photo span {{ font-size:10px; color:var(--muted); max-width:70%; line-height:1.4; }}
  .photo b {{ color:var(--ink2); }}

  /* Metrics strip */
  .metrics {{ grid-column:1 / -1; display:grid; grid-template-columns:repeat(4,1fr); gap:10px; }}
  .metric {{ border:1px solid var(--line); border-radius:10px; padding:7px; text-align:center; background:var(--soft); }}
  .metric .v {{ font-size:17px; font-weight:800; color:var(--steel); line-height:1; }}
  .metric .l {{ font-size:8.5px; color:var(--muted); text-transform:uppercase; letter-spacing:.5px; margin-top:4px; }}

  /* Footer */
  footer {{ margin-top:auto; padding-top:8px; border-top:1px solid var(--line);
    display:flex; align-items:center; gap:12px; }}
  .ask {{ flex:1; font-size:10px; color:var(--ink2); line-height:1.45; }}
  .ask b {{ color:var(--forge); }}
  .contact {{ text-align:right; font-size:9.5px; color:var(--muted); line-height:1.5; white-space:nowrap; }}
  .contact b {{ color:var(--ink); }}
  .deadline {{ display:inline-block; background:var(--steel); color:#fff; font-size:9px; font-weight:700;
    padding:3px 8px; border-radius:6px; letter-spacing:.4px; margin-top:4px; }}
</style>
</head>
<body>
<div class="page">
  <header>
    <img class="logo" src="{logo_uri}" alt="Forgeron">
    <div class="brand">
      <h1>FORGERON</h1>
      <div class="sub">Contrôleur CNC 5-axes · piloté par IA</div>
    </div>
    <div class="tags">
      <span class="pill ai">AI-ENABLED PROTOTYPE</span>
      <span class="pill ok">MACHINE PHYSIQUE FONCTIONNELLE</span>
    </div>
  </header>

  <div class="hero">
    <div class="kicker">METI-funded UniPods AI Programme · timbuktoo / UNDP</div>
    <h2>Le premier contrôleur CNC 5-axes <b>piloté par IA</b>, pensé pour l'industrie africaine —
       un microcontrôleur à 8&nbsp;$ transformé en machine-outil qu'on opère <b>en langage naturel</b>.</h2>
  </div>

  <div class="grid">
    <div class="card">
      <h3><span class="n">1</span> Le problème</h3>
      <p>Les contrôleurs CNC 5-axes industriels (Fanuc, Heidenhain, Siemens) coûtent
      <b>5 000 – 50 000&nbsp;$</b>, sont fermés et exigent des opérateurs très formés.</p>
      <p>Les ateliers, fablabs et PME manufacturières africaines sont donc <b>exclus</b> de
      la fabrication de précision — outillage, moules, prothèses, pièces — qui reste importée.</p>
    </div>
    <div class="card">
      <h3><span class="n">2</span> La solution</h3>
      <p>Forgeron transforme un <b>ESP32 (~8&nbsp;$)</b> sous firmware open-source FluidNC + drivers
      pas-à-pas bon marché en un <b>contrôleur 5-axes de grade industriel</b>, piloté depuis un
      smartphone ou un PC.</p>
      <p>DRO temps réel, jog 5 axes, streaming G-code, visualiseur 3D Trunnion, palpage, WCS,
      sécurité matérielle (arrêt d'urgence, watchdog).</p>
    </div>

    <div class="card ai-card">
      <h3><span class="n">IA</span> L'intelligence artificielle — le cœur du « next leap »</h3>
      <div class="ai-cols">
        <p>Un <b>agent IA agentique</b> (LLM en <i>function calling</i>) pilote la machine en langage
        naturel : «&nbsp;<i>palpe le centre de la pièce, puis lance le programme à 80&nbsp;% d'avance</i>&nbsp;».
        12 outils machine sûrs, planifiés et exécutés par l'agent. L'IA fait tomber la
        <b>barrière de compétence</b> qui tient la CNC hors de portée.</p>
        <ul class="ai-feats">
          <li><b>Contrôle agentique sûr</b> — permissions par outil + arrêt d'urgence toujours prioritaire</li>
          <li><b>Validation <i>lookahead</i></b> — simule tout le parcours vs. limites mécaniques réelles <b>avant</b> tout mouvement : l'IA ne peut pas provoquer de collision</li>
          <li><b>Résilience connectivité</b> — téléphone sur le WiFi machine, appels IA routés en 4G/5G ; repli multi-modèles pour rester gratuit</li>
        </ul>
      </div>
    </div>

    <div class="traction">
      <div class="badge">
        <div class="big">RÉEL</div>
        <div class="small">Hardware</div>
      </div>
      <p><b>La machine physique 5-axes est déjà construite et fonctionnelle</b> — ESP32 DevKit V1 +
      FluidNC v3.7 + 5× drivers TB6600, axes X/Y/Z linéaires + A/C rotatifs (Trunnion). Prototype
      démontré de bout en bout sur matériel réel, pas une simulation. <b>Prêt à passer de prototype à venture.</b></p>
    </div>

    <div class="photo">
      <span><b>[ Emplacement photo ]</b><br>Photo de la machine 5-axes réelle + capture de l'app en action à insérer ici</span>
    </div>

    <div class="metrics">
      <div class="metric"><div class="v">5</div><div class="l">Axes (X Y Z A C)</div></div>
      <div class="metric"><div class="v">~8&nbsp;$</div><div class="l">Coût contrôleur</div></div>
      <div class="metric"><div class="v">12</div><div class="l">Outils IA sûrs</div></div>
      <div class="metric"><div class="v">134</div><div class="l">Fichiers · tests auto</div></div>
    </div>

    <div class="card">
      <h3><span class="n">3</span> Marché &amp; modèle</h3>
      <p><b>Cible :</b> ateliers d'usinage, fablabs/makerspaces, écoles techniques et PME
      manufacturières d'Afrique ; puis fabricants de kits CNC.</p>
      <p><b>Revenu :</b> app freemium → abonnement Pro (IA, multi-machines, analytics) → bundles
      hardware certifiés → marketplace de configs machines.</p>
    </div>
    <div class="card">
      <h3><span class="n">4</span> Pourquoi ce programme</h3>
      <p>Le prototype est là ; il faut bâtir la <b>venture</b>. Skilling IA (Ethiopian AI Institute)
      pour durcir l'agent et viser l'edge/on-device.</p>
      <p>Parcours Wadhwani (14 sem.) : customer discovery, business model, go-to-market,
      <b>investment readiness</b> + réseau timbuktoo.</p>
    </div>
  </div>

  <footer>
    <div class="ask"><b>La demande :</b> passer d'un prototype crédible et fonctionnel à une venture
      investissable, pour <b>démocratiser la fabrication de précision en Afrique</b> — produire
      localement ce qui est aujourd'hui importé.
      <span class="deadline">Candidature · deadline 21 août 2026</span>
    </div>
    <div class="contact">
      <b>&#10214;Ton nom&#10215;</b> — Founder &amp; Engineer<br>
      &#10214;email&#10215; · &#10214;téléphone&#10215;<br>
      &#10214;pays/ville&#10215; · &#10214;github.com/…/forgeron&#10215;
    </div>
  </footer>
</div>
</body>
</html>"""

out = root / "scratch/onepager.html"
out.write_text(HTML, encoding="utf-8")
print(f"written: {out} ({len(HTML)} bytes)")
