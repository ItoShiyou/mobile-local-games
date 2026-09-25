import 'dart:async';

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import '../game/level_model.dart';
import '../game/solver.dart';
import 'board_view.dart';

/// A non-interactive board that plays a stage's shortest solution on a loop.
class AutoPlayBoard extends StatefulWidget {
  const AutoPlayBoard({super.key, required this.map, this.cap = 2, this.stepMs = 520, this.maxCell = 56});
  final List<String> map;
  final int cap;
  final int stepMs;
  final double maxCell;

  @override
  State<AutoPlayBoard> createState() => _AutoPlayBoardState();
}

class _AutoPlayBoardState extends State<AutoPlayBoard> {
  late GameController _c;
  late List<Dir> _solution;
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final level = Level(id: 'demo', ja: '', en: '', par: 0, map: widget.map, cap: widget.cap);
    _c = GameController(level);
    _solution = Solver().solve(_c.state) ?? const [];
    _i = 0;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: widget.stepMs), (_) => _tick());
  }

  int _pause = 0;

  void _tick() {
    if (!mounted) return;
    if (_i < _solution.length) {
      _c.move(_solution[_i++]);
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
    if (old.map.join() != widget.map.join()) {
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
        child: BoardView(controller: _c, reduceMotion: reduce, maxCell: widget.maxCell),
      ),
    );
  }
}
