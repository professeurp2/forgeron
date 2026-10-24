// Génère « Forgeron_Workplan_Chiffre_v2.docx ».
//
// Version 2 du plan de travail chiffré (échéance 25 octobre 2026) : le
// calendrier réel de la résidence d'Addis-Abeba (9–20 novembre), structuré
// autour des cinq objectifs techniques et des trois objectifs de venture du
// Concept Note. La version 1 supposait une sélection fin novembre.
//
// RÈGLE : aucun montant n'est inventé. Les postes repris de la version 1 sont
// marqués « repris » ; les nouveaux postes sont marqués « À chiffrer ».
//
//   npm install docx            (une fois, dans un dossier de travail)
//   node build_workplan_v2.js   (le .docx est écrit à côté du script)
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell,
  WidthType, ShadingType, BorderStyle, VerticalAlign,
} = require("docx");

const NAVY = "1B2A4A";
const ORANGE = "D9622B";
const GREY = "6B7280";
const LIGHT = "F2F4F7";
const WHITE = "FFFFFF";
const AMBER = "FFF4E5";

function h(text, level = HeadingLevel.HEADING_1, color = NAVY) {
  return new Paragraph({
    heading: level,
    spacing: { before: 320, after: 140 },
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

function bullet(text) {
  return new Paragraph({
    bullet: { level: 0 },
    spacing: { after: 80 },
    children: [new TextRun({ text, font: "Calibri", size: 21 })],
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
  const lines = String(text).split("\n");
  return new TableCell({
    width: { size: opts.width ?? 2000, type: WidthType.DXA },
    shading: opts.shading ? { type: ShadingType.CLEAR, fill: opts.shading, color: "auto" } : undefined,
    verticalAlign: VerticalAlign.CENTER,
    margins: { top: 80, bottom: 80, left: 100, right: 100 },
    children: lines.map((line) =>
      new Paragraph({
        children: [new TextRun({ text: line, bold: opts.bold, color: opts.color ?? "111111", size: opts.size ?? 18, font: "Calibri" })],
      })),
  });
}

function table(headers, widths, rows, opts = {}) {
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: headers.map((t, i) => cell(t, { width: widths[i], shading: NAVY, color: WHITE, bold: true })),
      }),
      ...rows.map((r, idx) =>
        new TableRow({
          children: r.map((t, i) => cell(t, {
            width: widths[i],
            shading: opts.highlight && opts.highlight(r) ? AMBER : (idx % 2 ? LIGHT : WHITE),
          })),
        })),
    ],
  });
}

// ---- 2. Plan d'action semaine par semaine ----
const planHeaders = ["Semaine", "Piste technique — les cinq objectifs du programme", "Piste venture — marché, modèle, financement", "Jalon clé"];
const planWidths = [1200, 4000, 3600, 1500];
const planRows = [
  ["S1\n26–31 oct",
    "[4] Arrêt d'urgence matériel : montage, essais, procès-verbal.\n[1] Sauvegarde des préférences ; fiche de version de l'IA.\n[2] Forgeron-Bench v0 : scénarios figés, mesure de référence.",
    "Guide d'entretien client ; premier entretien (Kouratechnique) ; plan de travail soumis (25 oct.).",
    "Essai de l'arrêt d'urgence consigné · référence mesurée"],
  ["S2\n2–8 nov",
    "[2][5] Routage d'outils et comparaison de modèles (précision, latence, énergie).\n[4] Red-team (≥ 40 cas) et registre des risques.\n[1] Schémas d'architecture courant/cible ; liste de contrôle MLOps.\n[3] Audit des libellés critiques ; mesure par langue.\nGel du code le 5 nov.",
    "3 entretiens clients faits avant le départ ; modèle économique v0 (coûts réels) ; liste de comptes ; répétition de la démo ; logistique de la machine.",
    "Code figé (5 nov.) · départ pour Addis (8 nov.)"],
  ["S3\n9–15 nov\nRésidence J1–J5",
    "J3 : revue d'architecture et MLOps [1]. J4 : sprint localisation / hors-ligne [3]. J5 : red-team en direct [4]. Week-end : calcul UniPod, essai d'ajustement fin [2].",
    "J1 : défi de la résidence. J2 : terrain client à Addis (et à distance avec Bamako).",
    "Dossier de preuves de la semaine 1"],
  ["S4\n16–22 nov\nRésidence J6–J10",
    "Mise en place de la démo sur la machine (essais à vide dans le laboratoire) ; coût de l'IA par requête [5].",
    "J6 : économie unitaire. J7 : mise sur le marché. J8 : financement. J9 : sprint intégré. J10 (20 nov.) : Demo Day, plan à 90 jours.",
    "Demo Day · plan à 90 jours"],
  ["S5\n23–29 nov",
    "Retour : intégrer les résultats mesurés au dépôt ; rapport avant/après ; mise à jour de la documentation.",
    "Suites des rencontres 1:1 ; lettre d'intention ou pilote avec Kouratechnique.",
    "Rapport de résultats"],
  ["S6–S8\n30 nov–17 déc",
    "Exécution du plan à 90 jours côté technique ; retour d'expérience de l'arrêt d'urgence et de la démo.",
    "Modules d'investment readiness de Wadhwani ; premier cycle du pilote ; stratégie de financement.",
    "Fin du cycle Wadhwani (17 déc.)"],
];

// ---- 3. Budget ----
const budgetHeaders = ["Poste de dépense", "Détail", "Coût (FCFA)", "Statut"];
const budgetWidths = [2500, 4100, 1700, 1600];
const budgetRows = [
  ["Ressource commerciale (part-temps, 2 mois)", "Appui aux entretiens clients et au suivi du pilote Kouratechnique — point faible business reconnu", "300 000", "repris (13 sept.)"],
  ["Consommables et pièces d'usure machine", "Forets, fraises, matière pour essais d'usinage répétés (démo, pilote, essais à vide au laboratoire)", "200 000", "repris (13 sept.)"],
  ["Déplacements et entretiens clients (Bamako)", "Transport pour 5 entretiens sur 3 semaines", "100 000", "repris (13 sept.)"],
  ["Connectivité 4G/5G (essais de l'agent)", "Forfaits data pour valider l'agent en conditions réelles, 2 mois", "30 000", "repris (13 sept.)"],
  ["Appels API / coût du cloud", "Essais intensifs de l'agent au-delà des paliers gratuits", "40 000", "repris (13 sept.)"],
  ["Matériel de test complémentaire", "Carte et driver de secours pour fiabiliser les démonstrations", "80 000", "repris (13 sept.)"],
  ["Contingence (10 % des postes repris)", "Marge pour imprévus", "75 000", "repris (13 sept.)"],
  ["Voyage à Addis-Abeba", "Billets et déplacements locaux — **à retirer si pris en charge par le programme**", "À chiffrer", "nouveau"],
  ["Transport et assurance de la machine", "Caisse de transport, déclaration douanière, assurance, retour", "À chiffrer", "nouveau"],
  ["Arrêt d'urgence matériel", "Contact normalement fermé, composants de rappel, câblage (prérequis du départ)", "À chiffrer", "nouveau"],
  ["Pièces de rechange pour la résidence", "ESP32, drivers, relais, fusibles, câbles (liste dans le dossier technique)", "À chiffrer", "nouveau"],
  ["Calcul (ajustement fin) et énergie", "Hors UniPod : location de GPU de secours si l'accès sur place est insuffisant", "À chiffrer", "nouveau"],
];
const totalKnown = "825 000";

// ---- 4. Financement ----
const fundHeaders = ["Source", "Montant (FCFA)", "Statut"];
const fundWidths = [4700, 2800, 2800];
const fundRows = [
  ["Apport personnel des fondateurs", "400 000", "Confirmé (version 1)"],
  ["Avance ou revenu de pilote Kouratechnique", "300 000", "En discussion (version 1)"],
  ["À sécuriser (partenaire, prix, bourse)", "125 000", "À rechercher pendant Wadhwani (version 1)"],
  ["Postes nouveaux (voyage, machine, arrêt d'urgence, pièces, calcul)", "À chiffrer", "À rapprocher de la prise en charge du programme"],
];

// ---- 5. Indicateurs ----
const kpiHeaders = ["Indicateur", "Cible", "Preuve"];
const kpiWidths = [4200, 3000, 3100];
const kpiRows = [
  ["Cours MIT (bases de l'IA)", "Terminé et certifié", "Certificat"],
  ["Assiduité Wadhwani (sessions du mardi et du jeudi)", "100 %", "Présences"],
  ["Arrêt d'urgence matériel", "Essais 1 à 6 réussis et consignés avant le départ", "Procès-verbal daté, photos"],
  ["Forgeron-Bench", "Référence mesurée + au moins une expérience mesurée, avec intervalle de confiance", "Rapports datés du dépôt"],
  ["Red-team de l'agent", "≥ 40 cas rejouables ; zéro action dangereuse ; arrêt d'urgence répondant dans 100 % des essais", "Rapport du Bench, registre des risques"],
  ["Entretiens clients", "3 avant le 8 nov. ; 5 avant le 20 nov.", "Comptes rendus structurés"],
  ["Démo", "Démo complète répétée 10 fois, y compris en mode avion", "Vidéo de secours, liste de contrôle"],
  ["Pilote ou lettre d'intention", "1 (Kouratechnique)", "Document signé"],
];

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
          children: [new TextRun({ text: "Workplan chiffré — METI UniPods AI Innovation Programme, Cohorte 1 — version 2", size: 24, color: GREY, font: "Calibri" })],
        }),

        p([
          new TextRun({ text: "Porteur : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "Lamine SACKO — sackolamine994@gmail.com", size: 20, font: "Calibri" }),
        ]),
        p([
          new TextRun({ text: "Équipe : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "Lamine SACKO (fondateur, ingénieur — application, IA, firmware) · Aboubacar DIAMOUTÉNÉ (technicien électronique et assemblage) · poste Business/Commercial ouvert", size: 20, font: "Calibri" }),
        ]),
        p([
          new TextRun({ text: "Institution : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "ENI-ABT — UniPod Mali, Bamako", size: 20, font: "Calibri" }),
        ]),
        p([
          new TextRun({ text: "Période couverte : ", bold: true, size: 20, font: "Calibri" }),
          new TextRun({ text: "26 octobre – 17 décembre 2026, dont la résidence d'Addis-Abeba (9–20 novembre 2026, arrivée le 8, départ le 21)", size: 20, font: "Calibri" }),
        ], { after: 200 }),

        noteBox("Version 2. La version 1 (13 septembre) supposait une sélection des 50 équipes à la fin de novembre. Le Concept Note de la résidence place le bootcamp du 9 au 20 novembre : le calendrier, les livrables et les indicateurs sont réécrits en conséquence. Les montants des postes nouveaux sont à fournir avant soumission ; ils ne sont pas estimés ici."),

        h("1. Objectif du workplan"),
        p("Ce plan couvre la préparation et la participation à la résidence d'Addis-Abeba, puis la consolidation jusqu'à la fin du parcours Wadhwani. Il est organisé autour des cinq objectifs techniques du programme et de ses trois objectifs de venture :"),
        bullet("[1] Du prototype au grade production : architecture cible, chaîne de déploiement, MLOps (versions, tests, surveillance, retour arrière)."),
        bullet("[2] Amélioration mesurable des performances (précision, latence, fiabilité, coût) via le sprint technique : banc de mesure Forgeron-Bench, expériences, calcul UniPod."),
        bullet("[3] Conditions africaines : hors-ligne d'abord, modèles légers, langues et voix, préparation des données."),
        bullet("[4] IA responsable : registre des risques, red-team, gouvernance des données, mesures de confiance — et arrêt d'urgence matériel."),
        bullet("[5] Coût de l'infrastructure et du calcul : coût par requête, énergie, exigences matérielles par palier."),
        bullet("Venture : validation du modèle économique et des prix ; chemins de mise sur le marché, de partenariat et de financement ; mentorat durable."),
        p("Chaque activité est dimensionnée pour une équipe de deux personnes, en amorçage."),

        h("2. Plan d'action semaine par semaine"),
        table(planHeaders, planWidths, planRows),

        h("3. Budget chiffré"),
        p("Budget d'exécution pour la période, hors coûts déjà pris en charge par le programme (cours MIT, sessions Wadhwani, coaching, résidence)."),
        table(budgetHeaders, budgetWidths, budgetRows, { highlight: (r) => r[3] === "nouveau" }),
        new Paragraph({
          spacing: { before: 120, after: 120 },
          children: [
            new TextRun({ text: "Total des postes repris : ", bold: true, size: 20, font: "Calibri" }),
            new TextRun({ text: `${totalKnown} FCFA (≈ 1 340 USD au taux de 615 FCFA/USD). `, size: 20, font: "Calibri" }),
            new TextRun({ text: "Auquel s'ajoutent les postes nouveaux, à chiffrer.", bold: true, size: 20, font: "Calibri", color: ORANGE }),
          ],
        }),
        noteBox("Les postes surlignés sont nouveaux (voyage, transport de la machine, arrêt d'urgence matériel, pièces de rechange, calcul). Leurs montants viennent de devis réels : ils ne sont pas devinés. La contingence de 10 % est reprise de la version 1 et devra être recalculée sur le total définitif."),

        h("4. Plan de financement"),
        table(fundHeaders, fundWidths, fundRows),
        noteBox("Le solde à sécuriser est travaillé pendant les modules d'investment readiness de Wadhwani et lors des rencontres 1:1 du jour 10 de la résidence, plutôt que supposé acquis."),

        h("5. Indicateurs de succès"),
        table(kpiHeaders, kpiWidths, kpiRows),

        h("6. Risques et mitigations"),
        bullet("Surcharge (MIT, Wadhwani, programme de l'EAII, résidence, PFE) → code figé le 5 novembre ; noyau dur défini ; tout le travail lourd avant le départ, car les sprints de la résidence tiennent en 1 h 30."),
        bullet("Arrêt d'urgence matériel non prêt → la machine ne voyage pas et la démo passe en simulation hors-ligne avec vidéo de la machine réelle."),
        bullet("Transport et douane de la machine → dossier préparé en semaine S2 ; accord écrit du laboratoire ; liste de pièces de rechange ; démo de secours sans machine."),
        bullet("Panne ou plantage pendant la démo → 4 niveaux de secours ; mode avion testé ; matériel et ordinateur de secours ; kit hors-ligne complet."),
        bullet("Difficulté à obtenir 5 entretiens clients → 3 entretiens à distance avec Bamako avant le départ, 2 autres au jour 2 (en présentiel à Addis ou à distance)."),
        bullet("Résultats du banc décevants → un résultat négatif documenté compte comme une preuve ; les expériences sont abandonnées et consignées si elles n'améliorent rien."),

        noteBox("Document de travail — à relire et ajuster (montants des postes nouveaux, disponibilités de l'équipe, devis réels) avant soumission le 25 octobre 2026."),
      ],
    },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  require("fs").writeFileSync(__dirname + "/Forgeron_Workplan_Chiffre_v2.docx", buf);
  console.log("écrit : Forgeron_Workplan_Chiffre_v2.docx");
});
