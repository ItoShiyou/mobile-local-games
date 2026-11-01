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

  /// A red seal stamp with one character.
  static void hanko(Canvas canvas, Offset c, double r, String ch) {
    canvas.drawCircle(c, r, stroke(const Color(0xE6C8452F), r * .16));
    final tp = TextPainter(
      text: TextSpan(text: ch, style: TextStyle(fontFamily: displayFont, fontSize: r * 1.1, color: const Color(0xE6C8452F), height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// A short length of pipe for icons: [dirs] are the open ends.
  static void pipeIcon(Canvas canvas, Offset c, double u, List<Dir> dirs, {Color? stock, bool iron = false}) {
    final shell = iron ? const Color(0xFF7D7B78) : const Color(0xFFC9B07A);
    for (final (w, col) in [(u * .36, kInk), (u * .28, shell), if (stock != null) (u * .13, stock)]) {
      for (final d in dirs) {
        canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Paint()
          ..color = col
          ..strokeWidth = w);
      }
    }
    if (iron) {
      for (final (dx, dy) in [(-.3, -.3), (.3, -.3), (-.3, .3), (.3, .3)]) {
        canvas.drawCircle(c + Offset(dx * u, dy * u), u * .045, fill(const Color(0xFF4A4845)));
      }
    }
  }
}
