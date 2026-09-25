import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/theme.dart';
import '../audio/sound.dart';
import '../game/engine.dart';
import 'art.dart';
import 'ink_icons.dart';
import 'paper.dart';

/// Swings a child around its top edge when [trigger] changes, like a tag
/// on a nail that has just been touched.
class _Swing extends StatefulWidget {
  const _Swing({required this.trigger, required this.child, this.amount = .16});
  final int trigger;
  final Widget child;
  final double amount;

  @override
  State<_Swing> createState() => _SwingState();
}

class _SwingState extends State<_Swing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(_Swing old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !AppScope.read(context).settings.reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final t = _c.value;
          final a = _c.isAnimating ? math.sin(t * math.pi * 5) * (1 - t) * widget.amount : 0.0;
          return Transform.rotate(angle: a, alignment: Alignment.topCenter, child: child);
        },
      );
}

enum TagWood { plain, dark, shu }

/// A wooden tag hanging from a string. Tapping it swings it.
/// Japanese labels are written top to bottom, like a menu tag.
class HangingTag extends StatefulWidget {
  const HangingTag({
    super.key,
    required this.onPressed,
    required this.label,
    this.glyph,
    this.width = 46,
    this.height = 60,
    this.string = 8,
    this.wood = TagWood.plain,
    this.showLabel = true,
    this.seed = 1,
  });

  final VoidCallback? onPressed;
  final String label;
  final InkGlyph? glyph;
  final double width, height, string;
  final TagWood wood;
  final bool showLabel;
  final int seed;

  @override
  State<HangingTag> createState() => _HangingTagState();
}

class _HangingTagState extends State<HangingTag> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final enabled = widget.onPressed != null;
    final (face, fg) = switch (widget.wood) {
      TagWood.plain => (pal.woodLight, kInk),
      TagWood.dark => (pal.woodDark, const Color(0xFFF6EEDF)),
      TagWood.shu => (pal.shu, pal.onShu),
    };
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final verticalText = ja && widget.showLabel && widget.label.length <= 4 && widget.height >= 72;
    Widget label() {
      if (!widget.showLabel || widget.label.isEmpty) return const SizedBox.shrink();
      if (verticalText) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final ch in widget.label.characters) Text(ch, style: display(16, fg, height: 1.05))],
        );
      }
      return FittedBox(fit: BoxFit.scaleDown, child: Text(widget.label, maxLines: 1, style: display(13, fg)));
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                setState(() => _taps++);
                AppScope.read(context).sound.play(Sfx.tap);
                widget.onPressed!();
              }
            : null,
        child: _Swing(
          trigger: _taps,
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: CustomPaint(
              painter: _TagPainter(face, widget.string, widget.seed),
              child: SizedBox(
                width: widget.width,
                height: widget.height + widget.string,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4, widget.string + 12, 4, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // a Japanese label is the sign itself, written top to bottom
                      if (widget.glyph != null && !verticalText) InkIcon(widget.glyph!, size: 20, color: fg),
                      if (widget.glyph != null && widget.showLabel && !verticalText) const SizedBox(height: 2),
                      Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label())),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPainter extends CustomPainter {
  _TagPainter(this.face, this.string, this.seed);
  final Color face;
  final double string;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, string + 8), Art.stroke(kInk, 1.6));
    final r = Rect.fromLTWH(1, string, w - 2, size.height - string - 1);
    const c = 8.0;
    final shape = Path()
      ..moveTo(r.left + c, r.top)
      ..lineTo(r.right - c, r.top)
      ..lineTo(r.right, r.top + c)
      ..lineTo(r.right, r.bottom - 3)
      ..quadraticBezierTo(r.right, r.bottom, r.right - 3, r.bottom)
      ..lineTo(r.left + 3, r.bottom)
      ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 3)
      ..lineTo(r.left, r.top + c)
      ..close();
    final p = Wob.around(shape, seed: seed, amp: .6);
    canvas.drawPath(p.shift(const Offset(2, 3)), Art.fill(const Color(0x33000000)));
    canvas.drawPath(p, Art.fill(face));
    canvas.save();
    canvas.clipPath(p);
    for (var i = 0; i < 3; i++) {
      final x = r.left + r.width * (.25 + i * .25);
      canvas.drawPath(Path()..moveTo(x, r.top)..cubicTo(x - 2, r.top + r.height * .3, x + 3, r.top + r.height * .7, x, r.bottom),
          Art.stroke(const Color(0x1C000000), 1));
    }
    PaperGrain.paint(canvas, r, opacity: .7);
    canvas.restore();
    canvas.drawPath(p, Art.stroke(kInk, 1.6));
    canvas.drawCircle(Offset(w / 2, r.top + 7), 2.4, Art.fill(kInk));
  }

  @override
  bool shouldRepaint(_TagPainter o) => o.face != face;
}

/// The hint: a paper lantern hanging from the rail. It glows while a hint
/// is showing.
class LanternButton extends StatefulWidget {
  const LanternButton({super.key, required this.onPressed, required this.label, required this.lit, this.width = 54, this.height = 92});
  final VoidCallback? onPressed;
  final String label;
  final bool lit;
  final double width, height;

  @override
  State<LanternButton> createState() => _LanternButtonState();
}

class _LanternButtonState extends State<LanternButton> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                setState(() => _taps++);
                AppScope.read(context).sound.play(Sfx.tap);
                widget.onPressed!();
              }
            : null,
        child: _Swing(
          trigger: _taps,
          amount: .1,
          child: Opacity(
            opacity: enabled ? 1 : .5,
            child: CustomPaint(
              painter: _LanternPainter(pal, widget.lit),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Padding(
                  padding: EdgeInsets.only(top: widget.height * .28, bottom: widget.height * .16),
                  child: Center(
                    child: ja
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [for (final ch in widget.label.characters) Text(ch, style: display(13, kInk, height: 1))],
                          )
                        : FittedBox(child: Text(widget.label, style: display(12.5, kInk))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanternPainter extends CustomPainter {
  _LanternPainter(this.pal, this.lit);
  final Palette pal;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * .14), Art.stroke(kInk, 1.6));
    final body = Rect.fromLTWH(w * .06, h * .2, w * .88, h * .66);
    if (lit) {
      final g = Rect.fromCircle(center: body.center, radius: w * 1.1);
      canvas.drawCircle(body.center, w * 1.1, Paint()
        ..shader = RadialGradient(colors: [pal.glow.withValues(alpha: .7), pal.glow.withValues(alpha: 0)]).createShader(g));
    }
    final paper = lit ? const Color(0xFFFFE3A0) : const Color(0xFFF4E6CB);
    Art.inked(canvas, Path()..addOval(body), paper, 1.6);
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    for (var i = 1; i < 6; i++) {
      final y = body.top + body.height * i / 6;
      canvas.drawLine(Offset(body.left, y), Offset(body.right, y), Art.stroke(const Color(0x33000000), 1));
    }
    canvas.drawRect(Rect.fromLTWH(body.left, body.center.dy - body.height * .08, body.width, body.height * .16), Art.fill(pal.shu.withValues(alpha: .18)));
    canvas.restore();
    for (final y in [body.top, body.bottom]) {
      Art.inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, y), width: w * .56, height: h * .07), const Radius.circular(2))),
          const Color(0xFF2A211C), 1.2);
    }
    canvas.drawLine(Offset(w / 2, body.bottom + h * .03), Offset(w / 2, h - 2), Art.stroke(pal.shu, 2));
  }

  @override
  bool shouldRepaint(_LanternPainter o) => o.lit != lit || o.pal != pal;
}

/// The direction pad: a round lacquered tray with four gold arrows.
/// Holding a side repeats the move.
class TrayPad extends StatefulWidget {
  const TrayPad({super.key, required this.onMove, this.highlight, this.enabled = true, this.size = 150});
  final void Function(Dir) onMove;
  final Dir? highlight;
  final bool enabled;
  final double size;

  @override
  State<TrayPad> createState() => _TrayPadState();
}

class _TrayPadState extends State<TrayPad> {
  Dir? _down;
  Timer? _repeat;

  Dir? _dirAt(Offset p) {
    final c = Offset(widget.size / 2, widget.size / 2);
    final d = p - c;
    if (d.distance < widget.size * .13 || d.distance > widget.size * .6) return null;
    if (d.dx.abs() > d.dy.abs()) return d.dx > 0 ? Dir.right : Dir.left;
    return d.dy > 0 ? Dir.down : Dir.up;
  }

  void _start(Offset p) {
    if (!widget.enabled) return;
    final d = _dirAt(p);
    if (d == null) return;
    setState(() => _down = d);
    widget.onMove(d);
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 380), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (_down != null) widget.onMove(_down!);
      });
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    if (mounted && _down != null) setState(() => _down = null);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final names = {Dir.up: ja ? '上' : 'Up', Dir.down: ja ? '下' : 'Down', Dir.left: ja ? '左' : 'Left', Dir.right: ja ? '右' : 'Right'};
    final s = widget.size;
    return Semantics(
      container: true,
      child: Stack(
        children: [
          Listener(
            onPointerDown: (e) => _start(e.localPosition),
            onPointerUp: (_) => _stop(),
            onPointerCancel: (_) => _stop(),
            child: CustomPaint(size: Size.square(s), painter: _TrayPadPainter(pal, _down, widget.highlight, widget.enabled)),
          ),
          for (final d in Dir.values)
            Positioned(
              left: s / 3 * (1 + d.dx),
              top: s / 3 * (1 + d.dy),
              width: s / 3,
              height: s / 3,
              child: Semantics(
                button: true,
                label: names[d],
                onTap: widget.enabled ? () => widget.onMove(d) : null,
                child: const IgnorePointer(child: SizedBox.expand()),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrayPadPainter extends CustomPainter {
  _TrayPadPainter(this.pal, this.down, this.hint, this.enabled);
  final Palette pal;
  final Dir? down;
  final Dir? hint;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 7), width: r * 2, height: r * 1.9), Art.fill(const Color(0x40000000)));
    Art.inked(canvas, Path()..addOval(Rect.fromCircle(center: c + const Offset(0, 4), radius: r)), const Color(0xFF4A1812), 2);
    Art.inked(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: r)), const Color(0xFF7A2A22), 2);
    final inner = Rect.fromCircle(center: c, radius: r * .84);
    canvas.drawOval(inner, Art.fill(const Color(0xFF9E3A2E)));
    canvas.drawOval(inner, Art.stroke(const Color(0xFF5A1E18), 1.6));
    // lacquer sheen
    canvas.drawArc(inner.deflate(6), math.pi * 1.1, .9, false, Art.stroke(Colors.white.withValues(alpha: .22), 4));
    for (final d in Dir.values) {
      final a = math.atan2(d.dy.toDouble(), d.dx.toDouble());
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(inner, a - math.pi / 4, math.pi / 2, false)
        ..close();
      if (d == hint) canvas.drawPath(path, Art.fill(pal.glow.withValues(alpha: .55)));
      if (d == down) canvas.drawPath(path, Art.fill(const Color(0x44000000)));
    }
    const gold = Color(0xFFE9C46A);
    for (final d in Dir.values) {
      final m = c + Offset(d.dx * r * .56, d.dy * r * .56) + (d == down ? const Offset(0, 1.5) : Offset.zero);
      final s = r * .2;
      final tri = Path()
        ..moveTo(m.dx + d.dx * s, m.dy + d.dy * s)
        ..lineTo(m.dx - d.dx * s * .6 - d.dy * s, m.dy - d.dy * s * .6 - d.dx * s)
        ..lineTo(m.dx - d.dx * s * .6 + d.dy * s, m.dy - d.dy * s * .6 + d.dx * s)
        ..close();
      Art.inked(canvas, tri, enabled ? gold : gold.withValues(alpha: .4), 1.4);
    }
    // a small mitsudomoe-like swirl in the middle
    canvas.drawCircle(c, r * .15, Art.fill(const Color(0xFF7A2A22)));
    canvas.drawCircle(c, r * .15, Art.stroke(gold, 2));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * .08), 0, math.pi * 1.3, false, Art.stroke(gold, 2));
  }

  @override
  bool shouldRepaint(_TrayPadPainter o) => o.down != down || o.hint != hint || o.enabled != enabled || o.pal != pal;
}

/// The little blackboard hanging on the wall: moves so far and the target,
/// and one chalk plate per dish the courier can carry.
class WallChalkboard extends StatelessWidget {
  const WallChalkboard({super.key, required this.moves, required this.par, required this.capacity, required this.movesWord, required this.parWord});
  final int moves, par, capacity;
  final String movesWord, parWord;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      painter: _WallBoardPainter(pal, capacity),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(movesWord, style: display(11, pal.chalk.withValues(alpha: .75), height: 1)),
                Text('$moves', style: display(26, pal.chalk, height: 1)),
              ],
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('/ $par', style: display(14, pal.chalk.withValues(alpha: .7), height: 1)),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 22, height: 8.0 * capacity + 6),
          ],
        ),
      ),
    );
  }
}

class _WallBoardPainter extends CustomPainter {
  _WallBoardPainter(this.pal, this.capacity);
  final Palette pal;
  final int capacity;

  @override
  void paint(Canvas canvas, Size size) {
    // strings to the nail
    final nail = Offset(size.width / 2, 0);
    canvas.drawLine(nail, const Offset(10, 12), Art.stroke(kInk, 1.4));
    canvas.drawLine(nail, Offset(size.width - 10, 12), Art.stroke(kInk, 1.4));
    canvas.drawCircle(nail, 2.5, Art.fill(kInk));
    final r = Rect.fromLTWH(0, 10, size.width, size.height - 10);
    final frame = Wob.rrect(r.deflate(1), 4, seed: 70, amp: .7);
    canvas.drawPath(frame.shift(const Offset(2, 3)), Art.fill(const Color(0x33000000)));
    canvas.drawPath(frame, Art.fill(pal.woodDark));
    final inner = Wob.rrect(r.deflate(5), 2, seed: 71, amp: .5);
    canvas.drawPath(inner, Art.fill(pal.board));
    canvas.save();
    canvas.clipPath(inner);
    canvas.drawOval(Rect.fromCenter(center: r.center, width: r.width * .8, height: 10), Art.fill(Colors.white.withValues(alpha: .05)));
    canvas.restore();
    canvas.drawPath(frame, Art.stroke(kInk, 1.5));
    // chalk plates, one per dish the courier can carry
    final x = size.width - 22;
    for (var i = 0; i < capacity; i++) {
      final y = size.height - 14 - i * 8.0;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 18, height: 5), Art.stroke(pal.chalk.withValues(alpha: .85), 1.4));
    }
  }

  @override
  bool shouldRepaint(_WallBoardPainter o) => o.capacity != capacity || o.pal != pal;
}
