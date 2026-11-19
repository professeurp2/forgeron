// Jalon S2 : le programme 5 axes rejoué dans le moteur de matière, comparé au dôme
// théorique. Lancer :  node test/js/dexel_5axes_test.js [programme.nc pas_mm]
const fs = require('fs');
const { DexelStock, machineToPiece } = require('../../web/js/dexel_stock.js');

let ok = true;
function chk(label, cond, detail = '') {
  ok = ok && !!cond;
  console.log(`  ${cond ? 'OK  ' : 'ECHEC'} ${label}${detail ? '  — ' + detail : ''}`);
}

function poses(gcode) {
  const D = parseFloat(/PIVOT A (\d+(?:\.\d+)?) MM/.exec(gcode)[1]);
  const pos = {};
  const out = [];
  for (const raw of gcode.split('\n')) {
    const line = raw.replace(/\([^)]*\)/g, '');
    if (!/^G[01]\b/.test(line)) continue;
    for (const m of line.matchAll(/([XYZAC])(-?[\d.]+)/g)) pos[m[1]] = parseFloat(m[2]);
    if (['X', 'Y', 'Z', 'A', 'C'].every((k) => k in pos)) {
      const tip = machineToPiece([pos.X, pos.Y, pos.Z], pos.A, pos.C, D);
      out.push([tip[0], tip[1], tip[2], pos.A, pos.C]);
    }
  }
  return { D, poses: out };
}

// Le dôme des tests : R=20, base carrée de 28 mm, sommet à Z=0, base 2 mm sous la surface.
const R = 20;
const surfaceZ = (x, y) => Math.sqrt(Math.max(R * R - x * x - y * y, 0)) - R;

function run(file, stepover, h) {
  const { D, poses: path } = poses(fs.readFileSync(file, 'utf-8'));
  const bottom = -(D - 8);
  const stock = new DexelStock({ shape: 'cuboid', size: [34, 34, -bottom], h });
  const tool = { radius: 3, type: 'ball' };
  const t0 = Date.now();
  for (let i = 1; i < path.length; i++) stock.sweepBlock(path[i - 1], path[i], tool, D);
  const ms = Date.now() - t0;

  // Écart de la matière restante à la surface, loin des bords de la pièce.
  const gaps = [];
  for (let y = -11; y <= 11; y += h) {
    for (let x = -11; x <= 11; x += h) {
      const top = stock.topAt(x, y);
      if (top) gaps.push(top.z - surfaceZ(top.x, top.y));
    }
  }
  gaps.sort((a, b) => a - b);
  const q = (f) => gaps[Math.floor(f * (gaps.length - 1))];
  // Crête théorique d'une boule sur sphère convexe, entre deux passes : s²/8 × (1/ρ + 1/R).
  const cusp = (stepover * stepover / 8) * (1 / 3 + 1 / R);
  return { blocks: path.length, ms, min: gaps[0], med: q(0.5), p95: q(0.95), max: gaps[gaps.length - 1], cusp, h };
}

const file = process.argv[2] || 'test/fixtures/dome5_continu.nc';
const stepover = parseFloat(process.argv[3] || '2');
const h = parseFloat(process.argv[4] || '0.25');
const r = run(file, stepover, h);
const f3 = (v) => v.toFixed(3);
console.log(`${file} : ${r.blocks} blocs en ${r.ms} ms, grille ${r.h} mm`);
console.log(`écart matière - dôme : min ${f3(r.min)}, médiane ${f3(r.med)}, 95 % ${f3(r.p95)}, max ${f3(r.max)} mm ; crête théorique ${f3(r.cusp)} mm`);
chk('aucune entaille au-delà de la résolution', r.min > -r.h, `${f3(r.min)} mm`);
// La crête se mesure entre passes : on tolère la grille en plus.
chk('la surface est atteinte : écart borné par la crête + la grille', r.p95 < r.cusp + r.h,
  `${f3(r.p95)} mm pour ${f3(r.cusp + r.h)} mm`);
console.log(ok ? '\nTOUT PASSE' : '\nECHEC');
process.exit(ok ? 0 : 1);
