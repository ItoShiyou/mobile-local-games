import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiage_demae/game/analysis.dart';
import 'package:tsumiage_demae/game/levels.dart';
import 'package:tsumiage_demae/game/solver.dart';

void main() {
  test('stage ids are unique', () {
    final ids = allLevels.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('stages are linked in order and gimmicks are introduced once', () {
    for (var i = 0; i + 1 < allLevels.length; i++) {
      expect(allLevels[i].next, same(allLevels[i + 1]));
    }
    expect(allLevels.last.next, isNull);
    final intro = allLevels.where((l) => l.introduces != null).map((l) => l.introduces).toList();
    expect(intro, ['counter', 'tray', 'oneWay']);
  });

  for (final level in allLevels) {
    group('${level.id} ${level.ja}', () {
      test('is solvable in exactly par moves', () {
        final sol = Solver().solve(level.board.initialState());
        expect(sol, isNotNull);
        expect(sol!.length, level.par);
        var s = level.board.initialState();
        for (final d in sol) {
          s = s.move(d).state!;
        }
        expect(s.isWon, isTrue);
      });

      test('fits on a phone and every floor cell is reachable', () {
        expect(level.board.width, lessThanOrEqualTo(8));
        expect(level.board.height, lessThanOrEqualTo(8));
        expect(level.cap, inInclusiveRange(2, 3));
        expect(analyze(level.map, level.cap).unusedFloor, 0);
      });

      for (final g in level.gimmicks) {
        test('uses its $g', () {
          expect(gimmickMatters(level.map, level.cap, Gimmick.values.byName(g)), isTrue);
        });
      }
      if (level.introduces != null) {
        test('cannot be solved without the gimmick it introduces', () {
          expect(isEssential(level.map, level.cap, Gimmick.values.byName(level.introduces!), oneWayMargin: 1), isTrue);
        });
      }
    });
  }
}
