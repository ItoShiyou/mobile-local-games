import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'art.dart';
import 'paper.dart';
import 'scene.dart';

int _h(int a, int b) {
  var h = a * 374761393 + b * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// The wall of the shop, seen from inside, filling the whole screen behind
/// the board. Each scene has its own wall; at night it is lamp-lit.
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({super.key, required this.scene, required this.child});
  final Scene scene;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(painter: _BackdropPainter(scene, pal, pal.night || scene.alwaysNight), child: child);
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.sc, this.pal, this.night);
  final Scene sc;
  final Palette pal;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final w = size.width, h = size.height;
    switch (sc.wall) {
      case WallKind.plaster:
        canvas.drawRect(r, Art.fill(const Color(0xFFFAF1DE)));
        // wooden posts and a lintel beam
        for (final x in [w * .02, w * .98]) {
          canvas.drawRect(Rect.fromCenter(center: Offset(x, h / 2), width: 18, height: h), Art.fill(sc.wallTrim));
        }
        _wainscot(canvas, Rect.fromLTWH(0, h * .74, w, h * .26), const Color(0xFFD9B283), vertical: true);
        canvas.drawRect(Rect.fromLTWH(0, h * .735, w, 10), Art.fill(sc.wallTrim));
      case WallKind.tiles:
        canvas.drawRect(r, Art.fill(const Color(0xFFEDE4D0)));
        final tiles = Rect.fromLTWH(0, h * .5, w, h * .5);
        canvas.drawRect(tiles, Art.fill(sc.wallFront));
        final t = 22.0;
        final line = Art.stroke(const Color(0x40FFFFFF), 1.4);
        for (var y = tiles.top; y < h; y += t) {
          canvas.drawLine(Offset(0, y), Offset(w, y), line);
        }
        for (var x = 0.0; x < w; x += t) {
          canvas.drawLine(Offset(x, tiles.top), Offset(x, h), line);
        }
        canvas.drawRect(Rect.fromLTWH(0, tiles.top - 6, w, 8), Art.fill(sc.wallTrim));
      case WallKind.brick:
        canvas.drawRect(r, Art.fill(const Color(0xFFC07A5C)));
        const bh = 18.0, bw = 44.0;
        final mortar = Art.stroke(const Color(0xFFE6CDB6), 2);
        for (var row = 0; row * bh < h; row++) {
          final y = row * bh;
          canvas.drawLine(Offset(0, y), Offset(w, y), mortar);
          for (var x = (row.isOdd ? bw / 2 : 0.0); x < w; x += bw) {
            canvas.drawLine(Offset(x, y), Offset(x, y + bh), mortar);
            final tone = _h(row, x.toInt()) % 5;
            if (tone == 0) canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, bw - 2, bh - 2), Art.fill(const Color(0x14000000)));
          }
        }
        canvas.drawRect(Rect.fromLTWH(0, h * .7, w, 12), Art.fill(sc.wallTrim));
      case WallKind.fence:
        final sky = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night ? const [Color(0xFF1B2440), Color(0xFF3A3F5C)] : const [Color(0xFFBFD9E6), Color(0xFFEDE6D2)],
        );
        canvas.drawRect(r, Paint()..shader = sky.createShader(r));
        // rooftops far away
        final roof = Path()..moveTo(0, h * .2);
        for (var i = 0; i <= 8; i++) {
          final x = w * i / 8;
          roof
            ..lineTo(x + w / 32, h * (.16 + (_h(i, 3) % 5) / 100))
            ..lineTo(x + w / 8, h * .2);
        }
        roof
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(roof, Art.fill(night ? const Color(0xFF2A2F45) : const Color(0xFF8C9AA6)));
        // board fence
        final fence = Rect.fromLTWH(0, h * .26, w, h * .74);
        _wainscot(canvas, fence, sc.wallFront, vertical: true, board: 26);
        canvas.drawRect(Rect.fromLTWH(0, fence.top, w, 8), Art.fill(sc.wallTrim));
      case WallKind.stalls:
        const sky = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141A33), Color(0xFF2C2A4A), Color(0xFF3E3350)],
        );
        canvas.drawRect(r, Paint()..shader = sky.createShader(r));
        final rnd = math.Random(5);
        for (var i = 0; i < 60; i++) {
          canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * .5), rnd.nextDouble() * 1.2 + .3,
              Art.fill(Colors.white.withValues(alpha: rnd.nextDouble() * .6 + .2)));
        }
        // trees
        for (var i = 0; i < 9; i++) {
          canvas.drawCircle(Offset(w * i / 8, h * .82), w * .14, Art.fill(const Color(0xFF1E2A22)));
        }
        canvas.drawRect(Rect.fromLTWH(0, h * .84, w, h * .16), Art.fill(const Color(0xFF1E2A22)));
    }
    _wallThings(canvas, size);
    PaperGrain.paint(canvas, r);
    if (night && sc.wall != WallKind.stalls && sc.wall != WallKind.fence) {
      canvas.drawRect(r, Paint()
        ..color = const Color(0xFFB4AAB4)
        ..blendMode = BlendMode.multiply);
    }
    // lantern strings across the top at night / at the festival
    if (sc.wall == WallKind.stalls || (night && sc.wall == WallKind.fence)) {
      _lanternString(canvas, w, h * .22, 7, 1);
    }
  }

  /// Things on the wall, where the room does not cover it: a row of menu
  /// strips under the beam, a clock, a calendar, a framed picture.
  void _wallThings(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final y0 = h * .235;
    if (sc.wall == WallKind.plaster || sc.wall == WallKind.tiles) {
      // a ranma (carved transom) band under the ceiling, lattice in wood
      final band = Rect.fromLTWH(0, y0 - 6, w, 40);
      c.drawRect(band, Art.fill(sc.wallTrim));
      final inner = band.deflate(5);
      c.drawRect(inner, Art.fill(const Color(0xFFF3E8D2)));
      final lattice = Art.stroke(sc.wallTrim, 2);
      for (var x = inner.left; x < inner.right; x += 22) {
        c.drawLine(Offset(x, inner.top), Offset(x + 11, inner.center.dy), lattice);
        c.drawLine(Offset(x + 11, inner.center.dy), Offset(x, inner.bottom), lattice);
        c.drawLine(Offset(x + 11, inner.center.dy), Offset(x + 22, inner.top), lattice);
        c.drawLine(Offset(x + 11, inner.center.dy), Offset(x + 22, inner.bottom), lattice);
      }
      c.drawRect(band, Art.stroke(kInk, 1.4));
      // a hanging scroll and a small flower vase lower on the wall
      final scroll = Rect.fromLTWH(w * .8, h * .36, 34, 78);
      c.drawRect(scroll.inflate(3), Art.fill(const Color(0xFF6B8A73)));
      Art.inked(c, Path()..addRect(scroll), const Color(0xFFFBF5E6), 1.2);
      for (var k = 0; k < 3; k++) {
        c.drawLine(scroll.topCenter + Offset(0, 14 + k * 16.0), scroll.topCenter + Offset(0, 24 + k * 16.0), Art.stroke(kInk.withValues(alpha: .7), 2.2));
      }
      c.drawLine(Offset(scroll.left - 5, scroll.bottom + 3), Offset(scroll.right + 5, scroll.bottom + 3), Art.stroke(const Color(0xFF3A2618), 4));
      final vase = Offset(w * .13, h * .47);
      Art.inked(c, Path()..addOval(Rect.fromCenter(center: vase, width: 16, height: 22)), const Color(0xFF7A8FA6), 1.2);
      for (final (dx, dy) in [(-6.0, -20.0), (5.0, -24.0), (0.0, -16.0)]) {
        c.drawLine(vase + const Offset(0, -9), vase + Offset(dx, dy), Art.stroke(const Color(0xFF5E7A45), 1.6));
        c.drawCircle(vase + Offset(dx, dy), 3.5, Art.fill(pal.shu.withValues(alpha: .85)));
      }
    } else if (sc.wall == WallKind.brick) {
      // framed pictures and wall lamps in the cafe
      for (final (x, y, fw, fh) in [(w * .1, h * .27, 70.0, 52.0), (w * .62, h * .3, 60.0, 76.0)]) {
        final fr = Rect.fromLTWH(x, y, fw, fh);
        Art.inked(c, Path()..addRect(fr), const Color(0xFF3A2618), 1.6);
        c.drawRect(fr.deflate(6), Art.fill(const Color(0xFFE8D9B8)));
        c.drawCircle(fr.center + const Offset(-6, 4), fw * .14, Art.fill(const Color(0xFF7FA58F)));
        c.drawCircle(fr.center + const Offset(8, -6), fw * .1, Art.fill(pal.shu.withValues(alpha: .7)));
      }
    }
  }

  void _wainscot(Canvas c, Rect r, Color col, {required bool vertical, double board = 20}) {
    c.drawRect(r, Art.fill(col));
    final line = Art.stroke(const Color(0x33000000), 1.2);
    for (var x = r.left; x < r.right; x += board) {
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), line);
      final k = _h(x.toInt(), 7) % 4;
      if (k == 0) c.drawRect(Rect.fromLTWH(x + 1, r.top, board - 2, r.height), Art.fill(const Color(0x10000000)));
    }
  }

  void _lanternString(Canvas c, double w, double y, int n, int seed) {
    final rope = Path()..moveTo(0, y);
    rope.quadraticBezierTo(w / 2, y + 40, w, y);
    c.drawPath(rope, Art.stroke(const Color(0xFF3A2B22), 1.6));
    for (var i = 1; i < n; i++) {
      final t = i / n;
      final p = Offset(w * t, y + 40 * 2 * t * (1 - t) * 1.0 + 4);
      final glow = Rect.fromCircle(center: p + const Offset(0, 12), radius: 34);
      c.drawCircle(p + const Offset(0, 12), 34, Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(colors: [pal.glow.withValues(alpha: .45), pal.glow.withValues(alpha: 0)]).createShader(glow));
      final body = Rect.fromCenter(center: p + const Offset(0, 12), width: 16, height: 20);
      Art.inked(c, Path()..addOval(body), (i + seed).isEven ? const Color(0xFFE0493A) : const Color(0xFFF6E7C8), 1.4);
      c.drawRect(Rect.fromCenter(center: body.topCenter, width: 8, height: 3), Art.fill(kInk));
      c.drawRect(Rect.fromCenter(center: body.bottomCenter, width: 8, height: 3), Art.fill(kInk));
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter o) => o.sc != sc || o.pal != pal || o.night != night;
}

/// A wooden desk top (for the notebook and the picture book).
class DeskBackground extends StatelessWidget {
  const DeskBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DeskPainter(context.palette), child: child);
}

class _DeskPainter extends CustomPainter {
  _DeskPainter(this.pal);
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final base = pal.night ? const Color(0xFF7A5A40) : const Color(0xFFCFA676);
    canvas.drawRect(r, Art.fill(base));
    const plank = 64.0;
    for (var y = 0.0, i = 0; y < size.height; y += plank, i++) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, plank), Art.fill(Color.lerp(base, Colors.black, (_h(i, 1) % 3) * .04)!));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Art.stroke(const Color(0x40000000), 1.5));
      for (var k = 0; k < 3; k++) {
        final gy = y + plank * (.25 + k * .25);
        canvas.drawPath(
            Path()
              ..moveTo(0, gy)
              ..cubicTo(size.width * .3, gy - 4, size.width * .6, gy + 5, size.width, gy),
            Art.stroke(const Color(0x1A000000), 1));
      }
    }
    PaperGrain.paint(canvas, r);
    canvas.drawRect(
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x00000000), Color(0x30000000)], stops: [.6, 1], radius: 1).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_DeskPainter o) => o.pal != pal;
}

/// A wooden beam across the top of the screen (the kitchen pass).
class BeamPainter extends CustomPainter {
  BeamPainter(this.pal, {this.height = 18});
  final Palette pal;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(-4, 0, size.width + 8, height);
    canvas.drawRect(r.shift(const Offset(0, 4)), Art.fill(const Color(0x33000000)));
    canvas.drawRect(r, Art.fill(Color.lerp(pal.woodDark, pal.wood, .35)!));
    canvas.drawLine(r.bottomLeft, r.bottomRight, Art.stroke(kInk, 2));
    canvas.drawLine(r.topLeft + const Offset(0, 5), r.topRight + const Offset(0, 5), Art.stroke(const Color(0x22FFFFFF), 1.5));
  }

  @override
  bool shouldRepaint(BeamPainter o) => o.pal != pal;
}

/// The counter along the bottom of the screen, where the tray and the
/// wooden tags sit.
class CounterPainter extends CustomPainter {
  CounterPainter(this.pal);
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = Rect.fromLTWH(-4, 0, w + 8, 26);
    final front = Rect.fromLTWH(-4, 26, w + 8, h - 26);
    canvas.drawRect(top.shift(const Offset(0, -5)), Art.fill(const Color(0x33000000)));
    canvas.drawRect(front, Art.fill(Color.lerp(pal.woodDark, pal.wood, .45)!));
    for (var x = 0.0; x < w; x += 34) {
      canvas.drawLine(Offset(x, front.top), Offset(x, h), Art.stroke(const Color(0x33000000), 1.2));
    }
    canvas.drawRect(top, Art.fill(pal.wood));
    for (var k = 0; k < 3; k++) {
      final y = 5.0 + k * 7;
      canvas.drawPath(Path()..moveTo(0, y)..cubicTo(w * .3, y - 2, w * .6, y + 3, w, y), Art.stroke(const Color(0x22000000), 1));
    }
    canvas.drawLine(top.topLeft, top.topRight, Art.stroke(kInk, 2));
    canvas.drawLine(top.bottomLeft, top.bottomRight, Art.stroke(kInk, 2));
    PaperGrain.paint(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(CounterPainter o) => o.pal != pal;
}
