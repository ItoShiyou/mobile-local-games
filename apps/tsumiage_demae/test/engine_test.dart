import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiage_demae/game/controller.dart';
import 'package:tsumiage_demae/game/engine.dart';
import 'package:tsumiage_demae/game/levels.dart';
import 'package:tsumiage_demae/game/solver.dart';

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

  group('cat-tongued guest', () {
    test('a fresh dish is too hot; it cools one step at a time', () {
      // E wants a, cat tongue
      final b = Board.parse(['#########', '#Pa....E#', '#########']);
      var s = play(b.initialState(), [r]);
      expect(s.heat, [coolSteps]);
      s = play(s, [r, r]);
      expect(s.heat, [coolSteps - 2]);
      s = play(s, [r]);
      expect(s.heat, [0]);
      s = play(s, [r, r]);
      expect(s.isWon, isTrue);
    });

    test('bumping while it still steams is refused', () {
      final b = Board.parse(['######', '#PaE.#', '#....#', '######']);
      final s = play(b.initialState(), [r]);
      expect(s.move(r).blocked, Blocked.tooHot);
      final cooled = play(s, [d, l, u, r]);
      expect(cooled.heat, [0]);
      expect(play(cooled, [r]).isWon, isTrue);
    });

    test('heat travels with each dish through a flip', () {
      final b = Board.parse(['#######', '#Pa.bs#', '#A#####', '#######']);
      final s = play(b.initialState(), [r, r, r, r]);
      expect(s.stack, ['b', 'a']);
      expect(s.heat, [coolSteps - 1, 0]);
    });

    test('a normal guest takes a hot dish', () {
      final b = Board.parse(['######', '#PaA##', '######']);
      expect(play(b.initialState(), [r, r]).isWon, isTrue);
    });
  });

  group('shared table', () {
    test('takes two dishes at once, in its order', () {
      final b = Board.parse(['#######', '#Pba.W#', '#######'], orders: ['ab']);
      final s = play(b.initialState(), [r, r, r, r]);
      expect(s.isWon, isTrue);
      expect(s.stack, isEmpty);
    });

    test('the wrong order, or only one dish, is refused', () {
      final b = Board.parse(['#######', '#Pab.W#', '#######'], orders: ['ab']);
      expect(play(b.initialState(), [r, r, r]).move(r).blocked, Blocked.wrongDish);
      final one = Board.parse(['######', '#Pa.W#', '######'], orders: ['ab']);
      expect(play(one.initialState(), [r, r]).move(r).blocked, Blocked.wrongDish);
    });

    test('needs an order for every table', () {
      expect(() => Board.parse(['#####', '#P.W#', '#####']), throwsFormatException);
    });
  });

  group('cart', () {
    test('slides until something stops it; the cat stays put', () {
      final b = Board.parse(['########', '#P=...#A', '########']);
      final s = play(b.initialState(), [r]);
      expect(s.pos, const Pos(1, 1));
      expect(s.carts, [const Pos(5, 1)]);
      expect(s.move(l).blocked, Blocked.wall);
    });

    test('a cart against a wall does not move', () {
      final b = Board.parse(['#####', '#P=##', '#..A#', '#####']);
      expect(b.initialState().move(r).blocked, Blocked.cartStuck);
    });

    test('a loaded cart delivers to the guest who wants its dish', () {
      final b = Board.parse(['#######', '#Pw..A#', '#######']);
      final s = play(b.initialState(), [r]);
      expect(s.isWon, isTrue);
      expect(s.isLoaded(0), isFalse);
      expect(s.carts, [const Pos(4, 1)]);
    });

    test('dishes on the floor stop a cart; the wrong guest does not take it', () {
      final b = Board.parse(['########', '#Px.a.B#', '#.....A#', '########']);
      final s = play(b.initialState(), [r]);
      expect(s.carts, [const Pos(3, 1)]);
      final b2 = Board.parse(['######', '#Pw.B#', '#...A#', '######']);
      final s2 = play(b2.initialState(), [r]);
      expect(s2.carts, [const Pos(3, 1)]);
      expect(s2.served, 0);
    });

    test('the cat can walk where a cart used to be', () {
      final b = Board.parse(['#######', '#P=..A#', '#.....#', '#######']);
      final s = play(b.initialState(), [r, r]);
      expect(s.pos, const Pos(2, 1));
    });
  });

  test('a dead-end search remembers every position it reached', () {
    // b on top of a: guest A can never be served
    final b = Board.parse(['#######', '#Pab.A#', '#.....#', '#######']);
    final stuck = play(b.initialState(), [r, r]);
    final dead = <String>{};
    expect(Solver().solve(stuck, dead: dead), isNull);
    expect(dead, contains(stuck.key));
    final further = play(stuck, [d, r]);
    expect(dead, contains(further.key));
    expect(Solver().solve(further, dead: dead), isNull);
    // a live position is still solved, and never marked
    expect(Solver().solve(b.initialState(), dead: dead), isNotNull);
    expect(dead, isNot(contains(b.initialState().key)));
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

    test('a dead end is only pointed out after the player runs into it', () {
      final level = Level(id: 'x', ja: '', en: '', par: 0, map: ['#######', '#Pab.A#', '#.....#', '#######']);
      final c = GameController(level);
      c.move(Dir.right);
      c.move(Dir.right);
      expect(c.stuck, isTrue);
      expect(c.beckonUndo, isFalse, reason: 'walking into a dead end is not announced');
      c.move(Dir.right);
      c.move(Dir.right);
      expect(c.bump?.reason, Blocked.wrongDish);
      expect(c.bump?.wanted, 'a');
      expect(c.beckonUndo, isTrue);
      c.undo();
      expect(c.beckonUndo, isTrue, reason: 'still stuck one move back');
      c.undo();
      c.undo();
      expect(c.stuck, isFalse);
      expect(c.beckonUndo, isFalse);
    });
  });
}
