import 'package:flutter_test/flutter_test.dart';
import 'package:fusuma_watari/game/engine.dart';
import 'package:fusuma_watari/game/levels.dart';
import 'package:fusuma_watari/game/solver.dart';

/// What the shortest solution does with each gimmick.
({bool paired, bool swung, bool unlocked, int pushes}) _uses(Level level, List<Dir> sol) {
  var s = level.board.initialState();
  var paired = false, swung = false, unlocked = false;
  var pushes = 0;
  for (final d in sol) {
    final r = s.move(d);
    for (final e in r.events) {
      if (e is Slid) {
        pushes++;
        if (e.doors.length > 1) paired = true;
        if (e.doors.any((i) => level.board.doors[i].locked)) unlocked = true;
      }
      if (e is Swung) {
        pushes++;
        swung = true;
      }
    }
    s = r.state!;
  }
  return (paired: paired, swung: swung, unlocked: unlocked, pushes: pushes);
}

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
    expect(intro, ['guests', 'pair', 'lock', 'revolve']);
  });

  for (final level in allLevels) {
    group('${level.id} ${level.ja}', () {
      final sol = Solver().solve(level.board.initialState());

      test('is solvable in exactly par moves', () {
        expect(sol, isNotNull);
        expect(sol!.length, level.par);
        var s = level.board.initialState();
        for (final d in sol) {
          s = s.move(d).state!;
        }
        expect(s.isWon, isTrue);
      });

      test('fits on a phone and the doors sit on free tatami', () {
        final b = level.board;
        expect(b.width, lessThanOrEqualTo(9));
        expect(b.height, lessThanOrEqualTo(8));
        final s = b.initialState();
        final seen = <Pos>{};
        for (var i = 0; i < b.doors.length; i++) {
          for (final c in s.cells(i)) {
            expect(b.doorFloor(c.x, c.y), isTrue, reason: 'door $i on ${b.at(c.x, c.y)} at $c');
            expect(seen.add(c), isTrue, reason: 'doors overlap at $c');
          }
        }
      });

      test('needs the doors, and uses every gimmick it has', () {
        final u = _uses(level, sol!);
        expect(u.pushes, greaterThanOrEqualTo(1));
        if (level.board.doors.any((d) => d.pair != null)) expect(u.paired, isTrue);
        if (level.board.hasLocks) expect(u.unlocked, isTrue);
        if (level.board.doors.any((d) => d.kind == DoorKind.revolve)) expect(u.swung, isTrue);
      });
    });
  }
}
