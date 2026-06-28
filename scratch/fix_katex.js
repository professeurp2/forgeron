const fs = require('fs');
let content = fs.readFileSync('CHAPITRE_3_Autres_Parties.md', 'utf8');

// Fix 1: Escape % inside math blocks
content = content.replace(/\$([\s\S]*?)\$/g, (match, p1) => {
    return '$' + p1.replace(/%/g, '\\%') + '$';
});

// Fix 2: Check for specific problematic line mentioned by user
// e.g., ... (soit 45,5 %)}$ -> ... (soit 45,5 \%)}$
// Wait, the error said: expected '}' at end of input: … (soit 45,5 %)}
// If it was at the end of the input, maybe the $ was missing?
// Let's check the grep again.
// L595: Rendement direct : $\eta = \frac{\tan \lambda}{\tan(\lambda + \varphi)} = \frac{\tan(5,02^\circ)}{\tan(5,02^\circ + 5,91^\circ)} = 0,455 \text{ (soit 45,5 %)}$

fs.writeFileSync('CHAPITRE_3_Autres_Parties.md', content, 'utf8');
console.log('Fixed KaTeX percent escaping');