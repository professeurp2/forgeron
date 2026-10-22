// Forgeron — Pitch Deck (FR) — "numbers + proof + visual" style. 13 slides.
const P = require("pptxgenjs");
const ROOT = "/home/user/forgeron";
const LOGO = ROOT + "/assets/logo.png";
const PHONES = ROOT + "/scratch/phones.png";
const MACHINE = ROOT + "/scratch/machine.png";

const BG="141821", BG2="1E2530", CARD="242E3B", CARD2="2B3644";
const TXT="EAECEF", MUT="9AA6B2", DIM="6E7A88";
const FORGE="FF6A1A", FORGE2="FF8C42", EMBER="FFB347";
const AI="4C8DF6", GREEN="1EBE7B", REDX="E5675E";
const F="Calibri";

const p = new P();
p.layout = "LAYOUT_WIDE";
const W = 13.33, H = 7.5, M = 0.62;

function slide(bg){ const s=p.addSlide(); s.background={color:bg||BG}; return s; }
function badge(s,x,y,n,col){ s.addText(String(n),{x,y,w:0.46,h:0.46,fontFace:F,fontSize:19,bold:true,color:"FFFFFF",align:"center",valign:"middle",fill:{color:col||FORGE},shape:p.ShapeType.roundRect,rectRadius:0.07,isTextBox:true,margin:0}); }
function title(s,t,n,col){ if(n!==undefined) badge(s,M,0.5,n,col); s.addText(t,{x:n!==undefined?M+0.62:M,y:0.46,w:W-2*M-0.6,h:0.62,fontFace:F,fontSize:28,bold:true,color:"FFFFFF",align:"left",valign:"middle",isTextBox:true,margin:0}); }
function foot(s,n){ s.addText("Forgeron · Pitch UNIPOD AI 2024 — "+n,{x:M,y:H-0.42,w:W-2*M,h:0.3,fontFace:F,fontSize:9,color:DIM,isTextBox:true,margin:0}); }
function card(s,x,y,w,h,col){ s.addShape(p.ShapeType.roundRect,{x,y,w,h,fill:{color:col||CARD},rectRadius:0.09,line:{color:CARD2,width:1}}); }
// big stat callout: value + label + source
function stat(s,x,y,w,val,valcol,lbl,src){ card(s,x,y,w,2.55,CARD);
  s.addText(val,{x:x+0.2,y:y+0.28,w:w-0.4,h:0.9,fontFace:F,fontSize:34,bold:true,color:valcol,align:"center",valign:"middle",isTextBox:true,margin:0});
  s.addText(lbl,{x:x+0.22,y:y+1.2,w:w-0.44,h:0.9,fontFace:F,fontSize:13,color:TXT,align:"center",valign:"top",lineSpacingMultiple:1.05,isTextBox:true,margin:0});
  if(src) s.addText(src,{x:x+0.2,y:y+2.15,w:w-0.4,h:0.3,fontFace:F,fontSize:9,italic:true,color:DIM,align:"center",isTextBox:true,margin:0}); }
const PH = t => ({text:t,options:{color:EMBER,bold:true}}); // ⟦placeholder⟧ helper

/* 1 · COVER */
(function(){ const s=slide(BG);
  s.addShape(p.ShapeType.roundRect,{x:W-4.6,y:-1.4,w:5.2,h:5.2,fill:{color:FORGE,transparency:86},rectRadius:2.6,line:{type:"none"}});
  s.addImage({path:LOGO,x:M,y:0.9,w:1.15,h:1.15});
  s.addText("FORGERON",{x:M,y:2.25,w:11,h:1.0,fontFace:F,fontSize:54,bold:true,color:"FFFFFF",charSpacing:1,isTextBox:true,margin:0});
  s.addText([{text:"Le premier contrôleur CNC 5-axes ",options:{color:TXT}},{text:"piloté par IA",options:{color:FORGE2,bold:true}}],
    {x:M,y:3.35,w:11.5,h:0.6,fontFace:F,fontSize:24,isTextBox:true,margin:0});
  s.addText("Pensé pour l'industrie africaine — un microcontrôleur à 8 $ transformé en machine-outil qu'on opère en langage naturel.",
    {x:M,y:4.0,w:9.6,h:0.9,fontFace:F,fontSize:14,color:MUT,isTextBox:true,margin:0});
  s.addText([{text:"Lamine SACKO",options:{bold:true,color:"FFFFFF"}},{text:"   ·   Fondateur & Ingénieur   ·   Mali",options:{color:MUT}}],
    {x:M,y:H-1.15,w:9,h:0.35,fontFace:F,fontSize:13,isTextBox:true,margin:0});
  s.addText("UNIPOD AI Innovation Pipeline · timbuktoo / UNDP",{x:M,y:H-0.78,w:9,h:0.3,fontFace:F,fontSize:11,color:DIM,isTextBox:true,margin:0});
})();

/* 2 · PROBLÈME (chiffres + sources) */
(function(){ const s=slide(BG); title(s,"Le problème",1);
  const w=(W-2*M-0.6)/3;
  stat(s,M,1.55,w,"5 000 – 50 000 $",FORGE,"Prix d'un contrôleur CNC 5-axes industriel","Source : catalogues Fanuc / Heidenhain / Siemens");
  stat(s,M+w+0.3,1.55,w,"≈ 2 %",FORGE2,"Part de l'Afrique dans la production manufacturière mondiale","Source : UNIDO");
  // third: placeholder import stat
  card(s,M+2*(w+0.3),1.55,w,2.55,CARD);
  s.addText([PH("⟦ ___ % ⟧")],{x:M+2*(w+0.3)+0.2,y:1.83,w:w-0.4,h:0.9,fontFace:F,fontSize:34,bold:true,align:"center",valign:"middle",isTextBox:true,margin:0});
  s.addText("de l'outillage & des pièces de précision sont importés",{x:M+2*(w+0.3)+0.22,y:2.75,w:w-0.44,h:0.9,fontFace:F,fontSize:13,color:TXT,align:"center",valign:"top",lineSpacingMultiple:1.05,isTextBox:true,margin:0});
  s.addText("Source : ⟦ à confirmer ⟧",{x:M+2*(w+0.3)+0.2,y:3.7,w:w-0.4,h:0.3,fontFace:F,fontSize:9,italic:true,color:DIM,align:"center",isTextBox:true,margin:0});
  s.addShape(p.ShapeType.roundRect,{x:M,y:4.5,w:W-2*M,h:1.5,fill:{color:CARD2},rectRadius:0.1,line:{type:"none"}});
  s.addText([{text:"→  ",options:{color:FORGE,bold:true}},{text:"Coût + compétence = les ateliers, fablabs et PME africaines sont ",options:{color:TXT}},{text:"exclus de la fabrication de précision",options:{bold:true,color:"FFFFFF"}},{text:". La valeur part à l'importation.",options:{color:TXT}}],
    {x:M+0.35,y:4.5,w:W-2*M-0.7,h:1.5,fontFace:F,fontSize:17,valign:"middle",isTextBox:true,margin:0});
  foot(s,2);
})();

/* 3 · SOLUTION */
(function(){ const s=slide(BG); title(s,"La solution",2);
  s.addText([{text:"Forgeron transforme un ",options:{color:TXT}},{text:"ESP32 à ~8 $",options:{color:FORGE2,bold:true}},{text:" (FluidNC open-source) en ",options:{color:TXT}},{text:"contrôleur CNC 5-axes industriel",options:{color:"FFFFFF",bold:true}},{text:", piloté depuis un smartphone.",options:{color:TXT}}],
    {x:M,y:1.35,w:W-2*M,h:0.9,fontFace:F,fontSize:19,valign:"top",isTextBox:true,margin:0});
  card(s,M,2.55,3.05,1.5,CARD); s.addText("~8 $",{x:M,y:2.8,w:3.05,h:0.75,fontFace:F,fontSize:36,bold:true,color:GREEN,align:"center",isTextBox:true,margin:0}); s.addText("contrôleur Forgeron",{x:M,y:3.55,w:3.05,h:0.4,fontFace:F,fontSize:12,color:MUT,align:"center",isTextBox:true,margin:0});
  s.addText("−99 %",{x:M+3.1,y:2.55,w:0.95,h:1.5,fontFace:F,fontSize:20,bold:true,italic:true,color:FORGE,align:"center",valign:"middle",isTextBox:true,margin:0});
  card(s,M+4.05,2.55,3.05,1.5,CARD); s.addText("5 000 $+",{x:M+4.05,y:2.8,w:3.05,h:0.75,fontFace:F,fontSize:36,bold:true,color:REDX,align:"center",isTextBox:true,margin:0}); s.addText("contrôleurs industriels",{x:M+4.05,y:3.55,w:3.05,h:0.4,fontFace:F,fontSize:12,color:MUT,align:"center",isTextBox:true,margin:0});
  card(s,7.65,2.55,W-M-7.65,1.5,CARD);
  s.addText("DRO temps réel · Jog 5 axes · Streaming G-code\nVisualiseur 3D Trunnion · Palpage · WCS\nSécurité matérielle (arrêt d'urgence, watchdog)",
    {x:7.85,y:2.55,w:W-M-7.85,h:1.5,fontFace:F,fontSize:13,color:TXT,valign:"middle",lineSpacingMultiple:1.15,isTextBox:true,margin:0});
  s.addShape(p.ShapeType.roundRect,{x:M,y:4.5,w:W-2*M,h:1.5,fill:{color:"172A45"},rectRadius:0.1,line:{color:"2C4A73",width:1}});
  s.addText([{text:"+ un agent IA",options:{bold:true,color:AI}},{text:"  qui pilote la machine ",options:{color:TXT}},{text:"en langage naturel",options:{bold:true,color:"FFFFFF"}},{text:" — l'opérateur parle, la machine exécute, sans risque de collision.",options:{color:TXT}}],
    {x:M+0.35,y:4.5,w:W-2*M-0.7,h:1.5,fontFace:F,fontSize:18,valign:"middle",isTextBox:true,margin:0});
  foot(s,3);
})();

/* 4 · PRODUIT (déjà réel) */
(function(){ const s=slide(BG); title(s,"Le produit — déjà réel",3);
  s.addImage({path:PHONES,x:0.7,y:1.45,w:11.93,h:4.2,sizing:{type:"contain",w:11.93,h:4.2}});
  const labs=["App de contrôle","Agent IA — function calling","Machine physique construite"];
  const xs=[1.09,5.07,9.05];
  labs.forEach((l,i)=>s.addText(l,{x:xs[i],y:5.75,w:3.2,h:0.35,fontFace:F,fontSize:12,bold:true,color:TXT,align:"center",isTextBox:true,margin:0}));
  s.addText("Application fonctionnelle + machine 5-axes réelle, démontrée de bout en bout sur matériel réel.",
    {x:M,y:6.2,w:W-2*M,h:0.5,fontFace:F,fontSize:14,color:MUT,align:"center",isTextBox:true,margin:0});
  foot(s,4);
})();

/* 5 · IA & POURQUOI MAINTENANT */
(function(){ const s=slide(BG); title(s,"Une IA qui pilote la machine — en toute sécurité","IA",AI);
  const cols=[["Contrôle agentique sûr","LLM + function calling · 12 outils · permissions par outil · arrêt d'urgence prioritaire"],
    ["Validation lookahead","simule toute la trajectoire vs limites réelles AVANT tout mouvement → zéro collision"],
    ["Résilience & coût","appels IA en 4G/5G · repli multi-modèles · 500 requêtes/jour gratuites"]];
  const w=(W-2*M-0.6)/3; let x=M;
  cols.forEach((c,i)=>{ card(s,x,1.55,w,2.7,CARD);
    s.addText(String(i+1),{x:x+0.25,y:1.8,w:0.5,h:0.5,fontFace:F,fontSize:16,bold:true,color:"FFFFFF",align:"center",valign:"middle",fill:{color:AI},shape:p.ShapeType.roundRect,rectRadius:0.07,isTextBox:true,margin:0});
    s.addText(c[0],{x:x+0.25,y:2.45,w:w-0.5,h:0.7,fontFace:F,fontSize:16,bold:true,color:"FFFFFF",valign:"top",isTextBox:true,margin:0});
    s.addText(c[1],{x:x+0.25,y:3.15,w:w-0.5,h:1.0,fontFace:F,fontSize:12.5,color:MUT,valign:"top",lineSpacingMultiple:1.1,isTextBox:true,margin:0}); x+=w+0.3;});
  s.addShape(p.ShapeType.roundRect,{x:M,y:4.55,w:W-2*M,h:1.5,fill:{color:CARD2},rectRadius:0.1,line:{type:"none"}});
  s.addText([{text:"Pourquoi maintenant ?  ",options:{bold:true,color:EMBER}},{text:"Le hardware CNC est devenu quasi gratuit (FluidNC/ESP32) et le function-calling rend le pilotage en langage naturel fiable. ",options:{color:TXT}},{text:"Notre avantage = la couche de sécurité, pas le modèle.",options:{bold:true,color:"FFFFFF"}}],
    {x:M+0.35,y:4.55,w:W-2*M-0.7,h:1.5,fontFace:F,fontSize:15,valign:"middle",isTextBox:true,margin:0});
  foot(s,5);
})();

/* 6 · MARCHÉ (TAM/SAM/SOM + part actuelle) */
(function(){ const s=slide(BG); title(s,"Le marché",4);
  const rows=[["TAM","Afrique — ateliers, fablabs, écoles techniques","~150 000 unités","≈ 15 Mds FCFA / an","≈ 25 M$ / an",FORGE],
    ["SAM","Afrique de l'Ouest francophone (3–5 ans)","~15 000 unités","≈ 1,5 Md FCFA / an","≈ 2,5 M$ / an",FORGE2],
    ["SOM","Mali + amorçage régional (2 ans, +40 %/an)","~300 unités","≈ 30 M FCFA / an","≈ 50 k$ / an",EMBER]];
  let y=1.5; rows.forEach(r=>{ card(s,M,y,W-2*M,1.0,CARD);
    s.addText(r[0],{x:M+0.2,y:y+0.12,w:1.5,h:0.76,fontFace:F,fontSize:24,bold:true,color:r[5],valign:"middle",isTextBox:true,margin:0});
    s.addText(r[1],{x:M+1.9,y:y,w:5.0,h:1.0,fontFace:F,fontSize:13,color:TXT,valign:"middle",isTextBox:true,margin:0});
    s.addText(r[2],{x:M+6.9,y:y,w:2.0,h:1.0,fontFace:F,fontSize:13,color:MUT,valign:"middle",align:"center",isTextBox:true,margin:0});
    s.addText([{text:r[3]+"\n",options:{bold:true,color:"FFFFFF",fontSize:15}},{text:r[4],options:{color:r[5],fontSize:12}}],
      {x:W-M-3.0,y:y,w:2.8,h:1.0,fontFace:F,valign:"middle",align:"right",isTextBox:true,margin:0}); y+=1.12;});
  s.addShape(p.ShapeType.roundRect,{x:M,y:4.9,w:W-2*M,h:1.05,fill:{color:CARD2},rectRadius:0.1,line:{type:"none"}});
  s.addText([{text:"Part actuellement servie par une solution locale abordable : ",options:{color:TXT}},{text:"≈ 0 %",options:{bold:true,color:GREEN,fontSize:18}},{text:"  — le marché est capté par des contrôleurs importés, chers et fermés.",options:{color:TXT}}],
    {x:M+0.35,y:4.9,w:W-2*M-0.7,h:1.05,fontFace:F,fontSize:15,valign:"middle",isTextBox:true,margin:0});
  s.addText("Estimations à valider (customer discovery / Wadhwani) · hypothèse revenu ≈ 100 000 FCFA / client / an (Pro + hardware amorti).",
    {x:M,y:6.05,w:W-2*M,h:0.4,fontFace:F,fontSize:10,italic:true,color:DIM,isTextBox:true,margin:0});
  foot(s,6);
})();

/* 7 · BUSINESS MODEL */
(function(){ const s=slide(BG); title(s,"Business model",5);
  const steps=[["1","App freemium","Contrôle de base gratuit → adoption dans les fablabs"],
    ["2","Abonnement Pro","Agent IA, multi-machines, analytics"],
    ["3","Bundles hardware","ESP32 + drivers pré-flashés & calibrés"],
    ["4","Marketplace","Configs machines & macros vérifiées"]];
  const w=(W-2*M-0.9)/4; let x=M;
  steps.forEach((st,i)=>{ const col=[FORGE,FORGE2,EMBER,GREEN][i]; card(s,x,1.7,w,2.9,CARD);
    s.addText(st[0],{x:x+(w-0.6)/2,y:2.0,w:0.6,h:0.6,fontFace:F,fontSize:22,bold:true,color:"FFFFFF",align:"center",valign:"middle",fill:{color:col},shape:p.ShapeType.roundRect,rectRadius:0.3,isTextBox:true,margin:0});
    s.addText(st[1],{x:x+0.15,y:2.75,w:w-0.3,h:0.6,fontFace:F,fontSize:15,bold:true,color:"FFFFFF",align:"center",valign:"top",isTextBox:true,margin:0});
    s.addText(st[2],{x:x+0.2,y:3.35,w:w-0.4,h:1.15,fontFace:F,fontSize:12,color:MUT,align:"center",valign:"top",lineSpacingMultiple:1.1,isTextBox:true,margin:0});
    if(i<3) s.addText("→",{x:x+w-0.02,y:2.85,w:0.32,h:0.4,fontFace:F,fontSize:18,bold:true,color:DIM,align:"center",valign:"middle",isTextBox:true,margin:0});
    x+=w+0.3;});
  s.addShape(p.ShapeType.roundRect,{x:M,y:4.85,w:W-2*M,h:1.05,fill:{color:CARD2},rectRadius:0.1,line:{type:"none"}});
  s.addText([{text:"Revenu moyen visé ≈ ",options:{color:TXT}},{text:"100 000 FCFA / client / an",options:{bold:true,color:"FFFFFF"}},{text:"  ·  faible coût d'entrée, revenu récurrent, hardware comme accélérateur.",options:{color:TXT}}],
    {x:M+0.35,y:4.85,w:W-2*M-0.7,h:1.05,fontFace:F,fontSize:14.5,valign:"middle",isTextBox:true,margin:0});
  foot(s,7);
})();

/* 8 · GO-TO-MARKET */
(function(){ const s=slide(BG); title(s,"Aller au marché",6);
  card(s,M,1.55,5.9,4.3,CARD);
  s.addText("Cibles prioritaires",{x:M+0.3,y:1.75,w:5.3,h:0.4,fontFace:F,fontSize:15,bold:true,color:FORGE2,isTextBox:true,margin:0});
  s.addText([
    {text:"Fablabs & makerspaces (réseau AfriLabs)",options:{bullet:{code:"2022"},color:TXT,breakLine:true}},
    {text:"Écoles techniques & TVET",options:{bullet:{code:"2022"},color:TXT,breakLine:true}},
    {text:"Ateliers d'usinage & PME (via Kouratechnique)",options:{bullet:{code:"2022"},color:TXT,breakLine:true}},
    {text:"Fabricants de kits CNC (2e temps)",options:{bullet:{code:"2022"},color:TXT}}],
    {x:M+0.35,y:2.3,w:5.3,h:3.4,fontFace:F,fontSize:14.5,paraSpaceAfter:12,isTextBox:true,margin:0});
  card(s,6.9,1.55,W-M-6.9,4.3,CARD);
  s.addText("Canaux & phasage",{x:7.15,y:1.75,w:5.0,h:0.4,fontFace:F,fontSize:15,bold:true,color:FORGE2,isTextBox:true,margin:0});
  s.addText([
    {text:"Démos & vidéos courtes, bouche-à-oreille",options:{bullet:{code:"2022"},color:TXT,breakLine:true}},
    {text:"Partenariats institutionnels (écoles, hubs)",options:{bullet:{code:"2022"},color:TXT,breakLine:true}},
    {text:"Bundles certifiés = entrée hardware",options:{bullet:{code:"2022"},color:TXT,breakLine:true}},
    {text:"Mali → Afrique de l'Ouest francophone → continent",options:{bullet:{code:"2022"},color:TXT}}],
    {x:7.2,y:2.3,w:W-M-7.4,h:3.4,fontFace:F,fontSize:14.5,paraSpaceAfter:12,isTextBox:true,margin:0});
  foot(s,8);
})();

/* 9 · POSITIONNEMENT */
(function(){ const s=slide(BG); title(s,"Positionnement",7);
  const head=(t,c)=>({text:t,options:{bold:true,color:c||"FFFFFF",fill:{color:CARD2},align:"center",valign:"middle",fontSize:13}});
  const cell=(t,c)=>({text:t,options:{color:c||TXT,align:"center",valign:"middle",fontSize:12.5,fill:{color:CARD}}});
  const yes=t=>({text:t||"✓",options:{color:GREEN,bold:true,align:"center",valign:"middle",fontSize:14,fill:{color:CARD}}});
  const no=t=>({text:t||"✕",options:{color:REDX,bold:true,align:"center",valign:"middle",fontSize:14,fill:{color:CARD}}});
  const rows=[
    [head(""),head("Contrôleurs propriétaires"),head("Senders GRBL gratuits"),head("Forgeron",FORGE2)],
    [head("Prix"),no("5 000–50 000 $"),yes("Faible / gratuit"),yes("~8 $ + app")],
    [head("5 axes réels"),yes(),no(),yes()],
    [head("IA / langage naturel"),no(),no(),yes()],
    [head("Sécurité anti-collision"),cell("Oui (fermée)"),no(),yes("Lookahead")],
    [head("Ouvert & abordable"),no(),cell("Ouvert mais limité"),yes()]
  ];
  s.addTable(rows,{x:M,y:1.6,w:W-2*M,colW:[2.7,3.13,3.13,3.13],rowH:0.62,border:{type:"solid",color:BG,pt:2},fontFace:F,valign:"middle"});
  s.addText([{text:"→  ",options:{color:FORGE,bold:true}},{text:"Forgeron occupe le trou du marché : ",options:{color:TXT}},{text:"abordable + 5 axes + IA sûre.",options:{bold:true,color:"FFFFFF"}}],
    {x:M,y:5.7,w:W-2*M,h:0.5,fontFace:F,fontSize:15,align:"center",isTextBox:true,margin:0});
  foot(s,9);
})();

/* 10 · TRACTION (chiffres réels ⟦⟧) */
(function(){ const s=slide(BG); title(s,"Traction",8,GREEN);
  s.addImage({path:MACHINE,x:M,y:1.5,w:3.0,h:3.6,sizing:{type:"contain",w:3.0,h:3.6}});
  s.addText("Machine 5-axes réelle",{x:M,y:5.15,w:3.0,h:0.3,fontFace:F,fontSize:11,italic:true,color:MUT,align:"center",isTextBox:true,margin:0});
  // proof numbers row
  const nx=3.9, nw=(W-M-nx-0.4)/2;
  card(s,nx,1.5,nw,1.15,CARD2); s.addText([PH("⟦ ___ FCFA ⟧")],{x:nx,y:1.62,w:nw,h:0.55,fontFace:F,fontSize:20,bold:true,align:"center",isTextBox:true,margin:0}); s.addText("coût de construction de la machine",{x:nx,y:2.15,w:nw,h:0.4,fontFace:F,fontSize:11,color:MUT,align:"center",isTextBox:true,margin:0});
  card(s,nx+nw+0.4,1.5,nw,1.15,CARD2); s.addText([PH("⟦ ± __ mm ⟧")],{x:nx+nw+0.4,y:1.62,w:nw,h:0.55,fontFace:F,fontSize:20,bold:true,align:"center",isTextBox:true,margin:0}); s.addText("précision / tolérance atteinte",{x:nx+nw+0.4,y:2.15,w:nw,h:0.4,fontFace:F,fontSize:11,color:MUT,align:"center",isTextBox:true,margin:0});
  // done list
  card(s,nx,2.8,W-M-nx,2.05,CARD);
  s.addText("Déjà accompli",{x:nx+0.25,y:2.95,w:6,h:0.35,fontFace:F,fontSize:14,bold:true,color:GREEN,isTextBox:true,margin:0});
  const done=["Machine 5-axes physique construite & fonctionnelle","App de contrôle + agent IA opérationnels","Vidéo de démonstration + code open-source (GitHub)","Partenaire intéressé : Kouratechnique ⟦ besoin : __ machines ⟧","Équipe de 2 (ingénieur + technicien)"];
  s.addText(done.map((d,i)=>({text:d,options:{bullet:{code:"2713"},color:TXT,breakLine:i<done.length-1}})),
    {x:nx+0.3,y:3.35,w:W-M-nx-0.6,h:1.4,fontFace:F,fontSize:13,paraSpaceAfter:5,isTextBox:true,margin:0});
  card(s,nx,4.95,W-M-nx,0.95,CARD2);
  s.addText([{text:"Prochaines étapes : ",options:{bold:true,color:EMBER}},{text:"pilotes clients réels · durcissement & edge de l'agent IA · lettre de partenariat Kouratechnique.",options:{color:TXT}}],
    {x:nx+0.25,y:4.95,w:W-M-nx-0.5,h:0.95,fontFace:F,fontSize:13,valign:"middle",isTextBox:true,margin:0});
  foot(s,10);
})();

/* 11 · USAGE DU SOUTIEN */
(function(){ const s=slide(BG); title(s,"Usage du soutien",9);
  const cols=[["Skilling IA","Ethiopian AI Institute — durcir l'agent, viser l'edge / on-device"],
    ["Pilotes terrain","déployer chez Kouratechnique + ⟦ 2–3 ⟧ ateliers pilotes"],
    ["Venture (Wadhwani)","customer discovery, business model, go-to-market, investment readiness"]];
  const w=(W-2*M-0.6)/3; let x=M;
  cols.forEach((c,i)=>{ card(s,x,1.55,w,2.4,CARD);
    s.addText(String(i+1),{x:x+0.25,y:1.8,w:0.5,h:0.5,fontFace:F,fontSize:16,bold:true,color:"FFFFFF",align:"center",valign:"middle",fill:{color:FORGE},shape:p.ShapeType.roundRect,rectRadius:0.07,isTextBox:true,margin:0});
    s.addText(c[0],{x:x+0.25,y:2.45,w:w-0.5,h:0.5,fontFace:F,fontSize:16,bold:true,color:"FFFFFF",isTextBox:true,margin:0});
    s.addText(c[1],{x:x+0.25,y:2.95,w:w-0.5,h:0.9,fontFace:F,fontSize:12.5,color:MUT,valign:"top",lineSpacingMultiple:1.1,isTextBox:true,margin:0}); x+=w+0.3;});
  // optional funds allocation (placeholder amounts)
  card(s,M,4.2,W-2*M,1.7,CARD2);
  s.addText("Si financement d'amorçage",{x:M+0.3,y:4.35,w:6,h:0.35,fontFace:F,fontSize:13,bold:true,color:EMBER,isTextBox:true,margin:0});
  s.addText([
    {text:"Hardware & pièces pour pilotes : ",options:{color:TXT}},PH("⟦ ___ FCFA ⟧"),{text:"      Développement IA (edge) : ",options:{color:TXT}},PH("⟦ ___ FCFA ⟧"),{text:"\nFonds de roulement : ",options:{color:TXT}},PH("⟦ ___ FCFA ⟧"),{text:"      Marketing & démos : ",options:{color:TXT}},PH("⟦ ___ FCFA ⟧")],
    {x:M+0.35,y:4.75,w:W-2*M-0.7,h:1.05,fontFace:F,fontSize:14,valign:"top",lineSpacingMultiple:1.2,isTextBox:true,margin:0});
  foot(s,11);
})();

/* 12 · ÉQUIPE */
(function(){ const s=slide(BG); title(s,"L'équipe",10);
  const mem=[["Lamine SACKO","Fondateur & Ingénieur","Application, agent IA, firmware/FluidNC, temps réel. A construit Forgeron de bout en bout.",FORGE,"LS"],
    ["Aboubacar DIAMOUTÉNÉ","Technicien électronique & assemblage","Câblage, drivers moteurs (TB6600), montage & tests de la machine.",FORGE2,"AD"],
    ["Poste ouvert","Business / Commercial","Développement commercial & partenariats — profil recherché via le programme.",DIM,"?"]];
  const w=(W-2*M-0.7)/3; let x=M;
  mem.forEach(m=>{ card(s,x,1.7,w,3.6,CARD);
    s.addShape(p.ShapeType.ellipse,{x:x+w/2-0.5,y:1.95,w:1.0,h:1.0,fill:{color:m[3]},line:{type:"none"}});
    s.addText(m[4],{x:x+w/2-0.5,y:1.95,w:1.0,h:1.0,fontFace:F,fontSize:22,bold:true,color:"FFFFFF",align:"center",valign:"middle",isTextBox:true,margin:0});
    s.addText(m[0],{x:x+0.15,y:3.1,w:w-0.3,h:0.4,fontFace:F,fontSize:15,bold:true,color:"FFFFFF",align:"center",valign:"top",isTextBox:true,margin:0});
    s.addText(m[1],{x:x+0.15,y:3.52,w:w-0.3,h:0.5,fontFace:F,fontSize:12,bold:true,color:m[3]==DIM?MUT:m[3],align:"center",valign:"top",isTextBox:true,margin:0});
    s.addText(m[2],{x:x+0.3,y:4.12,w:w-0.6,h:1.05,fontFace:F,fontSize:11.5,color:MUT,align:"center",valign:"top",lineSpacingMultiple:1.1,isTextBox:true,margin:0});
    x+=w+0.35;});
  s.addText([{text:"Partenaire : ",options:{color:MUT}},{text:"Kouratechnique",options:{bold:true,color:TXT}},{text:"  (atelier / terrain de test).",options:{color:MUT}}],
    {x:M,y:5.5,w:W-2*M,h:0.4,fontFace:F,fontSize:13,align:"center",isTextBox:true,margin:0});
  foot(s,12);
})();

/* 13 · THE ASK + VISION */
(function(){ const s=slide(BG2);
  s.addShape(p.ShapeType.roundRect,{x:W-4.4,y:H-4.0,w:5.2,h:5.2,fill:{color:FORGE,transparency:88},rectRadius:2.6,line:{type:"none"}});
  title(s,"Notre demande & vision");
  s.addText("Ce que le programme UNIPOD AI nous apporte",{x:M,y:1.35,w:11,h:0.4,fontFace:F,fontSize:14,bold:true,color:FORGE2,isTextBox:true,margin:0});
  const ask=[["Skilling IA","Ethiopian AI Institute — durcir l'agent, edge / on-device"],
    ["Wadhwani (14 sem.)","prototype → venture : customer discovery, business model, go-to-market, investment readiness"],
    ["Réseau timbuktoo","mentors, bootcamp d'Addis-Abeba, écosystème & investisseurs"]];
  let y=1.85; ask.forEach((a,i)=>{
    s.addText(String(i+1),{x:M,y:y,w:0.45,h:0.45,fontFace:F,fontSize:15,bold:true,color:"FFFFFF",align:"center",valign:"middle",fill:{color:FORGE},shape:p.ShapeType.roundRect,rectRadius:0.07,isTextBox:true,margin:0});
    s.addText([{text:a[0]+" — ",options:{bold:true,color:"FFFFFF"}},{text:a[1],options:{color:TXT}}],
      {x:M+0.6,y:y-0.02,w:11.4,h:0.5,fontFace:F,fontSize:14,valign:"middle",isTextBox:true,margin:0}); y+=0.62;});
  s.addShape(p.ShapeType.roundRect,{x:M,y:3.95,w:W-2*M,h:1.35,fill:{color:CARD},rectRadius:0.1,line:{type:"none"}});
  s.addText([{text:"Vision 2–3 ans : ",options:{bold:true,color:EMBER}},{text:"des contrôleurs Forgeron dans les ateliers d'Afrique de l'Ouest et de l'Est — produire localement ce qui est importé, et créer des emplois qualifiés.",options:{color:TXT}}],
    {x:M+0.35,y:3.95,w:W-2*M-0.7,h:1.35,fontFace:F,fontSize:15.5,valign:"middle",isTextBox:true,margin:0});
  s.addText([{text:"Lamine SACKO",options:{bold:true,color:"FFFFFF"}},{text:"   ·   sackolamine994@gmail.com   ·   Mali   ·   github.com/professeurp2/forgeron",options:{color:MUT}}],
    {x:M,y:5.6,w:W-2*M,h:0.4,fontFace:F,fontSize:12.5,isTextBox:true,margin:0});
  s.addText("Forgeron — construisons l'IA qui façonne l'avenir industriel de l'Afrique.",{x:M,y:6.05,w:W-2*M,h:0.4,fontFace:F,fontSize:13,italic:true,color:FORGE2,isTextBox:true,margin:0});
})();

p.writeFile({ fileName: ROOT + "/scratch/Forgeron_Pitch_Deck.pptx" }).then(f=>console.log("WROTE", f));
