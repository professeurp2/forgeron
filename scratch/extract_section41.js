const fs = require('fs');
const { PDFParse } = require('pdf-parse');

const pdfPath = 'C:\\Users\\CITT Unipod\\Downloads\\SACKO_LAMINE_PFE_16_05_2026.pdf';
const dataBuffer = fs.readFileSync(pdfPath);

async function main() {
    const parser = new PDFParse(new Uint8Array(dataBuffer));
    await parser.load();
    const result = await parser.getText();
    const text = result.text;
    
    // Get one of the linear axis dimensioning sections to see the writing style
    const patterns = [
        { name: 'Section 3.3.1 (Axe X)', pattern: /3\.3\.1\s+Dimensionnement/i },
        { name: 'Cas nominal', pattern: /Cas nominal/i },
        { name: 'Cas extreme', pattern: /Cas extr/i },
        { name: 'Verification fatigue', pattern: /fatigue/i },
        { name: 'Haigh', pattern: /Haigh/i },
        { name: 'Goodman', pattern: /Goodman/i },
    ];
    
    for (const s of patterns) {
        const m = text.match(s.pattern);
        if (m) {
            console.log(`\n=== ${s.name} at index ${m.index} ===`);
            console.log(text.substring(m.index, m.index + 800));
            console.log('\n--- END ---');
        } else {
            console.log(`\n${s.name}: NOT FOUND`);
        }
    }
    
    // Get the dimensioning style of axe X
    const axeX = text.match(/3\.3\.1[\s\S]*?Dimensionnement de l.*axe X/i);
    if (axeX) {
        console.log('\n\n========== AXE X FULL SECTION (first 5000 chars) ==========');
        console.log(text.substring(axeX.index, axeX.index + 5000));
    }
}

main().catch(err => console.error('Error:', err.message));
