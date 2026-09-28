// Menu, game screen, win receipt and saved progress.
(function () {
  const $ = (s) => document.querySelector(s);
  const store = {
    get(k, d) { try { const v = localStorage.getItem('demae-neko:' + k); return v === null ? d : JSON.parse(v); } catch (e) { return d; } },
    set(k, v) { try { localStorage.setItem('demae-neko:' + k, JSON.stringify(v)); } catch (e) { /* storage off: play on */ } },
  };
  const cleared = (id) => store.get('cleared:' + id, []);

  let game = null, meta = null, levelIndex = 0, canvas = null, ctx = null, cssW = 0, cssH = 0, raf = 0;

  // ---------------------------------------------------------------- menu
  function buildMenu() {
    const list = $('#cards');
    list.innerHTML = '';
    let fresh = 0;
    GAMES.forEach((g, i) => {
      const done = cleared(g.id).length;
      const label = g.kept ? '残した案' : `新案${++fresh}`;
      const chips = g.gimmicks.map(([name, on]) => `<li class="${on ? 'on' : ''}">${name}</li>`).join('');
      const card = document.createElement('button');
      card.className = 'card';
      card.id = 'card-' + g.id;
      card.innerHTML = `
        <canvas class="thumb" width="1" height="1" aria-hidden="true"></canvas>
        <span class="card-text">
          <span class="card-no ${g.kept ? 'kept' : ''}">${label}</span>
          <span class="card-title">${g.title}</span>
          <span class="card-en">${g.en}</span>
          <span class="card-pitch">${g.pitch}</span>
          <span class="card-progress">${LEVELS[g.id].map((_, k) => `<i class="${cleared(g.id).includes(k) ? 'on' : ''}"></i>`).join('')}<b>${done}/${LEVELS[g.id].length}</b></span>
        </span>
        <ul class="chips" aria-label="しかけ">${chips}</ul>`;
      card.addEventListener('click', () => open(i, firstOpen(g.id)));
      list.appendChild(card);
      drawThumb(card.querySelector('canvas'), g);
    });
  }
  function firstOpen(id) {
    const c = cleared(id);
    for (let k = 0; k < LEVELS[id].length; k++) if (!c.includes(k)) return k;
    return 0;
  }
  function drawThumb(cv, g) {
    const W = 108, H = 108, dpr = window.devicePixelRatio || 1;
    cv.width = W * dpr; cv.height = H * dpr;
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    const c = cv.getContext('2d');
    c.scale(dpr, dpr);
    const inst = new g.cls(LEVELS[g.id][0], { won() {} });
    const h = inst.layout(300);
    const s = Math.min(W / 300, H / h);
    c.fillStyle = '#FBF5EA';
    c.fillRect(0, 0, W, H);
    c.save();
    c.translate((W - 300 * s) / 2, (H - h * s) / 2);
    c.scale(s, s);
    try { inst.draw(c, 0); } catch (e) { /* a thumbnail is optional */ }
    c.restore();
  }

  // ---------------------------------------------------------------- game
  function open(i, lv) {
    meta = GAMES[i];
    levelIndex = lv;
    $('#menu').hidden = true;
    $('#play').hidden = false;
    $('#g-title').textContent = meta.title;
    $('#g-rule').textContent = meta.rule;
    start();
    window.scrollTo(0, 0);
  }
  function start() {
    const lv = LEVELS[meta.id][levelIndex];
    game = new meta.cls(lv, { won });
    $('#receipt').hidden = true;
    $('#g-level').textContent = `${levelIndex + 1} / ${LEVELS[meta.id].length}`;
    const note = meta.notes[levelIndex];
    $('#g-note').textContent = note || '';
    $('#g-note').hidden = !note;
    $('#dots').innerHTML = LEVELS[meta.id].map((_, k) => `<button class="dot ${k === levelIndex ? 'cur' : ''} ${cleared(meta.id).includes(k) ? 'on' : ''}" data-k="${k}" aria-label="${k + 1}問目">${k + 1}</button>`).join('');
    $('#dots').querySelectorAll('button').forEach((b) => b.addEventListener('click', () => { levelIndex = +b.dataset.k; start(); }));
    resize();
    loop();
  }
  function resize() {
    if (!game) return;
    const box = $('#stage');
    cssW = Math.min(box.clientWidth, 520);
    cssH = game.layout(cssW);
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(cssW * dpr);
    canvas.height = Math.round(cssH * dpr);
    canvas.style.width = cssW + 'px';
    canvas.style.height = cssH + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  function loop() {
    cancelAnimationFrame(raf);
    const frame = () => {
      if (!game || $('#play').hidden) return;
      ctx.clearRect(0, 0, cssW, cssH);
      game.draw(ctx, performance.now() / 1000);
      const st = game.status();
      $('#g-moves').textContent = st.label || `${st.moves}手`;
      $('#g-par').textContent = st.label ? '' : `目標 ${st.par}手`;
      $('#undo').disabled = !game.canUndo();
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
  }
  function won(st) {
    const c = cleared(meta.id);
    if (!c.includes(levelIndex)) store.set('cleared:' + meta.id, [...c, levelIndex]);
    const stars = st.label ? 3 : st.moves <= st.par ? 3 : st.moves <= st.par * 1.5 ? 2 : 1;
    $('#r-body').textContent = meta.id === 'pack' ? 'ぴったり詰めました'
      : meta.id === 'dashi' ? `${st.moves}回まわして、だしが届きました`
        : `${st.moves}手で配達（目標 ${st.par}手）`;
    $('#r-stars').innerHTML = [0, 1, 2].map((k) => `<i class="${k < stars ? 'on' : ''}">済</i>`).join('');
    const last = levelIndex >= LEVELS[meta.id].length - 1;
    $('#r-next').textContent = last ? 'ほかの案へ' : '次の出前へ';
    $('#receipt').hidden = false;
    $('#dots').querySelectorAll('.dot')[levelIndex].classList.add('on');
  }
  function toMenu() {
    game = null;
    cancelAnimationFrame(raf);
    $('#play').hidden = true;
    $('#menu').hidden = false;
    buildMenu();
  }

  // --------------------------------------------------------------- input
  function pos(e) {
    const r = canvas.getBoundingClientRect();
    return [e.clientX - r.left, e.clientY - r.top];
  }
  function wire() {
    canvas = $('#board');
    ctx = canvas.getContext('2d');
    canvas.addEventListener('pointerdown', (e) => {
      if (!game) return;
      canvas.setPointerCapture(e.pointerId);
      game.down && game.down(...pos(e));
      e.preventDefault();
    });
    canvas.addEventListener('pointermove', (e) => { if (game && game.move && e.buttons) game.move(...pos(e)); });
    canvas.addEventListener('pointerup', (e) => { if (game && game.up) game.up(...pos(e)); });
    canvas.addEventListener('pointercancel', (e) => { if (game && game.up) game.up(...pos(e)); });
    window.addEventListener('keydown', (e) => {
      if (!game) return;
      if (game.key) game.key(e.key);
      if (e.key === 'z' || e.key === 'Backspace') game.undo();
    });
    $('#undo').addEventListener('click', () => game && game.undo());
    $('#restart').addEventListener('click', () => game && start());
    $('#back').addEventListener('click', toMenu);
    $('#r-next').addEventListener('click', () => {
      if (levelIndex >= LEVELS[meta.id].length - 1) { toMenu(); return; }
      levelIndex++;
      start();
    });
    $('#r-again').addEventListener('click', start);
    $('#rule-toggle').addEventListener('click', () => { const r = $('#g-rule'); r.hidden = !r.hidden; });
    window.addEventListener('resize', resize);
  }

  function boot() {
    wire();
    buildMenu();
    // redraw thumbnails once the fonts arrive
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(buildMenu);
    const h = location.hash.replace('#', '');
    const i = GAMES.findIndex((g) => g.id === h);
    if (i >= 0) open(i, firstOpen(GAMES[i].id));
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
