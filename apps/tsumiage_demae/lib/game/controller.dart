import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'levels.dart';
import 'solver.dart';

/// The most recent state change, for the board to animate.
class Transition {
  const Transition({
    required this.serial,
    required this.from,
    required this.to,
    this.dir,
    this.events = const [],
    this.isUndo = false,
  });

  final int serial;
  final GameState from;
  final GameState to;
  final Dir? dir;
  final List<MoveEvent> events;
  final bool isUndo;
}

class Bump {
  const Bump(this.serial, this.dir, this.reason, {this.wanted});
  final int serial;
  final Dir dir;
  final Blocked reason;
  final String? wanted;
}

/// Play session for one stage: history with undo/redo, hints and
/// dead-end detection.
class GameController extends ChangeNotifier {
  GameController(this.level) : board = level.board {
    _history = [board.initialState()];
  }

  final Level level;
  final Board board;
  final Solver _solver = Solver();

  late List<GameState> _history;
  int _cursor = 0;
  int _serial = 0;
  Transition? _transition;
  Bump? _bump;
  Dir? _hint;
  bool _stuck = false;
  bool _noticed = false;
  int hintsUsed = 0;

  GameState get state => _history[_cursor];
  Transition? get transition => _transition;
  Bump? get bump => _bump;
  Dir? get hint => _hint;
  bool get stuck => _stuck;

  /// The player has run into the dead end themselves (a failed move or a
  /// hint asked for while stuck). Only then does the undo tag beckon: the
  /// game never announces a dead end before the player can see it.
  bool get beckonUndo => _stuck && _noticed && !isWon;
  bool get isWon => state.isWon;
  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _history.length - 1;
  int get moves => _cursor;

  /// Returns the move result so the caller can play sounds and haptics.
  MoveResult move(Dir d) {
    final r = state.move(d);
    final next = r.state;
    if (next == null) {
      if (r.blocked != Blocked.finished) {
        String? wanted;
        final gi = board.guestAt(state.pos.x + d.dx, state.pos.y + d.dy);
        if (gi >= 0) wanted = board.guests[gi].wants;
        _bump = Bump(++_serial, d, r.blocked!, wanted: wanted);
        if (_stuck) _noticed = true;
        notifyListeners();
      }
      return r;
    }
    final from = state;
    _history = [..._history.sublist(0, _cursor + 1), next];
    _cursor++;
    _transition = Transition(serial: ++_serial, from: from, to: next, dir: d, events: r.events);
    _afterChange(followHint: _hint == d);
    return r;
  }

  bool undo() {
    if (!canUndo) return false;
    final from = state;
    _cursor--;
    _transition = Transition(serial: ++_serial, from: from, to: state, isUndo: true);
    _afterChange();
    return true;
  }

  bool redo() {
    if (!canRedo) return false;
    final from = state;
    _cursor++;
    _transition = Transition(serial: ++_serial, from: from, to: state, isUndo: true);
    _afterChange();
    return true;
  }

  void restart() {
    if (_cursor == 0 && _history.length == 1) return;
    final from = state;
    _history = [board.initialState()];
    _cursor = 0;
    _transition = Transition(serial: ++_serial, from: from, to: state, isUndo: true);
    _afterChange();
  }

  /// Shows the first move of a shortest solution from here.
  Dir? showHint() {
    if (isWon) return null;
    final path = _solver.solve(state);
    _hint = (path == null || path.isEmpty) ? null : path.first;
    _stuck = path == null;
    if (_stuck) _noticed = true;
    if (_hint != null) hintsUsed++;
    notifyListeners();
    return _hint;
  }

  void _afterChange({bool followHint = false}) {
    _bump = null;
    // Keep the hint going while the player follows it.
    _hint = null;
    if (isWon) {
      _stuck = false;
    } else {
      final path = _solver.solve(state);
      _stuck = path == null;
      if (followHint && path != null && path.isNotEmpty) _hint = path.first;
    }
    if (!_stuck) _noticed = false;
    notifyListeners();
  }
}
