const fs = require('fs');
const fileContent = fs.readFileSync('c:\\Users\\CITT Unipod\\Documents\\ENI\\Mon PFE\\forgeron\\scratch\\pfe_text_extracted.txt', 'utf8');
const lines = fileContent.split('\n');

for (let i = 0; i < lines.length; i++) {
  const line = lines[i].trim();
  if (line.match(/^\d+(\.\d+)*\s+[A-ZÀ-Ÿ]/) || line.match(/CHAPITRE/i) || line.match(/simulation/i)) {
    if (i > 3500 && i < 7600) {
      console.log(`Line ${i + 1}: ${line}`);
    }
  }
}
