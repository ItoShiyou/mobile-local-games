import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiage_demae/game/controller.dart';
import 'package:tsumiage_demae/game/engine.dart';
import 'package:tsumiage_demae/game/levels.dart';

GameState play(GameState s, List<Dir> moves) {
  for (final d in moves) {
    final r = s.move(d);
    expect(r.isOk, isTrue, reason: 'move $d from ${s.pos} refused: ${r.blocked}');
    s = r.state!;
  }
  return s;
}

void main() {
  const r = Dir.right, l = Dir.left, u = Dir.up, d = Dir.down;

  test('walking over a dish always picks it up; last picked is on top', () {
    final b = Board.parse(['#######', '#Pab.A#', '#######']);
    final s = play(b.initialState(), [r, r]);
    expect(s.stack, ['a', 'b']);
    expect(s.top, 'b');
    expect(s.isTaken(0) && s.isTaken(1), isTrue);
  });

  test('capacity blocks stepping onto another dish', () {
    final b = Board.parse(['########', '#Pabc.A#', '########'], capacity: 2);
    final s = play(b.initialState(), [r, r]);
    expect(s.move(r).blocked, Blocked.full);
  });

  test('guests only take the dish they ordered, from the top', () {
    final b = Board.parse(['#######', '#Pba.A#', '#######']);
    var s = play(b.initialState(), [r, r, r]);
    final res = s.move(r);
    expect(res.isOk, isTrue);
    expect(res.events.whereType<Served>().single.color, 'a');
    s = res.state!;
    expect(s.pos, const Pos(4, 1), reason: 'serving does not move the courier');
    expect(s.stack, ['b']);
    expect(s.isWon, isTrue);

    final b2 = Board.parse(['#######', '#Pab.A#', '#######']);
    final s2 = play(b2.initialState(), [r, r, r]);
    expect(s2.move(r).blocked, Blocked.wrongDish);
  });

  test('served guests and empty hands are refused', () {
    final b = Board.parse(['#######', '#PA.aB#', '#######']);
    expect(b.initialState().move(r).blocked, Blocked.emptyHands);
  });

  test('return counter takes the top dish once', () {
    final b = Board.parse(['#######', '#Pab.A#', '####T##', '#######']);
    var s = play(b.initialState(), [r, r, r]);
    final res = s.move(d);
    expect(res.events.single, isA<Returned>());
    s = res.state!;
    expect(s.stack, ['a']);
    expect(s.move(d).blocked, Blocked.counterUsed);
    s = play(s, [r]);
    expect(s.isWon, isTrue);
  });

  test('flip tray reverses the stack after picking up', () {
    final b = Board.parse(['#######', '#Pabs.A#', '#######']);
    final s = play(b.initialState(), [r, r, r]);
    expect(s.stack, ['b', 'a']);
    final b2 = Board.parse(['######', '#PasA#', '######']);
    final s2 = play(b2.initialState(), [r, r]);
    expect(s2.stack, ['a'], reason: 'a single dish is unaffected');
  });

  test('one-way floor can only be entered in its direction', () {
    final b = Board.parse(['######', '#P>.A#', '######']);
    var s = play(b.initialState(), [r, r]);
    expect(s.move(l).blocked, Blocked.oneWay, reason: 'cannot enter against the arrow');
    s = play(b.initialState(), [r]);
    s = s.move(l).state!;
    expect(s.pos, const Pos(1, 1), reason: 'leaving an arrow is always allowed');
    final b2 = Board.parse(['######', '#P<.A#', '######']);
    expect(b2.initialState().move(r).blocked, Blocked.oneWay);
  });

  test('walls and void block', () {
    final b = Board.parse(['####', '#P##', '##A#', '####']);
    for (final dir in Dir.values) {
      expect(b.initialState().move(dir).blocked, Blocked.wall);
    }
    expect(u.opposite, d);
  });

  group('GameController', () {
    test('undo, redo and restart', () {
      final c = GameController(allLevels.first);
      c.move(Dir.right);
      c.move(Dir.right);
      expect(c.moves, 2);
      expect(c.undo(), isTrue);
      expect(c.moves, 1);
      expect(c.canRedo, isTrue);
      expect(c.redo(), isTrue);
      expect(c.state.stack, ['a']);
      c.undo();
      c.move(Dir.left);
      expect(c.canRedo, isFalse, reason: 'a new move drops the redo branch');
      c.restart();
      expect(c.moves, 0);
      expect(c.canUndo, isFalse);
    });

    test('refused moves do not count and report a bump', () {
      final c = GameController(allLevels.first);
      final res = c.move(Dir.up);
      expect(res.isOk, isFalse);
      expect(c.moves, 0);
      expect(c.bump?.reason, Blocked.wall);
    });

    test('hint follows the shortest solution and the stage can be won', () {
      final c = GameController(allLevels[1]);
      while (!c.isWon) {
        final h = c.showHint();
        expect(h, isNotNull);
        c.move(h!);
      }
      expect(c.moves, allLevels[1].par);
    });

    test('dead ends are detected', () {
      // burying the tomato under a matcha nobody ordered
      final level = Level(id: 'x', ja: '', en: '', par: 0, map: ['#######', '#Pab.A#', '#.....#', '#######']);
      final c = GameController(level);
      expect(c.stuck, isFalse);
      c.move(Dir.right);
      c.move(Dir.right);
      expect(c.stuck, isTrue);
      c.undo();
      expect(c.stuck, isFalse);
    });
  });
}
