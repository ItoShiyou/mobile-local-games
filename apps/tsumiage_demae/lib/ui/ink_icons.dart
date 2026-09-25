import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brush-drawn icons, used instead of the stock icon font so that every
/// mark on screen belongs to the same hand.
enum InkGlyph { back, settings, help, undo, redo, restart, hint, menu, play, book, sound, music, vibrate, trash, close, info }

class InkIcon extends StatelessWidget {
  const InkIcon(this.glyph, {super.key, this.size = 24, this.color});
  final InkGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF3A2B22);
    return CustomPaint(size: Size.square(size), painter: _InkPainter(glyph, c));
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.g, this.color);
  final InkGlyph g;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.scale(s / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    Paint pw(double w) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final f = Paint()
      ..color = color
      ..isAntiAlias = true;
    Path path(List<Offset> pts) {
      final pa = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        pa.lineTo(o.dx, o.dy);
      }
      return pa;
    }

    void arrowHead(Offset tip, double angle, [double len = 5]) {
      canvas.drawPath(
          path([
            tip + Offset(math.cos(angle + 2.5), math.sin(angle + 2.5)) * len,
            tip,
            tip + Offset(math.cos(angle - 2.5), math.sin(angle - 2.5)) * len,
          ]),
          p);
    }

    switch (g) {
      case InkGlyph.back:
        canvas.drawPath(Path()..moveTo(19, 12.5)..quadraticBezierTo(12, 11, 5.5, 12), p);
        arrowHead(const Offset(5, 12), math.pi, 6);
      case InkGlyph.settings:
        // a tea kettle lid seen from above: cog with soft teeth
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(Offset(12 + math.cos(a) * 7, 12 + math.sin(a) * 7), Offset(12 + math.cos(a) * 9.6, 12 + math.sin(a) * 9.6), pw(3));
        }
        canvas.drawCircle(const Offset(12, 12), 6.6, p);
        canvas.drawCircle(const Offset(12, 12), 2.2, f);
      case InkGlyph.help:
        canvas.drawPath(Path()..moveTo(8.5, 8.5)..cubicTo(8.5, 3.5, 16.5, 3.8, 16, 8.6)..cubicTo(15.7, 11.5, 12, 11.5, 12, 15), p);
        canvas.drawCircle(const Offset(12, 19.3), 1.6, f);
      case InkGlyph.undo:
        canvas.drawPath(Path()..moveTo(6, 9.5)..cubicTo(12, 5, 21, 7, 19.5, 14)..cubicTo(18.5, 18, 14, 19, 11, 18.5), p);
        arrowHead(const Offset(5.5, 9.8), math.pi * .95);
      case InkGlyph.redo:
        canvas.drawPath(Path()..moveTo(18, 9.5)..cubicTo(12, 5, 3, 7, 4.5, 14)..cubicTo(5.5, 18, 10, 19, 13, 18.5), p);
        arrowHead(const Offset(18.5, 9.8), math.pi * .05);
      case InkGlyph.restart:
        canvas.drawArc(Rect.fromCircle(center: const Offset(12, 12.5), radius: 7.5), -math.pi * .35, math.pi * 1.7, false, p);
        arrowHead(Offset(12 + math.cos(-math.pi * .35) * 7.5, 12.5 + math.sin(-math.pi * .35) * 7.5), -math.pi * .9);
      case InkGlyph.hint:
        // chochin lantern
        canvas.drawLine(const Offset(12, 2), const Offset(12, 4.5), p);
        canvas.drawPath(Path()..addOval(const Rect.fromLTRB(5.5, 4.5, 18.5, 19.5)), p);
        for (final y in [9.0, 12.0, 15.0]) {
          canvas.drawLine(Offset(6.5, y), Offset(17.5, y), pw(1.3));
        }
        canvas.drawLine(const Offset(9, 20.5), const Offset(15, 20.5), p);
        canvas.drawLine(const Offset(9, 3.6), const Offset(15, 3.6), p);
      case InkGlyph.menu:
        // folded menu card
        canvas.drawPath(path(const [Offset(4, 5), Offset(12, 6.5), Offset(20, 5), Offset(20, 19), Offset(12, 20.5), Offset(4, 19)])..close(), p);
        canvas.drawLine(const Offset(12, 6.5), const Offset(12, 20.5), p);
        for (final y in [10.0, 13.5]) {
          canvas.drawLine(Offset(6.5, y), Offset(9.8, y + .3), pw(1.6));
          canvas.drawLine(Offset(14.2, y + .3), Offset(17.5, y), p);
        }
      case InkGlyph.play:
        canvas.drawPath(path(const [Offset(8, 5), Offset(19, 12), Offset(8, 19)])..close(), f);
      case InkGlyph.book:
        canvas.drawPath(Path()..moveTo(12, 7)..quadraticBezierTo(8, 4.5, 3.5, 5.5)..lineTo(3.5, 18.5)..quadraticBezierTo(8, 17.5, 12, 20), p);
        canvas.drawPath(Path()..moveTo(12, 7)..quadraticBezierTo(16, 4.5, 20.5, 5.5)..lineTo(20.5, 18.5)..quadraticBezierTo(16, 17.5, 12, 20), p);
        canvas.drawLine(const Offset(12, 7), const Offset(12, 20), p);
      case InkGlyph.sound:
        canvas.drawPath(path(const [Offset(4, 9.5), Offset(8, 9.5), Offset(12.5, 5.5), Offset(12.5, 18.5), Offset(8, 14.5), Offset(4, 14.5)])..close(), p);
        canvas.drawArc(Rect.fromCircle(center: const Offset(13, 12), radius: 4.5), -.9, 1.8, false, p);
        canvas.drawArc(Rect.fromCircle(center: const Offset(13, 12), radius: 8), -.9, 1.8, false, p);
      case InkGlyph.music:
        canvas.drawLine(const Offset(9.5, 17), const Offset(9.5, 5), p);
        canvas.drawPath(Path()..moveTo(9.5, 5)..quadraticBezierTo(14, 6, 18, 4)..lineTo(18, 15), p);
        canvas.drawOval(Rect.fromCenter(center: const Offset(7.3, 17.5), width: 5.5, height: 4.2), f);
        canvas.drawOval(Rect.fromCenter(center: const Offset(15.8, 15.5), width: 5.5, height: 4.2), f);
      case InkGlyph.vibrate:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(8, 3.5, 16, 20.5), const Radius.circular(2.5)), p);
        for (final sx in [-1.0, 1.0]) {
          canvas.drawPath(path([Offset(12 + sx * 7, 8), Offset(12 + sx * 9, 10), Offset(12 + sx * 7, 12), Offset(12 + sx * 9, 14), Offset(12 + sx * 7, 16)]), pw(1.7));
        }
      case InkGlyph.trash:
        canvas.drawLine(const Offset(4.5, 6.5), const Offset(19.5, 6.5), p);
        canvas.drawPath(path(const [Offset(6.5, 7), Offset(7.8, 20), Offset(16.2, 20), Offset(17.5, 7)]), p);
        canvas.drawPath(path(const [Offset(9.5, 6.3), Offset(10, 3.8), Offset(14, 3.8), Offset(14.5, 6.3)]), p);
      case InkGlyph.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), p);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), p);
      case InkGlyph.info:
        canvas.drawCircle(const Offset(12, 12), 9, p);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 17), p);
        canvas.drawCircle(const Offset(12, 7.3), 1.4, f);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.g != g || old.color != color;
}
