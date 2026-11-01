// Brut tri-dexel : la matière est décrite par des segments le long de droites
// parallèles à X, Y et Z, passant par les noeuds d'une grille de pas h.
//
// Repère du brut : X/Y centrés, Z de 0 (dessous) à H (dessus).
//
// Une passe outil se soustrait droite par droite, par intersection exacte : coût
// proportionnel à la surface balayée, pas à la longueur du bloc. Une droite ne
// garde que les bords de matière, ce qui donne aussi la position exacte de la
// surface sur chaque arête de la grille, d'où le maillage (Surface Nets).
(function (root) {
  'use strict';

  const CHUNK = 16;
  const EPS = 1e-9;

  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const add = (a, b, k) => [a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k];
  const cross = (a, b) => [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];

  class DexelStock {
    constructor({ shape = 'cuboid', size, h }) {
      this.shape = shape;
      this.size = size;
      this.h = h;
      // Une maille de marge : le maillage se referme sur les faces du brut. Le décalage
      // d'une demi-maille évite qu'une droite tombe pile sur une face et compte double.
      this.origin = [-size[0] / 2 - 1.5 * h, -size[1] / 2 - 1.5 * h, -1.5 * h];
      this.n = [
        Math.ceil(size[0] / h) + 4,
        Math.ceil(size[1] / h) + 4,
        Math.ceil(size[2] / h) + 4,
      ];
      this.chunks = [
        Math.ceil(this.n[0] / CHUNK),
        Math.ceil(this.n[1] / CHUNK),
        Math.ceil(this.n[2] / CHUNK),
      ];
      this.reset();
    }

    coord(axis, index) {
      return this.origin[axis] + index * this.h;
    }

    // Droites parallèles à [axis], indexées par les deux autres axes (u < v).
    _others(axis) {
      return axis === 0 ? [1, 2] : axis === 1 ? [0, 2] : [0, 1];
    }

    _lineIndex(axis, iu, iv) {
      const [u] = this._others(axis);
      return iu + iv * this.n[u];
    }

    _initialInterval(axis, pu, pv) {
      const [sx, sy, sz] = this.size;
      if (this.shape === 'cylinder') {
        const rx = sx / 2;
        const ry = sy / 2;
        if (axis === 2) {
          return (pu * pu) / (rx * rx) + (pv * pv) / (ry * ry) <= 1 ? [0, sz] : null;
        }
        if (pv < 0 || pv > sz) return null;
        // Corde de l'ellipse : pu est l'autre coordonnée horizontale.
        const [ra, rb] = axis === 0 ? [rx, ry] : [ry, rx];
        const q = 1 - (pu * pu) / (rb * rb);
        if (q < 0) return null;
        const half = ra * Math.sqrt(q);
        return [-half, half];
      }
      if (axis === 2) {
        return Math.abs(pu) <= sx / 2 && Math.abs(pv) <= sy / 2 ? [0, sz] : null;
      }
      if (pv < 0 || pv > sz) return null;
      if (axis === 0) return Math.abs(pu) <= sy / 2 ? [-sx / 2, sx / 2] : null;
      return Math.abs(pu) <= sx / 2 ? [-sy / 2, sy / 2] : null;
    }

    reset() {
      this.lines = [];
      for (let axis = 0; axis < 3; axis++) {
        const [u, v] = this._others(axis);
        const arr = new Array(this.n[u] * this.n[v]);
        for (let iv = 0; iv < this.n[v]; iv++) {
          for (let iu = 0; iu < this.n[u]; iu++) {
            arr[iu + iv * this.n[u]] = this._initialInterval(
              axis, this.coord(u, iu), this.coord(v, iv));
          }
        }
        this.lines.push(arr);
      }
      this.dirty = new Set();
      for (let i = 0; i < this.chunks[0] * this.chunks[1] * this.chunks[2]; i++) {
        this.dirty.add(i);
      }
      this.initialVolume = this.volume();
    }

    // Volume par les droites Z : somme des longueurs × surface d'une maille.
    volume() {
      let total = 0;
      for (const line of this.lines[2]) {
        if (!line) continue;
        for (let i = 0; i < line.length; i += 2) total += line[i + 1] - line[i];
      }
      return total * this.h * this.h;
    }

    _markDirty(axis, iu, iv, t0, t1) {
      const [u, v] = this._others(axis);
      const a0 = Math.floor((t0 - this.origin[axis]) / this.h) - 1;
      const a1 = Math.ceil((t1 - this.origin[axis]) / this.h) + 1;
      const c = this.chunks;
      const lo = [0, 0, 0];
      const hi = [0, 0, 0];
      lo[u] = Math.max(0, Math.floor((iu - 1) / CHUNK));
      hi[u] = Math.min(c[u] - 1, Math.floor((iu + 1) / CHUNK));
      lo[v] = Math.max(0, Math.floor((iv - 1) / CHUNK));
      hi[v] = Math.min(c[v] - 1, Math.floor((iv + 1) / CHUNK));
      lo[axis] = Math.max(0, Math.floor(a0 / CHUNK));
      hi[axis] = Math.min(c[axis] - 1, Math.floor(a1 / CHUNK));
      for (let z = lo[2]; z <= hi[2]; z++) {
        for (let y = lo[1]; y <= hi[1]; y++) {
          for (let x = lo[0]; x <= hi[0]; x++) {
            this.dirty.add(x + c[0] * (y + c[1] * z));
          }
        }
      }
    }

    _subtract(axis, iu, iv, t0, t1) {
      const idx = this._lineIndex(axis, iu, iv);
      const line = this.lines[axis][idx];
      if (!line || !(t1 > t0)) return;
      let touched = false;
      for (let i = 0; i < line.length; i += 2) {
        if (line[i] < t1 && line[i + 1] > t0) touched = true;
      }
      if (!touched) return;
      const out = [];
      for (let i = 0; i < line.length; i += 2) {
        const a = line[i];
        const b = line[i + 1];
        if (t0 > a + EPS && t0 < b) out.push(a, Math.min(t0, b));
        else if (t0 >= b) out.push(a, b);
        if (t1 < b - EPS && t1 > a) out.push(Math.max(t1, a), b);
        else if (t1 <= a) out.push(a, b);
      }
      this.lines[axis][idx] = out.length ? out : null;
      this._markDirty(axis, iu, iv, t0, t1);
    }

    // Soustrait le balayage de l'outil, pointe de [tip0] à [tip1], axe [axis]
    // constant (vers le haut, unitaire). tool = { radius, type: 'ball' | 'flat', length }.
    sweep(tip0, tip1, tool, axisDir) {
      const u = axisDir || [0, 0, 1];
      const r = tool.radius;
      const L = tool.length || 60;
      const lift = tool.type === 'ball' ? r : 0;
      const c0 = add(tip0, u, lift);
      const c1 = add(tip1, u, lift);
      const top0 = add(tip0, u, L);
      const top1 = add(tip1, u, L);

      const prism = _prism(c0, c1, u, r);
      for (let axis = 0; axis < 3; axis++) {
        const [a, b] = this._others(axis);
        const pts = [c0, c1, top0, top1];
        const lo = (k) => Math.min(...pts.map((p) => p[k])) - r;
        const hi = (k) => Math.max(...pts.map((p) => p[k])) + r;
        const ia0 = Math.max(0, Math.ceil((lo(a) - this.origin[a]) / this.h));
        const ia1 = Math.min(this.n[a] - 1, Math.floor((hi(a) - this.origin[a]) / this.h));
        const ib0 = Math.max(0, Math.ceil((lo(b) - this.origin[b]) / this.h));
        const ib1 = Math.min(this.n[b] - 1, Math.floor((hi(b) - this.origin[b]) / this.h));
        const o = [0, 0, 0];
        const d = [0, 0, 0];
        d[axis] = 1;
        for (let ib = ib0; ib <= ib1; ib++) {
          o[b] = this.coord(b, ib);
          for (let ia = ia0; ia <= ia1; ia++) {
            if (!this.lines[axis][ia + ib * this.n[a]]) continue;
            o[a] = this.coord(a, ia);
            if (tool.type === 'ball') {
              const s = _capsule(o, d, c0, c1, r);
              if (s) this._subtract(axis, ia, ib, s[0], s[1]);
            }
            const p = _rayPrism(o, d, prism);
            if (p) this._subtract(axis, ia, ib, p[0], p[1]);
          }
        }
      }
    }

    _inside(i, j, k) {
      const line = this.lines[2][i + j * this.n[0]];
      if (!line) return false;
      const z = this.coord(2, k);
      for (let q = 0; q < line.length; q += 2) {
        if (z >= line[q] && z < line[q + 1]) return true;
      }
      return false;
    }

    // Position de la surface sur l'arête qui part du noeud (i,j,k) le long de [axis].
    _crossing(axis, i, j, k) {
      const idx = [i, j, k];
      const [u, v] = this._others(axis);
      const line = this.lines[axis][idx[u] + idx[v] * this.n[u]];
      const a = this.coord(axis, idx[axis]);
      const b = a + this.h;
      if (line) {
        for (const t of line) if (t >= a && t <= b) return t;
      }
      return a + this.h / 2;
    }

    // Maillage du morceau [id] : { positions, indices } en Float32/Uint32.
    extractChunk(id) {
      const c = this.chunks;
      const cz = Math.floor(id / (c[0] * c[1]));
      const cy = Math.floor((id - cz * c[0] * c[1]) / c[0]);
      const cx = id - cy * c[0] - cz * c[0] * c[1];
      const n = this.n;
      const x0 = cx * CHUNK;
      const y0 = cy * CHUNK;
      const z0 = cz * CHUNK;
      const x1 = Math.min(x0 + CHUNK, n[0] - 1);
      const y1 = Math.min(y0 + CHUNK, n[1] - 1);
      const z1 = Math.min(z0 + CHUNK, n[2] - 1);

      const positions = [];
      const indices = [];
      const vertexOf = new Map();
      const h = this.h;

      const vertex = (i, j, k) => {
        const key = i + n[0] * (j + n[1] * k);
        const known = vertexOf.get(key);
        if (known !== undefined) return known;
        let sx = 0, sy = 0, sz = 0, count = 0;
        const addCrossing = (x, y, z) => { sx += x; sy += y; sz += z; count++; };
        for (let b = 0; b <= 1; b++) {
          for (let a = 0; a <= 1; a++) {
            if (this._inside(i, j + a, k + b) !== this._inside(i + 1, j + a, k + b)) {
              addCrossing(this._crossing(0, i, j + a, k + b), this.coord(1, j + a), this.coord(2, k + b));
            }
            if (this._inside(i + a, j, k + b) !== this._inside(i + a, j + 1, k + b)) {
              addCrossing(this.coord(0, i + a), this._crossing(1, i + a, j, k + b), this.coord(2, k + b));
            }
            if (this._inside(i + a, j + b, k) !== this._inside(i + a, j + b, k + 1)) {
              addCrossing(this.coord(0, i + a), this.coord(1, j + b), this._crossing(2, i + a, j + b, k));
            }
          }
        }
        const at = positions.length / 3;
        if (count === 0) {
          positions.push(this.coord(0, i) + h / 2, this.coord(1, j) + h / 2, this.coord(2, k) + h / 2);
        } else {
          positions.push(sx / count, sy / count, sz / count);
        }
        vertexOf.set(key, at);
        return at;
      };

      const quad = (a, b, c2, d, flip) => {
        if (flip) indices.push(a, c2, b, a, d, c2);
        else indices.push(a, b, c2, a, c2, d);
      };

      for (let k = Math.max(z0, 1); k < z1; k++) {
        for (let j = Math.max(y0, 1); j < y1; j++) {
          for (let i = Math.max(x0, 1); i < x1; i++) {
            const here = this._inside(i, j, k);
            if (here !== this._inside(i + 1, j, k)) {
              quad(vertex(i, j - 1, k - 1), vertex(i, j, k - 1), vertex(i, j, k), vertex(i, j - 1, k), !here);
            }
            if (here !== this._inside(i, j + 1, k)) {
              quad(vertex(i - 1, j, k - 1), vertex(i - 1, j, k), vertex(i, j, k), vertex(i, j, k - 1), !here);
            }
            if (here !== this._inside(i, j, k + 1)) {
              quad(vertex(i - 1, j - 1, k), vertex(i, j - 1, k), vertex(i, j, k), vertex(i - 1, j, k), !here);
            }
          }
        }
      }
      return { positions: new Float32Array(positions), indices: new Uint32Array(indices) };
    }
  }

  // Sphère, cylindre fini : extrêmes de la droite dans la capsule [a, b], rayon r.
  function _capsule(o, d, a, b, r) {
    let tMin = Infinity;
    let tMax = -Infinity;
    const take = (t) => { if (t < tMin) tMin = t; if (t > tMax) tMax = t; };
    const sphere = (c) => {
      const oc = sub(o, c);
      const k = dot(oc, d);
      const q = k * k - dot(oc, oc) + r * r;
      if (q < 0) return;
      const s = Math.sqrt(q);
      take(-k - s);
      take(-k + s);
    };
    sphere(a);
    sphere(b);
    const ba = sub(b, a);
    const baba = dot(ba, ba);
    if (baba > EPS) {
      const oa = sub(o, a);
      const bard = dot(ba, d);
      const baoa = dot(ba, oa);
      const k2 = baba - bard * bard;
      if (k2 > EPS) {
        const k1 = baba * dot(oa, d) - baoa * bard;
        const k0 = baba * dot(oa, oa) - baoa * baoa - r * r * baba;
        const q = k1 * k1 - k2 * k0;
        if (q >= 0) {
          const s = Math.sqrt(q);
          for (const t of [(-k1 - s) / k2, (-k1 + s) / k2]) {
            const y = baoa + t * bard;
            if (y >= 0 && y <= baba) take(t);
          }
        }
      }
    }
    return tMax > tMin ? [tMin, tMax] : null;
  }

  // Volume balayé par un cylindre d'axe u, sans plafond, dont le fond suit [c0, c1].
  function _prism(c0, c1, u, r) {
    const seed = Math.abs(u[0]) < 0.9 ? [1, 0, 0] : [0, 1, 0];
    let e1 = cross(u, seed);
    const l1 = Math.sqrt(dot(e1, e1));
    e1 = [e1[0] / l1, e1[1] / l1, e1[2] / l1];
    const e2 = cross(u, e1);
    const s = sub(c1, c0);
    const w = cross(u, s);
    let n = u;
    let p = dot(s, u) >= 0 ? c0 : c1;
    if (dot(w, w) > 1e-12) {
      n = cross(s, w);
      const ln = Math.sqrt(dot(n, n));
      n = [n[0] / ln, n[1] / ln, n[2] / ln];
      if (dot(n, u) < 0) n = [-n[0], -n[1], -n[2]];
      p = c0;
    }
    return { c0, e1, e2, r, n, p, sx: dot(s, e1), sy: dot(s, e2) };
  }

  function _rayPrism(o, d, P) {
    const rel = sub(o, P.c0);
    const ox = dot(rel, P.e1);
    const oy = dot(rel, P.e2);
    const dx = dot(d, P.e1);
    const dy = dot(d, P.e2);
    const r2 = P.r * P.r;
    let t0;
    let t1;
    const planar = dx * dx + dy * dy;
    if (planar < 1e-12) {
      // Droite parallèle à l'axe : dedans ou dehors de la forme plane.
      const ll = P.sx * P.sx + P.sy * P.sy;
      let f = ll > 1e-18 ? (ox * P.sx + oy * P.sy) / ll : 0;
      f = Math.max(0, Math.min(1, f));
      const gx = ox - f * P.sx;
      const gy = oy - f * P.sy;
      if (gx * gx + gy * gy > r2) return null;
      t0 = -Infinity;
      t1 = Infinity;
    } else {
      let lo = Infinity;
      let hi = -Infinity;
      const take = (t) => { if (t < lo) lo = t; if (t > hi) hi = t; };
      const circle = (cx, cy) => {
        const fx = ox - cx;
        const fy = oy - cy;
        const b = fx * dx + fy * dy;
        const c = fx * fx + fy * fy - r2;
        const q = b * b - planar * c;
        if (q < 0) return;
        const s = Math.sqrt(q);
        take((-b - s) / planar);
        take((-b + s) / planar);
      };
      circle(0, 0);
      circle(P.sx, P.sy);
      const ll = Math.sqrt(P.sx * P.sx + P.sy * P.sy);
      if (ll > 1e-9) {
        // Rectangle entre les deux cercles.
        const ax = P.sx / ll;
        const ay = P.sy / ll;
        const nx = -ay;
        const ny = ax;
        const along0 = ox * ax + oy * ay;
        const alongD = dx * ax + dy * ay;
        const across0 = ox * nx + oy * ny;
        const acrossD = dx * nx + dy * ny;
        let a = -Infinity;
        let b = Infinity;
        const slab = (o0, dd, lo2, hi2) => {
          if (Math.abs(dd) < 1e-12) {
            if (o0 < lo2 || o0 > hi2) { a = 1; b = 0; }
            return;
          }
          const u0 = (lo2 - o0) / dd;
          const u1 = (hi2 - o0) / dd;
          a = Math.max(a, Math.min(u0, u1));
          b = Math.min(b, Math.max(u0, u1));
        };
        slab(along0, alongD, 0, ll);
        slab(across0, acrossD, -P.r, P.r);
        if (a <= b) { take(a); take(b); }
      }
      if (!(hi > lo)) return null;
      t0 = lo;
      t1 = hi;
    }
    // Au-dessus du plan de fond.
    const dn = dot(d, P.n);
    const pn = dot(sub(o, P.p), P.n);
    if (Math.abs(dn) < 1e-12) {
      if (pn < 0) return null;
    } else if (dn > 0) {
      t0 = Math.max(t0, -pn / dn);
    } else {
      t1 = Math.min(t1, -pn / dn);
    }
    return t1 > t0 ? [t0, t1] : null;
  }

  root.DexelStock = DexelStock;
  root.DEXEL_CHUNK = CHUNK;
  if (typeof module !== 'undefined' && module.exports) module.exports = { DexelStock };
})(typeof window !== 'undefined' ? window : globalThis);
