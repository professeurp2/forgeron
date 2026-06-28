const fs = require('fs');
const files = [
    'scratch/Section_3.1_3.2_Formatted.md',
    'scratch/Section_3.3.1_Formatted.md',
    'scratch/Section_3.3.2_Formatted.md',
    'scratch/Section_3.3.3_Formatted.md',
    'scratch/Section_3.5_Formatted.md',
    'scratch/Section_3.6_Formatted.md',
    'scratch/Section_3.7_Formatted.md'
];

let finalContent = '';
for (const file of files) {
    if (fs.existsSync(file)) {
        finalContent += fs.readFileSync(file, 'utf8') + '\n\n---\n\n';
    }
}

fs.writeFileSync('scratch/CHAPITRE_3_Autres_Parties_Mise_En_Forme.md', finalContent, 'utf8');
console.log('Merged successfully with UTF-8 encoding');