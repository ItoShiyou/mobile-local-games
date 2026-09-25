/// つみあげ出前 — core rules.
///
/// Pure Dart (no Flutter imports) so that the solver, level tools and tests
/// can run on the plain Dart VM.
///
/// Map characters:
///   `#` wall, ` ` void, `.` floor, `P` start (floor)
///   `a`..`d` dish on floor (colour a..d)
///   `A`..`D` guest who wants the dish of the same letter (acts as a wall)
///   `T` return counter: bump into it to hand over the top dish (one use)
///   `s` flip tray: stepping on it reverses the stack
///   `<` `>` `^` `v` one-way floor: can only be entered moving that way
library;

enum Dir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;

  Dir get opposite => switch (this) {
        Dir.up => Dir.down,
        Dir.down => Dir.up,
        Dir.left => Dir.right,
        Dir.right => Dir.left,
      };
}

const Map<String, Dir> arrowDirs = {
  '<': Dir.left,
  '>': Dir.right,
  '^': Dir.up,
  'v': Dir.down,
};

class Pos {
  const Pos(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is Pos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 131 + y;

  @override
  String toString() => '($x,$y)';
}

class Dish {
  const Dish(this.pos, this.color);
  final Pos pos;
  final String color;
}

class Guest {
  const Guest(this.pos, this.wants);
  final Pos pos;
  final String wants;
}

/// Static part of a level: everything that never changes during play.
class Board {
  Board._({
    required this.width,
    required this.height,
    required this.grid,
    required this.start,
    required this.dishes,
    required this.guests,
    required this.counters,
    required this.capacity,
  });

  factory Board.parse(List<String> rows, {int capacity = 3}) {
    final h = rows.length;
    final w = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final grid = [for (final r in rows) r.padRight(w).split('')];
    Pos? start;
    final dishes = <Dish>[];
    final guests = <Guest>[];
    final counters = <Pos>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = grid[y][x];
        final p = Pos(x, y);
        if (c == 'P') {
          start = p;
        } else if (_isDish(c)) {
          dishes.add(Dish(p, c));
        } else if (_isGuest(c)) {
          guests.add(Guest(p, c.toLowerCase()));
        } else if (c == 'T') {
          counters.add(p);
        }
      }
    }
    if (start == null) throw const FormatException('map has no start P');
    if (guests.isEmpty) throw const FormatException('map has no guests');
    return Board._(
      width: w,
      height: h,
      grid: grid,
      start: start,
      dishes: dishes,
      guests: guests,
      counters: counters,
      capacity: capacity,
    );
  }

  static bool _isDish(String c) => c.compareTo('a') >= 0 && c.compareTo('d') <= 0;
  static bool _isGuest(String c) => c.compareTo('A') >= 0 && c.compareTo('D') <= 0;

  final int width;
  final int height;
  final List<List<String>> grid;
  final Pos start;
  final List<Dish> dishes;
  final List<Guest> guests;
  final List<Pos> counters;
  final int capacity;

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  String at(int x, int y) => inside(x, y) ? grid[y][x] : ' ';

  bool isWall(int x, int y) {
    final c = at(x, y);
    return c == '#' || c == ' ';
  }

  int guestAt(int x, int y) => guests.indexWhere((g) => g.pos.x == x && g.pos.y == y);
  int dishAt(int x, int y) => dishes.indexWhere((d) => d.pos.x == x && d.pos.y == y);
  int counterAt(int x, int y) => counters.indexWhere((p) => p.x == x && p.y == y);

  GameState initialState() => GameState(
        board: this,
        pos: start,
        stack: const [],
        taken: 0,
        served: 0,
        used: 0,
        moves: 0,
        facing: Dir.down,
      );
}

/// Why a move was refused. Used for feedback (shake + a short message).
enum Blocked {
  wall,
  oneWay,
  full,
  wrongDish,
  emptyHands,
  alreadyServed,
  counterUsed,
  finished,
}

sealed class MoveEvent {
  const MoveEvent();
}

class Walked extends MoveEvent {
  const Walked();
}

class PickedUp extends MoveEvent {
  const PickedUp(this.dishIndex, this.color);
  final int dishIndex;
  final String color;
}

class Served extends MoveEvent {
  const Served(this.guestIndex, this.color);
  final int guestIndex;
  final String color;
}

class Returned extends MoveEvent {
  const Returned(this.counterIndex, this.color);
  final int counterIndex;
  final String color;
}

class Flipped extends MoveEvent {
  const Flipped();
}

class MoveResult {
  const MoveResult.ok(GameState this.state, this.events) : blocked = null;
  const MoveResult.blocked(Blocked this.blocked)
      : state = null,
        events = const [];

  final GameState? state;
  final List<MoveEvent> events;
  final Blocked? blocked;

  bool get isOk => state != null;
}

class GameState {
  const GameState({
    required this.board,
    required this.pos,
    required this.stack,
    required this.taken,
    required this.served,
    required this.used,
    required this.moves,
    required this.facing,
  });

  final Board board;
  final Pos pos;

  /// Bottom first; `stack.last` is the dish on top.
  final List<String> stack;

  /// Bitmask of picked-up dishes (index into [Board.dishes]).
  final int taken;

  /// Bitmask of served guests (index into [Board.guests]).
  final int served;

  /// Bitmask of used return counters (index into [Board.counters]).
  final int used;
  final int moves;
  final Dir facing;

  bool get isWon => served == (1 << board.guests.length) - 1;

  int get servedCount => _popCount(served);

  String? get top => stack.isEmpty ? null : stack.last;

  bool isTaken(int dishIndex) => taken & (1 << dishIndex) != 0;
  bool isServed(int guestIndex) => served & (1 << guestIndex) != 0;
  bool isUsed(int counterIndex) => used & (1 << counterIndex) != 0;

  /// Identity of the position for search (ignores move count and facing).
  String get key => '${pos.x},${pos.y}|${stack.join()}|$taken|$served|$used';

  GameState _copy({
    Pos? pos,
    List<String>? stack,
    int? taken,
    int? served,
    int? used,
    required Dir facing,
  }) =>
      GameState(
        board: board,
        pos: pos ?? this.pos,
        stack: stack ?? this.stack,
        taken: taken ?? this.taken,
        served: served ?? this.served,
        used: used ?? this.used,
        moves: moves + 1,
        facing: facing,
      );

  MoveResult move(Dir d) {
    if (isWon) return const MoveResult.blocked(Blocked.finished);
    final nx = pos.x + d.dx;
    final ny = pos.y + d.dy;
    if (board.isWall(nx, ny)) return const MoveResult.blocked(Blocked.wall);

    final gi = board.guestAt(nx, ny);
    if (gi >= 0) {
      if (isServed(gi)) return const MoveResult.blocked(Blocked.alreadyServed);
      if (stack.isEmpty) return const MoveResult.blocked(Blocked.emptyHands);
      if (stack.last != board.guests[gi].wants) {
        return const MoveResult.blocked(Blocked.wrongDish);
      }
      return MoveResult.ok(
        _copy(
          stack: stack.sublist(0, stack.length - 1),
          served: served | (1 << gi),
          facing: d,
        ),
        [Served(gi, stack.last)],
      );
    }

    final ci = board.counterAt(nx, ny);
    if (ci >= 0) {
      if (isUsed(ci)) return const MoveResult.blocked(Blocked.counterUsed);
      if (stack.isEmpty) return const MoveResult.blocked(Blocked.emptyHands);
      return MoveResult.ok(
        _copy(
          stack: stack.sublist(0, stack.length - 1),
          used: used | (1 << ci),
          facing: d,
        ),
        [Returned(ci, stack.last)],
      );
    }

    final c = board.at(nx, ny);
    final arrow = arrowDirs[c];
    if (arrow != null && arrow != d) return const MoveResult.blocked(Blocked.oneWay);

    var newStack = stack;
    var newTaken = taken;
    final events = <MoveEvent>[const Walked()];
    final di = board.dishAt(nx, ny);
    if (di >= 0 && !isTaken(di)) {
      if (stack.length >= board.capacity) return const MoveResult.blocked(Blocked.full);
      newStack = [...stack, board.dishes[di].color];
      newTaken |= 1 << di;
      events.add(PickedUp(di, board.dishes[di].color));
    }
    if (c == 's' && newStack.length > 1) {
      newStack = newStack.reversed.toList(growable: false);
      events.add(const Flipped());
    }
    return MoveResult.ok(
      _copy(pos: Pos(nx, ny), stack: newStack, taken: newTaken, facing: d),
      events,
    );
  }
}

int _popCount(int v) {
  var n = 0;
  while (v != 0) {
    v &= v - 1;
    n++;
  }
  return n;
}
