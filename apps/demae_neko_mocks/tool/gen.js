// Generates the levels for the five mocks and writes src/levels.js.
// Every level is checked here: solvable, and (where it matters) with a
// single answer.
//
//   node tool/gen.js
const fs = require('fs');
const path = require('path');
const L = require('../src/logic.js');

let seed = 20260927;
// mulberry32
const rnd = () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const pick = (a) => a[Math.floor(rnd() * a.length)];
const shuffle = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

// ------------------------------------------------------------------- pack
const FOOD = {
  hot: ['miso', 'gyoza', 'tempura', 'ramen'],
  cold: ['purin', 'soba', 'sushi', 'salad'],
  plain: ['onigiri', 'dango', 'tamago', 'bento'],
};
function genPack({ box, sizes, kinds, soup }) {
  const h = box.length, w = box[0].length;
  for (let t = 0; t < 30000; t++) {
    // grow random pieces until the box is covered
    const owner = Array.from({ length: h }, (_, y) => Array.from({ length: w }, (_, x) => (box[y][x] === '#' ? -2 : -1)));
    const pieces = [];
    let ok = true;
    for (let y = 0; y < h && ok; y++) for (let x = 0; x < w && ok; x++) {
      if (owner[y][x] !== -1) continue;
      const want = pick(sizes);
      const cells = [[x, y]];
      owner[y][x] = pieces.length;
      while (cells.length < want) {
        const cand = [];
        for (const [cx, cy] of cells) for (const [dx, dy] of [[1, 0], [0, 1], [-1, 0], [0, -1]]) {
          const nx = cx + dx, ny = cy + dy;
          if (nx >= 0 && ny >= 0 && nx < w && ny < h && owner[ny][nx] === -1) cand.push([nx, ny]);
        }
        if (!cand.length) break;
        const [nx, ny] = pick(cand);
        owner[ny][nx] = pieces.length;
        cells.push([nx, ny]);
      }
      pieces.push({ cells });
    }
    if (pieces.length < 4) continue;
    // kinds: the answer itself must follow the rules
    pieces.forEach((p) => { p.kind = pick(kinds); });
    const touching = (a, b) => a.cells.some(([x, y]) => b.cells.some(([u, v]) => Math.abs(x - u) + Math.abs(y - v) === 1));
    let bad = false;
    for (let i = 0; i < pieces.length; i++) for (let j = i + 1; j < pieces.length; j++) {
      const k = [pieces[i].kind, pieces[j].kind].sort().join();
      if (k === 'cold,hot' && touching(pieces[i], pieces[j])) bad = true;
    }
    if (bad) continue;
    if (!kinds.includes('hot') || !kinds.includes('cold')) continue;
    if (!pieces.some((p) => p.kind === 'hot') || !pieces.some((p) => p.kind === 'cold')) continue;
    if (soup) {
      const onFloor = (p) => p.cells.some(([x, y]) => { for (let yy = y + 1; yy < h; yy++) if (box[yy][x] !== '#') return false; return true; });
      const cand = pieces.filter((p) => p.kind === 'hot' && p.cells.length <= 2 && onFloor(p));
      if (!cand.length) continue;
      pick(cand).soup = true;
    }
    const level = {
      box,
      pieces: pieces.map((p) => ({
        cells: L.Pack.norm(p.cells),
        kind: p.kind,
        ...(p.soup ? { soup: true } : {}),
        food: p.soup ? 'miso' : FOOD[p.kind][Math.min(3, p.cells.length - 1)],
      })),
    };
    if (L.Pack.count(level, 2) === 1) {
      // shuffle the tray order and turn pieces so the answer is not given away
      level.pieces = shuffle(level.pieces).map((p) => { let c = p.cells; for (let r = Math.floor(rnd() * 4); r > 0; r--) c = L.Pack.rotate(c); return { ...p, cells: c }; });
      return level;
    }
  }
  throw new Error('pack: no level');
}

// ------------------------------------------------------------------- oden
function blankRoom(w, h) {
  return Array.from({ length: h }, (_, y) => Array.from({ length: w }, (_, x) => (x === 0 || y === 0 || x === w - 1 || y === h - 1 ? '#' : '.')));
}
function innerCells(w, h) {
  const out = [];
  for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) out.push([x, y]);
  return shuffle(out);
}
function genOden({ w, h, walls, pots, ice = 0, par: [lo, hi], tries = 2500 }) {
  const kinds = ['d', 'e', 'c', 'k', 'g'];
  let best = null;
  const deadline = Date.now() + 45000;
  for (let t = 0; t < tries; t++) {
    if (best && Date.now() > deadline) break;
    const g = blankRoom(w, h);
    const cells = innerCells(w, h);
    let k = 0;
    const take = () => cells[k++];
    const [px, py] = take(); g[py][px] = 'P';
    const pool = shuffle([...kinds]);
    const recipes = {};
    let ok = true;
    pots.forEach((n, i) => {
      const id = 'AB'[i];
      const [x, y] = take();
      g[y][x] = id;
      recipes[id] = pool.splice(0, n).join('');
    });
    for (const r of Object.values(recipes)) for (const c of r) {
      // ingredients away from the outer wall so they can be pushed
      let cell = take();
      let guard = 0;
      while ((cell[0] === 1 || cell[1] === 1 || cell[0] === w - 2 || cell[1] === h - 2) && guard++ < 20) { cells.push(cell); cell = take(); }
      if (!cell) { ok = false; break; }
      g[cell[1]][cell[0]] = c;
    }
    if (!ok) continue;
    for (let i = 0; i < ice; i++) { const c = take(); if (c) g[c[1]][c[0]] = '_'; }
    for (let i = 0; i < walls; i++) { const c = take(); if (c) g[c[1]][c[0]] = '#'; }
    const level = { map: g.map((r) => r.join('')), recipes };
    const b = L.Oden.parse(level);
    const sol = L.Oden.solve(b);
    if (!sol || sol.length < lo || sol.length > hi) continue;
    // the order on the recipe card has to matter
    const free = L.Oden.solve(b, { anyOrder: true });
    if (free && free.length >= sol.length) continue;
    if (ice) {
      const dry = L.Oden.solve(L.Oden.parse({ ...level, map: level.map.map((r) => r.replace(/_/g, '.')) }));
      if (dry && dry.length <= sol.length) continue;
    }
    if (!best || sol.length > best.par) best = { ...level, par: sol.length };
    if (best.par >= hi) break;
  }
  if (!best) throw new Error('oden: no level');
  return best;
}

// ------------------------------------------------------------------ light
function genLight({ w, h, walls, mirrors, targets, red = false, blind = false, par: [lo, hi], tries = 20000 }) {
  let best = null;
  const dirs = ['up', 'down', 'left', 'right'];
  const deadline = Date.now() + 45000;
  for (let t = 0; t < tries; t++) {
    if (best && Date.now() > deadline) break;
    const g = blankRoom(w, h);
    const cells = innerCells(w, h);
    let k = 0;
    const take = () => cells[k++];
    const [px, py] = take(); g[py][px] = 'P';
    const [sx, sy] = take();
    const src = { x: sx, y: sy, dir: pick(dirs) };
    const tg = Array.from({ length: targets }, (_, i) => { const [x, y] = take(); return { x, y, ...(red && i === 0 ? { red: true } : {}) }; });
    // screens away from the outer wall, so they can be pushed both ways
    const deep = cells.slice(k).filter(([x, y]) => x > 1 && y > 1 && x < w - 2 && y < h - 2).slice(0, mirrors);
    if (deep.length < mirrors) continue;
    deep.forEach((c) => cells.splice(cells.indexOf(c), 1));
    const ms = deep.map(([x, y]) => ({ x, y, o: pick(['/', '\\']) }));
    const filters = red ? [take()].map(([x, y]) => ({ x, y })) : [];
    const blinds = blind ? [take()].map(([x, y]) => ({ x, y, o: pick(['/', '\\']) })) : [];
    for (let i = 0; i < walls; i++) { const c = take(); if (c) g[c[1]][c[0]] = '#'; }
    const level = { map: g.map((r) => r.join('')), src, mirrors: ms, targets: tg, ...(red ? { filters } : {}), ...(blind ? { blinds } : {}) };
    const b = L.Light.parse(level);
    if (L.Light.won(b, L.Light.init(b))) continue;
    const sol = L.Light.solve(b);
    if (!sol || sol.length < lo || sol.length > hi) continue;
    if (blind) {
      // the blind has to be part of the answer
      const without = L.Light.solve(L.Light.parse({ ...level, blinds: [] }));
      if (without && without.length <= sol.length) continue;
    }
    if (!best || sol.length > best.par) best = { ...level, par: sol.length };
    if (best.par >= hi) break;
  }
  if (!best) throw new Error('light: no level');
  return best;
}

// ----------------------------------------------------------------- fusuma
// Made backwards: the cat starts at the guest room and walks away, pulling
// doors behind it now and then. Played forwards, that is always solvable.
function genFusuma({ w, h, panels, walls = 0, pushes = 3, link = false, lock = false, par: [lo, hi], tries = 20000 }) {
  let best = null;
  const deadline = Date.now() + 45000;
  const DIRV = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
  for (let t = 0; t < tries; t++) {
    if (best && Date.now() > deadline) break;
    const g = blankRoom(w, h);
    const gy = 1 + Math.floor(rnd() * (h - 2));
    g[gy][w - 2] = 'G';
    for (const [x, y] of innerCells(w, h).slice(0, walls)) if (g[y][x] === '.' && x > 1 && x < w - 2) g[y][x] = '#';
    const occ = new Set([`${w - 2},${gy}`]);
    const ps = [];
    for (let i = 0; i < panels * 8 && ps.length < panels; i++) {
      const axis = pick(['h', 'v']);
      const len = pick([2, 2, 3]);
      const x = 1 + Math.floor(rnd() * (w - 2)), y = 1 + Math.floor(rnd() * (h - 2));
      const cells = Array.from({ length: len }, (_, j) => (axis === 'h' ? [x + j, y] : [x, y + j]));
      if (cells.some(([cx, cy]) => cx >= w - 1 || cy >= h - 1 || g[cy][cx] !== '.' || occ.has(`${cx},${cy}`))) continue;
      cells.forEach(([cx, cy]) => occ.add(`${cx},${cy}`));
      ps.push({ x, y, len, axis });
    }
    if (ps.length < panels) continue;
    if (link) {
      const hs = ps.filter((p) => p.axis === 'h'), vs = ps.filter((p) => p.axis === 'v');
      const group = hs.length >= 2 ? hs : vs.length >= 2 ? vs : null;
      if (!group) continue;
      shuffle(group).slice(0, 2).forEach((p) => { p.link = 'a'; });
    }
    if (lock) pick(ps.filter((p) => !p.link)).lock = true;
    // walk backwards from the guest room
    const b0 = L.Fusuma.parse({ map: g.map((r) => r.join('')).map((r, y) => (y === gy ? r : r)), panels: ps });
    let st = { x: w - 2, y: gy, pos: ps.map((p) => ({ x: p.x, y: p.y })), key: true };
    const free = (x, y, s2, skip) => x > 0 && y > 0 && x < w - 1 && y < h - 1 && g[y][x] !== '#' && L.Fusuma.panelAt(b0, s2, x, y, skip) < 0;
    const trail = [];
    for (let step = 0; step < 60 + Math.floor(rnd() * 60); step++) {
      // lean away from the guest room (the cat steps back, so 'right' walks left)
      const d = pick(['right', 'right', 'up', 'down', 'left']);
      const [dx, dy] = DIRV[d];
      const bx = st.x - dx, by = st.y - dy; // where the cat steps back to
      if (!free(bx, by, st, [])) continue;
      const front = L.Fusuma.panelAt(b0, st, st.x + dx, st.y + dy);
      let pull = front >= 0 && rnd() < 0.6;
      if (pull) {
        const p = ps[front];
        const along = p.axis === 'h' ? dx !== 0 : dy !== 0;
        const moving = ps.map((_, i) => i).filter((i) => i === front || (p.link && ps[i].link === p.link));
        if (!along) pull = false;
        else {
          for (const i of moving) {
            for (const c of L.Fusuma.cells(ps[i], { x: st.pos[i].x - dx, y: st.pos[i].y - dy })) {
              if (!(c.x === st.x && c.y === st.y) && !free(c.x, c.y, st, moving)) pull = false;
              if (c.x === w - 2 && c.y === gy) pull = false;
            }
          }
          if (pull) st = { ...st, pos: st.pos.map((q, i) => (moving.includes(i) ? { x: q.x - dx, y: q.y - dy } : q)) };
        }
      }
      st = { ...st, x: bx, y: by };
      trail.push(st);
    }
    // of the last places on the walk, start from the one farthest (in moves) from the room
    let far = null;
    for (const cand of trail.slice(-12)) {
      if (cand.x === w - 2 && cand.y === gy) continue;
      const gg = g.map((r) => [...r]);
      gg[cand.y][cand.x] = 'P';
      const lv = { map: gg.map((r) => r.join('')), panels: ps.map((p, i) => ({ ...p, x: cand.pos[i].x, y: cand.pos[i].y })) };
      const sl = L.Fusuma.solve(L.Fusuma.parse(lv));
      if (sl && sl.length <= hi && (!far || sl.length > far.n)) far = { st: cand, n: sl.length };
    }
    if (!far) continue;
    st = far.st;
    if (st.x === w - 2 && st.y === gy) continue;
    const g2 = g.map((r) => [...r]);
    g2[st.y][st.x] = 'P';
    if (lock) {
      const cands = innerCells(w, h).filter(([x, y]) => g2[y][x] === '.' && L.Fusuma.panelAt(b0, st, x, y) < 0);
      if (!cands.length) continue;
      g2[cands[0][1]][cands[0][0]] = 'k';
    }
    const fin = ps.map((p, i) => ({ ...p, x: st.pos[i].x, y: st.pos[i].y }));
    const level = { map: g2.map((r) => r.join('')), panels: fin };
    const b = L.Fusuma.parse(level);
    const sol = L.Fusuma.solve(b);
    if (!sol || sol.length < lo || sol.length > hi) continue;
    const open = L.Fusuma.solve(L.Fusuma.parse({ ...level, panels: [] }));
    if (!open || sol.length <= open.length + 2) continue;
    let s2 = L.Fusuma.init(b), n = 0, pair = 0;
    for (const d of sol) { const r = L.Fusuma.move(b, s2, d); if (r.push) { n++; if (r.push.moving.length > 1) pair++; } s2 = r.state; }
    if (n < pushes) continue;
    // the paired doors have to move together on the way
    if (link && pair < 1) continue;
    if (lock) {
      const sb = L.Fusuma.parse({ ...level, map: level.map.map((r) => r.replace('k', '.')) });
      sb.key = { x: -9, y: -9 };
      if (L.Fusuma.solve(sb)) continue;
    }
    if (!best || sol.length > best.par) best = { ...level, par: sol.length };
    if (best.par >= hi) break;
  }
  if (!best) throw new Error('fusuma: no level');
  return best;
}

// ------------------------------------------------------------------ dashi
const BITS = { up: 1, right: 2, down: 4, left: 8 };
const DSTEP = { up: [0, -1], right: [1, 0], down: [0, 1], left: [-1, 0] };
const OPPD = { up: 'down', down: 'up', left: 'right', right: 'left' };
function dirTo(a, b) { return b[0] > a[0] ? 'right' : b[0] < a[0] ? 'left' : b[1] > a[1] ? 'down' : 'up'; }
// random simple path from a to b avoiding `used`; `cross` lets it pass
// straight over cells of an earlier straight run
function route(w, h, a, b, used, { min = 0, max = 99, cross = null } = {}) {
  for (let attempt = 0; attempt < 400; attempt++) {
    const path = [a];
    const seen = new Set([`${a}`]);
    let ok = false;
    const rec = () => {
      const cur = path[path.length - 1];
      if (path.length > max) return false;
      for (const d of shuffle(['up', 'down', 'left', 'right'])) {
        const n = [cur[0] + DSTEP[d][0], cur[1] + DSTEP[d][1]];
        if (n[0] < 0 || n[1] < 0 || n[0] >= w || n[1] >= h || seen.has(`${n}`)) continue;
        if (n[0] === b[0] && n[1] === b[1]) {
          if (path.length + 1 >= min) { path.push(n); return true; }
          continue;
        }
        if (used.has(`${n}`)) {
          // a crossing: straight over a straight pipe, perpendicular to it
          if (!cross || !cross.has(`${n}`) || cross.get(`${n}`) === (d === 'up' || d === 'down' ? 'v' : 'h')) continue;
          const n2 = [n[0] + DSTEP[d][0], n[1] + DSTEP[d][1]];
          if (n2[0] < 0 || n2[1] < 0 || n2[0] >= w || n2[1] >= h || seen.has(`${n2}`) || (used.has(`${n2}`) && !(n2[0] === b[0] && n2[1] === b[1]))) continue;
          seen.add(`${n}`); path.push(n);
          if (n2[0] === b[0] && n2[1] === b[1]) { if (path.length + 1 >= min) { path.push(n2); return true; } path.pop(); seen.delete(`${n}`); continue; }
          seen.add(`${n2}`); path.push(n2);
          if (rec()) return true;
          path.pop(); seen.delete(`${n2}`); path.pop(); seen.delete(`${n}`);
          continue;
        }
        seen.add(`${n}`); path.push(n);
        if (rec()) return true;
        path.pop(); seen.delete(`${n}`);
      }
      return false;
    };
    ok = rec();
    if (ok) return path;
  }
  return null;
}
function maskToTile(m) {
  for (const [t, base] of Object.entries(L.Dashi.BASE)) for (let r = 0; r < 4; r++) if (L.Dashi.rot(base, r) === m && t !== '.') return [t, r];
  return ['.', 0];
}
function genDashi({ w, h, plan, fixed = 0, tries = 300 }) {
  for (let t = 0; t < tries; t++) {
    const cells = [];
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) cells.push([x, y]);
    shuffle(cells);
    const used = new Set();
    const masks = {};
    const addOpen = (c, d) => { masks[`${c}`] = (masks[`${c}`] || 0) | BITS[d]; };
    const specials = [];
    const straight = new Map(); // cells of single straight runs, for crossings
    const lay = (path) => {
      for (let i = 0; i < path.length - 1; i++) {
        const d = dirTo(path[i], path[i + 1]);
        addOpen(path[i], d);
        addOpen(path[i + 1], OPPD[d]);
      }
      path.forEach((c) => used.add(`${c}`));
    };
    const free = () => { const c = cells.find((cc) => !used.has(`${cc}`)); used.add(`${c}`); return c; };
    let ok = true;
    const sources = [], bowls = [];
    if (plan === 'single' || plan === 'separate' || plan === 'cross') {
      const pairs = plan === 'single' ? [['k', 'k']] : [['k', 'k'], ['n', 'n']];
      for (const [f, want] of pairs) {
        const a = free(), b = free();
        const path = route(w, h, a, b, used, { min: 4, max: w * h, cross: plan === 'cross' && sources.length ? straight : null });
        if (!path) { ok = false; break; }
        lay(path);
        sources.push({ x: a[0], y: a[1], f, dir: dirTo(a, path[1]) });
        bowls.push({ x: b[0], y: b[1], want, dir: dirTo(b, path[path.length - 2]) });
        if (plan === 'cross' && sources.length === 1) {
          for (let i = 1; i < path.length - 1; i++) {
            const p = path[i - 1], n = path[i + 1];
            if (p[0] === n[0]) straight.set(`${path[i]}`, 'v');
            if (p[1] === n[1]) straight.set(`${path[i]}`, 'h');
          }
        }
      }
      if (ok && plan === 'cross' && !Object.values(masks).some((m) => m === 15)) ok = false;
    } else if (plan === 'mix') {
      const m = free(), a = free(), b = free(), c = free();
      used.delete(`${m}`);
      const p1 = route(w, h, a, m, used, { min: 3, max: 8 });
      if (!p1) { ok = false; } else {
        lay(p1); used.delete(`${m}`);
        const p2 = route(w, h, b, m, used, { min: 3, max: 8 });
        if (!p2) ok = false; else {
          lay(p2); used.delete(`${m}`);
          const p3 = route(w, h, m, c, used, { min: 3, max: 8 });
          if (!p3) ok = false; else {
            lay(p3);
            sources.push({ x: a[0], y: a[1], f: 'k', dir: dirTo(a, p1[1]) }, { x: b[0], y: b[1], f: 'n', dir: dirTo(b, p2[1]) });
            bowls.push({ x: c[0], y: c[1], want: 'kn', dir: dirTo(c, p3[p3.length - 2]) });
          }
        }
      }
    }
    if (!ok) continue;
    const tiles = Array.from({ length: h }, () => Array(w).fill('.'));
    const answer = Array.from({ length: h }, () => Array(w).fill(0));
    for (const s of sources) tiles[s.y][s.x] = 'S';
    for (const b of bowls) tiles[b.y][b.x] = 'B';
    for (const [k, m] of Object.entries(masks)) {
      const [x, y] = k.split(',').map(Number);
      if (tiles[y][x] === 'S' || tiles[y][x] === 'B') continue;
      const [tt, r] = maskToTile(m);
      tiles[y][x] = tt;
      answer[y][x] = r;
    }
    // spare pipes in the empty cells
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (tiles[y][x] === '.' && rnd() < 0.6) tiles[y][x] = pick(['I', 'L', 'L']);
    const pathCells = Object.keys(masks).filter((k) => { const [x, y] = k.split(',').map(Number); return 'ILTX'.includes(tiles[y][x]); });
    const fixedSet = shuffle([...pathCells]).slice(0, fixed);
    const level = { tiles: tiles.map((r) => r.join('')), sources, bowls, answer: answer.map((r) => r.join('')), fixed: fixedSet };
    if (!L.Dashi.won(level, answer)) continue;
    // scramble the loose pipes
    const rotm = answer.map((r, y) => r.map((v, x) => (fixedSet.includes(`${x},${y}`) ? v : Math.floor(rnd() * 4))));
    if (L.Dashi.won(level, rotm)) continue;
    level.rot = rotm.map((r) => r.join(''));
    return level;
  }
  throw new Error('dashi: no level ' + plan);
}

const makers = {
  pack: () => [
    genPack({ box: ['...', '...', '..#'], sizes: [1, 2, 3], kinds: ['hot', 'cold', 'plain'], soup: true }),
    genPack({ box: ['....', '....', '....'], sizes: [2, 3, 4], kinds: ['hot', 'cold', 'plain'], soup: true }),
    genPack({ box: ['#..#', '....', '....', '....'], sizes: [2, 3, 4], kinds: ['hot', 'cold', 'plain'], soup: true }),
    genPack({ box: ['..#..', '.....', '.....', '#....'], sizes: [2, 3, 4], kinds: ['hot', 'cold', 'hot', 'cold', 'plain'], soup: true }),
  ],
  oden: () => [
    genOden({ w: 7, h: 6, walls: 2, pots: [2], par: [8, 16] }),
    genOden({ w: 7, h: 7, walls: 3, pots: [2, 1], par: [12, 24] }),
    genOden({ w: 7, h: 7, walls: 2, pots: [3], ice: 7, par: [12, 24] }),
    genOden({ w: 7, h: 7, walls: 3, pots: [2, 1], ice: 6, par: [14, 30] }),
  ],
  light: () => [
    genLight({ w: 6, h: 6, walls: 2, mirrors: 1, targets: 1, par: [5, 12] }),
    genLight({ w: 7, h: 7, walls: 3, mirrors: 2, targets: 2, par: [8, 18] }),
    genLight({ w: 7, h: 7, walls: 3, mirrors: 2, targets: 2, red: true, par: [8, 20] }),
    genLight({ w: 7, h: 7, walls: 3, mirrors: 2, targets: 2, blind: true, par: [6, 20] }),
  ],
  fusuma: () => [
    genFusuma({ w: 8, h: 6, panels: 4, walls: 2, pushes: 3, par: [9, 24] }),
    genFusuma({ w: 8, h: 7, panels: 4, walls: 3, pushes: 3, link: true, par: [10, 26] }),
    genFusuma({ w: 8, h: 7, panels: 5, walls: 2, pushes: 2, lock: true, par: [7, 30] }),
    genFusuma({ w: 8, h: 7, panels: 5, walls: 3, pushes: 2, link: true, lock: true, par: [8, 34] }),
  ],
  dashi: () => [
    genDashi({ w: 4, h: 4, plan: 'single' }),
    genDashi({ w: 5, h: 5, plan: 'mix' }),
    genDashi({ w: 5, h: 5, plan: 'separate', fixed: 3 }),
    genDashi({ w: 6, h: 6, plan: 'cross', fixed: 2 }),
  ],
};

// only the games named on the command line are made again (default: the
// ones missing from src/levels.js)
const file = path.join(__dirname, '../src/levels.js');
const save = (lv) => fs.writeFileSync(file, `// Generated by tool/gen.js — do not edit by hand.\n(function (root) {\n  root.LEVELS = ${JSON.stringify(lv)};\n  if (typeof module !== 'undefined') module.exports = root.LEVELS;\n})(typeof globalThis !== 'undefined' ? globalThis : this);\n`);
let levels = {};
try { levels = require(file); } catch (e) { levels = {}; }
const want = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(makers).filter((k) => !levels[k]);
const kept = {};
for (const k of Object.keys(makers)) {
  if (want.includes(k)) {
    const t0 = Date.now();
    kept[k] = makers[k]();
    console.log(`${k} made in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
    save({ ...levels, ...kept });
  } else if (levels[k]) kept[k] = levels[k];
}
levels = kept;

const out = `// Generated by tool/gen.js — do not edit by hand.
(function (root) {
  root.LEVELS = ${JSON.stringify(levels)};
  if (typeof module !== 'undefined') module.exports = root.LEVELS;
})(typeof globalThis !== 'undefined' ? globalThis : this);
`;
fs.writeFileSync(file, out);
for (const [k, v] of Object.entries(levels)) console.log(k, v.map((l) => l.par ?? (l.pieces ? l.pieces.length + ' pieces' : (l.tiles || []).join('/'))).join('  '));
