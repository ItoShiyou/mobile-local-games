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

  // ---------------------------------------------------------------- 1. slide
  // After the rain the street is slick: the cart slides until something
  // stops it. Sliding into a guest hands over their order. Straw mats stop
  // the cart on them.
  const Slide = {
    parse(map) {
      const h = map.length, w = map[0].length;
      const guests = [];
      let start = null;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const c = map[y][x];
        if (c === 'P') start = { x, y };
        if (c === 'G') guests.push({ x, y });
      }
      return { w, h, map, guests, start };
    },
    cell(b, x, y) { return x < 0 || y < 0 || x >= b.w || y >= b.h ? '#' : b.map[y][x]; },
    guestAt(b, x, y) { return b.guests.findIndex((g) => g.x === x && g.y === y); },
    init(b) { return { x: b.start.x, y: b.start.y, served: 0 }; },
    // returns { state, path:[{x,y}], served:index|-1 } or null when nothing happens
    move(b, s, dir) {
      const [dx, dy] = DIRS[dir];
      let x = s.x, y = s.y;
      const path = [];
      let hit = -1;
      for (;;) {
        const nx = x + dx, ny = y + dy;
        const g = Slide.guestAt(b, nx, ny);
        if (g >= 0) { hit = g; break; }
        if (Slide.cell(b, nx, ny) === '#') break;
        x = nx; y = ny;
        path.push({ x, y });
        if (Slide.cell(b, x, y) === 'o') break;
      }
      const newServe = hit >= 0 && !(s.served & (1 << hit));
      if (!path.length && !newServe) return null;
      return { state: { x, y, served: newServe ? s.served | (1 << hit) : s.served }, path, served: newServe ? hit : -1 };
    },
    won(b, s) { return s.served === (1 << b.guests.length) - 1; },
    solve(b) {
      return bfs(Slide.init(b), (s) => `${s.x},${s.y},${s.served}`,
        (s) => DIR_LIST.map((d) => [d, Slide.move(b, s, d)]).filter(([, r]) => r).map(([d, r]) => [d, r.state]),
        (s) => Slide.won(b, s));
    },
  };

  // ---------------------------------------------------------------- 2. pack
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

  // --------------------------------------------------------------- 3. stroke
  // One round of the neighbourhood: walk every lane exactly once, calling at
  // the numbered houses in order.
  const Stroke = {
    parse(map) {
      const h = map.length, w = map[0].length;
      const nums = {};
      let open = 0;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const c = map[y][x];
        if (c !== '#') open++;
        if (/[0-9a-z]/.test(c) && c !== '.') nums[`${x},${y}`] = parseInt(c, 36);
      }
      const last = Math.max(...Object.values(nums));
      const start = Object.entries(nums).find(([, v]) => v === 1)[0].split(',').map(Number);
      return { w, h, map, nums, last, open, start: { x: start[0], y: start[1] } };
    },
    open(b, x, y) { return x >= 0 && y >= 0 && x < b.w && y < b.h && b.map[y][x] !== '#'; },
    // can the path (list of {x,y}) be extended to (x,y)?
    canStep(b, path, x, y) {
      const t = path[path.length - 1];
      if (Math.abs(t.x - x) + Math.abs(t.y - y) !== 1 || !Stroke.open(b, x, y)) return false;
      if (path.some((p) => p.x === x && p.y === y)) return false;
      const n = b.nums[`${x},${y}`];
      if (n === undefined) return true;
      return n === Stroke.nextNumber(b, path);
    },
    nextNumber(b, path) {
      let k = 1;
      for (const p of path) { const n = b.nums[`${p.x},${p.y}`]; if (n !== undefined) k = n + 1; }
      return k;
    },
    won(b, path) {
      const t = path[path.length - 1];
      return path.length === b.open && b.nums[`${t.x},${t.y}`] === b.last;
    },
    count(b, cap = 2) {
      let n = 0;
      const path = [b.start];
      const seen = new Set([`${b.start.x},${b.start.y}`]);
      const rec = () => {
        if (n >= cap) return;
        if (Stroke.won(b, path)) { n++; return; }
        const t = path[path.length - 1];
        for (const [dx, dy] of Object.values(DIRS)) {
          const x = t.x + dx, y = t.y + dy, k = `${x},${y}`;
          if (seen.has(k) || !Stroke.canStep(b, path, x, y)) continue;
          seen.add(k); path.push({ x, y });
          rec();
          path.pop(); seen.delete(k);
        }
      };
      rec();
      return n;
    },
  };

  // ----------------------------------------------------------------- 4. sort
  // Stall counters with mixed plates. Carry the top plate to another
  // counter (empty, or with the same dish on top) until every counter holds
  // one dish only.
  const Sort = {
    init(level) { return level.stacks.map((s) => [...s]); },
    canMove(level, st, i, j) {
      if (i === j || !st[i].length || st[j].length >= level.cap) return false;
      return !st[j].length || st[j][st[j].length - 1] === st[i][st[i].length - 1];
    },
    move(level, st, i, j) {
      if (!Sort.canMove(level, st, i, j)) return null;
      const n = st.map((s) => [...s]);
      n[j].push(n[i].pop());
      return n;
    },
    won(level, st) {
      return st.every((s) => !s.length || (s.length === level.cap && s.every((d) => d === s[0])));
    },
    solve(level) {
      return bfs(Sort.init(level), (st) => st.map((s) => s.join('')).sort().join('|'),
        (st) => {
          const out = [];
          for (let i = 0; i < st.length; i++) for (let j = 0; j < st.length; j++) {
            const n = Sort.move(level, st, i, j);
            if (n) out.push([[i, j], n]);
          }
          return out;
        },
        (st) => Sort.won(level, st));
    },
  };

  // --------------------------------------------------------------- 5. deduce
  // Overheard at the counter: work out who ordered what from what the
  // regulars say, then serve everyone at once.
  function permutations(a) {
    if (a.length <= 1) return [a];
    return a.flatMap((x, i) => permutations([...a.slice(0, i), ...a.slice(i + 1)]).map((p) => [x, ...p]));
  }
  const Deduce = {
    permutations,
    // clue: {t:'is'|'not'|'adj'|'left'|'end'|'mid', seat?, a?, b?}
    holds(c, asg) {
      const pos = (d) => asg.indexOf(d);
      const n = asg.length;
      switch (c.t) {
        case 'is': return asg[c.seat] === c.a;
        case 'not': return asg[c.seat] !== c.a;
        case 'adj': return Math.abs(pos(c.a) - pos(c.b)) === 1;
        case 'left': return pos(c.a) < pos(c.b);
        case 'end': return pos(c.a) === 0 || pos(c.a) === n - 1;
        case 'mid': return pos(c.a) !== 0 && pos(c.a) !== n - 1;
        default: return false;
      }
    },
    solutions(level) {
      return permutations(level.dishes).filter((p) => level.clues.every((c) => Deduce.holds(c, p)));
    },
  };

  root.Logic = { DIRS, DIR_LIST, bfs, Slide, Pack, Stroke, Sort, Deduce };
  if (typeof module !== 'undefined') module.exports = root.Logic;
})(typeof globalThis !== 'undefined' ? globalThis : this);
