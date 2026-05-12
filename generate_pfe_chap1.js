const docx = require("docx");
const fs = require("fs");

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, WidthType, BorderStyle, ShadingType,
  PageBreak, TableLayoutType, ImageRun, Header, Footer, PageNumber
} = docx;

// ═══════════════════════════════════════════════════
// CHARTE GRAPHIQUE
// ═══════════════════════════════════════════════════
const C = {
  primary: "1B365D",
  secondary: "4A7C9B",
  accent: "D4731A",
  bg: "F2F2F2",
  white: "FFFFFF",
  black: "000000",
};

const IMG_DIR = "C:\\Users\\CITT Unipod\\Documents\\ENI\\Mon PFE\\forgeron\\pfe_images\\";

function loadImg(name) {
  return fs.readFileSync(IMG_DIR + name);
}

// ═══════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════

function chapTitle(text) {
  return new Paragraph({
    children: [new TextRun({ text: text.toUpperCase(), bold: true, font: "Calibri", size: 32, color: C.primary })],
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
  });
}

function secTitle(num, text) {
  return new Paragraph({
    children: [new TextRun({ text: `${num}   ${text}`, bold: true, font: "Calibri", size: 26, color: C.primary })],
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 300, after: 150 },
  });
}

function subTitle(num, text) {
  return new Paragraph({
    children: [new TextRun({ text: `${num}   ${text}`, bold: true, font: "Calibri", size: 22, color: C.secondary })],
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 200, after: 100 },
  });
}

function body(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: "Times New Roman", size: 24 })],
    spacing: { after: 120, line: 360 },
    alignment: AlignmentType.JUSTIFIED,
  });
}

function bodyParts(parts) {
  return new Paragraph({
    children: parts.map(p => new TextRun({
      text: p.t,
      font: p.font || "Times New Roman",
      size: p.size || 24,
      bold: p.b || false,
      italics: p.i || false,
      color: p.c || C.black,
    })),
    spacing: { after: 120, line: 360 },
    alignment: AlignmentType.JUSTIFIED,
  });
}

function bullet(text, symbol = "➢") {
  return new Paragraph({
    children: [new TextRun({ text: `${symbol}   ${text}`, font: "Times New Roman", size: 24 })],
    spacing: { after: 80, line: 360 },
    indent: { left: 720 },
    alignment: AlignmentType.JUSTIFIED,
  });
}

function bulletBold(title, desc) {
  return new Paragraph({
    children: [
      new TextRun({ text: `➢   ${title} : `, font: "Times New Roman", size: 24, bold: true }),
      new TextRun({ text: desc, font: "Times New Roman", size: 24 }),
    ],
    spacing: { after: 80, line: 360 },
    indent: { left: 720 },
    alignment: AlignmentType.JUSTIFIED,
  });
}

function figCaption(num, desc) {
  return new Paragraph({
    children: [new TextRun({
      text: `Figure ${num} : ${desc}`,
      font: "Times New Roman", size: 20, italics: true, color: C.secondary,
    })],
    spacing: { before: 60, after: 200 },
    alignment: AlignmentType.CENTER,
  });
}

function insertImage(filename, widthPx, heightPx) {
  const imgData = loadImg(filename);
  return new Paragraph({
    children: [new ImageRun({
      data: imgData,
      transformation: { width: widthPx, height: heightPx },
      type: filename.endsWith('.jpeg') ? 'jpg' : 'png',
    })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 60 },
  });
}

function synthBox(lines) {
  return new Table({
    rows: [new TableRow({
      children: [new TableCell({
        children: lines.map(l => new Paragraph({
          children: [new TextRun({ text: l, font: "Times New Roman", size: 22, italics: true })],
          spacing: { after: 60 },
        })),
        shading: { type: ShadingType.SOLID, color: C.bg },
        borders: {
          top: { style: BorderStyle.NONE },
          bottom: { style: BorderStyle.NONE },
          right: { style: BorderStyle.NONE },
          left: { style: BorderStyle.SINGLE, size: 6, color: C.primary },
        },
        width: { size: 100, type: WidthType.PERCENTAGE },
      })],
    })],
    width: { size: 100, type: WidthType.PERCENTAGE },
  });
}

function tbl(headers, rows, caption) {
  const els = [];
  const hRow = new TableRow({
    tableHeader: true,
    children: headers.map(h => new TableCell({
      children: [new Paragraph({
        children: [new TextRun({ text: h, bold: true, font: "Calibri", size: 20, color: C.white })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 60, after: 60 },
      })],
      shading: { type: ShadingType.SOLID, color: C.primary },
      verticalAlign: "center",
    })),
  });
  const dRows = rows.map((row, i) => new TableRow({
    children: row.map(cell => new TableCell({
      children: [new Paragraph({
        children: [new TextRun({ text: String(cell), font: "Times New Roman", size: 20 })],
        spacing: { before: 40, after: 40 },
      })],
      shading: i % 2 === 1 ? { type: ShadingType.SOLID, color: C.bg } : undefined,
    })),
  }));
  els.push(new Table({
    rows: [hRow, ...dRows],
    width: { size: 100, type: WidthType.PERCENTAGE },
    layout: TableLayoutType.AUTOFIT,
  }));
  if (caption) {
    els.push(new Paragraph({
      children: [new TextRun({ text: caption, font: "Times New Roman", size: 20, italics: true, color: C.secondary })],
      spacing: { before: 60, after: 200 },
      alignment: AlignmentType.CENTER,
    }));
  }
  return els;
}

function timeline(year, event) {
  return new Paragraph({
    children: [
      new TextRun({ text: `${year}`, bold: true, font: "Calibri", size: 22, color: C.accent }),
      new TextRun({ text: `  —  ${event}`, font: "Times New Roman", size: 22 }),
    ],
    spacing: { after: 60 },
    indent: { left: 720 },
    border: { left: { style: BorderStyle.SINGLE, size: 4, color: C.secondary, space: 10 } },
  });
}

function codeBlock(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: "Consolas", size: 20, color: C.secondary })],
    spacing: { before: 80, after: 80 },
    indent: { left: 720 },
    shading: { type: ShadingType.SOLID, color: C.bg },
  });
}

function gap() {
  return new Paragraph({ children: [], spacing: { after: 60 } });
}

// ═══════════════════════════════════════════════════
// CHAPITRE 1 — CONTENU OPTIMISÉ AVEC IMAGES
// ═══════════════════════════════════════════════════

const ch1 = [
  chapTitle("1   CHAPITRE 1 : ÉTUDE BIBLIOGRAPHIQUE ET FONDEMENTS THÉORIQUES"),

  // ── 1.1 ──
  secTitle("1.1", "Introduction"),
  body(
    "Ce chapitre établit les fondements théoriques nécessaires à la conception d'une fraiseuse CNC 5 axes compacte. " +
    "L'étude s'articule en trois volets : le procédé de fraisage et les caractéristiques technologiques des outils de coupe, " +
    "les principes fondamentaux de la commande numérique et ses modes d'asservissement, " +
    "et la classification des architectures de machines CNC cinq axes avec leurs contraintes cinématiques."
  ),

  // ── 1.2 ──
  secTitle("1.2", "Généralités sur le procédé de fraisage"),

  subTitle("1.2.1", "Définition et principe du fraisage"),
  body(
    "Le fraisage est un procédé de fabrication par enlèvement de matière reposant sur la coordination entre " +
    "le mouvement de rotation d'un outil multi-arêtes (mouvement de coupe) et le déplacement de la pièce " +
    "(mouvement d'avance). Les fraiseuses conventionnelles sont classées selon l'orientation de leur broche."
  ),
  gap(),
  ...tbl(
    ["Type", "Orientation broche", "Mobilité", "Application principale"],
    [
      ["Horizontale", "Horizontale", "3 axes (X, Y, Z)", "Rainures, surfaces planes"],
      ["Verticale", "Verticale (⊥ table)", "3 axes (X, Y, Z)", "Surfaçage, perçage, poches"],
      ["Universelle", "Pivotante (H + V)", "3 axes + table rotative", "Rainures hélicoïdales, surfaces angulaires"],
    ],
    "Tableau 1.1 : Classification des fraiseuses conventionnelles"
  ),
  gap(),
  insertImage("image1.jpeg", 280, 220),
  figCaption("1.1", "Fraiseuse horizontale X6132"),
  insertImage("image2.png", 280, 220),
  figCaption("1.2", "Fraiseuse verticale"),
  insertImage("image3.png", 280, 220),
  figCaption("1.3", "Fraiseuse universelle WN736D"),

  // ── 1.2.2 ──
  subTitle("1.2.2", "Étude technologique des outils (Fraises)"),
  body(
    "La fraise est l'organe de coupe rotatif. Ses caractéristiques varient selon le mode de construction, " +
    "le nombre d'arêtes par dent (« taille ») et la géométrie de forme."
  ),
  gap(),
  ...tbl(
    ["Type", "Principe", "Avantage", "Usage"],
    [
      ["Monobloc", "ARS ou carbure massif", "Rigidité, précision", "Petites séries, CNC compactes"],
      ["Plaquettes amovibles", "Inserts carbure mécaniques", "Remplacement rapide", "Production industrielle"],
      ["Plaquettes brasées", "Inserts brasés sur acier", "Tenue sous fortes charges", "Usinage lourd"],
    ],
    "Tableau 1.2 : Classification par mode de construction"
  ),
  gap(),
  ...tbl(
    ["Taille", "Arêtes / dent", "Capacité", "Application"],
    [
      ["1 taille", "1 (périphérie)", "Surfaces planes", "Surfaçage"],
      ["2 tailles", "2 (péri + frontale)", "2 surfaces ⊥", "Épaulements"],
      ["3 tailles", "3 (péri + 2 latérales)", "3 côtés", "Rainurage profond"],
    ],
    "Tableau 1.3 : Classification par « taille »"
  ),

  // ── 1.2.3 ──
  subTitle("1.2.3", "Géométrie de forme et denture"),
  gap(),
  ...tbl(
    ["Forme", "Profil", "Application"],
    [
      ["Cylindrique", "Génératrices parallèles", "Surfaces planes"],
      ["Conique", "Génératrices inclinées", "Rainures en V"],
      ["De forme", "Profils spécifiques", "Géométries complexes, congés"],
    ],
    "Tableau 1.4 : Classification par forme"
  ),
  body(
    "La denture hélicoïdale assure une coupe progressive, réduisant les vibrations par rapport à la denture droite, " +
    "et améliore l'état de surface."
  ),

  // ── 1.2.4 ──
  subTitle("1.2.4", "Systèmes de fixation et porte-outils"),
  bodyParts([
    { t: "➢   Fixation par alésage : ", b: true },
    { t: "l'outil est monté sur un arbre porte-fraise via un alésage central (lisse avec clavetage ou taraudé par vissage)." },
  ]),
  insertImage("image13.jpeg", 260, 200),
  figCaption("1.4", "Arbre de fraisage à trou lisse"),
  insertImage("image14.jpeg", 260, 200),
  figCaption("1.5", "Arbre porte-fraise CAT avec trou taraudé"),
  bodyParts([
    { t: "➢   Fixation par queue : ", b: true },
    { t: "l'outil s'insère dans un dispositif de serrage via une queue cylindrique (standard) ou conique (centrage rigoureux)." },
  ]),
  insertImage("image15.jpeg", 260, 200),
  figCaption("1.6", "Fraise à queue cylindrique carbure"),
  insertImage("image16.png", 260, 200),
  figCaption("1.7", "Fraise à ébavurer queue conique"),
  bodyParts([
    { t: "➢   Porte-outil ER (retenu pour ce projet)", b: true, c: C.accent },
  ]),
  body(
    "Le système ER repose sur une pince élastique interchangeable enserrant la queue de l'outil sous l'action " +
    "d'un écrou de compression. C'est le standard retenu pour la CNC compacte."
  ),
  bulletBold("Précision", "liaison centrée, faux-rond minimisé"),
  bulletBold("Polyvalence", "une broche accueille plusieurs diamètres via changement de pince"),
  bulletBold("Rigidité", "maintien ferme pour l'usinage de précision sur aluminium"),
  insertImage("image17.jpeg", 260, 200),
  figCaption("1.8", "Porte-pince ER32 — Système de serrage à pinces ER"),

  // ── 1.2.5 ──
  subTitle("1.2.5", "Paramètres de coupe et conditions d'usinage"),
  body("Les paramètres cinématiques sont déterminés en fonction du couple outil/matière."),
  bodyParts([{ t: "➢   Vitesse de coupe (Vc) et vitesse de broche (N)", b: true }]),
  body(
    "La vitesse de coupe Vc (m/min) varie entre 30-100 m/min en ARS et jusqu'à 350 m/min en carbure pour l'aluminium. " +
    "La vitesse de broche est :"
  ),
  codeBlock("N = (Vc × 1000) / (π × D)     [N en tr/min ; Vc en m/min ; D en mm]"),
  bodyParts([{ t: "➢   Avance par dent (fz) et vitesse d'avance (Vf)", b: true }]),
  body("L'avance par dent fz vaut 0,1 à 0,4 mm/dent en fraisage standard. La vitesse d'avance :"),
  codeBlock("Vf = N × fz × Z     [Vf en mm/min ; Z = nombre de dents]"),
  bodyParts([{ t: "➢   Engagement de l'outil (ap et ae)", b: true }]),
  body(
    "La profondeur axiale ap (ADOC) et la largeur radiale ae (RDOC) définissent le volume de matière sollicité. " +
    "Ébauche : 30-50 % du diamètre ; Finition : 3-5 % pour un Ra optimal."
  ),

  // ── 1.3 ──
  secTitle("1.3", "Fondamentaux de la Commande Numérique par Calculateur (CNC)"),

  subTitle("1.3.1", "Historique et évolution"),
  body("L'évolution de la commande numérique se résume en six étapes clés :"),
  timeline("1949", "J.T. Parsons et le MIT — cartes perforées pour pales d'hélicoptère"),
  timeline("1952", "Première fraiseuse CN 3 axes (Cincinnati/MIT)"),
  timeline("1954", "CN industrielles câblées (Bendix, NUM 100) — rigides, non reprogrammables"),
  timeline("1972", "Transition NC → CNC — mini-calculateurs remplacent les logiques câblées"),
  timeline("1990", "Processeurs 32 bits — puissance de calcul décuplée"),
  timeline("2015+", "MCU hautes performances (ESP32) + RTOS → systèmes ouverts à bas coût"),

  // ── 1.3.2 ──
  subTitle("1.3.2", "Principe d'asservissement d'un système CNC"),
  body("Un système CNC repose sur trois unités coordonnées formant la chaîne de commande :"),
  gap(),
  ...tbl(
    ["Unité", "Fonction", "Action"],
    [
      ["DPU", "Lecture et analyse du G-Code", "Simulation, anti-collision, séquencement"],
      ["CLU", "Calculs cinématiques", "Cinématique inverse, rampes d'accélération, signaux Step/Dir"],
      ["Actionneurs", "Ordres → mouvements", "Drivers → moteurs → axes physiques + broche"],
    ],
    "Tableau 1.5 : Chaîne de commande — DPU → CLU → Actionneurs"
  ),
  gap(),
  bodyParts([{ t: "➢   Boucle ouverte : ", b: true }, { t: "impulsions sans retour de position. Simple mais sans correction d'erreur." }]),
  bodyParts([{ t: "➢   Boucle fermée : ", b: true }, { t: "encodeurs renseignent la CLU sur la position réelle. Correction en temps réel." }]),

  // ── 1.3.3 ──
  subTitle("1.3.3", "Architecture d'un système CNC 5 axes"),
  body(
    "Le pilotage 5 axes nécessite la synchronisation de trois translations (X, Y, Z) et deux rotations (A, C) " +
    "pour orienter l'outil perpendiculairement aux surfaces complexes. Cette technologie supprime les multiples " +
    "montages et est indispensable pour les pales de turbines, moules et prothèses médicales."
  ),

  // ── 1.3.4 ──
  subTitle("1.3.4", "Classification architecturale des machines CNC 5 axes"),
  body("Les machines 5 axes se classent en trois familles selon l'emplacement des axes rotatifs :"),
  gap(),
  ...tbl(
    ["Configuration", "Axes rotatifs sur", "Avantages", "Limites", "Application"],
    [
      ["Head-Head", "Tête broche", "Pièces grandes/lourdes", "Rigidité angulaire ↓", "Aéronautique"],
      ["Head-Table", "Tête + Table", "Compromis flex./stabilité", "Synchro complexe", "Usage général"],
      ["Table-Table ✓", "Table (Trunnion)", "Rigidité ↑, compacité", "Volume pièce limité", "CNC compactes"],
    ],
    "Tableau 1.6 : Comparatif des architectures CNC 5 axes"
  ),
  gap(),
  synthBox([
    "Architecture retenue : Table-Table (Trunnion)",
    "Compacité, rigidité globale élevée, précision optimale pour pièces aluminium de petite à moyenne taille."
  ]),

  // ── 1.3.5 ──
  subTitle("1.3.5", "Problématiques spécifiques et gestion des singularités"),
  body(
    "À A = 0°, l'axe C s'aligne avec la broche, provoquant une perte de degré de liberté (Gimbal Lock). " +
    "La solution implémentée repose sur une zone de garde (sin(θA) < ε) et un lissage de trajectoire par le firmware."
  ),

  // ── 1.3.6 ──
  subTitle("1.3.6", "Revue des firmwares et écosystèmes logiciels"),
  bodyParts([{ t: "➢   Chaîne numérique 5 axes", b: true }]),
  body(
    "Le flux suit trois étapes : CAO (modélisation 3D, SolidWorks/Fusion 360) → " +
    "FAO (parcours d'outils, usinage 3+2 ou continu 5 axes) → " +
    "Post-Processeur (traduction en coordonnées angulaires A/C et linéaires X/Y/Z pour le Trunnion)."
  ),
  bodyParts([{ t: "➢   Langage G-Code (ISO 6983)", b: true }]),
  body(
    "Chaque bloc contient des fonctions préparatoires (G), des coordonnées et des fonctions auxiliaires (M). " +
    "En 5 axes, G43.4 active le RTCP, compensant les rotations du berceau :"
  ),
  codeBlock("G43.4 H01"),
  codeBlock("G1 X120 Y30 Z-15 A20 C45 F2000"),
  codeBlock("M09"),
  bodyParts([{ t: "➢   Protocoles de communication", b: true }]),
  gap(),
  ...tbl(
    ["Protocole", "Latence", "Avantage", "Limite"],
    [
      ["USB-Serial", "Variable", "Fiable, standard", "Filaire, non déterministe"],
      ["WiFi UDP", "1-5 ms", "Sans fil, streaming G-Code", "Pas de garantie livraison"],
    ],
    "Tableau 1.7 : Protocoles de communication CNC"
  ),
  gap(),
  body("L'IHM de supervision est développée en Flutter (visualisation temps réel, multiplateforme PC/mobile)."),

  // ── 1.4 ──
  secTitle("1.4", "Conclusion"),
  body(
    "Cette étude bibliographique a présenté les fondements technologiques des machines CNC de fraisage : " +
    "procédé d'usinage, outils de coupe, paramètres, commande numérique, architectures 5 axes et chaîne logicielle. " +
    "Ces concepts constituent la base scientifique du système développé dans les chapitres suivants."
  ),
  gap(),
  synthBox([
    "Chapitre 1 — Synthèse :",
    "• Fraisage : enlèvement de matière par outil multi-arêtes, paramètres Vc, N, fz, Vf, ap, ae",
    "• Architecture retenue : Table-Table (Trunnion) — compacité + rigidité",
    "• Commande : ESP32 + FreeRTOS, Step/Dir, WiFi UDP",
    "• Chaîne numérique : CAO → FAO → Post-Processeur → G-Code → RTCP",
  ]),
];

// ═══════════════════════════════════════════════════
// DOCUMENT GENERATION
// ═══════════════════════════════════════════════════

const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: "Times New Roman", size: 24 },
        paragraph: { spacing: { line: 360 } },
      },
    },
  },
  sections: [{
    properties: {
      page: {
        margin: { top: 1440, bottom: 1440, left: 1728, right: 1440 },
      },
    },
    headers: {
      default: new Header({
        children: [new Paragraph({
          children: [
            new TextRun({ text: "Machine CNC 5 axes avec son logiciel de bord", font: "Calibri", size: 18, color: C.secondary, italics: true }),
            new TextRun({ text: "          Chapitre 1", font: "Calibri", size: 18, color: C.primary, bold: true }),
          ],
          border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: C.secondary } },
        })],
      }),
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({
          children: [new TextRun({ children: [PageNumber.CURRENT], font: "Calibri", size: 18 })],
          alignment: AlignmentType.CENTER,
        })],
      }),
    },
    children: ch1,
  }],
});

Packer.toBuffer(doc).then(buffer => {
  const out = "C:\\Users\\CITT Unipod\\Downloads\\PFE_Chapitre1_Optimise_V2.docx";
  fs.writeFileSync(out, buffer);
  console.log("OK:", out, "-", Math.round(buffer.length/1024), "Ko");
});
