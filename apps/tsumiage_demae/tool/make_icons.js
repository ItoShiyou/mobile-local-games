// Renders the app icon at every size the platforms need.
//   node tool/make_icons.js      (needs Playwright + Chromium)
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const ROOT = path.join(__dirname, '..');

// The App Store rejects app icons with an alpha channel, even a fully
// opaque one: re-encode an RGBA PNG (8-bit, as the canvas writes it) as RGB.
function opaquePng(png) {
  const zlib = require('zlib');
  let pos = 8, w = 0, h = 0;
  const idat = [];
  while (pos < png.length) {
    const len = png.readUInt32BE(pos), type = png.toString('ascii', pos + 4, pos + 8);
    const data = png.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') {
      w = data.readUInt32BE(0); h = data.readUInt32BE(4);
      if (data[8] !== 8 || data[9] !== 6 || data[12] !== 0) throw new Error('expected 8-bit RGBA, not interlaced');
    } else if (type === 'IDAT') idat.push(data);
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * 4, out = Buffer.alloc(h * (w * 3 + 1));
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let i = 0; i < stride; i++) {
      const a = i >= 4 ? line[i - 4] : 0, b = prev[i], c = i >= 4 ? prev[i - 4] : 0;
      let add = 0;
      if (f === 1) add = a;
      else if (f === 2) add = b;
      else if (f === 3) add = (a + b) >> 1;
      else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); add = pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      line[i] = (line[i] + add) & 255;
    }
    const o = y * (w * 3 + 1);
    for (let x = 0; x < w; x++) line.copy(out, o + 1 + x * 3, x * 4, x * 4 + 3);
    prev = line;
  }
  const chunk = (type, data) => {
    const head = Buffer.alloc(8); head.writeUInt32BE(data.length, 0); head.write(type, 4, 'ascii');
    const crc = Buffer.alloc(4); crc.writeUInt32BE(zlib.crc32(Buffer.concat([head.subarray(4), data])), 0);
    return Buffer.concat([head, data, crc]);
  };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([png.subarray(0, 8), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(out, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

// Draws the icon on a canvas of size s. `mode`: 'full' (square, background),
// 'fg' (adaptive-icon foreground: transparent, art inside the 66% safe zone),
// 'mask' (web maskable: background, art in the safe zone).
const draw = `
function draw(s, mode) {
  const c = document.createElement('canvas'); c.width = c.height = s;
  const x = c.getContext('2d');
  // deterministic noise, so every size gets the same print texture
  let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  if (mode !== 'fg') {
    // flat kinari paper, no gradient: depth comes from the print, not an airbrush
    x.fillStyle = '#F1E4C8'; x.fillRect(0, 0, s, s);
    if (mode === 'full') {
      // a noren across the top: four indigo panels with uneven slits and a darker hem
      x.fillStyle = '#2C4766'; x.fillRect(0, 0, s, s * .16);
      x.fillStyle = 'rgba(0,0,0,.18)'; x.fillRect(0, s * .135, s, s * .025);
      x.fillStyle = '#F1E4C8';
      [[.245, .1], [.505, .12], [.75, .09]].forEach(([fx, fh]) => x.fillRect(s * fx - s * .006, s * .03, s * .012, s * fh));
    }
  }
  const k = mode === 'full' ? 1 : .72;
  x.save();
  x.translate(s / 2, s / 2); x.scale(s * k / 1024, s * k / 1024); x.translate(-512, -512);
  const INK = '#33251E';
  const stroke = (w) => { x.lineWidth = w; x.strokeStyle = INK; x.lineJoin = 'round'; x.lineCap = 'round'; x.stroke(); };
  // printed fill: heavier ink on the shadow side (bottom right), colour a hair off register (up left), thin key line on top
  const inked = (shape, col, w) => {
    x.save(); x.translate(w * .3, w * .4); x.beginPath(); shape(); x.fillStyle = INK; x.fill(); x.restore();
    x.save(); x.translate(-w * .5, -w * .35); x.beginPath(); shape(); x.fillStyle = col; x.fill(); x.restore();
    x.beginPath(); shape(); stroke(w * .72);
  };
  const nick = (cx, cy, len, w, a) => { const dx = Math.cos(a) * len / 2, dy = Math.sin(a) * len / 2;
    x.beginPath(); x.moveTo(cx - dx, cy - dy); x.quadraticCurveTo(cx - dy * .35, cy + dx * .35, cx + dx, cy + dy); x.strokeStyle = 'rgba(255,248,234,.9)'; x.lineWidth = w; x.lineCap = 'round'; x.stroke(); };
  // shadow: flat and hard edged, offset to the right
  x.fillStyle = 'rgba(60,30,20,.2)'; x.beginPath(); x.ellipse(530, 915, 250, 40, 0, 0, 7); x.fill();
  // body in an indigo happi coat
  inked(() => { x.moveTo(330, 910); x.quadraticCurveTo(318, 770, 420, 760); x.lineTo(604, 760); x.quadraticCurveTo(706, 770, 694, 910); x.closePath(); }, '#2C4766', 18);
  x.strokeStyle = '#F4EBD9'; x.lineCap = 'round'; x.lineWidth = 26; x.beginPath(); x.moveTo(440, 775); x.lineTo(510, 900); x.stroke();
  x.lineWidth = 22; x.beginPath(); x.moveTo(514, 900); x.lineTo(584, 775); x.stroke();
  // ears: not a mirrored pair
  const fur = '#FBF3E4';
  for (const sx of [-1, 1]) {
    const tipX = sx < 0 ? 150 : 162, tipY = sx < 0 ? 425 : 438;
    inked(() => { x.moveTo(512 + sx * 172, 600); x.lineTo(512 + sx * tipX, tipY); x.lineTo(512 + sx * 50, 505); x.closePath(); }, fur, 18);
    x.beginPath(); x.moveTo(512 + sx * 145 - 8, 570 - 6); x.lineTo(512 + sx * (tipX - 10) - 8, tipY + 46 - 6); x.lineTo(512 + sx * 80 - 8, 520 - 6); x.closePath();
    x.fillStyle = '#EFA7AF'; x.fill();
  }
  // head with an irregular calico patch
  const head = () => x.ellipse(512, 640, 200, 178, 0, 0, 7);
  inked(head, fur, 20);
  x.save(); x.translate(-8, -6); x.beginPath(); head(); x.clip();
  x.fillStyle = '#D69A5C'; x.beginPath(); x.moveTo(280, 470); x.lineTo(490, 455); x.bezierCurveTo(515, 520, 500, 580, 470, 600);
  x.bezierCurveTo(440, 630, 400, 620, 380, 645); x.lineTo(300, 600); x.closePath(); x.fill(); x.restore();
  x.beginPath(); head(); stroke(14);
  // cheek tufts, one per side, not mirrored
  x.beginPath(); x.moveTo(316, 668); x.lineTo(298, 690); x.lineTo(322, 700); stroke(9);
  x.beginPath(); x.moveTo(705, 690); x.lineTo(726, 712); x.lineTo(694, 724); stroke(9);
  // hachimaki and its tails
  inked(() => { x.moveTo(314, 612); x.quadraticCurveTo(512, 552, 710, 612); x.lineTo(706, 648); x.quadraticCurveTo(512, 590, 318, 648); x.closePath(); }, '#C9432C', 14);
  for (const [dx, dy] of [[-88, -40], [-74, 30]]) inked(() => { x.moveTo(318, 625); x.lineTo(318 + dx, 625 + dy - 18); x.lineTo(318 + dx + 10, 625 + dy + 18); x.closePath(); }, '#C9432C', 12);
  // eyes, nose, mouth, blush, whiskers
  for (const sx of [-1, 1]) {
    x.fillStyle = INK; x.beginPath(); x.ellipse(512 + sx * 72, 670, 26, 34, 0, 0, 7); x.fill();
    x.fillStyle = '#FFFBF0'; x.beginPath(); x.arc(512 + sx * 72 + 9, 656, 10, 0, 7); x.fill();
    x.fillStyle = 'rgba(236,138,150,.42)'; x.beginPath(); x.ellipse(512 + sx * 125, 720, 30, 20, 0, 0, 7); x.fill();
    x.strokeStyle = 'rgba(217,98,111,.65)'; x.lineWidth = 5; x.lineCap = 'round';
    for (const h of [-12, 0, 12]) { x.beginPath(); x.moveTo(512 + sx * 125 + h + 4, 712); x.lineTo(512 + sx * 125 + h - 3, 728); x.stroke(); }
    const wy = sx < 0 ? 0 : 6;
    x.beginPath(); x.moveTo(512 + sx * 150, 700 + wy); x.quadraticCurveTo(512 + sx * 195, 684 + wy, 512 + sx * 240, 688 + wy); stroke(7);
    x.beginPath(); x.moveTo(512 + sx * 150, 726 + wy); x.quadraticCurveTo(512 + sx * 195, 728 + wy, 512 + sx * (sx < 0 ? 236 : 222), 742 + wy); stroke(6);
  }
  x.fillStyle = '#DB6F7E'; x.beginPath(); x.arc(512, 712, 15, 0, 7); x.fill();
  x.strokeStyle = INK; x.lineWidth = 8; x.beginPath(); x.arc(494, 728, 18, .3, Math.PI - .3); x.stroke(); x.beginPath(); x.arc(530, 728, 18, .3, Math.PI - .3); x.stroke();
  // stacked dishes
  const dishes = [['#F0C13F', 'egg'], ['#6FA64E', 'dango'], ['#E0564A', 'tomato']];
  dishes.forEach(([col, kind], i) => {
    const y = 425 - i * 115;
    if (kind === 'egg') { inked(() => x.roundRect(430, y - 88, 164, 80, 22), col, 14);
      x.strokeStyle = '#C98E1E'; x.lineWidth = 9; for (const dx of [-28, 28]) { x.beginPath(); x.moveTo(512 + dx, y - 82); x.lineTo(512 + dx, y - 16); x.stroke(); } }
    if (kind === 'dango') { x.strokeStyle = INK; x.lineWidth = 22; x.beginPath(); x.moveTo(420, y - 20); x.lineTo(604, y - 20); x.stroke();
      x.strokeStyle = '#D8B27A'; x.lineWidth = 10; x.beginPath(); x.moveTo(420, y - 20); x.lineTo(604, y - 20); x.stroke();
      for (const dx of [-60, 0, 60]) { inked(() => x.ellipse(512 + dx, y - 50, 37, 35, 0, 0, 7), dx === 0 ? '#A9C46A' : col, 13);
        if (dx !== 0) nick(498 + dx, y - 62, 18, 8, -1.2); } }
    if (kind === 'tomato') {
      inked(() => { x.moveTo(512, y - 108); x.bezierCurveTo(560, y - 120, 584, y - 80, 572, y - 40); x.bezierCurveTo(560, y, 470, y + 2, 455, y - 26); x.bezierCurveTo(438, y - 64, 464, y - 114, 512, y - 108); x.closePath(); }, col, 14);
      nick(482, y - 82, 26, 9, -1.1);
      x.fillStyle = '#4E8A3E'; x.beginPath();
      for (let a = 0; a < 5; a++) { const t = -Math.PI / 2 + a * 2 * Math.PI / 5; x.moveTo(512, y - 112); x.lineTo(512 + Math.cos(t - .4) * 12, y - 112 + Math.sin(t - .4) * 8); x.lineTo(512 + Math.cos(t) * 40, y - 112 + Math.sin(t) * 20); x.lineTo(512 + Math.cos(t + .4) * 12, y - 112 + Math.sin(t + .4) * 8); }
      x.fill(); stroke(6); }
    // plate (side view) in front of the food
    inked(() => { x.moveTo(300, y - 6); x.quadraticCurveTo(512, y + 26, 724, y - 6); x.lineTo(650, y + 40); x.lineTo(374, y + 40); x.closePath(); }, '#FFF9EC', 14);
    x.strokeStyle = '#3F6596'; x.lineWidth = 7; x.beginPath(); x.moveTo(330, y + 8); x.quadraticCurveTo(512, y + 34, 694, y + 8); x.stroke();
  });
  x.restore();
  // print texture over everything: starved specks and uneven coverage
  x.save();
  if (mode === 'fg') x.globalCompositeOperation = 'source-atop';
  x.filter = 'blur(' + (s * .012) + 'px)';
  for (let i = 0; i < 30; i++) { x.fillStyle = 'rgba(255,255,255,' + (.025 + rnd() * .03) + ')'; x.beginPath(); x.ellipse(rnd() * s, rnd() * s, s * (.02 + rnd() * .035), s * (.015 + rnd() * .03), rnd() * 3, 0, 7); x.fill(); }
  x.filter = 'none';
  for (let i = 0; i < 900; i++) { x.fillStyle = 'rgba(255,251,240,' + (.06 + rnd() * .2) + ')'; x.fillRect(rnd() * s, rnd() * s, s * .0015 + rnd() * s * .0015, s * .001 + rnd() * s * .001); }
  x.restore();
  return c.toDataURL('image/png');
}`;

const jobs = [
  // iOS
  ...[[20, 1], [20, 2], [20, 3], [29, 1], [29, 2], [29, 3], [40, 1], [40, 2], [40, 3], [60, 2], [60, 3], [76, 1], [76, 2], [83.5, 2], [1024, 1]]
    .map(([pt, x]) => [`ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-${pt}x${pt}@${x}x.png`, Math.round(pt * x), 'full']),
  // Android legacy + adaptive foreground
  ...[['mdpi', 48, 108], ['hdpi', 72, 162], ['xhdpi', 96, 216], ['xxhdpi', 144, 324], ['xxxhdpi', 192, 432]].flatMap(([d, s, fg]) => [
    [`android/app/src/main/res/mipmap-${d}/ic_launcher.png`, s, 'full'],
    [`android/app/src/main/res/drawable-${d}/ic_launcher_foreground.png`, fg, 'fg'],
  ]),
  // Web
  ['web/favicon.png', 32, 'full'],
  ['web/icons/Icon-192.png', 192, 'full'],
  ['web/icons/Icon-512.png', 512, 'full'],
  ['web/icons/Icon-maskable-192.png', 192, 'mask'],
  ['web/icons/Icon-maskable-512.png', 512, 'mask'],
  // Store listing
  ['store/icon-512.png', 512, 'full'],
];

(async () => {
  const b = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const p = await b.newPage();
  await p.setContent('<html><body></body></html>');
  await p.addScriptTag({ content: draw });
  for (const [file, size, mode] of jobs) {
    // draw large, then downscale in steps for crisp small icons
    const url = await p.evaluate(([size, mode]) => {
      const big = new Image();
      return new Promise(res => {
        big.onload = () => {
          let src = big, s = big.width;
          while (s / 2 >= size) {
            const c = document.createElement('canvas'); c.width = c.height = s / 2;
            const x = c.getContext('2d'); x.imageSmoothingQuality = 'high'; x.drawImage(src, 0, 0, s / 2, s / 2);
            src = c; s = s / 2;
          }
          const c = document.createElement('canvas'); c.width = c.height = size;
          const x = c.getContext('2d'); x.imageSmoothingQuality = 'high'; x.drawImage(src, 0, 0, size, size);
          res(c.toDataURL('image/png'));
        };
        big.src = draw(Math.max(1024, size), mode);
      });
    }, [size, mode]);
    const out = path.join(ROOT, file);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    const png = Buffer.from(url.split(',')[1], 'base64');
    fs.writeFileSync(out, file.startsWith('ios/') ? opaquePng(png) : png);
  }
  await b.close();
  console.log(`wrote ${jobs.length} icons`);
})();
