const fs = require('fs');
let content = fs.readFileSync('CHAPITRE_3_Autres_Parties.md', 'utf8');

// 1. Unescape any existing double backslashes before % to avoid accumulation
content = content.replace(/\\\\%/g, '%');
// 2. Unescape any single backslashes before %
content = content.replace(/\\%/g, '%');

// 3. Escape all % inside math blocks correctly with ONE backslash
content = content.replace(/\$([\s\S]*?)\$/g, (match, p1) => {
    // We want the resulting text in the file to be \%
    // In JS string literal, that's "\\%"
    return '$' + p1.replace(/%/g, '\\%') + '$';
});

fs.writeFileSync('CHAPITRE_3_Autres_Parties.md', content, 'utf8');
console.log('Normalized KaTeX percent escaping to single backslash');