#!/usr/bin/env python3
"""Build the Forgeron landing page (self-contained HTML, images inlined)."""
import base64, pathlib
root = pathlib.Path("/home/user/forgeron")
def uri(p, mime):
    return f"data:{mime};base64," + base64.b64encode((root/p).read_bytes()).decode()
LOGO = uri("assets/logo.png","image/png")
MACHINE = uri("scratch/machine.png","image/png")
PHONES = uri("scratch/phones.png","image/png")

HTML = f"""<title>Forgeron</title>
<meta name="description" content="AI-piloted 5-axis CNC machines, built to make precision manufacturing affordable in Africa.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Saira+Condensed:wght@500;600;700&family=Archivo:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
  :root{{
    --ground:#14171c; --ground-2:#181c22; --panel:#1b2028; --panel-2:#20262f;
    --line:#2b323c; --line-2:#3a434f;
    --ink:#eceef1; --muted:#98a2ad; --dim:#6a747e; --steel:#9fb0bf;
    --forge:#ff6a1a; --forge-2:#ff8c42; --ember:#ffb15a;
    --ok:#37c98b;
    --disp:'Saira Condensed',ui-sans-serif,system-ui,sans-serif;
    --body:'Archivo',ui-sans-serif,system-ui,sans-serif;
    --mono:'IBM Plex Mono',ui-monospace,'SFMono-Regular',monospace;
  }}
  *{{box-sizing:border-box;}}
  html{{-webkit-text-size-adjust:100%;}}
  body{{margin:0;background:var(--ground);color:var(--ink);font-family:var(--body);
    font-size:16px;line-height:1.6;letter-spacing:.005em;
    background-image:linear-gradient(var(--line) 1px,transparent 1px),linear-gradient(90deg,var(--line) 1px,transparent 1px);
    background-size:46px 46px;background-position:center top;
  }}
  body::before{{content:"";position:fixed;inset:0;pointer-events:none;z-index:0;
    background:radial-gradient(1100px 620px at 78% -8%,rgba(255,106,26,.16),transparent 60%),
               radial-gradient(900px 700px at 0% 0%,rgba(20,23,28,.6),transparent 55%),
               linear-gradient(180deg,rgba(20,23,28,.35),var(--ground) 70%);}}
  .wrap{{position:relative;z-index:1;max-width:1080px;margin:0 auto;padding-inline:22px;}}
  a{{color:inherit;text-decoration:none;}}
  img{{max-width:100%;display:block;}}
  h1,h2,h3{{font-family:var(--disp);font-weight:700;text-wrap:balance;margin:0;line-height:1.02;
    letter-spacing:.01em;text-transform:uppercase;}}
  .eyebrow{{font-family:var(--mono);font-size:12px;letter-spacing:.28em;text-transform:uppercase;color:var(--forge-2);}}
  .lede{{color:var(--muted);max-width:60ch;}}
  .mono{{font-family:var(--mono);}}

  /* nav */
  header{{position:sticky;top:0;z-index:20;backdrop-filter:blur(8px);
    background:linear-gradient(180deg,rgba(20,23,28,.92),rgba(20,23,28,.6));border-bottom:1px solid var(--line);}}
  .nav{{display:flex;align-items:center;gap:16px;height:64px;}}
  .brand{{display:flex;align-items:center;gap:11px;}}
  .brand img{{width:30px;height:30px;border-radius:6px;}}
  .brand b{{font-family:var(--disp);font-size:22px;letter-spacing:.06em;}}
  .nav .links{{margin-left:auto;display:flex;gap:26px;font-size:13.5px;color:var(--muted);
    font-family:var(--mono);letter-spacing:.04em;}}
  .nav .links a:hover{{color:var(--ink);}}
  .badge{{font-family:var(--mono);font-size:11px;letter-spacing:.12em;text-transform:uppercase;
    color:var(--ember);border:1px solid var(--line-2);padding:5px 10px;white-space:nowrap;}}
  @media(max-width:720px){{.nav .links{{display:none;}}}}

  /* section scaffolding */
  section{{padding-block:74px;border-top:1px solid var(--line);position:relative;}}
  .tag{{display:flex;align-items:center;gap:12px;margin-bottom:26px;}}
  .tag .n{{font-family:var(--mono);font-size:12px;color:var(--dim);letter-spacing:.1em;}}
  .tag .rule{{height:1px;background:var(--line-2);flex:1;}}
  .btn{{display:inline-flex;align-items:center;gap:9px;font-family:var(--mono);font-size:13.5px;
    letter-spacing:.06em;text-transform:uppercase;padding:13px 20px;border:1px solid var(--line-2);
    color:var(--ink);transition:.18s;}}
  .btn:hover{{border-color:var(--forge);color:var(--forge-2);}}
  .btn.solid{{background:var(--forge);color:#150a02;border-color:var(--forge);font-weight:500;}}
  .btn.solid:hover{{background:var(--forge-2);color:#150a02;}}

  /* hero */
  .hero{{padding-top:64px;padding-bottom:20px;}}
  .hero-grid{{display:grid;grid-template-columns:1.05fr .95fr;gap:42px;align-items:center;}}
  .hero h1{{font-size:clamp(40px,6.6vw,76px);margin:16px 0 20px;}}
  .hero h1 .heat{{color:var(--forge);}}
  .hero .cta{{display:flex;gap:14px;flex-wrap:wrap;margin-top:30px;}}
  .frame{{position:relative;border:1px solid var(--line-2);background:var(--panel);}}
  .frame::before,.frame::after{{content:"";position:absolute;width:12px;height:12px;border:2px solid var(--forge);}}
  .frame::before{{top:-1px;left:-1px;border-right:0;border-bottom:0;}}
  .frame::after{{bottom:-1px;right:-1px;border-left:0;border-top:0;}}
  .frame img{{width:100%;height:100%;object-fit:cover;display:block;}}
  .dro{{display:flex;gap:0;border-top:1px solid var(--line-2);font-family:var(--mono);}}
  .dro div{{flex:1;padding:9px 6px;text-align:center;border-right:1px solid var(--line);}}
  .dro div:last-child{{border-right:0;}}
  .dro .ax{{font-size:10px;color:var(--steel);letter-spacing:.14em;}}
  .dro .v{{font-size:14px;color:var(--ink);margin-top:2px;font-variant-numeric:tabular-nums;}}
  @media(max-width:820px){{.hero-grid{{grid-template-columns:1fr;gap:30px;}}}}

  /* stat tiles */
  .stats{{display:grid;grid-template-columns:repeat(3,1fr);gap:0;border:1px solid var(--line-2);}}
  .stat{{padding:24px 22px;border-right:1px solid var(--line);}}
  .stat:last-child{{border-right:0;}}
  .stat .big{{font-family:var(--disp);font-size:clamp(30px,4.2vw,44px);color:var(--forge);line-height:1;
    font-variant-numeric:tabular-nums;}}
  .stat .lab{{color:var(--muted);font-size:14px;margin-top:10px;}}
  .stat .src{{font-family:var(--mono);font-size:11px;color:var(--dim);margin-top:8px;letter-spacing:.03em;}}
  @media(max-width:720px){{.stats{{grid-template-columns:1fr;}}.stat{{border-right:0;border-bottom:1px solid var(--line);}}.stat:last-child{{border-bottom:0;}}}}

  /* two-col */
  .two{{display:grid;grid-template-columns:1fr 1fr;gap:38px;align-items:start;}}
  @media(max-width:820px){{.two{{grid-template-columns:1fr;gap:26px;}}}}
  h2{{font-size:clamp(28px,4vw,40px);}}
  .spec{{font-family:var(--mono);font-size:13px;color:var(--steel);border-top:1px solid var(--line);
    padding-top:16px;margin-top:24px;display:grid;gap:8px;}}
  .spec div{{display:flex;justify-content:space-between;gap:16px;}}
  .spec span:last-child{{color:var(--ink);}}
  .price{{display:flex;align-items:baseline;gap:14px;flex-wrap:wrap;margin-top:6px;}}
  .price .now{{font-family:var(--disp);font-size:46px;color:var(--forge);line-height:1;}}
  .price .was{{font-family:var(--mono);color:var(--dim);text-decoration:line-through;}}
  .price .cut{{font-family:var(--mono);font-size:12px;color:var(--ok);border:1px solid rgba(55,201,139,.4);padding:3px 8px;letter-spacing:.06em;}}

  /* tech pillars */
  .pillars{{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;}}
  .pill{{border:1px solid var(--line);background:var(--panel);padding:22px;}}
  .pill .k{{font-family:var(--mono);font-size:12px;color:var(--forge-2);letter-spacing:.12em;}}
  .pill h3{{font-size:21px;margin:12px 0 9px;text-transform:none;letter-spacing:0;font-family:var(--disp);}}
  .pill p{{color:var(--muted);font-size:14.5px;margin:0;}}
  @media(max-width:820px){{.pillars{{grid-template-columns:1fr;}}}}

  /* product */
  .shot{{border:1px solid var(--line-2);background:var(--panel);padding:16px;}}
  .caps{{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:14px;font-family:var(--mono);
    font-size:11.5px;letter-spacing:.04em;color:var(--steel);text-align:center;}}

  /* traction */
  .facts{{display:grid;gap:0;border:1px solid var(--line-2);}}
  .fact{{display:flex;gap:18px;align-items:baseline;padding:16px 20px;border-bottom:1px solid var(--line);}}
  .fact:last-child{{border-bottom:0;}}
  .fact .m{{font-family:var(--mono);color:var(--forge-2);font-size:13px;min-width:118px;letter-spacing:.04em;}}
  .fact .t{{color:var(--ink);}}
  .fact .t b{{color:#fff;}}

  /* team */
  .team{{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;}}
  .member{{border:1px solid var(--line);background:var(--panel);padding:20px;}}
  .member .role{{font-family:var(--mono);font-size:11.5px;color:var(--forge-2);letter-spacing:.08em;text-transform:uppercase;}}
  .member h3{{font-size:19px;margin:9px 0 8px;text-transform:none;letter-spacing:0;}}
  .member p{{color:var(--muted);font-size:13.5px;margin:0;}}
  .member.open{{border-style:dashed;border-color:var(--line-2);}}
  .member.open h3{{color:var(--muted);}}
  @media(max-width:820px){{.team{{grid-template-columns:1fr;}}}}

  /* cta / footer */
  .final{{border:1px solid var(--line-2);background:linear-gradient(180deg,var(--panel),var(--ground-2));padding:44px 34px;}}
  .final h2{{font-size:clamp(28px,4.4vw,44px);}}
  .contact{{font-family:var(--mono);font-size:14px;color:var(--muted);display:grid;gap:9px;margin-top:22px;}}
  .contact a:hover{{color:var(--forge-2);}}
  .contact b{{color:var(--steel);font-weight:500;}}
  footer{{border-top:1px solid var(--line);padding-block:26px;color:var(--dim);font-family:var(--mono);font-size:12px;
    display:flex;justify-content:space-between;gap:14px;flex-wrap:wrap;letter-spacing:.03em;}}
  @media(prefers-reduced-motion:reduce){{*{{transition:none!important;}}}}
</style>

<header><div class="wrap nav">
  <span class="brand"><img src="{LOGO}" alt="Forgeron logo"><b>FORGERON</b></span>
  <nav class="links">
    <a href="#product">Product</a><a href="#technology">Technology</a>
    <a href="#traction">Traction</a><a href="#contact">Contact</a>
  </nav>
  <span class="badge">Selected · UniPods AI 2026</span>
</div></header>

<main>
<section class="hero" style="border-top:0">
  <div class="wrap">
    <div class="hero-grid">
      <div>
        <div class="eyebrow">Deep-tech · 5-axis CNC · AI-piloted</div>
        <h1>The 5-axis machine you run by <span class="heat">talking to it.</span></h1>
        <p class="lede">Forgeron turns a low-cost microcontroller into a complete, affordable
          5-axis CNC machine — piloted in plain language by an on-board AI that plans the
          tool-paths and prevents collisions. Precision manufacturing, finally within reach
          of African workshops.</p>
        <div class="cta">
          <a class="btn solid" href="https://youtube.com/shorts/wCH-2Z9WxEw" target="_blank" rel="noopener">▶ Watch the demo</a>
          <a class="btn" href="#contact">Get in touch</a>
        </div>
      </div>
      <div class="frame">
        <img src="{MACHINE}" alt="Forgeron's real 5-axis CNC machine">
        <div class="dro">
          <div><div class="ax">X</div><div class="v">0.000</div></div>
          <div><div class="ax">Y</div><div class="v">0.000</div></div>
          <div><div class="ax">Z</div><div class="v">0.000</div></div>
          <div><div class="ax">A°</div><div class="v">0.00</div></div>
          <div><div class="ax">C°</div><div class="v">0.00</div></div>
        </div>
      </div>
    </div>
  </div>
</section>

<section id="problem">
  <div class="wrap">
    <div class="tag"><span class="eyebrow">The problem</span><span class="rule"></span><span class="n">01</span></div>
    <div class="stats">
      <div class="stat"><div class="big">$5k–50k</div><div class="lab">Cost of an industrial 5-axis CNC controller — closed and proprietary.</div><div class="src">Fanuc / Heidenhain / Siemens</div></div>
      <div class="stat"><div class="big">&lt; 2%</div><div class="lab">Africa's share of global manufacturing — precision parts stay imported.</div><div class="src">Source: UNIDO</div></div>
      <div class="stat"><div class="big">Locked&nbsp;out</div><div class="lab">Workshops, fablabs and SMEs can't afford the machines or the expert operators.</div><div class="src">The gap Forgeron closes</div></div>
    </div>
  </div>
</section>

<section id="solution">
  <div class="wrap">
    <div class="tag"><span class="eyebrow">The solution</span><span class="rule"></span><span class="n">02</span></div>
    <div class="two">
      <div>
        <h2>A complete 5-axis machine, at a fraction of the price.</h2>
        <p class="lede">Our own controller runs on an <b class="mono" style="color:var(--steel)">$8</b>
          microcontroller with open-source firmware and an embedded AI agent. That's our cost
          advantage — it lets us sell a full, capable machine for a fraction of an imported one,
          and removes the need for a highly-trained operator.</p>
        <div class="price">
          <span class="now">10M FCFA</span>
          <span class="was">~25M imported</span>
          <span class="cut">÷ 2.5</span>
        </div>
      </div>
      <div class="spec">
        <div><span>Configuration</span><span>Trunnion · X Y Z + A C</span></div>
        <div><span>Controller</span><span>ESP32 · FluidNC v3.7</span></div>
        <div><span>Drives</span><span>5 × TB6600 steppers</span></div>
        <div><span>Control</span><span>Real-time DRO · G-code streaming</span></div>
        <div><span>Interface</span><span>Phone or PC · plain language</span></div>
        <div><span>Status</span><span style="color:var(--ok)">Built &amp; working</span></div>
      </div>
    </div>
  </div>
</section>

<section id="technology">
  <div class="wrap">
    <div class="tag"><span class="eyebrow">The technology</span><span class="rule"></span><span class="n">03</span></div>
    <h2 style="margin-bottom:8px">An AI that drives the machine — safely.</h2>
    <p class="lede" style="margin-bottom:28px">Not a chatbot bolted on. A large language model wired to
      the machine through 12 safe tools, with a control layer that keeps the operator in charge.</p>
    <div class="pillars">
      <div class="pill"><div class="k">01 · AGENTIC</div><h3>Plain-language control</h3><p>The operator states an intent; the agent plans and runs the tool sequence through 12 machine tools, with per-tool permissions and an always-on emergency stop.</p></div>
      <div class="pill"><div class="k">02 · SAFE</div><h3>Look-ahead validation</h3><p>Before any motion, the full tool-path is simulated against the machine's real mechanical limits — a move that would collide is refused, not run.</p></div>
      <div class="pill"><div class="k">03 · RESILIENT</div><h3>Built for the field</h3><p>The machine is controlled locally with no internet; AI calls route over mobile data, with automatic multi-model fallback to keep the cost near zero.</p></div>
    </div>
  </div>
</section>

<section id="product">
  <div class="wrap">
    <div class="tag"><span class="eyebrow">The product in action</span><span class="rule"></span><span class="n">04</span></div>
    <div class="shot">
      <img src="{PHONES}" alt="Forgeron dashboard, AI agent and the real machine">
      <div class="caps"><span>Real-time 5-axis DRO</span><span>AI agent · function calling</span><span>Physical machine · built</span></div>
    </div>
  </div>
</section>

<section id="traction">
  <div class="wrap">
    <div class="tag"><span class="eyebrow">Traction</span><span class="rule"></span><span class="n">05</span></div>
    <div class="facts">
      <div class="fact"><span class="m">HARDWARE</span><span class="t"><b>Working 5-axis machine</b> — built and demonstrated end-to-end on real hardware.</span></div>
      <div class="fact"><span class="m">SOFTWARE</span><span class="t">Functional app + AI agent · open-source code on GitHub.</span></div>
      <div class="fact"><span class="m">DEMAND</span><span class="t">First partner interested in testing &amp; adoption — <b>Kouratechnique</b>.</span></div>
      <div class="fact"><span class="m">SELECTED</span><span class="t"><b>Cohort 1, METI-funded UniPods AI Programme</b> — among 244 founders chosen from 670 applicants.</span></div>
    </div>
  </div>
</section>

<section id="team">
  <div class="wrap">
    <div class="tag"><span class="eyebrow">Team</span><span class="rule"></span><span class="n">06</span></div>
    <div class="team">
      <div class="member"><div class="role">Founder &amp; Engineer</div><h3>Lamine SACKO</h3><p>Built Forgeron end-to-end — firmware, real-time protocol, the app and the AI agent.</p></div>
      <div class="member"><div class="role">Electronics &amp; Assembly</div><h3>Aboubacar Diamouténé</h3><p>Wiring, motor drivers and the build &amp; testing of the physical 5-axis machine.</p></div>
      <div class="member open"><div class="role">Open role</div><h3>Business &amp; Commercial</h3><p>Go-to-market and partnerships — the profile we're building next.</p></div>
    </div>
  </div>
</section>

<section id="contact">
  <div class="wrap">
    <div class="final">
      <div class="eyebrow" style="margin-bottom:14px">Get in touch</div>
      <h2>Let's bring precision manufacturing home.</h2>
      <div class="contact">
        <a href="mailto:sackolamine994@gmail.com"><b>Email</b>&nbsp;&nbsp;sackolamine994@gmail.com</a>
        <span><b>Based in</b>&nbsp;&nbsp;Bamako · Mali</span>
        <a href="https://github.com/professeurp2/forgeron" target="_blank" rel="noopener"><b>Code</b>&nbsp;&nbsp;github.com/professeurp2/forgeron</a>
        <a href="https://youtube.com/shorts/wCH-2Z9WxEw" target="_blank" rel="noopener"><b>Demo</b>&nbsp;&nbsp;youtube.com/shorts/wCH-2Z9WxEw</a>
      </div>
    </div>
  </div>
</section>
</main>

<footer class="wrap">
  <span>FORGERON · AI-piloted 5-axis CNC · Bamako, Mali</span>
  <span>© 2026 Forgeron</span>
</footer>
"""

out = pathlib.Path("/home/user/forgeron/scratch/index.html")
out.write_text(HTML, encoding="utf-8")
print("written", out, round(len(HTML)/1024), "KB")
