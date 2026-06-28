const fs = require('fs');
const { PDFParse } = require('pdf-parse');

const pdfPath = 'C:\\Users\\CITT Unipod\\Downloads\\SACKO_LAMINE_PFE_16_05_2026.pdf';
const dataBuffer = fs.readFileSync(pdfPath);

async function main() {
    const parser = new PDFParse(new Uint8Array(dataBuffer));
    await parser.load();
    const result = await parser.getText();
    const fullText = result.text;
    
    const pages = fullText.split(/-- \d+ of \d+ --\n/);
    
    // Page index is 0-based. So page 45 is pages[44].
    // We need pages 45 to 106, and 164 to 216.
    
    let textPart1 = [];
    for(let i = 44; i < 106; i++) {
        if(pages[i]) textPart1.push(pages[i]);
    }
    
    let textPart2 = [];
    for(let i = 163; i < 216; i++) {
        if(pages[i]) textPart2.push(pages[i]);
    }
    
    const cleanText = (lines) => {
        return lines.map(page => {
            let pLines = page.split('\n');
            // Remove header 'Machine CNC 5 axes avec son logiciel de bord' and page number
            pLines = pLines.filter(l => !l.includes('Machine CNC 5 axes avec son logiciel de bord') && !l.trim().match(/^\d+$/));
            return pLines.join('\n').trim();
        }).join('\n\n');
    };
    
    const md1 = cleanText(textPart1);
    const md2 = cleanText(textPart2);
    
    const finalMd = "# CHAPITRE 3 : MODÉLISATION ET DIMENSIONNEMENT\n\n" + 
                    "## Parties 3.1, 3.2, 3.3\n\n" + md1 + 
                    "\n\n## Parties 3.5, 3.6, 3.7\n\n" + md2;
                    
    fs.writeFileSync('CHAPITRE_3_Autres_Parties.md', finalMd, 'utf8');
    console.log('Saved to CHAPITRE_3_Autres_Parties.md');
}

main().catch(err => console.error(err));