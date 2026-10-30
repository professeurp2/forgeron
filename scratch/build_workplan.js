const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell,
  WidthType, ShadingType, BorderStyle, AlignmentType, VerticalAlign, PageOrientation,
} = require("docx");

const NAVY = "1B2A4A";
const ORANGE = "D9622B";
const GREY = "6B7280";
const LIGHT = "F2F4F7";
const WHITE = "FFFFFF";

function h(text, level = HeadingLevel.HEADING_1, color = NAVY, spacingBefore = 320, spacingAfter = 140) {
  return new Paragraph({
    heading: level,
    spacing: { before: spacingBefore, after: spacingAfter },
    children: [new TextRun({ text, bold: true, color, font: "Calibri" })],
  });
}

function p(text, opts = {}) {
  return new Paragraph({
    spacing: { after: opts.after ?? 120 },
    children: Array.isArray(text)
      ? text
      : [new TextRun({ text, font: "Calibri", size: opts.size ?? 21, bold: opts.bold, italics: opts.italics, color: opts.color })],
  });
}

function bullet(text, opts = {}) {
  return new Paragraph({
    bullet: { level: 0 },
    spacing: { after: 80 },
    children: [new TextRun({ text, font: "Calibri", size: 21, bold: opts.bold, color: opts.color })],
  });
}

function noteBox(text) {
  return new Paragraph({
    spacing: { before: 80, after: 200 },
    border: { left: { style: BorderStyle.SINGLE, size: 18, color: ORANGE, space: 8 } },
    children: [new TextRun({ text, italics: true, size: 19, color: GREY, font: "Calibri" })],
  });
}

function cell(text, opts = {}) {
  return new TableCell({
    width: { size: opts.width ?? 2000, type: WidthType.DXA },
    shading: opts.shading ? { type: ShadingType.CLEAR, fill: opts.shading, color: "auto" } : undefined,
    verticalAlign: VerticalAlign.CENTER,
    margins: { top: 80, bottom: 80, left: 100, right: 100 },
    children: [
      new Paragraph({
        children: [
          new TextRun({
            text,
            bold: opts.bold,
            color: opts.color ?? "111111",
            size: opts.size ?? 18,
            font: "Calibri",
          }),
        ],
      }),
    ],
  });
}

// ---- Table 1: Plan d'action semaine par semaine ----
const planHeaders = ["Semaine", "Piste technique — Institut IA (Ethiopian AI Institute)", "Piste business — Wadhwani Ignite", "Jalon clé"];
const planWidths = [1300, 3600, 3600, 1800];
const planRows = [
  ["S1\n26–31 oct", "Inscription & démarrage du module IA avancée ; définition du plan de durcissement de l'agent (cas limites lookahead, journal de décisions)", "Finalisation du guide d'entretien client ; 1er entretien (Kouratechnique)", "Workplan soumis (25 oct)"],
  ["S2\n2–8 nov", "Tests de résistance de l'agent : 20+ scénarios de commandes ambiguës/dangereuses, 0 collision tolérée", "2–3 entretiens clients supplémentaires (ateliers Bamako + ENI-ABT)", "3 entretiens clients cumulés"],
  ["S3\n9–15 nov", "Mesure de latence agent sous 4G/5G réelle ; réglage du repli multi-modèles", "Synthèse persona & segments (Module 2 Wadhwani) à partir des entretiens", "Persona validé sur du réel"],
  ["S4\n16–22 nov", "Mise à jour de la vidéo démo (nouveaux cas d'usage agent) ; devoirs Institut IA rendus", "Ébauche go-to-market (Module 3) ; préparation pitch court si sélection bootcamp", "Dossier technique à jour"],
  ["S5\n23–29 nov", "Résultat sélection des 50 (semaine du 23 nov) ; si retenu, prép. logistique Addis-Abeba", "Poursuite Wadhwani (sessions hebdo) quel que soit le résultat", "Décision bootcamp connue"],
  ["S6–S8\n30 nov–17 déc", "Si non retenu pour nov. : consolidation technique en vue du bootcamp de février 2027", "Modules investment readiness ; 2e cycle de traction (pilote Kouratechnique)", "Fin cycle Wadhwani (17 déc)"],
];

function buildPlanTable() {
  return new Table({
    width: { size: 10300, type: WidthType.DXA },
    columnWidths: planWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: planHeaders.map((t, i) => cell(t, { width: planWidths[i], shading: NAVY, color: WHITE, bold: true, size: 18 })),
      }),
      ...planRows.map((r, idx) =>
        new TableRow({
          children: r.map((t, i) => cell(t, { width: planWidths[i], shading: idx % 2 ? LIGHT : WHITE, size: 18 })),
        })
      ),
    ],
  });
}

// ---- Table 2: Budget chiffré ----
const budgetHeaders = ["Poste de dépense", "Détail", "Coût (FCFA)", "≈ USD"];
const budgetWidths = [2600, 4300, 1700, 1700];
const budgetRows = [
  ["Ressource commerciale/business (part-temps, 2 mois)", "Appui pour les entretiens clients et le suivi du pilote Kouratechnique — poste identifié comme prioritaire (point faible business)", "300 000", "≈ 490"],
  ["Consommables & pièces d'usure machine", "Forets, fraises, matière première pour tests d'usinage répétés pendant la phase de démo/pilote", "200 000", "≈ 325"],
  ["Déplacements & entretiens clients", "Transport pour 5 entretiens (ateliers de Bamako + ENI-ABT) sur 3 semaines", "100 000", "≈ 165"],
  ["Connectivité 4G/5G (tests agent IA)", "Forfaits data pour valider le routage cellulaire de l'agent en conditions réelles, 2 mois", "30 000", "≈ 50"],
  ["Appels API / coûts cloud LLM", "Volume de tests intensifs de l'agent (au-delà des paliers gratuits) pendant la phase de durcissement", "40 000", "≈ 65"],
  ["Matériel de test complémentaire", "Carte/driver de secours pour fiabiliser les démonstrations en direct", "80 000", "≈ 130"],
  ["Contingence (10 %)", "Marge pour imprévus", "75 000", "≈ 120"],
];
const totalFcfa = "825 000";
const totalUsd = "≈ 1 340";

function buildBudgetTable() {
  return new Table({
    width: { size: 10300, type: WidthType.DXA },
    columnWidths: budgetWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: budgetHeaders.map((t, i) => cell(t, { width: budgetWidths[i], shading: NAVY, color: WHITE, bold: true, size: 18 })),
      }),
      ...budgetRows.map((r, idx) =>
        new TableRow({
          children: r.map((t, i) => cell(t, { width: budgetWidths[i], shading: idx % 2 ? LIGHT : WHITE, size: 18 })),
        })
      ),
      new TableRow({
        children: [
          cell("TOTAL", { width: budgetWidths[0], shading: ORANGE, color: WHITE, bold: true, size: 18 }),
          cell("", { width: budgetWidths[1], shading: ORANGE }),
          cell(totalFcfa, { width: budgetWidths[2], shading: ORANGE, color: WHITE, bold: true, size: 18 }),
          cell(totalUsd, { width: budgetWidths[3], shading: ORANGE, color: WHITE, bold: true, size: 18 }),
        ],
      }),
    ],
  });
}

// ---- Table 3: Financement ----
const fundHeaders = ["Source", "Montant (FCFA)", "Statut"];
const fundWidths = [4700, 2800, 2800];
const fundRows = [
  ["Apport personnel des fondateurs", "400 000", "Confirmé"],
  ["Revenu / avance pilote Kouratechnique", "300 000", "En discussion"],
  ["À sécuriser (partenaire / prix / bourse)", "125 000", "À rechercher pendant Wadhwani"],
];
function buildFundTable() {
  return new Table({
    width: { size: 10300, type: WidthType.DXA },
    columnWidths: fundWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: fundHeaders.map((t, i) => cell(t, { width: fundWidths[i], shading: NAVY, color: WHITE, bold: true, size: 18 })),
      }),
      ...fundRows.map((r, idx) =>
        new TableRow({
          children: r.map((t, i) => cell(t, { width: fundWidths[i], shading: idx % 2 ? LIGHT : WHITE, size: 18 })),
        })
      ),
    ],
  });
}

// ---- KPI table ----
const kpiHeaders = ["Indicateur", "Cible au 23 novembre"];
const kpiWidths = [5700, 4600];
const kpiRows = [
  ["Cours MIT (foundational AI)", "Terminé et certifié"],
  ["Assiduité Wadhwani (sessions live)", "100 % des sessions mardi/jeudi"],
  ["Entretiens clients réalisés", "5 (Kouratechnique + 3 ateliers + 1 institution technique)"],
  ["Tests de sécurité agent (validation lookahead)", "20+ scénarios, 0 collision"],
  ["Pilote payant / lettre d'intention", "1 (Kouratechnique)"],
  ["Devoirs Institut IA rendus", "100 % à temps"],
];
function buildKpiTable() {
  return new Table({
    width: { size: 10300, type: WidthType.DXA },
    columnWidths: kpiWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: kpiHeaders.map((t, i) => cell(t, { width: kpiWidths[i], shading: NAVY, color: WHITE, bold: true, size: 18 })),
      }),
      ...kpiRows.map((r, idx) =>
        new TableRow({
          children: r.map((t, i) => cell(t, { width: kpiWidths[i], shading: idx % 2 ? LIGHT : WHITE, size: 18 })),
        })
      ),
    ],
  });
}

const doc = new Document({
  sections: [
    {
      properties: {
        page: {
          size: { width: 11907, height: 16840 }, // A4
          margin: { top: 900, bottom: 900, left: 900, right: 900 },
        },
      },
      children: [
        new Paragraph({
          spacing: { after: 40 },
          children: [new TextRun({ text: "FORGERON", bold: true, size: 40, color: NAVY, font: "Calibri" })],
        }),
        new Paragraph({
          spacing: { after: 240 },
          border: { bottom: { style: BorderStyle.SINGLE, size: 12, color: ORANGE, space: 6 } },
          children: [new TextRun({ text: "Workplan chiffré — METI UniPods AI Innovation Programme, Cohort 1", size: 24, color: GREY, font: "Calibri" })],
        }),

        p([
          new TextRun({ text: "Porteur : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "Lamine SACKO — ", size: 20, font: "Calibri" }),
          new TextRun({ text: "sackolamine994@gmail.com", size: 20, font: "Calibri", color: GREY }),
        ]),
        p([
          new TextRun({ text: "Équipe : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "Lamine SACKO (fondateur, ingénieur — app / IA / firmware) · Aboubacar DIAMOUTÉNÉ (technicien électronique & assemblage) · poste Business/Commercial ouvert", size: 20, font: "Calibri" }),
        ]),
        p([
          new TextRun({ text: "Institution : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "ENI-ABT — UniPod Mali, Bamako", size: 20, font: "Calibri" }),
        ]),
        p([
          new TextRun({ text: "Période couverte : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "26 octobre – 17 décembre 2026 (phase Ethiopian AI Institute + fin du parcours Wadhwani Ignite)", size: 20, font: "Calibri" }),
        ], { after: 200 }),

        h("1. Objectif du workplan"),
        p("Ce plan couvre la période qui suit la sélection en Cohorte 1 (244 retenus sur 670) et qui précède la sélection des 50 solutions invitées au bootcamp d'Addis-Abeba (semaine du 23 novembre 2026). Il avance sur deux pistes en parallèle, conformément à la structure du programme :"),
        bullet("Piste technique — durcir la couche IA agentique de Forgeron dans le cadre du programme de l'Ethiopian AI Institute (26 oct.–23 nov.)."),
        bullet("Piste business — transformer le prototype validé en venture investissable via le parcours Wadhwani Ignite (customer discovery, business model, go-to-market, investment readiness), en s'appuyant sur le pilote Kouratechnique."),
        p("Chaque activité est chiffrée pour rester réaliste sur les ressources d'une équipe de 2 personnes, en amorçage."),

        h("2. Plan d'action semaine par semaine"),
        buildPlanTable(),

        h("3. Budget chiffré"),
        p("Budget d'exécution pour la période, hors coûts déjà pris en charge par le programme (cours MIT, sessions Wadhwani, coaching)."),
        buildBudgetTable(),
        noteBox("Hypothèse de change utilisée : 1 USD ≈ 615 FCFA. Chiffres à ajuster avant soumission avec les coûts réels constatés (devis fournisseurs, forfaits opérateurs locaux)."),

        h("4. Plan de financement"),
        buildFundTable(),
        noteBox("Le solde à sécuriser (125 000 FCFA) est explicitement travaillé pendant les modules \"investment readiness\" de Wadhwani plutôt que supposé acquis."),

        h("5. Indicateurs de succès (au 23 novembre)"),
        buildKpiTable(),

        h("6. Risques & mitigations"),
        bullet("Retard sur les devoirs Institut IA (double charge avec Wadhwani) → bloquer 2 créneaux fixes/semaine dédiés, dès S1."),
        bullet("Difficulté à obtenir 5 entretiens clients en 3 semaines → mobiliser Kouratechnique comme point d'entrée vers d'autres ateliers de son réseau."),
        bullet("Dépassement du budget consommables (usure imprévue) → contingence de 10 % déjà intégrée au budget."),
        bullet("Non-sélection dans les 50 de novembre → le plan bascule sans rupture vers le bootcamp de février 2027 (S6–S8 déjà orientées en ce sens)."),

        noteBox("Document de travail — à relire et ajuster (montants, dates de disponibilité de l'équipe, devis réels) avant soumission le 25 octobre 2026."),
      ],
    },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  require("fs").writeFileSync(__dirname + "/Forgeron_Workplan_Chiffre.docx", buf);
  console.log("written");
});
