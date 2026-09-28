import 'dart:async';

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import '../game/level_model.dart';
import '../game/solver.dart';
import 'board_view.dart';
import 'scene.dart';

/// A non-interactive board that taps its way to the answer on a loop.
class AutoPlayBoard extends StatefulWidget {
  const AutoPlayBoard({super.key, required this.level, this.stepMs = 520, this.maxCell = 56, this.scene = 'basic'});
  final Level level;
  final int stepMs;
  final double maxCell;
  final String scene;

  @override
  State<AutoPlayBoard> createState() => _AutoPlayBoardState();
}

class _AutoPlayBoardState extends State<AutoPlayBoard> {
  late GameController _c;
  late List<Pos> _taps;
  int _i = 0;
  int _pause = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    _c = GameController(widget.level);
    _taps = _tapsToAnswer(_c.state);
    _i = 0;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: widget.stepMs), (_) => _tick());
  }

  static List<Pos> _tapsToAnswer(GameState s) {
    final answer = Solver(cap: 1).solutions(s.board);
    if (answer.isEmpty) return const [];
    final b = s.board;
    final out = <Pos>[];
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (!b.turnable(x, y)) continue;
        var r = s.rotAt(x, y);
        while (b.maskAt(x, y, r) != answer.first[b.index(x, y)]) {
          out.add(Pos(x, y));
          r++;
        }
      }
    }
    return out;
  }

  void _tick() {
    if (!mounted) return;
    if (_i < _taps.length) {
      _c.tap(_taps[_i].x, _taps[_i].y);
      _i++;
      return;
    }
    if (++_pause >= 4) {
      _pause = 0;
      _i = 0;
      _c.restart();
    }
  }

  @override
  void didUpdateWidget(AutoPlayBoard old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      _c.dispose();
      _setup();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppScope.of(context).settings.reduceMotion(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: BoardView(controller: _c, scene: sceneFor(widget.scene), reduceMotion: reduce, maxCell: widget.maxCell),
      ),
    );
  }
}
