import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import 'art.dart';
import 'paper.dart';
import 'scene.dart';

/// Everything the painter needs for one frame.
class BoardFrame {
  const BoardFrame({
    required this.state,
    required this.palette,
    required this.scene,
    this.transition,
    this.transitionP = 1,
    this.transitionAge = 99,
    this.bump,
    this.bumpAge = 99,
    this.hint,
    this.time = 0,
  });

  final GameState state;
  final Palette palette;
  final Scene scene;
  final Transition? transition;

  /// 0..1 progress of [transition], and seconds since it started.
  final double transitionP;
  final double transitionAge;
  final Bump? bump;
  final double bumpAge;
  final Dir? hint;

  /// Seconds, for idle animation. Frozen at 0 when motion is reduced.
  final double time;

  double get bumpP => (bumpAge / .22).clamp(0.0, 1.0);
  bool get night => palette.night || scene.alwaysNight;
}

/// Duration of a transition, longer when there is more to show.
Duration transitionDuration(Transition t) {
  if (t.isUndo) return const Duration(milliseconds: 110);
  final flip = t.events.any((e) => e is Flipped);
  final pick = t.events.any((e) => e is PickedUp);
  if (flip && pick) return const Duration(milliseconds: 480);
  if (flip) return const Duration(milliseconds: 400);
  if (t.events.any((e) => e is Served || e is Returned)) return const Duration(milliseconds: 340);
  if (pick) return const Duration(milliseconds: 250);
  return const Duration(milliseconds: 150);
}

/// Height of the visible front face of a wall, as a fraction of a cell.
const double wallDepth = .4;

int _hash(int x, int y, [int salt = 0]) {
  var h = x * 374761393 + y * 668265263 + salt * 2246822519;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

bool _isWall(Board b, int x, int y) {
  final c = b.at(x, y);
  return c == '#' || c == ' ';
}

/// The parts of the board that never change during a stage, recorded once.
class SceneLayers {
  SceneLayers._(this.base, this.lights, this.key);
  final ui.Picture base;
  final ui.Picture lights;
  final String key;

  static String keyFor(Board b, double u, Scene s, bool night) => '${b.grid.map((r) => r.join()).join('/')}|$u|${s.id}|$night';

  factory SceneLayers.build(Board b, double u, Scene sc, Palette pal, bool night) {
    final lightsAt = <(Offset, double)>[];
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    _paintRoomShadow(canvas, b, u);
    _paintFloor(canvas, b, u, sc);
    if (sc.sunny && !night) _paintSunlight(canvas, b, u);
    _paintShadows(canvas, b, u);
    _paintWalls(canvas, b, u, sc, pal, lightsAt, night);
    _paintFixtures(canvas, b, u);
    final base = rec.endRecording();

    final lr = ui.PictureRecorder();
    final lc = Canvas(lr);
    if (night) {
      for (final (o, r) in lightsAt) {
        final rect = Rect.fromCircle(center: o, radius: r);
        lc.drawCircle(
          o,
          r,
          Paint()
            ..blendMode = BlendMode.screen
            ..shader = RadialGradient(colors: [pal.glow.withValues(alpha: .4), pal.glow.withValues(alpha: 0)]).createShader(rect),
        );
      }
    }
    return SceneLayers._(base, lr.endRecording(), keyFor(b, u, sc, night));
  }

  void dispose() {
    base.dispose();
    lights.dispose();
  }

  static void _paintFloor(Canvas c, Board b, double u, Scene sc) {
    final floor = Path();
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (!_isWall(b, x, y)) floor.addRect(Rect.fromLTWH(x * u, y * u, u + .5, u + .5));
      }
    }
    c.save();
    c.clipPath(floor);
    final all = Rect.fromLTWH(0, 0, b.width * u, b.height * u);
    c.drawRect(all, Art.fill(sc.floorA));
    final line = Art.stroke(sc.floorLine, math.max(1, u * .02));
    switch (sc.floor) {
      case FloorKind.planks:
        final h = u / 3;
        for (var r = 0; r * h < all.height; r++) {
          var x = -(_hash(r, 1) % 100) / 100 * u * 1.5;
          var k = 0;
          while (x < all.width) {
            final len = u * (1.4 + (_hash(r, k, 3) % 100) / 60);
            final tone = (_hash(r, k, 5) % 3);
            c.drawRect(Rect.fromLTWH(x, r * h, len, h), Art.fill(Color.lerp(sc.floorA, sc.floorB, tone / 2)!));
            // grain
            final gy = r * h + h * (.3 + (_hash(r, k, 9) % 40) / 100);
            c.drawLine(Offset(x + u * .15, gy), Offset(x + len * .7, gy + u * .01), Art.stroke(sc.floorLine.withValues(alpha: .35), u * .012));
            c.drawLine(Offset(x, r * h), Offset(x, r * h + h), line);
            x += len;
            k++;
          }
          c.drawLine(Offset(0, r * h), Offset(all.width, r * h), line);
        }
      case FloorKind.tiles:
        final t = u / 2;
        for (var j = 0; j * t < all.height; j++) {
          for (var i = 0; i * t < all.width; i++) {
            final r = Rect.fromLTWH(i * t, j * t, t, t);
            c.drawRect(r, Art.fill((i + j).isEven ? sc.floorA : sc.floorB));
          }
        }
        for (var j = 0; j * t <= all.height; j++) {
          c.drawLine(Offset(0, j * t), Offset(all.width, j * t), Art.stroke(sc.floorLine, u * .015));
        }
        for (var i = 0; i * t <= all.width; i++) {
          c.drawLine(Offset(i * t, 0), Offset(i * t, all.height), Art.stroke(sc.floorLine, u * .015));
        }
      case FloorKind.parquet:
        final t = u / 2;
        for (var j = 0; j * t < all.height; j++) {
          for (var i = 0; i * t < all.width; i++) {
            final horizontal = (i + j).isEven;
            for (var k = 0; k < 3; k++) {
              final r = horizontal ? Rect.fromLTWH(i * t, j * t + k * t / 3, t, t / 3) : Rect.fromLTWH(i * t + k * t / 3, j * t, t / 3, t);
              c.drawRect(r, Art.fill(Color.lerp(sc.floorA, sc.floorB, (_hash(i, j, k) % 3) / 2)!));
              c.drawRect(r, Art.stroke(sc.floorLine.withValues(alpha: .7), u * .012));
            }
          }
        }
      case FloorKind.stones:
        c.drawRect(all, Art.fill(sc.floorLine.withValues(alpha: .55)));
        for (var j = 0; j < b.height * 2; j++) {
          final off = j.isOdd ? u * .25 : 0.0;
          for (var i = -1; i < b.width * 2; i++) {
            final r = Rect.fromLTWH(i * u / 2 + off + u * .025, j * u / 2 + u * .025, u / 2 - u * .05, u / 2 - u * .05);
            final tone = Color.lerp(sc.floorA, sc.floorB, (_hash(i, j, 2) % 4) / 3)!;
            c.drawPath(Wob.rrect(r, u * .08, seed: _hash(i, j), amp: u * .01), Art.fill(tone));
          }
        }
      case FloorKind.earth:
        final rnd = math.Random(3);
        for (var i = 0; i < b.width * b.height * 10; i++) {
          final o = Offset(rnd.nextDouble() * all.width, rnd.nextDouble() * all.height);
          c.drawCircle(o, u * (.01 + rnd.nextDouble() * .025), Art.fill((rnd.nextBool() ? sc.floorB : sc.floorLine).withValues(alpha: .6)));
        }
    }
    c.restore();
  }

  /// Soft patches of daylight slanting in from the windows.
  static void _paintSunlight(Canvas c, Board b, double u) {
    final floor = Path();
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (!_isWall(b, x, y)) floor.addRect(Rect.fromLTWH(x * u, y * u, u + .5, u + .5));
      }
    }
    final all = Rect.fromLTWH(0, 0, b.width * u, b.height * u);
    c.save();
    c.clipPath(floor);
    // the whole room a touch warmer and brighter near the windows
    c.drawRect(
        all,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x40FFF1CC), Color(0x14FFF1CC), Color(0x00FFF1CC)],
          ).createShader(all));
    // slanted window panes of light
    final pane = Paint()
      ..blendMode = BlendMode.screen
      ..color = const Color(0x38FFF6DC)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .12);
    final slope = u * .7;
    for (var k = 0; k * u * 2.6 < all.width + all.height; k++) {
      final x0 = u * .8 + k * u * 2.6;
      final path = Path()
        ..moveTo(x0, 0)
        ..lineTo(x0 + u * 1.1, 0)
        ..lineTo(x0 + u * 1.1 - all.height / u * slope, all.height)
        ..lineTo(x0 - all.height / u * slope, all.height)
        ..close();
      c.drawPath(path, pane);
    }
    c.restore();
  }

  static void _paintShadows(Canvas c, Board b, double u) {
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (_isWall(b, x, y)) continue;
        if (_isWall(b, x, y - 1)) {
          final r = Rect.fromLTWH(x * u, y * u, u, u * .32);
          c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x2C281810), Color(0x00281810)]).createShader(r));
        }
        for (final sx in [-1, 1]) {
          if (_isWall(b, x + sx, y)) {
            final r = Rect.fromLTWH(sx < 0 ? x * u : x * u + u * .84, y * u, u * .16, u);
            c.drawRect(
                r,
                Paint()
                  ..shader = LinearGradient(
                    begin: sx < 0 ? Alignment.centerLeft : Alignment.centerRight,
                    end: sx < 0 ? Alignment.centerRight : Alignment.centerLeft,
                    colors: const [Color(0x1C281810), Color(0x00281810)],
                  ).createShader(r));
          }
        }
      }
    }
  }

  static bool _nearFloor(Board b, int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (b.inside(x + dx, y + dy) && !_isWall(b, x + dx, y + dy)) return true;
      }
    }
    return false;
  }

  static void _paintWalls(Canvas c, Board b, double u, Scene sc, Palette pal, List<(Offset, double)> lights, bool night) {
    final w = u * .03;
    final d = u * wallDepth;
    final caps = <Rect>[];
    final fronts = <(Rect, int, int)>[];
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (!_isWall(b, x, y)) continue;
        final o = Offset(x * u, y * u);
        if (_isRing(b, x, y)) {
          _ringWall(b, x, y, u, d, caps, fronts);
          continue;
        }
        if (!_nearFloor(b, x, y)) {
          // a solid block inside the room (a built-in cupboard, a stall)
          final r = Rect.fromLTWH(o.dx, o.dy, u + .5, u + .5);
          c.drawRect(r, Art.fill(Color.lerp(sc.wallTop, Colors.black, .12)!));
          c.drawLine(o + Offset(u * .15, u * .5), o + Offset(u * .85, u * .5), Art.stroke(Color.lerp(sc.wallTop, Colors.black, .25)!, u * .02));
          continue;
        }
        final hasFront = b.inside(x, y + 1) && !_isWall(b, x, y + 1);
        final top = Rect.fromLTWH(o.dx, o.dy, u + .5, hasFront ? u - d : u + .5);
        _wallTop(c, top, u, sc);
        if (hasFront) {
          final front = Rect.fromLTWH(o.dx, o.dy + u - d, u + .5, d);
          _wallFront(c, front, u, sc, x);
          c.drawLine(front.topLeft, front.topRight, Art.stroke(kInk.withValues(alpha: .7), w));
          c.drawLine(front.bottomLeft, front.bottomRight, Art.stroke(kInk, w * 1.2));
        }
        // a lighter cap along the edges that face the room
        final cap = Art.fill(Color.lerp(sc.wallTop, Colors.white, .22)!);
        final cw = u * .07;
        if (b.inside(x - 1, y) && !_isWall(b, x - 1, y)) c.drawRect(Rect.fromLTWH(o.dx, o.dy, cw, top.height), cap);
        if (b.inside(x + 1, y) && !_isWall(b, x + 1, y)) c.drawRect(Rect.fromLTWH(o.dx + u - cw, o.dy, cw, top.height), cap);
        if (b.inside(x, y - 1) && !_isWall(b, x, y - 1)) c.drawRect(Rect.fromLTWH(o.dx, o.dy, u, cw), cap);
        if (hasFront) c.drawRect(Rect.fromLTWH(o.dx, top.bottom - cw, u, cw), cap);
        // ink edges where the wall meets the floor
        if (b.inside(x - 1, y) && !_isWall(b, x - 1, y)) {
          c.drawPath(Wob.line(o, o + Offset(0, u), seed: x * 7 + y, amp: u * .006), Art.stroke(kInk, w));
        }
        if (b.inside(x + 1, y) && !_isWall(b, x + 1, y)) {
          c.drawPath(Wob.line(o + Offset(u, 0), o + Offset(u, u), seed: x * 5 + y, amp: u * .006), Art.stroke(kInk, w));
        }
        if (b.inside(x, y - 1) && !_isWall(b, x, y - 1)) {
          c.drawPath(Wob.line(o, o + Offset(u, 0), seed: x + y * 3, amp: u * .006), Art.stroke(kInk, w));
        }
        // decoration
        final h = _hash(x, y, 11);
        if (h % 100 < 42) {
          final dec = sc.decor[h % sc.decor.length];
          if (dec.front && !hasFront) continue;
          final at = dec.front ? Offset(o.dx + u / 2, o.dy + u - d / 2) : Offset(o.dx + u / 2, o.dy + (hasFront ? (u - d) / 2 : u / 2));
          _decor(c, dec, at, u, pal, h);
          if (dec.light) lights.add((at, u * 1.3));
          if (night && dec == Decor.window) lights.add((at, u * .8));
        }
      }
    }
    _paintRing(c, b, u, sc, pal, caps, fronts, lights, night);
  }

  static bool _isRing(Board b, int x, int y) => x == 0 || y == 0 || x == b.width - 1 || y == b.height - 1;

  /// Outer walls are drawn thin, hugging the floor, so the room sits on the
  /// shop wall behind it instead of inside a thick frame.
  static void _ringWall(Board b, int x, int y, double u, double d, List<Rect> caps, List<(Rect, int, int)> fronts) {
    final t = u * .2;
    final o = Offset(x * u, y * u);
    bool floorAt(int xx, int yy) => b.inside(xx, yy) && !_isWall(b, xx, yy);
    final top = y == 0, bottom = y == b.height - 1, left = x == 0, right = x == b.width - 1;
    if (top && !left && !right) {
      if (floorAt(x, y + 1)) {
        caps.add(Rect.fromLTWH(o.dx, o.dy + u - d - t, u, t));
        fronts.add((Rect.fromLTWH(o.dx, o.dy + u - d, u, d), x, y));
      } else {
        caps.add(Rect.fromLTWH(o.dx, o.dy + u - d - t, u, d + t));
      }
    }
    if (bottom && !left && !right) {
      caps.add(Rect.fromLTWH(o.dx, o.dy, u, t));
      fronts.add((Rect.fromLTWH(o.dx, o.dy + t, u, u * .14), -1, -1));
    }
    if (left || right) {
      final y0 = top ? o.dy + u - d - t : o.dy;
      final y1 = bottom ? o.dy + t : o.dy + u;
      final x0 = left ? o.dx + u - t : o.dx;
      caps.add(Rect.fromLTRB(x0, y0, x0 + t, y1));
      if (bottom) fronts.add((Rect.fromLTWH(x0, o.dy + t, t, u * .14), -1, -1));
    }
  }

  static void _paintRing(Canvas c, Board b, double u, Scene sc, Palette pal, List<Rect> caps, List<(Rect, int, int)> fronts,
      List<(Offset, double)> lights, bool night) {
    final w = u * .03;
    Path union(Iterable<Rect> rs) {
      var p = Path();
      for (final r in rs) {
        p = Path.combine(PathOperation.union, p, Path()..addRect(r.inflate(.3)));
      }
      return p;
    }

    for (final (r, _, _) in fronts) {
      _wallFront(c, r, u, sc, (r.left / u).round());
    }
    final fp = union(fronts.map((e) => e.$1));
    c.drawPath(fp, Art.stroke(kInk, w));
    for (final (r, x, y) in fronts) {
      if (x < 0) continue;
      final h = _hash(x, y, 11);
      if (h % 100 < 55) {
        final dec = sc.decor[h % sc.decor.length];
        if (!dec.front) continue;
        final at = r.center;
        _decor(c, dec, at, u, pal, h);
        if (dec.light) lights.add((at, u * 1.3));
        if (night && dec == Decor.window) lights.add((at, u * .8));
      }
    }
    // fill piece by piece (a unioned ring would fill its hole too), then
    // outline the joined shape once so there are no seams
    final capColor = Color.lerp(sc.wallTop, Colors.white, .12)!;
    for (final r in caps) {
      c.drawRect(r.inflate(.3), Art.fill(capColor));
    }
    c.drawPath(union(caps), Art.stroke(kInk, w));
  }

  static void _paintRoomShadow(Canvas c, Board b, double u) {
    final room = Path();
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        if (!_isRing(b, x, y)) room.addRect(Rect.fromLTWH(x * u, y * u, u, u));
      }
    }
    c.drawPath(room.shift(Offset(0, u * .18)), Paint()
      ..color = const Color(0x40201008)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .3));
  }

  static void _wallTop(Canvas c, Rect r, double u, Scene sc) {
    c.drawRect(r, Art.fill(sc.wallTop));
    switch (sc.wall) {
      case WallKind.plaster:
      case WallKind.tiles:
      case WallKind.brick:
        c.drawLine(r.topLeft + Offset(0, r.height * .5), r.topRight + Offset(0, r.height * .5),
            Art.stroke(Color.lerp(sc.wallTop, Colors.black, .08)!, u * .015));
      case WallKind.fence:
        final h = _hash(r.left.toInt(), r.top.toInt());
        for (var k = 0; k < 4; k++) {
          c.drawCircle(r.topLeft + Offset(r.width * (.2 + .2 * k), r.height * (.35 + ((h >> k) % 3) * .15)), u * .14,
              Art.fill(Color.lerp(sc.wallTop, Colors.black, (k % 2) * .1)!));
        }
      case WallKind.stalls:
        final n = 4;
        for (var i = 0; i < n; i++) {
          if (i.isOdd) c.drawRect(Rect.fromLTWH(r.left + i * r.width / n, r.top, r.width / n + .5, r.height), Art.fill(const Color(0xFFE6D3BC)));
        }
    }
  }

  static void _wallFront(Canvas c, Rect r, double u, Scene sc, int x) {
    c.drawRect(r, Art.fill(sc.wallFront));
    switch (sc.wall) {
      case WallKind.plaster:
        c.drawRect(Rect.fromLTWH(r.left, r.bottom - r.height * .3, r.width, r.height * .3), Art.fill(sc.wallTrim));
      case WallKind.tiles:
        for (var j = 1; j < 3; j++) {
          c.drawLine(Offset(r.left, r.top + r.height * j / 3), Offset(r.right, r.top + r.height * j / 3), Art.stroke(const Color(0x55FFFFFF), u * .012));
        }
        for (var i = 1; i < 4; i++) {
          c.drawLine(Offset(r.left + r.width * i / 4, r.top), Offset(r.left + r.width * i / 4, r.bottom), Art.stroke(const Color(0x55FFFFFF), u * .012));
        }
      case WallKind.brick:
        final bh = r.height / 3;
        for (var j = 0; j < 3; j++) {
          c.drawLine(Offset(r.left, r.top + j * bh), Offset(r.right, r.top + j * bh), Art.stroke(const Color(0x66F3D9C0), u * .014));
          final off = (j + x).isOdd ? r.width / 4 : 0.0;
          for (var i = 0; i < 3; i++) {
            final xx = r.left + off + i * r.width / 2;
            if (xx > r.left && xx < r.right) c.drawLine(Offset(xx, r.top + j * bh), Offset(xx, r.top + (j + 1) * bh), Art.stroke(const Color(0x66F3D9C0), u * .014));
          }
        }
      case WallKind.fence:
        for (var i = 0; i < 4; i++) {
          final xx = r.left + r.width * (i + .5) / 4;
          c.drawLine(Offset(xx - r.width / 8, r.top), Offset(xx - r.width / 8, r.bottom), Art.stroke(sc.wallTrim.withValues(alpha: .6), u * .015));
        }
        c.drawLine(Offset(r.left, r.top + r.height * .35), Offset(r.right, r.top + r.height * .35), Art.stroke(sc.wallTrim, u * .03));
      case WallKind.stalls:
        c.drawRect(Rect.fromLTWH(r.left, r.bottom - r.height * .25, r.width, r.height * .25), Art.fill(sc.wallTrim));
    }
  }

  static void _decor(Canvas c, Decor d, Offset at, double u, Palette pal, int h) {
    final w = u * .025;
    switch (d) {
      case Decor.tanzaku:
        const colors = [Color(0xFFFFF8E8), Color(0xFFF7E3B5), Color(0xFFF3D1C4)];
        for (var i = -1; i <= 1; i++) {
          final r = Rect.fromCenter(center: at + Offset(i * u * .2, -u * .02), width: u * .13, height: u * .3);
          Art.inked(c, Path()..addRect(r), colors[(i + 1 + h) % 3], w * .7);
          for (var k = 0; k < 3; k++) {
            c.drawLine(r.topCenter + Offset(0, u * (.06 + k * .07)), r.topCenter + Offset(0, u * (.1 + k * .07)), Art.stroke(kInk.withValues(alpha: .7), w));
          }
        }
      case Decor.window:
        final r = Rect.fromCenter(center: at, width: u * .56, height: u * .3);
        Art.inked(c, Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(u * .03))), pal.night ? const Color(0xFFFFD98A) : const Color(0xFFBFDDEB), w);
        c.drawLine(r.topCenter, r.bottomCenter, Art.stroke(kInk, w));
        c.drawPath(Path()..moveTo(r.left, r.top)..quadraticBezierTo(r.left + r.width * .2, r.center.dy, r.left + r.width * .08, r.bottom)..lineTo(r.left, r.bottom)..close(), Art.fill(const Color(0xFFE9A0A0)));
      case Decor.shelf:
        c.drawLine(at + Offset(-u * .32, u * .1), at + Offset(u * .32, u * .1), Art.stroke(kInk, w * 2.5));
        const bottles = [Color(0xFF4E7A5A), Color(0xFF8A5A3A), Color(0xFFF4EEDF)];
        for (var i = 0; i < 3; i++) {
          final bx = at.dx - u * .2 + i * u * .2;
          Art.inked(c, Path()..addRRect(Art.rr(bx - u * .045, at.dy - u * .12, u * .09, u * .21, u * .03)), bottles[(i + h) % 3], w * .7);
        }
      case Decor.clock:
        Art.inked(c, Path()..addOval(Rect.fromCircle(center: at, radius: u * .13)), const Color(0xFFFFF8E8), w);
        c.drawLine(at, at + Offset(0, -u * .08), Art.stroke(kInk, w));
        c.drawLine(at, at + Offset(u * .06, 0), Art.stroke(kInk, w));
      case Decor.poster:
        final r = Rect.fromCenter(center: at, width: u * .34, height: u * .28);
        Art.inked(c, Path()..addRect(r), const Color(0xFFFFF4DC), w * .8);
        c.drawCircle(r.center + Offset(0, -u * .03), u * .06, Art.fill(pal.shu));
        c.drawLine(r.bottomLeft + Offset(u * .06, -u * .06), r.bottomRight + Offset(-u * .06, -u * .06), Art.stroke(kInk.withValues(alpha: .6), w));
      case Decor.lamp:
        c.drawLine(at + Offset(0, -u * .14), at + Offset(0, -u * .02), Art.stroke(kInk, w));
        final shade = Path()
          ..moveTo(at.dx - u * .1, at.dy + u * .08)
          ..lineTo(at.dx - u * .05, at.dy - u * .03)
          ..lineTo(at.dx + u * .05, at.dy - u * .03)
          ..lineTo(at.dx + u * .1, at.dy + u * .08)
          ..close();
        Art.inked(c, shade, const Color(0xFFF2C46B), w);
      case Decor.lantern:
        c.drawLine(at + Offset(0, -u * .2), at + Offset(0, -u * .12), Art.stroke(kInk, w));
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at, width: u * .2, height: u * .26)), const Color(0xFFD9483A), w);
        for (final dy in [-.05, .0, .05]) {
          c.drawLine(at + Offset(-u * .09, u * dy), at + Offset(u * .09, u * dy), Art.stroke(const Color(0x66000000), w * .5));
        }
        c.drawRect(Rect.fromCenter(center: at + Offset(0, -u * .13), width: u * .1, height: u * .03), Art.fill(kInk));
        c.drawRect(Rect.fromCenter(center: at + Offset(0, u * .13), width: u * .1, height: u * .03), Art.fill(kInk));
      case Decor.plant:
        Art.inked(c, Path()..addRRect(Art.rr(at.dx - u * .12, at.dy, u * .24, u * .18, u * .03)), const Color(0xFFB9643E), w);
        for (var i = -2; i <= 2; i++) {
          final leaf = Path()..addOval(Rect.fromCenter(center: at + Offset(i * u * .07, -u * (.08 + (2 - i.abs()) * .03)), width: u * .1, height: u * .2));
          Art.inked(c, leaf, i.isEven ? pal.leaf : Color.lerp(pal.leaf, Colors.black, .15)!, w * .7);
        }
      case Decor.maneki:
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at + Offset(0, u * .06), width: u * .26, height: u * .22)), const Color(0xFFFFFBF2), w);
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at + Offset(0, -u * .08), width: u * .24, height: u * .2)), const Color(0xFFFFFBF2), w);
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at + Offset(u * .14, -u * .12), width: u * .08, height: u * .1)), const Color(0xFFFFFBF2), w * .8);
        c.drawCircle(at + Offset(0, u * .03), u * .03, Art.fill(const Color(0xFFE9C46A)));
        c.drawLine(at + Offset(-u * .09, u * .0), at + Offset(u * .09, u * .0), Art.stroke(pal.shu, w * 1.5));
      case Decor.teapot:
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at, width: u * .3, height: u * .24)), const Color(0xFF5E6B55), w);
        c.drawLine(at + Offset(u * .14, 0), at + Offset(u * .22, -u * .07), Art.stroke(kInk, w * 2));
        c.drawCircle(at + Offset(0, -u * .1), u * .03, Art.fill(kInk));
      case Decor.cup:
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at + Offset(0, u * .04), width: u * .34, height: u * .16)), const Color(0xFFFFFBF2), w);
        Art.inked(c, Path()..addOval(Rect.fromCenter(center: at, width: u * .18, height: u * .1)), const Color(0xFF6B3E26), w * .8);
      case Decor.flowerpot:
        Art.inked(c, Path()..addRRect(Art.rr(at.dx - u * .1, at.dy + u * .02, u * .2, u * .14, u * .03)), const Color(0xFF9DB4C8), w);
        const petals = [Color(0xFFF08A9A), Color(0xFFF7D35C), Color(0xFFFFFFFF)];
        for (var i = -1; i <= 1; i++) {
          final fc = at + Offset(i * u * .09, -u * .07 - (i == 0 ? u * .04 : 0));
          c.drawLine(fc, fc + Offset(0, u * .1), Art.stroke(pal.leaf, w));
          Art.inked(c, Path()..addOval(Rect.fromCircle(center: fc, radius: u * .05)), petals[(i + 1 + h) % 3], w * .6);
        }
      case Decor.chochin:
        c.drawLine(at + Offset(-u * .5, -u * .15), at + Offset(u * .5, -u * .1), Art.stroke(kInk, w));
        for (final dx in [-.25, .25]) {
          final lc = at + Offset(u * dx, 0);
          Art.inked(c, Path()..addOval(Rect.fromCenter(center: lc, width: u * .18, height: u * .22)), dx < 0 ? const Color(0xFFF6EEDF) : const Color(0xFFD9483A), w);
          c.drawLine(lc + Offset(-u * .08, 0), lc + Offset(u * .08, 0), Art.stroke(const Color(0x55000000), w * .5));
        }
    }
  }

  /// Trays and painted arrows: fixed things on the floor.
  static void _paintFixtures(Canvas c, Board b, double u) {
    for (var y = 0; y < b.height; y++) {
      for (var x = 0; x < b.width; x++) {
        final ch = b.at(x, y);
        final center = Offset((x + .5) * u, (y + .5) * u);
        final arrow = arrowDirs[ch];
        if (arrow != null) Art.paintedArrow(c, center, u, arrow);
      }
    }
  }
}

/// Draws one frame: the cached scene, then everything that moves.
class BoardPainter {
  BoardPainter(this.f, this.layers);

  final BoardFrame f;
  final SceneLayers layers;

  static double _seg(double p, double a, double b) => ((p - a) / (b - a)).clamp(0.0, 1.0);

  void paint(Canvas canvas, Size size) {
    final s = f.state;
    final board = s.board;
    final u = size.width / board.width;
    final pal = f.palette;
    final t = f.time;
    final tr = f.transition;
    final p = tr == null ? 1.0 : f.transitionP;
    final events = tr?.events ?? const <MoveEvent>[];

    PickedUp? picked;
    Served? served;
    Returned? returned;
    var flipped = false;
    for (final e in events) {
      switch (e) {
        case PickedUp():
          picked = e;
        case Served():
          served = e;
        case Returned():
          returned = e;
        case Flipped():
          flipped = true;
        case Walked():
      }
    }
    final walkEnd = flipped ? (picked != null ? .35 : .45) : (picked != null ? .55 : 1.0);
    final pickA = flipped ? .3 : .45, pickB = flipped ? .62 : 1.0;
    final flipA = picked != null ? .6 : .45;

    final all = Offset.zero & size;
    // Everything on the board goes in one layer so that the evening tint
    // only darkens what is drawn (the room), not the transparent wall around it.
    canvas.saveLayer(all.inflate(u), Paint());
    canvas.drawPicture(layers.base);

    // ---- trays (they spin when used) ----
    for (var y = 0; y < board.height; y++) {
      for (var x = 0; x < board.width; x++) {
        if (board.at(x, y) != 's') continue;
        final spin = flipped && tr != null && tr.to.pos == Pos(x, y) ? _seg(p, flipA, 1) * math.pi : 0.0;
        Art.tray(canvas, Offset((x + .5) * u, (y + .5) * u), u, spin: spin);
      }
    }

    // ---- return counters ----
    for (var i = 0; i < board.counters.length; i++) {
      final cp = board.counters[i];
      final justUsed = returned?.counterIndex == i && p < .8;
      Art.counter(canvas, Offset(cp.x * u, cp.y * u), u, pal,
          used: s.isUsed(i) && !justUsed, depth: wallDepth, pulse: s.isUsed(i) ? 0 : (math.sin(t * 3) + 1) / 2);
    }

    // ---- dishes still on the floor ----
    for (var i = 0; i < board.dishes.length; i++) {
      final d = board.dishes[i];
      final waiting = picked?.dishIndex == i && p < pickA;
      if (s.isTaken(i) && !waiting) continue;
      Art.floorDish(canvas, Offset((d.pos.x + .5) * u, (d.pos.y + .5) * u), u, d.color);
    }

    // ---- hint: paw prints on the next cell ----
    final hint = f.hint;
    if (hint != null && (tr == null || p >= 1)) {
      final pulse = (math.sin(t * 4) + 1) / 2;
      Art.paws(canvas, Offset((s.pos.x + hint.dx + .5) * u, (s.pos.y + hint.dy + .5) * u), u, pal.shu, .45 + .45 * pulse);
    }

    // ---- courier position ----
    var pos = Offset(s.pos.x.toDouble(), s.pos.y.toDouble());
    var hop = 0.0;
    if (tr != null && p < 1) {
      final a = Offset(tr.from.pos.x.toDouble(), tr.from.pos.y.toDouble());
      final wp = Curves.easeOutCubic.transform(_seg(p, 0, walkEnd));
      if (a != pos && !tr.isUndo) hop = math.sin(_seg(p, 0, walkEnd) * math.pi) * u * .08;
      pos = Offset.lerp(a, pos, wp)!;
    }
    final bump = f.bump;
    final bq = bump == null ? 1.0 : f.bumpP;

    // ---- guests above the courier's row, courier, then the rest ----
    final catRow = pos.dy;
    void drawGuest(int i) {
      final g = board.guests[i];
      final o = Offset(g.pos.x * u, g.pos.y * u);
      final beingServed = served?.guestIndex == i && p < .72;
      final done = s.isServed(i) && !beingServed;
      final wrong = bump != null && bump.reason == Blocked.wrongDish && f.bumpAge < 1.1 &&
          s.pos.x + bump.dir.dx == g.pos.x && s.pos.y + bump.dir.dy == g.pos.y;
      final bob = done ? math.sin(t * 4 + i) * u * .01 : 0.0;
      Art.guest(canvas, o, u, i, pal,
          mood: done ? Mood.happy : (wrong ? Mood.upset : Mood.waiting), phase: t, servedDish: done ? g.wants : null, bob: bob);
      if (!done) {
        var bc = o + Offset(u * .76, u * .12 + math.sin(t * 2 + i) * u * .015);
        if (wrong && f.bumpAge < .5) bc += Offset(math.sin(f.bumpAge * math.pi * 12) * u * .04, 0);
        Art.orderTicket(canvas, bc, u, g.wants, upset: wrong, scale: wrong ? 1.12 : 1);
      } else if (served?.guestIndex == i && f.transitionAge < 1.4) {
        // a little tune when the order arrives
        final k = (f.transitionAge / 1.4).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(text: '♪', style: TextStyle(fontSize: u * .3, color: pal.shu.withValues(alpha: 1 - k), fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o + Offset(u * .65, u * (.05 - k * .3)));
      }
    }

    final order = List.generate(board.guests.length, (i) => i)..sort((a, b) => board.guests[a].pos.y.compareTo(board.guests[b].pos.y));
    for (final i in order.where((i) => board.guests[i].pos.y < catRow)) {
      drawGuest(i);
    }

    final center = Offset((pos.dx + .5) * u, (pos.dy + .42) * u);
    var lean = Offset.zero;
    if (tr != null && p < 1 && (served != null || returned != null) && tr.dir != null) {
      lean = Offset(tr.dir!.dx.toDouble(), tr.dir!.dy.toDouble()) * math.sin(_seg(p, 0, .6) * math.pi) * u * .2;
    }
    if (bump != null && bq < 1) {
      lean += Offset(bump.dir.dx.toDouble(), bump.dir.dy.toDouble()) * math.sin(bq * math.pi) * u * .12;
    }
    final head = center + lean + Offset(0, math.sin(t * 2 * math.pi / 1.8) * u * .01);
    Art.courier(canvas, head, u, s.facing, pal, phase: t, hop: hop);

    // ---- the stack on the head ----
    final top = head - Offset(0, hop);
    Offset slot(int k) => top + Offset(0, -u * .3 - k * u * .16);
    final du = u * 1.1;

    var shown = s.stack;
    if (tr != null && p < 1) {
      if (picked != null) {
        shown = tr.from.stack;
        if (flipped && p >= flipA) shown = tr.to.stack;
      } else if (flipped) {
        shown = p < flipA ? tr.from.stack : tr.to.stack;
      }
    }
    final flipping = flipped && tr != null && p < 1 && p >= flipA;
    final wobble = bump != null && bq < 1 && bump.reason == Blocked.full ? math.sin(bq * math.pi * 5) * u * .03 : 0.0;
    if (flipping) {
      final q = Curves.easeInOut.transform(_seg(p, flipA, 1));
      final pre = picked != null ? [...tr.from.stack, picked.color] : tr.from.stack;
      final list = q < .5 ? pre : tr.to.stack;
      final angle = q < .5 ? q * math.pi : (q - 1) * math.pi;
      final mid = slot(0) + Offset(0, -(list.length - 1) * u * .08);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(angle);
      canvas.translate(-mid.dx, -mid.dy);
      for (var k = 0; k < list.length; k++) {
        Art.stackDish(canvas, slot(k), du, list[k]);
      }
      canvas.restore();
    } else {
      // After trying to serve the wrong dish, the dishes on top lift for a
      // moment to show the one the guest wanted, glowing underneath: you can
      // see for yourself that it went on too early.
      var buried = -1;
      if (bump != null && bump.reason == Blocked.wrongDish && f.bumpAge < 1.8) {
        buried = shown.lastIndexOf(bump.wanted ?? '');
      }
      final age = f.bumpAge;
      final reveal = age < .25
          ? Curves.easeOutBack.transform(age / .25)
          : age < 1.3
              ? 1.0
              : 1 - Curves.easeInOut.transform(((age - 1.3) / .5).clamp(0.0, 1.0));
      for (var k = 0; k < shown.length; k++) {
        var at = slot(k) + Offset(wobble * (k + 1), 0);
        if (buried >= 0 && k > buried) at += Offset(0, -u * .26 * reveal);
        if (k == buried) {
          canvas.drawCircle(
              at + Offset(0, -u * .06),
              u * .3,
              Paint()
                ..color = pal.glow.withValues(alpha: .9 * reveal.clamp(0.0, 1.0))
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .09));
        }
        Art.stackDish(canvas, at, du, shown[k], highlight: k == shown.length - 1 && shown.length > 1);
      }
    }

    for (final i in order.where((i) => board.guests[i].pos.y >= catRow)) {
      drawGuest(i);
    }

    // ---- flying dishes ----
    if (tr != null && p < 1) {
      if (picked != null && p >= pickA && p < pickB) {
        final q = Curves.easeOutBack.transform(_seg(p, pickA, pickB));
        final d = board.dishes[picked.dishIndex];
        final from = Offset((d.pos.x + .5) * u, (d.pos.y + .5) * u);
        final to = slot(tr.from.stack.length);
        final arc = Offset(0, -math.sin(q.clamp(0, 1) * math.pi) * u * .3);
        Art.stackDish(canvas, Offset.lerp(from, to, q)! + arc, du, picked.color);
      } else if (picked != null && !flipped && p >= pickB) {
        Art.stackDish(canvas, slot(tr.from.stack.length), du, picked.color);
      }
      final flyer = served ?? returned;
      if (flyer != null) {
        final q = Curves.easeInOutCubic.transform(_seg(p, .1, .85));
        if (q < 1) {
          final color = served?.color ?? returned!.color;
          final dest = served != null
              ? Offset((board.guests[served.guestIndex].pos.x + .5) * u, (board.guests[served.guestIndex].pos.y + .66) * u)
              : Offset((board.counters[returned!.counterIndex].x + .5) * u, (board.counters[returned.counterIndex].y + .48) * u);
          final from = slot(tr.to.stack.length);
          final arc = Offset(0, -math.sin(q * math.pi) * u * .35);
          final at = Offset.lerp(from, dest, q)! + arc;
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.scale(served != null ? 1 - q * .2 : 1 - q * .6);
          Art.stackDish(canvas, Offset.zero, du, color);
          canvas.restore();
        }
      }
    }

    // ---- evening light ----
    if (f.night) {
      canvas.drawRect(all.inflate(u), Paint()
        ..color = const Color(0xFFE6D8C8)
        ..blendMode = BlendMode.modulate);
    }
    PaperGrain.paint(canvas, all, opacity: .5);
    canvas.restore();
    if (f.night) {
      canvas.drawPicture(layers.lights);
      // the courier carries a little warmth with them
      canvas.drawCircle(
        center,
        u * 1.2,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(colors: [pal.glow.withValues(alpha: .2), pal.glow.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: u * 1.2)),
      );
    }
  }
}
