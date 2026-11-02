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
///   `E`..`H` cat-tongued guest who wants dish a..d, but only once it has
///       cooled down: a dish steams for [coolSteps] steps after pick-up
///   `W` shared table: wants two dishes at once, in the order given by the
///       level's `orders` (`'ab'`: a on top, b right below it)
///   `=` cart: walk into it and it slides until something stops it
///   `w`..`z` cart loaded with dish a..d: slid into a guest who wants that
///       dish, it serves them
library;

/// Steps a freshly picked-up dish needs before a cat-tongued guest takes it.
const coolSteps = 3;

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
  const Guest(this.pos, this.wants, {this.catTongue = false});
  final Pos pos;

  /// The dish this guest wants; two letters for a shared table (top first).
  final String wants;

  /// Takes the dish only once it has stopped steaming.
  final bool catTongue;

  bool get shared => wants.length == 2;
}

class Cart {
  const Cart(this.pos, this.load);
  final Pos pos;

  /// The dish riding on the cart, if any.
  final String? load;
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
    required this.carts,
    required this.capacity,
  });

  /// [orders]: what each shared table (`W`, in reading order) wants.
  factory Board.parse(List<String> rows, {int capacity = 3, List<String> orders = const []}) {
    final h = rows.length;
    final w = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final grid = [for (final r in rows) r.padRight(w).split('')];
    Pos? start;
    final dishes = <Dish>[];
    final guests = <Guest>[];
    final counters = <Pos>[];
    final carts = <Cart>[];
    var tables = 0;
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
        } else if (_isCatTongue(c)) {
          guests.add(Guest(p, String.fromCharCode(c.codeUnitAt(0) - 4).toLowerCase(), catTongue: true));
        } else if (c == 'W') {
          if (tables >= orders.length || orders[tables].length != 2) {
            throw FormatException('shared table ${tables + 1} has no two-dish order');
          }
          guests.add(Guest(p, orders[tables++]));
        } else if (c == 'T') {
          counters.add(p);
        } else if (c == '=') {
          carts.add(Cart(p, null));
        } else if (_isCartDish(c)) {
          carts.add(Cart(p, String.fromCharCode(c.codeUnitAt(0) - 22)));
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
      carts: carts,
      capacity: capacity,
    );
  }

  static bool _isDish(String c) => c.compareTo('a') >= 0 && c.compareTo('d') <= 0;
  static bool _isGuest(String c) => c.compareTo('A') >= 0 && c.compareTo('D') <= 0;
  static bool _isCatTongue(String c) => c.compareTo('E') >= 0 && c.compareTo('H') <= 0;
  static bool _isCartDish(String c) => c.compareTo('w') >= 0 && c.compareTo('z') <= 0;

  final int width;
  final int height;
  final List<List<String>> grid;
  final Pos start;
  final List<Dish> dishes;
  final List<Guest> guests;
  final List<Pos> counters;
  final List<Cart> carts;
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

  /// Floor that never holds anything by itself (carts start on floor too).
  bool isFloorLike(int x, int y) {
    final c = at(x, y);
    return c == '.' || c == 'P' || c == 's' || c == '=' || arrowDirs.containsKey(c) || _isDish(c) || _isCartDish(c);
  }

  int _loadedMask() {
    var m = 0;
    for (var i = 0; i < carts.length; i++) {
      if (carts[i].load != null) m |= 1 << i;
    }
    return m;
  }

  GameState initialState() => GameState(
        board: this,
        pos: start,
        stack: const [],
        heat: const [],
        carts: [for (final c in carts) c.pos],
        loaded: _loadedMask(),
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

  /// A cat-tongued guest: the top dish is still steaming.
  tooHot,

  /// A cart with something right behind it.
  cartStuck,
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
  const Served(this.guestIndex, this.color, [this.under]);
  final int guestIndex;
  final String color;

  /// The second dish handed to a shared table (it was right below [color]).
  final String? under;
}

/// A cart slid from [from] to [to]; [served] is the guest it delivered to.
class Pushed extends MoveEvent {
  const Pushed(this.cartIndex, this.from, this.to, {this.served});
  final int cartIndex;
  final Pos from, to;
  final int? served;
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
    required this.heat,
    required this.carts,
    required this.loaded,
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

  /// Steps each dish in [stack] will still steam for (0 = cool).
  final List<int> heat;

  /// Where each cart (see [Board.carts]) is now.
  final List<Pos> carts;

  /// Bitmask of carts still carrying their dish.
  final int loaded;

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
  bool isLoaded(int cartIndex) => loaded & (1 << cartIndex) != 0;

  int cartAt(int x, int y) {
    for (var i = 0; i < carts.length; i++) {
      if (carts[i].x == x && carts[i].y == y) return i;
    }
    return -1;
  }

  /// Identity of the position for search (ignores move count and facing).
  String get key => '${pos.x},${pos.y}|${stack.join()}|${heat.join()}|$taken|$served|$used|${carts.map((c) => '${c.x}.${c.y}').join(':')}|$loaded';

  GameState _copy({
    Pos? pos,
    List<String>? stack,
    List<int>? heat,
    List<Pos>? carts,
    int? loaded,
    int? taken,
    int? served,
    int? used,
    required Dir facing,
  }) =>
      GameState(
        board: board,
        pos: pos ?? this.pos,
        stack: stack ?? this.stack,
        heat: heat ?? this.heat,
        carts: carts ?? this.carts,
        loaded: loaded ?? this.loaded,
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
      final g = board.guests[gi];
      final n = g.shared ? 2 : 1;
      final len = stack.length;
      if (stack.last != g.wants[0] || (g.shared && (len < 2 || stack[len - 2] != g.wants[1]))) {
        return const MoveResult.blocked(Blocked.wrongDish);
      }
      if (g.catTongue && heat.last > 0) return const MoveResult.blocked(Blocked.tooHot);
      return MoveResult.ok(
        _copy(
          stack: stack.sublist(0, len - n),
          heat: heat.sublist(0, len - n),
          served: served | (1 << gi),
          facing: d,
        ),
        [Served(gi, stack.last, g.shared ? stack[len - 2] : null)],
      );
    }

    final ki = cartAt(nx, ny);
    if (ki >= 0) return _push(ki, d);

    final ci = board.counterAt(nx, ny);
    if (ci >= 0) {
      if (isUsed(ci)) return const MoveResult.blocked(Blocked.counterUsed);
      if (stack.isEmpty) return const MoveResult.blocked(Blocked.emptyHands);
      return MoveResult.ok(
        _copy(
          stack: stack.sublist(0, stack.length - 1),
          heat: heat.sublist(0, heat.length - 1),
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
    // every step cools what the cat carries
    var newHeat = [for (final h in heat) h > 0 ? h - 1 : 0];
    var newTaken = taken;
    final events = <MoveEvent>[const Walked()];
    final di = board.dishAt(nx, ny);
    if (di >= 0 && !isTaken(di)) {
      if (stack.length >= board.capacity) return const MoveResult.blocked(Blocked.full);
      newStack = [...stack, board.dishes[di].color];
      newHeat = [...newHeat, coolSteps];
      newTaken |= 1 << di;
      events.add(PickedUp(di, board.dishes[di].color));
    }
    if (c == 's' && newStack.length > 1) {
      newStack = newStack.reversed.toList(growable: false);
      newHeat = newHeat.reversed.toList(growable: false);
      events.add(const Flipped());
    }
    return MoveResult.ok(
      _copy(pos: Pos(nx, ny), stack: newStack, heat: List.unmodifiable(newHeat), taken: newTaken, facing: d),
      events,
    );
  }

  /// Can a sliding cart move onto (x, y) going [d]?
  bool _cartCanEnter(int x, int y, Dir d) {
    if (!board.isFloorLike(x, y)) return false;
    if (x == pos.x && y == pos.y) return false;
    if (cartAt(x, y) >= 0) return false;
    final di = board.dishAt(x, y);
    if (di >= 0 && !isTaken(di)) return false;
    final arrow = arrowDirs[board.at(x, y)];
    return arrow == null || arrow == d;
  }

  /// The cat stays put; the cart slides until something stops it. A loaded
  /// cart that runs into a guest waiting for its dish serves them.
  MoveResult _push(int ki, Dir d) {
    final from = carts[ki];
    var at = from;
    while (_cartCanEnter(at.x + d.dx, at.y + d.dy, d)) {
      at = Pos(at.x + d.dx, at.y + d.dy);
    }
    int? servedGuest;
    final gi = board.guestAt(at.x + d.dx, at.y + d.dy);
    if (gi >= 0 && isLoaded(ki) && !isServed(gi)) {
      final g = board.guests[gi];
      if (!g.shared && g.wants == board.carts[ki].load) servedGuest = gi;
    }
    if (at == from && servedGuest == null) return const MoveResult.blocked(Blocked.cartStuck);
    final newCarts = [...carts];
    newCarts[ki] = at;
    return MoveResult.ok(
      _copy(
        carts: List.unmodifiable(newCarts),
        loaded: servedGuest == null ? loaded : loaded & ~(1 << ki),
        served: servedGuest == null ? served : served | (1 << servedGuest),
        facing: d,
      ),
      [Pushed(ki, from, at, served: servedGuest)],
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
