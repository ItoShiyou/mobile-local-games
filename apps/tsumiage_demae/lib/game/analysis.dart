import 'dart:collection';

import 'engine.dart';
import 'solver.dart';

/// Gimmicks a stage can use. Each one knows how to replace itself with its
/// plain counterpart, so we can check that the stage really needs it.
enum Gimmick {
  counter('T', {'T': '#'}),
  tray('s', {'s': '.'}),
  oneWay('<>^v', {'<': '.', '>': '.', '^': '.', 'v': '.'});

  const Gimmick(this.chars, this.neutral);
  final String chars;
  final Map<String, String> neutral;

  List<String> neutralize(List<String> map) => [
        for (final row in map) row.split('').map((c) => neutral[c] ?? c).join(),
      ];
}

class StageAnalysis {
  const StageAnalysis({
    required this.solution,
    required this.reachable,
    required this.deadEnds,
    required this.unusedFloor,
  });

  /// Shortest solution, null when unsolvable.
  final List<Dir>? solution;
  final int reachable;

  /// Reachable states from which the stage can no longer be won.
  final int deadEnds;

  /// Floor cells that no reachable state ever stands on.
  final int unusedFloor;

  bool get solvable => solution != null;
  double get trapRatio => reachable == 0 ? 0 : deadEnds / reachable;
}

StageAnalysis analyze(List<String> map, int capacity, {int maxStates = 200000}) {
  final board = Board.parse(map, capacity: capacity);
  final start = board.initialState();
  final solution = Solver(maxStates: maxStates).solve(start);

  // Full forward exploration, remembering reverse edges.
  final index = <String, int>{start.key: 0};
  final states = <GameState>[start];
  final reverse = <List<int>>[[]];
  final wins = <int>[];
  final queue = Queue<int>()..add(0);
  while (queue.isNotEmpty && states.length <= maxStates) {
    final i = queue.removeFirst();
    final s = states[i];
    if (s.isWon) {
      wins.add(i);
      continue;
    }
    for (final d in Dir.values) {
      final n = s.move(d).state;
      if (n == null) continue;
      var j = index[n.key];
      if (j == null) {
        j = states.length;
        index[n.key] = j;
        states.add(n);
        reverse.add([]);
        queue.add(j);
      }
      reverse[j].add(i);
    }
  }
  final alive = List<bool>.filled(states.length, false);
  final back = Queue<int>();
  for (final w in wins) {
    alive[w] = true;
    back.add(w);
  }
  while (back.isNotEmpty) {
    final j = back.removeFirst();
    for (final i in reverse[j]) {
      if (!alive[i]) {
        alive[i] = true;
        back.add(i);
      }
    }
  }
  final visited = <Pos>{for (final s in states) s.pos};
  var unused = 0;
  for (var y = 0; y < board.height; y++) {
    for (var x = 0; x < board.width; x++) {
      final c = board.at(x, y);
      final walkable = c == '.' || c == 'P' || c == 's' || arrowDirs.containsKey(c) ||
          (board.dishAt(x, y) >= 0);
      if (walkable && !visited.contains(Pos(x, y))) unused++;
    }
  }
  return StageAnalysis(
    solution: solution,
    reachable: states.length,
    deadEnds: alive.where((a) => !a).length,
    unusedFloor: unused,
  );
}

/// True when [g] changes how the stage is solved.
///
/// Counters and trays give the player new abilities, so they are essential
/// when the stage cannot be solved without them. One-way floors only take
/// options away, so they are essential when removing them would make the
/// shortest solution at least [oneWayMargin] moves shorter.
bool isEssential(List<String> map, int capacity, Gimmick g, {int oneWayMargin = 4}) {
  final plain = g.neutralize(map);
  final board = Board.parse(plain, capacity: capacity);
  final without = Solver(maxStates: 200000).solve(board.initialState());
  if (without == null) return true;
  if (g != Gimmick.oneWay) return false;
  final with_ = Solver(maxStates: 200000).solve(Board.parse(map, capacity: capacity).initialState());
  return with_ != null && with_.length - without.length >= oneWayMargin;
}

/// True when removing [g] changes the length of the shortest solution (or
/// makes the stage unsolvable): the gimmick is part of the intended route,
/// as a shortcut, an obstacle or a necessity.
bool gimmickMatters(List<String> map, int capacity, Gimmick g) {
  final plain = Solver(maxStates: 200000).solve(Board.parse(g.neutralize(map), capacity: capacity).initialState());
  if (plain == null) return true;
  final real = Solver(maxStates: 200000).solve(Board.parse(map, capacity: capacity).initialState());
  return real != null && real.length != plain.length;
}
