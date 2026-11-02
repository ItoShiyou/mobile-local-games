import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Hand-drawn geometry: shapes whose outline wanders slightly, like a line
/// drawn with a brush. Deterministic for a given seed, so a shape keeps the
/// same wobble from frame to frame.
class Wob {
  static double _n(double t, int seed) {
    final s1 = (seed * 12.9898) % 6.28, s2 = (seed * 78.233) % 6.28;
    return math.sin(t * .09 + s1) * .6 + math.sin(t * .23 + s2) * .4;
  }

  /// Samples [base] every [step] px and pushes each point along its normal.
  static Path around(Path base, {int seed = 0, double amp = 1.2, double step = 5}) {
    final out = Path();
    for (final m in base.computeMetrics()) {
      final n = math.max(8, (m.length / step).round());
      for (var i = 0; i <= n; i++) {
        final d = m.length * i / n;
        final t = m.getTangentForOffset(d)!;
        final normal = Offset(-t.vector.dy, t.vector.dx);
        final p = t.position + normal * (_n(d, seed) * amp);
        if (i == 0) {
          out.moveTo(p.dx, p.dy);
        } else {
          out.lineTo(p.dx, p.dy);
        }
      }
      if (m.isClosed) out.close();
    }
    return out;
  }

  static Path rrect(Rect r, double radius, {int seed = 0, double amp = 1.2}) =>
      around(Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))), seed: seed, amp: amp);

  static Path oval(Rect r, {int seed = 0, double amp = 1.0}) => around(Path()..addOval(r), seed: seed, amp: amp);

  static Path line(Offset a, Offset b, {int seed = 0, double amp = 1.0}) =>
      around(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), seed: seed, amp: amp);
}

/// A small tileable paper texture: specks and short fibres.
class PaperGrain {
  static ui.Image? _image;

  static ui.Image? get image {
    if (_image != null) return _image;
    try {
      const size = 256.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final rnd = math.Random(7);
      for (var i = 0; i < 1400; i++) {
        final dark = rnd.nextBool();
        final p = Paint()..color = (dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF)).withValues(alpha: rnd.nextDouble() * .07);
        c.drawCircle(Offset(rnd.nextDouble() * size, rnd.nextDouble() * size), rnd.nextDouble() * 1.1 + .3, p);
      }
      for (var i = 0; i < 90; i++) {
        final o = Offset(rnd.nextDouble() * size, rnd.nextDouble() * size);
        final a = rnd.nextDouble() * math.pi;
        final l = rnd.nextDouble() * 10 + 4;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF6B4A2A).withValues(alpha: rnd.nextDouble() * .06 + .02)
          ..strokeWidth = rnd.nextDouble() * .7 + .3;
        final path = Path()
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(o.dx + math.cos(a) * l * .5 + 2, o.dy + math.sin(a) * l * .5 - 2, o.dx + math.cos(a) * l,
              o.dy + math.sin(a) * l);
        c.drawPath(path, p);
      }
      _image = rec.endRecording().toImageSync(size.toInt(), size.toInt());
    } catch (_) {
      _image = null;
    }
    return _image;
  }

  /// Paints the grain over [rect] (already filled with a base colour).
  static void paint(Canvas canvas, Rect rect, {double opacity = 1}) {
    final img = image;
    if (img == null) return;
    final paint = Paint()
      ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.drawRect(rect, paint);
  }
}

/// The texture of a hand-pulled print over flat colour: uneven ink coverage
/// (mottled where the baren pressed less), starved specks where the paper
/// shows through, and faint circular baren strokes. Laid over flat fills so
/// a large area of one colour never reads as a perfect digital fill.
class PrintGrain {
  static ui.Image? _image;
  static const double _size = 320;

  static ui.Image? get image {
    if (_image != null) return _image;
    try {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final rnd = math.Random(11);
      // wrap every mark so the tile repeats without a seam
      void wrapped(void Function(Offset shift) draw) {
        for (final dx in [-_size, 0.0, _size]) {
          for (final dy in [-_size, 0.0, _size]) {
            draw(Offset(dx, dy));
          }
        }
      }

      // mottling: large, soft, uneven patches (blurred once, here, not per frame)
      for (var i = 0; i < 46; i++) {
        final o = Offset(rnd.nextDouble() * _size, rnd.nextDouble() * _size);
        final r = rnd.nextDouble() * 26 + 8;
        final light = rnd.nextDouble() < .6;
        final p = Paint()
          ..color = (light ? const Color(0xFFFFFFFF) : const Color(0xFF2A1A10)).withValues(alpha: rnd.nextDouble() * .05 + .025)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .45);
        final sx = rnd.nextDouble() * .8 + .6;
        wrapped((s) => c.drawOval(Rect.fromCenter(center: o + s, width: r * 2 * sx, height: r * 2 / sx), p));
      }
      // baren swirls
      for (var i = 0; i < 26; i++) {
        final o = Offset(rnd.nextDouble() * _size, rnd.nextDouble() * _size);
        final r = rnd.nextDouble() * 18 + 10;
        final a0 = rnd.nextDouble() * math.pi * 2;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rnd.nextDouble() * 1.6 + .6
          ..color = const Color(0xFFFFFFFF).withValues(alpha: rnd.nextDouble() * .025 + .015);
        final sweep = rnd.nextDouble() * 1.2 + .8;
        wrapped((s) => c.drawArc(Rect.fromCircle(center: o + s, radius: r), a0, sweep, false, p));
      }
      // starved specks: tiny gaps where ink did not take
      for (var i = 0; i < 700; i++) {
        final o = Offset(rnd.nextDouble() * _size, rnd.nextDouble() * _size);
        final p = Paint()..color = const Color(0xFFFFFBF0).withValues(alpha: rnd.nextDouble() * .22 + .05);
        c.drawRect(Rect.fromCenter(center: o, width: rnd.nextDouble() * 1.4 + .4, height: rnd.nextDouble() * .9 + .3), p);
      }
      _image = rec.endRecording().toImageSync(_size.toInt(), _size.toInt());
    } catch (_) {
      _image = null;
    }
    return _image;
  }

  static void paint(Canvas canvas, Rect rect, {double opacity = 1}) {
    final img = image;
    if (img == null) return;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
          ..color = Color.fromRGBO(0, 0, 0, opacity));
  }
}

/// Page background: washi with fibres and uneven print coverage. No
/// airbrushed vignette: depth comes from the things drawn on it.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(painter: _PaperPainter(pal), child: child);
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.pal);
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = pal.paper);
    PaperGrain.paint(canvas, r, opacity: pal.night ? .7 : 1);
    PrintGrain.paint(canvas, r, opacity: pal.night ? .5 : .9);
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.pal != pal;
}

/// A slip of paper (a card) with a wobbly edge and a soft shadow.
class PaperSlip extends StatelessWidget {
  const PaperSlip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.seed = 1,
    this.tilt = 0,
    this.tape = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final int seed;

  /// Rotation in degrees, for a hand-placed look.
  final double tilt;

  /// Draw two strips of masking tape at the top corners.
  final bool tape;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Transform.rotate(
      angle: tilt * math.pi / 180,
      child: CustomPaint(
        painter: _SlipPainter(color ?? pal.card, pal, seed, tape),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _SlipPainter extends CustomPainter {
  _SlipPainter(this.color, this.pal, this.seed, this.tape);
  final Color color;
  final Palette pal;
  final int seed;
  final bool tape;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final path = Wob.rrect(r.deflate(1), 5, seed: seed, amp: 1.1);
    // a hard, offset shadow: the slip lies on the page, it does not float
    canvas.drawPath(path.shift(const Offset(2.5, 3)), Paint()..color = const Color(0x24301808));
    canvas.drawPath(path, Paint()..color = color);
    canvas.save();
    canvas.clipPath(path);
    PaperGrain.paint(canvas, r, opacity: .8);
    PrintGrain.paint(canvas, r, opacity: .6);
    canvas.restore();
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = pal.ink.withValues(alpha: .3));
    if (tape) {
      final tp = Paint()..color = const Color(0xAAE9D9A6);
      for (final (x, a) in [(size.width * .12, -.35), (size.width * .88, .3)]) {
        canvas.save();
        canvas.translate(x, 2);
        canvas.rotate(a);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 46, height: 16), tp);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_SlipPainter old) => old.color != color || old.seed != seed || old.pal != pal || old.tape != tape;
}
