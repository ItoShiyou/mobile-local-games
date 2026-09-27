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

// ------------------------------------------------------------------ slide
function genSlide({ w, h, guests, mats, walls, par: [lo, hi], tries = 40000 }) {
  let best = null;
  for (let t = 0; t < tries; t++) {
    const g = Array.from({ length: h }, (_, y) => Array.from({ length: w }, (_, x) => (x === 0 || y === 0 || x === w - 1 || y === h - 1 ? '#' : '.')));
    const inner = [];
    for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) inner.push([x, y]);
    shuffle(inner);
    let k = 0;
    const put = (c, n) => { for (let i = 0; i < n; i++) { const [x, y] = inner[k++]; g[y][x] = c; } };
    put('P', 1); put('G', guests); put('o', mats); put('#', walls);
    const map = g.map((r) => r.join(''));
    const b = L.Slide.parse(map);
    const sol = L.Slide.solve(b);
    if (!sol || sol.length < lo || sol.length > hi) continue;
    // mats have to matter: without them the level is longer or impossible
    if (mats) {
      const plain = L.Slide.solve(L.Slide.parse(map.map((r) => r.replace(/o/g, '.'))));
      if (plain && plain.length <= sol.length) continue;
    }
    const score = sol.length;
    if (!best || score > best.par) best = { map, par: sol.length };
    if (best.par >= hi) break;
  }
  if (!best) throw new Error('slide: no level');
  return best;
}

// ----------------------------------------------------------------- stroke
function hamPath(w, h, blocked) {
  const open = (x, y) => x >= 0 && y >= 0 && x < w && y < h && !blocked.has(`${x},${y}`);
  const total = w * h - blocked.size;
  const cells = [];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (open(x, y)) cells.push([x, y]);
  for (let attempt = 0; attempt < 200; attempt++) {
    const [sx, sy] = pick(cells);
    const seen = new Set([`${sx},${sy}`]);
    const pathOut = [[sx, sy]];
    let steps = 0;
    const deg = (x, y) => [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([dx, dy]) => open(x + dx, y + dy) && !seen.has(`${x + dx},${y + dy}`)).length;
    const rec = () => {
      if (pathOut.length === total) return true;
      if (++steps > 20000) return false;
      const [x, y] = pathOut[pathOut.length - 1];
      const nb = shuffle([[1, 0], [-1, 0], [0, 1], [0, -1]]).map(([dx, dy]) => [x + dx, y + dy])
        .filter(([nx, ny]) => open(nx, ny) && !seen.has(`${nx},${ny}`))
        .sort((a, b) => deg(...a) - deg(...b));
      for (const [nx, ny] of nb) {
        seen.add(`${nx},${ny}`); pathOut.push([nx, ny]);
        if (rec()) return true;
        seen.delete(`${nx},${ny}`); pathOut.pop();
      }
      return false;
    };
    if (rec()) return pathOut;
  }
  return null;
}
function genStroke({ w, h, walls, nums }) {
  for (let t = 0; t < 400; t++) {
    const blocked = new Set();
    while (blocked.size < walls) blocked.add(`${Math.floor(rnd() * w)},${Math.floor(rnd() * h)}`);
    const p = hamPath(w, h, blocked);
    if (!p) continue;
    // numbers at both ends and spread along the way
    const idx = new Set([0, p.length - 1]);
    while (idx.size < nums) idx.add(1 + Math.floor(rnd() * (p.length - 2)));
    const make = () => {
      const g = Array.from({ length: h }, (_, y) => Array.from({ length: w }, (_, x) => (blocked.has(`${x},${y}`) ? '#' : '.')));
      [...idx].sort((a, b) => a - b).forEach((i, k) => { const [x, y] = p[i]; g[y][x] = (k + 1).toString(36); });
      return g.map((r) => r.join(''));
    };
    // add numbers until the round is the only one
    for (let extra = 0; extra < 6; extra++) {
      const map = make();
      if (L.Stroke.count(L.Stroke.parse(map), 2) === 1) return { map };
      idx.add(1 + Math.floor(rnd() * (p.length - 2)));
    }
  }
  throw new Error('stroke: no level');
}

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

// ------------------------------------------------------------------- sort
function genSort({ kinds, cap, empty, par: [lo, hi] }) {
  const names = ['a', 'b', 'c', 'd', 'e'].slice(0, kinds);
  let best = null;
  for (let t = 0; t < 300; t++) {
    const plates = shuffle(names.flatMap((n) => Array(cap).fill(n)));
    const stacks = [];
    for (let i = 0; i < kinds; i++) stacks.push(plates.slice(i * cap, (i + 1) * cap).join(''));
    for (let i = 0; i < empty; i++) stacks.push('');
    const level = { cap, stacks: stacks.map((s) => [...s]) };
    if (stacks.some((s) => s.length && [...s].every((c) => c === s[0]))) continue;
    const sol = L.Sort.solve(level);
    if (!sol || sol.length < lo || sol.length > hi) continue;
    if (!best || sol.length > best.par) best = { cap, stacks, par: sol.length };
    if (best.par >= hi) break;
  }
  if (!best) throw new Error('sort: no level');
  return best;
}

// ----------------------------------------------------------------- deduce
const DISHES = ['ramen', 'soba', 'sushi', 'tamago', 'onigiri', 'gyoza'];
function genDeduce({ n, maxNot }) {
  for (let t = 0; t < 2000; t++) {
    const dishes = shuffle([...DISHES]).slice(0, n);
    const answer = shuffle([...dishes]);
    const cand = [];
    for (let s = 0; s < n; s++) for (const d of dishes) if (answer[s] !== d) cand.push({ t: 'not', seat: s, a: d });
    for (const a of dishes) for (const b of dishes) if (a < b && L.Deduce.holds({ t: 'adj', a, b }, answer)) cand.push({ t: 'adj', a, b });
    for (const a of dishes) for (const b of dishes) if (a !== b && L.Deduce.holds({ t: 'left', a, b }, answer)) cand.push({ t: 'left', a, b });
    for (const a of dishes) cand.push(L.Deduce.holds({ t: 'end', a }, answer) ? { t: 'end', a } : { t: 'mid', a });
    shuffle(cand);
    const clues = [];
    const count = (cs) => L.Deduce.solutions({ dishes, clues: cs }).length;
    let nots = 0;
    for (const c of cand) {
      if (c.t === 'not' && nots >= maxNot) continue;
      if (count([...clues, c]) < count(clues)) { clues.push(c); if (c.t === 'not') nots++; }
      if (count(clues) === 1) break;
    }
    if (count(clues) !== 1) continue;
    // drop anything that is not needed
    for (let i = clues.length - 1; i >= 0; i--) {
      const rest = clues.filter((_, j) => j !== i);
      if (count(rest) === 1) clues.splice(i, 1);
    }
    if (clues.length < n - 1 || clues.length > n + 2) continue;
    return { dishes, clues, answer };
  }
  throw new Error('deduce: no level');
}

const levels = {
  slide: [
    genSlide({ w: 6, h: 6, guests: 2, mats: 0, walls: 2, par: [3, 5] }),
    genSlide({ w: 7, h: 7, guests: 3, mats: 1, walls: 3, par: [5, 8] }),
    genSlide({ w: 7, h: 8, guests: 3, mats: 2, walls: 4, par: [7, 11] }),
    genSlide({ w: 8, h: 8, guests: 4, mats: 2, walls: 5, par: [9, 14] }),
  ],
  pack: [
    genPack({ box: ['...', '...', '..#'], sizes: [1, 2, 3], kinds: ['hot', 'cold', 'plain'], soup: true }),
    genPack({ box: ['....', '....', '....'], sizes: [2, 3, 4], kinds: ['hot', 'cold', 'plain'], soup: true }),
    genPack({ box: ['#..#', '....', '....', '....'], sizes: [2, 3, 4], kinds: ['hot', 'cold', 'plain'], soup: true }),
    genPack({ box: ['..#..', '.....', '.....', '#....'], sizes: [2, 3, 4], kinds: ['hot', 'cold', 'hot', 'cold', 'plain'], soup: true }),
  ],
  stroke: [
    genStroke({ w: 4, h: 4, walls: 0, nums: 4 }),
    genStroke({ w: 5, h: 5, walls: 1, nums: 5 }),
    genStroke({ w: 5, h: 6, walls: 2, nums: 5 }),
    genStroke({ w: 6, h: 6, walls: 2, nums: 6 }),
  ],
  sort: [
    genSort({ kinds: 3, cap: 3, empty: 2, par: [5, 8] }),
    genSort({ kinds: 3, cap: 4, empty: 2, par: [9, 13] }),
    genSort({ kinds: 4, cap: 4, empty: 2, par: [14, 20] }),
    genSort({ kinds: 5, cap: 4, empty: 2, par: [20, 28] }),
  ],
  deduce: [
    genDeduce({ n: 3, maxNot: 1 }),
    genDeduce({ n: 4, maxNot: 1 }),
    genDeduce({ n: 4, maxNot: 0 }),
    genDeduce({ n: 5, maxNot: 1 }),
  ],
};

const out = `// Generated by tool/gen.js — do not edit by hand.\n(function (root) {\n  root.LEVELS = ${JSON.stringify(levels)};\n  if (typeof module !== 'undefined') module.exports = root.LEVELS;\n})(typeof globalThis !== 'undefined' ? globalThis : this);\n`;
fs.writeFileSync(path.join(__dirname, '../src/levels.js'), out);
for (const [k, v] of Object.entries(levels)) console.log(k, v.map((l) => l.par ?? (l.clues ? l.clues.length + ' clues' : l.pieces ? l.pieces.length + ' pieces' : l.map.join('/'))).join('  '));
