import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/theme.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import 'board_painter.dart';

/// Animated board for a [GameController]. Handles swipes (one move per
/// ~0.7 cell of drag, so a long drag walks several cells) and taps on a
/// neighbouring cell.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.controller,
    required this.reduceMotion,
    this.onMove,
    this.maxCell = 76,
    this.semanticLabel,
  });

  final GameController controller;
  final bool reduceMotion;
  final void Function(Dir)? onMove;
  final double maxCell;
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
  Offset? _dragOrigin;

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
      final u = math.min(math.min(box.maxWidth / board.width, box.maxHeight / board.height), widget.maxCell).floorToDouble();
      final size = Size(u * board.width, u * board.height);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _dragOrigin = d.localPosition,
        onPanUpdate: (d) {
          final o = _dragOrigin;
          if (o == null || widget.onMove == null) return;
          final delta = d.localPosition - o;
          final step = math.max(24.0, u * .7);
          if (delta.distance < step) return;
          final dir = delta.dx.abs() > delta.dy.abs()
              ? (delta.dx > 0 ? Dir.right : Dir.left)
              : (delta.dy > 0 ? Dir.down : Dir.up);
          widget.onMove!(dir);
          _dragOrigin = d.localPosition;
        },
        onPanEnd: (_) => _dragOrigin = null,
        onTapUp: (d) {
          if (widget.onMove == null) return;
          final origin = Offset((box.maxWidth - size.width) / 2, (box.maxHeight - size.height) / 2);
          final p = d.localPosition - origin;
          final x = (p.dx / u).floor(), y = (p.dy / u).floor();
          final s = c.state;
          for (final dir in Dir.values) {
            if (s.pos.x + dir.dx == x && s.pos.y + dir.dy == y) {
              widget.onMove!(dir);
              return;
            }
          }
        },
        child: Center(
          child: Semantics(
            label: widget.semanticLabel,
            liveRegion: true,
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _AnimatedBoardPainter(this, pal),
              ),
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
      final dur = transitionDuration(tr).inMicroseconds / 1e6;
      trP = ((_now - _trStart) / dur).clamp(0.0, 1.0);
    }
    double bumpP = 1;
    if (motion && c.bump != null && c.bump!.serial == _bumpSerial) {
      bumpP = ((_now - _bumpStart) / .22).clamp(0.0, 1.0);
    }
    return BoardFrame(
      state: c.state,
      palette: pal,
      transition: tr,
      transitionP: trP,
      bump: c.bump,
      bumpP: bumpP,
      hint: c.hint,
      time: motion ? _now : 0,
    );
  }
}

class _AnimatedBoardPainter extends CustomPainter {
  _AnimatedBoardPainter(this.view, this.pal) : super(repaint: view._clock);
  final _BoardViewState view;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final f = view.frame(pal);
    final b = f.bump;
    if (b != null && f.bumpP < 1 && (b.reason == Blocked.wall || b.reason == Blocked.oneWay)) {
      // spec §3-4: a refused move shakes the board 4px sideways
      canvas.translate(math.sin(f.bumpP * math.pi * 4) * 4 * (1 - f.bumpP), 0);
    }
    BoardPainter(f).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_AnimatedBoardPainter old) => true;
}
