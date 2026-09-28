/// ふすま渡り — core rules.
///
/// Pure Dart (no Flutter imports) so that the solver, level tools and tests
/// can run on the plain Dart VM.
///
/// The cat carries the orders through an old inn. Sliding doors (fusuma)
/// stand in the way; they only move along their tracks.
///
/// Map characters:
///   `#` wall, ` ` void, `.` tatami, `P` start (the kitchen door, tatami)
///   `A`..`D` a guest (bump into them to serve; they stay put)
///   `k` the landlady's key (walk over it to take it)
///
/// Doors are listed apart from the map, one string each:
///   `h x,y,len`  a door lying left-right, `len` cells from (x, y)
///   `v x,y,len`  a door lying up-down
///   add `=a` (any letter) to pair doors: doors with the same letter move together
///   add `*` for a locked door (moves only once the key is taken)
///   `r x,y,d`    a revolving shoji: pivot at (x, y), arm towards d (u/d/l/r)
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

  bool get horizontal => dx != 0;

  static Dir fromLetter(String c) => switch (c) {
        'u' => Dir.up,
        'd' => Dir.down,
        'l' => Dir.left,
        'r' => Dir.right,
        _ => throw FormatException('bad direction $c'),
      };

  String get letter => name[0];
}

class Pos {
  const Pos(this.x, this.y);
  final int x;
  final int y;

  Pos step(Dir d, [int n = 1]) => Pos(x + d.dx * n, y + d.dy * n);

  @override
  bool operator ==(Object other) => other is Pos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 131 + y;

  @override
  String toString() => '($x,$y)';
}

class Guest {
  const Guest(this.pos, this.letter);
  final Pos pos;
  final String letter;

  /// The dish this guest ordered ('a'..'d', drawn by the dish art):
  /// the first guest in a room gets the omelette, then dango, tomato, grapes.
  String get wants => const {'A': 'c', 'B': 'b', 'C': 'a', 'D': 'd'}[letter]!;
}

enum DoorKind { slide, revolve }

/// A door as placed at the start of a stage.
class Door {
  const Door.slide({required this.pos, required this.horizontal, required this.length, this.pair, this.locked = false})
      : kind = DoorKind.slide,
        arm = Dir.right;
  const Door.revolve({required this.pos, required this.arm})
      : kind = DoorKind.revolve,
        horizontal = false,
        length = 2,
        pair = null,
        locked = false;

  final DoorKind kind;

  /// Top-left cell of a sliding door; the pivot of a revolving one.
  final Pos pos;
  final bool horizontal;
  final int length;

  /// Doors with the same pair letter move together.
  final String? pair;
  final bool locked;

  /// Where a revolving door's arm points from the pivot at the start.
  final Dir arm;

  static Door parse(String spec) {
    final kind = spec[0];
    var rest = spec.substring(1).trim();
    String? pair;
    var locked = false;
    if (rest.endsWith('*')) {
      locked = true;
      rest = rest.substring(0, rest.length - 1);
    }
    final eq = rest.indexOf('=');
    if (eq >= 0) {
      pair = rest.substring(eq + 1);
      rest = rest.substring(0, eq);
    }
    final parts = rest.split(',');
    final p = Pos(int.parse(parts[0]), int.parse(parts[1]));
    return switch (kind) {
      'h' => Door.slide(pos: p, horizontal: true, length: int.parse(parts[2]), pair: pair, locked: locked),
      'v' => Door.slide(pos: p, horizontal: false, length: int.parse(parts[2]), pair: pair, locked: locked),
      'r' => Door.revolve(pos: p, arm: Dir.fromLetter(parts[2])),
      _ => throw FormatException('bad door $spec'),
    };
  }

  String get spec => switch (kind) {
        DoorKind.slide => '${horizontal ? 'h' : 'v'}${pos.x},${pos.y},$length${pair != null ? '=$pair' : ''}${locked ? '*' : ''}',
        DoorKind.revolve => 'r${pos.x},${pos.y},${arm.letter}',
      };
}

/// Where a door is now: a sliding door's top-left cell, or a revolving
/// door's arm direction (its pivot never moves).
class DoorAt {
  const DoorAt(this.pos, this.arm);
  final Pos pos;
  final Dir arm;

  @override
  bool operator ==(Object other) => other is DoorAt && other.pos == pos && other.arm == arm;

  @override
  int get hashCode => pos.hashCode * 7 + arm.index;
}

/// Static part of a level: everything that never changes during play.
class Board {
  Board._({
    required this.width,
    required this.height,
    required this.grid,
    required this.start,
    required this.guests,
    required this.key,
    required this.doors,
  });

  factory Board.parse(List<String> rows, List<String> doorSpecs) {
    final h = rows.length;
    final w = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final grid = [for (final r in rows) r.padRight(w).split('')];
    Pos? start;
    Pos? key;
    final guests = <Guest>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = grid[y][x];
        final p = Pos(x, y);
        if (c == 'P') start = p;
        if (c == 'k') key = p;
        if (_isGuest(c)) guests.add(Guest(p, c));
      }
    }
    if (start == null) throw const FormatException('map has no start P');
    if (guests.isEmpty) throw const FormatException('map has no guests');
    return Board._(
      width: w,
      height: h,
      grid: grid,
      start: start,
      guests: guests,
      key: key,
      doors: [for (final s in doorSpecs) Door.parse(s)],
    );
  }

  static bool _isGuest(String c) => c.compareTo('A') >= 0 && c.compareTo('D') <= 0;

  final int width;
  final int height;
  final List<List<String>> grid;
  final Pos start;
  final List<Guest> guests;
  final Pos? key;
  final List<Door> doors;

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  String at(int x, int y) => inside(x, y) ? grid[y][x] : ' ';

  bool isWall(int x, int y) {
    final c = at(x, y);
    return c == '#' || c == ' ';
  }

  int guestAt(int x, int y) => guests.indexWhere((g) => g.pos.x == x && g.pos.y == y);

  /// Floor a door may slide or swing onto: plain tatami or the start.
  bool doorFloor(int x, int y) {
    final c = at(x, y);
    return c == '.' || c == 'P';
  }

  bool get hasLocks => doors.any((d) => d.locked);

  GameState initialState() => GameState(
        board: this,
        pos: start,
        doors: [for (final d in doors) DoorAt(d.pos, d.arm)],
        served: 0,
        hasKey: key == null,
        moves: 0,
        facing: Dir.right,
      );
}

/// Why a move was refused. Used for feedback (a shake, a wobble).
enum Blocked {
  wall,

  /// Pushed a sliding door across its track.
  across,

  /// The door (or its pair) has no room to slide or swing.
  jammed,

  /// A locked door, and no key yet.
  locked,

  /// Pushed a revolving door at its pivot or along its arm.
  pivot,
  alreadyServed,
  finished,
}

sealed class MoveEvent {
  const MoveEvent();
}

class Walked extends MoveEvent {
  const Walked();
}

class Slid extends MoveEvent {
  const Slid(this.doors, this.dir);
  final List<int> doors;
  final Dir dir;
}

class Swung extends MoveEvent {
  const Swung(this.door, this.from, this.to);
  final int door;
  final Dir from;
  final Dir to;
}

class Served extends MoveEvent {
  const Served(this.guestIndex);
  final int guestIndex;
}

class KeyTaken extends MoveEvent {
  const KeyTaken();
}

class MoveResult {
  const MoveResult.ok(GameState this.state, this.events)
      : blocked = null,
        door = null;
  const MoveResult.blocked(Blocked this.blocked, {this.door})
      : state = null,
        events = const [];

  final GameState? state;
  final List<MoveEvent> events;
  final Blocked? blocked;

  /// The door that refused to move, if one did.
  final int? door;

  bool get isOk => state != null;
}

class GameState {
  const GameState({
    required this.board,
    required this.pos,
    required this.doors,
    required this.served,
    required this.hasKey,
    required this.moves,
    required this.facing,
  });

  final Board board;
  final Pos pos;
  final List<DoorAt> doors;

  /// Bitmask of served guests (index into [Board.guests]).
  final int served;
  final bool hasKey;
  final int moves;
  final Dir facing;

  bool get isWon => served == (1 << board.guests.length) - 1;

  bool isServed(int guestIndex) => served & (1 << guestIndex) != 0;

  int get servedCount {
    var n = 0;
    for (var v = served; v != 0; v &= v - 1) {
      n++;
    }
    return n;
  }

  /// The cells a door covers now.
  List<Pos> cells(int i) {
    final d = board.doors[i], at = doors[i];
    if (d.kind == DoorKind.revolve) return [d.pos, d.pos.step(at.arm)];
    return [for (var k = 0; k < d.length; k++) Pos(at.pos.x + (d.horizontal ? k : 0), at.pos.y + (d.horizontal ? 0 : k))];
  }

  int doorAt(Pos p, {Set<int> skip = const {}}) {
    for (var i = 0; i < doors.length; i++) {
      if (skip.contains(i)) continue;
      if (cells(i).contains(p)) return i;
    }
    return -1;
  }

  /// Identity of the position for search (ignores move count and facing).
  String get key {
    final b = StringBuffer('${pos.x},${pos.y}|$served|${hasKey ? 1 : 0}|');
    for (final d in doors) {
      b
        ..write(d.pos.x)
        ..write(',')
        ..write(d.pos.y)
        ..write(d.arm.index)
        ..write(';');
    }
    return b.toString();
  }

  GameState _copy({Pos? pos, List<DoorAt>? doors, int? served, bool? hasKey, required Dir facing}) => GameState(
        board: board,
        pos: pos ?? this.pos,
        doors: doors ?? this.doors,
        served: served ?? this.served,
        hasKey: hasKey ?? this.hasKey,
        moves: moves + 1,
        facing: facing,
      );

  /// Can a door slide or swing onto [p]? (No wall, guest, key, cat or other door.)
  bool _free(Pos p, Set<int> moving) {
    if (!board.doorFloor(p.x, p.y)) return false;
    if (p == pos) return false;
    return doorAt(p, skip: moving) < 0;
  }

  MoveResult move(Dir d) {
    if (isWon) return const MoveResult.blocked(Blocked.finished);
    final next = pos.step(d);
    if (board.isWall(next.x, next.y)) return const MoveResult.blocked(Blocked.wall);

    final gi = board.guestAt(next.x, next.y);
    if (gi >= 0) {
      if (isServed(gi)) return const MoveResult.blocked(Blocked.alreadyServed);
      return MoveResult.ok(_copy(served: served | (1 << gi), facing: d), [Served(gi)]);
    }

    final di = doorAt(next);
    if (di < 0) {
      final taking = !hasKey && board.key == next;
      return MoveResult.ok(
        _copy(pos: next, hasKey: taking ? true : null, facing: d),
        [const Walked(), if (taking) const KeyTaken()],
      );
    }

    final door = board.doors[di];
    if (door.kind == DoorKind.revolve) return _swing(di, d, next);

    if (door.horizontal != d.horizontal) return MoveResult.blocked(Blocked.across, door: di);
    if (door.locked && !hasKey) return MoveResult.blocked(Blocked.locked, door: di);
    final moving = <int>{
      for (var i = 0; i < board.doors.length; i++)
        if (i == di || (door.pair != null && board.doors[i].pair == door.pair)) i,
    };
    for (final i in moving) {
      final other = board.doors[i];
      if (other.kind != DoorKind.slide || other.horizontal != door.horizontal) return MoveResult.blocked(Blocked.jammed, door: di);
      if (other.locked && !hasKey) return MoveResult.blocked(Blocked.locked, door: i);
      for (final c in cells(i)) {
        final to = c.step(d);
        if (cells(i).contains(to)) continue;
        if (!_free(to, moving)) return MoveResult.blocked(Blocked.jammed, door: di);
      }
    }
    final newDoors = [
      for (var i = 0; i < doors.length; i++) moving.contains(i) ? DoorAt(doors[i].pos.step(d), doors[i].arm) : doors[i],
    ];
    return MoveResult.ok(
      _copy(pos: next, doors: newDoors, facing: d),
      [const Walked(), Slid(moving.toList()..sort(), d)],
    );
  }

  /// Pushing a revolving door's arm sideways swings it a quarter turn
  /// about the pivot, sweeping the corner between the old and new arm.
  MoveResult _swing(int di, Dir d, Pos next) {
    final door = board.doors[di];
    final arm = doors[di].arm;
    if (next == door.pos || d == arm || d == arm.opposite) return MoveResult.blocked(Blocked.pivot, door: di);
    final to = door.pos.step(d);
    final corner = door.pos.step(arm).step(d);
    if (!_free(to, {di}) || !_free(corner, {di})) return MoveResult.blocked(Blocked.jammed, door: di);
    final newDoors = [for (var i = 0; i < doors.length; i++) i == di ? DoorAt(doors[i].pos, d) : doors[i]];
    return MoveResult.ok(
      _copy(pos: next, doors: newDoors, facing: d),
      [const Walked(), Swung(di, arm, d)],
    );
  }
}
