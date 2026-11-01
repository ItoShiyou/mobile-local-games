// Store screenshots and the Play feature graphic, from the web build.
//
//   flutter build web --release --no-web-resources-cdn
//   (cd build/web && python3 -m http.server 8765) &
//   node tool/make_store_screens.js
//
// Needs Playwright + Chromium (PLAYWRIGHT / CHROMIUM env vars to override).
// Writes store/screenshots/{ios,android}/{ja,en}/NN.png and
// store/feature-graphic-{ja,en}.png.
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const ROOT = path.join(__dirname, '..');
const URL = process.env.URL || 'http://localhost:8765/';
const OUT = path.join(ROOT, 'store');
// embedded so the composing pages need no network access
const FONT = `url(data:font/ttf;base64,${fs.readFileSync(path.join(ROOT, 'assets/fonts/YuseiMagic-Regular.ttf')).toString('base64')})`;

// css size x device pixel ratio = pixel size
const devices = {
  ios: { w: 430, h: 932, dpr: 3 }, // 1290 x 2796 (iPhone 6.7"/6.9")
  android: { w: 432, h: 768, dpr: 2.5 }, // 1080 x 1920 (9:16)
};

const ids = Array.from({ length: 40 }, (_, i) => 'd' + String(i + 1).padStart(2, '0'));

// progress: stages cleared before `upTo`, with a mix of stamp counts
function progressUpTo(upTo) {
  const best = {};
  const idx = ids.indexOf(upTo);
  ids.slice(0, idx).forEach((id, i) => { best[id] = i % 4 === 1 ? 999 : 1; });
  return { best, last: idx > 0 ? ids[idx - 1] : null };
}

// Keys follow the solver's hints from the start of each stage (arrows move
// the cursor, Space turns a pipe); Escape hides the cursor again.
const R = 'ArrowRight', L = 'ArrowLeft', U = 'ArrowUp', D = 'ArrowDown', T = 'Space';
const shots = [
  { name: '01', progress: 'd04', open: 'd04', keys: [T, R, T, L, D, T, R, D, T, R, T, T, 'Escape'], wait: 900,
    ja: '樋を回して、\nだしをお椀へ', en: 'Turn the pipes,\nfill the bowls' },
  { name: '02', progress: 'd12', open: 'd12', keys: [R, R, D, D, T, R, T, T, R, T, L, L, L, L, D, D, T, R, R, R, R, T, T, T, 'Escape'], wait: 900,
    ja: '鰹と昆布が出会えば\n合わせだし', en: 'Katsuo meets kombu:\nawase' },
  { name: '03', progress: 'd20', open: 'd20', keys: [T, R, R, R, T, T, D, T, T, T, 'Escape', 'h'], wait: 900,
    ja: '困ったら提灯で、\n次の樋が光る', en: 'Stuck? The lantern\nlights the next pipe' },
  { name: '04', progress: 'd27', open: 'stages', keys: [], wait: 1800,
    ja: '5つの場所で全40品', en: '40 dishes\nin five places' },
  { name: '05', progress: 'd06', open: 'd06',
    keys: [R, R, R, T, L, L, L, L, D, T, T, T, R, T, R, R, T, L, L, D, D, T, R, R, T, T, L, L, L, D, T, R, R, R, T, L, D, T, T, R, T], wait: 3200,
    ja: '目標の回数で仕上げて\n判子を集めよう', en: 'Finish within par,\ncollect the stamps' },
  { name: '06', progress: 'd36', open: 'd36', keys: [T, D, T, R, D, T, T, R, R, T, L, L, D, T, T, R, T, T, 'Escape'], wait: 900, dark: true,
    ja: '夜なべは\n提灯の灯りで', en: 'Late-night stock,\nby lantern light' },
];

async function capture(browser, dev, lang, shot) {
  const page = await browser.newPage({
    viewport: { width: dev.w, height: dev.h },
    deviceScaleFactor: dev.dpr,
    colorScheme: shot.dark ? 'dark' : 'light',
    reducedMotion: shot.still ? 'reduce' : 'no-preference',
    locale: lang === 'ja' ? 'ja-JP' : 'en-US',
  });
  await page.goto(URL);
  const { best, last } = progressUpTo(shot.progress);
  await page.evaluate(([best, last, lang]) => {
    localStorage.clear();
    localStorage.setItem('flutter.progress.best.v1', JSON.stringify(JSON.stringify(best)));
    if (last) localStorage.setItem('flutter.progress.last.v1', JSON.stringify(last));
    localStorage.setItem('flutter.progress.intro.v1', JSON.stringify(['howto', 'mix', 'iron', 'cross', 'shiitake']));
    localStorage.setItem('flutter.settings.language', JSON.stringify(lang));
    localStorage.setItem('flutter.settings.music', 'false');
    localStorage.setItem('flutter.settings.sound', 'false');
  }, [best, last, lang]);
  await page.goto(URL + (shot.open ? `?open=${shot.open}` : ''));
  await page.waitForTimeout(shot.open ? 5200 : 4200);
  for (const k of shot.keys) {
    await page.keyboard.press(k);
    await page.waitForTimeout(280);
  }
  await page.waitForTimeout(shot.wait);
  const png = await page.screenshot();
  await page.close();
  return png;
}

async function compose(browser, dev, png, caption, lang) {
  const W = dev.w, H = dev.h;
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: dev.dpr });
  const lines = caption.split('\n').map((l) => `<div>${l}</div>`).join('');
  const band = H * 0.2;
  const shotH = H * 0.745;
  const shotW = shotH * W / H;
  await page.setContent(`<!doctype html><html><head><style>
    @font-face { font-family: Yusei; src: ${FONT}; }
    body { margin:0; width:${W}px; height:${H}px; overflow:hidden; background:#F3EAD8;
      background-image: radial-gradient(circle at 50% 60%, #F7F0E2 0%, #EADBC0 100%); font-family: Yusei, sans-serif; }
    .noren { position:absolute; left:0; right:0; top:0; height:${band}px; display:flex; gap:3px; padding-top:10px; background:#8E6A48; }
    .noren i { flex:1; background:#2F4B6B; border-bottom-left-radius:4px; border-bottom-right-radius:4px;
      box-shadow: inset 0 -2px 0 rgba(0,0,0,.2); }
    .rod { position:absolute; left:0; right:0; top:0; height:10px; background:#7E5535; border-bottom:2px solid #3A2B22; }
    .cap { position:absolute; left:0; right:0; top:10px; height:${band - 10}px; display:flex; flex-direction:column;
      justify-content:center; align-items:center; color:#F6EEDF; font-size:${W * (lang === 'ja' ? 0.072 : 0.064)}px; line-height:1.3; text-align:center;
      text-shadow: 0 2px 0 rgba(0,0,0,.25); }
    .shot { position:absolute; top:${band + H * 0.03}px; left:${(W - shotW) / 2}px; width:${shotW}px; height:${shotH}px;
      border:5px solid #7E5535; border-radius:22px; overflow:hidden; box-shadow: 0 10px 24px rgba(40,25,15,.35); }
    .shot img { width:100%; height:100%; display:block; }
  </style></head><body>
    <div class="noren"><i></i><i></i><i></i></div><div class="rod"></div>
    <div class="cap">${lines}</div>
    <div class="shot"><img src="data:image/png;base64,${png.toString('base64')}"></div>
  </body></html>`);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  const out = await page.screenshot();
  await page.close();
  return out;
}

async function featureGraphic(browser, lang, titlePng) {
  const page = await browser.newPage({ viewport: { width: 1024, height: 500 } });
  const name = lang === 'ja' ? 'だし回し' : 'Stock Pipes';
  const tag = lang === 'ja' ? '竹の樋を回して、だしをお椀へ' : 'Turn the bamboo pipes, fill every bowl';
  await page.setContent(`<!doctype html><html><head><style>
    @font-face { font-family: Yusei; src: ${FONT}; }
    body { margin:0; width:1024px; height:500px; overflow:hidden; font-family: Yusei, sans-serif;
      background: radial-gradient(circle at 30% 50%, #F7F0E2, #E6D3B4); }
    .noren { position:absolute; left:0; right:0; top:0; height:70px; display:flex; gap:4px; background:#7E5535; padding-top:8px; }
    .noren i { flex:1; background:#2F4B6B; border-radius:0 0 4px 4px; }
    .sign { position:absolute; left:48px; top:140px; padding:18px 34px 22px; background:#C6955F; border:3px solid #3A2B22;
      border-radius:10px; box-shadow:0 6px 0 rgba(0,0,0,.2); font-size:${lang === 'ja' ? 76 : 58}px; color:#3A2B22; }
    .tag { position:absolute; left:52px; top:${lang === 'ja' ? 320 : 300}px; font-size:28px; color:#7D6754; width:520px; }
    .shot { position:absolute; right:40px; top:90px; width:340px; height:390px; border:5px solid #7E5535; border-radius:18px;
      overflow:hidden; box-shadow:0 8px 20px rgba(40,25,15,.35);
      background-image:url(data:image/png;base64,${titlePng.toString('base64')}); background-size:cover; background-position:50% 55%; }
  </style></head><body>
    <div class="noren"><i></i><i></i><i></i><i></i><i></i><i></i></div>
    <div class="sign">${name}</div><div class="tag">${tag}</div><div class="shot"></div>
  </body></html>`);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  const out = await page.screenshot();
  await page.close();
  return out;
}

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  for (const lang of ['ja', 'en']) {
    for (const [devName, dev] of Object.entries(devices)) {
      const dir = path.join(OUT, 'screenshots', devName, lang);
      fs.mkdirSync(dir, { recursive: true });
      for (const shot of shots) {
        const raw = await capture(browser, dev, lang, shot);
        const out = await compose(browser, dev, raw, shot[lang], lang);
        fs.writeFileSync(path.join(dir, `${shot.name}.png`), out);
        if (devName === 'android' && shot.name === '01') {
          fs.writeFileSync(path.join(OUT, `feature-graphic-${lang}.png`), await featureGraphic(browser, lang, raw));
        }
        console.log(`${devName}/${lang}/${shot.name}`);
      }
    }
  }
  await browser.close();
})();
