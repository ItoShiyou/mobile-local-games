import 'dart:collection';

import 'engine.dart';

/// Breadth-first search over [GameState]s. The state space of a stage is
/// small (a few thousand positions), so an exhaustive search is cheap enough
/// to run on every move for hints and dead-end detection.
class Solver {
  Solver({this.maxStates = 400000});

  final int maxStates;

  /// Shortest winning move sequence from [start], or null if none exists
  /// (or the search budget is exhausted).
  List<Dir>? solve(GameState start) {
    if (start.isWon) return const [];
    final parent = <String, (String, Dir)>{};
    final seen = <String>{start.key};
    final queue = Queue<GameState>()..add(start);
    while (queue.isNotEmpty) {
      final s = queue.removeFirst();
      for (final d in Dir.values) {
        final r = s.move(d);
        final n = r.state;
        if (n == null) continue;
        final k = n.key;
        if (!seen.add(k)) continue;
        parent[k] = (s.key, d);
        if (n.isWon) return _path(parent, start.key, k);
        if (seen.length > maxStates) return null;
        queue.add(n);
      }
    }
    return null;
  }

  List<Dir> _path(Map<String, (String, Dir)> parent, String root, String leaf) {
    final out = <Dir>[];
    var k = leaf;
    while (k != root) {
      final (p, d) = parent[k]!;
      out.add(d);
      k = p;
    }
    return out.reversed.toList();
  }

  /// Statistics used by the level tools to judge how interesting a stage is.
  SearchStats stats(GameState start) {
    final seen = <String>{start.key};
    final queue = Queue<GameState>()..add(start);
    var wins = 0;
    while (queue.isNotEmpty && seen.length <= maxStates) {
      final s = queue.removeFirst();
      if (s.isWon) {
        wins++;
        continue;
      }
      for (final d in Dir.values) {
        final n = s.move(d).state;
        if (n != null && seen.add(n.key)) queue.add(n);
      }
    }
    return SearchStats(reachable: seen.length, winning: wins);
  }
}

class SearchStats {
  const SearchStats({required this.reachable, required this.winning});
  final int reachable;
  final int winning;
}
