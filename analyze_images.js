const JSZip = require('jszip');
const fs = require('fs');

async function analyzeRels() {
  const data = fs.readFileSync('C:\\Users\\CITT Unipod\\Downloads\\SACKO_LAMINE_PFE_10_05_2026.docx');
  const zip = await JSZip.loadAsync(data);
  
  const relsXml = await zip.file('word/_rels/document.xml.rels').async('string');
  const docXml = await zip.file('word/document.xml').async('string');
  
  // Build rId -> image mapping
  const relMap = {};
  const relRegex = /Id="(rId\d+)"[^>]*Target="(media\/[^"]+)"/g;
  let m;
  while ((m = relRegex.exec(relsXml)) !== null) {
    relMap[m[1]] = m[2];
  }
  
  console.log("=== rId -> Image mapping ===");
  for (const [k,v] of Object.entries(relMap)) {
    console.log(k, "->", v);
  }
  
  // Find images in document with surrounding text context
  // Split document into paragraphs
  const paragraphs = docXml.split(/<\/w:p>/);
  let lastText = "";
  let imgIndex = 0;
  
  console.log("\n=== Images in document order with context ===");
  for (const para of paragraphs) {
    // Extract text from this paragraph
    const textMatches = para.match(/<w:t[^>]*>([^<]*)<\/w:t>/g);
    if (textMatches) {
      const texts = textMatches.map(t => t.replace(/<[^>]+>/g, ''));
      lastText = texts.join(' ').trim();
    }
    
    // Check if this paragraph contains an image
    const imgMatch = para.match(/r:embed="(rId\d+)"/);
    if (imgMatch && relMap[imgMatch[1]]) {
      imgIndex++;
      const imgFile = relMap[imgMatch[1]];
      const contextShort = lastText.substring(0, 80);
      console.log(`[${imgIndex}] ${imgFile} | Context: "${contextShort}"`);
    }
  }
}

analyzeRels();
