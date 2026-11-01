// Comparaison du brut usiné au modèle : distance signée d'un point à un maillage.
//
// Repère pièce : X/Y sur l'axe C, Z=0 au sommet, comme les programmes de
// pipeline/continuous5.py. d > 0 : hors de la pièce, il reste de la matière à
// enlever. d < 0 : dans la pièce, l'outil y est entré.
(function (root) {
  'use strict';

  class PartModel {
    constructor(vertices, indices) {
      this.v = Float64Array.from(vertices);
      const n = this.v.length / 3;
      this.ix = indices && indices.length >= 3
        ? Uint32Array.from(indices)
        : Uint32Array.from({ length: n }, (_, i) => i);
      this.count = this.ix.length / 3;
      const lo = [Infinity, Infinity, Infinity];
      const hi = [-Infinity, -Infinity, -Infinity];
      for (let i = 0; i < n; i++) {
        for (let k = 0; k < 3; k++) {
          const c = this.v[i * 3 + k];
          if (c < lo[k]) lo[k] = c;
          if (c > hi[k]) hi[k] = c;
        }
      }
      this.lo = lo;
      this.hi = hi;
      this.closed = this._isClosed();
      this._buildGrid();
    }

    // Le modèle est-il dans le repère des programmes ? Sinon toute comparaison
    // serait fausse : on ne devine pas un repère.
    inProgramFrame(tol = 0.5) {
      return Math.abs(this.hi[2]) < tol
        && Math.abs((this.lo[0] + this.hi[0]) / 2) < tol
        && Math.abs((this.lo[1] + this.hi[1]) / 2) < tol;
    }

    _isClosed() {
      const edges = new Map();
      const key = (i) => {
        const v = this.v;
        return `${v[i * 3].toFixed(3)},${v[i * 3 + 1].toFixed(3)},${v[i * 3 + 2].toFixed(3)}`;
      };
      for (let t = 0; t < this.count; t++) {
        const k = [key(this.ix[t * 3]), key(this.ix[t * 3 + 1]), key(this.ix[t * 3 + 2])];
        for (let e = 0; e < 3; e++) {
          const a = k[e];
          const b = k[(e + 1) % 3];
          if (a === b) continue;
          const id = a < b ? a + '|' + b : b + '|' + a;
          edges.set(id, (edges.get(id) || 0) + 1);
        }
      }
      for (const c of edges.values()) if (c % 2) return false;
      return edges.size > 0;
    }

    _buildGrid() {
      const size = Math.max(this.hi[0] - this.lo[0], this.hi[1] - this.lo[1], this.hi[2] - this.lo[2], 1);
      this.cell = Math.max(size / 48, 0.5);
      this.dim = [0, 1, 2].map((k) => Math.max(1, Math.ceil((this.hi[k] - this.lo[k]) / this.cell)));
      this.cells = new Map();
      this.columns = new Map();
      for (let t = 0; t < this.count; t++) {
        const mn = [Infinity, Infinity, Infinity];
        const mx = [-Infinity, -Infinity, -Infinity];
        for (let q = 0; q < 3; q++) {
          const i = this.ix[t * 3 + q] * 3;
          for (let k = 0; k < 3; k++) {
            if (this.v[i + k] < mn[k]) mn[k] = this.v[i + k];
            if (this.v[i + k] > mx[k]) mx[k] = this.v[i + k];
          }
        }
        const a = [0, 1, 2].map((k) => this._cellIndex(k, mn[k]));
        const b = [0, 1, 2].map((k) => this._cellIndex(k, mx[k]));
        for (let y = a[1]; y <= b[1]; y++) {
          for (let x = a[0]; x <= b[0]; x++) {
            const col = x + y * this.dim[0];
            let list = this.columns.get(col);
            if (!list) this.columns.set(col, (list = []));
            list.push(t);
            for (let z = a[2]; z <= b[2]; z++) {
              const id = col + z * this.dim[0] * this.dim[1];
              let cell = this.cells.get(id);
              if (!cell) this.cells.set(id, (cell = []));
              cell.push(t);
            }
          }
        }
      }
      this.stamp = new Uint32Array(this.count);
      this.stampId = 0;
    }

    _cellIndex(k, c) {
      return Math.max(0, Math.min(this.dim[k] - 1, Math.floor((c - this.lo[k]) / this.cell)));
    }

    // Carré de la distance au triangle t (point le plus proche, Ericson).
    _dist2(t, px, py, pz) {
      const v = this.v;
      const ia = this.ix[t * 3] * 3;
      const ib = this.ix[t * 3 + 1] * 3;
      const ic = this.ix[t * 3 + 2] * 3;
      const ax = v[ia], ay = v[ia + 1], az = v[ia + 2];
      const abx = v[ib] - ax, aby = v[ib + 1] - ay, abz = v[ib + 2] - az;
      const acx = v[ic] - ax, acy = v[ic + 1] - ay, acz = v[ic + 2] - az;
      const apx = px - ax, apy = py - ay, apz = pz - az;
      const d1 = abx * apx + aby * apy + abz * apz;
      const d2 = acx * apx + acy * apy + acz * apz;
      let qx, qy, qz;
      const done = (x, y, z) => {
        const dx = px - x, dy = py - y, dz = pz - z;
        return dx * dx + dy * dy + dz * dz;
      };
      if (d1 <= 0 && d2 <= 0) return done(ax, ay, az);
      const bpx = px - v[ib], bpy = py - v[ib + 1], bpz = pz - v[ib + 2];
      const d3 = abx * bpx + aby * bpy + abz * bpz;
      const d4 = acx * bpx + acy * bpy + acz * bpz;
      if (d3 >= 0 && d4 <= d3) return done(v[ib], v[ib + 1], v[ib + 2]);
      const vc = d1 * d4 - d3 * d2;
      if (vc <= 0 && d1 >= 0 && d3 <= 0) {
        const s = d1 / (d1 - d3);
        return done(ax + s * abx, ay + s * aby, az + s * abz);
      }
      const cpx = px - v[ic], cpy = py - v[ic + 1], cpz = pz - v[ic + 2];
      const d5 = abx * cpx + aby * cpy + abz * cpz;
      const d6 = acx * cpx + acy * cpy + acz * cpz;
      if (d6 >= 0 && d5 <= d6) return done(v[ic], v[ic + 1], v[ic + 2]);
      const vb = d5 * d2 - d1 * d6;
      if (vb <= 0 && d2 >= 0 && d6 <= 0) {
        const s = d2 / (d2 - d6);
        return done(ax + s * acx, ay + s * acy, az + s * acz);
      }
      const va = d3 * d6 - d5 * d4;
      if (va <= 0 && d4 - d3 >= 0 && d5 - d6 >= 0) {
        const s = (d4 - d3) / (d4 - d3 + (d5 - d6));
        return done(v[ib] + s * (v[ic] - v[ib]), v[ib + 1] + s * (v[ic + 1] - v[ib + 1]),
          v[ib + 2] + s * (v[ic + 2] - v[ib + 2]));
      }
      const denom = 1 / (va + vb + vc);
      const a2 = vb * denom;
      const b2 = vc * denom;
      qx = ax + abx * a2 + acx * b2;
      qy = ay + aby * a2 + acy * b2;
      qz = az + abz * a2 + acz * b2;
      return done(qx, qy, qz);
    }

    // Distance au maillage, plafonnée à maxRange.
    distance(px, py, pz, maxRange) {
      let best = maxRange * maxRange;
      const stamp = ++this.stampId;
      const a = [px, py, pz].map((c, k) => this._cellIndex(k, c - maxRange));
      const b = [px, py, pz].map((c, k) => this._cellIndex(k, c + maxRange));
      // Hors de la grille d'au moins maxRange : aucun triangle n'est assez proche.
      for (let k = 0; k < 3; k++) {
        const c = [px, py, pz][k];
        if (c < this.lo[k] - maxRange || c > this.hi[k] + maxRange) return maxRange;
      }
      const dx = this.dim[0];
      const dxy = dx * this.dim[1];
      for (let z = a[2]; z <= b[2]; z++) {
        for (let y = a[1]; y <= b[1]; y++) {
          for (let x = a[0]; x <= b[0]; x++) {
            const list = this.cells.get(x + y * dx + z * dxy);
            if (!list) continue;
            for (const t of list) {
              if (this.stamp[t] === stamp) continue;
              this.stamp[t] = stamp;
              const d2 = this._dist2(t, px, py, pz);
              if (d2 < best) best = d2;
            }
          }
        }
      }
      return Math.sqrt(best);
    }

    // Dans la pièce ? Parité des traversées d'un rayon vertical vers le haut.
    inside(px, py, pz) {
      if (px < this.lo[0] || px > this.hi[0] || py < this.lo[1] || py > this.hi[1]
        || pz < this.lo[2] || pz > this.hi[2]) return false;
      const col = this._cellIndex(0, px) + this._cellIndex(1, py) * this.dim[0];
      const list = this.columns.get(col);
      if (!list) return false;
      // Décalage infime : un rayon qui passe pile sur une arête compterait double.
      const x = px + 1.37e-7;
      const y = py + 2.11e-7;
      const v = this.v;
      let crossings = 0;
      for (const t of list) {
        const ia = this.ix[t * 3] * 3;
        const ib = this.ix[t * 3 + 1] * 3;
        const ic = this.ix[t * 3 + 2] * 3;
        const x0 = v[ia], y0 = v[ia + 1];
        const x1 = v[ib], y1 = v[ib + 1];
        const x2 = v[ic], y2 = v[ic + 1];
        const den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2);
        if (Math.abs(den) < 1e-12) continue;
        const u = ((y1 - y2) * (x - x2) + (x2 - x1) * (y - y2)) / den;
        const w = ((y2 - y0) * (x - x2) + (x0 - x2) * (y - y2)) / den;
        if (u < 0 || w < 0 || u + w > 1) continue;
        const z = u * v[ia + 2] + w * v[ib + 2] + (1 - u - w) * v[ic + 2];
        if (z > pz) crossings++;
      }
      return crossings % 2 === 1;
    }

    // Sur un maillage ouvert (scan troué), dedans et dehors n'ont pas de sens : la
    // distance reste exacte, mais elle est rendue sans signe.
    signed(px, py, pz, maxRange) {
      const d = this.distance(px, py, pz, maxRange);
      return this.closed && this.inside(px, py, pz) ? -d : d;
    }
  }

  // Bilan sur les bords exacts de la matière : les extrémités des segments du brut.
  // Le dessous et les côtés du brut brut ne comptent pas dans « surface usinée »,
  // mais une pénétration y resterait une pénétration.
  function compareStock(stock, part, { tol = 0.05, range = 3 } = {}) {
    const H = stock.size[2];
    let worstPen = { depth: 0, at: null };
    let worstRest = { height: 0, at: null };
    const bins = { penetration: 0, conforme: 0, reste: 0, loin: 0 };
    for (let axis = 0; axis < 3; axis++) {
      const [u, v] = stock._others(axis);
      const lines = stock.lines[axis];
      for (let iv = 0; iv < stock.n[v]; iv++) {
        for (let iu = 0; iu < stock.n[u]; iu++) {
          const line = lines[iu + iv * stock.n[u]];
          if (!line) continue;
          const p = [0, 0, 0];
          p[u] = stock.coord(u, iu);
          p[v] = stock.coord(v, iv);
          for (const t of line) {
            p[axis] = t;
            const d = part.signed(p[0], p[1], p[2] - H, range);
            if (d < -tol) {
              bins.penetration++;
              if (-d > worstPen.depth) worstPen = { depth: -d, at: [p[0], p[1], p[2] - H] };
            } else if (d <= tol) {
              bins.conforme++;
            } else if (d >= range) {
              bins.loin++;
            } else {
              bins.reste++;
              if (d > worstRest.height) worstRest = { height: d, at: [p[0], p[1], p[2] - H] };
            }
          }
        }
      }
    }
    return {
      tolMm: tol,
      modeleFerme: part.closed,
      // null : non mesurable sur un modèle ouvert, ce qui ne veut pas dire « aucune ».
      penetrationMaxMm: part.closed ? worstPen.depth : null,
      penetrationAu: part.closed ? worstPen.at : null,
      resteMaxMm: worstRest.height,
      resteAu: worstRest.at,
      points: bins,
    };
  }

  root.PartModel = PartModel;
  root.compareStock = compareStock;
  if (typeof module !== 'undefined' && module.exports) module.exports = { PartModel, compareStock };
})(typeof window !== 'undefined' ? window : globalThis);
