// Random stage generator used while designing the stage list.
//
//   dart run tool/gen_levels.dart --gims=counter,tray --cap=2 --min=12 --max=24
//
// Every candidate is solved exhaustively; only stages that are solvable,
// need every listed gimmick, and leave no floor unused are printed (JSON,
// best first). The chosen ones are copied into lib/game/levels.dart, where
// test/levels_test.dart re-verifies them.
import 'dart:convert';
import 'dart:math';

import 'package:tsumiage_demae/game/analysis.dart';

void main(List<String> args) {
  final opt = {
    for (final a in args)
      if (a.startsWith('--')) a.substring(2).split('=')[0]: a.contains('=') ? a.split('=')[1] : 'true',
  };
  int i(String k, int d) => int.tryParse(opt[k] ?? '') ?? d;
  final gims = (opt['gims'] ?? '')
      .split(',')
      .where((s) => s.isNotEmpty)
      .map((s) => Gimmick.values.byName(s))
      .toList();
  final cap = i('cap', 2);
  final minLen = i('min', 8), maxLen = i('max', 24);
  final wMin = i('wmin', 4), wMax = i('wmax', 5);
  final hMin = i('hmin', 3), hMax = i('hmax', 4);
  final gMin = i('gmin', 2), gMax = i('gmax', 3);
  final extraMax = i('extra', 2);
  final colors = i('colors', 3);
  final tries = i('n', 20000);
  final keep = i('keep', 12);
  final rnd = Random(i('seed', 1));

  final found = <String, Map<String, Object>>{};
  for (var t = 0; t < tries; t++) {
    final w = wMin + rnd.nextInt(wMax - wMin + 1);
    final h = hMin + rnd.nextInt(hMax - hMin + 1);
    final g = List.generate(h + 2, (y) => List.generate(w + 2, (x) => x == 0 || y == 0 || x == w + 1 || y == h + 1 ? '#' : '.'));
    final cells = [for (var y = 1; y <= h; y++) for (var x = 1; x <= w; x++) (x, y)]..shuffle(rnd);
    var k = 0;
    (int, int) next() => cells[k++];
    void put(String c) {
      final (x, y) = next();
      g[y][x] = c;
    }

    final walls = (w * h * (0.05 + rnd.nextDouble() * 0.18)).round();
    final guests = gMin + rnd.nextInt(gMax - gMin + 1);
    final extras = rnd.nextInt(extraMax + 1);
    final need = 1 + walls + guests * 2 + extras + 3 * gims.length + 5;
    if (need >= cells.length) continue;
    put('P');
    for (var n = 0; n < walls; n++) {
      put('#');
    }
    for (var n = 0; n < guests; n++) {
      final c = String.fromCharCode(97 + rnd.nextInt(colors));
      put(c.toUpperCase());
      put(c);
    }
    for (var n = 0; n < extras; n++) {
      put(String.fromCharCode(97 + rnd.nextInt(colors)));
    }
    for (final gm in gims) {
      switch (gm) {
        case Gimmick.counter:
          put('T');
        case Gimmick.tray:
          for (var n = 0, m = 1 + rnd.nextInt(2); n < m; n++) {
            put('s');
          }
        case Gimmick.oneWay:
          for (var n = 0, m = 2 + rnd.nextInt(4); n < m; n++) {
            put('<>^v'[rnd.nextInt(4)]);
          }
      }
    }
    final map = trim([for (final r in g) r.join()]);
    final key = map.join('/');
    if (found.containsKey(key)) continue;
    final a = analyze(map, cap, maxStates: 60000);
    if (!a.solvable || a.unusedFloor > 0) continue;
    final len = a.solution!.length;
    if (len < minLen || len > maxLen) continue;
    if (!gims.every((gm) => isEssential(map, cap, gm, oneWayMargin: i('owmargin', 4)))) continue;
    final score = a.trapRatio * 40 + len * 0.6 + (a.reachable > 3000 ? -10 : 0);
    found[key] = {
      'map': map,
      'cap': cap,
      'par': len,
      'reachable': a.reachable,
      'trap': double.parse(a.trapRatio.toStringAsFixed(2)),
      'score': double.parse(score.toStringAsFixed(1)),
    };
  }
  final list = found.values.toList()..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  for (final l in list.take(keep)) {
    print(jsonEncode(l));
  }
}

/// Drops outer rows/columns that are wall-only beyond the first ring.
List<String> trim(List<String> rows) {
  bool allWall(String s) => s.split('').every((c) => c == '#');
  var r = rows;
  while (r.length > 3 && allWall(r[1])) {
    r = [r[0], ...r.sublist(2)];
  }
  while (r.length > 3 && allWall(r[r.length - 2])) {
    r = [...r.sublist(0, r.length - 2), r.last];
  }
  bool colWall(int x) => r.every((row) => row[x] == '#');
  while (r[0].length > 3 && colWall(1)) {
    r = [for (final row in r) row[0] + row.substring(2)];
  }
  while (r[0].length > 3 && colWall(r[0].length - 2)) {
    r = [for (final row in r) row.substring(0, row.length - 2) + row[row.length - 1]];
  }
  return r;
}
