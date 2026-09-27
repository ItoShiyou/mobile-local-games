// Inlines the sources into one page: dist/index.html.
//
//   node tool/gen.js && node tool/verify.js && node tool/build.js
const fs = require('fs');
const path = require('path');
const src = (f) => fs.readFileSync(path.join(__dirname, '../src', f), 'utf8');
let page = src('page.html');
for (const [mark, file] of [['LOGIC', 'logic.js'], ['LEVELS', 'levels.js'], ['ART', 'art.js'], ['GAMES', 'games.js'], ['SHELL', 'shell.js']]) {
  page = page.replace(`/*${mark}*/`, () => src(file));
}
fs.mkdirSync(path.join(__dirname, '../dist'), { recursive: true });
fs.writeFileSync(path.join(__dirname, '../dist/index.html'), page);
console.log(`dist/index.html ${(page.length / 1024).toFixed(1)} KB`);
