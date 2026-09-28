import 'package:flutter_test/flutter_test.dart';
import 'package:fusuma_watari/game/controller.dart';
import 'package:fusuma_watari/game/engine.dart';
import 'package:fusuma_watari/game/levels.dart';
import 'package:fusuma_watari/game/solver.dart';

GameState play(GameState s, List<Dir> moves) {
  for (final d in moves) {
    final r = s.move(d);
    expect(r.isOk, isTrue, reason: 'move $d from ${s.pos} refused: ${r.blocked}');
    s = r.state!;
  }
  return s;
}

GameState start(List<String> map, [List<String> doors = const []]) => Board.parse(map, doors).initialState();

void main() {
  const r = Dir.right, u = Dir.up, d = Dir.down;

  test('door specs round-trip', () {
    for (final spec in ['h1,2,3', 'v4,1,2=a', 'h2,2,2*', 'r3,3,u']) {
      expect(Door.parse(spec).spec, spec);
    }
  });

  test('walking into a door slides it along its track', () {
    final s = play(start(['#######', '#P...A#', '#.....#', '#######'], ['h2,1,2']), [r]);
    expect(s.pos, const Pos(2, 1));
    expect(s.cells(0), [const Pos(3, 1), const Pos(4, 1)]);
  });

  test('a door cannot be pushed across its track', () {
    final s = start(['#####', '#P..#', '#...#', '#..A#', '#####'], ['h1,2,2']);
    final res = s.move(d);
    expect(res.blocked, Blocked.across);
    expect(res.door, 0);
  });

  test('a door jams against walls, guests and other doors', () {
    // wall
    expect(start(['#####', '#P..#', '#..A#', '#####'], ['h2,1,2']).move(r).blocked, Blocked.jammed);
    // guest
    expect(start(['######', '#P..A#', '#....#', '######'], ['h2,1,2']).move(r).blocked, Blocked.jammed);
    // another door
    expect(start(['#######', '#P....#', '#....A#', '#######'], ['h2,1,2', 'v4,1,2']).move(r).blocked, Blocked.jammed);
  });

  test('bumping into a guest serves them; serving everyone wins', () {
    var s = start(['######', '#P.A.#', '#..B.#', '######']);
    s = play(s, [r]);
    final res = s.move(r);
    expect(res.events.whereType<Served>().single.guestIndex, 0);
    s = res.state!;
    expect(s.move(r).blocked, Blocked.alreadyServed);
    s = play(s, [d]);
    expect(s.isWon, isFalse);
    s = play(s, [r]);
    expect(s.isWon, isTrue);
    expect(s.move(u).blocked, Blocked.finished);
  });

  test('paired doors slide together, and neither moves if one jams', () {
    var s = start(['########', '#P.....#', '#......#', '#.....A#', '########'], ['h2,1,2=a', 'h1,3,2=a']);
    s = play(s, [r]);
    expect(s.cells(0).first, const Pos(3, 1));
    expect(s.cells(1).first, const Pos(2, 3));
    // the partner is stuck against the guest on its row
    final jam = start(['#######', '#P....#', '#..#.A#', '#######'], ['h2,1,2=a', 'h1,2,2=a']);
    expect(jam.move(r).blocked, Blocked.jammed);
  });

  test('a locked door moves only after the key is taken', () {
    final map = ['#######', '#P...A#', '#k....#', '#######'];
    var s = start(map, ['h2,1,2*']);
    expect(s.hasKey, isFalse);
    expect(s.move(r).blocked, Blocked.locked);
    final res = s.move(d);
    expect(res.events.whereType<KeyTaken>(), hasLength(1));
    s = play(res.state!, [u, r]);
    expect(s.cells(0).first, const Pos(3, 1));
  });

  test('a revolving shoji swings a quarter turn when pushed from the side', () {
    //   pivot at (3,2), arm to the right at (4,2); the cat pushes the arm down
    var s = start(['#######', '#.....#', '#..P..#', '#.....#', '#....A#', '#######'], ['r3,3,r']);
    expect(s.cells(0), [const Pos(3, 3), const Pos(4, 3)]);
    s = play(s, [r]);
    final res = s.move(d);
    expect(res.isOk, isTrue);
    expect(res.events.whereType<Swung>().single.to, Dir.down);
    s = res.state!;
    expect(s.cells(0), [const Pos(3, 3), const Pos(3, 4)]);
    expect(s.pos, const Pos(4, 3));
  });

  test('a revolving shoji will not turn at its post or along its arm', () {
    final s = start(['#######', '#.....#', '#P....#', '#.....#', '#....A#', '#######'], ['r2,2,r']);
    // the cat stands left of the post and pushes it
    expect(play(start(['#######', '#.....#', '#P....#', '#.....#', '#....A#', '#######'], ['r3,2,r']), []).move(r).isOk, isTrue);
    expect(s.move(r).blocked, Blocked.pivot);
  });

  group('GameController', () {
    test('undo, redo and restart', () {
      final c = GameController(allLevels.first);
      final s0 = c.state;
      final first = c.showHint()!;
      expect(c.move(first).isOk, isTrue);
      expect(c.moves, 1);
      expect(c.undo(), isTrue);
      expect(c.state.key, s0.key);
      expect(c.redo(), isTrue);
      expect(c.moves, 1);
      c.restart();
      expect(c.moves, 0);
      expect(c.canRedo, isFalse);
    });

    test('hints follow the shortest solution to the end', () {
      final c = GameController(allLevels[1]);
      while (!c.isWon) {
        final h = c.showHint();
        expect(h, isNotNull);
        c.move(h!);
      }
      expect(c.moves, allLevels[1].par);
    });

    test('a dead end is only pointed out after the player runs into it', () {
      // find a way into a dead end on the first stages
      for (final level in allLevels.take(8)) {
        final path = _pathToDeadEnd(level);
        if (path == null) continue;
        final c = GameController(level);
        for (final d in path) {
          expect(c.move(d).isOk, isTrue);
        }
        expect(c.beckonUndo, isFalse, reason: 'nothing is announced before the player runs into it');
        final blocked = Dir.values.where((d) => !c.state.move(d).isOk).toList();
        if (blocked.isEmpty) continue;
        expect(c.move(blocked.first).isOk, isFalse);
        expect(c.stuck, isTrue);
        expect(c.beckonUndo, isTrue);
        while (c.stuck && c.canUndo) {
          c.undo();
        }
        expect(c.beckonUndo, isFalse);
        return;
      }
      fail('no dead end found on the first stages');
    });
  });
}

/// Moves from the start of [level] into a position that can no longer be won.
List<Dir>? _pathToDeadEnd(Level level) {
  final solver = Solver();
  final start = level.board.initialState();
  final seen = <String>{start.key};
  final queue = <(GameState, List<Dir>)>[(start, [])];
  for (var i = 0; i < queue.length && i < 3000; i++) {
    final (s, path) = queue[i];
    if (!s.isWon && path.isNotEmpty && solver.solve(s) == null) return path;
    for (final d in Dir.values) {
      final n = s.move(d).state;
      if (n != null && seen.add(n.key)) queue.add((n, [...path, d]));
    }
  }
  return null;
}
