const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, ExternalHyperlink,
  BorderStyle, AlignmentType,
} = require('docx');
const fs = require('fs');

const FORGE = 'C8551A';
const INK = '1F2733';
const MUT = '6B7686';

const rule = () => new Paragraph({
  border: { bottom: { color: 'E4E8EE', space: 1, style: BorderStyle.SINGLE, size: 6 } },
  spacing: { after: 120 },
});

const h = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_2,
  spacing: { before: 220, after: 80 },
  children: [new TextRun({ text, bold: true, color: FORGE, size: 26 })],
});

const p = (children, opts = {}) => new Paragraph({
  spacing: { after: 100 },
  children: Array.isArray(children) ? children : [new TextRun({ text: children, size: 21, color: INK })],
  ...opts,
});

const link = (label, url) => new ExternalHyperlink({
  link: url,
  children: [new TextRun({ text: label, style: 'Hyperlink', size: 21 })],
});

const bullet = (children) => new Paragraph({
  bullet: { level: 0 },
  spacing: { after: 60 },
  children: Array.isArray(children) ? children : [new TextRun({ text: children, size: 21, color: INK })],
});

const label = (t) => new TextRun({ text: t, bold: true, size: 21, color: INK });
const txt = (t) => new TextRun({ text: t, size: 21, color: INK });
const note = (t) => new TextRun({ text: t, italics: true, size: 19, color: MUT });

const doc = new Document({
  creator: 'Lamine SACKO',
  title: 'Forgeron — Supporting Evidence',
  sections: [{
    properties: { page: { margin: { top: 1000, bottom: 1000, left: 1100, right: 1100 } } },
    children: [
      new Paragraph({
        spacing: { after: 40 },
        children: [new TextRun({ text: 'FORGERON', bold: true, size: 40, color: INK })],
      }),
      new Paragraph({
        spacing: { after: 160 },
        children: [new TextRun({ text: 'Supporting Evidence — METI-funded UniPods AI Programme (timbuktoo / UNDP)', size: 22, color: MUT })],
      }),
      rule(),

      p([label('Applicant: '), txt('Lamine SACKO — Founder & Engineer')]),
      p([label('Email: '), txt('sackolamine994@gmail.com')]),
      p([label('Country: '), txt('Mali')]),
      p([label('Product: '), txt('Forgeron — an AI-piloted 5-axis CNC controller that turns a low-cost ESP32 into an industrial-grade machine controller operated in plain language.')]),

      h('1. Live code / working application'),
      p([txt('Full open-source codebase (Flutter app, FluidNC integration, AI agent). The app is functional and demonstrable on real hardware and in simulation mode.')]),
      bullet([label('GitHub repository: '), link('https://github.com/professeurp2/forgeron', 'https://github.com/professeurp2/forgeron')]),

      h('2. Demo video'),
      p([txt('Short walkthrough of the app driving the 5-axis machine, including the AI agent controlling the machine by plain-language commands.')]),
      bullet([label('Video link: '), link('https://youtube.com/shorts/wCH-2Z9WxEw', 'https://youtube.com/shorts/wCH-2Z9WxEw')]),

      h('3. Physical machine (hardware proof)'),
      p([txt('A fully built, working physical 5-axis CNC machine: ESP32 DevKit V1 + FluidNC v3.7 + 5× TB6600 drivers, X/Y/Z linear + A/C rotary (Trunnion) axes. See attached photos and the one-pager.')]),
      bullet([note('[ Photos of the real machine attached as separate image files ]')]),

      h('4. AI capability (technical evidence)'),
      p([txt('The core AI is an agentic assistant: an LLM using function calling, exposed to 12 safe machine-control tools, with a permissions layer and a pre-motion trajectory validator that prevents collisions. Key source files:')]),
      bullet([label('AI agent (Gemini function calling): '), txt('lib/application/services/ai_agent_service.dart, ai_agent_tools.dart')]),
      bullet([label('Lookahead safety validation: '), txt('lib/core/utils/trajectory_validator.dart')]),
      bullet([label('Connectivity resilience (cellular routing): '), txt('lib/core/net/cellular_http_client.dart')]),

      h('5. Market interest / partner'),
      p([txt('Initial conversation held with the management of Kouratechnique regarding testing and adoption of Forgeron in a real machining environment.')]),
      bullet([note('[ If a support letter from Kouratechnique is obtained, attach it here as evidence ]')]),

      h('6. One-pager (pitch summary)'),
      p([txt('A one-page summary of the problem, solution, AI, market and traction is attached as Forgeron_OnePager.pdf.')]),

      rule(),
      new Paragraph({
        spacing: { before: 120 },
        children: [note('All information provided in this application is accurate and true. — Lamine SACKO')],
      }),
    ],
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync('/tmp/claude-0/-home-user-forgeron/f115b2cf-c02c-5ae4-8f73-96461eacf843/scratchpad/Forgeron_Supporting_Evidence.docx', buf);
  console.log('written docx', buf.length, 'bytes');
});
