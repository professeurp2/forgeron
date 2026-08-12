#!/usr/bin/env python3
"""Génère le one-pager Forgeron (HTML autonome, logo + maquettes app embarqués)."""
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
  header {{ display:flex; align-items:center; gap:12px; padding-bottom:9px;
    border-bottom:3px solid var(--forge); }}
  .logo {{ width:50px; height:50px; border-radius:12px; object-fit:cover;
    box-shadow:0 2px 8px rgba(0,0,0,.15); }}
  .brand h1 {{ font-size:27px; letter-spacing:.5px; line-height:1; }}
  .brand .sub {{ font-size:11px; color:var(--muted); margin-top:3px; font-weight:600;
    text-transform:uppercase; letter-spacing:1.1px; }}
  .tags {{ margin-left:auto; text-align:right; display:flex; flex-direction:column; gap:5px; align-items:flex-end;}}
  .pill {{ display:inline-block; font-size:9.5px; font-weight:700; padding:4px 9px;
    border-radius:999px; letter-spacing:.4px; }}
  .pill.ai {{ background:var(--ai-soft); color:var(--ai); }}
  .pill.ok {{ background:var(--ok-soft); color:var(--ok); }}

  /* Hero */
  .hero {{ margin-top:9px; background:linear-gradient(115deg,var(--steel),var(--steel2));
    color:#fff; border-radius:13px; padding:11px 16px; position:relative; overflow:hidden; }}
  .hero::after {{ content:""; position:absolute; right:-40px; top:-40px; width:170px; height:170px;
    background:radial-gradient(circle,rgba(255,106,26,.35),transparent 70%); }}
  .hero .kicker {{ font-size:10px; font-weight:700; letter-spacing:1.4px;
    text-transform:uppercase; color:var(--ember); }}
  .hero h2 {{ font-size:17px; line-height:1.24; margin-top:4px; font-weight:750; max-width:93%; }}
  .hero h2 b {{ color:var(--forge2); }}

  /* Grid */
  .grid {{ margin-top:9px; display:grid; grid-template-columns:1fr 1fr; gap:8px; }}
  .card {{ border:1px solid var(--line); border-radius:11px; padding:9px 12px; background:#fff; }}
  .card h3 {{ font-size:11.5px; text-transform:uppercase; letter-spacing:.7px; color:var(--forge);
    display:flex; align-items:center; gap:7px; margin-bottom:5px; }}
  .card h3 .n {{ width:17px; height:17px; border-radius:6px; background:var(--forge); color:#fff;
    font-size:10px; display:inline-flex; align-items:center; justify-content:center; font-weight:800; }}
  .card p {{ font-size:10.5px; line-height:1.45; color:var(--ink2); }}
  .card p + p {{ margin-top:4px; }}
  .card b {{ color:var(--ink); }}

  .card.ai-card {{ grid-column:1 / -1; border-color:#cfe0fb; background:linear-gradient(180deg,#fbfdff,#f3f8ff); }}
  .card.ai-card h3 {{ color:var(--ai); }}
  .card.ai-card h3 .n {{ background:var(--ai); }}
  .ai-cols {{ display:grid; grid-template-columns:1.15fr 1fr; gap:14px; }}
  .ai-feats {{ list-style:none; display:flex; flex-direction:column; gap:5px; }}
  .ai-feats li {{ font-size:10px; line-height:1.35; color:var(--ink2); padding-left:15px; position:relative; }}
  .ai-feats li::before {{ content:"▹"; position:absolute; left:0; color:var(--ai); font-weight:700; }}
  .ai-feats b {{ color:var(--ai); }}

  /* Traction band */
  .traction {{ grid-column:1 / -1; display:grid; grid-template-columns:auto 1fr auto; gap:12px; align-items:center;
    border:1px solid var(--ok); background:var(--ok-soft); border-radius:11px; padding:8px 12px; }}
  .traction .badge {{ background:var(--ok); color:#fff; border-radius:10px; padding:8px 11px; text-align:center; }}
  .traction .badge .big {{ font-size:14px; font-weight:800; line-height:1.1; }}
  .traction .badge .small {{ font-size:8px; letter-spacing:.5px; text-transform:uppercase; margin-top:2px; opacity:.95; }}
  .traction p {{ font-size:10px; line-height:1.4; color:#256b45; }}
  .traction b {{ color:#0f5c34; }}
  .metricchips {{ display:flex; gap:6px; }}
  .chip {{ background:#fff; border:1px solid #bfe6cd; border-radius:8px; padding:5px 8px; text-align:center; min-width:52px; }}
  .chip .v {{ font-size:13px; font-weight:800; color:var(--steel); line-height:1; }}
  .chip .l {{ font-size:7px; color:#4f7a63; text-transform:uppercase; letter-spacing:.4px; margin-top:2px; }}

  /* Showcase band */
  .showcase {{ grid-column:1 / -1; }}
  .showcase .sh-head {{ font-size:9px; text-transform:uppercase; letter-spacing:1px; color:var(--muted);
    font-weight:700; margin-bottom:5px; padding-left:2px; }}
  .shots {{ display:grid; grid-template-columns:1fr 1fr 1fr; gap:9px; }}
  .screen {{ height:214px; border-radius:12px; overflow:hidden; position:relative;
    border:1px solid var(--line); box-shadow:0 3px 10px rgba(20,24,31,.08); }}
  .cap {{ font-size:8px; color:var(--muted); text-align:center; margin-top:4px; letter-spacing:.2px; }}
  .cap b {{ color:var(--ink2); }}

  /* ---- Dashboard mock (light) ---- */
  .m-dash {{ background:#f4f6f9; font-size:8px; color:#2a3340; padding:0; }}
  .m-dash .top {{ display:flex; align-items:center; gap:4px; padding:6px 7px; background:#fff; border-bottom:1px solid #eceff3; }}
  .m-dash .hex {{ width:13px; height:13px; background:var(--steel); color:#fff; border-radius:4px;
    display:flex; align-items:center; justify-content:center; font-weight:800; font-size:8px; }}
  .m-dash .nm {{ color:var(--forge); font-weight:800; font-style:italic; font-size:9px; letter-spacing:.3px; }}
  .m-dash .off {{ background:#eef1f4; color:#8b95a1; font-size:6.5px; padding:2px 5px; border-radius:999px; margin-left:2px; }}
  .m-dash .gear {{ margin-left:auto; color:var(--forge); font-size:9px; }}
  .m-dash .wifi {{ color:#aab2bd; font-size:9px; }}
  .m-dash .tabs {{ display:flex; gap:12px; justify-content:center; padding:5px 0; background:#fff; border-bottom:1px solid #eceff3; font-size:7px; font-weight:700; color:#aab2bd; }}
  .m-dash .tabs .act {{ color:var(--forge); border-bottom:2px solid var(--forge); padding-bottom:3px; }}
  .m-dash .body {{ padding:7px; }}
  .m-dash .sim {{ background:#fff; border:1px solid #e7ebf0; border-radius:7px; padding:5px 7px; font-weight:700; color:#5b6672; font-size:7px; display:flex; align-items:center; gap:4px; margin-bottom:6px; }}
  .dro {{ display:grid; grid-template-columns:1fr 1fr 1fr; gap:5px; margin-bottom:5px; }}
  .dro.two {{ grid-template-columns:1fr 1fr; }}
  .dcell {{ background:#fff; border:1px solid #e7ebf0; border-radius:7px; padding:5px 6px; }}
  .dcell .ax {{ font-weight:800; font-size:8px; }} .dcell .u {{ float:right; color:#aab2bd; font-size:6px; font-weight:600; }}
  .dcell .val {{ font-family:'Courier New',monospace; font-weight:800; font-size:12px; color:#1e2732; margin-top:2px; letter-spacing:.5px; }}
  .d-x {{ color:#e5484d; }} .d-y {{ color:#2ca24b; }} .d-z {{ color:#2f6fed; }} .d-a {{ color:#ff7a1a; }} .d-c {{ color:#12a3b4; }}
  .m-dash .cyc {{ background:#e7f7ee; color:#0f9d58; border:1px solid #b7e6c9; border-radius:8px; text-align:center; padding:6px; font-weight:800; font-size:8px; margin-bottom:5px; }}
  .m-dash .duo {{ display:grid; grid-template-columns:1fr 1fr; gap:5px; }}
  .m-dash .pause {{ background:#fdf2e0; color:#d9820a; border:1px solid #f2dcae; border-radius:8px; text-align:center; padding:6px; font-weight:800; font-size:8px; }}
  .m-dash .stop {{ background:#fdeaea; color:#e5484d; border:1px solid #f4c9c9; border-radius:8px; text-align:center; padding:6px; font-weight:800; font-size:8px; }}

  /* ---- AI chat mock (dark) ---- */
  .m-ai {{ background:#171b22; color:#e8ebf0; font-size:8px; display:flex; flex-direction:column; }}
  .m-ai .top {{ display:flex; align-items:center; gap:5px; padding:6px 7px; background:#1e232c; border-bottom:1px solid #262c36; }}
  .m-ai .av {{ width:14px; height:14px; border-radius:999px; background:var(--forge); color:#fff; display:flex; align-items:center; justify-content:center; font-size:8px; }}
  .m-ai .tt {{ font-weight:800; font-size:8.5px; }} .m-ai .st {{ color:#8b95a1; font-size:6.5px; }}
  .m-ai .ic {{ color:#8b95a1; font-size:8px; }} .m-ai .grow {{ margin-left:auto; display:flex; gap:6px; }}
  .m-ai .chatbody {{ padding:7px; display:flex; flex-direction:column; gap:5px; flex:1; overflow:hidden; }}
  .m-ai .ubub {{ align-self:flex-end; background:#5a3a2a; color:#f4e3d7; border-radius:9px 9px 3px 9px; padding:5px 7px; max-width:82%; font-size:7.5px; }}
  .m-ai .tool {{ align-self:flex-start; background:#12321f; color:#4fd07f; border:1px solid #1f5a37; border-radius:7px; padding:3px 7px; font-family:'Courier New',monospace; font-size:7.5px; font-weight:700; }}
  .m-ai .bbub {{ align-self:flex-start; background:#20262f; border:1px solid #2b323d; border-radius:9px 9px 9px 3px; padding:6px 7px; max-width:92%; font-size:7px; line-height:1.5; }}
  .m-ai .bbub b {{ color:#cfd6df; }}
  .m-ai .inbar {{ display:flex; align-items:center; gap:5px; padding:6px 7px; border-top:1px solid #262c36; background:#1e232c; }}
  .m-ai .inbox {{ flex:1; background:#2a303a; color:#8b95a1; border-radius:999px; padding:4px 8px; font-size:7px; }}
  .m-ai .send {{ width:16px; height:16px; border-radius:999px; background:var(--forge); color:#fff; display:flex; align-items:center; justify-content:center; font-size:8px; }}
  .m-ai .quota {{ font-size:6px; color:#6b7480; text-align:center; padding:3px 0 5px; background:#1e232c; }}

  /* ---- Machine placeholder ---- */
  .m-slot {{ background:var(--soft); border:1.5px dashed #c7d0dc; display:flex; flex-direction:column;
    align-items:center; justify-content:center; text-align:center; gap:6px; padding:10px; }}
  .m-slot .ic {{ font-size:26px; }} .m-slot .t {{ font-size:9px; color:var(--ink2); font-weight:700; }}
  .m-slot .s {{ font-size:8px; color:var(--muted); line-height:1.4; max-width:88%; }}

  /* Footer */
  footer {{ margin-top:auto; padding-top:7px; border-top:1px solid var(--line);
    display:flex; align-items:center; gap:12px; }}
  .ask {{ flex:1; font-size:9.5px; color:var(--ink2); line-height:1.4; }}
  .ask b {{ color:var(--forge); }}
  .contact {{ text-align:right; font-size:9px; color:var(--muted); line-height:1.5; white-space:nowrap; }}
  .contact b {{ color:var(--ink); }}
  .deadline {{ display:inline-block; background:var(--steel); color:#fff; font-size:8.5px; font-weight:700;
    padding:3px 8px; border-radius:6px; letter-spacing:.4px; margin-top:3px; }}
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
      <p>Ateliers, fablabs et PME manufacturières africaines sont donc <b>exclus</b> de la
      fabrication de précision — outillage, moules, prothèses, pièces — qui reste importée.</p>
    </div>
    <div class="card">
      <h3><span class="n">2</span> La solution</h3>
      <p>Forgeron transforme un <b>ESP32 (~8&nbsp;$)</b> sous firmware open-source FluidNC + drivers
      pas-à-pas en un <b>contrôleur 5-axes de grade industriel</b>, piloté depuis un smartphone ou un PC.</p>
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
          <li><b>Contrôle agentique sûr</b> — permissions par outil + arrêt d'urgence prioritaire</li>
          <li><b>Validation <i>lookahead</i></b> — simule tout le parcours vs. limites mécaniques réelles <b>avant</b> tout mouvement : pas de collision</li>
          <li><b>Résilience connectivité</b> — WiFi machine + appels IA en 4G/5G ; repli multi-modèles gratuit</li>
        </ul>
      </div>
    </div>

    <div class="traction">
      <div class="badge"><div class="big">RÉEL</div><div class="small">Hardware</div></div>
      <p><b>La machine physique 5-axes est déjà construite et fonctionnelle</b> — ESP32 DevKit V1 +
      FluidNC v3.7 + 5× drivers TB6600, axes X/Y/Z linéaires + A/C rotatifs (Trunnion). Démontré de
      bout en bout sur matériel réel. <b>Prêt à passer de prototype à venture.</b></p>
      <div class="metricchips">
        <div class="chip"><div class="v">5</div><div class="l">Axes</div></div>
        <div class="chip"><div class="v">12</div><div class="l">Outils IA</div></div>
        <div class="chip"><div class="v">134</div><div class="l">Fichiers</div></div>
      </div>
    </div>

    <div class="showcase">
      <div class="sh-head">Le produit en action</div>
      <div class="shots">
        <!-- Dashboard -->
        <div>
          <div class="screen m-dash">
            <div class="top">
              <span class="hex">F</span><span class="nm">FORGERON</span><span class="off">● OFFLINE</span>
              <span class="gear">⚙</span><span class="wifi">⚏</span>
            </div>
            <div class="tabs"><span class="act">MASTER</span><span>JOG</span><span>PROGRAMME</span></div>
            <div class="body">
              <div class="sim">⬚ SIMULATEUR 3D ⌄</div>
              <div class="dro">
                <div class="dcell"><span class="ax d-x">● X</span><span class="u">mm</span><div class="val">0.000</div></div>
                <div class="dcell"><span class="ax d-y">● Y</span><span class="u">mm</span><div class="val">0.000</div></div>
                <div class="dcell"><span class="ax d-z">● Z</span><span class="u">mm</span><div class="val">0.000</div></div>
              </div>
              <div class="dro two">
                <div class="dcell"><span class="ax d-a">● A</span><span class="u">°</span><div class="val">0.000</div></div>
                <div class="dcell"><span class="ax d-c">● C</span><span class="u">°</span><div class="val">0.000</div></div>
              </div>
              <div class="cyc">▶ DÉPART CYCLE</div>
              <div class="duo"><div class="pause">❚❚ PAUSE</div><div class="stop">■ STOP</div></div>
            </div>
          </div>
          <div class="cap"><b>Dashboard</b> · DRO 5 axes temps réel</div>
        </div>

        <!-- AI agent -->
        <div>
          <div class="screen m-ai">
            <div class="top">
              <span class="ic">‹</span><span class="av">🤖</span>
              <div><div class="tt">AGENT IA</div><div class="st">Assistant CNC · Gemini</div></div>
              <span class="grow"><span class="ic">🔇</span><span class="ic">⚙</span><span class="ic">🗑</span></span>
            </div>
            <div class="chatbody">
              <div class="ubub">Donne-moi l'état complet de la machine.</div>
              <div class="tool">⟳ get_machine_state ✓</div>
              <div class="bbub">Voici l'état actuel :<br>• <b>Statut</b> : Hors ligne<br>• <b>WCS</b> : X 0,0 · Y 0,0 · Z 0,0 mm<br>• <b>Coord.</b> : G54 · Outil 0<br>• <b>Avance</b> : 0,0 mm/min<br>• <b>Broche</b> : 0 tr/min<br>• <b>Alarme</b> : Aucune</div>
            </div>
            <div class="inbar"><div class="inbox">Écris à l'agent…</div><span class="send">➤</span></div>
            <div class="quota">Gemini Flash Lite · 0/500 · 500 restantes</div>
          </div>
          <div class="cap"><b>Agent IA</b> · function calling (Gemini)</div>
        </div>

        <!-- Machine physical (placeholder) -->
        <div>
          <div class="screen m-slot">
            <div class="ic">🛠️</div>
            <div class="t">Machine 5-axes physique</div>
            <div class="s">Photo réelle en fonctionnement à insérer ici (modèle 3D → photo).</div>
          </div>
          <div class="cap"><b>Hardware</b> · construit &amp; fonctionnel</div>
        </div>
      </div>
    </div>

    <div class="card">
      <h3><span class="n">3</span> Marché &amp; modèle</h3>
      <p><b>Cible :</b> ateliers d'usinage, fablabs/makerspaces, écoles techniques et PME
      manufacturières d'Afrique ; puis fabricants de kits CNC.</p>
      <p><b>Revenu :</b> app freemium → Pro (IA, multi-machines) → bundles hardware certifiés →
      marketplace de configs.</p>
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
    <div class="ask"><b>La demande :</b> passer d'un prototype fonctionnel à une venture investissable,
      pour <b>démocratiser la fabrication de précision en Afrique</b> — produire localement ce qui est importé.
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
