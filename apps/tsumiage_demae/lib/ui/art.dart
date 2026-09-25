import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/engine.dart';

/// Shared vector art for the board, the HUD and the menus.
/// Every dish has its own silhouette, so colour is never the only cue.
class Art {
  static final _fill = Paint()..isAntiAlias = true;
  static final _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint fill(Color c) => _fill..color = c;
  static Paint stroke(Color c, double w) => _stroke
    ..color = c
    ..strokeWidth = w;

  static RRect rr(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  /// Food only (no plate), centred at [c], roughly [s] wide.
  static void food(Canvas canvas, Offset c, double s, String kind) {
    final col = dishColors[kind]!;
    switch (kind) {
      case 'a': // tomato
        canvas.drawCircle(c, s * .42, fill(col));
        canvas.drawCircle(c + Offset(-s * .14, -s * .12), s * .1, fill(Colors.white.withValues(alpha: .45)));
        final leaf = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final p = c + Offset(0, -s * .34) + Offset(math.cos(a), math.sin(a) * .6) * s * .2;
          if (i == 0) {
            leaf.moveTo(c.dx, c.dy - s * .34);
          }
          leaf.lineTo(p.dx, p.dy);
          leaf.lineTo(c.dx, c.dy - s * .34);
        }
        canvas.drawPath(leaf, stroke(const Color(0xFF3F8A4E), s * .09));
      case 'b': // matcha dango: three balls on a skewer
        canvas.drawLine(c + Offset(-s * .44, s * .34), c + Offset(s * .44, -s * .34), stroke(const Color(0xFFB88A55), s * .07));
        for (var i = -1; i <= 1; i++) {
          final p = c + Offset(i * s * .26, -i * s * .2);
          canvas.drawCircle(p, s * .19, fill(col));
          canvas.drawCircle(p + Offset(-s * .06, -s * .06), s * .05, fill(Colors.white.withValues(alpha: .4)));
        }
      case 'c': // tamagoyaki: a rolled omelette block
        final r = rr(c.dx - s * .42, c.dy - s * .26, s * .84, s * .52, s * .12);
        canvas.drawRRect(r, fill(col));
        for (final dx in [-.14, .14]) {
          canvas.drawLine(c + Offset(s * dx, -s * .22), c + Offset(s * dx, s * .22), stroke(const Color(0xFFC9921C), s * .05));
        }
        canvas.drawLine(c + Offset(-s * .34, -s * .16), c + Offset(-s * .24, -s * .16), stroke(Colors.white.withValues(alpha: .5), s * .05));
      default: // grapes
        const pts = [(-.18, -.18), (0.0, -.2), (.18, -.18), (-.1, 0.0), (.1, 0.0), (0.0, .18)];
        for (final (x, y) in pts) {
          canvas.drawCircle(c + Offset(x * s, y * s + s * .06), s * .13, fill(col));
          canvas.drawCircle(c + Offset(x * s - s * .04, y * s + s * .02), s * .035, fill(Colors.white.withValues(alpha: .45)));
        }
        canvas.drawLine(c + Offset(0, -s * .3), c + Offset(s * .06, -s * .44), stroke(const Color(0xFF8A6A45), s * .06));
        canvas.drawOval(Rect.fromCenter(center: c + Offset(s * .18, -s * .38), width: s * .24, height: s * .12), fill(const Color(0xFF4FA86A)));
    }
  }

  /// A dish lying on the floor (top-down view).
  static void floorDish(Canvas canvas, Offset c, double u, String kind) {
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, u * .08), width: u * .7, height: u * .44), fill(const Color(0x22000000)));
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, u * .04), width: u * .7, height: u * .46), fill(Colors.white));
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, u * .04), width: u * .7, height: u * .46), stroke(const Color(0xFFD5D9E0), 1.5));
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, u * .04), width: u * .5, height: u * .3), stroke(const Color(0xFFE8EBF0), 1.2));
    food(canvas, c + Offset(0, -u * .01), u * .44, kind);
  }

  /// A dish on the stack (side view): thin plate with the food on it.
  static void stackDish(Canvas canvas, Offset c, double u, String kind, {bool highlight = false}) {
    final plate = Rect.fromCenter(center: c, width: u * .56, height: u * .14);
    canvas.drawOval(plate.shift(Offset(0, u * .02)), fill(const Color(0x33000000)));
    canvas.drawOval(plate, fill(Colors.white));
    canvas.drawOval(plate, stroke(highlight ? const Color(0xFF26303F) : const Color(0xFFC9CED6), highlight ? 1.6 : 1));
    food(canvas, c + Offset(0, -u * .07), u * .24, kind);
  }

  /// Delivery cat seen from the front. [look] is the facing direction.
  static void courier(Canvas canvas, Offset c, double u, Dir look, Color band, {double squash = 0}) {
    final body = Rect.fromCenter(center: c + Offset(0, u * .22), width: u * .5, height: u * .26);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(u * .12)), fill(band));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 + squash * .06, 1 - squash * .06);
    const fur = Color(0xFFF4F1EC);
    const edge = Color(0xFFC9C2B6);
    for (final sx in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(sx * u * .22, -u * .1)
        ..lineTo(sx * u * .17, -u * .33)
        ..lineTo(sx * u * .05, -u * .21)
        ..close();
      canvas.drawPath(ear, fill(fur));
      canvas.drawPath(ear, stroke(edge, 1.2));
    }
    canvas.drawCircle(Offset.zero, u * .27, fill(fur));
    canvas.drawCircle(Offset.zero, u * .27, stroke(edge, 1.5));
    // headband
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: u * .27), math.pi * 1.12, math.pi * .76, false, stroke(band, u * .07));
    final lx = look.dx * u * .04, ly = look.dy * u * .03;
    for (final sx in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(sx * u * .1 + lx, u * .0 + ly), u * .05, fill(const Color(0xFF26303F)));
      canvas.drawCircle(Offset(sx * u * .1 + lx + u * .015, -u * .015 + ly), u * .016, fill(Colors.white));
    }
    canvas.drawCircle(Offset(lx, u * .09 + ly), u * .03, fill(const Color(0xFFE58A9A)));
    canvas.restore();
  }

  static const _hair = [Color(0xFF4A3B34), Color(0xFF8B5A3C), Color(0xFF2F3A55), Color(0xFFB0588F), Color(0xFF6B6B6B)];
  static const _shirt = [Color(0xFF8B6A4E), Color(0xFF4F7FA8), Color(0xFF6E8B4E), Color(0xFFA8604F), Color(0xFF7A6FD0)];

  /// Seated guest waiting at a table.
  static void guest(Canvas canvas, Offset cell, double u, int index, {required bool happy, double bob = 0}) {
    final cx = cell.dx + u * .5, cy = cell.dy + u * .55 + bob;
    canvas.drawRRect(rr(cell.dx + u * .14, cell.dy + u * .6 + bob, u * .72, u * .3, u * .1), fill(_shirt[index % _shirt.length]));
    canvas.drawCircle(Offset(cx, cy - u * .06), u * .24, fill(const Color(0xFFEBC3A2)));
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - u * .12), radius: u * .25), math.pi * 1.02, math.pi * .96, true,
        fill(_hair[index % _hair.length]));
    const ink = Color(0xFF3A2E28);
    if (happy) {
      for (final sx in [-1.0, 1.0]) {
        canvas.drawArc(Rect.fromCircle(center: Offset(cx + sx * u * .08, cy - u * .03), radius: u * .04), math.pi * 1.1, math.pi * .8, false, stroke(ink, u * .03));
      }
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy + u * .03), radius: u * .07), .2, math.pi - .4, false, stroke(ink, u * .03));
      canvas.drawCircle(Offset(cx - u * .15, cy + u * .03), u * .035, fill(const Color(0x66E58A9A)));
      canvas.drawCircle(Offset(cx + u * .15, cy + u * .03), u * .035, fill(const Color(0x66E58A9A)));
    } else {
      for (final sx in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(cx + sx * u * .08, cy - u * .04), u * .03, fill(ink));
      }
      canvas.drawLine(Offset(cx - u * .04, cy + u * .06), Offset(cx + u * .04, cy + u * .06), stroke(ink, u * .025));
    }
  }

  /// Order bubble above-right of a guest.
  static void bubble(Canvas canvas, Offset center, double u, String kind, {double scale = 1, Color? ring}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final tail = Path()
      ..moveTo(-u * .1, u * .08)
      ..lineTo(-u * .2, u * .22)
      ..lineTo(-u * .02, u * .13)
      ..close();
    canvas.drawPath(tail, fill(Colors.white));
    canvas.drawCircle(Offset.zero, u * .2, fill(Colors.white));
    canvas.drawCircle(Offset.zero, u * .2, stroke(ring ?? dishColors[kind]!, u * .035));
    food(canvas, Offset.zero, u * .27, kind);
    canvas.restore();
  }

  static void check(Canvas canvas, Offset c, double u, Color color) {
    canvas.drawCircle(c, u * .12, fill(color));
    final p = Path()
      ..moveTo(c.dx - u * .055, c.dy)
      ..lineTo(c.dx - u * .01, c.dy + u * .045)
      ..lineTo(c.dx + u * .06, c.dy - u * .045);
    canvas.drawPath(p, stroke(Colors.white, u * .035));
  }

  static void chevrons(Canvas canvas, Offset c, double u, Dir d, Color color, {int n = 2, double width = .08}) {
    final p = stroke(color, u * width);
    for (var k = 0; k < n; k++) {
      final o = (k - (n - 1) / 2) * u * .2;
      final x = c.dx + d.dx * o, y = c.dy + d.dy * o;
      final path = Path()
        ..moveTo(x - d.dx * u * .08 - d.dy * u * .14, y - d.dy * u * .08 - d.dx * u * .14)
        ..lineTo(x + d.dx * u * .08, y + d.dy * u * .08)
        ..lineTo(x - d.dx * u * .08 + d.dy * u * .14, y - d.dy * u * .08 + d.dx * u * .14);
      canvas.drawPath(path, p);
    }
  }

  static void woodTile(Canvas canvas, Offset o, double u, Palette pal) {
    canvas.drawRRect(rr(o.dx + 1.5, o.dy + 1.5, u - 3, u - 3, u * .14), fill(pal.wood));
    canvas.drawLine(Offset(o.dx + 4, o.dy + u * .5), Offset(o.dx + u - 4, o.dy + u * .5), stroke(pal.woodLine, 1));
  }

  static void tray(Canvas canvas, Offset o, double u, Palette pal, {double spin = 0}) {
    woodTile(canvas, o, u, pal);
    const col = Color(0xFFB7794A);
    final c = o + Offset(u / 2, u / 2);
    canvas.drawCircle(c, u * .3, fill(const Color(0x33B7794A)));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    canvas.drawCircle(Offset.zero, u * .26, stroke(col, u * .06));
    canvas.drawLine(Offset(-u * .07, -u * .14), Offset(-u * .07, u * .14), stroke(col, u * .06));
    canvas.drawLine(Offset(u * .07, -u * .14), Offset(u * .07, u * .14), stroke(col, u * .06));
    canvas.drawPath(
        Path()
          ..moveTo(-u * .16, -u * .05)
          ..lineTo(-u * .07, -u * .19)
          ..lineTo(u * .02, -u * .05)
          ..close(),
        fill(col));
    canvas.drawPath(
        Path()
          ..moveTo(-u * .02, u * .05)
          ..lineTo(u * .07, u * .19)
          ..lineTo(u * .16, u * .05)
          ..close(),
        fill(col));
    canvas.restore();
  }

  static void oneWay(Canvas canvas, Offset o, double u, Palette pal, Dir d) {
    woodTile(canvas, o, u, pal);
    canvas.drawRRect(rr(o.dx + u * .12, o.dy + u * .12, u * .76, u * .76, u * .12), fill(const Color(0x1FB7794A)));
    chevrons(canvas, o + Offset(u / 2, u / 2), u, d, const Color(0xFFB7794A));
  }

  static void counter(Canvas canvas, Offset o, double u, Palette pal, {required bool used, double pulse = 0}) {
    woodTile(canvas, o, u, pal);
    final col = used ? const Color(0xFF8C939D) : const Color(0xFF4C6A88);
    canvas.drawRRect(rr(o.dx + u * .14, o.dy + u * .14, u * .72, u * .72, u * .14), fill(col));
    // slot
    canvas.drawRRect(rr(o.dx + u * .26, o.dy + u * .24, u * .48, u * .1, u * .05), fill(const Color(0x66000000)));
    final c = o + Offset(u / 2, u * .58);
    if (used) {
      final p = Path()
        ..moveTo(c.dx - u * .12, c.dy)
        ..lineTo(c.dx - u * .03, c.dy + u * .09)
        ..lineTo(c.dx + u * .13, c.dy - u * .09);
      canvas.drawPath(p, stroke(Colors.white, u * .06));
    } else {
      final w = u * .06;
      canvas.drawLine(c + Offset(0, -u * .14 + pulse * u * .04), c + Offset(0, u * .08 + pulse * u * .04), stroke(Colors.white, w));
      canvas.drawPath(
          Path()
            ..moveTo(c.dx - u * .1, c.dy + pulse * u * .04)
            ..lineTo(c.dx, c.dy + u * .12 + pulse * u * .04)
            ..lineTo(c.dx + u * .1, c.dy + pulse * u * .04),
          stroke(Colors.white, w));
    }
  }
}
