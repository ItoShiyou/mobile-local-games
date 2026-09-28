// The mock games. Each one draws into a canvas of the width it is
// given and handles pointer input in canvas pixels (CSS px).
const { Pack } = Logic;
const ease = (p) => 1 - Math.pow(1 - Math.min(1, Math.max(0, p)), 3);
const now = () => performance.now() / 1000;

function paperTile(ctx, x, y, w, h, fill) {
  ctx.fillStyle = fill;
  ctx.fillRect(x, y, w, h);
}

// ======================================================================
// 0. おかもち詰め (kept from the first round) — pack the delivery box
// ======================================================================
class PackGame {
  constructor(level, api) {
    this.api = api;
    this.level = level;
    this.rot = level.pieces.map((p) => p.cells);
    this.placed = [];
    this.hist = [];
    this.moves = 0;
    this.drag = null;
    this.problemAt = 0;
  }
  layout(w) {
    const L = this.level;
    const bw = L.box[0].length, bh = L.box.length;
    this.cell = Math.floor(Math.min((w - 40) / bw, 58));
    this.bx = Math.floor((w - this.cell * bw) / 2);
    this.by = 16;
    this.w = w;
    // tray below, pieces laid out left to right in rows, each in a slot
    // big enough for any turn of it
    this.tc = Math.floor(this.cell * 0.72);
    let x = 12, y = this.by + this.cell * bh + 40, rowH = 0;
    this.trayTop = y - 16;
    this.slots = this.level.pieces.map((p) => {
      const ext = Math.max(...p.cells.map((c) => Math.max(c[0], c[1]))) + 1;
      const box = ext * this.tc + 8;
      if (x + box > w - 8) { x = 12; y += rowH + 10; rowH = 0; }
      const slot = { x, y, w: box, h: box };
      x += box + 10;
      rowH = Math.max(rowH, box);
      return slot;
    });
    return y + rowH + 18;
  }
  status() { return { moves: this.moves, par: this.level.pieces.length, label: `${this.placed.length}/${this.level.pieces.length}品` }; }
  canUndo() { return this.hist.length > 0; }
  undo() {
    if (!this.hist.length) return;
    const h = this.hist.pop();
    this.placed = h.placed;
    this.rot = h.rot;
    this.moves--;
  }
  snapshot() { this.hist.push({ placed: this.placed.map((p) => ({ ...p })), rot: [...this.rot] }); }
  inTray(i) { return !this.placed.some((p) => p.piece === i); }
  pieceAtBox(x, y) {
    const gx = Math.floor((x - this.bx) / this.cell), gy = Math.floor((y - this.by) / this.cell);
    return this.placed.find((p) => p.cells.some(([cx, cy]) => p.x + cx === gx && p.y + cy === gy));
  }
  down(x, y) {
    const onBox = this.pieceAtBox(x, y);
    if (onBox) {
      this.drag = { piece: onBox.piece, from: 'box', cells: onBox.cells, x, y, x0: x, y0: y, src: onBox };
      return;
    }
    const i = this.slots.findIndex((s, k) => this.inTray(k) && x >= s.x && x <= s.x + s.w && y >= s.y && y <= s.y + s.h);
    if (i >= 0) this.drag = { piece: i, from: 'tray', cells: this.rot[i], x, y, x0: x, y0: y };
  }
  move(x, y) { if (this.drag) { this.drag.x = x; this.drag.y = y; } }
  up(x, y) {
    const d = this.drag;
    this.drag = null;
    if (!d) return;
    const tap = Math.hypot(x - d.x0, y - d.y0) < 8;
    const others = this.placed.filter((p) => p.piece !== d.piece);
    if (tap) {
      // tap turns the dish
      const r = Pack.rotate(d.cells);
      this.snapshot();
      if (d.from === 'tray') { this.rot[d.piece] = r; this.hist.pop(); return; }
      if (Pack.canPlace(this.level, others, d.piece, r, d.src.x, d.src.y)) {
        this.placed = [...others, { piece: d.piece, x: d.src.x, y: d.src.y, cells: r }];
      } else {
        this.placed = others;
        this.rot[d.piece] = r;
      }
      this.after();
      return;
    }
    // drop where the dragged dish's top-left cell lands
    const g = this.ghost(d);
    const gx = Math.round((g.x - this.bx) / this.cell), gy = Math.round((g.y - this.by) / this.cell);
    this.snapshot();
    if (Pack.canPlace(this.level, others, d.piece, d.cells, gx, gy)) {
      this.placed = [...others, { piece: d.piece, x: gx, y: gy, cells: d.cells }];
      this.moves++;
    } else {
      this.placed = others;
      this.rot[d.piece] = d.cells;
      if (d.from === 'tray') this.hist.pop();
    }
    this.after();
  }
  after() {
    const pr = Pack.problems(this.level, this.placed);
    if (pr.clash.size || pr.floating.size) this.problemAt = now();
    if (Pack.won(this.level, this.placed)) setTimeout(() => this.api.won(this.status()), 500);
  }
  // top-left of a dragged dish, drawn at box scale under the finger
  ghost(d) {
    const u = this.cell;
    const w = Math.max(...d.cells.map((c) => c[0])) + 1, h = Math.max(...d.cells.map((c) => c[1])) + 1;
    return { x: d.x - (w * u) / 2, y: d.y - (h * u) / 2 - u * 0.6, u };
  }
  drawPiece(ctx, i, cells, ox, oy, u, o = {}) {
    const p = this.level.pieces[i];
    const fill = { hot: '#F7CBAE', cold: '#CFE4F2', plain: '#F4E7C9' }[p.kind];
    const lw = Math.max(1.2, u * 0.05);
    const set = new Set(cells.map(([x, y]) => `${x},${y}`));
    ctx.save();
    if (o.alpha) ctx.globalAlpha = o.alpha;
    for (const [cx, cy] of cells) paperTile(ctx, ox + cx * u, oy + cy * u, u + 0.5, u + 0.5, fill);
    // texture: steam for hot, frost for cold
    for (const [cx, cy] of cells) {
      const X = ox + cx * u, Y = oy + cy * u;
      ctx.strokeStyle = p.kind === 'hot' ? 'rgba(200,69,47,.35)' : p.kind === 'cold' ? 'rgba(60,120,170,.35)' : 'rgba(125,103,84,.18)';
      ctx.lineWidth = Math.max(1, u * 0.035);
      ctx.beginPath();
      if (p.kind === 'hot') {
        for (const k of [0.3, 0.7]) { ctx.moveTo(X + u * k, Y + u * 0.8); ctx.bezierCurveTo(X + u * (k - 0.1), Y + u * 0.6, X + u * (k + 0.1), Y + u * 0.4, X + u * k, Y + u * 0.2); }
      } else if (p.kind === 'cold') {
        for (const [a, b2] of [[0.25, 0.25], [0.75, 0.7]]) { const r = u * 0.08; ctx.moveTo(X + u * a - r, Y + u * b2); ctx.lineTo(X + u * a + r, Y + u * b2); ctx.moveTo(X + u * a, Y + u * b2 - r); ctx.lineTo(X + u * a, Y + u * b2 + r); }
      }
      ctx.stroke();
    }
    // outline only the outer edges, so one dish reads as one shape
    ctx.strokeStyle = o.warn ? C.shu : C.ink;
    ctx.lineWidth = o.warn ? lw * 2 : lw;
    ctx.lineCap = 'round';
    ctx.beginPath();
    for (const [cx, cy] of cells) {
      const X = ox + cx * u, Y = oy + cy * u;
      if (!set.has(`${cx},${cy - 1}`)) { ctx.moveTo(X, Y); ctx.lineTo(X + u, Y); }
      if (!set.has(`${cx},${cy + 1}`)) { ctx.moveTo(X, Y + u); ctx.lineTo(X + u, Y + u); }
      if (!set.has(`${cx - 1},${cy}`)) { ctx.moveTo(X, Y); ctx.lineTo(X, Y + u); }
      if (!set.has(`${cx + 1},${cy}`)) { ctx.moveTo(X + u, Y); ctx.lineTo(X + u, Y + u); }
    }
    ctx.stroke();
    // the dish on the cell nearest the middle
    const mx = cells.reduce((s, c) => s + c[0], 0) / cells.length, my = cells.reduce((s, c) => s + c[1], 0) / cells.length;
    const [fx, fy] = cells.slice().sort((a, b) => Math.hypot(a[0] - mx, a[1] - my) - Math.hypot(b[0] - mx, b[1] - my))[0];
    Art.food(ctx, p.food, ox + (fx + 0.5) * u, oy + (fy + 0.5) * u, u * 0.3);
    if (p.soup) {
      // soups show a little arrow pointing to the floor of the box
      const X = ox + (fx + 0.5) * u, Y = oy + (fy + 0.92) * u;
      ctx.fillStyle = o.floating ? C.shu : C.inkSoft;
      ctx.beginPath(); ctx.moveTo(X - u * 0.1, Y - u * 0.1); ctx.lineTo(X + u * 0.1, Y - u * 0.1); ctx.lineTo(X, Y); ctx.closePath(); ctx.fill();
    }
    ctx.restore();
  }
  draw(ctx, t) {
    const L = this.level, u = this.cell;
    const bw = L.box[0].length, bh = L.box.length;
    // the okamochi: lacquered box with a brass handle
    const X = this.bx, Y = this.by;
    ctx.fillStyle = '#6E2A20';
    Art.rr(ctx, X - 12, Y - 10, bw * u + 24, bh * u + 22, 8);
    Art.inked(ctx, '#7A3024', 2);
    ctx.strokeStyle = '#B08A45';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(X + bw * u * 0.3, Y - 10); ctx.lineTo(X + bw * u * 0.3, Y - 16); ctx.lineTo(X + bw * u * 0.7, Y - 16); ctx.lineTo(X + bw * u * 0.7, Y - 10);
    ctx.stroke();
    for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) {
      const cx = X + x * u, cy = Y + y * u;
      if (L.box[y][x] === '#') {
        paperTile(ctx, cx, cy, u + 0.5, u + 0.5, '#5C241B');
        continue;
      }
      paperTile(ctx, cx, cy, u + 0.5, u + 0.5, '#EADAB9');
      ctx.strokeStyle = 'rgba(58,43,34,.2)';
      ctx.lineWidth = 1;
      ctx.strokeRect(cx + 0.5, cy + 0.5, u - 1, u - 1);
    }
    // shelf boards between rows
    for (let y = 1; y < bh; y++) {
      ctx.fillStyle = 'rgba(110,42,32,.35)';
      ctx.fillRect(X, Y + y * u - 1.5, bw * u, 3);
    }
    const pr = Pack.problems(L, this.placed);
    const shake = now() - this.problemAt < 0.4 ? Math.sin((now() - this.problemAt) * 50) * 2 : 0;
    for (const p of this.placed) {
      if (this.drag && this.drag.piece === p.piece) continue;
      const warn = pr.clash.has(p.piece);
      this.drawPiece(ctx, p.piece, p.cells, X + p.x * u + (warn ? shake : 0), Y + p.y * u, u, { warn, floating: pr.floating.has(p.piece) });
    }
    // tray
    Art.rr(ctx, 6, this.trayTop, this.w - 12, 8, 3);
    Art.inked(ctx, C.woodDark, 1.5);
    this.slots.forEach((s, i) => {
      if (!this.inTray(i) || (this.drag && this.drag.piece === i)) return;
      const cells = this.rot[i];
      const w = Math.max(...cells.map((c) => c[0])) + 1, h = Math.max(...cells.map((c) => c[1])) + 1;
      this.drawPiece(ctx, i, cells, s.x + (s.w - w * this.tc) / 2, s.y + (s.h - h * this.tc) / 2, this.tc);
    });
    // the dish being dragged, at box scale
    if (this.drag && Math.hypot(this.drag.x - this.drag.x0, this.drag.y - this.drag.y0) >= 8) {
      const g = this.ghost(this.drag);
      const gx = Math.round((g.x - this.bx) / u), gy = Math.round((g.y - this.by) / u);
      const others = this.placed.filter((p) => p.piece !== this.drag.piece);
      if (Pack.canPlace(L, others, this.drag.piece, this.drag.cells, gx, gy)) {
        ctx.fillStyle = 'rgba(255,197,107,.35)';
        for (const [cx, cy] of this.drag.cells) ctx.fillRect(X + (gx + cx) * u, Y + (gy + cy) * u, u, u);
      }
      this.drawPiece(ctx, this.drag.piece, this.drag.cells, g.x, g.y, u, { alpha: 0.9 });
    }
    // the cat waits beside the box with the lid
    Art.cat(ctx, Math.max(28, X - 34), Y + bh * u - 22, 16, { facing: 'right', t, noShadow: false });
  }
}

// ======================================================================
// Shared: a cat walking a grid, pushing things (oden, light, fusuma)
// ======================================================================
class GridGame {
  constructor(level, api, rules, board) {
    this.api = api;
    this.level = level;
    this.R = rules;
    this.b = board;
    this.s = rules.init(board);
    this.prev = this.s;
    this.hist = [];
    this.moves = 0;
    this.facing = 'down';
    this.anim = null;
    this.W = (board.map || level.map)[0].length;
    this.H = (board.map || level.map).length;
  }
  layout(w) {
    this.u = Math.floor(Math.min(w / this.W, 60));
    this.ox = Math.floor((w - this.u * this.W) / 2);
    this.oy = 8;
    return this.u * this.H + 16;
  }
  status() { return { moves: this.moves, par: this.level.par }; }
  canUndo() { return this.hist.length > 0; }
  undo() {
    if (!this.hist.length) return;
    this.s = this.hist.pop();
    this.prev = this.s;
    this.anim = null;
    this.moves--;
  }
  won() { return this.R.won(this.b, this.s); }
  go(dir) {
    if (this.won()) return;
    if (this.anim && now() - this.anim.t0 < this.anim.dur * 0.6) return;
    this.facing = dir;
    const r = this.R.move(this.b, this.s, dir);
    if (!r || !r.state) { this.bump = { dir, t: now(), info: r }; return; }
    this.hist.push(this.s);
    this.prev = this.s;
    this.s = r.state;
    this.last = r;
    this.anim = { t0: now(), dur: 0.14 + (r.push && r.push.path ? r.push.path.length * 0.06 : 0) };
    this.moves++;
    if (this.won()) setTimeout(() => this.api.won(this.status()), 650);
  }
  p() { return this.anim ? Math.min(1, (now() - this.anim.t0) / this.anim.dur) : 1; }
  cellC(x, y) { return { x: this.ox + (x + 0.5) * this.u, y: this.oy + (y + 0.5) * this.u }; }
  catAt() {
    const e = ease(this.p());
    const x = this.prev.x + (this.s.x - this.prev.x) * e, y = this.prev.y + (this.s.y - this.prev.y) * e;
    let bx = 0, by = 0;
    if (this.bump && now() - this.bump.t < 0.25) {
      const d = Logic.DIRS[this.bump.dir];
      const k = Math.sin(((now() - this.bump.t) / 0.25) * Math.PI) * this.u * 0.1;
      bx = d[0] * k; by = d[1] * k;
    }
    const c = this.cellC(x, y);
    return { x: c.x + bx, y: c.y + by };
  }
  bumped(since = 0.4) { return this.bump && now() - this.bump.t < since ? this.bump : null; }
  down(x, y) { this.p0 = { x, y }; }
  up(x, y) {
    if (!this.p0) return;
    let dx = x - this.p0.x, dy = y - this.p0.y;
    this.p0 = null;
    if (Math.hypot(dx, dy) < 14) {
      const c = this.cellC(this.s.x, this.s.y);
      dx = x - c.x; dy = y - c.y;
      if (Math.hypot(dx, dy) < this.u * 0.4) return;
    }
    this.go(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'));
  }
  key(k) {
    const m = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' }[k];
    if (m) this.go(m);
  }
  drawCat(ctx, t, o = {}) {
    const c = this.catAt();
    Art.cat(ctx, c.x, c.y - this.u * 0.16, this.u * 0.23, { facing: this.facing, t, happy: this.won(), ...o });
  }
}

// ======================================================================
// 1. おでん仕込み — push the ingredients into the pot, in recipe order
// ======================================================================
const ODEN = { d: 'daikon', e: 'egg', c: 'chikuwa', k: 'konnyaku', g: 'ganmo' };
const POT_MARK = [['一', '#C8452F'], ['二', '#2F4B6B']];
class OdenGame extends GridGame {
  constructor(level, api) {
    const b = Logic.Oden.parse(level);
    super(level, api, Logic.Oden, b);
  }
  layout(w) {
    const h = super.layout(w);
    this.w = w;
    this.oy += 52; // recipe cards above the kitchen
    return h + 52;
  }
  draw(ctx, t) {
    const { b, u } = this;
    const s = this.s, P = this.p();
    for (let y = 0; y < this.H; y++) for (let x = 0; x < this.W; x++) {
      const X = this.ox + x * u, Y = this.oy + y * u;
      const c = b.map[y][x];
      if (c === '#') {
        paperTile(ctx, X, Y, u + 0.5, u + 0.5, '#9A7250');
        ctx.fillStyle = 'rgba(255,255,255,.08)';
        ctx.fillRect(X, Y + u * 0.1, u, u * 0.12);
        continue;
      }
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, (x + y) % 2 ? '#EAD9B8' : '#E3CFAA');
      ctx.strokeStyle = 'rgba(58,43,34,.12)';
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(X, Y + u * 0.5); ctx.lineTo(X + u, Y + u * 0.5); ctx.stroke();
      if (c === '_') {
        // slippery wet boards
        Art.rr(ctx, X + 2, Y + 2, u - 4, u - 4, u * 0.1);
        ctx.fillStyle = 'rgba(134,184,218,.55)';
        ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,.8)';
        ctx.lineWidth = Math.max(1, u * 0.04);
        ctx.beginPath(); ctx.moveTo(X + u * 0.2, Y + u * 0.35); ctx.lineTo(X + u * 0.45, Y + u * 0.25); ctx.moveTo(X + u * 0.55, Y + u * 0.72); ctx.lineTo(X + u * 0.8, Y + u * 0.62); ctx.stroke();
      }
    }
    // pots with their recipe cards
    const bump = this.bumped(0.6);
    b.pots.forEach((pot, i) => {
      const c = this.cellC(pot.x, pot.y);
      Art.ellipse(ctx, c.x, c.y + u * 0.08, u * 0.44, u * 0.34, '#4A3A30', Math.max(1.2, u * 0.04));
      Art.ellipse(ctx, c.x, c.y - u * 0.02, u * 0.36, u * 0.22, '#C99A55', Math.max(1, u * 0.03));
      // what is already in the pot
      pot.recipe.slice(0, s.prog[i]).split('').forEach((k, j) => Art.food(ctx, ODEN[k], c.x + (j - 1) * u * 0.18, c.y - u * 0.04, u * 0.1));
      // steam
      ctx.strokeStyle = 'rgba(255,255,255,.7)';
      ctx.lineWidth = Math.max(1, u * 0.03);
      for (const k of [-1, 1]) {
        const sway = Math.sin(t * 2 + k) * u * 0.04;
        ctx.beginPath(); ctx.moveTo(c.x + k * u * 0.12, c.y - u * 0.2); ctx.quadraticCurveTo(c.x + k * u * 0.2 + sway, c.y - u * 0.35, c.x + k * u * 0.1, c.y - u * 0.48); ctx.stroke();
      }
      // a mark on the pot matching its recipe card
      const [ch, col] = POT_MARK[i];
      Art.ellipse(ctx, c.x + u * 0.34, c.y - u * 0.3, u * 0.14, u * 0.14, col, 1.2);
      ctx.fillStyle = '#FFF7EA';
      ctx.font = `${u * 0.18}px "Yusei Magic", sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(ch, c.x + u * 0.34, c.y - u * 0.29);
    });
    // recipe cards: ingredients in order, the next one marked
    const wrongPot = bump && bump.info === null ? (() => {
      const [dx, dy] = Logic.DIRS[bump.dir];
      const it = s.items.find((q) => q.x === s.x + dx && q.y === s.y + dy);
      return it ? b.pots.findIndex((pp) => pp.x === it.x + dx && pp.y === it.y + dy) : -1;
    })() : -1;
    let rx = 8;
    b.pots.forEach((pot, i) => {
      const n = pot.recipe.length;
      const cw = 34;
      const W = 30 + n * cw;
      const shake = wrongPot === i ? Math.sin((now() - bump.t) * 50) * 3 : 0;
      const X = rx + shake, Y = 6;
      Art.rr(ctx, X, Y, W, 40, 5);
      Art.inked(ctx, '#FFFBF2', 1.4);
      const [ch, col] = POT_MARK[i];
      Art.ellipse(ctx, X + 15, Y + 20, 10, 10, col, 1.2);
      ctx.fillStyle = '#FFF7EA';
      ctx.font = '13px "Yusei Magic", sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(ch, X + 15, Y + 21);
      pot.recipe.split('').forEach((k, j) => {
        const done = j < s.prog[i], next = j === s.prog[i];
        const cx = X + 30 + (j + 0.5) * cw;
        if (next) {
          ctx.strokeStyle = wrongPot === i ? C.shu : '#E0A93A';
          ctx.lineWidth = 2.2;
          Art.rr(ctx, cx - cw / 2 + 2, Y + 4, cw - 4, 32, 4);
          ctx.stroke();
        }
        ctx.globalAlpha = done ? 0.3 : 1;
        Art.food(ctx, ODEN[k], cx, Y + 20, 11);
        ctx.globalAlpha = 1;
        if (done) Art.hanko(ctx, cx + 8, Y + 12, 7, '済');
        if (j < n - 1) { ctx.fillStyle = C.inkSoft; ctx.font = '10px sans-serif'; ctx.fillText('›', cx + cw / 2, Y + 20); }
      });
      rx += W + 10;
    });
    // ingredients (the one just pushed slides along its path)
    const push = this.anim && P < 1 && this.last && this.last.push;
    s.items.forEach((it) => {
      let c = this.cellC(it.x, it.y);
      if (push && push.into < 0 && push.path.length && push.path[push.path.length - 1].x === it.x && push.path[push.path.length - 1].y === it.y) {
        const a = this.cellC(push.from.x, push.from.y);
        c = { x: a.x + (c.x - a.x) * ease(P), y: a.y + (c.y - a.y) * ease(P) };
      }
      Art.shadow(ctx, c.x, c.y + u * 0.28, u * 0.28, u * 0.08);
      Art.food(ctx, ODEN[it.k], c.x, c.y, u * 0.3);
    });
    if (push && push.into >= 0) {
      const a = this.cellC(push.from.x, push.from.y), pot = b.pots[push.into], z = this.cellC(pot.x, pot.y);
      const e = ease(P);
      Art.food(ctx, ODEN[push.k], a.x + (z.x - a.x) * e, a.y + (z.y - a.y) * e - Math.sin(e * Math.PI) * u * 0.3, u * 0.3 * (1 - e * 0.5));
    }
    this.drawCat(ctx, t);
  }
}

// ======================================================================
// 2. あかり届け — push the folding mirrors to light the lanterns
// ======================================================================
class LightGame extends GridGame {
  constructor(level, api) {
    const b = Logic.Light.parse(level);
    super(level, api, Logic.Light, b);
  }
  draw(ctx, t) {
    const { b, u } = this;
    const s = this.s, P = this.p();
    for (let y = 0; y < this.H; y++) for (let x = 0; x < this.W; x++) {
      const X = this.ox + x * u, Y = this.oy + y * u;
      if (b.map[y][x] === '#') { paperTile(ctx, X, Y, u + 0.5, u + 0.5, '#2E2833'); continue; }
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, (x + y) % 2 ? '#4A4552' : '#443F4C');
      ctx.strokeStyle = 'rgba(255,255,255,.05)';
      ctx.strokeRect(X + 0.5, Y + 0.5, u - 1, u - 1);
    }
    for (const f of b.filters) {
      const c = this.cellC(f.x, f.y);
      Art.rr(ctx, c.x - u * 0.4, c.y - u * 0.4, u * 0.8, u * 0.8, u * 0.06);
      ctx.fillStyle = 'rgba(214,64,52,.55)';
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,190,180,.7)';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
    // the light
    const { segs, lit } = Logic.Light.trace(b, s);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.lineCap = 'round';
    for (const g of segs) {
      const a = this.cellC(g.x, g.y), z = this.cellC(g.nx, g.ny);
      const zz = g.stop ? { x: (a.x + z.x) / 2 + (z.x - a.x) * 0.0, y: (a.y + z.y) / 2 } : z;
      for (const [wdt, al] of [[u * 0.34, 0.12], [u * 0.14, 0.35], [u * 0.05, 0.9]]) {
        ctx.strokeStyle = g.red ? `rgba(255,90,70,${al})` : `rgba(255,214,120,${al})`;
        ctx.lineWidth = wdt;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(zz.x, zz.y); ctx.stroke();
      }
    }
    ctx.restore();
    // the lamp
    const sc = this.cellC(b.src.x, b.src.y);
    Art.rr(ctx, sc.x - u * 0.22, sc.y - u * 0.3, u * 0.44, u * 0.56, u * 0.05);
    Art.inked(ctx, '#FFF3D6', Math.max(1.2, u * 0.035));
    const [ddx, ddy] = Logic.DIRS[b.src.dir];
    Art.ellipse(ctx, sc.x + ddx * u * 0.28, sc.y + ddy * u * 0.28, u * 0.08, u * 0.08, C.glow, 1);
    // lanterns
    b.targets.forEach((tg, i) => {
      const c = this.cellC(tg.x, tg.y);
      const on = Logic.Light.litOk(b, lit, i);
      if (on) {
        const g = ctx.createRadialGradient(c.x, c.y, 2, c.x, c.y, u * 0.7);
        g.addColorStop(0, tg.red ? 'rgba(255,110,90,.6)' : 'rgba(255,210,120,.6)');
        g.addColorStop(1, 'rgba(255,200,120,0)');
        ctx.fillStyle = g;
        ctx.fillRect(c.x - u, c.y - u, u * 2, u * 2);
      }
      ctx.fillStyle = C.ink;
      ctx.fillRect(c.x - u * 0.16, c.y - u * 0.36, u * 0.32, u * 0.07);
      ctx.fillRect(c.x - u * 0.16, c.y + u * 0.29, u * 0.32, u * 0.07);
      Art.ellipse(ctx, c.x, c.y, u * 0.26, u * 0.3, tg.red ? (on ? '#FF6B55' : '#9E3A30') : on ? '#FFE9B0' : '#CFC6B8', Math.max(1.2, u * 0.035));
      ctx.strokeStyle = 'rgba(58,43,34,.35)';
      ctx.lineWidth = 1;
      for (const k of [-0.12, 0, 0.12]) { ctx.beginPath(); ctx.moveTo(c.x - u * 0.25, c.y + k * u); ctx.lineTo(c.x + u * 0.25, c.y + k * u); ctx.stroke(); }
    });
    // folding screens (pushable) and the bamboo blind (fixed)
    const screen = (c, o, blind) => {
      const k = o === '/' ? 1 : -1;
      ctx.lineCap = 'round';
      ctx.strokeStyle = C.ink;
      ctx.lineWidth = u * 0.16;
      ctx.beginPath(); ctx.moveTo(c.x - u * 0.34, c.y + k * u * 0.34); ctx.lineTo(c.x + u * 0.34, c.y - k * u * 0.34); ctx.stroke();
      ctx.strokeStyle = blind ? '#A9B77E' : '#E8C766';
      ctx.lineWidth = u * 0.1;
      // a bamboo blind is slatted: light slips through between the slats
      if (blind) ctx.setLineDash([u * 0.05, u * 0.04]);
      ctx.stroke();
      ctx.setLineDash([]);
      if (blind) {
        ctx.strokeStyle = 'rgba(58,43,34,.6)';
        ctx.lineWidth = 1;
        for (let i = -2; i <= 2; i++) {
          const mx = c.x + i * u * 0.12, my = c.y - k * i * u * 0.12;
          ctx.beginPath(); ctx.moveTo(mx - u * 0.05, my - u * 0.05 * k * -1); ctx.lineTo(mx + u * 0.05, my + u * 0.05 * k * -1); ctx.stroke();
        }
      }
    };
    for (const bl of b.blinds) screen(this.cellC(bl.x, bl.y), bl.o, true);
    const push = this.anim && P < 1 && this.last && this.last.push;
    for (const m of s.mirrors) {
      let c = this.cellC(m.x, m.y);
      if (push && push.to.x === m.x && push.to.y === m.y) {
        const a = this.cellC(push.from.x, push.from.y);
        c = { x: a.x + (c.x - a.x) * ease(P), y: a.y + (c.y - a.y) * ease(P) };
      }
      Art.shadow(ctx, c.x, c.y + u * 0.3, u * 0.3, u * 0.07);
      screen(c, m.o, false);
    }
    this.drawCat(ctx, t);
  }
}

// ======================================================================
// 3. ふすま渡り — slide the doors to reach the guest room
// ======================================================================
class FusumaGame extends GridGame {
  constructor(level, api) {
    const b = Logic.Fusuma.parse(level);
    super(level, api, Logic.Fusuma, b);
  }
  draw(ctx, t) {
    const { b, u } = this;
    const s = this.s, P = this.p();
    for (let y = 0; y < this.H; y++) for (let x = 0; x < this.W; x++) {
      const X = this.ox + x * u, Y = this.oy + y * u;
      const c = b.map[y][x];
      if (c === '#') { paperTile(ctx, X, Y, u + 0.5, u + 0.5, '#6B4A33'); continue; }
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, (x + y) % 2 ? '#D9D3A6' : '#D2CB9C');
      ctx.strokeStyle = 'rgba(90,110,60,.25)';
      ctx.lineWidth = 1;
      for (let k = 1; k < 5; k++) { ctx.beginPath(); ctx.moveTo(X + 2, Y + (k * u) / 5); ctx.lineTo(X + u - 2, Y + (k * u) / 5); ctx.stroke(); }
      ctx.strokeStyle = 'rgba(58,43,34,.35)';
      ctx.strokeRect(X + 0.5, Y + 0.5, u - 1, u - 1);
    }
    // the guest room: a cushion and the guest waiting
    const g = this.cellC(b.goal.x, b.goal.y);
    Art.rr(ctx, g.x - u * 0.4, g.y - u * 0.4, u * 0.8, u * 0.8, u * 0.12);
    Art.inked(ctx, '#B84A3A', Math.max(1.2, u * 0.035));
    if (!(s.x === b.goal.x && s.y === b.goal.y)) Art.guest(ctx, g.x, g.y - u * 0.1, u * 0.22, 1, { t, happy: this.won() });
    // the landlady's key
    if (b.key && !s.key) {
      const k = this.cellC(b.key.x, b.key.y);
      const bob = Math.sin(t * 3) * u * 0.03;
      Art.ellipse(ctx, k.x - u * 0.1, k.y + bob, u * 0.12, u * 0.12, '#E8C766', Math.max(1.2, u * 0.03));
      ctx.strokeStyle = C.ink; ctx.lineWidth = u * 0.07;
      ctx.beginPath(); ctx.moveTo(k.x, k.y + bob); ctx.lineTo(k.x + u * 0.28, k.y + bob); ctx.moveTo(k.x + u * 0.2, k.y + bob); ctx.lineTo(k.x + u * 0.2, k.y + u * 0.1 + bob); ctx.stroke();
      ctx.strokeStyle = '#E8C766'; ctx.lineWidth = u * 0.04; ctx.stroke();
    }
    // the doors
    const bump = this.bumped(0.35);
    const moving = this.anim && P < 1 && this.last && this.last.push ? this.last.push.moving : [];
    b.panels.forEach((p, i) => {
      let pos = s.pos[i];
      if (moving.includes(i)) {
        const a = this.prev.pos[i];
        pos = { x: a.x + (pos.x - a.x) * ease(P), y: a.y + (pos.y - a.y) * ease(P) };
      }
      let X = this.ox + pos.x * u, Y = this.oy + pos.y * u;
      const w = p.axis === 'h' ? p.len * u : u, h = p.axis === 'h' ? u : p.len * u;
      if (bump && bump.info && bump.info.panel === i) {
        const k = Math.sin((now() - bump.t) * 60) * 2;
        X += k; Y += k;
      }
      const inset = u * 0.12;
      const x0 = X + (p.axis === 'v' ? inset : 2), y0 = Y + (p.axis === 'h' ? inset : 2);
      const ww = w - (p.axis === 'v' ? inset * 2 : 4), hh = h - (p.axis === 'h' ? inset * 2 : 4);
      ctx.fillStyle = 'rgba(58,43,34,.18)';
      ctx.fillRect(x0 + 2, y0 + 3, ww, hh);
      Art.rr(ctx, x0, y0, ww, hh, 3);
      Art.inked(ctx, p.link ? '#DCE6EE' : '#F6EEDB', Math.max(1.5, u * 0.05));
      // frame and paper pattern
      ctx.strokeStyle = '#7A5638';
      ctx.lineWidth = Math.max(1, u * 0.04);
      ctx.strokeRect(x0 + 3, y0 + 3, ww - 6, hh - 6);
      if (p.link) {
        // paired doors share an indigo wave crest
        ctx.strokeStyle = C.noren;
        ctx.lineWidth = Math.max(1, u * 0.035);
        for (let k = 0; k < p.len; k++) {
          const cx = p.axis === 'h' ? x0 + (k + 0.5) * u : x0 + ww / 2, cy = p.axis === 'h' ? y0 + hh / 2 : y0 + (k + 0.5) * u;
          ctx.beginPath(); ctx.arc(cx, cy + u * 0.05, u * 0.12, Math.PI, 2 * Math.PI); ctx.arc(cx, cy + u * 0.05, u * 0.06, Math.PI, 2 * Math.PI); ctx.stroke();
        }
      }
      // handle
      const hx = p.axis === 'h' ? x0 + ww - u * 0.3 : x0 + ww / 2, hy = p.axis === 'h' ? y0 + hh / 2 : y0 + hh - u * 0.3;
      Art.ellipse(ctx, hx, hy, u * 0.07, u * 0.07, '#5A4034', 1);
      // track arrows show which way it slides
      ctx.fillStyle = 'rgba(122,86,56,.55)';
      const m = { x: x0 + ww / 2, y: y0 + hh / 2 };
      for (const sgn of [-1, 1]) {
        ctx.beginPath();
        if (p.axis === 'h') { const ax = m.x + sgn * (ww / 2 - u * 0.12); ctx.moveTo(ax, m.y); ctx.lineTo(ax - sgn * u * 0.1, m.y - u * 0.07); ctx.lineTo(ax - sgn * u * 0.1, m.y + u * 0.07); }
        else { const ay = m.y + sgn * (hh / 2 - u * 0.12); ctx.moveTo(m.x, ay); ctx.lineTo(m.x - u * 0.07, ay - sgn * u * 0.1); ctx.lineTo(m.x + u * 0.07, ay - sgn * u * 0.1); }
        ctx.fill();
      }
      if (p.lock) {
        const lx = m.x, ly = m.y;
        Art.rr(ctx, lx - u * 0.12, ly - u * 0.05, u * 0.24, u * 0.2, 2);
        Art.inked(ctx, s.key ? '#C9B98A' : C.shu, 1.2);
        ctx.beginPath(); ctx.arc(lx + (s.key ? u * 0.06 : 0), ly - u * 0.05, u * 0.08, Math.PI, 2 * Math.PI);
        ctx.strokeStyle = C.ink; ctx.lineWidth = 1.6; ctx.stroke();
      }
    });
    this.drawCat(ctx, t, { carry: this.won() ? [] : ['tempura'] });
  }
}

// ======================================================================
// 4. だし回し — turn the bamboo pipes, mix the stocks
// ======================================================================
const STOCK = { k: '#E39A3F', n: '#5E9A4C', kn: '#D8B03A' };
class DashiGame {
  constructor(level, api) {
    this.api = api;
    this.level = level;
    this.r = level.rot.map((row) => [...row].map(Number));
    this.fixed = new Set(level.fixed || []);
    this.turns = 0;
    this.hist = [];
    this.spin = {};
    this.h = level.tiles.length;
    this.w = level.tiles[0].length;
  }
  layout(w) {
    this.u = Math.floor(Math.min((w - 8) / this.w, 66));
    this.ox = Math.floor((w - this.u * this.w) / 2);
    this.oy = 8;
    return this.u * this.h + 18;
  }
  status() { return { moves: this.turns, par: 0, label: `${this.turns}回まわした` }; }
  canUndo() { return this.hist.length > 0; }
  undo() { if (this.hist.length) { this.r = this.hist.pop(); this.turns--; } }
  down(x, y) {
    const cx = Math.floor((x - this.ox) / this.u), cy = Math.floor((y - this.oy) / this.u);
    if (cx < 0 || cy < 0 || cx >= this.w || cy >= this.h) return;
    const tile = this.level.tiles[cy][cx];
    if (!'ILTX'.includes(tile)) return;
    if (this.fixed.has(`${cx},${cy}`)) { this.spin[`${cx},${cy}`] = { t: now(), locked: true }; return; }
    if (Logic.Dashi.won(this.level, this.r)) return;
    this.hist.push(this.r.map((row) => [...row]));
    this.r[cy][cx] = (this.r[cy][cx] + 1) % 4;
    this.turns++;
    this.spin[`${cx},${cy}`] = { t: now() };
    if (Logic.Dashi.won(this.level, this.r)) setTimeout(() => this.api.won(this.status()), 600);
  }
  draw(ctx, t) {
    const { u, level } = this;
    const flow = Logic.Dashi.flow(level, this.r);
    Art.rr(ctx, this.ox - 6, this.oy - 6, this.u * this.w + 12, this.u * this.h + 12, 8);
    Art.inked(ctx, '#B98A5E', 2);
    const pipe = (cx, cy, m, chanOf, fixed, rotA) => {
      const c = { x: this.ox + (cx + 0.5) * u, y: this.oy + (cy + 0.5) * u };
      ctx.save();
      ctx.translate(c.x, c.y);
      ctx.rotate(rotA);
      const arms = [[1, 0, -1], [2, 1, 0], [4, 0, 1], [8, -1, 0]].filter(([bit]) => m & bit);
      // bamboo (or iron) tube, then what flows in it
      for (const pass of [0, 1, 2]) {
        for (const [bit, dx, dy] of arms) {
          const ch = chanOf(bit);
          const carry = flow.carry(cx, cy, ch);
          if (pass === 2 && !carry) continue;
          ctx.strokeStyle = pass === 0 ? C.ink : pass === 1 ? (fixed ? '#7D7B78' : '#C9B07A') : STOCK[carry] || '#fff';
          ctx.lineWidth = pass === 0 ? u * 0.34 : pass === 1 ? u * 0.26 : u * 0.12;
          ctx.lineCap = 'butt';
          ctx.beginPath();
          // on a crossing the E-W tube bridges over the N-S one
          ctx.moveTo(0, 0);
          ctx.lineTo(dx * u * 0.5, dy * u * 0.5);
          ctx.stroke();
        }
        if (pass < 2 && arms.length > 1 && !(m === 15)) {
          Art.ellipse(ctx, 0, 0, pass === 0 ? u * 0.17 : u * 0.13, pass === 0 ? u * 0.17 : u * 0.13, pass === 0 ? C.ink : fixed ? '#7D7B78' : '#C9B07A');
        }
      }
      if (m === 15) {
        // redraw the bridge on top
        for (const pass of [0, 1, 2]) {
          const carry = flow.carry(cx, cy, 1);
          if (pass === 2 && !carry) continue;
          ctx.strokeStyle = pass === 0 ? C.ink : pass === 1 ? (fixed ? '#8E8C88' : '#D8C08A') : STOCK[carry];
          ctx.lineWidth = pass === 0 ? u * 0.36 : pass === 1 ? u * 0.28 : u * 0.12;
          ctx.beginPath(); ctx.moveTo(-u * 0.5, 0); ctx.lineTo(u * 0.5, 0); ctx.stroke();
        }
      }
      if (fixed) for (const [dx, dy] of [[-0.3, -0.3], [0.3, -0.3], [-0.3, 0.3], [0.3, 0.3]]) Art.ellipse(ctx, dx * u, dy * u, u * 0.04, u * 0.04, '#5E5C58');
      // spill: drops at an open end
      for (const [bit, dx, dy] of arms) {
        if (!flow.spilling(cx, cy, chanOf(bit))) continue;
        const [nx, ny] = [cx + (bit === 2 ? 1 : bit === 8 ? -1 : 0), cy + (bit === 4 ? 1 : bit === 1 ? -1 : 0)];
        const nm = nx >= 0 && ny >= 0 && nx < this.w && ny < this.h ? Logic.Dashi.mask(level, this.r, nx, ny) : 0;
        const back = { 1: 4, 2: 8, 4: 1, 8: 2 }[bit];
        if (nm & back) continue;
        const k = (t * 2) % 1;
        Art.ellipse(ctx, dx * u * (0.5 + k * 0.1), dy * u * (0.5 + k * 0.1) + k * u * 0.1, u * 0.05, u * 0.07, STOCK[flow.carry(cx, cy, chanOf(bit))] || C.cold);
      }
      ctx.restore();
    };
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const X = this.ox + x * u, Y = this.oy + y * u;
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, (x + y) % 2 ? '#E9D6B2' : '#E2CDA6');
      ctx.strokeStyle = 'rgba(58,43,34,.15)';
      ctx.strokeRect(X + 0.5, Y + 0.5, u - 1, u - 1);
      const tile = level.tiles[y][x];
      if ('ILTX'.includes(tile)) {
        const sp = this.spin[`${x},${y}`];
        const fixed = this.fixed.has(`${x},${y}`);
        let rotA = 0, m = Logic.Dashi.mask(level, this.r, x, y);
        if (sp && !sp.locked && now() - sp.t < 0.18) {
          // turn in from the previous quarter
          rotA = -(1 - ease((now() - sp.t) / 0.18)) * Math.PI / 2;
        }
        let dx2 = 0;
        if (sp && sp.locked && now() - sp.t < 0.3) dx2 = Math.sin((now() - sp.t) * 60) * 2;
        ctx.save(); ctx.translate(dx2, 0);
        pipe(x, y, m, (bit) => Logic.Dashi.chan(level, x, y, bit), fixed, rotA);
        ctx.restore();
      }
    }
    // stock pots and bowls
    for (const src of level.sources) {
      const m = { up: 1, right: 2, down: 4, left: 8 }[src.dir];
      pipe(src.x, src.y, m, () => 0, true, 0);
      const c = { x: this.ox + (src.x + 0.5) * u, y: this.oy + (src.y + 0.5) * u };
      Art.ellipse(ctx, c.x, c.y, u * 0.34, u * 0.3, '#3F3530', Math.max(1.2, u * 0.035));
      Art.ellipse(ctx, c.x, c.y - u * 0.04, u * 0.26, u * 0.16, STOCK[src.f], 1);
      ctx.fillStyle = '#FFF7EA';
      ctx.font = `${u * 0.28}px "Yusei Magic", sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(src.f === 'k' ? '鰹' : '昆', c.x, c.y + u * 0.02);
    }
    level.bowls.forEach((bw, i) => {
      const m = { up: 1, right: 2, down: 4, left: 8 }[bw.dir];
      pipe(bw.x, bw.y, m, () => 0, true, 0);
      const c = { x: this.ox + (bw.x + 0.5) * u, y: this.oy + (bw.y + 0.5) * u };
      const got = flow.bowls[i];
      const want = [...bw.want].sort().join('');
      ctx.beginPath();
      ctx.moveTo(c.x - u * 0.36, c.y - u * 0.08);
      ctx.quadraticCurveTo(c.x - u * 0.32, c.y + u * 0.34, c.x, c.y + u * 0.34);
      ctx.quadraticCurveTo(c.x + u * 0.32, c.y + u * 0.34, c.x + u * 0.36, c.y - u * 0.08);
      ctx.closePath();
      Art.inked(ctx, '#FFFBF2', Math.max(1.2, u * 0.035));
      Art.ellipse(ctx, c.x, c.y - u * 0.08, u * 0.36, u * 0.12, got ? STOCK[got] || '#ccc' : '#F4EAD6', Math.max(1, u * 0.03));
      // the order: a ring in the colour this bowl wants
      ctx.lineWidth = u * 0.06;
      ctx.strokeStyle = STOCK[want];
      ctx.beginPath(); ctx.arc(c.x, c.y + u * 0.12, u * 0.12, 0, Math.PI * 2); ctx.stroke();
      if (got === want) Art.hanko(ctx, c.x + u * 0.26, c.y - u * 0.28, u * 0.14, '済');
    });
  }
}

const GAMES = [
  {
    id: 'pack', cls: PackGame, title: 'おかもち詰め', en: 'Okamochi Packing', kept: true,
    pitch: '出前箱にぴったり詰める。熱いものと冷たいものは、となりに置けない。',
    rule: 'ドラッグで箱へ、タップで回す。赤い湯気と青い霜はとなり合わせ禁止。汁物（▼）はいちばん下の段へ。',
    gimmicks: [['熱い／冷たい', 1], ['汁物は下段', 1], ['割れもの（上に載せられない）', 0], ['二段重ね（ふたを閉めて次の段）', 0], ['配達順（先に届ける品は手前）', 0], ['大盛り（途中で形が変わる）', 0]],
    notes: {},
  },
  {
    id: 'oden', cls: OdenGame, title: 'おでん仕込み', en: 'Oden Prep',
    pitch: '具を押して鍋へ。鍋は札に書かれた順番でしか受けつけない。',
    rule: 'スワイプかタップで歩き、具を押す。鍋の札の順番どおりに入れる（光っている具が次）。',
    gimmicks: [['入れる順番', 1], ['鍋がふたつ', 1], ['つるつる床（押した具がすべる）', 1], ['重い具（2マス分）', 0], ['だし汁の流れ（具が流される）', 0], ['火加減の鍋（入れる数で火が変わる）', 0]],
    notes: { 1: '新しいしかけ：鍋がふたつ。それぞれの札の順番で。', 2: '新しいしかけ：つるつる床。押した具が止まるまですべる。' },
  },
  {
    id: 'light', cls: LightGame, title: 'あかり届け', en: 'Lantern Light',
    pitch: '縁日の夜。びょうぶを押して、行灯の光を提灯まで届ける。',
    rule: 'スワイプかタップで歩き、金のびょうぶを押す。光はびょうぶで直角に曲がる。提灯すべてに灯りを。',
    gimmicks: [['びょうぶで反射', 1], ['提灯がふたつ', 1], ['赤い和紙（赤い光に）', 1], ['すだれ（半分通して半分曲げる）', 1], ['回転台のびょうぶ', 0], ['時間で動く人影', 0]],
    notes: { 1: '新しいしかけ：提灯がふたつ。', 2: '新しいしかけ：赤い和紙。通った光は赤くなる。赤い提灯は赤い光でしか灯らない。', 3: '新しいしかけ：すだれ。光を半分通して、半分曲げる（押せない）。' },
  },
  {
    id: 'fusuma', cls: FusumaGame, title: 'ふすま渡り', en: 'Sliding Doors',
    pitch: '古い宿で、ふすまを敷居にそって押し、お客さんの部屋まで天ぷらを届ける。',
    rule: 'スワイプかタップで歩く。ふすまは矢印の向きにだけ押せる。座布団の部屋まで行けば配達完了。',
    gimmicks: [['敷居にそって押す', 1], ['連動ふすま（同じ柄は一緒に動く）', 1], ['女将さんの鍵', 1], ['回り障子（押すと90度回る）', 0], ['寝ているお客さん（静かに通る）', 0], ['階段で上の階へ', 0]],
    notes: { 1: '新しいしかけ：同じ柄のふすまは一緒に動く。', 2: '新しいしかけ：鍵のかかったふすま。先に女将さんの鍵を拾う。' },
  },
  {
    id: 'dashi', cls: DashiGame, title: 'だし回し', en: 'Stock Pipes',
    pitch: '竹の樋を回して、だしをお椀まで。鰹と昆布が出会うと合わせだしになる。',
    rule: '樋をタップで回す。お椀の輪の色のだしを届け、だしを樋からこぼさない。鉄の樋は回らない。',
    gimmicks: [['樋を回す', 1], ['合わせだし（混ざる）', 1], ['回らない鉄の樋', 1], ['交差（混ざらずにすれ違う）', 1], ['栓（開け閉め）', 0], ['温度（遠いとぬるくなる）', 0]],
    notes: { 1: '新しいしかけ：鰹（橙）と昆布（緑）が出会うと合わせだし（金）。', 2: '新しいしかけ：鉄の樋は回らない。2つのだしを混ぜずに届ける。', 3: '新しいしかけ：交差する樋。縦と横は混ざらずにすれ違う。' },
  },
];
