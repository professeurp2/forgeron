// Moteur de matière : volumes comparés à des résultats connus par le calcul.
// Lancer :  node test/js/dexel_stock_test.js
const { DexelStock } = require('../../web/js/dexel_stock.js');

let ok = true;
function chk(label, cond, detail = '') {
  ok = ok && !!cond;
  console.log(`  ${cond ? 'OK  ' : 'ECHEC'} ${label}${detail ? '  — ' + detail : ''}`);
}
const pct = (got, want) => (100 * Math.abs(got - want)) / want;
const removed = (s) => s.initialVolume - s.volume();
const H = 0.25;

console.log('brut initial');
{
  const box = new DexelStock({ shape: 'cuboid', size: [40, 30, 20], h: H });
  chk('volume du pavé', pct(box.initialVolume, 24000) < 1, box.initialVolume.toFixed(1));
  const cyl = new DexelStock({ shape: 'cylinder', size: [40, 40, 20], h: H });
  const want = Math.PI * 400 * 20;
  chk('volume du cylindre', pct(cyl.initialVolume, want) < 1, cyl.initialVolume.toFixed(1));
}

console.log('fraise plate');
{
  // Rainure : Ø6, longueur 20 + deux demi-disques, profondeur 5.
  const s = new DexelStock({ shape: 'cuboid', size: [40, 30, 20], h: H });
  s.sweep([-10, 0, 15], [10, 0, 15], { radius: 3, type: 'flat' });
  const want = (20 * 6 + Math.PI * 9) * 5;
  chk('rainure', pct(removed(s), want) < 1, `${removed(s).toFixed(1)} pour ${want.toFixed(1)}`);

  // Poche : 20 × 20 × 4, balayée à 4 mm, coins arrondis Ø6 retirés du volume.
  const p = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  for (let y = -7; y <= 7.001; y += 4) p.sweep([-7, y, 16], [7, y, 16], { radius: 3, type: 'flat' });
  p.sweep([-7, 7, 16], [7, 7, 16], { radius: 3, type: 'flat' });
  p.sweep([-7, -7, 16], [-7, 7, 16], { radius: 3, type: 'flat' });
  p.sweep([7, -7, 16], [7, 7, 16], { radius: 3, type: 'flat' });
  const pocket = (400 - (4 - Math.PI) * 9) * 4;
  chk('poche connue à moins de 1 %', pct(removed(p), pocket) < 1,
    `${removed(p).toFixed(1)} pour ${pocket.toFixed(1)}`);

  // Plongée pure.
  const d = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  d.sweep([0, 0, 25], [0, 0, 12], { radius: 3, type: 'flat' });
  const hole = Math.PI * 9 * 8;
  chk('perçage plat', pct(removed(d), hole) < 1, removed(d).toFixed(1));
}

console.log('passe en pente : rien sous l\'outil au-delà de la passe');
{
  const s = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  s.sweep([0, 0, 25], [5, 0, 15], { radius: 3, type: 'flat' });
  const end = s.topAt(7.5, 0);
  chk('après le bout bas, fond à la hauteur du bout', Math.abs(end.z - (15 - 20)) < 1e-6, end.z.toFixed(3));
  const start = s.topAt(-2.5, 0);
  chk('derrière le bout haut, rien n\'est coupé', start.z === 0, start.z.toFixed(3));
  const ramp = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  ramp.sweep([-15, 0, 23], [15, 0, 13], { radius: 3, type: 'flat' });
  const mid = ramp.topAt(0, 0);
  const expected = 23 - (10 * (mid.x + 15)) / 30 - 20;
  chk('au milieu, le fond suit la pente', Math.abs(mid.z - expected) < 1e-6, mid.z.toFixed(3));

  // Micro-mouvement à direction quelconque : ne doit pas creuser.
  const m = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  m.sweep([0, 0, 15], [0, 0, 15], { radius: 3, type: 'flat' });
  const v0 = m.volume();
  m.sweep([0, 0, 15], [0.0005, 0, 15.0009], { radius: 3, type: 'flat' });
  chk('un micro-mouvement ne change presque rien', Math.abs(m.volume() - v0) < 2, (m.volume() - v0).toFixed(2));
}

console.log('fraise boule');
{
  // Plongée de 6 mm : cylindre de 3 mm + demi-sphère.
  const s = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  s.sweep([0, 0, 25], [0, 0, 14], { radius: 3, type: 'ball' });
  const want = Math.PI * 9 * 3 + (2 / 3) * Math.PI * 27;
  chk('plongée', pct(removed(s), want) < 1, `${removed(s).toFixed(1)} pour ${want.toFixed(1)}`);

  // Passe droite à pleine profondeur de bille.
  const r = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  r.sweep([-10, 0, 17], [10, 0, 17], { radius: 3, type: 'ball' });
  const groove = 20 * (Math.PI * 9) / 2 + (2 / 3) * Math.PI * 27;
  chk('rainure ronde', pct(removed(r), groove) < 1, `${removed(r).toFixed(1)} pour ${groove.toFixed(1)}`);

  // Une passe en pente ne doit pas dépendre du découpage en blocs.
  const whole = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  whole.sweep([-15, 0, 19], [15, 0, 14], { radius: 3, type: 'ball' });
  const cut = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  for (let i = 0; i < 40; i++) {
    const a = i / 40;
    const b = (i + 1) / 40;
    cut.sweep([-15 + 30 * a, 0, 19 - 5 * a], [-15 + 30 * b, 0, 19 - 5 * b], { radius: 3, type: 'ball' });
  }
  chk('un bloc ou quarante, même matière', pct(removed(cut), removed(whole)) < 0.5,
    `${removed(whole).toFixed(1)} / ${removed(cut).toFixed(1)}`);
}

console.log('outil incliné');
{
  // Sphère seule : le volume enlevé ne dépend pas de l'axe de la queue si elle
  // reste hors de la matière. Pointe posée de sorte que la bille soit sous le dessus.
  const axis = [0, -Math.sin(Math.PI / 6), Math.cos(Math.PI / 6)];
  const s = new DexelStock({ shape: 'cuboid', size: [40, 40, 20], h: H });
  const centre = [0, 0, 20];
  const tip = [centre[0] - 3 * axis[0], centre[1] - 3 * axis[1], centre[2] - 3 * axis[2]];
  s.sweep(tip, tip, { radius: 3, type: 'ball' }, axis);
  // Bille à moitié dans le brut, plus la part de queue sous le plan du dessus : nulle ici.
  const half = (2 / 3) * Math.PI * 27;
  chk('demi-sphère inclinée', pct(removed(s), half) < 2, `${removed(s).toFixed(1)} pour ${half.toFixed(1)}`);
}

console.log('hors brut, remise à zéro, maillage');
{
  const s = new DexelStock({ shape: 'cuboid', size: [20, 20, 10], h: 0.5 });
  s.sweep([50, 50, 5], [60, 50, 5], { radius: 3, type: 'ball' });
  chk('une passe hors du brut ne coupe rien', removed(s) === 0);
  s.sweep([0, 0, 15], [0, 0, 4], { radius: 3, type: 'flat' });
  chk('la passe enlève de la matière', removed(s) > 0);

  // Maillage fermé et orienté : le volume par divergence retrouve celui des droites.
  let signed = 0;
  let triangles = 0;
  const total = s.chunks[0] * s.chunks[1] * s.chunks[2];
  for (let id = 0; id < total; id++) {
    const { positions: p, indices: ix } = s.extractChunk(id);
    triangles += ix.length / 3;
    for (let t = 0; t < ix.length; t += 3) {
      const [a, b, c] = [ix[t] * 3, ix[t + 1] * 3, ix[t + 2] * 3];
      signed += (p[a] * (p[b + 1] * p[c + 2] - p[b + 2] * p[c + 1])
        - p[a + 1] * (p[b] * p[c + 2] - p[b + 2] * p[c])
        + p[a + 2] * (p[b] * p[c + 1] - p[b + 1] * p[c])) / 6;
    }
  }
  chk('le maillage existe', triangles > 100, `${triangles} triangles`);
  chk('normales vers l\'extérieur', signed > 0, signed.toFixed(1));
  chk('maillage fermé : même volume à 2 % près', pct(signed, s.volume()) < 2,
    `${signed.toFixed(1)} pour ${s.volume().toFixed(1)}`);

  s.reset();
  chk('reset rend le brut', removed(s) === 0);
}

console.log('performance (indicatif)');
{
  const s = new DexelStock({ shape: 'cuboid', size: [40, 40, 25], h: 40 / 128 });
  const start = Date.now();
  let moves = 0;
  for (let z = 24; z > 15; z -= 1) {
    for (let y = -18; y <= 18; y += 2) {
      s.sweep([-18, y, z], [18, y, z], { radius: 3, type: 'ball' });
      moves++;
    }
  }
  const cutMs = Date.now() - start;
  const t2 = Date.now();
  const total = s.chunks[0] * s.chunks[1] * s.chunks[2];
  for (let id = 0; id < total; id++) s.extractChunk(id);
  console.log(`  ${moves} passes de 36 mm en ${cutMs} ms ; maillage complet en ${Date.now() - t2} ms`);
}

console.log(ok ? '\nTOUT PASSE' : '\nECHEC');
process.exit(ok ? 0 : 1);
