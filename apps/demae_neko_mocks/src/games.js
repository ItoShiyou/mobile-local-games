// The five mock games. Each one draws into a canvas of the width it is
// given and handles pointer input in canvas pixels (CSS px).
const { Slide, Pack, Stroke, Sort, Deduce } = Logic;
const ease = (p) => 1 - Math.pow(1 - Math.min(1, Math.max(0, p)), 3);
const now = () => performance.now() / 1000;

function paperTile(ctx, x, y, w, h, fill) {
  ctx.fillStyle = fill;
  ctx.fillRect(x, y, w, h);
}

// ======================================================================
// 1. すべって出前 — slide until something stops you
// ======================================================================
class SlideGame {
  constructor(level, api) {
    this.api = api;
    this.level = level;
    this.b = Slide.parse(level.map);
    this.s = Slide.init(this.b);
    this.hist = [];
    this.moves = 0;
    this.anim = null;
    this.facing = 'down';
    this.foods = ['ramen', 'sushi', 'tamago', 'gyoza', 'soba'];
    this.servedAt = {};
  }
  layout(w) {
    this.cell = Math.floor(Math.min(w / this.b.w, 64));
    this.ox = Math.floor((w - this.cell * this.b.w) / 2);
    this.oy = 6;
    return this.cell * this.b.h + 12;
  }
  status() { return { moves: this.moves, par: this.level.par }; }
  canUndo() { return this.hist.length > 0 && !this.anim; }
  undo() {
    if (!this.canUndo()) return;
    this.s = this.hist.pop();
    this.moves--;
  }
  go(dir) {
    if (this.anim || Slide.won(this.b, this.s)) return;
    const r = Slide.move(this.b, this.s, dir);
    this.facing = dir;
    if (!r) { this.bump = { dir, t: now() }; return; }
    this.hist.push(this.s);
    this.anim = { from: this.s, r, t0: now(), dur: 0.09 * Math.max(1, r.path.length) + 0.05 };
    this.moves++;
  }
  down(x, y) { this.p0 = { x, y }; }
  up(x, y) {
    if (!this.p0) return;
    let dx = x - this.p0.x, dy = y - this.p0.y;
    if (Math.hypot(dx, dy) < 14) {
      // a tap: go towards it from the cat
      const c = this.cellCenter(this.s.x, this.s.y);
      dx = x - c.x; dy = y - c.y;
      if (Math.hypot(dx, dy) < this.cell * 0.4) { this.p0 = null; return; }
    }
    this.go(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'));
    this.p0 = null;
  }
  key(k) {
    const m = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' }[k];
    if (m) this.go(m);
  }
  cellCenter(x, y) { return { x: this.ox + (x + 0.5) * this.cell, y: this.oy + (y + 0.5) * this.cell }; }
  draw(ctx, t) {
    const { b, cell: u } = this;
    // finish the slide
    let pos = { x: this.s.x, y: this.s.y };
    let served = this.s.served;
    if (this.anim) {
      const a = this.anim;
      const p = (now() - a.t0) / a.dur;
      if (p >= 1) {
        this.s = a.r.state;
        if (a.r.served >= 0) this.servedAt[a.r.served] = now();
        this.anim = null;
        pos = { x: this.s.x, y: this.s.y };
        served = this.s.served;
        if (Slide.won(b, this.s)) setTimeout(() => this.api.won(this.status()), 600);
      } else {
        const pts = [{ x: a.from.x, y: a.from.y }, ...a.r.path];
        const q = ease(p) * (pts.length - 1);
        const i = Math.min(pts.length - 2, Math.floor(q));
        const f = q - i;
        pos = pts.length > 1 ? { x: pts[i].x + (pts[i + 1].x - pts[i].x) * f, y: pts[i].y + (pts[i + 1].y - pts[i].y) * f } : pts[0];
        served = a.from.served;
      }
    }
    // floor: wet paving stones
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
      const c = b.map[y][x];
      const X = this.ox + x * u, Y = this.oy + y * u;
      if (c === '#') continue;
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, (x + y) % 2 ? '#DCD6CA' : '#D3CDC0');
      ctx.strokeStyle = 'rgba(58,43,34,.18)';
      ctx.lineWidth = 1;
      ctx.strokeRect(X + 0.5, Y + 0.5, u - 1, u - 1);
      // a sheen of rain water
      ctx.strokeStyle = 'rgba(255,255,255,.55)';
      ctx.lineWidth = Math.max(1, u * 0.04);
      ctx.beginPath();
      const k = wob(x, y) * u * 0.3;
      ctx.moveTo(X + u * 0.2 + k, Y + u * 0.7);
      ctx.lineTo(X + u * 0.45 + k, Y + u * 0.62);
      ctx.stroke();
      if (c === 'o') {
        Art.rr(ctx, X + u * 0.08, Y + u * 0.08, u * 0.84, u * 0.84, u * 0.08);
        Art.inked(ctx, '#D8B96E', Math.max(1, u * 0.035));
        ctx.strokeStyle = 'rgba(122,90,40,.45)';
        ctx.lineWidth = Math.max(1, u * 0.025);
        for (let i = 1; i < 6; i++) {
          ctx.beginPath();
          ctx.moveTo(X + u * 0.1, Y + u * (0.08 + i * 0.14));
          ctx.lineTo(X + u * 0.9, Y + u * (0.08 + i * 0.14));
          ctx.stroke();
        }
      }
    }
    // walls: wooden crates and shop fronts, seen from above
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
      if (b.map[y][x] !== '#') continue;
      const X = this.ox + x * u, Y = this.oy + y * u;
      const edge = x === 0 || y === 0 || x === b.w - 1 || y === b.h - 1;
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, edge ? '#8C6B50' : '#B98A5E');
      if (!edge) {
        Art.rr(ctx, X + u * 0.1, Y + u * 0.1, u * 0.8, u * 0.8, u * 0.06);
        Art.inked(ctx, '#C9995F', Math.max(1, u * 0.04));
        ctx.beginPath();
        ctx.moveTo(X + u * 0.1, Y + u * 0.1); ctx.lineTo(X + u * 0.9, Y + u * 0.9);
        ctx.moveTo(X + u * 0.9, Y + u * 0.1); ctx.lineTo(X + u * 0.1, Y + u * 0.9);
        ctx.stroke();
      } else {
        ctx.fillStyle = 'rgba(0,0,0,.08)';
        if ((x + y) % 2) ctx.fillRect(X, Y, u, u);
      }
    }
    // guests
    b.guests.forEach((g, i) => {
      const c = this.cellCenter(g.x, g.y);
      const done = !!(served & (1 << i));
      Art.guest(ctx, c.x, c.y - u * 0.05, u * 0.3, i, { happy: done, t });
      Art.ticket(ctx, c.x + u * 0.3, c.y - u * 0.34, u * 0.34, this.foods[i], { done });
    });
    // cat
    const c = this.cellCenter(pos.x, pos.y);
    let bx = 0, by = 0;
    if (this.bump && now() - this.bump.t < 0.25) {
      const d = Logic.DIRS[this.bump.dir];
      const k = Math.sin((now() - this.bump.t) / 0.25 * Math.PI) * u * 0.08;
      bx = d[0] * k; by = d[1] * k;
    }
    const left = b.guests.filter((_, i) => !(served & (1 << i))).length;
    const carry = this.foods.slice(0, b.guests.length).filter((_, i) => !(served & (1 << i))).slice(0, 3);
    Art.cat(ctx, c.x + bx, c.y - u * 0.18 + by, u * 0.24, { facing: this.facing, t, carry: left ? carry : [], happy: !left });
    // flying dish to a just-served guest
    for (const [i, t0] of Object.entries(this.servedAt)) {
      const q = (now() - t0) / 0.5;
      if (q > 1) continue;
      const g = b.guests[i];
      const to = this.cellCenter(g.x, g.y);
      Art.plate(ctx, c.x + (to.x - c.x) * ease(q), c.y - u * 0.5 + (to.y - c.y) * ease(q) - Math.sin(q * Math.PI) * u * 0.4, u * 0.3, this.foods[i]);
    }
  }
}

// ======================================================================
// 2. おかもち詰め — pack the delivery box
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
// 3. ひとふで出前 — one round through every lane
// ======================================================================
class StrokeGame {
  constructor(level, api) {
    this.api = api;
    this.level = level;
    this.b = Stroke.parse(level.map);
    this.path = [this.b.start];
    this.hist = [];
    this.moves = 0;
  }
  layout(w) {
    this.cell = Math.floor(Math.min(w / this.b.w, 70));
    this.ox = Math.floor((w - this.cell * this.b.w) / 2);
    this.oy = 8;
    return this.cell * this.b.h + 16;
  }
  status() { return { moves: this.path.length, par: this.b.open, label: `${this.path.length}/${this.b.open}マス` }; }
  canUndo() { return this.path.length > 1; }
  undo() { if (this.path.length > 1) this.path.pop(); }
  at(x, y) { return { x: Math.floor((x - this.ox) / this.cell), y: Math.floor((y - this.oy) / this.cell) }; }
  down(x, y) {
    const c = this.at(x, y);
    const i = this.path.findIndex((p) => p.x === c.x && p.y === c.y);
    // touching the walked line picks the round up from there
    if (i >= 0) this.path = this.path.slice(0, i + 1);
    this.dragging = true;
    this.move(x, y);
  }
  move(x, y) {
    if (!this.dragging) return;
    const c = this.at(x, y);
    const end = this.path[this.path.length - 1];
    if (c.x === end.x && c.y === end.y) return;
    const prev = this.path[this.path.length - 2];
    if (prev && c.x === prev.x && c.y === prev.y) { this.path.pop(); return; }
    if (Stroke.canStep(this.b, this.path, c.x, c.y)) {
      this.path.push(c);
      if (Stroke.won(this.b, this.path)) { this.dragging = false; setTimeout(() => this.api.won(this.status()), 500); }
    }
  }
  up() { this.dragging = false; }
  draw(ctx, t) {
    const { b, cell: u } = this;
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
      const X = this.ox + x * u, Y = this.oy + y * u;
      if (b.map[y][x] === '#') {
        // a garden: shrubs over a hedge
        paperTile(ctx, X, Y, u + 0.5, u + 0.5, '#9DBB7E');
        for (let k = 0; k < 3; k++) Art.ellipse(ctx, X + u * (0.3 + 0.2 * k), Y + u * (0.4 + 0.15 * (k % 2)), u * 0.22, u * 0.2, '#7FA360', Math.max(1, u * 0.03));
        continue;
      }
      paperTile(ctx, X, Y, u + 0.5, u + 0.5, (x + y) % 2 ? '#EFE5D1' : '#E8DCC4');
      ctx.strokeStyle = 'rgba(58,43,34,.14)';
      ctx.lineWidth = 1;
      ctx.strokeRect(X + 0.5, Y + 0.5, u - 1, u - 1);
    }
    // the walked line
    const P = this.path.map((p) => ({ x: this.ox + (p.x + 0.5) * u, y: this.oy + (p.y + 0.5) * u }));
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(200,69,47,.28)';
    ctx.lineWidth = u * 0.34;
    ctx.beginPath();
    P.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
    ctx.stroke();
    // paw prints along it
    for (let i = 1; i < P.length; i++) {
      const a = P[i - 1], c = P[i];
      const ang = Math.atan2(c.y - a.y, c.x - a.x);
      const mx = (a.x + c.x) / 2, my = (a.y + c.y) / 2;
      ctx.save();
      ctx.translate(mx, my);
      ctx.rotate(ang + Math.PI / 2);
      ctx.fillStyle = 'rgba(58,43,34,.35)';
      Art.ellipse(ctx, (i % 2 ? -1 : 1) * u * 0.06, 0, u * 0.05, u * 0.065, 'rgba(58,43,34,.35)');
      ctx.restore();
    }
    // houses with numbered door plates
    const next = Stroke.nextNumber(b, this.path);
    for (const [k, n] of Object.entries(b.nums)) {
      const [x, y] = k.split(',').map(Number);
      const X = this.ox + (x + 0.5) * u, Y = this.oy + (y + 0.5) * u;
      const visited = this.path.some((p) => p.x === x && p.y === y);
      if (n === 1) {
        // the shop: a small noren
        Art.rr(ctx, X - u * 0.36, Y - u * 0.38, u * 0.72, u * 0.34, u * 0.05);
        Art.inked(ctx, C.noren, Math.max(1, u * 0.03));
        ctx.fillStyle = '#F6EEDF';
        ctx.font = `${u * 0.24}px "Yusei Magic", sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('出', X, Y - u * 0.2);
        continue;
      }
      ctx.save();
      if (n === next && !visited) {
        ctx.shadowColor = C.glow;
        ctx.shadowBlur = 10 + 6 * Math.sin(t * 4);
      }
      Art.ellipse(ctx, X, Y, u * 0.26, u * 0.26, visited ? '#F3D9C9' : '#FFFBF2', Math.max(1.2, u * 0.04));
      ctx.restore();
      ctx.fillStyle = visited ? C.shu : C.ink;
      ctx.font = `${u * 0.3}px "Yusei Magic", sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(n === b.last ? '終' : String(n), X, Y + 1);
    }
    // the cat at the head of the line
    const e = this.path[this.path.length - 1], p = this.path[this.path.length - 2];
    const facing = !p ? 'down' : e.x > p.x ? 'right' : e.x < p.x ? 'left' : e.y < p.y ? 'up' : 'down';
    const E = P[P.length - 1];
    Art.cat(ctx, E.x, E.y - u * 0.18, u * 0.2, { facing, t, carry: this.path.length === b.open ? [] : ['bento'] });
  }
}

// ======================================================================
// 4. 皿そろえ屋台 — sort the plates at the stall
// ======================================================================
const SORT_FOOD = { a: 'ramen', b: 'sushi', c: 'tamago', d: 'dango', e: 'onigiri' };
class SortGame {
  constructor(level, api) {
    this.api = api;
    this.level = { cap: level.cap, stacks: level.stacks.map((s) => [...s]) };
    this.par = level.par;
    this.st = Sort.init(this.level);
    this.hist = [];
    this.moves = 0;
    this.held = null;
    this.catAt = 0;
    this.catX = null;
  }
  layout(w) {
    const n = this.st.length;
    this.cw = Math.floor(Math.min((w - 16) / n, 84));
    this.ox = Math.floor((w - this.cw * n) / 2);
    this.ph = Math.floor(this.cw * 0.42);
    this.top = Math.floor(this.cw * 0.95);
    this.base = this.top + this.ph * this.level.cap + 22;
    return this.base + 30;
  }
  status() { return { moves: this.moves, par: this.par }; }
  canUndo() { return this.hist.length > 0 && !this.held; }
  undo() { if (this.canUndo()) { this.st = this.hist.pop(); this.moves--; } }
  complete(s) { return s.length === this.level.cap && s.every((d) => d === s[0]); }
  down(x) {
    const i = Math.floor((x - this.ox) / this.cw);
    if (i < 0 || i >= this.st.length) return;
    this.catAt = i;
    if (this.held === null) {
      if (!this.st[i].length || this.complete(this.st[i])) { this.wobble = { i, t: now() }; return; }
      this.held = i;
      return;
    }
    if (i === this.held) { this.held = null; return; }
    const n = Sort.move(this.level, this.st, this.held, i);
    if (!n) { this.wobble = { i, t: now() }; return; }
    this.hist.push(this.st);
    this.st = n;
    this.moves++;
    this.held = null;
    if (Sort.won(this.level, this.st)) setTimeout(() => this.api.won(this.status()), 600);
  }
  draw(ctx, t) {
    const { cw, ox, ph } = this;
    const cap = this.level.cap;
    // the stall roof
    ctx.fillStyle = '#F6E7C8';
    for (let i = 0; i < this.st.length; i++) {
      const X = ox + i * cw;
      Art.rr(ctx, X + 4, this.base - ph * cap - 14, cw - 8, ph * cap + 14, 6);
      Art.inked(ctx, 'rgba(255,251,242,.6)', 1);
    }
    // counters
    for (let i = 0; i < this.st.length; i++) {
      const X = ox + i * cw;
      Art.rr(ctx, X + 3, this.base, cw - 6, 14, 3);
      Art.inked(ctx, C.wood, 1.6);
      const s = this.st[i];
      const shake = this.wobble && this.wobble.i === i && now() - this.wobble.t < 0.35 ? Math.sin((now() - this.wobble.t) * 60) * 3 : 0;
      s.forEach((d, k) => {
        if (this.held === i && k === s.length - 1) return;
        Art.plate(ctx, X + cw / 2 + shake, this.base - ph * (k + 0.55), cw * 0.62, SORT_FOOD[d]);
      });
      if (this.complete(s)) Art.hanko(ctx, X + cw - 14, this.base - ph * cap - 4, 11, '完');
    }
    // the cat walks to the chosen counter, carrying the lifted plate
    const target = ox + this.catAt * cw + cw / 2;
    this.catX = this.catX === null ? target : this.catX + (target - this.catX) * 0.25;
    const carry = this.held !== null ? [SORT_FOOD[this.st[this.held][this.st[this.held].length - 1]]] : [];
    const r = Math.min(cw * 0.2, 18);
    Art.cat(ctx, this.catX, this.top - r * 1.9, r, { facing: 'down', t, carry, happy: Sort.won(this.level, this.st) });
  }
}

// ======================================================================
// 5. 注文あてっこ — who ordered what?
// ======================================================================
class DeduceGame {
  constructor(level, api) {
    this.api = api;
    this.level = level;
    this.n = level.dishes.length;
    this.seat = Array(this.n).fill(null); // dish index per seat
    this.sel = null; // dish index held
    this.tries = 0;
    this.result = null;
    this.hist = [];
  }
  layout(w) {
    this.w = w;
    this.sw = Math.floor(Math.min((w - 20) / this.n, 90));
    this.ox = Math.floor((w - this.sw * this.n) / 2);
    this.guestY = 70;
    this.slotY = 150;
    this.passY = 222;
    this.clueY = 282;
    this.rowH = 38;
    this.btn = { x: w / 2 - 70, y: 0, w: 140, h: 40 };
    const relational = this.level.clues.filter((c) => !['is', 'not'].includes(c.t));
    this.btn.y = this.clueY + relational.length * this.rowH + 18;
    return this.btn.y + this.btn.h + 16;
  }
  status() { return { moves: this.tries, par: 1, label: `${this.tries}回目` }; }
  canUndo() { return false; }
  undo() {}
  placedAt(d) { return this.seat.indexOf(d); }
  down(x, y) {
    const { sw, ox } = this;
    // dishes waiting on the pass
    if (y > this.passY - 26 && y < this.passY + 26) {
      const d = Math.floor((x - ox) / sw);
      if (d >= 0 && d < this.n && this.placedAt(d) < 0) this.sel = this.sel === d ? null : d;
      return;
    }
    // the seats
    if (y > this.slotY - 30 && y < this.slotY + 30) {
      const s = Math.floor((x - ox) / sw);
      if (s < 0 || s >= this.n) return;
      this.result = null;
      if (this.sel !== null) {
        const prev = this.placedAt(this.sel);
        if (prev >= 0) this.seat[prev] = null;
        this.seat[s] = this.sel;
        this.sel = null;
      } else if (this.seat[s] !== null) {
        this.seat[s] = null;
      }
      return;
    }
    const b = this.btn;
    if (x > b.x && x < b.x + b.w && y > b.y && y < b.y + b.h && this.seat.every((d) => d !== null)) {
      this.tries++;
      const right = this.seat.filter((d, s) => this.level.dishes[d] === this.level.answer[s]).length;
      this.result = { right, t: now() };
      if (right === this.n) setTimeout(() => this.api.won(this.status()), 700);
    }
  }
  drawClue(ctx, c, x, y, s) {
    const icon = (k, xx) => { Art.food(ctx, k, xx, y, s * 0.42); };
    // drawing a dish changes the fill, so set the chalk colour each time
    const T = (txt, xx) => {
      ctx.fillStyle = '#F2EEDF';
      ctx.font = `${s * 0.42}px "Zen Maru Gothic", sans-serif`;
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(txt, xx, y + 1);
      return xx + ctx.measureText(txt).width;
    };
    let cx = x;
    if (c.t === 'adj') { icon(c.a, cx + s * 0.5); icon(c.b, cx + s * 1.5); T('は となりどうし', cx + s * 2.1); }
    if (c.t === 'left') { icon(c.a, cx + s * 0.5); cx = T('は', cx + s * 1.05); icon(c.b, cx + s * 0.6); T('より 左の席', cx + s * 1.15); }
    if (c.t === 'end') { icon(c.a, cx + s * 0.5); T('は はしっこの席', cx + s * 1.05); }
    if (c.t === 'mid') { icon(c.a, cx + s * 0.5); T('は はしっこじゃない', cx + s * 1.05); }
  }
  draw(ctx, t) {
    const { sw, ox, n } = this;
    const L = this.level;
    // counter
    Art.rr(ctx, ox - 8, this.slotY - 26, sw * n + 16, 52, 6);
    Art.inked(ctx, C.wood, 1.6);
    const happyAll = this.result && this.result.right === n;
    for (let s = 0; s < n; s++) {
      const X = ox + s * sw + sw / 2;
      Art.guest(ctx, X, this.guestY, Math.min(22, sw * 0.26), s, { t, happy: happyAll });
      // what this guest says about themselves
      const own = L.clues.filter((c) => (c.t === 'not' || c.t === 'is') && c.seat === s);
      own.forEach((c, k) => {
        const bx = X + sw * 0.18, by = this.guestY - 44 - k * 30;
        Art.rr(ctx, bx - 16, by - 13, 32, 26, 8);
        Art.inked(ctx, '#FFFBF2', 1.4);
        Art.food(ctx, c.a, bx, by, 9);
        if (c.t === 'not') {
          ctx.strokeStyle = C.shu; ctx.lineWidth = 2.4;
          ctx.beginPath(); ctx.moveTo(bx - 10, by - 9); ctx.lineTo(bx + 10, by + 9); ctx.moveTo(bx + 10, by - 9); ctx.lineTo(bx - 10, by + 9); ctx.stroke();
        }
      });
      // the place setting in front of them
      Art.ellipse(ctx, X, this.slotY + 4, sw * 0.34, 12, 'rgba(255,251,242,.5)', 1);
      if (this.seat[s] !== null) Art.plate(ctx, X, this.slotY, Math.min(sw * 0.8, 60), L.dishes[this.seat[s]]);
    }
    // the pass: dishes still to hand out
    ctx.fillStyle = 'rgba(126,85,53,.18)';
    ctx.fillRect(ox - 8, this.passY - 22, sw * n + 16, 44);
    for (let d = 0; d < n; d++) {
      if (this.placedAt(d) >= 0) continue;
      const X = ox + d * sw + sw / 2;
      const lift = this.sel === d ? -8 + Math.sin(t * 6) * 2 : 0;
      if (this.sel === d) Art.ellipse(ctx, X, this.passY + 4, sw * 0.34, 12, 'rgba(255,197,107,.6)');
      Art.plate(ctx, X, this.passY + lift, Math.min(sw * 0.8, 60), L.dishes[d]);
    }
    // the cat behind the pass
    Art.cat(ctx, ox - 2, this.passY - 16, 12, { facing: 'right', t, noShadow: true, happy: happyAll });
    // chalkboard with what the regulars said about each other
    const rel = L.clues.filter((c) => !['is', 'not'].includes(c.t));
    Art.rr(ctx, 10, this.clueY - 24, this.w - 20, rel.length * this.rowH + 12, 6);
    Art.inked(ctx, '#2F3A31', 3);
    rel.forEach((c, i) => this.drawClue(ctx, c, 24, this.clueY - 4 + i * this.rowH, 30));
    // serve button and the result as smiling faces
    const b = this.btn;
    const ready = this.seat.every((d) => d !== null);
    Art.rr(ctx, b.x, b.y, b.w, b.h, 8);
    Art.inked(ctx, ready ? C.shu : '#CDB9A4', 1.8);
    ctx.fillStyle = '#FFF7EA';
    ctx.font = `18px "Yusei Magic", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('お届け', b.x + b.w / 2, b.y + b.h / 2 + 1);
    if (this.result && !happyAll) {
      for (let k = 0; k < n; k++) {
        const fx = b.x + b.w + 18 + k * 18, fy = b.y + b.h / 2;
        Art.ellipse(ctx, fx, fy, 7, 7, k < this.result.right ? '#F4CF4A' : '#DDD3C4', 1.2);
      }
    }
  }
}

const GAMES = [
  {
    id: 'slide', cls: SlideGame, title: 'すべって出前', en: 'Slippery Street',
    pitch: '雨あがりの商店街。一度すべり出したら、何かにぶつかるまで止まらない。',
    rule: 'スワイプかタップでその向きへすべる。お客さんにぶつかると料理を渡す。ござの上では止まれる。',
  },
  {
    id: 'pack', cls: PackGame, title: 'おかもち詰め', en: 'Okamochi Packing',
    pitch: '出前箱にぴったり詰める。熱いものと冷たいものは、となりに置けない。',
    rule: 'ドラッグで箱へ、タップで回す。赤い湯気と青い霜はとなり合わせ禁止。汁物（▼）はいちばん下の段へ。',
  },
  {
    id: 'stroke', cls: StrokeGame, title: 'ひとふで出前', en: 'One-Stroke Round',
    pitch: 'お店を出て、すべての路地を一度ずつ通り、番号の家に順番どおり寄る。',
    rule: '指でなぞって進む。通ったマスには戻れない（なぞり直すと巻き戻る）。',
  },
  {
    id: 'sort', cls: SortGame, title: '皿そろえ屋台', en: 'Stall Sort',
    pitch: '縁日の屋台で、ごちゃまぜの皿を種類ごとにそろえる。',
    rule: 'タップで一番上の皿を持ち上げ、別の台へ。置けるのは空の台か、同じ料理の上だけ。',
  },
  {
    id: 'deduce', cls: DeduceGame, title: '注文あてっこ', en: 'Who Ordered What?',
    pitch: '常連さんの話を聞いて、だれが何を頼んだか当てる推理パズル。',
    rule: '料理をタップして席へ。吹き出しは本人の話、黒板はみんなの話。当たった人数が顔で出る。',
  },
];
