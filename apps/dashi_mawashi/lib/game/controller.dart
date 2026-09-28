import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'levels.dart';
import 'solver.dart';

/// The most recent change, for the board to animate.
class Transition {
  const Transition({required this.serial, required this.from, required this.to, this.cell, this.isUndo = false});

  final int serial;
  final GameState from;
  final GameState to;

  /// The pipe that was turned (null for undo, redo and restart).
  final Pos? cell;
  final bool isUndo;
}

/// A tap that did nothing (an iron pipe), for a little shake.
class Bump {
  const Bump(this.serial, this.cell, this.reason);
  final int serial;
  final Pos cell;
  final Blocked reason;
}

/// Play session for one stage: taps with undo/redo, hints and a keyboard
/// cursor.
class GameController extends ChangeNotifier {
  GameController(this.level) : board = level.board {
    _history = [board.initialState()];
    cursor = _firstPipe();
  }

  final Level level;
  final Board board;
  final Solver _solver = Solver();

  late List<GameState> _history;
  int _cursor = 0;
  int _serial = 0;
  Transition? _transition;
  Bump? _bump;
  Pos? _hint;
  int hintsUsed = 0;

  /// Cell picked with the keyboard.
  late Pos cursor;

  GameState get state => _history[_cursor];
  Transition? get transition => _transition;
  Bump? get bump => _bump;

  /// A pipe to tap next, while a hint is showing.
  Pos? get hint => _hint;
  bool get isWon => state.isWon;
  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _history.length - 1;
  int get moves => _cursor;

  /// Turning pipes can always be undone, so a stage never gets stuck.
  bool get stuck => false;
  bool get beckonUndo => false;

  MoveResult tap(int x, int y) {
    final r = state.tap(x, y);
    final next = r.state;
    if (next == null) {
      if (r.blocked == Blocked.iron) {
        _bump = Bump(++_serial, r.cell, r.blocked!);
        notifyListeners();
      }
      return r;
    }
    final from = state;
    _history = [..._history.sublist(0, _cursor + 1), next];
    _cursor++;
    _transition = Transition(serial: ++_serial, from: from, to: next, cell: r.cell);
    cursor = r.cell;
    _afterChange(followHint: _hint == r.cell);
    return r;
  }

  void moveCursor(Dir d) {
    final n = cursor.step(d);
    if (board.inside(n.x, n.y)) {
      cursor = n;
      notifyListeners();
    }
  }

  MoveResult tapCursor() => tap(cursor.x, cursor.y);

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

  /// Points at a pipe to turn on the way to the answer.
  Pos? showHint() {
    if (isWon) return null;
    _hint = _solver.hint(state);
    if (_hint != null) hintsUsed++;
    notifyListeners();
    return _hint;
  }

  void _afterChange({bool followHint = false}) {
    _bump = null;
    final keep = followHint || (_hint != null && state.maskAt(_hint!.x, _hint!.y) != _solutionMaskAt(_hint!));
    _hint = null;
    // keep pointing while the player follows the hint
    if (!isWon && keep) _hint = _solver.hint(state);
    notifyListeners();
  }

  int? _solutionMaskAt(Pos p) {
    final r = _solver.best(state);
    return r?.$2[board.index(p.x, p.y)];
  }

  Pos _firstPipe() {
    for (var y = 0; y < board.height; y++) {
      for (var x = 0; x < board.width; x++) {
        if (board.turnable(x, y)) return Pos(x, y);
      }
    }
    return const Pos(0, 0);
  }
}
