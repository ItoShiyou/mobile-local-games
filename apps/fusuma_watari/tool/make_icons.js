// Renders the app icon at every size the platforms need.
//   node tool/make_icons.js      (needs Playwright + Chromium)
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const ROOT = path.join(__dirname, '..');

// Draws the icon on a canvas of size s. `mode`: 'full' (square, background),
// 'fg' (adaptive-icon foreground: transparent, art inside the 66% safe zone),
// 'mask' (web maskable: background, art in the safe zone).
const draw = `
function draw(s, mode) {
  const c = document.createElement('canvas'); c.width = c.height = s;
  const x = c.getContext('2d');
  if (mode !== 'fg') {
    const g = x.createLinearGradient(0, 0, 0, s);
    g.addColorStop(0, '#F3EAD8'); g.addColorStop(1, '#E3D1B2');
    x.fillStyle = g; x.fillRect(0, 0, s, s);
    if (mode === 'full') {
      x.fillStyle = '#2F4B6B'; x.fillRect(0, 0, s, s * .16);
      x.fillStyle = '#F3EAD8'; for (let i = 1; i < 4; i++) x.fillRect(s * i / 4 - s * .006, s * .02, s * .012, s * .14);
    }
  }
  const k = mode === 'full' ? 1 : .72;
  x.translate(s / 2, s / 2); x.scale(s * k / 1024, s * k / 1024); x.translate(-512, -512);
  const INK = '#3A2B22';
  const stroke = (w) => { x.lineWidth = w; x.strokeStyle = INK; x.lineJoin = 'round'; x.lineCap = 'round'; x.stroke(); };
  // two fusuma slid half open behind the cat
  for (const [l, r] of [[40, 360], [664, 984]]) {
    x.fillStyle = 'rgba(40,20,10,.18)'; x.fillRect(l + 14, 118, r - l, 850);
    x.beginPath(); x.rect(l, 104, r - l, 850); x.fillStyle = '#5E3B26'; x.fill(); stroke(12);
    x.fillStyle = '#F6EEDB'; x.fillRect(l + 22, 126, r - l - 44, 806);
    x.save(); x.beginPath(); x.rect(l + 22, 126, r - l - 44, 806); x.clip();
    x.strokeStyle = 'rgba(190,168,128,.55)'; x.lineWidth = 5;
    for (let d = -900; d < 900; d += 70) { x.beginPath(); x.moveTo(l + d, 126); x.lineTo(l + d + 806, 932); x.stroke(); x.beginPath(); x.moveTo(l + d, 932); x.lineTo(l + d + 806, 126); x.stroke(); }
    x.restore();
    const px = l < 512 ? r - 60 : l + 60;
    x.fillStyle = INK; x.beginPath(); x.arc(px, 800, 24, 0, 7); x.fill();
    x.fillStyle = "#B08A45"; x.beginPath(); x.arc(px, 800, 13, 0, 7); x.fill();
  }
  // shadow
  x.fillStyle = 'rgba(40,20,10,.22)'; x.beginPath(); x.ellipse(512, 915, 250, 42, 0, 0, 7); x.fill();
  // body in an indigo happi coat
  x.beginPath(); x.moveTo(330, 910); x.quadraticCurveTo(318, 770, 420, 760); x.lineTo(604, 760); x.quadraticCurveTo(706, 770, 694, 910); x.closePath();
  x.fillStyle = '#2F4B6B'; x.fill(); stroke(14);
  x.strokeStyle = '#F6EEDF'; x.lineWidth = 26; x.beginPath(); x.moveTo(440, 775); x.lineTo(512, 900); x.lineTo(584, 775); x.stroke();
  // ears
  const fur = '#FBF4E8';
  for (const sx of [-1, 1]) {
    x.beginPath(); x.moveTo(512 + sx * 170, 600); x.lineTo(512 + sx * 150, 425); x.lineTo(512 + sx * 50, 505); x.closePath();
    x.fillStyle = fur; x.fill(); stroke(14);
    x.beginPath(); x.moveTo(512 + sx * 145, 570); x.lineTo(512 + sx * 138, 470); x.lineTo(512 + sx * 80, 520); x.closePath();
    x.fillStyle = '#F2B3BE'; x.fill();
  }
  // head with a brown patch
  x.save(); x.beginPath(); x.ellipse(512, 640, 200, 178, 0, 0, 7); x.fillStyle = fur; x.fill(); x.clip();
  x.fillStyle = '#D9A066'; x.beginPath(); x.ellipse(400, 560, 115, 95, 0, 0, 7); x.fill(); x.restore();
  x.beginPath(); x.ellipse(512, 640, 200, 178, 0, 0, 7); stroke(16);
  // hachimaki
  x.beginPath(); x.moveTo(314, 612); x.quadraticCurveTo(512, 552, 710, 612); x.lineTo(706, 648); x.quadraticCurveTo(512, 590, 318, 648); x.closePath();
  x.fillStyle = '#C8452F'; x.fill(); stroke(10);
  for (const [dx, dy] of [[-80, -40], [-90, 30]]) { x.beginPath(); x.moveTo(318, 625); x.lineTo(318 + dx, 625 + dy - 18); x.lineTo(318 + dx + 10, 625 + dy + 18); x.closePath(); x.fillStyle = '#C8452F'; x.fill(); stroke(9); }
  // eyes, nose, mouth, cheeks, whiskers
  for (const sx of [-1, 1]) {
    x.fillStyle = INK; x.beginPath(); x.ellipse(512 + sx * 72, 670, 26, 34, 0, 0, 7); x.fill();
    x.fillStyle = '#fff'; x.beginPath(); x.arc(512 + sx * 72 + 9, 656, 10, 0, 7); x.fill();
    x.fillStyle = 'rgba(240,138,154,.5)'; x.beginPath(); x.arc(512 + sx * 125, 720, 24, 0, 7); x.fill();
    x.strokeStyle = INK; x.lineWidth = 6; x.beginPath(); x.moveTo(512 + sx * 145, 700); x.lineTo(512 + sx * 235, 685); x.stroke();
    x.beginPath(); x.moveTo(512 + sx * 145, 725); x.lineTo(512 + sx * 235, 735); x.stroke();
  }
  x.fillStyle = '#E07A8C'; x.beginPath(); x.arc(512, 712, 15, 0, 7); x.fill();
  x.strokeStyle = INK; x.lineWidth = 8; x.beginPath(); x.arc(494, 728, 18, .3, Math.PI - .3); x.stroke(); x.beginPath(); x.arc(530, 728, 18, .3, Math.PI - .3); x.stroke();
  // the order on the cat's head
  const dishes = [['#F0C13F', 'egg']];
  dishes.forEach(([col, kind], i) => {
    const y = 425 - i * 115;
    if (kind === 'egg') { x.beginPath(); x.roundRect(430, y - 88, 164, 80, 22); x.fillStyle = col; x.fill(); stroke(10);
      x.strokeStyle = '#C98E1E'; x.lineWidth = 9; for (const dx of [-28, 28]) { x.beginPath(); x.moveTo(512 + dx, y - 82); x.lineTo(512 + dx, y - 16); x.stroke(); } }
    if (kind === 'dango') { x.strokeStyle = INK; x.lineWidth = 22; x.beginPath(); x.moveTo(420, y - 20); x.lineTo(604, y - 20); x.stroke();
      x.strokeStyle = '#D8B27A'; x.lineWidth = 10; x.beginPath(); x.moveTo(420, y - 20); x.lineTo(604, y - 20); x.stroke();
      for (const dx of [-60, 0, 60]) { x.fillStyle = dx === 0 ? '#86B85F' : col; x.beginPath(); x.arc(512 + dx, y - 50, 36, 0, 7); x.fill(); stroke(9);
        x.fillStyle = 'rgba(255,255,255,.45)'; x.beginPath(); x.arc(500 + dx, y - 62, 10, 0, 7); x.fill(); } }
    if (kind === 'tomato') { x.beginPath(); x.arc(512, y - 58, 60, 0, 7); x.fillStyle = col; x.fill(); stroke(10);
      x.fillStyle = 'rgba(255,255,255,.5)'; x.beginPath(); x.ellipse(488, y - 78, 16, 10, 0, 0, 7); x.fill();
      x.fillStyle = '#4E8A3E'; x.beginPath();
      for (let a = 0; a < 5; a++) { const t = -Math.PI / 2 + a * 2 * Math.PI / 5; x.moveTo(512, y - 112); x.lineTo(512 + Math.cos(t - .4) * 12, y - 112 + Math.sin(t - .4) * 8); x.lineTo(512 + Math.cos(t) * 40, y - 112 + Math.sin(t) * 20); x.lineTo(512 + Math.cos(t + .4) * 12, y - 112 + Math.sin(t + .4) * 8); }
      x.fill(); stroke(6); }
    // plate (side view) in front of the food
    x.beginPath(); x.moveTo(300, y - 6); x.quadraticCurveTo(512, y + 26, 724, y - 6); x.lineTo(650, y + 40); x.lineTo(374, y + 40); x.closePath();
    x.fillStyle = '#FFFCF4'; x.fill(); stroke(10);
    x.strokeStyle = '#4A6F9E'; x.lineWidth = 7; x.beginPath(); x.moveTo(330, y + 8); x.quadraticCurveTo(512, y + 34, 694, y + 8); x.stroke();
  });
  if (mode === 'mono') {}
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
    fs.writeFileSync(out, Buffer.from(url.split(',')[1], 'base64'));
  }
  await b.close();
  console.log(`wrote ${jobs.length} icons`);
})();
