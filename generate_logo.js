const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const svg = `
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <!-- Gradient Definition -->
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#2d3436;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#000000;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="gradForge" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FF8C00;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#FF4500;stop-opacity:1" />
    </linearGradient>
  </defs>

  <!-- Hexagonal Shield -->
  <path d="M256 20 L460 138 V374 L256 492 L52 374 V138 Z" fill="url(#grad1)" />
  <path d="M256 40 L440 148 V364 L256 472 L72 364 V148 Z" fill="none" stroke="#FF8C00" stroke-width="4" opacity="0.5" />

  <!-- Stylized 'F' / Anvil / CNC Tool -->
  <!-- The vertical part of F as a tool/drill -->
  <rect x="210" y="120" width="30" height="240" fill="#DFE6E9" />
  <path d="M210 360 L225 390 L240 360 Z" fill="#FF8C00" /> <!-- Tool tip -->

  <!-- Top bar of F (Anvil top) -->
  <path d="M210 120 H360 C380 120 380 150 360 150 H240 V180 H330 C350 180 350 210 330 210 H240 V360 H210 V120Z" fill="#DFE6E9" />
  
  <!-- "Heat" Spark / Toolpath -->
  <path d="M240 210 L380 210 L410 240 L380 270 L240 270" fill="none" stroke="url(#gradForge)" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" />
  <circle cx="410" cy="240" r="8" fill="#FFD700">
    <animate attributeName="opacity" values="1;0.5;1" dur="2s" repeatCount="indefinite" />
  </circle>

  <!-- Text -->
  <text x="256" y="445" font-family="Segoe UI, Arial, sans-serif" font-size="52" font-weight="900" fill="#FFFFFF" text-anchor="middle" letter-spacing="4">FORGERON</text>
  <text x="256" y="465" font-family="Segoe UI, Arial, sans-serif" font-size="14" font-weight="bold" fill="#FF8C00" text-anchor="middle" letter-spacing="8">PRECISION CNC</text>
</svg>
`;

async function generateIcons() {
    const b = Buffer.from(svg);
    
    const targets = [
        { path: 'web/favicon.png', size: 32 },
        { path: 'web/icons/Icon-192.png', size: 192 },
        { path: 'web/icons/Icon-512.png', size: 512 },
        { path: 'web/icons/Icon-maskable-192.png', size: 192 },
        { path: 'web/icons/Icon-maskable-512.png', size: 512 },
        { path: 'assets/logo.png', size: 512 },
        { path: 'logo_full.png', size: 1024 }
    ];

    for (const target of targets) {
        const dir = path.dirname(target.path);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        
        console.log(`Generating ${target.path}...`);
        await sharp(b)
            .resize(target.size, target.size)
            .png()
            .toFile(target.path);
    }
    
    console.log('All icons generated successfully.');
}

generateIcons().catch(err => console.error(err));
