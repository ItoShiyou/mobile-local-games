import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/engine.dart';

/// Sumi-brown ink used for every outline on the board.
const kInk = Color(0xFF3A2B22);

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

  /// Fill then outline.
  static void inked(Canvas c, Path p, Color color, double w) {
    c.drawPath(p, fill(color));
    c.drawPath(p, stroke(kInk, w));
  }

  static void shadow(Canvas c, Offset center, double w, double h, [double a = .22]) {
    c.drawOval(Rect.fromCenter(center: center, width: w, height: h), fill(Color.fromRGBO(40, 25, 15, a)));
  }

  // ---------------------------------------------------------------- food

  /// Food only (no plate), centred at [c], roughly [s] wide.
  static void food(Canvas canvas, Offset c, double s, String kind) {
    final w = math.max(1.0, s * .05);
    final col = dishColors[kind]!;
    switch (kind) {
      case 'a': // tomato
        inked(canvas, Path()..addOval(Rect.fromCircle(center: c + Offset(0, s * .04), radius: s * .38)), col, w);
        canvas.drawOval(Rect.fromCenter(center: c + Offset(-s * .15, -s * .06), width: s * .16, height: s * .1),
            fill(Colors.white.withValues(alpha: .55)));
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
          inked(canvas, Path()..addOval(Rect.fromCircle(center: p, radius: s * .17)), i == 0 ? const Color(0xFF86B85F) : col, w);
          canvas.drawCircle(p + Offset(-s * .055, -s * .06), s * .045, fill(Colors.white.withValues(alpha: .5)));
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
        for (final (x, y) in pts) {
          inked(canvas, Path()..addOval(Rect.fromCircle(center: c + Offset(x * s, y * s + s * .06), radius: s * .13)), col, w * .8);
          canvas.drawCircle(c + Offset(x * s - s * .04, y * s + s * .02), s * .035, fill(Colors.white.withValues(alpha: .5)));
        }
    }
  }

  /// A dish lying on the floor (seen from above).
  static void floorDish(Canvas canvas, Offset c, double u, String kind) {
    final w = u * .03;
    shadow(canvas, c + Offset(0, u * .12), u * .72, u * .38);
    final plate = Rect.fromCenter(center: c + Offset(0, u * .06), width: u * .72, height: u * .46);
    inked(canvas, Path()..addOval(plate), const Color(0xFFFFFCF4), w);
    canvas.drawOval(plate.deflate(u * .07), stroke(const Color(0xFFE2D8C4), w));
    canvas.drawArc(plate.deflate(u * .03), math.pi * 1.1, .9, false, stroke(const Color(0xFF4A6F9E), w * .9));
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

  /// The delivery cat. [c] is the centre of the head. [phase] is the time
  /// in seconds for blinking and the tail.
  static void courier(Canvas canvas, Offset c, double u, Dir look, Palette pal, {double phase = 0, double hop = 0}) {
    final w = u * .032;
    final head = c + Offset(0, -hop);
    shadow(canvas, c + Offset(0, u * .36), u * .52 - hop * .6, u * .16);
    // tail
    final side = look == Dir.left ? 1.0 : -1.0;
    final sway = math.sin(phase * 3.2) * u * .05;
    final tail = Path()
      ..moveTo(c.dx + side * u * .16, c.dy + u * .3 - hop)
      ..cubicTo(c.dx + side * u * .42, c.dy + u * .32 - hop, c.dx + side * u * .38 + sway, c.dy + u * .05 - hop,
          c.dx + side * u * .3 + sway, c.dy - u * .02 - hop);
    canvas.drawPath(tail, stroke(kInk, u * .11));
    canvas.drawPath(tail, stroke(const Color(0xFFF6EEE0), u * .065));
    // body in a happi coat
    final body = Path()
      ..moveTo(head.dx - u * .21, head.dy + u * .36)
      ..quadraticBezierTo(head.dx - u * .24, head.dy + u * .14, head.dx - u * .12, head.dy + u * .12)
      ..lineTo(head.dx + u * .12, head.dy + u * .12)
      ..quadraticBezierTo(head.dx + u * .24, head.dy + u * .14, head.dx + u * .21, head.dy + u * .36)
      ..close();
    inked(canvas, body, pal.noren, w);
    canvas.drawLine(head + Offset(-u * .1, u * .14), head + Offset(0, u * .33), stroke(const Color(0xFFF6EEDF), u * .05));
    canvas.drawLine(head + Offset(u * .1, u * .14), head + Offset(0, u * .33), stroke(const Color(0xFFF6EEDF), u * .05));
    // ears
    const fur = Color(0xFFFBF4E8);
    for (final sx in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(head.dx + sx * u * .23, head.dy - u * .06)
        ..lineTo(head.dx + sx * u * .2, head.dy - u * .31)
        ..lineTo(head.dx + sx * u * .05, head.dy - u * .2)
        ..close();
      inked(canvas, ear, fur, w);
      final inner = Path()
        ..moveTo(head.dx + sx * u * .2, head.dy - u * .1)
        ..lineTo(head.dx + sx * u * .19, head.dy - u * .25)
        ..lineTo(head.dx + sx * u * .1, head.dy - u * .18)
        ..close();
      canvas.drawPath(inner, fill(const Color(0xFFF2B3BE)));
    }
    // head
    final face = Path()..addOval(Rect.fromCenter(center: head, width: u * .56, height: u * .5));
    inked(canvas, face, fur, w);
    // brown patch over one eye
    canvas.save();
    canvas.clipPath(face);
    canvas.drawOval(Rect.fromCenter(center: head + Offset(-u * .16, -u * .12), width: u * .3, height: u * .26), fill(const Color(0xFFD9A066)));
    canvas.restore();
    canvas.drawPath(face, stroke(kInk, w));
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
    for (final a in [-.5, .3]) {
      final tipOff = Offset(-side * u * .13, a * u * .2 + flutter);
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
        canvas.drawCircle(e + Offset(u * .014, -u * .018), u * .015, fill(Colors.white));
      }
    }
    // nose, mouth, whiskers, cheeks
    final m = head + Offset(lx, u * .12 + ly);
    canvas.drawCircle(m + Offset(0, -u * .02), u * .022, fill(const Color(0xFFE07A8C)));
    canvas.drawArc(Rect.fromCenter(center: m + Offset(-u * .025, u * .005), width: u * .05, height: u * .04), .3, math.pi - .6, false, stroke(kInk, w * .7));
    canvas.drawArc(Rect.fromCenter(center: m + Offset(u * .025, u * .005), width: u * .05, height: u * .04), .3, math.pi - .6, false, stroke(kInk, w * .7));
    for (final sx in [-1.0, 1.0]) {
      canvas.drawCircle(head + Offset(sx * u * .17, u * .09), u * .035, fill(const Color(0x55F08A9A)));
      canvas.drawLine(head + Offset(sx * u * .2, u * .06), head + Offset(sx * u * .33, u * .03), stroke(kInk, w * .5));
      canvas.drawLine(head + Offset(sx * u * .2, u * .1), head + Offset(sx * u * .33, u * .12), stroke(kInk, w * .5));
    }
  }

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
    inked(canvas, Path()..addRRect(rr(cx - u * .3, o.dy + u * .14, u * .6, u * .5, u * .1)), pal.woodDark, w);
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
    final top = Path()..addRRect(rr(o.dx + u * .07, o.dy + u * .62, u * .86, u * .16, u * .06));
    inked(canvas, top, pal.woodLight, w);
    final front = Path()..addRRect(rr(o.dx + u * .1, o.dy + u * .76, u * .8, u * .14, u * .03));
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

  /// The order ticket hanging above a guest.
  static void orderTicket(Canvas canvas, Offset center, double u, String kind, {double scale = 1, bool upset = false, double tilt = -.08}) {
    final w = u * .028;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.scale(scale);
    final tail = Path()
      ..moveTo(-u * .08, u * .13)
      ..lineTo(-u * .17, u * .25)
      ..lineTo(-u * .01, u * .15);
    final card = Path()..addRRect(rr(-u * .2, -u * .17, u * .4, u * .32, u * .08));
    final both = Path.combine(PathOperation.union, card, tail..close());
    canvas.drawPath(both.shift(Offset(u * .015, u * .025)), fill(const Color(0x33000000)));
    inked(canvas, both, const Color(0xFFFFFCF4), upset ? w * 1.6 : w);
    if (upset) canvas.drawPath(both, stroke(const Color(0xFFC8452F), w * 1.4));
    food(canvas, Offset(0, -u * .01), u * .26, kind);
    canvas.restore();
  }

  // ------------------------------------------------------------- props

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

  // --------------------------------------------------------------- doors

  /// A fusuma: paper on a lacquered frame, a round pull, and small marks
  /// at both ends showing which way it slides. Paired doors share an indigo
  /// wave crest on pale blue paper; a locked one wears a red lock plate.
  static void fusuma(Canvas canvas, Rect cells, double u,
      {required bool horizontal, bool pair = false, bool locked = false, double lockShake = 0}) {
    final inset = u * .13;
    final r = horizontal
        ? Rect.fromLTRB(cells.left + u * .04, cells.top + inset, cells.right - u * .04, cells.bottom - inset)
        : Rect.fromLTRB(cells.left + inset, cells.top + u * .04, cells.right - inset, cells.bottom - u * .04);
    final w = math.max(1.2, u * .035);
    canvas.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(u * .03, u * .05)), Radius.circular(u * .05)), fill(const Color(0x33000000)));
    final frame = RRect.fromRectAndRadius(r, Radius.circular(u * .05));
    canvas.drawRRect(frame, fill(const Color(0xFF5E3B26)));
    final paper = r.deflate(u * .06);
    canvas.drawRect(paper, fill(pair ? const Color(0xFFDDE7EE) : const Color(0xFFF6EEDB)));
    // karakami pattern: faint diamonds
    final pat = stroke((pair ? const Color(0xFF7F9BB5) : const Color(0xFFD9C9A8)).withValues(alpha: .55), math.max(.6, u * .012));
    canvas.save();
    canvas.clipRect(paper);
    final step = u * .22;
    for (var x = paper.left - paper.height; x < paper.right; x += step) {
      canvas.drawLine(Offset(x, paper.bottom), Offset(x + paper.height, paper.top), pat);
      canvas.drawLine(Offset(x, paper.top), Offset(x + paper.height, paper.bottom), pat);
    }
    canvas.restore();
    // panel joints every cell
    final n = ((horizontal ? cells.width : cells.height) / u).round();
    for (var k = 1; k < n; k++) {
      if (horizontal) {
        final x = cells.left + k * u;
        canvas.drawLine(Offset(x, paper.top), Offset(x, paper.bottom), stroke(const Color(0xFF5E3B26), w));
      } else {
        final y = cells.top + k * u;
        canvas.drawLine(Offset(paper.left, y), Offset(paper.right, y), stroke(const Color(0xFF5E3B26), w));
      }
    }
    if (pair) {
      // wave crest (seigaiha) in each panel
      final crest = stroke(const Color(0xFF2F4B6B), math.max(1, u * .03));
      for (var k = 0; k < n; k++) {
        final c = horizontal ? Offset(cells.left + (k + .5) * u, paper.center.dy + u * .06) : Offset(paper.center.dx, cells.top + (k + .5) * u + u * .06);
        for (final rr in [u * .15, u * .09, u * .03]) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: rr), math.pi, math.pi, false, crest);
        }
      }
    }
    canvas.drawRRect(frame, stroke(kInk, w));
    // pull: a small round hollow near one end
    final pull = horizontal ? Offset(paper.right - u * .22, paper.center.dy) : Offset(paper.center.dx, paper.bottom - u * .22);
    canvas.drawCircle(pull, u * .06, fill(const Color(0xFF3A2B22)));
    canvas.drawCircle(pull, u * .035, fill(const Color(0xFFB08A45)));
    // slide marks at both ends
    final mark = fill(const Color(0xCC7A5638));
    for (final sgn in [-1.0, 1.0]) {
      final path = Path();
      if (horizontal) {
        final x = sgn < 0 ? paper.left + u * .08 : paper.right - u * .08;
        path
          ..moveTo(x + sgn * u * .05, paper.center.dy)
          ..lineTo(x - sgn * u * .04, paper.center.dy - u * .06)
          ..lineTo(x - sgn * u * .04, paper.center.dy + u * .06)
          ..close();
      } else {
        final y = sgn < 0 ? paper.top + u * .08 : paper.bottom - u * .08;
        path
          ..moveTo(paper.center.dx, y + sgn * u * .05)
          ..lineTo(paper.center.dx - u * .06, y - sgn * u * .04)
          ..lineTo(paper.center.dx + u * .06, y - sgn * u * .04)
          ..close();
      }
      canvas.drawPath(path, mark);
    }
    if (locked) {
      final jig = lockShake > 0 ? math.sin(lockShake * math.pi * 8) * u * .03 : 0.0;
      final c = r.center + Offset(jig, 0);
      final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, u * .04), width: u * .26, height: u * .2), Radius.circular(u * .03));
      canvas.drawArc(Rect.fromCenter(center: c - Offset(0, u * .04), width: u * .16, height: u * .18), math.pi, math.pi, false, stroke(kInk, math.max(1.4, u * .04)));
      canvas.drawRRect(body, fill(const Color(0xFFC8452F)));
      canvas.drawRRect(body, stroke(kInk, w));
      canvas.drawCircle(c + Offset(0, u * .04), u * .025, fill(kInk));
    }
  }

  /// A revolving shoji: a post at the pivot and a lattice panel reaching
  /// one cell out at [angle] (0 = right, clockwise).
  static void revolvingShoji(Canvas canvas, Offset pivot, double u, double angle) {
    final w = math.max(1.2, u * .035);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    final panel = Rect.fromLTRB(u * .08, -u * .3, u * 1.46, u * .3);
    canvas.drawRect(panel.shift(Offset(u * .03, u * .05)), fill(const Color(0x33000000)));
    canvas.drawRect(panel, fill(const Color(0xFFFBF7EE)));
    final lattice = stroke(const Color(0xFF8C6A48), math.max(.8, u * .022));
    for (var k = 1; k < 5; k++) {
      final x = panel.left + panel.width * k / 5;
      canvas.drawLine(Offset(x, panel.top), Offset(x, panel.bottom), lattice);
    }
    canvas.drawLine(Offset(panel.left, 0), Offset(panel.right, 0), lattice);
    canvas.drawRect(panel, stroke(const Color(0xFF6B4A33), math.max(1.4, u * .05)));
    canvas.drawRect(panel, stroke(kInk, w * .6));
    canvas.restore();
    // the post
    canvas.drawCircle(pivot + Offset(u * .02, u * .04), u * .2, fill(const Color(0x33000000)));
    canvas.drawCircle(pivot, u * .19, fill(const Color(0xFF7E5535)));
    canvas.drawCircle(pivot, u * .19, stroke(kInk, w));
    canvas.drawCircle(pivot, u * .08, fill(const Color(0xFFB08A45)));
  }

  /// The landlady's key: brass, with a red tassel.
  static void key(Canvas canvas, Offset c, double u) {
    final w = math.max(1.2, u * .035);
    shadow(canvas, c + Offset(0, u * .2), u * .4, u * .1);
    canvas.drawLine(c + Offset(-u * .02, u * .06), c + Offset(-u * .12, u * .26), stroke(const Color(0xFFC8452F), u * .05));
    canvas.drawCircle(c + Offset(-u * .12, u * .28), u * .04, fill(const Color(0xFFC8452F)));
    final ring = c + Offset(-u * .12, 0);
    canvas.drawCircle(ring, u * .11, fill(const Color(0xFFE2B84F)));
    canvas.drawCircle(ring, u * .11, stroke(kInk, w));
    canvas.drawCircle(ring, u * .045, fill(const Color(0xFF7A5638)));
    final shaft = Rect.fromLTWH(c.dx - u * .02, c.dy - u * .035, u * .3, u * .07);
    canvas.drawRect(shaft, fill(const Color(0xFFE2B84F)));
    canvas.drawRect(shaft, stroke(kInk, w * .8));
    for (final x in [.2, .27]) {
      final tooth = Rect.fromLTWH(c.dx + u * x - u * .02, c.dy + u * .035, u * .04, u * .07);
      canvas.drawRect(tooth, fill(const Color(0xFFE2B84F)));
      canvas.drawRect(tooth, stroke(kInk, w * .7));
    }
  }
}
