import 'engine.dart';

/// Finds the ways to set every pipe so the stage is done.
///
/// Cells are filled row by row; each choice has to meet the neighbours
/// already chosen (an opening only where the neighbour opens back) and
/// the fixed cells around it. Those local checks cut the search down to a
/// handful of candidates, which are then checked for flow.
class Solver {
  Solver({this.cap = 64});

  /// Stop after this many solutions.
  final int cap;

  /// Opening masks (one per cell) of every solution, up to [cap].
  List<List<int>> solutions(Board b) {
    final n = b.width * b.height;
    final masks = List<int>.filled(n, 0);
    final known = List<bool>.filled(n, false);
    // cells that never change are known up front
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        final i = b.index(x, y);
        if (!b.turnable(x, y)) {
          masks[i] = b.maskAt(x, y, b.start[i]);
          known[i] = true;
        }
      }
    }
    final order = [for (var i = 0; i < n; i++) if (!known[i]) i];
    final options = <int, List<int>>{
      for (final i in order)
        i: {for (var r = 0; r < facings(b.grid[i ~/ b.width][i % b.width]); r++) b.maskAt(i % b.width, i ~/ b.width, r)}.toList(),
    };
    final out = <List<int>>[];
    final rotFor = <int, Map<int, int>>{};

    bool fits(int i, int m) {
      final x = i % b.width, y = i ~/ b.width;
      for (final d in Dir.values) {
        final nx = x + d.dx, ny = y + d.dy;
        final opens = m & d.bit != 0;
        if (!b.inside(nx, ny)) {
          if (opens) return false;
          continue;
        }
        final j = b.index(nx, ny);
        if (!known[j]) continue;
        final back = masks[j] & d.opposite.bit != 0;
        if (opens != back) return false;
      }
      return true;
    }

    void rec(int k) {
      if (out.length >= cap) return;
      if (k == order.length) {
        final rot = _rotations(b, masks, rotFor);
        if (StockFlow.of(b, rot).won) out.add([...masks]);
        return;
      }
      final i = order[k];
      for (final m in options[i]!) {
        if (!fits(i, m)) continue;
        masks[i] = m;
        known[i] = true;
        rec(k + 1);
        known[i] = false;
      }
    }

    rec(0);
    return out;
  }

  /// Taps needed to turn [s] into the solution with opening [masks].
  static int tapsTo(GameState s, List<int> masks) {
    final b = s.board;
    var total = 0;
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (!b.turnable(x, y)) continue;
        total += _tapsFor(b, x, y, s.rotAt(x, y), masks[b.index(x, y)]);
      }
    }
    return total;
  }

  static int _tapsFor(Board b, int x, int y, int from, int mask) {
    for (var t = 0; t < 4; t++) {
      if (b.maskAt(x, y, from + t) == mask) return t;
    }
    throw StateError('no rotation of ${b.at(x, y)} gives $mask');
  }

  /// The fewest taps from [s] to any solution, and that solution.
  (int, List<int>)? best(GameState s) {
    int? bestTaps;
    List<int>? bestMasks;
    for (final m in solutions(s.board)) {
      final t = tapsTo(s, m);
      if (bestTaps == null || t < bestTaps) {
        bestTaps = t;
        bestMasks = m;
      }
    }
    return bestMasks == null ? null : (bestTaps!, bestMasks);
  }

  /// A pipe to tap next on the way to the nearest solution.
  Pos? hint(GameState s) {
    final r = best(s);
    if (r == null) return null;
    final b = s.board;
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (b.turnable(x, y) && s.maskAt(x, y) != r.$2[b.index(x, y)]) return Pos(x, y);
      }
    }
    return null;
  }

  static List<int> _rotations(Board b, List<int> masks, Map<int, Map<int, int>> cache) {
    return [
      for (var i = 0; i < masks.length; i++)
        () {
          final x = i % b.width, y = i ~/ b.width;
          if (!b.turnable(x, y)) return b.start[i];
          final byMask = cache.putIfAbsent(i, () => {for (var r = 3; r >= 0; r--) b.maskAt(x, y, r): r});
          return byMask[masks[i]]!;
        }(),
    ];
  }
}
