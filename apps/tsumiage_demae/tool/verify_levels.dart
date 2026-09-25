// Prints, for every stage, its shortest solution and what happens to it when
// each gimmick is removed.   dart run tool/verify_levels.dart
import 'package:tsumiage_demae/game/analysis.dart';
import 'package:tsumiage_demae/game/engine.dart';
import 'package:tsumiage_demae/game/levels.dart';
import 'package:tsumiage_demae/game/solver.dart';

void main() {
  for (final l in allLevels) {
    final a = analyze(l.map, l.cap);
    final parts = <String>[];
    for (final g in l.gimmicks) {
      final plain = Gimmick.values.byName(g).neutralize(l.map);
      final sol = Solver().solve(Board.parse(plain, capacity: l.cap).initialState());
      parts.add('$g→${sol?.length ?? 'X'}');
    }
    final unused = <String>[];
    if (a.unusedFloor > 0) {
      final visited = <Pos>{};
      // cheap re-exploration for positions
      final seen = <String>{};
      final q = [l.board.initialState()];
      while (q.isNotEmpty) {
        final s = q.removeLast();
        if (!seen.add(s.key)) continue;
        visited.add(s.pos);
        if (s.isWon) continue;
        for (final d in Dir.values) {
          final n = s.move(d).state;
          if (n != null) q.add(n);
        }
      }
      for (var y = 0; y < l.board.height; y++) {
        for (var x = 0; x < l.board.width; x++) {
          final c = l.board.at(x, y);
          if ('.Pabcds<>^v'.contains(c) && !visited.contains(Pos(x, y))) unused.add('($x,$y)');
        }
      }
    }
    print('${l.id} par=${l.par} bfs=${a.solution?.length} trap=${a.trapRatio.toStringAsFixed(2)} ${parts.join(' ')} ${unused.isEmpty ? '' : 'UNUSED ${unused.join(',')}'}');
  }
}
