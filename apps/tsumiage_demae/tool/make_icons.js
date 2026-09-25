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
    g.addColorStop(0, '#C98A5A'); g.addColorStop(1, '#A96B3E');
    x.fillStyle = g; x.fillRect(0, 0, s, s);
    x.fillStyle = 'rgba(255,255,255,.07)';
    for (let i = 0; i < 6; i++) x.fillRect(0, s * (i / 6 + .08), s, s * .012);
  }
  const k = mode === 'full' ? 1 : .72;
  x.translate(s / 2, s / 2); x.scale(s * k / 1024, s * k / 1024); x.translate(-512, -512);
  // shadow
  x.fillStyle = 'rgba(0,0,0,.16)'; x.beginPath(); x.ellipse(512, 905, 250, 42, 0, 0, 7); x.fill();
  // body (headband colour apron)
  x.fillStyle = '#7A4A26'; x.beginPath(); x.roundRect(352, 760, 320, 150, 70); x.fill();
  // ears
  const fur = '#F4F1EC', edge = '#C9C2B6';
  for (const sx of [-1, 1]) {
    x.beginPath(); x.moveTo(512 + sx * 150, 600); x.lineTo(512 + sx * 120, 440); x.lineTo(512 + sx * 40, 520); x.closePath();
    x.fillStyle = fur; x.fill(); x.lineWidth = 10; x.strokeStyle = edge; x.stroke();
    x.beginPath(); x.moveTo(512 + sx * 128, 575); x.lineTo(512 + sx * 112, 480); x.lineTo(512 + sx * 66, 525); x.closePath();
    x.fillStyle = '#F2B8C6'; x.fill();
  }
  // head
  x.beginPath(); x.arc(512, 650, 185, 0, 7); x.fillStyle = fur; x.fill(); x.lineWidth = 12; x.strokeStyle = edge; x.stroke();
  x.beginPath(); x.arc(512, 650, 185, Math.PI * 1.12, Math.PI * 1.88); x.lineWidth = 46; x.strokeStyle = '#7A4A26'; x.stroke();
  for (const sx of [-1, 1]) {
    x.fillStyle = '#26303F'; x.beginPath(); x.arc(512 + sx * 68, 665, 32, 0, 7); x.fill();
    x.fillStyle = '#fff'; x.beginPath(); x.arc(512 + sx * 68 + 10, 655, 11, 0, 7); x.fill();
    x.fillStyle = 'rgba(229,138,154,.45)'; x.beginPath(); x.arc(512 + sx * 118, 715, 26, 0, 7); x.fill();
  }
  x.fillStyle = '#E58A9A'; x.beginPath(); x.arc(512, 722, 20, 0, 7); x.fill();
  // stacked dishes
  const dishes = [['#E9B93A', 'egg'], ['#4FA86A', 'dango'], ['#E0646A', 'tomato']];
  dishes.forEach(([col, kind], i) => {
    const y = 420 - i * 118;
    x.fillStyle = 'rgba(0,0,0,.18)'; x.beginPath(); x.ellipse(512, y + 14, 210, 44, 0, 0, 7); x.fill();
    x.fillStyle = '#fff'; x.beginPath(); x.ellipse(512, y, 210, 46, 0, 0, 7); x.fill();
    x.lineWidth = 6; x.strokeStyle = '#D5D9E0'; x.stroke();
    x.fillStyle = col;
    if (kind === 'egg') { x.beginPath(); x.roundRect(422, y - 92, 180, 84, 22); x.fill();
      x.strokeStyle = '#C9921C'; x.lineWidth = 9; for (const dx of [-30, 30]) { x.beginPath(); x.moveTo(512 + dx, y - 86); x.lineTo(512 + dx, y - 14); x.stroke(); } }
    if (kind === 'dango') { x.strokeStyle = '#B88A55'; x.lineWidth = 12; x.beginPath(); x.moveTo(420, y - 18); x.lineTo(604, y - 18); x.stroke();
      for (const dx of [-60, 0, 60]) { x.fillStyle = col; x.beginPath(); x.arc(512 + dx, y - 50, 38, 0, 7); x.fill();
        x.fillStyle = 'rgba(255,255,255,.35)'; x.beginPath(); x.arc(500 + dx, y - 62, 11, 0, 7); x.fill(); } }
    if (kind === 'tomato') { x.beginPath(); x.arc(512, y - 58, 62, 0, 7); x.fill();
      x.fillStyle = 'rgba(255,255,255,.4)'; x.beginPath(); x.arc(490, y - 80, 15, 0, 7); x.fill();
      x.strokeStyle = '#3F8A4E'; x.lineWidth = 14; x.lineCap = 'round';
      for (let a = 0; a < 5; a++) { const t = -Math.PI / 2 + a * 2 * Math.PI / 5; x.beginPath(); x.moveTo(512, y - 116); x.lineTo(512 + Math.cos(t) * 34, y - 116 + Math.sin(t) * 18); x.stroke(); } }
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
