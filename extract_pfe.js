const fs = require('fs');
const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.mjs');

async function extract() {
  const data = new Uint8Array(fs.readFileSync('C:\\Users\\CITT Unipod\\Downloads\\SACKO_LAMINE_PFE_06_05_2026.pdf'));
  const doc = await pdfjsLib.getDocument({ data }).promise;
  let text = '';
  for (let i = 1; i <= doc.numPages; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    const pageText = content.items.map(item => item.str).join(' ');
    text += `=== PAGE ${i} ===\n${pageText}\n`;
  }
  fs.writeFileSync('pfe_full.txt', text, 'utf8');
  console.log(`Extracted ${doc.numPages} pages`);
}
extract();
