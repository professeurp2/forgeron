const fs = require('fs');
const fullText = fs.readFileSync('pfe_full_16_05.txt', 'utf8');

function getPages(start, end) {
    let result = '';
    for (let i = start; i <= end; i++) {
        const regex = new RegExp(`=== PAGE ${i} ===\n([\\s\\S]*?)(?==== PAGE ${i+1} ===|$)`);
        const match = fullText.match(regex);
        if (match) {
            result += match[1].trim() + '\n\n';
        }
    }
    return result;
}

// 3.1 & 3.2
fs.writeFileSync('scratch/raw_3_1_3_2.txt', getPages(45, 61), 'utf8');
// 3.3.1
fs.writeFileSync('scratch/raw_3_3_1.txt', getPages(62, 77), 'utf8');
// 3.3.2
fs.writeFileSync('scratch/raw_3_3_2.txt', getPages(78, 92), 'utf8');
// 3.3.3
fs.writeFileSync('scratch/raw_3_3_3.txt', getPages(93, 106), 'utf8');
// 3.5
fs.writeFileSync('scratch/raw_3_5.txt', getPages(164, 187), 'utf8');
// 3.6
fs.writeFileSync('scratch/raw_3_6.txt', getPages(188, 213), 'utf8');
// 3.7
fs.writeFileSync('scratch/raw_3_7.txt', getPages(214, 216), 'utf8');

console.log('Raw text parts saved to scratch/');