import 'package:flutter_test/flutter_test.dart';
import 'package:dashi_mawashi/game/controller.dart';
import 'package:dashi_mawashi/game/engine.dart';
import 'package:dashi_mawashi/game/levels.dart';
import 'package:dashi_mawashi/game/solver.dart';

Board board(List<String> map, List<String> rot, {List<String> fixed = const [], required List<String> pots, required List<String> bowls}) =>
    Board.parse(map, rot, fixed: fixed, pots: pots, bowls: bowls);

void main() {
  test('pipe shapes turn clockwise', () {
    expect(turn(baseMask['I']!, 1), Dir.left.bit | Dir.right.bit);
    expect(turn(baseMask['L']!, 1), Dir.right.bit | Dir.down.bit);
    expect(turn(baseMask['T']!, 3), Dir.up.bit | Dir.right.bit | Dir.down.bit);
    expect(facings('I'), 2);
    expect(facings('X'), 1);
  });

  test('a straight pipe carries the stock from pot to bowl', () {
    final b = board(['PIB'], ['010'], pots: ['k 0,0 r'], bowls: ['k 2,0 l']);
    final s = b.initialState();
    expect(s.flow.won, isTrue);
    expect(s.flow.bowls, ['k']);
  });

  test('turning a pipe the wrong way spills and leaves the bowl dry', () {
    final b = board(['PIB'], ['000'], pots: ['k 0,0 r'], bowls: ['k 2,0 l']);
    final s = b.initialState();
    expect(s.flow.won, isFalse);
    expect(s.flow.bowls, ['']);
    expect(s.flow.spills(b, 0, 0, Dir.right), isTrue);
    final r = s.tap(1, 0);
    expect(r.isOk, isTrue);
    expect(r.state!.isWon, isTrue);
    expect(r.state!.tap(1, 0).blocked, Blocked.finished);
  });

  test('stocks that meet mix, and a bowl wants the exact mix', () {
    // katsuo from the left, kombu from the right, meeting at a tee above a bowl
    final b = board(['PTP', '.B.'], ['000', '000'], pots: ['k 0,0 r', 'n 2,0 l'], bowls: ['kn 1,1 u']);
    final s = b.initialState();
    expect(s.flow.bowls, ['kn']);
    expect(s.isWon, isTrue);
    final wantsKatsuo = board(['PTP', '.B.'], ['000', '000'], pots: ['k 0,0 r', 'n 2,0 l'], bowls: ['k 1,1 u']);
    expect(wantsKatsuo.initialState().isWon, isFalse);
  });

  test('a crossing keeps the two stocks apart', () {
    final b = board(['.P.', 'PXB', '.B.'], ['000', '000', '000'], pots: ['k 1,0 d', 'n 0,1 r'], bowls: ['n 2,1 l', 'k 1,2 u']);
    final s = b.initialState();
    expect(s.flow.bowls, ['n', 'k']);
    expect(s.isWon, isTrue);
    expect(s.tap(1, 1).blocked, Blocked.iron, reason: 'a crossing looks the same every way round, so it does not turn');
  });

  test('iron pipes do not turn', () {
    final b = board(['PIB'], ['000'], fixed: ['1,0'], pots: ['k 0,0 r'], bowls: ['k 2,0 l']);
    expect(b.initialState().tap(1, 0).blocked, Blocked.iron);
    expect(Solver().solutions(b), isEmpty);
  });

  test('a dry loop of pipes does not count as joined up', () {
    final b = board(['LL.', 'LLB', 'P.#'], ['120', '030', '000'], pots: ['k 0,2 u'], bowls: ['k 2,1 l']);
    expect(b.initialState().isWon, isFalse);
  });

  group('solver', () {
    test('finds the one answer and the fewest taps to it', () {
      final b = board(['PIB'], ['000'], pots: ['k 0,0 r'], bowls: ['k 2,0 l']);
      final sols = Solver().solutions(b);
      expect(sols, hasLength(1));
      expect(Solver.tapsTo(b.initialState(), sols.first), 1);
      expect(Solver().hint(b.initialState()), const Pos(1, 0));
    });
  });

  group('GameController', () {
    test('taps, undo, redo and restart', () {
      final c = GameController(allLevels.first);
      final h = c.showHint()!;
      expect(c.tap(h.x, h.y).isOk, isTrue);
      expect(c.moves, 1);
      expect(c.undo(), isTrue);
      expect(c.moves, 0);
      expect(c.redo(), isTrue);
      c.restart();
      expect(c.moves, 0);
      expect(c.canRedo, isFalse);
    });

    test('following hints finishes the stage in par taps', () {
      for (final level in allLevels.take(3)) {
        final c = GameController(level);
        while (!c.isWon) {
          final h = c.showHint();
          expect(h, isNotNull);
          c.tap(h!.x, h.y);
        }
        expect(c.moves, level.par);
      }
    });

    test('the keyboard cursor moves and taps', () {
      final c = GameController(allLevels.first);
      final start = c.cursor;
      c.moveCursor(Dir.right);
      expect(c.cursor, start.step(Dir.right));
      c.moveCursor(Dir.left);
      expect(c.cursor, start);
    });
  });
}
