// Checks every level in src/levels.js: solvable, and a single answer where
// the game depends on it.
//
//   node tool/verify.js
const L = require('../src/logic.js');
const LV = require('../src/levels.js');

let bad = 0;
const check = (ok, msg) => { if (!ok) { bad++; console.log('NG', msg); } };

LV.slide.forEach((l, i) => {
  const sol = L.Slide.solve(L.Slide.parse(l.map));
  check(sol && sol.length === l.par, `slide ${i + 1}: par ${l.par}, shortest ${sol && sol.length}`);
});
LV.pack.forEach((l, i) => {
  const free = L.Pack.free(l).length;
  const cells = l.pieces.reduce((n, p) => n + p.cells.length, 0);
  check(free === cells, `pack ${i + 1}: ${cells} dish cells for ${free} spaces`);
  check(L.Pack.count(l, 2) === 1, `pack ${i + 1}: not exactly one packing`);
});
LV.stroke.forEach((l, i) => check(L.Stroke.count(L.Stroke.parse(l.map), 2) === 1, `stroke ${i + 1}: not exactly one round`));
LV.sort.forEach((l, i) => {
  const sol = L.Sort.solve({ cap: l.cap, stacks: l.stacks.map((s) => [...s]) });
  check(sol && sol.length === l.par, `sort ${i + 1}: par ${l.par}, shortest ${sol && sol.length}`);
});
LV.deduce.forEach((l, i) => {
  const sols = L.Deduce.solutions(l);
  check(sols.length === 1 && sols[0].join() === l.answer.join(), `deduce ${i + 1}: ${sols.length} answers`);
});
console.log(bad ? `${bad} problem(s)` : 'all levels ok');
process.exit(bad ? 1 : 0);
