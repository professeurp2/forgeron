#!/usr/bin/env python3
"""Generate the Forgeron one-pager (self-contained HTML, logo + app mockups embedded)."""
import base64, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
logo_b64 = base64.b64encode((root / "assets/logo.png").read_bytes()).decode()
logo_uri = f"data:image/png;base64,{logo_b64}"

# Optional real machine photo — embedded when scratch/machine.{png,jpg} exists,
# otherwise a descriptive fallback card is shown.
_machine = next((root / f"scratch/machine.{ext}" for ext in ("png", "jpg", "jpeg")
                 if (root / f"scratch/machine.{ext}").exists()), None)
if _machine is not None:
    _data = _machine.read_bytes()
    _mime = "image/png" if _data[:4] == b"\x89PNG" else "image/jpeg"
    _m_b64 = base64.b64encode(_data).decode()
    machine_screen = (
        '<div class="phscreen m-photo">'
        f'<img src="data:{_mime};base64,{_m_b64}" alt="Forgeron 5-axis machine">'
        '<span class="ph-tag">BUILT &amp; WORKING</span>'
        '</div>'
    )
else:
    machine_screen = (
        '<div class="phscreen m-slot">'
        '<div class="ic">🛠️</div>'
        '<div class="t">5-axis physical machine</div>'
        '<div class="s">ESP32 + FluidNC + 5× TB6600 · X/Y/Z linear + A/C Trunnion. '
        'Photo attached with this application.</div>'
        '<div class="badge2">BUILT &amp; WORKING</div>'
        '</div>'
    )

HTML = f"""<!doctype html>
<html lang="en">
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
  .hero {{ margin-top:8px; background:linear-gradient(115deg,var(--steel),var(--steel2));
    color:#fff; border-radius:13px; padding:10px 16px; position:relative; overflow:hidden; }}
  .hero::after {{ content:""; position:absolute; right:-40px; top:-40px; width:170px; height:170px;
    background:radial-gradient(circle,rgba(255,106,26,.35),transparent 70%); }}
  .hero .kicker {{ font-size:10px; font-weight:700; letter-spacing:1.4px;
    text-transform:uppercase; color:var(--ember); }}
  .hero h2 {{ font-size:17px; line-height:1.24; margin-top:4px; font-weight:750; max-width:94%; }}
  .hero h2 b {{ color:var(--forge2); }}

  /* Grid */
  .grid {{ margin-top:8px; display:grid; grid-template-columns:1fr 1fr; gap:7px; }}
  .card {{ border:1px solid var(--line); border-radius:11px; padding:8px 12px; background:#fff; }}
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
  .ai-feats {{ list-style:none; display:flex; flex-direction:column; gap:4px; }}
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
  .chip {{ background:#fff; border:1px solid #bfe6cd; border-radius:8px; padding:5px 8px; text-align:center; min-width:50px; }}
  .chip .v {{ font-size:13px; font-weight:800; color:var(--steel); line-height:1; }}
  .chip .l {{ font-size:7px; color:#4f7a63; text-transform:uppercase; letter-spacing:.4px; margin-top:2px; }}

  /* Showcase band */
  .showcase {{ grid-column:1 / -1; }}
  .showcase .sh-head {{ font-size:9px; text-transform:uppercase; letter-spacing:1px; color:var(--muted);
    font-weight:700; margin-bottom:4px; padding-left:2px;
    display:flex; justify-content:space-between; align-items:baseline; }}
  .showcase .sh-head .demo {{ color:var(--forge); text-transform:none; letter-spacing:.2px; font-weight:700; }}
  .shots {{ display:grid; grid-template-columns:1fr 1fr 1fr; gap:10px; }}

  /* Phone frame */
  .phone {{ width:100%; max-width:162px; margin:0 auto; position:relative;
    background:linear-gradient(160deg,#2a313b,#0d1117); border-radius:26px;
    padding:12px 7px 10px; box-shadow:0 9px 22px rgba(20,24,31,.24); }}
  .phone .island {{ position:absolute; top:5px; left:50%; transform:translateX(-50%);
    width:48px; height:7px; background:#05070a; border-radius:999px; z-index:6; }}
  .phone .home {{ position:absolute; bottom:4px; left:50%; transform:translateX(-50%);
    width:56px; height:3px; background:#4a5462; border-radius:999px; }}
  .phscreen {{ border-radius:18px; overflow:hidden; height:222px; position:relative; background:#fff;
    display:flex; flex-direction:column; }}
  .cap {{ font-size:8px; color:var(--muted); text-align:center; margin-top:4px; letter-spacing:.2px; }}
  .cap b {{ color:var(--ink2); }}

  /* ---- Dashboard mock (light) ---- */
  .m-dash {{ background:#f4f6f9; font-size:8px; color:#2a3340; }}
  .m-dash .top {{ display:flex; align-items:center; gap:4px; padding:6px 7px; background:#fff; border-bottom:1px solid #eceff3; }}
  .m-dash .hex {{ width:13px; height:13px; background:var(--steel); color:#fff; border-radius:4px;
    display:flex; align-items:center; justify-content:center; font-weight:800; font-size:8px; }}
  .m-dash .nm {{ color:var(--forge); font-weight:800; font-style:italic; font-size:9px; letter-spacing:.3px; }}
  .m-dash .off {{ background:#eef1f4; color:#8b95a1; font-size:6.5px; padding:2px 5px; border-radius:999px; margin-left:2px; }}
  .m-dash .gear {{ margin-left:auto; color:var(--forge); font-size:9px; }}
  .m-dash .wifi {{ color:#aab2bd; font-size:9px; }}
  .m-dash .tabs {{ display:flex; gap:11px; justify-content:center; padding:5px 0; background:#fff; border-bottom:1px solid #eceff3; font-size:7px; font-weight:700; color:#aab2bd; }}
  .m-dash .tabs .act {{ color:var(--forge); border-bottom:2px solid var(--forge); padding-bottom:3px; }}
  .m-dash .body {{ padding:7px; }}
  .m-dash .sim {{ background:#fff; border:1px solid #e7ebf0; border-radius:7px; padding:5px 7px; font-weight:700; color:#5b6672; font-size:7px; display:flex; align-items:center; gap:4px; margin-bottom:6px; }}
  .dro {{ display:grid; grid-template-columns:1fr 1fr 1fr; gap:4px; margin-bottom:5px; }}
  .dro.two {{ grid-template-columns:1fr 1fr; }}
  .dcell {{ background:#fff; border:1px solid #e7ebf0; border-radius:6px; padding:4px 5px; }}
  .dcell .ax {{ font-weight:800; font-size:7.5px; }} .dcell .u {{ float:right; color:#aab2bd; font-size:5.5px; font-weight:600; }}
  .dcell .val {{ font-family:'Courier New',monospace; font-weight:800; font-size:10px; color:#1e2732; margin-top:2px; letter-spacing:0; }}
  .d-x {{ color:#e5484d; }} .d-y {{ color:#2ca24b; }} .d-z {{ color:#2f6fed; }} .d-a {{ color:#ff7a1a; }} .d-c {{ color:#12a3b4; }}
  .m-dash .cyc {{ background:#e7f7ee; color:#0f9d58; border:1px solid #b7e6c9; border-radius:8px; text-align:center; padding:6px; font-weight:800; font-size:8px; margin-bottom:5px; }}
  .m-dash .duo {{ display:grid; grid-template-columns:1fr 1fr; gap:5px; }}
  .m-dash .pause {{ background:#fdf2e0; color:#d9820a; border:1px solid #f2dcae; border-radius:8px; text-align:center; padding:6px; font-weight:800; font-size:8px; }}
  .m-dash .stop {{ background:#fdeaea; color:#e5484d; border:1px solid #f4c9c9; border-radius:8px; text-align:center; padding:6px; font-weight:800; font-size:8px; }}

  /* ---- AI chat mock (light) ---- */
  .m-ai {{ background:#ffffff; color:#2a3340; font-size:8px; }}
  .m-ai .top {{ display:flex; align-items:center; gap:5px; padding:6px 7px; background:#fff5f1; border-bottom:1px solid #f0e2db; }}
  .m-ai .av {{ width:14px; height:14px; border-radius:999px; background:var(--forge); color:#fff; display:flex; align-items:center; justify-content:center; font-size:8px; }}
  .m-ai .tt {{ font-weight:800; font-size:8.5px; color:#1e2732; }} .m-ai .st {{ color:#98a1ac; font-size:6.5px; }}
  .m-ai .ic {{ color:#b3bcc6; font-size:8px; }} .m-ai .grow {{ margin-left:auto; display:flex; gap:6px; }}
  .m-ai .chatbody {{ padding:7px; display:flex; flex-direction:column; gap:5px; flex:1; overflow:hidden; background:#f7f9fb; }}
  .m-ai .ubub {{ align-self:flex-end; background:#ffe4d3; color:#7a3f1e; border:1px solid #ffd3ba; border-radius:9px 9px 3px 9px; padding:5px 7px; max-width:84%; font-size:7.5px; }}
  .m-ai .tool {{ align-self:flex-start; background:#e7f7ee; color:#0f9d58; border:1px solid #b7e6c9; border-radius:7px; padding:3px 7px; font-family:'Courier New',monospace; font-size:7.5px; font-weight:700; }}
  .m-ai .bbub {{ align-self:flex-start; background:#fff; border:1px solid #e7ebf0; color:#3a4453; border-radius:9px 9px 9px 3px; padding:6px 7px; max-width:94%; font-size:7px; line-height:1.5; box-shadow:0 1px 2px rgba(20,24,31,.05); }}
  .m-ai .bbub b {{ color:#1e2732; }}
  .m-ai .inbar {{ display:flex; align-items:center; gap:5px; padding:6px 7px; border-top:1px solid #eceff3; background:#fff; }}
  .m-ai .inbox {{ flex:1; background:#f1f4f7; color:#98a1ac; border-radius:999px; padding:4px 8px; font-size:7px; }}
  .m-ai .send {{ width:16px; height:16px; border-radius:999px; background:var(--forge); color:#fff; display:flex; align-items:center; justify-content:center; font-size:8px; }}
  .m-ai .quota {{ font-size:6px; color:#a7afb9; text-align:center; padding:3px 0 4px; background:#fff; }}

  /* ---- Machine photo (real) ---- */
  .m-photo {{ position:relative; background:#000; }}
  .m-photo img {{ width:100%; height:100%; object-fit:cover; object-position:center; display:block; }}
  .m-photo .ph-tag {{ position:absolute; bottom:8px; left:50%; transform:translateX(-50%);
    background:rgba(15,157,88,.92); color:#fff; font-size:7.5px; font-weight:800; letter-spacing:.4px;
    padding:3px 9px; border-radius:999px; white-space:nowrap; }}

  /* ---- Machine placeholder ---- */
  .m-slot {{ background:var(--soft); border:1.5px dashed #c7d0dc; border-radius:14px; height:100%;
    display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; gap:7px; padding:12px; }}
  .m-slot .ic {{ font-size:30px; }} .m-slot .t {{ font-size:9px; color:var(--ink2); font-weight:800; }}
  .m-slot .s {{ font-size:8px; color:var(--muted); line-height:1.45; max-width:90%; }}
  .m-slot .badge2 {{ margin-top:2px; font-size:6.5px; font-weight:700; color:var(--ok); background:var(--ok-soft);
    border:1px solid #bfe6cd; padding:2px 7px; border-radius:999px; letter-spacing:.3px; }}

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
      <div class="sub">5-axis CNC controller · AI-piloted</div>
    </div>
    <div class="tags">
      <span class="pill ai">AI-ENABLED PROTOTYPE</span>
      <span class="pill ok">WORKING PHYSICAL MACHINE</span>
    </div>
  </header>

  <div class="hero">
    <div class="kicker">METI-funded UniPods AI Programme · timbuktoo / UNDP</div>
    <h2>The first <b>AI-piloted</b> 5-axis CNC controller, built for African industry —
       an $8 microcontroller turned into a machine tool you operate <b>in plain language</b>.</h2>
  </div>

  <div class="grid">
    <div class="card">
      <h3><span class="n">1</span> The problem</h3>
      <p>Industrial 5-axis CNC controllers (Fanuc, Heidenhain, Siemens) cost
      <b>$5,000 – $50,000</b>, are closed, and require highly trained operators.</p>
      <p>African workshops, fablabs and manufacturing SMEs are therefore <b>locked out</b> of
      precision manufacturing — tooling, molds, prosthetics, parts — which stays imported.</p>
    </div>
    <div class="card">
      <h3><span class="n">2</span> The solution</h3>
      <p>Forgeron turns an <b>ESP32 (~$8)</b> running open-source FluidNC firmware + cheap stepper
      drivers into an <b>industrial-grade 5-axis controller</b>, operated from a phone or PC.</p>
      <p>Real-time DRO, 5-axis jog, G-code streaming, 3D Trunnion visualizer, probing, WCS,
      hardware safety (emergency stop, watchdog).</p>
    </div>

    <div class="card ai-card">
      <h3><span class="n">AI</span> Artificial intelligence — the core of the "next leap"</h3>
      <div class="ai-cols">
        <p>An <b>agentic AI assistant</b> (LLM with <i>function calling</i>) drives the machine in plain
        language: "<i>probe the part center, then run the program at 80% feed</i>." 12 safe machine tools,
        planned and executed by the agent. AI removes the <b>skill barrier</b> that keeps CNC out of reach.</p>
        <ul class="ai-feats">
          <li><b>Safe agentic control</b> — per-tool permissions + always-on emergency stop</li>
          <li><b>Lookahead validation</b> — simulates the full toolpath vs. real mechanical limits <b>before</b> any motion: no collisions</li>
          <li><b>Connectivity resilience</b> — machine WiFi + AI calls over 4G/5G; free multi-model fallback</li>
        </ul>
      </div>
    </div>

    <div class="traction">
      <div class="badge"><div class="big">REAL</div><div class="small">Hardware</div></div>
      <p><b>The physical 5-axis machine is already built and working</b> — ESP32 DevKit V1 +
      FluidNC v3.7 + 5× TB6600 drivers, X/Y/Z linear + A/C rotary (Trunnion) axes. Demonstrated
      end-to-end on real hardware. <b>Ready to move from prototype to venture.</b></p>
      <div class="metricchips">
        <div class="chip"><div class="v">5</div><div class="l">Axes</div></div>
        <div class="chip"><div class="v">12</div><div class="l">AI tools</div></div>
        <div class="chip"><div class="v">134</div><div class="l">Files</div></div>
      </div>
    </div>

    <div class="showcase">
      <div class="sh-head"><span>The product in action</span><span class="demo">▶ Watch the demo — youtube.com/shorts/wCH-2Z9WxEw</span></div>
      <div class="shots">
        <!-- Dashboard -->
        <div>
          <div class="phone">
            <span class="island"></span>
            <div class="phscreen m-dash">
              <div class="top">
                <span class="hex">F</span><span class="nm">FORGERON</span><span class="off">● OFFLINE</span>
                <span class="gear">⚙</span><span class="wifi">⚏</span>
              </div>
              <div class="tabs"><span class="act">MASTER</span><span>JOG</span><span>PROGRAM</span></div>
              <div class="body">
                <div class="sim">⬚ 3D SIMULATOR ⌄</div>
                <div class="dro">
                  <div class="dcell"><span class="ax d-x">● X</span><span class="u">mm</span><div class="val">0.000</div></div>
                  <div class="dcell"><span class="ax d-y">● Y</span><span class="u">mm</span><div class="val">0.000</div></div>
                  <div class="dcell"><span class="ax d-z">● Z</span><span class="u">mm</span><div class="val">0.000</div></div>
                </div>
                <div class="dro two">
                  <div class="dcell"><span class="ax d-a">● A</span><span class="u">°</span><div class="val">0.000</div></div>
                  <div class="dcell"><span class="ax d-c">● C</span><span class="u">°</span><div class="val">0.000</div></div>
                </div>
                <div class="cyc">▶ CYCLE START</div>
                <div class="duo"><div class="pause">❚❚ PAUSE</div><div class="stop">■ STOP</div></div>
              </div>
            </div>
            <span class="home"></span>
          </div>
          <div class="cap"><b>Dashboard</b> · real-time 5-axis DRO</div>
        </div>

        <!-- AI agent -->
        <div>
          <div class="phone">
            <span class="island"></span>
            <div class="phscreen m-ai">
              <div class="top">
                <span class="ic">‹</span><span class="av">🤖</span>
                <div><div class="tt">AI AGENT</div><div class="st">CNC Assistant · Gemini</div></div>
                <span class="grow"><span class="ic">🔇</span><span class="ic">⚙</span><span class="ic">🗑</span></span>
              </div>
              <div class="chatbody">
                <div class="ubub">Give me the machine's full status.</div>
                <div class="tool">⟳ get_machine_state ✓</div>
                <div class="bbub">Here is the current status:<br>• <b>Status</b>: Offline<br>• <b>WCS</b>: X 0.0 · Y 0.0 · Z 0.0 mm<br>• <b>Coord.</b>: G54 · Tool 0<br>• <b>Feed</b>: 0.0 mm/min · <b>Spindle</b>: 0 rpm<br>• <b>Alarm</b>: None</div>
              </div>
              <div class="inbar"><div class="inbox">Message the agent…</div><span class="send">➤</span></div>
              <div class="quota">Gemini Flash Lite · 0/500 · 500 left</div>
            </div>
            <span class="home"></span>
          </div>
          <div class="cap"><b>AI agent</b> · function calling (Gemini)</div>
        </div>

        <!-- Machine physical (placeholder) -->
        <div>
          <div class="phone">
            <span class="island"></span>
            {machine_screen}
            <span class="home"></span>
          </div>
          <div class="cap"><b>Hardware</b> · real 5-axis rig</div>
        </div>
      </div>
    </div>

    <div class="card">
      <h3><span class="n">3</span> Market &amp; model</h3>
      <p><b>Target:</b> machine shops, fablabs/makerspaces, technical schools and manufacturing
      SMEs across Africa; then CNC-kit builders.</p>
      <p><b>Revenue:</b> freemium app → Pro (AI, multi-machine) → certified hardware bundles →
      config marketplace.</p>
    </div>
    <div class="card">
      <h3><span class="n">4</span> Why this programme</h3>
      <p>The prototype exists; we need to build the <b>venture</b>. AI skilling (Ethiopian AI Institute)
      to harden the agent and target edge / on-device.</p>
      <p>Wadhwani track (14 weeks): customer discovery, business modelling, go-to-market,
      <b>investment readiness</b> + the timbuktoo network.</p>
    </div>
  </div>

  <footer>
    <div class="ask"><b>The ask:</b> move from a working prototype to an investable venture, to
      <b>democratize precision manufacturing in Africa</b> — producing locally what is currently imported.
    </div>
    <div class="contact">
      <b>Lamine SACKO</b> — Founder &amp; Engineer<br>
      sackolamine994@gmail.com<br>
      Mali · github.com/professeurp2/forgeron
    </div>
  </footer>
</div>
</body>
</html>"""

out = root / "scratch/onepager.html"
out.write_text(HTML, encoding="utf-8")
print(f"written: {out} ({len(HTML)} bytes)")
