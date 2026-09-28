// Rules for the five mock games, free of any drawing so that node can
// check every level (tool/verify.js) and the page can play them.
(function (root) {
  const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
  const DIR_LIST = ['up', 'down', 'left', 'right'];

  function bfs(start, key, next, won, limit = 200000) {
    const seen = new Map([[key(start), null]]);
    const queue = [start];
    for (let i = 0; i < queue.length; i++) {
      const s = queue[i];
      if (won(s)) {
        const path = [];
        let k = key(s);
        while (seen.get(k)) {
          const [prev, move] = seen.get(k);
          path.unshift(move);
          k = prev;
        }
        return path;
      }
      if (queue.length > limit) return undefined;
      for (const [move, t] of next(s)) {
        const kt = key(t);
        if (!seen.has(kt)) {
          seen.set(kt, [key(s), move]);
          queue.push(t);
        }
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ 0. pack
  // Fill the okamochi (the delivery box) with every dish. Hot and cold
  // dishes may not touch; soups have to sit on the bottom shelf.
  function norm(cells) {
    const mx = Math.min(...cells.map((c) => c[0])), my = Math.min(...cells.map((c) => c[1]));
    return cells.map(([x, y]) => [x - mx, y - my]).sort((a, b) => a[1] - b[1] || a[0] - b[0]);
  }
  function rotations(cells) {
    const out = [];
    let cur = norm(cells);
    for (let i = 0; i < 4; i++) {
      const k = JSON.stringify(cur);
      if (!out.some((o) => JSON.stringify(o) === k)) out.push(cur);
      cur = norm(cur.map(([x, y]) => [-y, x]));
    }
    return out;
  }
  const Pack = {
    // level: { box: ['....', ...] ('#' = no shelf), pieces: [{ cells:[[x,y]...], kind:'hot'|'cold'|'plain', soup?:bool, food }] }
    rotations,
    rotate(cells) { return norm(cells.map(([x, y]) => [-y, x])); },
    norm,
    free(level) {
      const out = [];
      level.box.forEach((row, y) => [...row].forEach((c, x) => { if (c !== '#') out.push([x, y]); }));
      return out;
    },
    // placed: [{ piece:i, x, y, cells(rotated, normalised) }]
    grid(level, placed) {
      const h = level.box.length, w = level.box[0].length;
      const g = Array.from({ length: h }, () => Array(w).fill(-1));
      for (const p of placed) for (const [cx, cy] of p.cells) g[p.y + cy][p.x + cx] = p.piece;
      return g;
    },
    canPlace(level, placed, piece, cells, x, y) {
      const h = level.box.length, w = level.box[0].length;
      const g = Pack.grid(level, placed);
      for (const [cx, cy] of cells) {
        const gx = x + cx, gy = y + cy;
        if (gx < 0 || gy < 0 || gx >= w || gy >= h) return false;
        if (level.box[gy][gx] === '#' || g[gy][gx] >= 0) return false;
      }
      return true;
    },
    // rule breaks in a (partial) packing: pairs of touching hot/cold pieces
    // and soups off the bottom shelf
    problems(level, placed) {
      const g = Pack.grid(level, placed);
      const h = g.length, w = g[0].length;
      const clash = new Set();
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const a = g[y][x];
        if (a < 0) continue;
        for (const [dx, dy] of [[1, 0], [0, 1]]) {
          const bx = x + dx, by = y + dy;
          if (bx >= w || by >= h) continue;
          const b = g[by][bx];
          if (b < 0 || b === a) continue;
          const ka = level.pieces[a].kind, kb = level.pieces[b].kind;
          if ((ka === 'hot' && kb === 'cold') || (ka === 'cold' && kb === 'hot')) { clash.add(a); clash.add(b); }
        }
      }
      const floating = new Set();
      for (const p of placed) {
        if (!level.pieces[p.piece].soup) continue;
        // the bottom shelf is the lowest open row in that column
        const ok = p.cells.some(([cx, cy]) => {
          const x = p.x + cx, y = p.y + cy;
          for (let yy = y + 1; yy < h; yy++) if (level.box[yy][x] !== '#') return false;
          return true;
        });
        if (!ok) floating.add(p.piece);
      }
      return { clash, floating };
    },
    won(level, placed) {
      if (placed.length !== level.pieces.length) return false;
      const pr = Pack.problems(level, placed);
      return pr.clash.size === 0 && pr.floating.size === 0;
    },
    // number of valid packings (capped), for checking a level has exactly one
    count(level, cap = 2) {
      const h = level.box.length, w = level.box[0].length;
      const rots = level.pieces.map((p) => rotations(p.cells));
      const used = Array(level.pieces.length).fill(false);
      const placed = [];
      let n = 0;
      const g = Array.from({ length: h }, (_, y) => Array.from({ length: w }, (_, x) => (level.box[y][x] === '#' ? -2 : -1)));
      const rec = () => {
        if (n >= cap) return;
        let fx = -1, fy = -1;
        outer: for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (g[y][x] === -1) { fx = x; fy = y; break outer; }
        if (fx < 0) {
          if (Pack.won(level, placed)) n++;
          return;
        }
        const tried = new Set();
        for (let i = 0; i < level.pieces.length; i++) {
          if (used[i]) continue;
          const sig = JSON.stringify([level.pieces[i].kind, !!level.pieces[i].soup, rots[i].map((r) => JSON.stringify(r)).sort()[0]]);
          if (tried.has(sig)) continue; // identical pieces: try once
          tried.add(sig);
          for (const r of rots[i]) {
            const [ax, ay] = r[0];
            const ox = fx - ax, oy = fy - ay;
            if (!r.every(([cx, cy]) => { const x = ox + cx, y = oy + cy; return x >= 0 && y >= 0 && x < w && y < h && g[y][x] === -1; })) continue;
            r.forEach(([cx, cy]) => { g[oy + cy][ox + cx] = i; });
            used[i] = true;
            placed.push({ piece: i, x: ox, y: oy, cells: r });
            const pr = Pack.problems(level, placed);
            if (pr.clash.size === 0) rec();
            placed.pop();
            used[i] = false;
            r.forEach(([cx, cy]) => { g[oy + cy][ox + cx] = -1; });
          }
        }
      };
      rec();
      return n;
    },
  };

  const STEP = (x, y, dir) => [x + DIRS[dir][0], y + DIRS[dir][1]];
  const isWall = (map, x, y) => y < 0 || x < 0 || y >= map.length || x >= map[0].length || map[y][x] === '#';

  // ----------------------------------------------------------------- 1. oden
  // Push the ingredients into the oden pots. Each pot takes them only in the
  // order on its recipe card.
  // Gimmicks: several pots, ice (a pushed ingredient keeps sliding),
  // and more to come (see README).
  const Oden = {
    // level: { map: rows with '#' wall, '.' floor, '_' ice, 'P' cat,
    //          lower-case ingredient, upper-case pot }, recipes: { A: 'dec' } }
    parse(level) {
      const items = [], pots = [];
      let start = null;
      level.map.forEach((row, y) => [...row].forEach((c, x) => {
        if (c === 'P') start = { x, y };
        else if (/[a-z]/.test(c)) items.push({ x, y, k: c });
        else if (/[A-Z]/.test(c)) pots.push({ x, y, id: c, recipe: level.recipes[c] });
      }));
      return { map: level.map, items, pots, start };
    },
    ice(b, x, y) { return !isWall(b.map, x, y) && b.map[y][x] === '_'; },
    init(b) { return { x: b.start.x, y: b.start.y, items: b.items.map((i) => ({ ...i })), prog: b.pots.map(() => 0) }; },
    potAt(b, x, y) { return b.pots.findIndex((p) => p.x === x && p.y === y); },
    itemAt(s, x, y) { return s.items.findIndex((i) => i.x === x && i.y === y); },
    // opts.anyOrder: recipes accept their ingredients in any order (used to
    // check that the order matters when generating levels)
    move(b, s, dir, opts = {}) {
      const [nx, ny] = STEP(s.x, s.y, dir);
      if (isWall(b.map, nx, ny) || Oden.potAt(b, nx, ny) >= 0) return null;
      const ii = Oden.itemAt(s, nx, ny);
      if (ii < 0) return { state: { ...s, x: nx, y: ny }, push: null };
      const item = s.items[ii];
      const accepts = (pi) => {
        const p = b.pots[pi], k = s.prog[pi];
        if (k >= p.recipe.length) return false;
        return opts.anyOrder ? p.recipe.includes(item.k) : p.recipe[k] === item.k;
      };
      let [tx, ty] = STEP(nx, ny, dir);
      const path = [];
      let into = -1;
      for (;;) {
        const pi = Oden.potAt(b, tx, ty);
        if (pi >= 0) { if (accepts(pi)) into = pi; break; }
        if (isWall(b.map, tx, ty) || Oden.itemAt(s, tx, ty) >= 0) break;
        path.push({ x: tx, y: ty });
        if (!Oden.ice(b, tx, ty)) break;
        [tx, ty] = STEP(tx, ty, dir);
      }
      if (!path.length && into < 0) return null;
      const items = s.items.filter((_, i) => i !== ii);
      const prog = [...s.prog];
      if (into >= 0) {
        prog[into]++;
      } else {
        const end = path[path.length - 1];
        items.push({ x: end.x, y: end.y, k: item.k });
      }
      return { state: { x: nx, y: ny, items, prog }, push: { from: { x: nx, y: ny }, path, into, k: item.k } };
    },
    key(s) { return `${s.x},${s.y}|${s.items.map((i) => `${i.k}${i.x},${i.y}`).sort().join(';')}|${s.prog.join(',')}`; },
    won(b, s) { return b.pots.every((p, i) => s.prog[i] >= p.recipe.length); },
    solve(b, opts = {}) {
      return bfs(Oden.init(b), Oden.key,
        (s) => DIR_LIST.map((d) => [d, Oden.move(b, s, d, opts)]).filter(([, r]) => r).map(([d, r]) => [d, r.state]),
        (s) => Oden.won(b, s), 400000);
    },
  };

  // ---------------------------------------------------------------- 2. light
  // Guide the lamp's light to the paper lanterns by pushing the folding
  // mirror screens. Gimmicks: red paper (turns the light red for red
  // lanterns), a bamboo blind (lets half the light through, reflects half).
  const REFLECT = {
    '/': { right: 'up', up: 'right', left: 'down', down: 'left' },
    '\\': { right: 'down', down: 'right', left: 'up', up: 'left' },
  };
  const Light = {
    // level: { map, src:{x,y,dir}, mirrors:[{x,y,o}], targets:[{x,y,red}], filters:[{x,y}], blinds:[{x,y,o}] }
    parse(level) {
      let start = null;
      level.map.forEach((row, y) => [...row].forEach((c, x) => { if (c === 'P') start = { x, y }; }));
      return { ...level, filters: level.filters || [], blinds: level.blinds || [], start };
    },
    init(b) { return { x: b.start.x, y: b.start.y, mirrors: b.mirrors.map((m) => ({ ...m })) }; },
    solid(b, s, x, y) {
      // things that stop the cat and the screens
      if (isWall(b.map, x, y)) return 'wall';
      if (b.src.x === x && b.src.y === y) return 'src';
      if (b.targets.some((t) => t.x === x && t.y === y)) return 'target';
      if (b.blinds.some((t) => t.x === x && t.y === y)) return 'blind';
      if (s.mirrors.some((m) => m.x === x && m.y === y)) return 'mirror';
      return null;
    },
    move(b, s, dir) {
      const [nx, ny] = STEP(s.x, s.y, dir);
      const what = Light.solid(b, s, nx, ny);
      if (!what) return { state: { ...s, x: nx, y: ny }, push: null };
      if (what !== 'mirror') return null;
      const [tx, ty] = STEP(nx, ny, dir);
      if (Light.solid(b, s, tx, ty) || b.filters.some((f) => f.x === tx && f.y === ty)) return null;
      const mirrors = s.mirrors.map((m) => (m.x === nx && m.y === ny ? { ...m, x: tx, y: ty } : m));
      return { state: { x: nx, y: ny, mirrors }, push: { from: { x: nx, y: ny }, to: { x: tx, y: ty } } };
    },
    // follow the light: segments for drawing and which lanterns are lit
    trace(b, s) {
      const segs = [];
      const lit = b.targets.map(() => ({ any: false, red: false }));
      const seen = new Set();
      const queue = [{ x: b.src.x, y: b.src.y, dir: b.src.dir, red: false }];
      while (queue.length) {
        let { x, y, dir, red } = queue.shift();
        for (let guard = 0; guard < 200; guard++) {
          const [nx, ny] = STEP(x, y, dir);
          const k = `${nx},${ny},${dir},${red}`;
          if (seen.has(k)) break;
          seen.add(k);
          if (isWall(b.map, nx, ny) || (b.src.x === nx && b.src.y === ny)) { segs.push({ x, y, nx, ny, red, stop: true }); break; }
          segs.push({ x, y, nx, ny, red });
          x = nx; y = ny;
          if (b.filters.some((f) => f.x === x && f.y === y)) red = true;
          const ti = b.targets.findIndex((t) => t.x === x && t.y === y);
          if (ti >= 0) { lit[ti].any = true; if (red) lit[ti].red = true; }
          const m = s.mirrors.find((mm) => mm.x === x && mm.y === y);
          if (m) { dir = REFLECT[m.o][dir]; continue; }
          const bl = b.blinds.find((mm) => mm.x === x && mm.y === y);
          if (bl) queue.push({ x, y, dir: REFLECT[bl.o][dir], red });
        }
      }
      return { segs, lit };
    },
    litOk(b, lit, i) { return b.targets[i].red ? lit[i].red : lit[i].any; },
    won(b, s) { const { lit } = Light.trace(b, s); return b.targets.every((_, i) => Light.litOk(b, lit, i)); },
    key(s) { return `${s.x},${s.y}|${s.mirrors.map((m) => `${m.o}${m.x},${m.y}`).sort().join(';')}`; },
    solve(b) {
      return bfs(Light.init(b), Light.key,
        (s) => DIR_LIST.map((d) => [d, Light.move(b, s, d)]).filter(([, r]) => r).map(([d, r]) => [d, r.state]),
        (s) => Light.won(b, s), 300000);
    },
  };

  // --------------------------------------------------------------- 3. fusuma
  // An old inn with sliding doors. Push the fusuma along their tracks to
  // reach the guest room. Gimmicks: paired doors (move together), a locked
  // door (find the landlady's key first).
  const Fusuma = {
    // level: { map ('#' wall, '.' floor, 'P' cat, 'G' guest room, 'k' key), panels:[{x,y,len,axis:'h'|'v',lock?,link?}] }
    parse(level) {
      let start = null, goal = null, key = null;
      level.map.forEach((row, y) => [...row].forEach((c, x) => {
        if (c === 'P') start = { x, y };
        if (c === 'G') goal = { x, y };
        if (c === 'k') key = { x, y };
      }));
      return { map: level.map, panels: level.panels, start, goal, key };
    },
    cells(p, pos) { return Array.from({ length: p.len }, (_, i) => (p.axis === 'h' ? { x: pos.x + i, y: pos.y } : { x: pos.x, y: pos.y + i })); },
    init(b) { return { x: b.start.x, y: b.start.y, pos: b.panels.map((p) => ({ x: p.x, y: p.y })), key: !b.key }; },
    panelAt(b, s, x, y, skip = []) {
      return b.panels.findIndex((p, i) => !skip.includes(i) && Fusuma.cells(p, s.pos[i]).some((c) => c.x === x && c.y === y));
    },
    move(b, s, dir) {
      const [nx, ny] = STEP(s.x, s.y, dir);
      if (isWall(b.map, nx, ny)) return null;
      const pi = Fusuma.panelAt(b, s, nx, ny);
      if (pi < 0) {
        const key = s.key || (b.key && b.key.x === nx && b.key.y === ny);
        return { state: { ...s, x: nx, y: ny, key }, push: null };
      }
      const p = b.panels[pi];
      const along = p.axis === 'h' ? dir === 'left' || dir === 'right' : dir === 'up' || dir === 'down';
      if (!along) return { blocked: 'across', panel: pi };
      if (p.lock && !s.key) return { blocked: 'locked', panel: pi };
      const moving = b.panels.map((q, i) => i).filter((i) => i === pi || (p.link && b.panels[i].link === p.link));
      const [dx, dy] = DIRS[dir];
      for (const i of moving) {
        const q = b.panels[i];
        if (i !== pi && q.axis !== p.axis) return { blocked: 'link', panel: pi };
        for (const c of Fusuma.cells(q, { x: s.pos[i].x + dx, y: s.pos[i].y + dy })) {
          if (isWall(b.map, c.x, c.y) || '.P'.indexOf(b.map[c.y][c.x]) < 0) return { blocked: 'jam', panel: pi };
          if (Fusuma.panelAt(b, s, c.x, c.y, moving) >= 0) return { blocked: 'jam', panel: pi };
          if (c.x === s.x && c.y === s.y) return { blocked: 'jam', panel: pi };
        }
      }
      const pos = s.pos.map((q, i) => (moving.includes(i) ? { x: q.x + dx, y: q.y + dy } : q));
      return { state: { ...s, x: nx, y: ny, pos }, push: { moving } };
    },
    won(b, s) { return s.x === b.goal.x && s.y === b.goal.y; },
    key(s) { return `${s.x},${s.y},${s.key ? 1 : 0}|${s.pos.map((p) => `${p.x},${p.y}`).join(';')}`; },
    solve(b) {
      return bfs(Fusuma.init(b), Fusuma.key,
        (s) => DIR_LIST.map((d) => [d, Fusuma.move(b, s, d)]).filter(([, r]) => r && r.state).map(([d, r]) => [d, r.state]),
        (s) => Fusuma.won(b, s), 400000);
    },
  };

  // ---------------------------------------------------------------- 4. dashi
  // Turn the bamboo pipes so the stock reaches every bowl. Stocks that meet
  // mix: katsuo + kombu = awase. Gimmicks: mixing, fixed iron pipes, a
  // crossing that keeps two stocks apart, and spills (an open pipe end
  // loses the stock).
  // Openings: N=1 E=2 S=4 W=8
  const OPEN = { N: 1, E: 2, S: 4, W: 8 };
  const DIR_BIT = { up: 1, right: 2, down: 4, left: 8 };
  const OPP = { 1: 4, 2: 8, 4: 1, 8: 2 };
  const BIT_STEP = { 1: [0, -1], 2: [1, 0], 4: [0, 1], 8: [-1, 0] };
  const BASE = { I: 5, L: 3, T: 14, X: 15, '.': 0 };
  const rot = (m, r) => { for (let i = 0; i < r; i++) m = ((m << 1) | (m >> 3)) & 15; return m; };
  const Dashi = {
    // level: { tiles: rows of I/L/T/X/. and S (source) / B (bowl),
    //          rot: rows of 0-3, fixed: ['x,y'], sources:[{x,y,f:'k'|'n',dir}], bowls:[{x,y,want,dir}], answer: rows of 0-3 }
    OPEN, BASE, rot,
    mask(level, r, x, y) {
      const t = level.tiles[y][x];
      if (t === 'S') return DIR_BIT[level.sources.find((s) => s.x === x && s.y === y).dir];
      if (t === 'B') return DIR_BIT[level.bowls.find((s) => s.x === x && s.y === y).dir];
      return rot(BASE[t] || 0, r[y][x]);
    },
    // channel of an opening: a crossing keeps N-S and E-W apart
    chan(level, x, y, bit) { return level.tiles[y][x] === 'X' && (bit === 2 || bit === 8) ? 1 : 0; },
    flow(level, r) {
      const h = level.tiles.length, w = level.tiles[0].length;
      const parent = {};
      const find = (a) => { while (parent[a] !== a) { parent[a] = parent[parent[a]]; a = parent[a]; } return a; };
      const node = (x, y, c) => { const k = `${x},${y},${c}`; if (!(k in parent)) parent[k] = k; return k; };
      const union = (a, b) => { parent[find(a)] = find(b); };
      const open = [];
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const m = Dashi.mask(level, r, x, y);
        for (const bit of [1, 2, 4, 8]) {
          if (!(m & bit)) continue;
          const a = node(x, y, Dashi.chan(level, x, y, bit));
          const [dx, dy] = BIT_STEP[bit];
          const nx = x + dx, ny = y + dy;
          const nm = nx >= 0 && ny >= 0 && nx < w && ny < h ? Dashi.mask(level, r, nx, ny) : 0;
          if (nm & OPP[bit]) union(a, node(nx, ny, Dashi.chan(level, nx, ny, OPP[bit])));
          else open.push(a);
        }
      }
      const flavours = {};
      for (const s of level.sources) {
        const c = find(node(s.x, s.y, 0));
        flavours[c] = (flavours[c] || '') + s.f;
      }
      const spill = new Set(open.map(find));
      // what each node carries, for drawing
      const carry = (x, y, c) => { const k = `${x},${y},${c}`; return k in parent ? [...new Set(flavours[find(k)] || '')].sort().join('') : ''; };
      const spilling = (x, y, c) => { const k = `${x},${y},${c}`; return k in parent && spill.has(find(k)) && !!flavours[find(k)]; };
      const bowls = level.bowls.map((bw) => carry(bw.x, bw.y, 0));
      const ok = level.bowls.every((bw, i) => bowls[i] === [...bw.want].sort().join(''))
        && level.sources.every((s) => !spill.has(find(node(s.x, s.y, 0))));
      return { carry, spilling, bowls, ok };
    },
    won(level, r) { return Dashi.flow(level, r).ok; },
  };
  root.Logic = { DIRS, DIR_LIST, bfs, Pack, Oden, Light, Fusuma, Dashi };
  if (typeof module !== 'undefined') module.exports = root.Logic;
})(typeof globalThis !== 'undefined' ? globalThis : this);
