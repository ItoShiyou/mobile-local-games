/// だし回し — core rules.
///
/// Pure Dart (no Flutter imports) so that the solver, level tools and tests
/// can run on the plain Dart VM.
///
/// A board of bamboo pipes. Tap a pipe to turn it a quarter turn clockwise.
/// Stock runs from the pots through every pipe it is joined to; stocks
/// that meet mix (katsuo + kombu = awase). The stage is done when every
/// pipe is joined up with no open end, and every bowl gets exactly the
/// stock it asks for.
///
/// Map characters (one per cell):
///   `#` wall, `.` empty floor (no pipe)
///   `I` straight, `L` corner, `T` three-way, `X` crossing (two separate
///       pipes, one over the other: up-down never mixes with left-right)
///   `P` a stock pot, `B` a bowl (listed in [Board.parse]'s `pots`/`bowls`)
/// A pipe may be iron (`fixed`): it does not turn.
library;

enum Dir {
  up(0, -1, 1),
  right(1, 0, 2),
  down(0, 1, 4),
  left(-1, 0, 8);

  const Dir(this.dx, this.dy, this.bit);
  final int dx;
  final int dy;

  /// This side's bit in an opening mask.
  final int bit;

  Dir get opposite => switch (this) {
        Dir.up => Dir.down,
        Dir.down => Dir.up,
        Dir.left => Dir.right,
        Dir.right => Dir.left,
      };

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

  Pos step(Dir d) => Pos(x + d.dx, y + d.dy);

  @override
  bool operator ==(Object other) => other is Pos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 131 + y;

  @override
  String toString() => '($x,$y)';
}

/// Openings of each pipe at rotation 0 (bits: up 1, right 2, down 4, left 8).
const Map<String, int> baseMask = {'I': 5, 'L': 3, 'T': 14, 'X': 15};

/// Turns an opening mask a quarter turn clockwise [r] times.
int turn(int mask, int r) {
  var m = mask;
  for (var i = 0; i < r % 4; i++) {
    m = ((m << 1) | (m >> 3)) & 15;
  }
  return m;
}

/// How many different ways a pipe can face (a straight has 2, a crossing 1).
int facings(String kind) => switch (kind) { 'I' => 2, 'X' => 1, _ => 4 };

/// Stocks, and what a bowl can ask for.
const stocks = ['k', 'n', 's'];

String mix(Iterable<String> flavours) => (flavours.toSet().toList()..sort()).join();

class Pot {
  const Pot(this.pos, this.stock, this.dir);
  final Pos pos;

  /// `k` katsuo, `n` kombu, `s` shiitake.
  final String stock;
  final Dir dir;
}

class Bowl {
  const Bowl(this.pos, this.want, this.dir);
  final Pos pos;

  /// The stocks this bowl wants, sorted (`k`, `kn`, …).
  final String want;
  final Dir dir;
}

/// Static part of a level.
class Board {
  Board._({
    required this.width,
    required this.height,
    required this.grid,
    required this.start,
    required this.fixed,
    required this.pots,
    required this.bowls,
  });

  /// [rot] has one digit (0-3) per cell, quarter turns from the base shape.
  /// Pots and bowls: `'k 2,0 d'` = katsuo pot at (2,0) opening downwards;
  /// `'kn 4,5 u'` = a bowl wanting awase at (4,5) opening upwards.
  factory Board.parse(List<String> rows, List<String> rot, {List<String> fixed = const [], required List<String> pots, required List<String> bowls}) {
    final h = rows.length;
    final w = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final grid = [for (final r in rows) r.padRight(w, '#').split('')];
    final start = <int>[
      for (var y = 0; y < h; y++)
        for (var x = 0; x < w; x++) y < rot.length && x < rot[y].length ? int.parse(rot[y][x]) : 0,
    ];
    (Pos, Dir) spec(String s) {
      final p = s.split(' ');
      final xy = p[1].split(',');
      return (Pos(int.parse(xy[0]), int.parse(xy[1])), Dir.fromLetter(p[2]));
    }

    final potList = [for (final s in pots) (s.split(' ')[0], spec(s))].map((e) => Pot(e.$2.$1, e.$1, e.$2.$2)).toList();
    final bowlList = [for (final s in bowls) (mix(s.split(' ')[0].split('')), spec(s))].map((e) => Bowl(e.$2.$1, e.$1, e.$2.$2)).toList();
    for (final p in potList) {
      if (grid[p.pos.y][p.pos.x] != 'P') throw FormatException('pot not on P at ${p.pos}');
    }
    for (final b in bowlList) {
      if (grid[b.pos.y][b.pos.x] != 'B') throw FormatException('bowl not on B at ${b.pos}');
    }
    if (potList.isEmpty || bowlList.isEmpty) throw const FormatException('needs pots and bowls');
    final fixedSet = <Pos>{
      for (final f in fixed) Pos(int.parse(f.split(',')[0]), int.parse(f.split(',')[1])),
    };
    return Board._(width: w, height: h, grid: grid, start: start, fixed: fixedSet, pots: potList, bowls: bowlList);
  }

  final int width;
  final int height;
  final List<List<String>> grid;

  /// Starting rotation of every cell, row by row.
  final List<int> start;
  final Set<Pos> fixed;
  final List<Pot> pots;
  final List<Bowl> bowls;

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;
  String at(int x, int y) => inside(x, y) ? grid[y][x] : '#';
  int index(int x, int y) => y * width + x;

  bool isPipe(int x, int y) => baseMask.containsKey(at(x, y));

  /// Can this cell be turned by the player?
  bool turnable(int x, int y) => isPipe(x, y) && !fixed.contains(Pos(x, y)) && facings(at(x, y)) > 1;

  Pot? potAt(int x, int y) {
    for (final p in pots) {
      if (p.pos.x == x && p.pos.y == y) return p;
    }
    return null;
  }

  Bowl? bowlAt(int x, int y) {
    for (final b in bowls) {
      if (b.pos.x == x && b.pos.y == y) return b;
    }
    return null;
  }

  /// Openings of a cell with rotation [r].
  int maskAt(int x, int y, int r) {
    final c = at(x, y);
    if (c == 'P') return potAt(x, y)!.dir.bit;
    if (c == 'B') return bowlAt(x, y)!.dir.bit;
    final b = baseMask[c];
    return b == null ? 0 : turn(b, r);
  }

  /// A crossing keeps its up-down pipe (channel 0) apart from its
  /// left-right one (channel 1); every other cell is one channel.
  int channel(int x, int y, Dir side) => at(x, y) == 'X' && (side == Dir.left || side == Dir.right) ? 1 : 0;

  GameState initialState() => GameState(board: this, rot: List.unmodifiable(start), taps: 0);
}

/// Where the stock goes on the current board.
class StockFlow {
  StockFlow._(this._carry, this._spill, this.bowls, this.allJoined, this.won);

  final Map<int, String> _carry;
  final Set<int> _spill;

  /// What each bowl is getting (sorted stock letters, '' for nothing).
  final List<String> bowls;

  /// Every pipe opening meets another opening.
  final bool allJoined;
  final bool won;

  static int _node(Board b, int x, int y, int ch) => (b.index(x, y) << 1) | ch;

  /// Stocks flowing through a cell's channel ('' when dry).
  String carry(Board b, int x, int y, int ch) => _carry[_node(b, x, y, ch)] ?? '';

  /// Is stock leaking out of this opening?
  bool spills(Board b, int x, int y, Dir side) => _spill.contains((_node(b, x, y, b.channel(x, y, side)) << 2) | side.index);

  static StockFlow of(Board b, List<int> rot) {
    final parent = <int, int>{};
    int find(int a) {
      var r = a;
      while (parent[r] != r) {
        r = parent[r]!;
      }
      var c = a;
      while (parent[c] != r) {
        final n = parent[c]!;
        parent[c] = r;
        c = n;
      }
      return r;
    }

    int node(int x, int y, int ch) {
      final k = _node(b, x, y, ch);
      parent.putIfAbsent(k, () => k);
      return k;
    }

    final open = <(int, int)>[]; // (node, side) with nothing to meet
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        final m = b.maskAt(x, y, rot[b.index(x, y)]);
        if (m == 0) continue;
        for (final d in Dir.values) {
          if (m & d.bit == 0) continue;
          final a = node(x, y, b.channel(x, y, d));
          final nx = x + d.dx, ny = y + d.dy;
          final nm = b.inside(nx, ny) ? b.maskAt(nx, ny, rot[b.index(nx, ny)]) : 0;
          if (nm & d.opposite.bit != 0) {
            final c = node(nx, ny, b.channel(nx, ny, d.opposite));
            parent[find(a)] = find(c);
          } else {
            open.add((a, d.index));
          }
        }
      }
    }
    final flavours = <int, Set<String>>{};
    for (final p in b.pots) {
      flavours.putIfAbsent(find(node(p.pos.x, p.pos.y, 0)), () => {}).add(p.stock);
    }
    final carry = <int, String>{};
    for (final k in parent.keys) {
      final f = flavours[find(k)];
      if (f != null) carry[k] = mix(f);
    }
    final spill = <int>{
      for (final (n, side) in open)
        if (carry.containsKey(n)) (n << 2) | side,
    };
    final bowls = [for (final w in b.bowls) carry[_node(b, w.pos.x, w.pos.y, 0)] ?? ''];
    final joined = open.isEmpty;
    // every pipe carries stock (no dry loops), and each bowl gets its order
    var allWet = true;
    for (final k in parent.keys) {
      if (!carry.containsKey(k)) allWet = false;
    }
    var bowlsOk = true;
    for (var i = 0; i < b.bowls.length; i++) {
      if (bowls[i] != b.bowls[i].want) bowlsOk = false;
    }
    return StockFlow._(carry, spill, bowls, joined, joined && allWet && bowlsOk);
  }
}

/// Why a tap did nothing.
enum Blocked { notPipe, iron, finished }

class MoveResult {
  const MoveResult.ok(GameState this.state, this.cell)
      : blocked = null;
  const MoveResult.blocked(Blocked this.blocked, this.cell) : state = null;

  final GameState? state;
  final Pos cell;
  final Blocked? blocked;

  bool get isOk => state != null;
}

class GameState {
  const GameState({required this.board, required this.rot, required this.taps});

  final Board board;

  /// Rotation of every cell, row by row.
  final List<int> rot;
  final int taps;

  int rotAt(int x, int y) => rot[board.index(x, y)];
  int maskAt(int x, int y) => board.maskAt(x, y, rotAt(x, y));

  StockFlow get flow => StockFlow.of(board, rot);
  bool get isWon => flow.won;

  String get key => rot.join();

  MoveResult tap(int x, int y) {
    final p = Pos(x, y);
    if (!board.isPipe(x, y)) return MoveResult.blocked(Blocked.notPipe, p);
    if (!board.turnable(x, y)) return MoveResult.blocked(Blocked.iron, p);
    if (isWon) return MoveResult.blocked(Blocked.finished, p);
    final i = board.index(x, y);
    final next = [...rot];
    next[i] = (next[i] + 1) % 4;
    return MoveResult.ok(GameState(board: board, rot: List.unmodifiable(next), taps: taps + 1), p);
  }
}
