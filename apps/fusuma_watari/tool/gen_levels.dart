// Stage generator used while designing the stage list.
//
//   dart run tool/gen_levels.dart --w=6 --h=5 --walls=3 --doors=4 --guests=1 --min=16 --n=200 --seed=1
//   options: --pair  --lock  --revolve=1
//
// For each random room it explores every position reachable from the
// starting layout, works out how far each one is from serving everyone,
// and keeps the layout where the cat, standing at the kitchen door, is
// furthest from done. Candidates must use every gimmick they have. The
// best are printed as Dart, ready to paste into lib/game/levels.dart,
// where test/levels_test.dart checks them again.
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:fusuma_watari/game/engine.dart';

class Found {
  Found(this.map, this.doors, this.par, this.pushes, this.reachable);
  final List<String> map;
  final List<String> doors;
  final int par;
  final int pushes;
  final int reachable;
}

void main(List<String> args) {
  final opt = {
    for (final a in args)
      if (a.startsWith('--')) a.substring(2).split('=')[0]: a.contains('=') ? a.split('=')[1] : 'true',
  };
  int i(String k, int d) => int.tryParse(opt[k] ?? '') ?? d;
  final w = i('w', 6), h = i('h', 5);
  final walls = i('walls', 3);
  final nDoors = i('doors', 4);
  final guests = i('guests', 1);
  final revolve = i('revolve', 0);
  final pair = opt.containsKey('pair');
  final lock = opt.containsKey('lock');
  final minPar = i('min', 14);
  final minPush = i('push', 3);
  final tries = i('n', 200);
  final keep = i('keep', 5);
  final rnd = Random(i('seed', 1));

  final found = <Found>[];
  for (var t = 0; t < tries; t++) {
    final cand = _make(rnd, w, h, walls, nDoors, guests, revolve, pair, lock);
    if (cand == null) continue;
    final best = _deepest(cand.$1, cand.$2, seeds: _shuffledLayouts(rnd, cand.$1, cand.$2, i('seeds', 40)));
    if (opt.containsKey('debug')) print('// try $t: ${best == null ? 'none' : 'par ${best.par} pushes ${best.pushes} states ${best.reachable}'}');
    if (best == null || best.par < minPar || best.pushes < minPush) continue;
    if (!_usesEverything(best)) continue;
    found.add(best);
  }
  final target = i('target', 0);
  // closest to the wanted length first (or longest), more pushes breaking ties
  double score(Found f) => target > 0 ? (f.par - target).abs() * 2.0 - f.pushes : -(f.par + f.pushes).toDouble();
  found.sort((a, b) => score(a).compareTo(score(b)));
  if (opt.containsKey('json')) {
    print(jsonEncode([
      for (final f in found.take(keep)) {'map': f.map, 'doors': f.doors, 'par': f.par, 'pushes': f.pushes},
    ]));
    return;
  }
  final seen = <String>{};
  var shown = 0;
  for (final f in found) {
    if (!seen.add(f.map.join())) continue;
    print('// par ${f.par}, pushes ${f.pushes}, reachable ${f.reachable}');
    print("Level(id: '', ja: '', en: '', par: ${f.par}, map: [");
    for (final r in f.map) {
      print("  '$r',");
    }
    print('], doors: [${f.doors.map((d) => "'$d'").join(', ')}]),');
    if (++shown >= keep) break;
  }
  if (shown == 0) print('// nothing found');
}

(List<String>, List<String>)? _make(Random rnd, int w, int h, int walls, int nDoors, int guests, int revolve, bool pair, bool lock) {
  final g = List.generate(h + 2, (y) => List.generate(w + 2, (x) => x == 0 || y == 0 || x == w + 1 || y == h + 1 ? '#' : '.'));
  // kitchen door on the left, guests towards the right
  final py = 1 + rnd.nextInt(h);
  g[py][1] = 'P';
  for (var k = 0; k < guests; k++) {
    for (var a = 0; a < 20; a++) {
      final gx = w - rnd.nextInt(2), gy = 1 + rnd.nextInt(h);
      if (g[gy][gx] == '.') {
        g[gy][gx] = String.fromCharCode(65 + k);
        break;
      }
    }
  }
  if (lock) {
    for (var a = 0; a < 20; a++) {
      final kx = 1 + rnd.nextInt(w), ky = 1 + rnd.nextInt(h);
      if (g[ky][kx] == '.') {
        g[ky][kx] = 'k';
        break;
      }
    }
  }
  for (var k = 0; k < walls; k++) {
    final x = 2 + rnd.nextInt(max(1, w - 2)), y = 1 + rnd.nextInt(h);
    if (g[y][x] == '.') g[y][x] = '#';
  }
  final occ = <Pos>{};
  final doors = <String>[];
  bool free(Pos p) => p.x > 0 && p.y > 0 && p.x <= w && p.y <= h && g[p.y][p.x] == '.' && !occ.contains(p);
  for (var k = 0; k < revolve; k++) {
    for (var a = 0; a < 40; a++) {
      final p = Pos(1 + rnd.nextInt(w), 1 + rnd.nextInt(h));
      final arm = Dir.values[rnd.nextInt(4)];
      final q = p.step(arm);
      if (!free(p) || !free(q)) continue;
      occ..add(p)..add(q);
      doors.add('r${p.x},${p.y},${arm.letter}');
      break;
    }
  }
  final slides = <(bool, Pos, int)>[];
  for (var a = 0; a < nDoors * 12 && slides.length < nDoors; a++) {
    final horizontal = rnd.nextBool();
    final len = rnd.nextInt(3) == 0 ? 3 : 2;
    final p = Pos(1 + rnd.nextInt(w), 1 + rnd.nextInt(h));
    final cells = [for (var j = 0; j < len; j++) Pos(p.x + (horizontal ? j : 0), p.y + (horizontal ? 0 : j))];
    if (!cells.every(free)) continue;
    occ.addAll(cells);
    slides.add((horizontal, p, len));
  }
  if (slides.length < nDoors) return null;
  // a pair: two doors on the same axis
  var pairIdx = <int>[];
  if (pair) {
    for (final axis in [true, false]) {
      final same = [for (var j = 0; j < slides.length; j++) if (slides[j].$1 == axis) j]..shuffle(rnd);
      if (same.length >= 2) {
        pairIdx = same.sublist(0, 2);
        break;
      }
    }
    if (pairIdx.isEmpty) return null;
  }
  var lockIdx = -1;
  if (lock) {
    final cand = [for (var j = 0; j < slides.length; j++) if (!pairIdx.contains(j)) j];
    if (cand.isEmpty) return null;
    lockIdx = cand[rnd.nextInt(cand.length)];
  }
  for (var j = 0; j < slides.length; j++) {
    final (horizontal, p, len) = slides[j];
    doors.add('${horizontal ? 'h' : 'v'}${p.x},${p.y},$len${pairIdx.contains(j) ? '=a' : ''}${j == lockIdx ? '*' : ''}');
  }
  return ([for (final r in g) r.join()], doors);
}

/// Explores everything reachable from the layout and returns the start
/// (cat at the kitchen door, nothing served, no key) furthest from winning.
Found? _deepest(List<String> map, List<String> doorSpecs, {List<List<DoorAt>> seeds = const [], int limit = 250000}) {
  final board = Board.parse(map, doorSpecs);
  final s0 = board.initialState();
  final ids = <String, int>{};
  final states = <GameState>[];
  final preds = <List<int>>[];
  final predW = <List<int>>[];
  final queue = Queue<int>();
  for (final doors in [s0.doors, ...seeds]) {
    final s = GameState(board: board, pos: board.start, doors: doors, served: 0, hasKey: board.key == null, moves: 0, facing: Dir.right);
    if (ids.containsKey(s.key)) continue;
    ids[s.key] = states.length;
    states.add(s);
    preds.add([]);
    predW.add([]);
    queue.add(states.length - 1);
  }
  while (queue.isNotEmpty) {
    final a = queue.removeFirst();
    final s = states[a];
    if (s.isWon) continue;
    for (final d in Dir.values) {
      final r = s.move(d);
      final n = r.state;
      if (n == null) continue;
      final k = n.key;
      var b = ids[k];
      if (b == null) {
        if (states.length >= limit) return null;
        b = states.length;
        ids[k] = b;
        states.add(n);
        preds.add([]);
        predW.add([]);
        queue.add(b);
      }
      preds[b].add(a);
      predW[b].add(r.events.any((e) => e is Slid || e is Swung) ? 1000 : 1);
    }
  }
  // distance to a win, backwards from every winning state
  final dist = List<int>.filled(states.length, -1);
  final back = Queue<int>();
  for (var j = 0; j < states.length; j++) {
    if (states[j].isWon) {
      dist[j] = 0;
      back.add(j);
    }
  }
  while (back.isNotEmpty) {
    final b = back.removeFirst();
    for (final a in preds[b]) {
      if (dist[a] < 0) {
        dist[a] = dist[b] + 1;
        back.add(a);
      }
    }
  }
  // pushes needed (then steps), backwards from the wins: the start that
  // needs the most pushes makes the best puzzle
  final cost = List<int>.filled(states.length, -1);
  final heap = _Heap();
  for (var j = 0; j < states.length; j++) {
    if (states[j].isWon) heap.push(0, j);
  }
  while (heap.isNotEmpty) {
    final (c, b) = heap.pop();
    if (cost[b] >= 0) continue;
    cost[b] = c;
    for (var e = 0; e < preds[b].length; e++) {
      final a = preds[b][e];
      if (cost[a] < 0) heap.push(c + predW[b][e], a);
    }
  }
  var best = -1;
  for (var j = 0; j < states.length; j++) {
    final s = states[j];
    if (s.pos != board.start || s.served != 0 || (board.key != null && s.hasKey)) continue;
    if (cost[j] < 0) continue;
    if (best < 0 || cost[j] > cost[best] || (cost[j] == cost[best] && dist[j] > dist[best])) best = j;
  }
  if (best < 0 || dist[best] <= 0) return null;
  final start = states[best];
  // the start layout as door specs
  final specs = <String>[
    for (var j = 0; j < board.doors.length; j++)
      board.doors[j].kind == DoorKind.revolve
          ? 'r${board.doors[j].pos.x},${board.doors[j].pos.y},${start.doors[j].arm.letter}'
          : Door.slide(
              pos: start.doors[j].pos,
              horizontal: board.doors[j].horizontal,
              length: board.doors[j].length,
              pair: board.doors[j].pair,
              locked: board.doors[j].locked,
            ).spec,
  ];
  // count pushes along one shortest line of play
  var s = start;
  var pushes = 0;
  var j = best;
  while (!s.isWon) {
    for (final d in Dir.values) {
      final r = s.move(d);
      final n = r.state;
      if (n == null) continue;
      final nj = ids[n.key]!;
      if (dist[nj] == dist[j] - 1) {
        if (r.events.any((e) => e is Slid || e is Swung)) pushes++;
        s = n;
        j = nj;
        break;
      }
    }
  }
  return Found(map, specs, dist[best], pushes, states.length);
}

/// Every gimmick on the stage has to be part of the answer.
bool _usesEverything(Found f) {
  final board = Board.parse(f.map, f.doors);
  final path = _solve(board.initialState());
  if (path == null) return false;
  var s = board.initialState();
  var paired = false, swung = false, lockedMoved = false;
  for (final d in path) {
    final r = s.move(d);
    for (final e in r.events) {
      if (e is Slid && e.doors.length > 1) paired = true;
      if (e is Slid && e.doors.any((i) => board.doors[i].locked)) lockedMoved = true;
      if (e is Swung) swung = true;
    }
    s = r.state!;
  }
  if (board.doors.any((d) => d.pair != null) && !paired) return false;
  if (board.doors.any((d) => d.kind == DoorKind.revolve) && !swung) return false;
  if (board.hasLocks && !lockedMoved) return false;
  return true;
}

List<Dir>? _solve(GameState start) {
  final parent = <String, (String, Dir)>{};
  final seen = <String>{start.key};
  final queue = Queue<GameState>()..add(start);
  while (queue.isNotEmpty) {
    final s = queue.removeFirst();
    for (final d in Dir.values) {
      final n = s.move(d).state;
      if (n == null || !seen.add(n.key)) continue;
      parent[n.key] = (s.key, d);
      if (n.isWon) {
        final out = <Dir>[];
        var k = n.key;
        while (k != start.key) {
          final (p, dd) = parent[k]!;
          out.add(dd);
          k = p;
        }
        return out.reversed.toList();
      }
      queue.add(n);
    }
  }
  return null;
}

/// The same doors dropped at other random spots, as extra starting points
/// for the search: together they cover far more layouts than one start.
List<List<DoorAt>> _shuffledLayouts(Random rnd, List<String> map, List<String> doorSpecs, int n) {
  final board = Board.parse(map, doorSpecs);
  final out = <List<DoorAt>>[];
  for (var t = 0; t < n * 4 && out.length < n; t++) {
    final occ = <Pos>{};
    final placed = <DoorAt>[];
    var ok = true;
    for (final d in board.doors) {
      var done = false;
      for (var a = 0; a < 30 && !done; a++) {
        final p = Pos(1 + rnd.nextInt(board.width - 2), 1 + rnd.nextInt(board.height - 2));
        if (d.kind == DoorKind.revolve) {
          // a revolving door keeps its pivot; only the arm is random
          final arm = Dir.values[rnd.nextInt(4)];
          final q = d.pos.step(arm);
          if (occ.contains(d.pos) || occ.contains(q) || !board.doorFloor(q.x, q.y) || q == board.start) continue;
          occ..add(d.pos)..add(q);
          placed.add(DoorAt(d.pos, arm));
          done = true;
          continue;
        }
        final cells = [for (var k = 0; k < d.length; k++) Pos(p.x + (d.horizontal ? k : 0), p.y + (d.horizontal ? 0 : k))];
        if (cells.any((c) => !board.doorFloor(c.x, c.y) || occ.contains(c) || c == board.start)) continue;
        occ.addAll(cells);
        placed.add(DoorAt(p, Dir.right));
        done = true;
      }
      if (!done) {
        ok = false;
        break;
      }
    }
    if (ok) out.add(placed);
  }
  return out;
}

class _Heap {
  final _c = <int>[], _v = <int>[];
  bool get isNotEmpty => _c.isNotEmpty;
  void push(int c, int v) {
    _c.add(c);
    _v.add(v);
    var i = _c.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_c[p] <= _c[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  (int, int) pop() {
    final out = (_c[0], _v[0]);
    final lc = _c.removeLast(), lv = _v.removeLast();
    if (_c.isNotEmpty) {
      _c[0] = lc;
      _v[0] = lv;
      var i = 0;
      for (;;) {
        final l = i * 2 + 1, r = l + 1;
        var m = i;
        if (l < _c.length && _c[l] < _c[m]) m = l;
        if (r < _c.length && _c[r] < _c[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return out;
  }

  void _swap(int a, int b) {
    final tc = _c[a], tv = _v[a];
    _c[a] = _c[b];
    _v[a] = _v[b];
    _c[b] = tc;
    _v[b] = tv;
  }
}
