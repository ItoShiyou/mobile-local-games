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

const ids = ['b01', 'b02', 'b03', 'b04', 'b05', 'b06', 'b07', 'b08', 'b09', 'b10', 'c01', 'c02', 'c03', 'c04', 'c05', 'c06', 'c07', 'c08',
  't02', 't01', 't03', 't04', 't05', 't06', 't07', 't08', 'o01', 'o02', 'o03', 'o04', 'o05', 'o06', 'o07', 'o08',
  'm01', 'm02', 'm03', 'm04', 'm05', 'm06', 'm07', 'm08', 'm09', 'm10', 'm11', 'm12'];

// progress: stages cleared before `upTo`, with a mix of stamp counts
function progressUpTo(upTo) {
  const best = {};
  const idx = ids.indexOf(upTo);
  ids.slice(0, idx).forEach((id, i) => { best[id] = i % 4 === 1 ? 999 : 1; });
  return { best, last: idx > 0 ? ids[idx - 1] : null };
}

const shots = [
  { name: '01', progress: 'b05', open: null, keys: [], wait: 4200,
    ja: '頭の上に積んで、\n順番どおりにお届け', en: 'Stack it on your head,\nserve it in order' },
  // a wrong serve: the dishes on top lift and the wanted one glows (held still with reduced motion)
  { name: '02', progress: 'b05', open: 'b04', keys: ['ArrowLeft', 'ArrowLeft', 'ArrowLeft', 'ArrowDown'], wait: 900, still: true,
    ja: '通れば拾う。\n渡せるのはいちばん上だけ', en: 'Pick up what you walk over.\nServe only the top dish' },
  { name: '03', progress: 'm09', open: 'm09', keys: ['ArrowDown', 'ArrowUp', 'ArrowRight', 'h'], wait: 700,
    ja: '困ったら提灯をともして\n足あとヒント', en: 'Stuck? Light the lantern\nfor a paw-print hint' },
  { name: '04', progress: 'o05', open: 'stages', keys: [], wait: 1800,
    ja: '5つのお店で全46品', en: '46 orders\nin five shops' },
  { name: '05', progress: 'b01', open: 'b01', keys: ['ArrowRight', 'ArrowRight', 'ArrowRight', 'ArrowRight'], wait: 2200,
    ja: '目標の手数で届けて\n判子を集めよう', en: 'Deliver within par,\ncollect the stamps' },
  { name: '06', progress: 't05', open: 't05', keys: ['ArrowUp'], wait: 900, dark: true,
    ja: '夜営業は提灯の灯りで', en: 'Evening service,\nby lantern light' },
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
    localStorage.setItem('flutter.progress.intro.v1', JSON.stringify(['howto', 'counter', 'tray', 'oneWay']));
    localStorage.setItem('flutter.settings.language', JSON.stringify(lang));
    localStorage.setItem('flutter.settings.music', 'false');
    localStorage.setItem('flutter.settings.sound', 'false');
  }, [best, last, lang]);
  await page.goto(URL + (shot.open ? `?open=${shot.open}` : ''));
  await page.waitForTimeout(shot.open ? 5200 : 4200);
  for (const k of shot.keys) {
    await page.keyboard.press(k);
    await page.waitForTimeout(450);
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
  const name = lang === 'ja' ? 'つみあげ出前' : 'Stack &amp; Deliver';
  const tag = lang === 'ja' ? '頭の上に積んで、順番どおりにお届け' : 'Stack it on your head, serve it in order';
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
