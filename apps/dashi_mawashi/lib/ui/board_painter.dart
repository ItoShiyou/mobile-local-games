import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import 'art.dart';
import 'paper.dart';
import 'scene.dart';

/// Colour of each stock and of each mix.
const Map<String, Color> stockColor = {
  'k': Color(0xFFE39A3F), // katsuo: amber
  'n': Color(0xFF5E9A4C), // kombu: green
  's': Color(0xFF8A5A3C), // shiitake: brown
  'kn': Color(0xFFD8B03A), // awase: gold
  'ks': Color(0xFFB8743A),
  'ns': Color(0xFF7E8A48),
  'kns': Color(0xFF9E7A36),
};

/// Everything the painter needs for one frame.
class BoardFrame {
  const BoardFrame({
    required this.state,
    required this.palette,
    required this.scene,
    this.transition,
    this.transitionP = 1,
    this.bump,
    this.bumpAge = 99,
    this.hint,
    this.cursor,
    this.time = 0,
  });

  final GameState state;
  final Palette palette;
  final Scene scene;
  final Transition? transition;
  final double transitionP;
  final Bump? bump;
  final double bumpAge;
  final Pos? hint;

  /// Keyboard cursor, shown only once the keyboard is used.
  final Pos? cursor;

  /// Seconds, for idle animation. Frozen at 0 when motion is reduced.
  final double time;

  bool get night => palette.night || scene.alwaysNight;
}

Duration transitionDuration(Transition t) => t.isUndo ? const Duration(milliseconds: 120) : const Duration(milliseconds: 200);

int _hash(int x, int y, [int salt = 0]) {
  var h = x * 374761393 + y * 668265263 + salt * 2246822519;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// Draws the counter, the pipes and the stock in them.
class BoardPainter {
  BoardPainter(this.f);
  final BoardFrame f;

  void paint(Canvas canvas, Size size) {
    final s = f.state;
    final b = s.board;
    final u = size.width / b.width;
    final t = f.time;
    final flow = s.flow;
    final all = Offset.zero & size;

    // ---- the counter: planks under a lacquered frame ----
    final frame = RRect.fromRectAndRadius(all.inflate(u * .18), Radius.circular(u * .16));
    canvas.drawRRect(frame.shift(Offset(0, u * .08)), Art.fill(const Color(0x40000000)));
    canvas.drawRRect(frame, Art.fill(const Color(0xFF6B4A33)));
    canvas.drawRRect(frame, Art.stroke(kInk, math.max(1.4, u * .04)));
    canvas.save();
    canvas.clipRect(all);
    final sc = f.scene;
    final ph = u / 2;
    for (var r = 0; r * ph < size.height; r++) {
      var x = -((_hash(r, 1) % 100) / 100) * u;
      var k = 0;
      while (x < size.width) {
        final len = u * (1.2 + (_hash(r, k, 3) % 100) / 70);
        canvas.drawRect(Rect.fromLTWH(x, r * ph, len, ph), Art.fill(Color.lerp(sc.floorA, sc.floorB, (_hash(r, k, 5) % 3) / 2)!));
        canvas.drawLine(Offset(x, r * ph), Offset(x, r * ph + ph), Art.stroke(sc.floorLine.withValues(alpha: .5), 1));
        x += len;
        k++;
      }
      canvas.drawLine(Offset(0, r * ph), Offset(size.width, r * ph), Art.stroke(sc.floorLine.withValues(alpha: .5), 1));
    }
    canvas.restore();

    // ---- cells ----
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        final c = b.at(x, y);
        final r = Rect.fromLTWH(x * u, y * u, u, u);
        if (c == '#') {
          // a stone: nothing passes here
          final stone = RRect.fromRectAndRadius(r.deflate(u * .08), Radius.circular(u * .2));
          canvas.drawRRect(stone.shift(Offset(0, u * .05)), Art.fill(const Color(0x33000000)));
          canvas.drawRRect(stone, Art.fill(const Color(0xFF9C968A)));
          canvas.drawRRect(stone, Art.stroke(kInk, math.max(1.2, u * .03)));
          canvas.drawCircle(r.center + Offset(-u * .12, -u * .1), u * .06, Art.fill(const Color(0x33FFFFFF)));
          continue;
        }
        // a shallow tray for each cell
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(u * .04), Radius.circular(u * .08)), Art.fill(const Color(0x14000000)));
      }
    }

    // ---- pipes ----
    final tr = f.transition;
    final p = tr == null ? 1.0 : f.transitionP;
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        final kind = b.at(x, y);
        if (!b.isPipe(x, y)) continue;
        final center = Offset((x + .5) * u, (y + .5) * u);
        var angle = 0.0;
        if (tr != null && !tr.isUndo && tr.cell == Pos(x, y) && p < 1) {
          angle = -(1 - Curves.easeOutBack.transform(p)) * math.pi / 2;
        }
        var shake = Offset.zero;
        if (f.bump != null && f.bump!.cell == Pos(x, y) && f.bumpAge < .3) {
          shake = Offset(math.sin(f.bumpAge * 60) * u * .04 * (1 - f.bumpAge / .3), 0);
        }
        final hinted = f.hint == Pos(x, y);
        if (hinted) {
          final pulse = (math.sin(t * 4) + 1) / 2;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: u * .96, height: u * .96), Radius.circular(u * .14)),
            Paint()
              ..color = f.palette.glow.withValues(alpha: .35 + .35 * pulse)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .08),
          );
        }
        canvas.save();
        canvas.translate(center.dx + shake.dx, center.dy + shake.dy);
        canvas.rotate(angle);
        _pipe(canvas, b, flow, x, y, kind, s.maskAt(x, y), u, t, iron: b.fixed.contains(Pos(x, y)), settled: angle == 0);
        canvas.restore();
        if (hinted) Art.paws(canvas, center + Offset(u * .28, u * .28), u * .7, f.palette.shu, .8);
      }
    }

    // ---- pots and bowls ----
    for (final pot in b.pots) {
      _pot(canvas, pot, u, t);
    }
    for (var i = 0; i < b.bowls.length; i++) {
      _bowl(canvas, b.bowls[i], flow.bowls[i], u, t, flow.won);
    }

    // ---- stock spilling out of open ends ----
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        final m = s.maskAt(x, y);
        if (m == 0) continue;
        if (tr != null && tr.cell == Pos(x, y) && p < 1) continue;
        for (final d in Dir.values) {
          if (m & d.bit == 0 || !flow.spills(b, x, y, d)) continue;
          final carry = flow.carry(b, x, y, b.channel(x, y, d));
          final color = stockColor[carry] ?? const Color(0xFFB0A080);
          final end = Offset((x + .5 + d.dx * .5) * u, (y + .5 + d.dy * .5) * u);
          final k = (t * 1.6 + x * .3 + y * .7) % 1;
          canvas.drawOval(Rect.fromCenter(center: end + Offset(0, u * .12), width: u * .34, height: u * .12), Art.fill(color.withValues(alpha: .45)));
          canvas.drawCircle(end + Offset(0, k * u * .14), u * .045 * (1 - k * .5), Art.fill(color));
        }
      }
    }

    // ---- keyboard cursor ----
    final cur = f.cursor;
    if (cur != null) {
      final r = Rect.fromLTWH(cur.x * u, cur.y * u, u, u).deflate(u * .03);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u * .1)), Art.stroke(f.palette.shu, math.max(2, u * .05)));
    }

    PaperGrain.paint(canvas, all, opacity: .4);
    if (f.night) {
      canvas.drawRect(all.inflate(u), Paint()
        ..color = const Color(0xFFE2D6C8)
        ..blendMode = BlendMode.modulate);
    }
  }

  /// A bamboo (or iron) pipe centred on the origin, with the stock inside.
  void _pipe(Canvas canvas, Board b, StockFlow flow, int x, int y, String kind, int mask, double u, double t, {required bool iron, required bool settled}) {
    final shell = iron ? const Color(0xFF7D7B78) : const Color(0xFFC9B07A);
    final shellDark = iron ? const Color(0xFF5E5C58) : const Color(0xFF9E8650);
    final arms = [for (final d in Dir.values) if (mask & d.bit != 0) d];

    void arm(Dir d, double width, Color c) {
      canvas.drawLine(Offset.zero, Offset(d.dx * u * .5, d.dy * u * .5), Paint()
        ..color = c
        ..strokeWidth = width
        ..strokeCap = StrokeCap.butt);
    }

    void tube(List<Dir> dirs, int ch) {
      for (final d in dirs) {
        arm(d, u * .36, kInk);
      }
      for (final d in dirs) {
        arm(d, u * .28, shell);
      }
      // bamboo nodes near the ends
      for (final d in dirs) {
        final at = Offset(d.dx * u * .36, d.dy * u * .36);
        final across = Offset(d.dy.toDouble(), d.dx.toDouble()) * u * .14;
        canvas.drawLine(at - across, at + across, Art.stroke(shellDark, math.max(1, u * .03)));
      }
      final carry = settled ? flow.carry(b, x, y, ch) : '';
      if (carry.isNotEmpty) {
        final color = stockColor[carry]!;
        for (final d in dirs) {
          arm(d, u * .13, color);
        }
        // a slow shimmer running along the stock
        final k = (t * .8 + (x + y) * .17) % 1;
        for (final d in dirs) {
          canvas.drawCircle(Offset(d.dx * u * .5 * k, d.dy * u * .5 * k), u * .035, Art.fill(Colors.white.withValues(alpha: .35)));
        }
      }
    }

    if (kind == 'X') {
      // up-down underneath, left-right bridging over it
      tube([Dir.up, Dir.down], 0);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: u * .5, height: u * .44), Art.fill(const Color(0x33000000)));
      tube([Dir.left, Dir.right], 1);
      canvas.drawLine(Offset(-u * .5, -u * .18), Offset(u * .5, -u * .18), Art.stroke(kInk, math.max(1, u * .025)));
      canvas.drawLine(Offset(-u * .5, u * .18), Offset(u * .5, u * .18), Art.stroke(kInk, math.max(1, u * .025)));
    } else {
      tube(arms, 0);
      if (arms.length > 1 && kind != 'I') {
        final carry = settled ? flow.carry(b, x, y, 0) : '';
        canvas.drawCircle(Offset.zero, u * .19, Art.fill(kInk));
        canvas.drawCircle(Offset.zero, u * .15, Art.fill(shell));
        if (carry.isNotEmpty) canvas.drawCircle(Offset.zero, u * .08, Art.fill(stockColor[carry]!));
      }
    }
    if (iron) {
      for (final (dx, dy) in [(-.3, -.3), (.3, -.3), (-.3, .3), (.3, .3)]) {
        canvas.drawCircle(Offset(dx * u, dy * u), u * .045, Art.fill(const Color(0xFF4A4845)));
      }
    }
  }

  void _pot(Canvas canvas, Pot pot, double u, double t) {
    final c = Offset((pot.pos.x + .5) * u, (pot.pos.y + .5) * u);
    // the spout
    final d = pot.dir;
    canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Art.stroke(kInk, u * .3));
    canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Art.stroke(const Color(0xFF4A3A30), u * .22));
    canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Art.stroke(stockColor[pot.stock]!, u * .1));
    Art.shadow(canvas, c + Offset(0, u * .3), u * .7, u * .14);
    final body = Rect.fromCenter(center: c + Offset(0, u * .04), width: u * .74, height: u * .6);
    canvas.drawOval(body, Art.fill(const Color(0xFF3F3530)));
    canvas.drawOval(body, Art.stroke(kInk, math.max(1.2, u * .035)));
    canvas.drawOval(Rect.fromCenter(center: c - Offset(0, u * .06), width: u * .56, height: u * .24), Art.fill(stockColor[pot.stock]!));
    for (final sx in [-1.0, 1.0]) {
      canvas.drawLine(c + Offset(sx * u * .37, -u * .02), c + Offset(sx * u * .47, -u * .06), Art.stroke(kInk, u * .05));
    }
    final label = const {'k': '鰹', 'n': '昆', 's': '椎'}[pot.stock]!;
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(fontFamily: displayFont, fontSize: u * .24, color: const Color(0xFFFFF7EA))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, u * .06));
    // steam
    for (final k in [-1.0, 1.0]) {
      final sway = math.sin(t * 2 + k) * u * .04;
      final path = Path()
        ..moveTo(c.dx + k * u * .1, c.dy - u * .2)
        ..quadraticBezierTo(c.dx + k * u * .18 + sway, c.dy - u * .34, c.dx + k * u * .08, c.dy - u * .46);
      canvas.drawPath(path, Art.stroke(Colors.white.withValues(alpha: .75), math.max(1, u * .03)));
    }
  }

  void _bowl(Canvas canvas, Bowl bowl, String got, double u, double t, bool won) {
    final c = Offset((bowl.pos.x + .5) * u, (bowl.pos.y + .5) * u);
    final d = bowl.dir;
    canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Art.stroke(kInk, u * .3));
    canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Art.stroke(const Color(0xFFC9B07A), u * .22));
    if (got.isNotEmpty) {
      canvas.drawLine(c, c + Offset(d.dx * u * .5, d.dy * u * .5), Art.stroke(stockColor[got] ?? Colors.grey, u * .1));
    }
    Art.shadow(canvas, c + Offset(0, u * .3), u * .7, u * .14);
    final rim = Rect.fromCenter(center: c - Offset(0, u * .06), width: u * .76, height: u * .26);
    final body = Path()
      ..moveTo(rim.left, rim.center.dy)
      ..quadraticBezierTo(rim.left + u * .04, c.dy + u * .34, c.dx, c.dy + u * .34)
      ..quadraticBezierTo(rim.right - u * .04, c.dy + u * .34, rim.right, rim.center.dy)
      ..close();
    canvas.drawPath(body, Art.fill(const Color(0xFF8E2A22)));
    canvas.drawPath(body, Art.stroke(kInk, math.max(1.2, u * .035)));
    canvas.drawOval(rim, Art.fill(const Color(0xFF2A1E18)));
    canvas.drawOval(rim.deflate(u * .04), Art.fill(got.isEmpty ? const Color(0xFF3A2B22) : (stockColor[got] ?? Colors.grey)));
    canvas.drawOval(rim, Art.stroke(kInk, math.max(1.2, u * .035)));
    // the order: a ring in the colour this bowl wants, on the side of the bowl
    final want = stockColor[bowl.want]!;
    canvas.drawCircle(c + Offset(0, u * .17), u * .1, Art.fill(const Color(0xFFFBF5EA)));
    canvas.drawCircle(c + Offset(0, u * .17), u * .1, Art.stroke(want, u * .05));
    if (got == bowl.want) {
      Art.hanko(canvas, c + Offset(u * .28, -u * .3), u * .16, '済');
      if (won) {
        final k = (t * .7) % 1;
        canvas.drawCircle(c + Offset(0, -u * (.2 + k * .3)), u * .04 * (1 - k), Art.fill(Colors.white.withValues(alpha: .7 * (1 - k))));
      }
    }
  }
}
