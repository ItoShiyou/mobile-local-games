// Checks every level in src/levels.js: solvable, the par is the shortest
// solution, and the packing has a single answer.
//
//   node tool/verify.js
const L = require('../src/logic.js');
const LV = require('../src/levels.js');

let bad = 0;
const check = (ok, msg) => { if (!ok) { bad++; console.log('NG', msg); } };

LV.pack.forEach((l, i) => {
  const free = L.Pack.free(l).length;
  const cells = l.pieces.reduce((n, p) => n + p.cells.length, 0);
  check(free === cells, `pack ${i + 1}: ${cells} dish cells for ${free} spaces`);
  check(L.Pack.count(l, 2) === 1, `pack ${i + 1}: not exactly one packing`);
});
for (const [name, R] of [['oden', L.Oden], ['light', L.Light], ['fusuma', L.Fusuma]]) {
  LV[name].forEach((l, i) => {
    const sol = R.solve(R.parse(l));
    check(sol && sol.length === l.par, `${name} ${i + 1}: par ${l.par}, shortest ${sol && sol.length}`);
  });
}
LV.dashi.forEach((l, i) => {
  const answer = l.answer.map((r) => [...r].map(Number));
  const start = l.rot.map((r) => [...r].map(Number));
  check(L.Dashi.won(l, answer), `dashi ${i + 1}: the answer does not work`);
  check(!L.Dashi.won(l, start), `dashi ${i + 1}: already solved at the start`);
  check((l.fixed || []).every((k) => { const [x, y] = k.split(',').map(Number); return start[y][x] === answer[y][x]; }), `dashi ${i + 1}: a fixed pipe is turned wrong`);
});
console.log(bad ? `${bad} problem(s)` : 'all levels ok');
process.exit(bad ? 1 : 0);
