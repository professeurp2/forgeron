// Jalon S3 : le brut usiné comparé au modèle. Des défauts volontaires doivent être
// retrouvés, avec leur valeur et au bon endroit.
// Lancer :  node test/js/part_model_test.js
const fs = require('fs');
const { DexelStock, machineToPiece } = require('../../web/js/dexel_stock.js');
const { PartModel, compareStock } = require('../../web/js/part_model.js');

let ok = true;
function chk(label, cond, detail = '') {
  ok = ok && !!cond;
  console.log(`  ${cond ? 'OK  ' : 'ECHEC'} ${label}${detail ? '  — ' + detail : ''}`);
}

// Même dôme que test_continuous5 : R=20, base 28 × 28, sommet à Z=0.
function domeModel(n = 90, half = 14, R = 20) {
  const axis = Array.from({ length: n }, (_, i) => -half + (2 * half * i) / (n - 1));
  const raw = (x, y) => Math.sqrt(Math.max(R * R - x * x - y * y, 0));
  let top = -Infinity;
  for (const y of axis) for (const x of axis) top = Math.max(top, raw(x, y));
  let low = Infinity;
  for (const y of axis) for (const x of axis) low = Math.min(low, raw(x, y) - top);
  const bottom = low - 2;
  const v = [];
  const push = (a, b, c) => v.push(...a, ...b, ...c);
  const P = (x, y) => [x, y, raw(x, y) - top];
  for (let j = 0; j < n - 1; j++) {
    for (let i = 0; i < n - 1; i++) {
      const a = P(axis[i], axis[j]);
      const b = P(axis[i + 1], axis[j]);
      const c = P(axis[i + 1], axis[j + 1]);
      const d = P(axis[i], axis[j + 1]);
      push(a, b, c);
      push(a, c, d);
    }
  }
  const B = (x, y) => [x, y, bottom];
  // Parois et fond : le modèle est fermé.
  for (let i = 0; i < n - 1; i++) {
    const [p, q] = [axis[i], axis[i + 1]];
    push(P(p, -half), B(p, -half), B(q, -half)); push(P(p, -half), B(q, -half), P(q, -half));
    push(P(q, half), B(q, half), B(p, half)); push(P(q, half), B(p, half), P(p, half));
    push(P(-half, q), B(-half, q), B(-half, p)); push(P(-half, q), B(-half, p), P(-half, p));
    push(P(half, p), B(half, p), B(half, q)); push(P(half, p), B(half, q), P(half, q));
  }
  for (let j = 0; j < n - 1; j++) {
    for (let i = 0; i < n - 1; i++) {
      const [a, b, c, d] = [B(axis[i], axis[j]), B(axis[i + 1], axis[j]),
        B(axis[i + 1], axis[j + 1]), B(axis[i], axis[j + 1])];
      push(a, c, b);
      push(a, d, c);
    }
  }
  return { model: new PartModel(v, null), bottom };
}

function program(text) {
  const D = parseFloat(/PIVOT A (\d+(?:\.\d+)?) MM/.exec(text)[1]);
  const finishAt = text.indexOf('ETAPE 2');
  const pos = {};
  const out = [];
  let offset = 0;
  for (const raw of text.split('\n')) {
    offset += raw.length + 1;
    const line = raw.replace(/\([^)]*\)/g, '');
    if (!/^G[01]\b/.test(line)) continue;
    for (const m of line.matchAll(/([XYZAC])(-?[\d.]+)/g)) pos[m[1]] = parseFloat(m[2]);
    if (['X', 'Y', 'Z', 'A', 'C'].every((k) => k in pos)) {
      const tip = machineToPiece([pos.X, pos.Y, pos.Z], pos.A, pos.C, D);
      out.push({ pose: [tip[0], tip[1], tip[2], pos.A, pos.C], cut: /^G1/.test(line), finish: offset > finishAt });
    }
  }
  return { D, path: out };
}

function cut(path, D, H, h) {
  const stock = new DexelStock({ shape: 'cuboid', size: [34, 34, H], h });
  const tool = { radius: 3, type: 'ball' };
  for (let i = 1; i < path.length; i++) stock.sweepBlock(path[i - 1].pose, path[i].pose, tool, D);
  return stock;
}

const near = (a, b, r) => Math.hypot(a[0] - b[0], a[1] - b[1]) < r;
const fmt = (p) => (p ? p.map((x) => x.toFixed(1)).join(', ') : '-');

console.log('distance signée');
const { model, bottom } = domeModel();
{
  chk('le modèle est fermé', model.closed);
  chk('le modèle est dans le repère des programmes', model.inProgramFrame());
  chk('sous la surface = dedans', model.signed(0, 0, -5, 3) < 0);
  chk('au-dessus = dehors', model.signed(0, 0, 1, 3) > 0);
  chk('distance exacte au sommet', Math.abs(model.signed(0, 0, 1, 3) - 1) < 0.01, model.signed(0, 0, 1, 3).toFixed(3));
  chk('sous le fond = dehors', model.signed(0, 0, bottom - 1, 3) > 0);
  const moved = new PartModel([50, 50, 5, 60, 50, 5, 50, 60, 5], null);
  chk('un modèle ailleurs est signalé', !moved.inProgramFrame());
}

const text = fs.readFileSync('test/fixtures/dome5_continu.nc', 'utf-8');
const { D, path } = program(text);
const H = D - 8;
const h = 0.25;

console.log('programme sain');
{
  const r = compareStock(cut(path, D, H, h), model, { tol: 0.1 });
  chk('aucune pénétration', r.penetrationMaxMm < 0.1, `${r.penetrationMaxMm.toFixed(3)} mm`);
  chk('il reste la crête, pas plus, sur le dessus', r.points.conforme > 0, JSON.stringify(r.points));
}

console.log('modèle ouvert : on ne devine pas');
{
  // Un dessus sans parois ni fond, comme un scan troué.
  const v = [-10, -10, 0, 10, -10, 0, 10, 10, 0, -10, -10, 0, 10, 10, 0, -10, 10, 0];
  const open = new PartModel(v, null);
  chk('il est reconnu ouvert', !open.closed);
  chk('la distance reste exacte et sans signe', Math.abs(open.signed(0, 0, -2, 3) - 2) < 1e-9);
  const stock = new DexelStock({ shape: 'cuboid', size: [20, 20, 5], h: 0.5 });
  const r = compareStock(stock, open, { tol: 0.1 });
  chk('la pénétration est dite non mesurable, pas nulle', r.penetrationMaxMm === null);
}

console.log('défauts volontaires de 0,5 mm');
{
  const hole = [6, 4];
  const bump = [-6, -4];
  const faulty = path.map((p) => {
    if (!p.finish || !p.cut) return p;
    const pose = p.pose.slice();
    if (near(pose, hole, 3)) pose[2] -= 0.5;
    if (near(pose, bump, 3)) pose[2] += 0.5;
    return { ...p, pose };
  });
  const r = compareStock(cut(faulty, D, H, h), model, { tol: 0.1 });
  chk('la pénétration est trouvée', r.penetrationMaxMm > 0.3 && r.penetrationMaxMm < 0.6,
    `${r.penetrationMaxMm.toFixed(3)} mm`);
  chk('au bon endroit', r.penetrationAu && near(r.penetrationAu, hole, 3.5), fmt(r.penetrationAu));

  // Là où on a laissé de la matière : l'écart local dépasse la crête du programme sain.
  const stock = cut(faulty, D, H, h);
  let worst = 0;
  for (let y = bump[1] - 1; y <= bump[1] + 1; y += h) {
    for (let x = bump[0] - 1; x <= bump[0] + 1; x += h) {
      const t = stock.topAt(x, y);
      worst = Math.max(worst, model.signed(t.x, t.y, t.z, 3));
    }
  }
  chk('le manque de coupe est trouvé', worst > 0.3 && worst < 0.9, `${worst.toFixed(3)} mm`);
}

console.log(ok ? '\nTOUT PASSE' : '\nECHEC');
process.exit(ok ? 0 : 1);
