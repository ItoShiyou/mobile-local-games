// Shared drawing: the delivery cat, guests, dishes and a few materials.
// Same world as つみあげ出前: washi paper, sumi-brown ink, wood, an indigo
// noren and vermilion stamps.
const C = {
  paper: '#F3EAD8', paperDeep: '#E6D6BA', card: '#FBF5EA', ink: '#3A2B22', inkSoft: '#7D6754',
  wood: '#C6955F', woodLight: '#E0B985', woodDark: '#7E5535', noren: '#2F4B6B', shu: '#C8452F',
  glow: '#FFC56B', leaf: '#6E9C58', hot: '#E58A5C', cold: '#86B8DA', skin: '#F6DCC0', navy: '#2E4666',
};

const Art = {
  rr(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  },
  // fill then outline in ink
  inked(ctx, fill, lw) {
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    ctx.lineWidth = lw;
    ctx.strokeStyle = C.ink;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.stroke();
  },
  ellipse(ctx, x, y, rx, ry, fill, lw) {
    ctx.beginPath();
    ctx.ellipse(x, y, Math.max(0.1, rx), Math.max(0.1, ry), 0, 0, Math.PI * 2);
    if (lw) Art.inked(ctx, fill, lw); else { ctx.fillStyle = fill; ctx.fill(); }
  },
  shadow(ctx, x, y, rx, ry) {
    Art.ellipse(ctx, x, y, rx, ry, 'rgba(58,43,34,.16)');
  },

  // ------------------------------------------------------------- the cat
  // (x, y) is the centre of the head, r its radius.
  cat(ctx, x, y, r, o = {}) {
    const face = o.facing || 'down';
    const t = o.t || 0;
    const lw = Math.max(1.2, r * 0.09);
    const side = face === 'left' ? -1 : face === 'right' ? 1 : 0;
    if (!o.noShadow) Art.shadow(ctx, x, y + r * 1.72, r * 1.05, r * 0.28);
    // tail
    const sway = Math.sin(t * 3.2) * r * 0.12;
    const tx = side === 0 ? -1 : -side;
    ctx.beginPath();
    ctx.moveTo(x + tx * r * 0.5, y + r * 1.35);
    ctx.bezierCurveTo(x + tx * r * 1.3, y + r * 1.45, x + tx * r * 1.25 + sway, y + r * 0.7, x + tx * r * 1.0 + sway, y + r * 0.55);
    ctx.lineWidth = r * 0.26;
    ctx.strokeStyle = C.ink;
    ctx.lineCap = 'round';
    ctx.stroke();
    ctx.lineWidth = r * 0.26 - lw * 1.6;
    ctx.strokeStyle = '#E39A52';
    ctx.stroke();
    // body: a navy happi coat
    ctx.beginPath();
    ctx.moveTo(x - r * 0.62, y + r * 0.62);
    ctx.lineTo(x + r * 0.62, y + r * 0.62);
    ctx.quadraticCurveTo(x + r * 0.86, y + r * 1.3, x + r * 0.78, y + r * 1.62);
    ctx.lineTo(x - r * 0.78, y + r * 1.62);
    ctx.quadraticCurveTo(x - r * 0.86, y + r * 1.3, x - r * 0.62, y + r * 0.62);
    Art.inked(ctx, C.navy, lw);
    if (face !== 'up') {
      ctx.beginPath();
      ctx.moveTo(x - r * 0.3, y + r * 0.7);
      ctx.lineTo(x + side * r * 0.1, y + r * 1.2);
      ctx.lineTo(x + r * 0.3, y + r * 0.7);
      ctx.lineWidth = r * 0.12;
      ctx.strokeStyle = '#F4EBDD';
      ctx.stroke();
    }
    // paws
    Art.ellipse(ctx, x - r * 0.42, y + r * 1.62, r * 0.22, r * 0.13, '#FFFDF8', lw * 0.8);
    Art.ellipse(ctx, x + r * 0.42, y + r * 1.62, r * 0.22, r * 0.13, '#FFFDF8', lw * 0.8);
    // ears
    const ear = (sx, fill) => {
      ctx.beginPath();
      ctx.moveTo(x + sx * r * 0.88, y - r * 0.2);
      ctx.lineTo(x + sx * r * 0.8, y - r * 1.02);
      ctx.lineTo(x + sx * r * 0.22, y - r * 0.72);
      ctx.closePath();
      Art.inked(ctx, fill, lw);
      if (face !== 'up') {
        ctx.beginPath();
        ctx.moveTo(x + sx * r * 0.74, y - r * 0.4);
        ctx.lineTo(x + sx * r * 0.72, y - r * 0.82);
        ctx.lineTo(x + sx * r * 0.4, y - r * 0.66);
        ctx.closePath();
        ctx.fillStyle = '#F2B8B0';
        ctx.fill();
      }
    };
    ear(-1, '#E39A52');
    ear(1, '#5A4034');
    // head
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(x, y, r * 1.02, r * 0.9, 0, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFDF8';
    ctx.fill();
    ctx.clip();
    // calico patches
    Art.ellipse(ctx, x - r * 0.72 - side * r * 0.1, y - r * 0.55, r * 0.6, r * 0.45, '#E39A52');
    Art.ellipse(ctx, x + r * 0.85 - side * r * 0.1, y - r * 0.5, r * 0.42, r * 0.36, '#5A4034');
    if (face === 'up') Art.ellipse(ctx, x + r * 0.1, y + r * 0.1, r * 0.5, r * 0.4, '#E39A52');
    ctx.restore();
    ctx.beginPath();
    ctx.ellipse(x, y, r * 1.02, r * 0.9, 0, 0, Math.PI * 2);
    Art.inked(ctx, null, lw);
    // headband
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(x, y, r * 1.02, r * 0.9, 0, 0, Math.PI * 2);
    ctx.clip();
    ctx.fillStyle = C.shu;
    ctx.beginPath();
    ctx.moveTo(x - r * 1.1, y - r * 0.5);
    ctx.quadraticCurveTo(x, y - r * 0.28, x + r * 1.1, y - r * 0.5);
    ctx.lineTo(x + r * 1.1, y - r * 0.26);
    ctx.quadraticCurveTo(x, y - r * 0.04, x - r * 1.1, y - r * 0.26);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
    // knot and tails, fluttering
    const kx = x + (face === 'left' ? r * 0.95 : -r * 0.95), ky = y - r * 0.38;
    const flap = Math.sin(t * 5) * r * 0.06;
    const dirK = face === 'left' ? 1 : -1;
    ctx.fillStyle = C.shu;
    for (const k of [0, 1]) {
      ctx.beginPath();
      ctx.moveTo(kx, ky);
      ctx.lineTo(kx + dirK * r * (0.55 + k * 0.1), ky - r * (0.25 - k * 0.35) + flap * (k ? -1 : 1));
      ctx.lineTo(kx + dirK * r * (0.45 + k * 0.1), ky - r * (0.05 - k * 0.35) + flap * (k ? -1 : 1));
      ctx.closePath();
      Art.inked(ctx, C.shu, lw * 0.8);
    }
    Art.ellipse(ctx, kx, ky, r * 0.12, r * 0.12, C.shu, lw * 0.8);
    // face
    if (face !== 'up') {
      const fx = x + side * r * 0.22;
      const blink = o.happy || (Math.sin(t * 1.3) > 0.985);
      ctx.strokeStyle = C.ink;
      ctx.fillStyle = C.ink;
      ctx.lineWidth = lw;
      for (const s of [-1, 1]) {
        const ex = fx + s * r * 0.36, ey = y + r * 0.05;
        if (blink) {
          ctx.beginPath();
          ctx.arc(ex, ey + r * 0.05, r * 0.11, Math.PI * 1.1, Math.PI * 1.9);
          ctx.stroke();
        } else {
          Art.ellipse(ctx, ex, ey, r * 0.085, r * 0.11, C.ink);
          Art.ellipse(ctx, ex + r * 0.03, ey - r * 0.04, r * 0.03, r * 0.03, '#fff');
        }
      }
      Art.ellipse(ctx, fx - r * 0.6, y + r * 0.3, r * 0.14, r * 0.08, 'rgba(236,140,130,.55)');
      Art.ellipse(ctx, fx + r * 0.6, y + r * 0.3, r * 0.14, r * 0.08, 'rgba(236,140,130,.55)');
      ctx.beginPath();
      ctx.moveTo(fx - r * 0.07, y + r * 0.2);
      ctx.lineTo(fx + r * 0.07, y + r * 0.2);
      ctx.lineTo(fx, y + r * 0.28);
      ctx.closePath();
      ctx.fillStyle = '#E58C86';
      ctx.fill();
      ctx.beginPath();
      ctx.arc(fx - r * 0.08, y + r * 0.3, r * 0.08, 0.1 * Math.PI, 0.9 * Math.PI);
      ctx.arc(fx + r * 0.08, y + r * 0.3, r * 0.08, 0.1 * Math.PI, 0.9 * Math.PI);
      ctx.lineWidth = lw * 0.8;
      ctx.strokeStyle = C.ink;
      ctx.stroke();
    }
    // plates carried on the head
    (o.carry || []).forEach((kind, i) => Art.plate(ctx, x, y - r * (1.05 + i * 0.42), r * 0.85, kind));
  },

  // -------------------------------------------------------------- guests
  guest(ctx, x, y, r, type, o = {}) {
    const lw = Math.max(1.2, r * 0.09);
    const g = [
      { hair: '#3B3029', shirt: '#6F8FB4', glasses: true }, // salaryman
      { hair: '#B8B4AE', shirt: '#A07BB0', bun: true }, // grandma
      { hair: '#5A3A2A', shirt: '#E2A0A0', bob: true }, // girl
      { hair: '#3B3029', shirt: '#7FA36A', cap: true }, // boy
      { hair: '#8C8278', shirt: '#C9A26A', beard: true }, // grandpa
    ][type % 5];
    const bob = o.happy ? Math.sin((o.t || 0) * 6) * r * 0.06 : 0;
    const shake = o.upset ? Math.sin((o.t || 0) * 40) * r * 0.08 * Math.max(0, 1 - (o.upsetAge || 0) / 0.6) : 0;
    x += shake; y += bob;
    Art.shadow(ctx, x, y + r * 1.55, r * 0.9, r * 0.22);
    Art.rr(ctx, x - r * 0.78, y + r * 0.62, r * 1.56, r * 0.95, r * 0.4);
    Art.inked(ctx, g.shirt, lw);
    if (g.bun) Art.ellipse(ctx, x, y - r * 0.95, r * 0.35, r * 0.28, g.hair, lw);
    Art.ellipse(ctx, x, y, r * 0.86, r * 0.84, C.skin, lw);
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(x, y, r * 0.86, r * 0.84, 0, 0, Math.PI * 2);
    ctx.clip();
    ctx.fillStyle = g.hair;
    if (g.bob) {
      ctx.fillRect(x - r, y - r, r * 2, r * 0.62);
      ctx.fillRect(x - r, y - r, r * 0.3, r * 1.6);
      ctx.fillRect(x + r * 0.7, y - r, r * 0.3, r * 1.6);
    } else if (g.cap) {
      ctx.fillStyle = '#3F6FA0';
      ctx.fillRect(x - r, y - r, r * 2, r * 0.55);
    } else {
      ctx.beginPath();
      ctx.ellipse(x, y - r * 0.72, r * 0.95, r * 0.5, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
    ctx.beginPath();
    ctx.ellipse(x, y, r * 0.86, r * 0.84, 0, 0, Math.PI * 2);
    Art.inked(ctx, null, lw);
    if (g.cap) {
      ctx.beginPath();
      ctx.moveTo(x - r * 0.2, y - r * 0.44);
      ctx.lineTo(x + r * 1.0, y - r * 0.4);
      ctx.lineWidth = lw * 1.6;
      ctx.strokeStyle = '#3F6FA0';
      ctx.stroke();
    }
    // face
    ctx.strokeStyle = C.ink;
    ctx.fillStyle = C.ink;
    ctx.lineWidth = lw;
    for (const s of [-1, 1]) {
      if (o.happy) {
        ctx.beginPath();
        ctx.arc(x + s * r * 0.3, y + r * 0.08, r * 0.1, Math.PI * 1.1, Math.PI * 1.9);
        ctx.stroke();
      } else Art.ellipse(ctx, x + s * r * 0.3, y + r * 0.05, r * 0.07, r * 0.09, C.ink);
    }
    if (g.glasses) {
      ctx.lineWidth = lw * 0.7;
      for (const s of [-1, 1]) { ctx.beginPath(); ctx.arc(x + s * r * 0.3, y + r * 0.05, r * 0.19, 0, Math.PI * 2); ctx.stroke(); }
    }
    if (g.beard) Art.ellipse(ctx, x, y + r * 0.55, r * 0.35, r * 0.2, '#E8E2DA', lw * 0.6);
    ctx.beginPath();
    if (o.happy) ctx.arc(x, y + r * 0.3, r * 0.16, 0.1 * Math.PI, 0.9 * Math.PI);
    else if (o.upset) ctx.arc(x, y + r * 0.48, r * 0.14, 1.15 * Math.PI, 1.85 * Math.PI);
    else { ctx.moveTo(x - r * 0.1, y + r * 0.4); ctx.lineTo(x + r * 0.1, y + r * 0.4); }
    ctx.lineWidth = lw * 0.9;
    ctx.stroke();
    Art.ellipse(ctx, x - r * 0.55, y + r * 0.3, r * 0.12, r * 0.07, 'rgba(236,140,130,.45)');
    Art.ellipse(ctx, x + r * 0.55, y + r * 0.3, r * 0.12, r * 0.07, 'rgba(236,140,130,.45)');
    if (o.happy) Art.note(ctx, x + r * 0.9, y - r * 0.9 - bob * 2, r * 0.5);
  },
  note(ctx, x, y, s) {
    ctx.fillStyle = C.shu;
    ctx.font = `bold ${s}px "Zen Maru Gothic", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('♪', x, y);
  },
  // order ticket: a small paper slip with a dish on it
  ticket(ctx, x, y, s, kind, o = {}) {
    const lw = Math.max(1, s * 0.07);
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(o.tilt || -0.06);
    Art.rr(ctx, -s * 0.55, -s * 0.55, s * 1.1, s * 1.1, s * 0.12);
    Art.inked(ctx, o.done ? '#EFE6D2' : '#FFFBF2', lw);
    ctx.globalAlpha = o.done ? 0.45 : 1;
    Art.food(ctx, kind, 0, s * 0.02, s * 0.38);
    ctx.globalAlpha = 1;
    if (o.done) Art.hanko(ctx, s * 0.22, s * 0.2, s * 0.26, '済');
    ctx.restore();
  },
  hanko(ctx, x, y, r, ch) {
    ctx.save();
    ctx.globalAlpha = 0.9;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.lineWidth = r * 0.16;
    ctx.strokeStyle = C.shu;
    ctx.stroke();
    ctx.fillStyle = C.shu;
    ctx.font = `bold ${r * 1.1}px "Yusei Magic", "Zen Maru Gothic", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(ch, x, y + r * 0.05);
    ctx.restore();
  },

  // --------------------------------------------------------------- dishes
  plate(ctx, x, y, r, kind) {
    const lw = Math.max(1, r * 0.07);
    Art.ellipse(ctx, x, y + r * 0.18, r * 0.62, r * 0.2, '#FFFDF6', lw);
    ctx.beginPath();
    ctx.ellipse(x, y + r * 0.18, r * 0.44, r * 0.12, 0, 0, Math.PI);
    ctx.strokeStyle = '#4A6F9E';
    ctx.lineWidth = lw * 0.8;
    ctx.stroke();
    Art.food(ctx, kind, x, y - r * 0.04, r * 0.36);
  },
  food(ctx, kind, x, y, r) {
    const lw = Math.max(1, r * 0.12);
    const E = (xx, yy, rx, ry, f, l = lw) => Art.ellipse(ctx, xx, yy, rx, ry, f, l);
    switch (kind) {
      case 'ramen': case 'miso': {
        E(x, y - r * 0.1, r, r * 0.4, kind === 'ramen' ? '#F2D39A' : '#B7803F');
        ctx.beginPath();
        ctx.moveTo(x - r, y - r * 0.1);
        ctx.quadraticCurveTo(x - r * 0.9, y + r * 0.9, x, y + r * 0.9);
        ctx.quadraticCurveTo(x + r * 0.9, y + r * 0.9, x + r, y - r * 0.1);
        Art.inked(ctx, kind === 'ramen' ? '#C8452F' : '#3A2B22', lw);
        if (kind === 'ramen') {
          E(x + r * 0.35, y - r * 0.12, r * 0.22, r * 0.12, '#FFF6F2', lw * 0.6);
          ctx.strokeStyle = '#6E9C58'; ctx.lineWidth = lw; ctx.beginPath(); ctx.moveTo(x - r * 0.5, y - r * 0.15); ctx.lineTo(x - r * 0.15, y - r * 0.05); ctx.stroke();
        } else {
          E(x - r * 0.3, y - r * 0.12, r * 0.1, r * 0.06, '#E8E2C8', 0);
          E(x + r * 0.2, y - r * 0.05, r * 0.1, r * 0.06, '#6E9C58', 0);
        }
        break;
      }
      case 'soba': {
        Art.rr(ctx, x - r, y - r * 0.2, r * 2, r * 0.8, r * 0.2);
        Art.inked(ctx, '#C9A26A', lw);
        E(x, y - r * 0.1, r * 0.75, r * 0.4, '#8C7A68', lw);
        ctx.strokeStyle = '#6A5A4A'; ctx.lineWidth = lw * 0.6;
        for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.moveTo(x - r * 0.5, y - r * 0.1 + i * r * 0.12); ctx.quadraticCurveTo(x, y + i * r * 0.12, x + r * 0.5, y - r * 0.1 + i * r * 0.12); ctx.stroke(); }
        break;
      }
      case 'sushi': {
        for (const s of [-1, 1]) {
          Art.rr(ctx, x + s * r * 0.5 - r * 0.42, y - r * 0.1, r * 0.84, r * 0.55, r * 0.2);
          Art.inked(ctx, '#FFFDF6', lw);
          Art.rr(ctx, x + s * r * 0.5 - r * 0.48, y - r * 0.42, r * 0.96, r * 0.4, r * 0.18);
          Art.inked(ctx, s < 0 ? '#F08A5D' : '#D8433A', lw);
        }
        break;
      }
      case 'tamago': {
        Art.rr(ctx, x - r * 0.8, y - r * 0.45, r * 1.6, r * 0.9, r * 0.15);
        Art.inked(ctx, '#F4CF4A', lw);
        ctx.fillStyle = '#2F3B2F';
        ctx.fillRect(x - r * 0.15, y - r * 0.45, r * 0.3, r * 0.9);
        break;
      }
      case 'onigiri': {
        ctx.beginPath();
        ctx.moveTo(x, y - r * 0.85);
        ctx.quadraticCurveTo(x + r * 0.2, y - r * 0.85, x + r * 0.85, y + r * 0.45);
        ctx.quadraticCurveTo(x + r * 0.9, y + r * 0.7, x + r * 0.6, y + r * 0.7);
        ctx.lineTo(x - r * 0.6, y + r * 0.7);
        ctx.quadraticCurveTo(x - r * 0.9, y + r * 0.7, x - r * 0.85, y + r * 0.45);
        ctx.quadraticCurveTo(x - r * 0.2, y - r * 0.85, x, y - r * 0.85);
        Art.inked(ctx, '#FFFDF6', lw);
        ctx.fillStyle = '#2F3B2F';
        ctx.fillRect(x - r * 0.4, y + r * 0.2, r * 0.8, r * 0.5);
        break;
      }
      case 'gyoza': {
        for (const s of [-1, 0, 1]) {
          ctx.beginPath();
          ctx.ellipse(x + s * r * 0.55, y, r * 0.32, r * 0.55, s * 0.2, 0, Math.PI * 2);
          Art.inked(ctx, '#F2D8A8', lw);
          ctx.beginPath();
          ctx.moveTo(x + s * r * 0.55 - r * 0.2, y + r * 0.35);
          ctx.lineTo(x + s * r * 0.55 + r * 0.2, y + r * 0.35);
          ctx.strokeStyle = '#C98A45'; ctx.lineWidth = lw * 1.4; ctx.stroke();
        }
        break;
      }
      case 'tempura': {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(-0.5);
        E(0, 0, r * 0.95, r * 0.36, '#EDB654');
        ctx.beginPath(); ctx.moveTo(r * 0.9, 0); ctx.lineTo(r * 1.2, -r * 0.25); ctx.lineTo(r * 1.2, r * 0.25); ctx.closePath();
        Art.inked(ctx, '#E0553B', lw);
        ctx.restore();
        break;
      }
      case 'purin': {
        ctx.beginPath();
        ctx.moveTo(x - r * 0.5, y - r * 0.5);
        ctx.lineTo(x + r * 0.5, y - r * 0.5);
        ctx.lineTo(x + r * 0.75, y + r * 0.55);
        ctx.lineTo(x - r * 0.75, y + r * 0.55);
        ctx.closePath();
        Art.inked(ctx, '#F6D77A', lw);
        E(x, y - r * 0.52, r * 0.5, r * 0.16, '#8A4E22', lw);
        break;
      }
      case 'salad': {
        E(x, y + r * 0.1, r, r * 0.55, '#DDEFF6', lw);
        for (const [dx, dy, c] of [[-0.4, -0.1, '#7FB069'], [0.1, -0.2, '#5E9A4C'], [0.45, 0, '#D8433A'], [-0.05, 0.1, '#9CCB7A']]) E(x + dx * r, y + dy * r, r * 0.3, r * 0.2, c, lw * 0.6);
        break;
      }
      case 'dango': {
        ctx.strokeStyle = '#A8845A'; ctx.lineWidth = lw * 1.2;
        ctx.beginPath(); ctx.moveTo(x - r, y + r * 0.6); ctx.lineTo(x + r, y - r * 0.6); ctx.stroke();
        [['#F2B8C6', -0.5], ['#FFFDF6', 0], ['#8CBF6A', 0.5]].forEach(([c, k]) => E(x + k * r * 1.1, y - k * r * 0.66, r * 0.33, r * 0.33, c));
        break;
      }
      case 'bento': {
        Art.rr(ctx, x - r, y - r * 0.7, r * 2, r * 1.4, r * 0.18);
        Art.inked(ctx, '#2B2B2B', lw);
        Art.rr(ctx, x - r * 0.85, y - r * 0.55, r * 0.95, r * 1.1, r * 0.1);
        Art.inked(ctx, '#FFFDF6', lw * 0.6);
        E(x - r * 0.38, y, r * 0.14, r * 0.14, '#D8433A', 0);
        E(x + r * 0.5, y - r * 0.2, r * 0.3, r * 0.2, '#F4CF4A', lw * 0.6);
        E(x + r * 0.5, y + r * 0.3, r * 0.3, r * 0.2, '#7FB069', lw * 0.6);
        break;
      }
      // oden
      case 'daikon': {
        E(x, y + r * 0.25, r * 0.8, r * 0.35, '#F3E7C4');
        ctx.beginPath();
        ctx.rect(x - r * 0.8, y - r * 0.3, r * 1.6, r * 0.55);
        ctx.fillStyle = '#F3E7C4'; ctx.fill();
        ctx.beginPath(); ctx.moveTo(x - r * 0.8, y - r * 0.3); ctx.lineTo(x - r * 0.8, y + r * 0.25); ctx.moveTo(x + r * 0.8, y - r * 0.3); ctx.lineTo(x + r * 0.8, y + r * 0.25);
        ctx.lineWidth = lw; ctx.strokeStyle = C.ink; ctx.stroke();
        E(x, y - r * 0.3, r * 0.8, r * 0.35, '#E6CFA0');
        break;
      }
      case 'egg': {
        E(x, y, r * 0.62, r * 0.82, '#C98A45');
        E(x - r * 0.15, y - r * 0.25, r * 0.15, r * 0.22, 'rgba(255,255,255,.4)', 0);
        break;
      }
      case 'chikuwa': {
        ctx.save(); ctx.translate(x, y); ctx.rotate(-0.4);
        Art.rr(ctx, -r, -r * 0.34, r * 2, r * 0.68, r * 0.34);
        Art.inked(ctx, '#E9D2A0', lw);
        ctx.fillStyle = '#B86F35';
        ctx.fillRect(-r * 0.7, -r * 0.34, r * 1.4, r * 0.3);
        E(r * 0.95, 0, r * 0.14, r * 0.3, '#7A4A2A', lw * 0.6);
        ctx.restore();
        break;
      }
      case 'konnyaku': {
        ctx.beginPath(); ctx.moveTo(x, y - r * 0.8); ctx.lineTo(x + r * 0.85, y + r * 0.6); ctx.lineTo(x - r * 0.85, y + r * 0.6); ctx.closePath();
        Art.inked(ctx, '#8C8A86', lw);
        ctx.fillStyle = '#5E5C58';
        for (const [dx, dy] of [[-0.2, 0.2], [0.2, 0.3], [0, -0.1], [-0.35, 0.45], [0.4, 0.45]]) ctx.fillRect(x + dx * r, y + dy * r, r * 0.07, r * 0.07);
        break;
      }
      case 'ganmo': {
        E(x, y, r * 0.85, r * 0.7, '#C9803F');
        ctx.fillStyle = '#6E9C58';
        ctx.fillRect(x - r * 0.3, y - r * 0.1, r * 0.12, r * 0.12);
        ctx.fillStyle = '#D8433A';
        ctx.fillRect(x + r * 0.2, y + r * 0.1, r * 0.12, r * 0.12);
        break;
      }
      default: E(x, y, r * 0.7, r * 0.7, '#ddd');
    }
  },
};

const FOOD_NAME = {
  daikon: '大根', egg: '卵', chikuwa: 'ちくわ', konnyaku: 'こんにゃく', ganmo: 'がんも',
  ramen: 'ラーメン', soba: 'ざるそば', sushi: 'お寿司', tamago: '卵焼き', onigiri: 'おにぎり', gyoza: '餃子',
  miso: 'みそ汁', tempura: '天ぷら', purin: 'プリン', salad: 'サラダ', dango: 'だんご', bento: 'お弁当',
};

// A seeded wobble for hand-drawn lines.
function wob(i, j, k = 0) {
  const s = Math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453;
  return s - Math.floor(s) - 0.5;
}
