import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/theme.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import 'board_painter.dart';
import 'scene.dart';

/// Cell size for a board that must fit in [box], leaving room for the
/// counter's frame.
double cellSizeFor(Board b, Size box, double maxCell) =>
    math.min(math.min((box.width - 16) / b.width, (box.height - 16) / b.height), maxCell).floorToDouble();

/// Animated board for a [GameController]. Tap a pipe to turn it.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.controller,
    required this.scene,
    required this.reduceMotion,
    this.onTap,
    this.maxCell = 76,
    this.showCursor = false,
    this.semanticLabel,
  });

  final GameController controller;
  final Scene scene;
  final bool reduceMotion;
  final void Function(int x, int y)? onTap;
  final double maxCell;

  /// Show the keyboard cursor (after a key has been pressed).
  final bool showCursor;
  final String? semanticLabel;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  double _now = 0;
  int _trSerial = -1;
  double _trStart = -10;
  int _bumpSerial = -1;
  double _bumpStart = -10;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _now = elapsed.inMicroseconds / 1e6;
      _clock.value = _now;
    });
    widget.controller.addListener(_onChange);
    _syncTicker();
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onChange() {
    final c = widget.controller;
    if (c.transition != null && c.transition!.serial != _trSerial) {
      _trSerial = c.transition!.serial;
      _trStart = _now;
    }
    if (c.bump != null && c.bump!.serial != _bumpSerial) {
      _bumpSerial = c.bump!.serial;
      _bumpStart = _now;
    }
    _clock.value = _now + 1e-9; // force a repaint even when motion is off
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final board = c.board;
    final pal = context.palette;
    return LayoutBuilder(builder: (context, box) {
      final u = cellSizeFor(board, box.biggest, widget.maxCell);
      final size = Size(u * board.width, u * board.height);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (widget.onTap == null) return;
          final origin = Offset((box.maxWidth - size.width) / 2, (box.maxHeight - size.height) / 2);
          final p = d.localPosition - origin;
          final x = (p.dx / u).floor(), y = (p.dy / u).floor();
          if (board.inside(x, y)) widget.onTap!(x, y);
        },
        child: Center(
          child: Semantics(
            label: widget.semanticLabel,
            liveRegion: true,
            child: RepaintBoundary(
              child: CustomPaint(size: size, painter: _AnimatedBoardPainter(this, pal)),
            ),
          ),
        ),
      );
    });
  }

  BoardFrame frame(Palette pal) {
    final c = widget.controller;
    final motion = !widget.reduceMotion;
    final tr = c.transition;
    double trP = 1;
    if (motion && tr != null && tr.serial == _trSerial) {
      trP = ((_now - _trStart) / (transitionDuration(tr).inMicroseconds / 1e6)).clamp(0.0, 1.0);
    }
    double bumpAge = 99;
    if (c.bump != null && c.bump!.serial == _bumpSerial) {
      bumpAge = motion ? _now - _bumpStart : .3;
    }
    return BoardFrame(
      state: c.state,
      palette: pal,
      scene: widget.scene,
      transition: tr,
      transitionP: trP,
      bump: c.bump,
      bumpAge: bumpAge,
      hint: c.hint,
      cursor: widget.showCursor ? c.cursor : null,
      time: motion ? _now : 0,
    );
  }
}

class _AnimatedBoardPainter extends CustomPainter {
  _AnimatedBoardPainter(this.view, this.pal) : super(repaint: view._clock);
  final _BoardViewState view;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) => BoardPainter(view.frame(pal)).paint(canvas, size);

  @override
  bool shouldRepaint(_AnimatedBoardPainter old) => true;
}
