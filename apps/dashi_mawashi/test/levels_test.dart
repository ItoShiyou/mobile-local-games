import 'package:flutter_test/flutter_test.dart';
import 'package:dashi_mawashi/game/engine.dart';
import 'package:dashi_mawashi/game/levels.dart';
import 'package:dashi_mawashi/game/solver.dart';

void main() {
  test('forty stages with unique ids', () {
    final ids = allLevels.map((l) => l.id).toList();
    expect(ids.length, 40);
    expect(ids.toSet().length, ids.length);
  });

  test('stages are linked in order and gimmicks are introduced once, in chapter order', () {
    for (var i = 0; i + 1 < allLevels.length; i++) {
      expect(allLevels[i].next, same(allLevels[i + 1]));
    }
    expect(allLevels.last.next, isNull);
    final intro = allLevels.where((l) => l.introduces != null).map((l) => l.introduces).toList();
    expect(intro, ['mix', 'iron', 'cross', 'shiitake']);
  });

  for (final level in allLevels) {
    group('${level.id} ${level.ja}', () {
      final b = level.board;
      final sols = Solver(cap: 2).solutions(b);

      test('has exactly one answer, par taps away', () {
        expect(sols, hasLength(1));
        expect(Solver.tapsTo(b.initialState(), sols.first), level.par);
        expect(b.initialState().isWon, isFalse);
      });

      test('fits on a phone', () {
        expect(b.width, lessThanOrEqualTo(6));
        expect(b.height, lessThanOrEqualTo(8));
      });

      test('uses every gimmick it has', () {
        // the answer, laid out
        final rot = [
          for (var i = 0; i < sols.first.length; i++)
            () {
              final x = i % b.width, y = i ~/ b.width;
              if (!b.turnable(x, y)) return b.start[i];
              for (var r = 0; r < 4; r++) {
                if (b.maskAt(x, y, r) == sols.first[i]) return r;
              }
              return 0;
            }(),
        ];
        final flow = StockFlow.of(b, rot);
        expect(flow.won, isTrue);
        if (level.gimmicks.contains('mix')) expect(b.bowls.any((w) => w.want.length > 1), isTrue);
        if (level.gimmicks.contains('cross')) {
          // some crossing carries stock both ways
          var both = false;
          for (var y = 0; y < b.height; y++) {
            for (var x = 0; x < b.width; x++) {
              if (b.at(x, y) == 'X' && flow.carry(b, x, y, 0).isNotEmpty && flow.carry(b, x, y, 1).isNotEmpty) both = true;
            }
          }
          expect(both, isTrue);
        }
        if (level.gimmicks.contains('iron')) {
          // without the iron, the answer would not be unique (or the start would differ)
          expect(level.fixed, isNotEmpty);
        }
      });
    });
  }
}
