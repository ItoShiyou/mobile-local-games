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

// ======================================================================
// Buttons
// ======================================================================

enum WoodKind { wood, shu, noren, paper }

/// A chunky wooden (or lacquered) block that sinks when pressed.
class WoodButton extends StatefulWidget {
  const WoodButton({
    super.key,
    required this.onPressed,
    this.label = '',
    this.glyph,
    this.kind = WoodKind.wood,
    this.small = false,
    this.vertical = false,
    this.glow = false,
    this.semanticLabel,
    this.seed = 3,
  });

  final VoidCallback? onPressed;
  final String label;
  final InkGlyph? glyph;
  final WoodKind kind;
  final bool small;

  /// Icon above the label (tool plaques).
  final bool vertical;

  /// Lantern-light rim, used to draw the eye (e.g. to the hint).
  final bool glow;
  final String? semanticLabel;
  final int seed;

  @override
  State<WoodButton> createState() => _WoodButtonState();
}

class _WoodButtonState extends State<WoodButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final enabled = widget.onPressed != null;
    final (face, edge, fg) = switch (widget.kind) {
      WoodKind.wood => (pal.woodLight, pal.woodDark, kInk),
      WoodKind.shu => (pal.shu, Color.lerp(pal.shu, Colors.black, .35)!, pal.onShu),
      WoodKind.noren => (pal.noren, Color.lerp(pal.noren, Colors.black, .4)!, pal.onNoren),
      WoodKind.paper => (pal.card, pal.line, pal.ink),
    };
    const depth = 5.0;
    final press = _down ? depth - 1.5 : 0.0;
    final iconSize = widget.small || widget.vertical ? 20.0 : 22.0;
    final text = widget.label.isEmpty
        ? null
        : Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: display(widget.vertical ? 13 : (widget.small ? 15 : 19), fg, height: 1.1),
          );
    final icon = widget.glyph == null ? null : InkIcon(widget.glyph!, size: iconSize, color: fg);
    final content = widget.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: [?icon, if (icon != null && text != null) const SizedBox(height: 3), ?text])
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            ?icon,
            if (icon != null && text != null) const SizedBox(width: 8),
            if (text != null) Flexible(child: text),
          ]);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Opacity(
        opacity: enabled ? 1 : .42,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: enabled
              ? (_) {
                  setState(() => _down = false);
                  AppScope.read(context).sound.play(Sfx.tap);
                  widget.onPressed!();
                }
              : null,
          child: CustomPaint(
            painter: _BlockPainter(face, edge, depth, press, widget.seed, grain: widget.kind == WoodKind.wood, glow: widget.glow ? pal.glow : null),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.small || widget.vertical ? 44 : 54, minWidth: 44),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    widget.vertical ? 4 : (widget.small ? 12 : 18), 6 + press, widget.vertical ? 4 : (widget.small ? 12 : 18), 6 + depth - press),
                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: content)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockPainter extends CustomPainter {
  _BlockPainter(this.face, this.edge, this.depth, this.press, this.seed, {required this.grain, this.glow});
  final Color face, edge;
  final double depth, press;
  final int seed;
  final bool grain;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1, 1 + press, size.width - 2, size.height - 2 - depth);
    final bottom = Rect.fromLTWH(1, 1 + press, size.width - 2, size.height - 2 - press);
    if (glow != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(bottom.inflate(3), const Radius.circular(12)),
          Paint()..color = glow!.withValues(alpha: .7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    final side = Wob.rrect(bottom, 10, seed: seed, amp: .8);
    canvas.drawPath(side, Paint()..color = edge);
    canvas.drawPath(side, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = kInk);
    final top = Wob.rrect(r, 10, seed: seed + 1, amp: .8);
    canvas.drawPath(top, Paint()..color = face);
    if (grain) {
      canvas.save();
      canvas.clipPath(top);
      final g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000);
      for (var i = 0; i < 4; i++) {
        final y = r.top + r.height * (.22 + i * .2);
        canvas.drawPath(Path()..moveTo(r.left, y)..quadraticBezierTo(r.center.dx, y + (i.isOdd ? 3 : -3), r.right, y + 1), g);
      }
      canvas.restore();
    }
    canvas.save();
    canvas.clipPath(top);
    PaperGrain.paint(canvas, r, opacity: .6);
    canvas.drawLine(r.topLeft + const Offset(8, 3), r.topRight + const Offset(-8, 3), Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .25));
    canvas.restore();
    canvas.drawPath(top, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = kInk);
  }

  @override
  bool shouldRepaint(_BlockPainter o) => o.face != face || o.press != press || o.glow != glow;
}

/// Round wooden button holding only an icon (back, settings, help).
class RoundWoodButton extends StatelessWidget {
  const RoundWoodButton({super.key, required this.glyph, required this.onPressed, required this.tooltip});
  final InkGlyph glyph;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        height: 50,
        child: WoodButton(onPressed: onPressed, glyph: glyph, small: true, semanticLabel: tooltip, seed: glyph.index),
      );
}

// ======================================================================
// Signs, paper and stamps
// ======================================================================

/// A wooden shop sign with two nails, optionally hanging on cords.
class Signboard extends StatelessWidget {
  const Signboard({super.key, required this.child, this.hanging = false, this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 10)});
  final Widget child;
  final bool hanging;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      painter: _SignPainter(pal, hanging),
      child: Padding(padding: padding.copyWith(top: padding.top + (hanging ? 14 : 0)), child: child),
    );
  }
}

class _SignPainter extends CustomPainter {
  _SignPainter(this.pal, this.hanging);
  final Palette pal;
  final bool hanging;

  @override
  void paint(Canvas canvas, Size size) {
    final top = hanging ? 14.0 : 0.0;
    final r = Rect.fromLTWH(2, top + 2, size.width - 4, size.height - top - 4);
    final cord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kInk;
    if (hanging) {
      canvas.drawLine(Offset(r.left + 18, r.top + 4), Offset(r.left + 30, 0), cord);
      canvas.drawLine(Offset(r.right - 18, r.top + 4), Offset(r.right - 30, 0), cord);
    }
    final path = Wob.rrect(r, 6, seed: 5, amp: 1);
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = const Color(0x33000000));
    canvas.drawPath(path, Paint()..color = pal.wood);
    canvas.save();
    canvas.clipPath(path);
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x26000000);
    for (var i = 0; i < 5; i++) {
      final y = r.top + r.height * (.15 + i * .18);
      canvas.drawPath(Path()..moveTo(r.left, y)..cubicTo(r.left + r.width * .3, y - 3, r.left + r.width * .6, y + 4, r.right, y), g);
    }
    PaperGrain.paint(canvas, r, opacity: .7);
    canvas.restore();
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kInk);
    for (final x in [r.left + 9, r.right - 9]) {
      canvas.drawCircle(Offset(x, r.top + 9), 2.6, Paint()..color = const Color(0xFF6B5A4A));
    }
  }

  @override
  bool shouldRepaint(_SignPainter o) => o.pal != pal || o.hanging != hanging;
}

/// Three hanko stamps instead of stars. Earned ones are solid vermilion.
class HankoStars extends StatelessWidget {
  const HankoStars({super.key, required this.stars, this.size = 16, this.animate = false, this.total = 3});
  final int stars;
  final int total;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    Widget stamp(int i) {
      final on = i < stars;
      final w = CustomPaint(size: Size.square(size), painter: _HankoPainter(on, pal, i));
      if (!animate || !on) return w;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + i * 220),
        curve: Interval(i * .35, 1, curve: Curves.easeOutBack),
        builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 1.8 - .8 * v, child: child)),
        child: w,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 0; i < total; i++) Padding(padding: EdgeInsets.symmetric(horizontal: size * .06), child: stamp(i))],
    );
  }
}

class _HankoPainter extends CustomPainter {
  _HankoPainter(this.on, this.pal, this.i);
  final bool on;
  final Palette pal;
  final int i;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * .46;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate((i - 1) * .18);
    if (on) {
      final ring = Wob.oval(Rect.fromCircle(center: Offset.zero, radius: r), seed: i + 2, amp: r * .05);
      canvas.drawPath(ring, Paint()..color = pal.shu);
      final star = Path();
      for (var k = 0; k < 10; k++) {
        final a = -math.pi / 2 + k * math.pi / 5;
        final rr = k.isEven ? r * .62 : r * .27;
        final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
        k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..color = pal.card);
      // worn ink
      final rnd = math.Random(i * 31);
      for (var k = 0; k < 6; k++) {
        canvas.drawCircle(Offset((rnd.nextDouble() - .5) * r * 1.6, (rnd.nextDouble() - .5) * r * 1.6), r * .06,
            Paint()..color = pal.card.withValues(alpha: .6));
      }
    } else {
      final ring = Wob.oval(Rect.fromCircle(center: Offset.zero, radius: r * .9), seed: i + 7, amp: r * .06);
      canvas.drawPath(ring, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * .1)
        ..color = pal.inkSoft.withValues(alpha: .45));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HankoPainter o) => o.on != on || o.pal != pal;
}

/// Order slip pinned on a line: shows the dish; stamped once served.
class OrderSlip extends StatelessWidget {
  const OrderSlip({super.key, required this.kind, required this.served, required this.stamp, this.index = 0});
  final String kind;
  final bool served;
  final String stamp;
  final int index;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Transform.rotate(
      angle: ((index * 37) % 7 - 3) * .025,
      child: CustomPaint(size: const Size(38, 46), painter: _SlipPainter(kind, served, stamp, pal)),
    );
  }
}

class _SlipPainter extends CustomPainter {
  _SlipPainter(this.kind, this.served, this.stamp, this.pal);
  final String kind;
  final bool served;
  final String stamp;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()..moveTo(2, 4)..lineTo(w - 2, 4)..lineTo(w - 2, h - 5);
    for (var i = 0; i < 6; i++) {
      final x = w - 2 - (i + .5) * (w - 4) / 6;
      path.lineTo(x, i.isEven ? h - 1 : h - 5);
    }
    path
      ..lineTo(2, h - 5)
      ..close();
    canvas.drawPath(path.shift(const Offset(1, 2)), Paint()..color = const Color(0x22000000));
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFBF1));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = kInk.withValues(alpha: .6));
    canvas.drawLine(Offset(6, h - 12), Offset(w - 6, h - 12), Paint()..color = const Color(0x33C8452F)..strokeWidth = 1);
    canvas.drawCircle(Offset(w / 2, 5), 3, Paint()..color = pal.shu); // pin
    Art.food(canvas, Offset(w / 2, h * .46), w * .62, kind);
    if (served) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x66FFFBF1));
      canvas.save();
      canvas.translate(w / 2, h * .5);
      canvas.rotate(-.25);
      canvas.drawCircle(Offset.zero, w * .34, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = pal.shu.withValues(alpha: .9));
      final tp = TextPainter(
        text: TextSpan(text: stamp, style: TextStyle(fontFamily: displayFont, fontSize: w * .38, color: pal.shu, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SlipPainter o) => o.kind != kind || o.served != served || o.pal != pal;
}

/// A small blackboard with chalk lines.
class Chalkboard extends StatelessWidget {
  const Chalkboard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      painter: _ChalkPainter(pal),
      child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 9), child: DefaultTextStyle(style: display(14, pal.chalk), child: child)),
    );
  }
}

class _ChalkPainter extends CustomPainter {
  _ChalkPainter(this.pal);
  final Palette pal;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final frame = Wob.rrect(r.deflate(1), 5, seed: 9, amp: .7);
    canvas.drawPath(frame, Paint()..color = pal.woodDark);
    final inner = Wob.rrect(r.deflate(5), 3, seed: 10, amp: .6);
    canvas.drawPath(inner, Paint()..color = pal.board);
    canvas.save();
    canvas.clipPath(inner);
    final rnd = math.Random(4);
    final smudge = Paint()..color = Colors.white.withValues(alpha: .05);
    for (var i = 0; i < 6; i++) {
      canvas.drawOval(Rect.fromCenter(center: Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), width: 30, height: 10), smudge);
    }
    canvas.restore();
    canvas.drawPath(frame, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = kInk);
  }

  @override
  bool shouldRepaint(_ChalkPainter o) => o.pal != pal;
}

/// Speech bubble with a hand-drawn edge. The tail points down-left, at the
/// speaker below.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.child, this.tailX = .18, this.tailFromLeft, this.tailFromRight, this.warn = false});
  final Widget child;

  /// Where the tail sits: a fraction of the width, or a distance in pixels
  /// from the left or right edge.
  final double tailX;
  final double? tailFromLeft;
  final double? tailFromRight;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      painter: _BubblePainter(pal, tailX, warn, tailFromLeft, tailFromRight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 19),
        child: DefaultTextStyle(style: const TextStyle(fontFamily: fontFamily, color: kInk, fontWeight: FontWeight.w700, fontSize: 14.5), child: child),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.pal, this.tailX, this.warn, this.fromLeft, this.fromRight);
  final Palette pal;
  final double tailX;
  final bool warn;
  final double? fromLeft, fromRight;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(1, 1, size.width - 2, size.height - 12);
    final tx = (fromLeft ?? (fromRight != null ? size.width - fromRight! : size.width * tailX)).clamp(20.0, size.width - 20);
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(16))),
      Path()
        ..moveTo(tx - 8, body.bottom - 2)
        ..lineTo(tx - 12, size.height - 1)
        ..lineTo(tx + 8, body.bottom - 2)
        ..close(),
    );
    final path = Wob.around(shape, seed: 21, amp: .8);
    canvas.drawPath(path.shift(const Offset(0, 2)), Paint()..color = const Color(0x2A000000));
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFBF1));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = warn ? 2.4 : 1.8
      ..color = warn ? pal.shu : kInk);
  }

  @override
  bool shouldRepaint(_BubblePainter o) => o.warn != warn || o.tailX != tailX || o.fromLeft != fromLeft || o.fromRight != fromRight || o.pal != pal;
}

// ======================================================================
// Settings controls
// ======================================================================

/// On/off: a wooden token slides along a groove; "on" is a vermilion stamp.
class InkSwitch extends StatelessWidget {
  const InkSwitch({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          AppScope.read(context).sound.play(Sfx.tap);
          onChanged(!value);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value ? 1 : 0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          builder: (_, v, _) => CustomPaint(size: const Size(60, 34), painter: _SwitchPainter(v, pal)),
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter(this.v, this.pal);
  final double v;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final groove = Wob.rrect(Rect.fromLTWH(2, 8, size.width - 4, size.height - 16), 9, seed: 4, amp: .6);
    canvas.drawPath(groove, Paint()..color = Color.lerp(pal.paperDeep, pal.shu.withValues(alpha: .3), v)!);
    canvas.drawPath(groove, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = kInk.withValues(alpha: .7));
    final x = 17 + (size.width - 34) * v;
    final c = Offset(x, size.height / 2);
    canvas.drawCircle(c + const Offset(0, 2), 13, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(c, 13, Paint()..color = Color.lerp(pal.woodLight, pal.shu, v)!);
    canvas.drawCircle(c, 13, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = kInk);
    if (v > .5) {
      canvas.drawCircle(c, 7, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = pal.onShu.withValues(alpha: (v - .5) * 2));
    }
  }

  @override
  bool shouldRepaint(_SwitchPainter o) => o.v != v || o.pal != pal;
}

/// A row of paper tags; the chosen one carries a vermilion circle.
class TagChoice<T> extends StatelessWidget {
  const TagChoice({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, (v, label)) in options.indexed)
          Semantics(
            selected: v == value,
            button: true,
            label: label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                AppScope.read(context).sound.play(Sfx.tap);
                onChanged(v);
              },
              child: PaperSlip(
                seed: i + 30,
                tilt: v == value ? -1.5 : 0,
                color: v == value ? pal.card : pal.paperDeep.withValues(alpha: .6),
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (v == value) ...[
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: pal.shu, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Text(label, style: display(15, v == value ? pal.ink : pal.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ======================================================================
// Direction pad
// ======================================================================

/// A cross carved from one block of wood. Holding an arm repeats the move.
class WoodDPad extends StatefulWidget {
  const WoodDPad({super.key, required this.onMove, this.highlight, this.enabled = true, this.arm = 52});
  final void Function(Dir) onMove;
  final Dir? highlight;
  final bool enabled;
  final double arm;

  @override
  State<WoodDPad> createState() => _WoodDPadState();
}

class _WoodDPadState extends State<WoodDPad> {
  Dir? _down;
  Timer? _repeat;

  Dir? _dirAt(Offset p) {
    final c = Offset(widget.arm * 1.5, widget.arm * 1.5);
    final d = p - c;
    if (d.distance < widget.arm * .35) return null;
    if (d.dx.abs() > d.dy.abs()) {
      if (d.dy.abs() > widget.arm * .6) return null;
      return d.dx > 0 ? Dir.right : Dir.left;
    }
    if (d.dx.abs() > widget.arm * .6) return null;
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
    final names = {
      Dir.up: ja ? '上' : 'Up',
      Dir.down: ja ? '下' : 'Down',
      Dir.left: ja ? '左' : 'Left',
      Dir.right: ja ? '右' : 'Right',
    };
    final s = widget.arm * 3;
    return Semantics(
      container: true,
      child: Stack(
        children: [
          Listener(
            onPointerDown: (e) => _start(e.localPosition),
            onPointerUp: (_) => _stop(),
            onPointerCancel: (_) => _stop(),
            child: CustomPaint(size: Size.square(s), painter: _PadPainter(pal, widget.arm, _down, widget.highlight, widget.enabled)),
          ),
          // invisible targets for screen readers
          for (final d in Dir.values)
            Positioned(
              left: widget.arm * (1 + d.dx),
              top: widget.arm * (1 + d.dy),
              width: widget.arm,
              height: widget.arm,
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

class _PadPainter extends CustomPainter {
  _PadPainter(this.pal, this.a, this.down, this.hint, this.enabled);
  final Palette pal;
  final double a;
  final Dir? down;
  final Dir? hint;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(a * 1.5, a * 1.5);
    final cross = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: a * .98, height: a * 2.94), Radius.circular(a * .3))),
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: a * 2.94, height: a * .98), Radius.circular(a * .3))),
    );
    final shape = Wob.around(cross, seed: 12, amp: .9);
    canvas.drawPath(shape.shift(const Offset(0, 5)), Paint()..color = pal.woodDark);
    canvas.drawPath(shape.shift(const Offset(0, 5)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = kInk);
    canvas.drawPath(shape, Paint()..color = pal.woodLight);
    canvas.save();
    canvas.clipPath(shape);
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x22000000);
    for (var i = 0; i < 9; i++) {
      final y = a * .2 + i * a * .32;
      canvas.drawPath(Path()..moveTo(0, y)..quadraticBezierTo(a * 1.5, y + (i.isOdd ? 5 : -5), a * 3, y), g);
    }
    PaperGrain.paint(canvas, Offset.zero & size, opacity: .7);
    for (final d in Dir.values) {
      final armRect = Rect.fromCenter(center: c + Offset(d.dx * a, d.dy * a), width: a * .98, height: a * .98);
      if (d == hint) canvas.drawRect(armRect, Paint()..color = pal.glow.withValues(alpha: .55));
      if (d == down) canvas.drawRect(armRect, Paint()..color = const Color(0x33000000));
    }
    canvas.restore();
    canvas.drawPath(shape, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = kInk);
    // carved arrows
    for (final d in Dir.values) {
      final m = c + Offset(d.dx * a * (d == down ? 1.08 : 1.05), d.dy * a * (d == down ? 1.08 : 1.05));
      final tri = Path()
        ..moveTo(m.dx + d.dx * a * .2, m.dy + d.dy * a * .2)
        ..lineTo(m.dx - d.dx * a * .12 - d.dy * a * .2, m.dy - d.dy * a * .12 - d.dx * a * .2)
        ..lineTo(m.dx - d.dx * a * .12 + d.dy * a * .2, m.dy - d.dy * a * .12 + d.dx * a * .2)
        ..close();
      canvas.drawPath(tri.shift(const Offset(0, 1.2)), Paint()..color = Colors.white.withValues(alpha: .35));
      canvas.drawPath(tri, Paint()..color = enabled ? pal.woodDark : pal.woodDark.withValues(alpha: .4));
    }
    canvas.drawCircle(c, a * .16, Paint()..color = pal.wood);
    canvas.drawCircle(c, a * .16, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = kInk.withValues(alpha: .6));
  }

  @override
  bool shouldRepaint(_PadPainter o) => o.down != down || o.hint != hint || o.enabled != enabled || o.pal != pal;
}

// ======================================================================
// Noren (shop curtain) and page transition
// ======================================================================

class NorenPainter extends CustomPainter {
  NorenPainter({required this.color, required this.text, this.sway = 0, this.panels = 4, this.crest = '出', this.rod = true});
  final Color color;
  final Color text;
  final double sway;
  final int panels;
  final String crest;
  final bool rod;

  @override
  void paint(Canvas canvas, Size size) {
    final rod = this.rod ? 10.0 : 0.0;
    final gap = 3.0;
    final pw = size.width / panels;
    final panelPaths = <Path>[];
    for (var i = 0; i < panels; i++) {
      final x0 = i * pw + gap / 2, x1 = (i + 1) * pw - gap / 2;
      final s = sway * (i.isEven ? 1 : -.7) * 6;
      final p = Path()
        ..moveTo(x0, rod)
        ..lineTo(x1, rod)
        ..lineTo(x1 + s, size.height - 4)
        ..quadraticBezierTo((x0 + x1) / 2 + s, size.height + 2, x0 + s, size.height - 4)
        ..close();
      panelPaths.add(p);
    }
    final cloth = panelPaths.reduce((a, b) => Path.combine(PathOperation.union, a, b));
    canvas.drawPath(cloth.shift(const Offset(0, 3)), Paint()..color = const Color(0x33000000));
    canvas.drawPath(cloth, Paint()..color = color);
    canvas.save();
    canvas.clipPath(cloth);
    // weave
    final weave = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), weave);
    }
    PaperGrain.paint(canvas, Offset.zero & size, opacity: .9);
    if (crest.isNotEmpty) _crest(canvas, size, rod, pw);
    canvas.restore();
    for (final p in panelPaths) {
      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = kInk.withValues(alpha: .7));
    }
    if (!this.rod) return;
    final rodR = RRect.fromRectAndRadius(Rect.fromLTWH(-4, 0, size.width + 8, rod), const Radius.circular(4));
    canvas.drawRRect(rodR, Paint()..color = const Color(0xFF8A5E3B));
    canvas.drawRRect(rodR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = kInk);
  }

  void _crest(Canvas canvas, Size size, double rod, double pw) {
    // a white circle across the middle seam
    final cc = Offset(size.width / 2, (size.height + rod) / 2);
    final cr = math.min(size.height * .3, pw * .8);
    canvas.drawCircle(cc, cr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cr * .12
      ..color = text);
    final tp = TextPainter(
      text: TextSpan(text: crest, style: TextStyle(fontFamily: displayFont, fontSize: cr * 1.15, color: text, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, cc - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(NorenPainter o) => o.sway != sway || o.color != color || o.crest != crest;
}

/// Page route that drops a noren over the old page and lifts it off the
/// new one, like walking through a shop entrance.
class NorenRoute<T> extends PageRouteBuilder<T> {
  NorenRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 620),
          reverseTransitionDuration: const Duration(milliseconds: 520),
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, a, _, child) {
            final reduce = AppScope.read(context).settings.reduceMotion(context);
            if (reduce) return FadeTransition(opacity: a, child: child);
            final pal = context.palette;
            return AnimatedBuilder(
              animation: a,
              child: child,
              builder: (context, child) {
                final t = a.value;
                final cover = t < .5 ? Curves.easeOutCubic.transform(t / .5) : 1 - Curves.easeInCubic.transform((t - .5) / .5);
                if (cover < .01) return Opacity(opacity: t < .5 ? 0 : 1, child: child);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(opacity: t < .5 ? 0 : 1, child: child),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: math.max(.001, cover * 1.02),
                          widthFactor: 1,
                          child: CustomPaint(painter: NorenPainter(color: pal.noren, text: pal.onNoren, sway: (1 - cover) * .6, panels: 4)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
}

// ======================================================================
// Dialogs
// ======================================================================

/// A notice pinned to the wall with tape.
Future<T?> showNotice<T>(
  BuildContext context, {
  required String title,
  Widget? art,
  required Widget body,
  required List<Widget> actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: const Color(0x66201810),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) {
      final pal = context.palette;
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                type: MaterialType.transparency,
                child: PaperSlip(
                  tape: true,
                  tilt: -1.2,
                  seed: 17,
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (art != null) ...[art, const SizedBox(height: 10)],
                      Text(title, textAlign: TextAlign.center, style: display(24, pal.ink)),
                      const SizedBox(height: 10),
                      DefaultTextStyle(
                        style: TextStyle(fontFamily: fontFamily, color: pal.ink, fontSize: 15, height: 1.65, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                        child: body,
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: a)],
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
  );
}

// ======================================================================
// Small pictures used outside the board
// ======================================================================

class GimmickIcon extends StatelessWidget {
  const GimmickIcon(this.id, {super.key, this.size = 32});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(size: Size.square(size), painter: _GimmickPainter(id, pal));
  }
}

class _GimmickPainter extends CustomPainter {
  _GimmickPainter(this.id, this.pal);
  final String id;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width;
    final c = Offset(u / 2, u / 2);
    switch (id) {
      case 'counter':
        Art.counter(canvas, Offset.zero, u, pal, used: false);
      case 'tray':
        Art.tray(canvas, c, u);
      case 'oneWay':
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(u * .06, u * .06, u * .88, u * .88), Radius.circular(u * .14));
        canvas.drawRRect(r, Art.fill(const Color(0xFFBDB5A5)));
        canvas.drawRRect(r, Art.stroke(kInk, u * .03));
        Art.paintedArrow(canvas, c, u, Dir.right);
      default:
        Art.floorDish(canvas, c, u, 'a');
    }
  }

  @override
  bool shouldRepaint(_GimmickPainter old) => old.id != id || old.pal != pal;
}

class DishIcon extends StatelessWidget {
  const DishIcon(this.kind, {super.key, this.size = 28});
  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _DishPainter(kind));
}

class _DishPainter extends CustomPainter {
  _DishPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas, Size size) => Art.food(canvas, size.center(Offset.zero), size.width, kind);
  @override
  bool shouldRepaint(_DishPainter old) => old.kind != kind;
}

/// The courier on their own, for menus and speech.
class CourierPortrait extends StatelessWidget {
  const CourierPortrait({super.key, this.size = 56, this.look = Dir.down, this.stack = const []});
  final double size;
  final Dir look;
  final List<String> stack;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(size: Size(size, size * (1 + stack.length * .18)), painter: _CourierPainter(pal, look, stack));
  }
}

class _CourierPainter extends CustomPainter {
  _CourierPainter(this.pal, this.look, this.stack);
  final Palette pal;
  final Dir look;
  final List<String> stack;
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width;
    final head = Offset(u / 2, size.height - u * .58);
    Art.courier(canvas, head, u, look, pal);
    for (var k = 0; k < stack.length; k++) {
      Art.stackDish(canvas, head + Offset(0, -u * .3 - k * u * .16), u * 1.1, stack[k]);
    }
  }

  @override
  bool shouldRepaint(_CourierPainter o) => o.pal != pal || o.look != look || o.stack.join() != stack.join();
}

/// A wooden picture frame around [child] (a small diorama).
class WoodFrame extends StatelessWidget {
  const WoodFrame({super.key, required this.child, this.width = 12});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      painter: _WoodFramePainter(pal, width),
      child: Padding(padding: EdgeInsets.all(width), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child)),
    );
  }
}

class _WoodFramePainter extends CustomPainter {
  _WoodFramePainter(this.pal, this.w);
  final Palette pal;
  final double w;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = Wob.rrect(r.deflate(1), 14, seed: 41, amp: 1.1);
    canvas.drawPath(outer.shift(const Offset(0, 4)), Paint()..color = const Color(0x3A000000));
    canvas.drawPath(outer, Paint()..color = pal.woodDark);
    canvas.save();
    canvas.clipPath(outer);
    PaperGrain.paint(canvas, r);
    canvas.restore();
    canvas.drawPath(outer, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kInk);
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(w - 1.5), const Radius.circular(7)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = kInk);
  }

  @override
  bool shouldRepaint(_WoodFramePainter o) => o.pal != pal;
}
