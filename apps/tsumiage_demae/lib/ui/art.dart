import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/engine.dart';
import 'paper.dart';
import 'sprites.dart';

/// Sumi-brown ink used for every outline on the board.
const kInk = Color(0xFF33251E);

/// Where the ink pools: light comes from the top left, so every outline is
/// thin on that side and heavy on the shadow side (bottom right).
const Offset kInkWeight = Offset(.5, .65);

/// The colour "block" is printed a hair off the key block, up and to the
/// left, like a woodblock or risograph pass that did not quite line up.
const Offset kRegistration = Offset(-.7, -.5);

enum Mood { waiting, upset, happy }

/// Picture-book sprites. Everything is drawn with a warm ink outline so the
/// board reads as one illustration rather than a set of flat shapes.
class Art {
  // A fresh Paint per call: some renderers keep a reference to the Paint
  // rather than copying it, so a shared, mutated Paint would change colours
  // that were already drawn.
  static Paint fill(Color c) => Paint()
    ..isAntiAlias = true
    ..color = c;
  static Paint stroke(Color c, double w) => Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c
    ..strokeWidth = w;

  static RRect rr(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  /// Fill then outline, printed rather than vector-stroked: a heavier ink
  /// edge on the shadow side, the colour slightly off register, and a
  /// thinner key line on top. Three draws, no path work, so it is cheap
  /// enough for sprites that repaint every frame.
  static void inked(Canvas c, Path p, Color color, double w) {
    final wo = kInkWeight * w, ro = kRegistration * w;
    c.save();
    c.translate(wo.dx, wo.dy);
    c.drawPath(p, fill(kInk));
    c.translate(ro.dx - wo.dx, ro.dy - wo.dy);
    c.drawPath(p, fill(color));
    c.restore();
    c.drawPath(p, stroke(kInk, w * .72));
  }

  /// A cast shadow: flat and hard-edged, the way a print would do it.
  static void shadow(Canvas c, Offset center, double w, double h, [double a = .22]) {
    c.drawOval(Rect.fromCenter(center: center + Offset(w * .06, 0), width: w, height: h), fill(Color.fromRGBO(60, 30, 20, a)));
  }

  /// A highlight that is unprinted paper rather than gloss: a short,
  /// slightly bent sliver of the paper colour.
  static void nick(Canvas c, Offset at, double len, double w, {double angle = -.5, Color color = const Color(0xE6FFF8EA)}) {
    final d = Offset(math.cos(angle), math.sin(angle)) * (len / 2);
    final n = Offset(-d.dy, d.dx) * .35;
    c.drawPath(
        Path()
          ..moveTo(at.dx - d.dx, at.dy - d.dy)
          ..quadraticBezierTo(at.dx + n.dx, at.dy + n.dy, at.dx + d.dx, at.dy + d.dy),
        stroke(color, w));
  }

  /// Brush writing in a vertical column (menu strips, posters), as it looks
  /// from across the room: runs of joined, zig-zagging strokes with gaps
  /// between words and a brush that thickens and thins. No letter shapes,
  /// so it never reads as garbled text and needs no translation.
  static void scribble(Canvas c, Offset top, double length, double size, int seed, Color color) {
    var h = (seed * 7919 + 17) & 0x7fffffff;
    int next(int m) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      return (h >> 8) % m;
    }

    var y = top.dy + size * .25;
    final end = top.dy + length;
    while (y < end - size * .6) {
      final yEnd = math.min(end, y + size * (1.1 + next(5) * .45));
      final path = Path()..moveTo(top.dx + (next(3) - 1) * size * .12, y);
      var k = 0;
      var yy = y;
      while (true) {
        final step = size * (.3 + next(4) * .07);
        if (yy + step > yEnd) break;
        k++;
        final kind = next(4);
        if (kind == 0) {
          // a straight downstroke, ending in a small hook
          path
            ..lineTo(top.dx + (next(3) - 1) * size * .04, yy + step * 1.4)
            ..relativeLineTo(size * (next(2) == 0 ? .14 : -.14), -size * .1);
          yy += step * 1.4;
        } else {
          final side = k.isOdd ? 1 : -1;
          final x = top.dx + side * size * (.1 + next(4) * .07);
          path.quadraticBezierTo(top.dx - side * size * .08, yy + step * .35, x, yy + step);
          yy += step;
        }
      }
      c.drawPath(path, stroke(color, size * (.13 + next(4) * .035)));
      // now and then a dot or a short tick beside the column
      if (next(3) == 0) c.drawCircle(Offset(top.dx + size * .32, y + size * .2), size * .08, fill(color));
      y = yEnd + size * (.35 + next(3) * .15);
    }
  }

  /// A pool of lamp light in two flat steps, like a block-printed bokashi
  /// instead of a smooth airbrushed glow. The brighter core sits a little
  /// below the lamp, where the light lands. [rough] gives the edges a
  /// cut-by-hand wobble (for cached layers; it costs path work).
  static void lightPool(Canvas c, Offset o, double r, Color glow, double a, {bool rough = false}) {
    final outer = Rect.fromCircle(center: o, radius: r);
    final inner = Rect.fromCenter(center: o + Offset(r * .04, r * .1), width: r * 1.1, height: r * 1.0);
    // overlay keeps the warm colour saturated where screen would turn it
    // to a grey haze on the dark evening colours
    final po = Paint()
      ..blendMode = BlendMode.overlay
      ..color = glow.withValues(alpha: a * .7);
    final pi = Paint()
      ..blendMode = BlendMode.overlay
      ..color = glow.withValues(alpha: a * .9);
    if (rough) {
      c.drawPath(Wob.oval(outer, seed: o.dx.toInt(), amp: r * .03), po);
      c.drawPath(Wob.oval(inner, seed: o.dy.toInt(), amp: r * .025), pi);
    } else {
      c.drawOval(outer, po);
      c.drawOval(inner, pi);
    }
  }

  // ---------------------------------------------------------------- food

  /// Food only (no plate), centred at [c], roughly [s] wide.
  static void food(Canvas canvas, Offset c, double s, String kind) {
    final w = math.max(1.0, s * .05);
    final col = dishColors[kind]!;
    switch (kind) {
      case 'a': // tomato
        // a real tomato is lumpy and wider than it is tall
        final body = Path()
          ..moveTo(c.dx, c.dy - s * .3)
          ..cubicTo(c.dx + s * .3, c.dy - s * .38, c.dx + s * .44, c.dy - s * .08, c.dx + s * .37, c.dy + s * .17)
          ..cubicTo(c.dx + s * .3, c.dy + s * .42, c.dx - s * .26, c.dy + s * .44, c.dx - s * .36, c.dy + s * .2)
          ..cubicTo(c.dx - s * .46, c.dy - s * .04, c.dx - s * .3, c.dy - s * .4, c.dx, c.dy - s * .3)
          ..close();
        inked(canvas, body, col, w);
        canvas.drawArc(Rect.fromCenter(center: c + Offset(s * .05, s * .07), width: s * .5, height: s * .5), .3, 1.3, false,
            stroke(const Color(0x33601810), w * 1.6));
        nick(canvas, c + Offset(-s * .19, -s * .08), s * .14, w * 1.1, angle: -1.1);
        final calyx = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final tip = c + Offset(math.cos(a) * s * .2, -s * .3 + math.sin(a) * s * .1);
          final l = c + Offset(math.cos(a - .5) * s * .06, -s * .3 + math.sin(a - .5) * s * .04);
          final r = c + Offset(math.cos(a + .5) * s * .06, -s * .3 + math.sin(a + .5) * s * .04);
          calyx
            ..moveTo(l.dx, l.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(r.dx, r.dy);
        }
        calyx.close();
        inked(canvas, calyx, const Color(0xFF4E8A3E), w * .8);
        canvas.drawLine(c + Offset(0, -s * .32), c + Offset(s * .04, -s * .44), stroke(kInk, w));
      case 'b': // matcha dango on a skewer
        canvas.drawLine(c + Offset(-s * .46, s * .3), c + Offset(s * .46, -s * .3), stroke(kInk, w * 2.4));
        canvas.drawLine(c + Offset(-s * .46, s * .3), c + Offset(s * .46, -s * .3), stroke(const Color(0xFFD8B27A), w * 1.2));
        for (var i = -1; i <= 1; i++) {
          final p = c + Offset(i * s * .25, -i * s * .165);
          final r = s * (.17 + i * .006);
          inked(canvas, Path()..addOval(Rect.fromCenter(center: p, width: r * 2.04, height: r * 1.9)), i == 0 ? const Color(0xFFA9C46A) : col, w);
          if (i != 0) nick(canvas, p + Offset(-s * .06, -s * .05), s * .07, w * .9, angle: -1.2);
        }
      case 'c': // tamagoyaki
        final body = Path()..addRRect(rr(c.dx - s * .42, c.dy - s * .24, s * .84, s * .5, s * .14));
        inked(canvas, body, col, w);
        canvas.drawRRect(rr(c.dx - s * .42, c.dy + s * .08, s * .84, s * .18, s * .1), fill(const Color(0x33B8741A)));
        for (final dx in [-.14, .14]) {
          canvas.drawLine(c + Offset(s * dx, -s * .2), c + Offset(s * dx, s * .22), stroke(const Color(0xFFC98E1E), w));
        }
        canvas.drawLine(c + Offset(-s * .32, -s * .13), c + Offset(-s * .22, -s * .13), stroke(Colors.white.withValues(alpha: .7), w));
      default: // grapes
        canvas.drawLine(c + Offset(0, -s * .28), c + Offset(s * .06, -s * .44), stroke(kInk, w * 1.3));
        final leaf = Path()..addOval(Rect.fromCenter(center: c + Offset(s * .2, -s * .38), width: s * .26, height: s * .13));
        inked(canvas, leaf, const Color(0xFF6FA64E), w * .8);
        const pts = [(-.18, -.16), (0.0, -.2), (.18, -.16), (-.1, .02), (.1, .02), (0.0, .2)];
        for (var k = 0; k < pts.length; k++) {
          final (x, y) = pts[k];
          final g = k.isEven ? col : Color.lerp(col, kInk, .18)!;
          inked(canvas, Path()..addOval(Rect.fromCircle(center: c + Offset(x * s, y * s + s * .06), radius: s * (.125 + (k % 3) * .006))), g, w * .8);
          if (k == 0 || k == 3) nick(canvas, c + Offset(x * s - s * .045, y * s + s * .025), s * .05, w * .8, angle: -1.3);
        }
    }
  }

  /// A dish lying on the floor (seen from above).
  static void floorDish(Canvas canvas, Offset c, double u, String kind) {
    final w = u * .03;
    shadow(canvas, c + Offset(0, u * .12), u * .72, u * .38);
    final plate = Rect.fromCenter(center: c + Offset(0, u * .06), width: u * .72, height: u * .46);
    // every dish comes on its own kind of plate, as in a real diner where
    // nothing matches: blue-rimmed porcelain, a square mashiko plate,
    // a long plate for skewers, a dotted kobachi
    switch (kind) {
      case 'c':
        final sq = Rect.fromCenter(center: plate.center, width: u * .66, height: u * .44);
        inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(sq, Radius.circular(u * .06))), const Color(0xFFE9DCC4), w);
        canvas.drawRRect(RRect.fromRectAndRadius(sq.deflate(u * .05), Radius.circular(u * .03)), stroke(const Color(0x668A5A3A), w * .8));
      case 'b':
        final long = Rect.fromCenter(center: plate.center, width: u * .8, height: u * .38);
        inked(canvas, Path()..addOval(long), const Color(0xFFFFF9EC), w);
        canvas.drawArc(long.deflate(u * .03), math.pi * .1, .8, false, stroke(const Color(0xFF6E8E4E), w * .9));
      case 'd':
        inked(canvas, Path()..addOval(plate), const Color(0xFFFFF9EC), w);
        for (var i = 0; i < 9; i++) {
          final a = i * math.pi * 2 / 9 + .3;
          canvas.drawCircle(plate.center + Offset(math.cos(a) * plate.width * .43, math.sin(a) * plate.height * .41), u * .012, fill(const Color(0xFF3F6596)));
        }
      default:
        inked(canvas, Path()..addOval(plate), const Color(0xFFFFF9EC), w);
        canvas.drawOval(plate.deflate(u * .07), stroke(const Color(0xFFE2D8C4), w));
        canvas.drawArc(plate.deflate(u * .03), math.pi * 1.1, .9, false, stroke(const Color(0xFF3F6596), w * .9));
    }
    food(canvas, c + Offset(0, -u * .01), u * .46, kind);
  }

  /// A dish on the stack (side view): a plate rim with the food on it.
  static void stackDish(Canvas canvas, Offset c, double u, String kind, {bool highlight = false}) {
    final w = u * .028;
    final plate = Path()
      ..moveTo(c.dx - u * .3, c.dy - u * .02)
      ..quadraticBezierTo(c.dx, c.dy + u * .04, c.dx + u * .3, c.dy - u * .02)
      ..lineTo(c.dx + u * .2, c.dy + u * .07)
      ..lineTo(c.dx - u * .2, c.dy + u * .07)
      ..close();
    food(canvas, c + Offset(0, -u * .08), u * .27, kind);
    inked(canvas, plate, const Color(0xFFFFFCF4), w);
    canvas.drawLine(c + Offset(-u * .22, u * .005), c + Offset(u * .22, u * .005), stroke(const Color(0xFF4A6F9E), w * .8));
    if (highlight) {
      canvas.drawCircle(c + Offset(u * .3, -u * .1), u * .045, fill(const Color(0xFFFFC56B)));
    }
  }

  // ------------------------------------------------------------ courier

  /// How far above the head centre the first dish sits: the printed cat is
  /// taller than the vector one.
  static double stackBase(double u) => (CatSprites.pose('down') != null ? .45 : .3) * u;

  /// The printed cat. Feet stand where the shadow is; the ears reach the
  /// height the vector cat's did, so the dish stack still sits on the head.
  static bool _courierSprite(Canvas canvas, Offset c, double u, Dir look, double phase, double hop, bool happy) {
    final name = happy ? 'happy' : switch (look) { Dir.up => 'up', Dir.down => 'down', _ => 'right' };
    final img = CatSprites.pose(name);
    if (img == null) return false;
    final h = u * .92, wd = h * CatSprites.aspect;
    // a slow breath: the body squashes a hair about the feet
    final breathe = 1 + math.sin(phase * 2.4) * .012;
    final feet = Offset(c.dx, c.dy + u * .42 - hop);
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(look == Dir.left && !happy ? -1.0 : 1.0, breathe);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-wd / 2, -h, wd, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
    return true;
  }


  /// The delivery cat. [c] is the centre of the head. [phase] is the time
  /// in seconds for blinking and the tail.
  static void courier(Canvas canvas, Offset c, double u, Dir look, Palette pal,
      {double phase = 0, double hop = 0, bool happy = false}) {
    final w = u * .032;
    final head = c + Offset(0, -hop);
    shadow(canvas, c + Offset(0, u * .36), u * .52 - hop * .6, u * .16);
    if (_courierSprite(canvas, c, u, look, phase, hop, happy)) return;
    // tail
    final side = look == Dir.left ? 1.0 : -1.0;
    final sway = math.sin(phase * 3.2) * u * .05;
    final tail = Path()
      ..moveTo(c.dx + side * u * .16, c.dy + u * .3 - hop)
      ..cubicTo(c.dx + side * u * .42, c.dy + u * .32 - hop, c.dx + side * u * .38 + sway, c.dy + u * .05 - hop,
          c.dx + side * u * .3 + sway, c.dy - u * .02 - hop);
    // the tail is a brush stroke: ink laid down heavier on the shadow side,
    // the fur colour printed over it a little off register
    final wo = kInkWeight * w, ro = kRegistration * w;
    canvas.save();
    canvas.translate(wo.dx * .5, wo.dy * .5);
    canvas.drawPath(tail, stroke(kInk, u * .105));
    canvas.translate((ro.dx - wo.dx) * .5, (ro.dy - wo.dy) * .5);
    canvas.drawPath(tail, stroke(_fur, u * .064));
    canvas.restore();
    // body in a happi coat
    final body = Path()
      ..moveTo(head.dx - u * .21, head.dy + u * .36)
      ..quadraticBezierTo(head.dx - u * .24, head.dy + u * .14, head.dx - u * .12, head.dy + u * .12)
      ..lineTo(head.dx + u * .12, head.dy + u * .12)
      ..quadraticBezierTo(head.dx + u * .24, head.dy + u * .14, head.dx + u * .21, head.dy + u * .36)
      ..close();
    inked(canvas, body, pal.noren, w);
    // collar: the white lapels, slightly uneven like a hand-dyed band
    canvas.drawLine(head + Offset(-u * .1, u * .14), head + Offset(-u * .005, u * .33), stroke(const Color(0xFFF4EBD9), u * .05));
    canvas.drawLine(head + Offset(u * .1, u * .14), head + Offset(u * .005, u * .33), stroke(const Color(0xFFF4EBD9), u * .044));
    // ears: never quite a mirrored pair; the one on the far side of the
    // knot sits a touch lower and splays out
    for (final sx in [-1.0, 1.0]) {
      final far = sx == side;
      final tipY = far ? -.295 : -.315, tipX = far ? .215 : .195;
      final ear = Path()
        ..moveTo(head.dx + sx * u * .235, head.dy - u * .06)
        ..lineTo(head.dx + sx * u * tipX, head.dy + u * tipY)
        ..lineTo(head.dx + sx * u * .05, head.dy - u * .2)
        ..close();
      inked(canvas, ear, _fur, w);
      final inner = Path()
        ..moveTo(head.dx + sx * u * .2, head.dy - u * .1)
        ..lineTo(head.dx + sx * u * (tipX - .01), head.dy + u * (tipY + .06))
        ..lineTo(head.dx + sx * u * .1, head.dy - u * .18)
        ..close();
      canvas.drawPath(inner.shift(ro), fill(const Color(0xFFEFA7AF)));
    }
    // head
    final face = Path()..addOval(Rect.fromCenter(center: head, width: u * .56, height: u * .5));
    inked(canvas, face, _fur, w);
    // calico patch over one eye: an irregular shape, printed with the fur
    canvas.save();
    canvas.translate(ro.dx, ro.dy);
    canvas.clipPath(face);
    final p0 = head + Offset(-u * .16, -u * .12);
    canvas.drawPath(
        Path()
          ..moveTo(p0.dx - u * .2, p0.dy - u * .1)
          ..lineTo(p0.dx + u * .11, p0.dy - u * .14)
          ..cubicTo(p0.dx + u * .16, p0.dy - u * .04, p0.dx + u * .13, p0.dy + u * .06, p0.dx + u * .07, p0.dy + u * .1)
          ..cubicTo(p0.dx + u * .03, p0.dy + u * .15, p0.dx - u * .07, p0.dy + u * .13, p0.dx - u * .1, p0.dy + u * .16)
          ..lineTo(p0.dx - u * .2, p0.dy + u * .1)
          ..close(),
        fill(const Color(0xFFD69A5C)));
    canvas.restore();
    canvas.drawPath(face, stroke(kInk, w * .72));
    // cheek fur: two little tufts break the oval, one per side, not mirrored
    canvas.drawPath(
        Path()
          ..moveTo(head.dx - u * .272, head.dy + u * .05)
          ..lineTo(head.dx - u * .3, head.dy + u * .085)
          ..lineTo(head.dx - u * .262, head.dy + u * .1),
        stroke(kInk, w * .8));
    canvas.drawPath(
        Path()
          ..moveTo(head.dx + u * .262, head.dy + u * .085)
          ..lineTo(head.dx + u * .292, head.dy + u * .115)
          ..lineTo(head.dx + u * .245, head.dy + u * .135),
        stroke(kInk, w * .8));
    // hachimaki
    final band = Path()
      ..moveTo(head.dx - u * .27, head.dy - u * .06)
      ..quadraticBezierTo(head.dx, head.dy - u * .14, head.dx + u * .27, head.dy - u * .06)
      ..lineTo(head.dx + u * .26, head.dy - u * .01)
      ..quadraticBezierTo(head.dx, head.dy - u * .09, head.dx - u * .26, head.dy - u * .01)
      ..close();
    inked(canvas, band, pal.shu, w * .8);
    final knot = head + Offset(-side * u * .27, -u * .04);
    final flutter = math.sin(phase * 5) * u * .02;
    for (final (a, len) in [(-.5, .13), (.3, .11)]) {
      final tipOff = Offset(-side * u * len, a * u * .2 + flutter);
      final t = Path()
        ..moveTo(knot.dx, knot.dy)
        ..lineTo(knot.dx + tipOff.dx, knot.dy + tipOff.dy - u * .03)
        ..lineTo(knot.dx + tipOff.dx * .9, knot.dy + tipOff.dy + u * .03)
        ..close();
      inked(canvas, t, pal.shu, w * .7);
    }
    // eyes
    final lx = look.dx * u * .045, ly = look.dy * u * .03;
    final blink = (phase % 3.7) > 3.57;
    for (final sx in [-1.0, 1.0]) {
      final e = head + Offset(sx * u * .1 + lx, u * .03 + ly);
      if (blink) {
        canvas.drawArc(Rect.fromCenter(center: e, width: u * .09, height: u * .06), .2, math.pi - .4, false, stroke(kInk, w));
      } else {
        canvas.drawOval(Rect.fromCenter(center: e, width: u * .075, height: u * .095), fill(kInk));
        canvas.drawCircle(e + Offset(u * .014, -u * .018), u * .015, fill(const Color(0xFFFFFBF0)));
      }
    }
    // nose, mouth, whiskers, cheeks
    final m = head + Offset(lx, u * .12 + ly);
    canvas.drawCircle(m + Offset(0, -u * .02), u * .022, fill(const Color(0xFFDB6F7E)));
    canvas.drawArc(Rect.fromCenter(center: m + Offset(-u * .025, u * .005), width: u * .05, height: u * .04), .3, math.pi - .6, false, stroke(kInk, w * .7));
    canvas.drawArc(Rect.fromCenter(center: m + Offset(u * .025, u * .005), width: u * .05, height: u * .04), .3, math.pi - .6, false, stroke(kInk, w * .7));
    for (final sx in [-1.0, 1.0]) {
      // blush: a flat dab with a few quick hatch marks
      final bc = head + Offset(sx * u * .17, u * .09);
      canvas.drawOval(Rect.fromCenter(center: bc, width: u * .08, height: u * .055), fill(const Color(0x66EC8A96)));
      for (var k = -1; k <= 1; k++) {
        final o = bc + Offset(k * u * .018, 0);
        canvas.drawLine(o + Offset(u * .008, -u * .012), o + Offset(-u * .006, u * .012), stroke(const Color(0x99D9626F), w * .45));
      }
      // whiskers: a little curve, different on each side
      final wy = sx < 0 ? .0 : .012;
      canvas.drawPath(
          Path()
            ..moveTo(head.dx + sx * u * .2, head.dy + u * (.06 + wy))
            ..quadraticBezierTo(head.dx + sx * u * .27, head.dy + u * (.035 + wy), head.dx + sx * u * .34, head.dy + u * (.04 + wy)),
          stroke(kInk, w * .5));
      canvas.drawPath(
          Path()
            ..moveTo(head.dx + sx * u * .2, head.dy + u * (.1 + wy))
            ..quadraticBezierTo(head.dx + sx * u * .27, head.dy + u * (.105 + wy), head.dx + sx * u * (sx < 0 ? .33 : .31), head.dy + u * (.13 + wy)),
          stroke(kInk, w * .45));
    }
  }

  static const _fur = Color(0xFFFBF3E4);

  // ------------------------------------------------------------- guests

  static const _skin = [Color(0xFFF1CDAE), Color(0xFFEBC3A0), Color(0xFFF5D2B5), Color(0xFFE7BC98), Color(0xFFDDB08A)];
  static const _hair = [Color(0xFFD7D2CC), Color(0xFF2E2A2A), Color(0xFF5B3A26), Color(0xFF7A4A2E), Color(0xFF3A3030)];
  static const _clothes = [Color(0xFF8C6BAE), Color(0xFFF4F1EA), Color(0xFFE59A3A), Color(0xFF6E9C74), Color(0xFF3F5F86)];

  /// A seated guest behind a little table. [o] is the cell's top-left.
  static void guest(Canvas canvas, Offset o, double u, int index, Palette pal,
      {required Mood mood, double phase = 0, String? servedDish, double bob = 0}) {
    final type = index % 5;
    final w = u * .03;
    final cx = o.dx + u * .5;
    final headC = Offset(cx, o.dy + u * .36 + bob);
    // chair back
    // bentwood chair back: arched on top, square at the seat
    final chair = Path()
      ..moveTo(cx - u * .29, o.dy + u * .64)
      ..lineTo(cx - u * .3, o.dy + u * .3)
      ..quadraticBezierTo(cx - u * .29, o.dy + u * .13, cx + u * .02, o.dy + u * .14)
      ..quadraticBezierTo(cx + u * .3, o.dy + u * .15, cx + u * .3, o.dy + u * .32)
      ..lineTo(cx + u * .29, o.dy + u * .64)
      ..close();
    inked(canvas, chair, pal.woodDark, w);
    canvas.drawLine(Offset(cx - u * .2, o.dy + u * .24), Offset(cx + u * .18, o.dy + u * .235), stroke(Color.lerp(pal.woodDark, Colors.white, .18)!, w * .8));
    // shoulders / clothes
    final body = Path()
      ..moveTo(cx - u * .27, o.dy + u * .72)
      ..quadraticBezierTo(cx - u * .28, headC.dy + u * .2, cx, headC.dy + u * .17)
      ..quadraticBezierTo(cx + u * .28, headC.dy + u * .2, cx + u * .27, o.dy + u * .72)
      ..close();
    inked(canvas, body, _clothes[type], w);
    if (type == 1) {
      // salaryman: tie
      final tie = Path()
        ..moveTo(cx - u * .03, headC.dy + u * .19)
        ..lineTo(cx + u * .03, headC.dy + u * .19)
        ..lineTo(cx + u * .04, headC.dy + u * .33)
        ..lineTo(cx, headC.dy + u * .37)
        ..lineTo(cx - u * .04, headC.dy + u * .33)
        ..close();
      inked(canvas, tie, const Color(0xFF3F5F86), w * .7);
    }
    // hair behind (long hair)
    if (type == 3) {
      inked(canvas, Path()..addRRect(rr(headC.dx - u * .22, headC.dy - u * .12, u * .44, u * .36, u * .14)), _hair[type], w);
    }
    // head
    final face = Path()..addOval(Rect.fromCenter(center: headC, width: u * .4, height: u * .38));
    inked(canvas, face, _skin[type], w);
    // hair on top
    canvas.save();
    canvas.clipPath(face);
    switch (type) {
      case 0: // grandma: grey hair
        canvas.drawOval(Rect.fromCenter(center: headC + Offset(0, -u * .14), width: u * .46, height: u * .22), fill(_hair[type]));
      case 1:
        canvas.drawOval(Rect.fromCenter(center: headC + Offset(u * .03, -u * .15), width: u * .46, height: u * .2), fill(_hair[type]));
      case 2: // child: cap drawn later
        canvas.drawOval(Rect.fromCenter(center: headC + Offset(0, -u * .14), width: u * .44, height: u * .16), fill(_hair[type]));
      case 3:
        canvas.drawOval(Rect.fromCenter(center: headC + Offset(-u * .05, -u * .15), width: u * .5, height: u * .22), fill(_hair[type]));
      case 4: // taisho: short crop
        canvas.drawOval(Rect.fromCenter(center: headC + Offset(0, -u * .17), width: u * .42, height: u * .12), fill(_hair[type]));
    }
    canvas.restore();
    canvas.drawPath(face, stroke(kInk, w));
    if (type == 0) {
      // bun
      inked(canvas, Path()..addOval(Rect.fromCircle(center: headC + Offset(0, -u * .22), radius: u * .07)), _hair[type], w);
    } else if (type == 2) {
      final cap = Path()
        ..moveTo(headC.dx - u * .2, headC.dy - u * .06)
        ..quadraticBezierTo(headC.dx, headC.dy - u * .34, headC.dx + u * .2, headC.dy - u * .06)
        ..lineTo(headC.dx + u * .3, headC.dy - u * .05)
        ..lineTo(headC.dx - u * .2, headC.dy - u * .03)
        ..close();
      inked(canvas, cap, const Color(0xFF4A86C8), w);
    } else if (type == 4) {
      inked(canvas, Path()..addRRect(rr(headC.dx - u * .21, headC.dy - u * .15, u * .42, u * .06, u * .02)), const Color(0xFFF6EEDF), w * .8);
    }
    // face
    final ey = headC.dy + u * .01;
    final blink = ((phase + index * .9) % 4.3) > 4.18;
    switch (mood) {
      case Mood.happy:
        for (final sx in [-1.0, 1.0]) {
          canvas.drawArc(Rect.fromCenter(center: Offset(cx + sx * u * .075, ey + u * .01), width: u * .07, height: u * .06), math.pi * 1.1, math.pi * .8, false, stroke(kInk, w));
          canvas.drawCircle(Offset(cx + sx * u * .12, ey + u * .06), u * .03, fill(const Color(0x66F08A8A)));
        }
        final mouth = Path()
          ..moveTo(cx - u * .05, ey + u * .07)
          ..quadraticBezierTo(cx, ey + u * .14, cx + u * .05, ey + u * .07)
          ..close();
        inked(canvas, mouth, const Color(0xFFC8574F), w * .7);
      case Mood.upset:
        for (final sx in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(cx + sx * u * .075, ey + u * .015), u * .022, fill(kInk));
          canvas.drawLine(Offset(cx + sx * u * .04, ey - u * .045), Offset(cx + sx * u * .11, ey - u * .025), stroke(kInk, w * .8));
        }
        final m = Path()..moveTo(cx - u * .05, ey + u * .1);
        for (var i = 1; i <= 4; i++) {
          m.lineTo(cx - u * .05 + i * u * .025, ey + u * (i.isOdd ? .08 : .1));
        }
        canvas.drawPath(m, stroke(kInk, w * .8));
        final drop = Path()
          ..moveTo(cx + u * .19, ey - u * .1)
          ..quadraticBezierTo(cx + u * .24, ey - u * .02, cx + u * .19, ey - u * .01)
          ..quadraticBezierTo(cx + u * .15, ey - u * .02, cx + u * .19, ey - u * .1);
        inked(canvas, drop, const Color(0xFF9FD0F0), w * .6);
      case Mood.waiting:
        for (final sx in [-1.0, 1.0]) {
          final e = Offset(cx + sx * u * .075, ey + u * .015);
          if (blink) {
            canvas.drawLine(e - Offset(u * .025, 0), e + Offset(u * .025, 0), stroke(kInk, w));
          } else {
            canvas.drawCircle(e, u * .024, fill(kInk));
          }
        }
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, ey + u * .07), width: u * .06, height: u * .03), .2, math.pi - .4, false, stroke(kInk, w * .8));
    }
    if (type == 1 || type == 0) {
      // glasses
      for (final sx in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(cx + sx * u * .075, ey + u * .015), u * .045, stroke(kInk, w * .6));
      }
      canvas.drawLine(Offset(cx - u * .03, ey + u * .01), Offset(cx + u * .03, ey + u * .01), stroke(kInk, w * .6));
    }
    // table in front
    // a plain plank table: square cut, with grain and a knot
    final top = Path()..addRect(Rect.fromLTWH(o.dx + u * .07, o.dy + u * .62, u * .86, u * .15));
    inked(canvas, top, pal.woodLight, w);
    canvas.drawLine(Offset(o.dx + u * .14, o.dy + u * .7), Offset(o.dx + u * .52, o.dy + u * .705), stroke(pal.wood, w * .7));
    canvas.drawOval(Rect.fromCenter(center: Offset(o.dx + u * (.66 + (index % 3) * .08), o.dy + u * .695), width: u * .05, height: u * .025), stroke(pal.wood, w * .6));
    final front = Path()..addRect(Rect.fromLTWH(o.dx + u * .1, o.dy + u * .77, u * .8, u * .13));
    inked(canvas, front, pal.wood, w);
    // hands
    for (final sx in [-1.0, 1.0]) {
      inked(canvas, Path()..addOval(Rect.fromCenter(center: Offset(cx + sx * u * .2, o.dy + u * .66), width: u * .11, height: u * .08)), _skin[type], w * .7);
    }
    if (servedDish != null) {
      final d = Offset(cx, o.dy + u * .69);
      canvas.drawOval(Rect.fromCenter(center: d + Offset(0, u * .02), width: u * .4, height: u * .12), fill(const Color(0xFFFFFCF4)));
      canvas.drawOval(Rect.fromCenter(center: d + Offset(0, u * .02), width: u * .4, height: u * .12), stroke(kInk, w * .7));
      food(canvas, d - Offset(0, u * .03), u * .22, servedDish);
      // chopsticks
      canvas.drawLine(Offset(cx + u * .24, o.dy + u * .63), Offset(cx + u * .38, o.dy + u * .74), stroke(kInk, w * 1.2));
      steam(canvas, d - Offset(0, u * .12), u * .8, phase + index);
    }
  }

  static void steam(Canvas canvas, Offset base, double u, double t) {
    for (var i = -1; i <= 1; i++) {
      final k = ((t * .6 + i * .33) % 1.0);
      final a = (1 - k) * .45;
      final x = base.dx + i * u * .08;
      final y = base.dy - k * u * .22;
      final p = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + u * .04, y - u * .04, x, y - u * .08)
        ..quadraticBezierTo(x - u * .04, y - u * .12, x, y - u * .16);
      canvas.drawPath(p, stroke(Colors.white.withValues(alpha: a), u * .03));
    }
  }

  /// Steam over a hot dish on the stack: one wisp per step it still needs
  /// to cool. Ink strokes, not a soft blur, so it reads at a glance.
  static void dishSteam(Canvas canvas, Offset c, double u, int heat, double t) {
    final w = math.max(1.6, u * .038);
    for (var i = 0; i < heat; i++) {
      final x = c.dx + (i - (heat - 1) / 2) * u * .14;
      final sway = math.sin(t * 3 + i * 1.7) * u * .03;
      final path = Path()
        ..moveTo(x, c.dy)
        ..quadraticBezierTo(x - u * .06 + sway, c.dy - u * .09, x + sway * .5, c.dy - u * .16)
        ..quadraticBezierTo(x + u * .06 + sway, c.dy - u * .23, x + sway, c.dy - u * .31);
      // a pale halo under the ink line keeps it readable on any floor
      canvas.drawPath(path, stroke(const Color(0xCCFFF8EA), w * 2.2));
      canvas.drawPath(path, stroke(kInk.withValues(alpha: .8), w));
    }
  }

  /// A round paper fan (uchiwa) with indigo waves: "cool it down first".
  static void coolFan(Canvas canvas, Offset c, double u) {
    final w = u * .02;
    canvas.drawLine(c + Offset(u * .02, u * .05), c + Offset(u * .07, u * .14), stroke(const Color(0xFF8A5A33), w * 1.6));
    final face = Path()..addOval(Rect.fromCircle(center: c, radius: u * .075));
    inked(canvas, face, const Color(0xFFF2EBDA), w);
    for (var k = 0; k < 2; k++) {
      final y = c.dy - u * .02 + k * u * .035;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx - u * .055, y)
            ..quadraticBezierTo(c.dx - u * .025, y - u * .025, c.dx, y)
            ..quadraticBezierTo(c.dx + u * .025, y + u * .025, c.dx + u * .055, y),
          stroke(const Color(0xFF3F5F86), w * .9));
    }
  }

  /// The order ticket hanging above a guest. [kind] is one dish, or two for
  /// a shared table (top dish first, drawn above the one under it). [cool]
  /// adds the fan of a cat-tongued guest.
  static void orderTicket(Canvas canvas, Offset center, double u, String kind,
      {double scale = 1, bool upset = false, double tilt = -.08, bool cool = false}) {
    if (kind.length == 2) {
      _pairTicket(canvas, center, u, kind, scale: scale, upset: upset, tilt: tilt);
      return;
    }
    final w = u * .028;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.scale(scale);
    // an order slip (denpyo): square top, torn bottom, a pointer tab
    final both = Path()
      ..moveTo(-u * .19, -u * .17)
      ..lineTo(u * .2, -u * .165)
      ..lineTo(u * .195, u * .12);
    const teeth = [.0, .03, -.01, .025, .0, .02, -.005];
    for (var i = 1; i < teeth.length; i++) {
      both.lineTo(u * (.195 - i * .065), u * (.12 + teeth[i] + (i.isOdd ? .018 : 0)));
    }
    both
      ..lineTo(-u * .03, u * .15)
      ..lineTo(-u * .17, u * .26)
      ..lineTo(-u * .1, u * .14)
      ..lineTo(-u * .19, u * .13)
      ..close();
    canvas.drawPath(both.shift(Offset(u * .02, u * .03)), fill(const Color(0x30200C04)));
    inked(canvas, both, const Color(0xFFFFF9EC), upset ? w * 1.6 : w);
    // a vermilion rule across the top, like a printed slip
    canvas.drawLine(Offset(-u * .15, -u * .12), Offset(u * .16, -u * .12), stroke(const Color(0xB3C8452F), w * .8));
    if (upset) canvas.drawPath(both, stroke(const Color(0xFFC8452F), w * 1.4));
    food(canvas, Offset(0, u * .0), u * .25, kind);
    if (cool) coolFan(canvas, Offset(u * .19, u * .1), u * 1.3);
    canvas.restore();
  }

  /// A taller slip for a shared table: the top dish over the one under it,
  /// joined by a little bracket, as they must sit on the cat's head.
  static void _pairTicket(Canvas canvas, Offset center, double u, String kinds, {double scale = 1, bool upset = false, double tilt = -.08}) {
    final w = u * .028;
    canvas.save();
    canvas.translate(center.dx, center.dy + u * .04);
    canvas.rotate(tilt);
    canvas.scale(scale);
    final slip = Path()
      ..moveTo(-u * .19, -u * .3)
      ..lineTo(u * .2, -u * .295)
      ..lineTo(u * .195, u * .2)
      ..lineTo(u * .06, u * .23)
      ..lineTo(-u * .05, u * .2)
      ..lineTo(-u * .19, u * .225)
      ..close();
    canvas.drawPath(slip.shift(Offset(u * .02, u * .03)), fill(const Color(0x30200C04)));
    inked(canvas, slip, const Color(0xFFFFF9EC), upset ? w * 1.6 : w);
    canvas.drawLine(Offset(-u * .15, -u * .25), Offset(u * .16, -u * .25), stroke(const Color(0xB3C8452F), w * .8));
    if (upset) canvas.drawPath(slip, stroke(const Color(0xFFC8452F), w * 1.4));
    food(canvas, Offset(u * .02, -u * .12), u * .2, kinds[0]);
    food(canvas, Offset(u * .02, u * .09), u * .2, kinds[1]);
    // a bracket on the left: these two go together, top over bottom
    canvas.drawPath(
        Path()
          ..moveTo(-u * .1, -u * .16)
          ..lineTo(-u * .14, -u * .16)
          ..lineTo(-u * .14, u * .13)
          ..lineTo(-u * .1, u * .13),
        stroke(const Color(0xFFC8452F), w));
    canvas.restore();
  }

  /// A wooden market cart seen from above at a slant: plank bed, two iron
  /// wheels, a handle bar. [load] is the dish riding on it.
  static void cart(Canvas canvas, Offset c, double u, String? load, {double tilt = 0}) {
    final w = u * .03;
    shadow(canvas, c + Offset(0, u * .3), u * .82, u * .2, .2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    for (final sx in [-1.0, 1.0]) {
      final wheel = Path()..addOval(Rect.fromCenter(center: Offset(sx * u * .3, u * .22), width: u * .16, height: u * .2));
      inked(canvas, wheel, const Color(0xFF4A3A30), w);
      canvas.drawCircle(Offset(sx * u * .3, u * .22), u * .025, fill(const Color(0xFFB9A88E)));
    }
    final bed = Path()
      ..moveTo(-u * .36, -u * .2)
      ..lineTo(u * .37, -u * .21)
      ..lineTo(u * .35, u * .2)
      ..lineTo(-u * .35, u * .21)
      ..close();
    inked(canvas, bed, const Color(0xFFC79A62), w);
    for (var k = 1; k < 3; k++) {
      final y = -u * .2 + k * u * .135;
      canvas.drawLine(Offset(-u * .34, y), Offset(u * .34, y - u * .005), stroke(const Color(0xFF8C6236), w * .8));
    }
    nick(canvas, Offset(-u * .2, -u * .14), u * .14, w * .8, angle: 0);
    // handle bar at the back
    canvas.drawLine(Offset(-u * .2, -u * .2), Offset(-u * .24, -u * .36), stroke(kInk, w * 1.3));
    canvas.drawLine(Offset(u * .2, -u * .21), Offset(u * .24, -u * .36), stroke(kInk, w * 1.3));
    canvas.drawLine(Offset(-u * .28, -u * .36), Offset(u * .28, -u * .36), stroke(const Color(0xFF7A5232), w * 2.2));
    canvas.restore();
    if (load != null) floorDish(canvas, c + Offset(0, -u * .03), u * .82, load);
  }

  // ------------------------------------------------------------- props

  /// Lacquered tray (o-bon) lying on the floor, with the flip arrows.
  static void tray(Canvas canvas, Offset c, double u, {double spin = 0}) {
    final w = u * .03;
    shadow(canvas, c + Offset(0, u * .06), u * .8, u * .5, .18);
    final r = Rect.fromCenter(center: c, width: u * .8, height: u * .6);
    inked(canvas, Path()..addOval(r), const Color(0xFF7A2A22), w);
    canvas.drawOval(r.deflate(u * .06), fill(const Color(0xFF9E3A2E)));
    canvas.drawOval(r.deflate(u * .06), stroke(const Color(0xFF5A1E18), w * .7));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, .72);
    canvas.rotate(spin);
    const gold = Color(0xFFE9C46A);
    for (final a in [0.0, math.pi]) {
      canvas.save();
      canvas.rotate(a);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: u * .2), -math.pi * .85, math.pi * .7, false, stroke(gold, u * .05));
      final tip = Offset(math.cos(-math.pi * .15), math.sin(-math.pi * .15)) * u * .2;
      canvas.drawPath(
          Path()
            ..moveTo(tip.dx - u * .06, tip.dy - u * .07)
            ..lineTo(tip.dx + u * .05, tip.dy + u * .01)
            ..lineTo(tip.dx - u * .07, tip.dy + u * .05)
            ..close(),
          fill(gold));
      canvas.restore();
    }
    canvas.restore();
  }

  /// Arrows painted on the ground for a one-way floor: brushed on with a
  /// stencil, so the edges wander and the paint has worn thin in places.
  /// Drawn once into the cached scene layer, so the path work is free.
  static void paintedArrow(Canvas canvas, Offset c, double u, Dir d, {Color color = const Color(0xE6FFF8E6)}) {
    final seed = (c.dx * 3 + c.dy * 7).toInt();
    for (var k = 0; k < 2; k++) {
      final o = (k - .5) * u * .22;
      final x = c.dx + d.dx * o + d.dy * (k - .5) * u * .02, y = c.dy + d.dy * o + d.dx * (k - .5) * u * .02;
      final path = Path()
        ..moveTo(x - d.dx * u * .09 - d.dy * u * .17, y - d.dy * u * .09 - d.dx * u * .17)
        ..lineTo(x + d.dx * u * .09, y + d.dy * u * .09)
        ..lineTo(x - d.dx * u * .09 + d.dy * u * .17, y - d.dy * u * .09 + d.dx * u * .17);
      canvas.drawPath(Wob.around(path, seed: seed + k, amp: u * .008, step: u * .04), stroke(color, u * (k == 0 ? .09 : .085)));
      // worn patches where feet have scuffed the paint
      final worn = stroke(const Color(0x55B0A898), u * .03);
      canvas.drawLine(Offset(x - d.dy * u * .1, y - d.dx * u * .1), Offset(x - d.dy * u * .05 + d.dx * u * .02, y - d.dx * u * .05 + d.dy * u * .02), worn);
    }
  }

  /// Return counter: a little booth with a slot. Closed shutter once used.
  static void counter(Canvas canvas, Offset o, double u, Palette pal, {required bool used, double depth = .3, double pulse = 0}) {
    final w = u * .03;
    final d = u * depth;
    final topR = Rect.fromLTWH(o.dx + u * .04, o.dy + u * .06, u * .92, u - d - u * .06);
    final frontR = Rect.fromLTWH(o.dx + u * .04, o.dy + u - d, u * .92, d - u * .02);
    inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(topR, Radius.circular(u * .06))), pal.woodLight, w);
    // rack of clean plates on top
    for (var i = 0; i < 3; i++) {
      final x = topR.left + u * .2 + i * u * .12;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, topR.top + u * .2), width: u * .08, height: u * .22), fill(const Color(0xFFFFFCF4)));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, topR.top + u * .2), width: u * .08, height: u * .22), stroke(kInk, w * .6));
    }
    inked(canvas, Path()..addRect(frontR), pal.wood, w);
    final slot = Rect.fromLTWH(o.dx + u * .2, o.dy + u * .34, u * .6, u * .28);
    if (used) {
      inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(slot, Radius.circular(u * .03))), const Color(0xFF9A9186), w);
      for (var i = 1; i < 4; i++) {
        final y = slot.top + slot.height * i / 4;
        canvas.drawLine(Offset(slot.left + u * .02, y), Offset(slot.right - u * .02, y), stroke(kInk.withValues(alpha: .5), w * .6));
      }
    } else {
      inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(slot, Radius.circular(u * .03))), const Color(0xFF2A1E18), w);
      // little noren over the slot
      final nr = Rect.fromLTWH(slot.left - u * .02, slot.top - u * .05, slot.width + u * .04, u * .12 + pulse * u * .01);
      for (var i = 0; i < 3; i++) {
        final pw = nr.width / 3;
        inked(canvas, Path()..addRect(Rect.fromLTWH(nr.left + i * pw + u * .005, nr.top, pw - u * .01, nr.height)), pal.noren, w * .6);
      }
      // down arrow on the booth front
      final a = Offset(o.dx + u * .5, frontR.center.dy + pulse * u * .02);
      canvas.drawPath(
          Path()
            ..moveTo(a.dx - u * .07, a.dy - u * .03)
            ..lineTo(a.dx, a.dy + u * .04)
            ..lineTo(a.dx + u * .07, a.dy - u * .03),
          stroke(const Color(0xFFFFF3D6), u * .035));
    }
  }

  /// Two paw prints on a cell: the hint.
  static void paws(Canvas canvas, Offset c, double u, Color color, double alpha) {
    final p = fill(color.withValues(alpha: alpha));
    for (final (dx, dy, s) in [(-.13, .1, 1.0), (.13, -.1, 1.0)]) {
      final o = c + Offset(dx * u, dy * u);
      canvas.drawOval(Rect.fromCenter(center: o + Offset(0, u * .04), width: u * .14 * s, height: u * .11 * s), p);
      for (final (tx, ty) in [(-.06, -.04), (-.02, -.075), (.02, -.075), (.06, -.04)]) {
        canvas.drawCircle(o + Offset(tx * u, ty * u), u * .025, p);
      }
    }
  }
}
