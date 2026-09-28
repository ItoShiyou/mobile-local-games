// Stage generator used while designing the stage list.
//
//   dart run tool/gen_levels.dart --w=5 --h=6 --trees=k,n,kn --walls=2 --target=14 --n=400 --seed=1
//   options: --cross (pipes may cross)  --fixed=2 (iron pipes)  --json
//
// Each candidate grows one pipe network per entry of --trees from random
// starting cells (a depth-first walk, so the networks are long and have
// few ends). The ends become the pots of that network (one per stock
// letter) and bowls asking for the mix. Every pipe is then turned at
// random. Only boards with exactly one answer are kept; the par is the
// number of taps to reach it.
import 'dart:convert';
import 'dart:math';

import 'package:dashi_mawashi/game/engine.dart';
import 'package:dashi_mawashi/game/solver.dart';

class Found {
  Found(this.map, this.rot, this.fixed, this.pots, this.bowls, this.par, this.pipes);
  final List<String> map, rot, fixed, pots, bowls;
  final int par, pipes;
}

void main(List<String> args) {
  final opt = {
    for (final a in args)
      if (a.startsWith('--')) a.substring(2).split('=')[0]: a.contains('=') ? a.split('=')[1] : 'true',
  };
  int i(String k, int d) => int.tryParse(opt[k] ?? '') ?? d;
  final w = i('w', 5), h = i('h', 6);
  final trees = (opt['trees'] ?? 'k').split(',');
  final walls = i('walls', 0);
  final fixed = i('fixed', 0);
  final cross = opt.containsKey('cross');
  final maxEmpty = i('empty', 2);
  final target = i('target', 12);
  final minPar = i('min', 4);
  final tries = i('n', 400);
  final keep = i('keep', 3);
  final rnd = Random(i('seed', 1));

  final found = <Found>[];
  for (var t = 0; t < tries; t++) {
    final f = _make(rnd, w, h, trees, walls, fixed, cross, maxEmpty);
    if (f == null || f.par < minPar) continue;
    found.add(f);
  }
  found.sort((a, b) => ((a.par - target).abs() * 2 - a.pipes ~/ 4).compareTo((b.par - target).abs() * 2 - b.pipes ~/ 4));
  final best = found.take(keep).toList();
  if (opt.containsKey('json')) {
    print(jsonEncode([
      for (final f in best) {'map': f.map, 'rot': f.rot, 'fixed': f.fixed, 'pots': f.pots, 'bowls': f.bowls, 'par': f.par},
    ]));
    return;
  }
  for (final f in best) {
    print('// par ${f.par}, pipes ${f.pipes}');
    print("Level(id: '', ja: '', en: '', par: ${f.par}, map: ${jsonEncode(f.map)}, rot: ${jsonEncode(f.rot)},");
    print('  fixed: ${jsonEncode(f.fixed)}, pots: ${jsonEncode(f.pots)}, bowls: ${jsonEncode(f.bowls)}),');
  }
  if (best.isEmpty) print('// nothing found');
}

Found? _make(Random rnd, int w, int h, List<String> trees, int walls, int nFixed, bool cross, int maxEmpty) {
  final wall = <Pos>{};
  while (wall.length < walls) {
    wall.add(Pos(rnd.nextInt(w), rnd.nextInt(h)));
  }
  final owner = <Pos, int>{}; // tree of each cell (crossings belong to both)
  final links = <Pos, int>{}; // opening masks
  final crossed = <Pos>{}; // crossing cells: nothing may branch from them
  bool free(Pos p) => p.x >= 0 && p.y >= 0 && p.x < w && p.y < h && !wall.contains(p) && !owner.containsKey(p);
  int degree(Pos p) {
    var n = 0;
    for (var m = links[p] ?? 0; m != 0; m &= m - 1) {
      n++;
    }
    return n;
  }

  void link(Pos a, Pos b, Dir d) {
    links[a] = (links[a] ?? 0) | d.bit;
    links[b] = (links[b] ?? 0) | d.opposite.bit;
  }

  final stacks = <List<Pos>>[];
  for (var t = 0; t < trees.length; t++) {
    Pos? root;
    for (var a = 0; a < 50 && root == null; a++) {
      final p = Pos(rnd.nextInt(w), rnd.nextInt(h));
      if (free(p)) root = p;
    }
    if (root == null) return null;
    owner[root] = t;
    stacks.add([root]);
  }
  // grow the networks in turns, depth first
  var growing = true;
  while (growing) {
    growing = false;
    for (var t = 0; t < trees.length; t++) {
      final st = stacks[t];
      while (st.isNotEmpty) {
        final cur = st.last;
        if (crossed.contains(cur) || degree(cur) >= 3) {
          st.removeLast();
          continue;
        }
        final dirs = [...Dir.values]..shuffle(rnd);
        Pos? next;
        for (final d in dirs) {
          final n = cur.step(d);
          if (free(n)) {
            link(cur, n, d);
            owner[n] = t;
            next = n;
            break;
          }
          // a crossing: straight over another network's straight pipe
          if (cross && owner.containsKey(n) && owner[n] != t && !crossed.contains(n)) {
            final m = links[n] ?? 0;
            final straightAcross = (d == Dir.up || d == Dir.down) ? m == 10 : m == 5;
            final beyond = n.step(d);
            if (straightAcross && free(beyond) && rnd.nextInt(3) == 0) {
              link(cur, n, d);
              link(n, beyond, d);
              crossed.add(n);
              owner[beyond] = t;
              next = beyond;
              break;
            }
          }
        }
        if (next == null) {
          st.removeLast();
          continue;
        }
        st.add(next);
        growing = true;
        break;
      }
    }
  }
  // cells nobody reached stay as empty floor
  var empty = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = Pos(x, y);
      if (!wall.contains(p) && !owner.containsKey(p)) empty++;
    }
  }
  if (empty > maxEmpty) return null;
  if (cross && crossed.isEmpty) return null;

  // the ends of each network: pots first, the rest are bowls
  final grid = List.generate(h, (_) => List.filled(w, '.'));
  final rot = List.generate(h, (_) => List.filled(w, 0));
  for (final p in wall) {
    grid[p.y][p.x] = '#';
  }
  final pots = <String>[], bowls = <String>[];
  for (var t = 0; t < trees.length; t++) {
    final cells = [for (final e in owner.entries) if (e.value == t && !crossed.contains(e.key)) e.key];
    if (cells.length < 4) return null;
    final ends = cells.where((p) => degree(p) == 1).toList()..shuffle(rnd);
    final want = trees[t];
    if (ends.length < want.length + 1) return null;
    for (var k = 0; k < ends.length; k++) {
      final p = ends[k];
      final d = Dir.values.firstWhere((d) => links[p]! & d.bit != 0);
      if (k < want.length) {
        grid[p.y][p.x] = 'P';
        pots.add('${want[k]} ${p.x},${p.y} ${d.letter}');
      } else {
        grid[p.y][p.x] = 'B';
        bowls.add('${mix(want.split(''))} ${p.x},${p.y} ${d.letter}');
      }
    }
  }
  final pipes = <Pos>[];
  for (final e in links.entries) {
    final p = e.key;
    if (grid[p.y][p.x] != '.') continue;
    final m = e.value;
    String? kind;
    int? r;
    for (final entry in baseMask.entries) {
      for (var k = 0; k < 4; k++) {
        if (turn(entry.value, k) == m) {
          kind = entry.key;
          r = k;
          break;
        }
      }
      if (kind != null) break;
    }
    if (kind == null) return null; // a four-way join: not a pipe we have
    grid[p.y][p.x] = kind;
    rot[p.y][p.x] = r!;
    pipes.add(p);
  }
  // iron pipes keep their right turn; the others are scrambled
  pipes.shuffle(rnd);
  final ironCells = pipes.where((p) => grid[p.y][p.x] != 'X').take(nFixed).toSet();
  if (ironCells.length < nFixed) return null;
  for (final p in pipes) {
    if (ironCells.contains(p)) continue;
    rot[p.y][p.x] = rnd.nextInt(4);
  }
  final map = [for (final r in grid) r.join()];
  final rotRows = [for (final r in rot) r.join()];
  final fixedSpecs = [for (final p in ironCells) '${p.x},${p.y}'];
  final board = Board.parse(map, rotRows, fixed: fixedSpecs, pots: pots, bowls: bowls);
  final sols = Solver(cap: 2).solutions(board);
  if (sols.length != 1) return null;
  final s0 = board.initialState();
  if (s0.isWon) return null;
  final par = Solver.tapsTo(s0, sols.first);
  return Found(map, rotRows, fixedSpecs, pots, bowls, par, pipes.length);
}
