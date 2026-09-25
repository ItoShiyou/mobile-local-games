import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import 'art.dart';

/// Everything the painter needs for one frame.
class BoardFrame {
  const BoardFrame({
    required this.state,
    required this.palette,
    this.transition,
    this.transitionP = 1,
    this.bump,
    this.bumpP = 1,
    this.hint,
    this.time = 0,
  });

  final GameState state;
  final Palette palette;
  final Transition? transition;

  /// 0..1 linear progress of [transition].
  final double transitionP;
  final Bump? bump;
  final double bumpP;
  final Dir? hint;

  /// Seconds, for idle animation. Frozen at 0 when motion is reduced.
  final double time;
}

/// Duration of a transition, longer when there is more to show.
Duration transitionDuration(Transition t) {
  if (t.isUndo) return const Duration(milliseconds: 110);
  final flip = t.events.any((e) => e is Flipped);
  final pick = t.events.any((e) => e is PickedUp);
  if (flip && pick) return const Duration(milliseconds: 460);
  if (flip) return const Duration(milliseconds: 380);
  if (t.events.any((e) => e is Served || e is Returned)) return const Duration(milliseconds: 320);
  if (pick) return const Duration(milliseconds: 240);
  return const Duration(milliseconds: 140);
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.f, {super.repaint});

  final BoardFrame f;

  static double _seg(double p, double a, double b) => ((p - a) / (b - a)).clamp(0.0, 1.0);

  @override
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
    // Phase boundaries within the transition.
    final walkEnd = flipped ? (picked != null ? .35 : .45) : (picked != null ? .55 : 1.0);
    final pickA = flipped ? .3 : .45, pickB = flipped ? .62 : 1.0;
    final flipA = picked != null ? .6 : .45;

    // ---- floor, walls and fixed tiles ----
    for (var y = 0; y < board.height; y++) {
      for (var x = 0; x < board.width; x++) {
        final c = board.at(x, y);
        final o = Offset(x * u, y * u);
        if (c == ' ') continue;
        if (c == '#') {
          if (_nearFloor(board, x, y)) {
            canvas.drawRRect(Art.rr(o.dx + 1, o.dy + 1, u - 2, u - 2, u * .18), Art.fill(pal.wall));
          }
          continue;
        }
        final arrow = arrowDirs[c];
        if (c == 's') {
          final spin = flipped && tr != null && tr.to.pos == Pos(x, y) ? _seg(p, flipA, 1) * math.pi : 0.0;
          Art.tray(canvas, o, u, pal, spin: spin);
        } else if (arrow != null) {
          Art.oneWay(canvas, o, u, pal, arrow);
        } else {
          Art.woodTile(canvas, o, u, pal);
        }
      }
    }
    for (var i = 0; i < board.counters.length; i++) {
      final cp = board.counters[i];
      final justUsed = returned?.counterIndex == i && p < .8;
      Art.counter(canvas, Offset(cp.x * u, cp.y * u), u, pal,
          used: s.isUsed(i) && !justUsed, pulse: s.isUsed(i) ? 0 : (math.sin(t * 3) + 1) / 2);
    }

    // ---- dishes still on the floor ----
    for (var i = 0; i < board.dishes.length; i++) {
      final d = board.dishes[i];
      final flying = picked?.dishIndex == i && p >= pickA;
      final waiting = picked?.dishIndex == i && p < pickA;
      if (s.isTaken(i) && !waiting) continue;
      if (flying) continue;
      Art.floorDish(canvas, Offset((d.pos.x + .5) * u, (d.pos.y + .5) * u), u, d.color);
    }

    // ---- hint ----
    final hint = f.hint;
    if (hint != null && tr != null && p < 1) {
      // wait for the move to land
    } else if (hint != null) {
      final hx = s.pos.x + hint.dx, hy = s.pos.y + hint.dy;
      final pulse = (math.sin(t * 5) + 1) / 2;
      final c = Offset((hx + .5) * u, (hy + .5) * u);
      canvas.drawRRect(Art.rr(hx * u + 3, hy * u + 3, u - 6, u - 6, u * .16),
          Art.stroke(pal.accent.withValues(alpha: .55 + .45 * pulse), u * .06));
      Art.chevrons(canvas, Offset((s.pos.x + .5 + hint.dx * .62) * u, (s.pos.y + .5 + hint.dy * .62) * u), u * .8, hint,
          pal.accent, n: 1, width: .11);
      canvas.drawCircle(c, u * .06 * pulse, Art.fill(pal.accent.withValues(alpha: .5)));
    }

    // ---- guests ----
    final bump = f.bump;
    final bq = bump == null ? 1.0 : f.bumpP;
    for (var i = 0; i < board.guests.length; i++) {
      final g = board.guests[i];
      final o = Offset(g.pos.x * u, g.pos.y * u);
      Art.woodTile(canvas, o, u, pal);
      final beingServed = served?.guestIndex == i && p < .72;
      final done = s.isServed(i) && !beingServed;
      final bob = done ? math.sin(t * 4 + i) * u * .012 : math.sin(t * 2.4 + i * 1.3) * u * .01;
      Art.guest(canvas, o, u, i, happy: done, bob: bob);
      if (done) {
        // their dish on the table
        Art.stackDish(canvas, o + Offset(u * .5, u * .82), u * .9, g.wants);
        Art.check(canvas, o + Offset(u * .8, u * .2), u, pal.ok);
      } else {
        var bc = o + Offset(u * .74, u * .22 + bob);
        Color? ring;
        var scale = 1 + .04 * math.sin(t * 3 + i);
        final hit = bump != null && bq < 1 && bump.reason == Blocked.wrongDish &&
            s.pos.x + bump.dir.dx == g.pos.x && s.pos.y + bump.dir.dy == g.pos.y;
        if (hit) {
          bc += Offset(math.sin(bq * math.pi * 6) * u * .05, 0);
          ring = pal.warn;
          scale = 1.18;
        }
        Art.bubble(canvas, bc, u, g.wants, scale: scale, ring: ring);
      }
    }

    // ---- courier ----
    var pos = Offset(s.pos.x.toDouble(), s.pos.y.toDouble());
    if (tr != null && p < 1) {
      final a = Offset(tr.from.pos.x.toDouble(), tr.from.pos.y.toDouble());
      final wp = Curves.easeOutCubic.transform(_seg(p, 0, walkEnd));
      pos = Offset.lerp(a, pos, wp)!;
    }
    final center = Offset((pos.dx + .5) * u, (pos.dy + .58) * u);
    var lean = Offset.zero;
    if (tr != null && p < 1 && (served != null || returned != null) && tr.dir != null) {
      lean = Offset(tr.dir!.dx.toDouble(), tr.dir!.dy.toDouble()) * math.sin(_seg(p, 0, .6) * math.pi) * u * .2;
    }
    if (bump != null && bq < 1) {
      lean += Offset(bump.dir.dx.toDouble(), bump.dir.dy.toDouble()) * math.sin(bq * math.pi) * u * .12;
    }
    final breathe = math.sin(t * 2 * math.pi / 1.8) * u * .012;
    final head = center + lean + Offset(0, breathe);
    Art.courier(canvas, head, u, s.facing, pal.accent, squash: math.sin(t * 2 * math.pi / 1.8));

    // ---- the stack on the head ----
    Offset slot(int k) => head + Offset(0, -u * .36 - k * u * .16);

    var shown = s.stack;
    if (tr != null && p < 1) {
      if (picked != null) {
        // dish hops from the floor to the top of the pre-pickup stack
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
      final mid = slot(0) + Offset(0, -(list.length - 1) * u * .07);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(angle);
      canvas.translate(-mid.dx, -mid.dy);
      for (var k = 0; k < list.length; k++) {
        Art.stackDish(canvas, slot(k), u * 1.15, list[k]);
      }
      canvas.restore();
    } else {
      for (var k = 0; k < shown.length; k++) {
        final top = k == shown.length - 1;
        Art.stackDish(canvas, slot(k) + Offset(wobble * (k + 1), 0), u * 1.15, shown[k], highlight: top && shown.length > 1);
      }
    }

    // ---- flying dishes ----
    if (tr != null && p < 1) {
      if (picked != null && p >= pickA && p < pickB) {
        final q = Curves.easeOutBack.transform(_seg(p, pickA, pickB));
        final d = board.dishes[picked.dishIndex];
        final from = Offset((d.pos.x + .5) * u, (d.pos.y + .5) * u);
        final to = slot(tr.from.stack.length);
        final arc = Offset(0, -math.sin(q.clamp(0, 1) * math.pi) * u * .3);
        Art.stackDish(canvas, Offset.lerp(from, to, q)! + arc, u * 1.15, picked.color);
      } else if (picked != null && !flipped && p >= pickB) {
        Art.stackDish(canvas, slot(tr.from.stack.length), u * 1.15, picked.color);
      }
      final flyer = served ?? returned;
      if (flyer != null) {
        final q = Curves.easeInOutCubic.transform(_seg(p, .1, .85));
        if (q < 1) {
          final color = served?.color ?? returned!.color;
          final dest = served != null
              ? Offset((board.guests[served.guestIndex].pos.x + .5) * u, (board.guests[served.guestIndex].pos.y + .82) * u)
              : Offset((board.counters[returned!.counterIndex].x + .5) * u, (board.counters[returned.counterIndex].y + .45) * u);
          final from = slot(tr.to.stack.length);
          final arc = Offset(0, -math.sin(q * math.pi) * u * .35);
          canvas.save();
          final at = Offset.lerp(from, dest, q)! + arc;
          canvas.translate(at.dx, at.dy);
          final sc = served != null ? 1 - q * .1 : 1 - q * .6;
          canvas.scale(sc);
          Art.stackDish(canvas, Offset.zero, u * 1.15, color);
          canvas.restore();
        }
      }
    }
  }

  static bool _nearFloor(Board b, int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final c = b.at(x + dx, y + dy);
        if (c != '#' && c != ' ') return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
