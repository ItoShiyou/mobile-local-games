import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../audio/sound.dart';
import '../game/engine.dart';
import '../game/levels.dart';
import 'art.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'settings_screen.dart';
import 'stage_select_screen.dart';
import 'widgets.dart';
import 'world_controls.dart';

/// The title is the front of the shop: tiled eaves and the big sign, a
/// lattice window, the noren over the door with the cat waiting in front,
/// and a chalk stand-board whose lines are the menu.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    // Web only, for tool/make_store_screens.js: `?open=stages` or
    // `?open=<stage id>` goes straight to that screen.
    if (kIsWeb) {
      final target = Uri.base.queryParameters['open'];
      if (target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final nav = Navigator.of(context);
          if (target == 'stages') {
            nav.push(StageSelectScreen.route());
          } else if (levelById(target) case final level?) {
            nav.push(GameScreen.route(level));
          }
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AppScope.of(context).settings.reduceMotion(context);
    if (reduce) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final pal = context.palette;
    final progress = scope.progress;
    final lang = Localizations.localeOf(context).languageCode;
    final started = progress.clearedCount > 0 || progress.lastLevelId != null;
    final cont = progress.continueLevel;
    final pad = MediaQuery.paddingOf(context);

    Future<void> play() async {
      if (!started && !progress.introSeen('howto')) {
        progress.markIntroSeen('howto');
        await Navigator.of(context).push(HowToPlayScreen.route());
        if (!context.mounted) return;
      }
      Navigator.of(context).push(GameScreen.route(cont));
    }

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        // the whole storefront scales with the screen height
        final k = (h / 844).clamp(.68, 1.2);
        final eave = pad.top + 96 * k;
        final ground = h - 170 * k - pad.bottom;
        final doorL = w * .29, doorR = w * .71;
        return AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final t = _t.value * 2 * math.pi;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShopFrontPainter(
                      pal: pal,
                      eave: eave,
                      ground: ground,
                      doorL: doorL,
                      doorR: doorR,
                      sway: math.sin(t) * .25,
                      crest: '宿',
                    ),
                  ),
                ),
                // the big sign on the eaves
                Positioned(
                  top: eave - 44 * k,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: -.015,
                      child: Signboard(
                        padding: EdgeInsets.fromLTRB(26 * k, 8 * k, 26 * k, 10 * k),
                        child: Column(
                          children: [
                            Text(s.appTitle, style: display((lang == 'ja' ? 42 : 34) * k, kInk, height: 1.1)),
                            Text(s.appTitleKana, style: display(12 * k, kInk.withValues(alpha: .6))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // settings: a small tag hanging under the eaves
                Positioned(
                  top: eave + 6,
                  right: 12,
                  child: HangingTag(
                    glyph: InkGlyph.settings,
                    label: s.settings,
                    showLabel: false,
                    width: 42,
                    height: 44,
                    string: 14,
                    onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
                  ),
                ),
                // stamp count on a notice pasted by the window
                Positioned(
                  left: 14,
                  top: ground - 190 * k,
                  child: PaperSlip(
                    seed: 81,
                    tilt: -3,
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HankoStars(stars: 1, total: 1, size: 18),
                        const SizedBox(width: 4),
                        Text('${progress.totalStars}/${allLevels.length * 3}', style: display(14, pal.ink)),
                      ],
                    ),
                  ),
                ),
                // walking through the noren starts / continues
                Positioned(
                  left: doorL,
                  width: doorR - doorL,
                  top: eave + 40 * k,
                  height: ground - eave - 40 * k,
                  child: Semantics(
                    button: true,
                    label: started ? '${s.continueFrom} ${cont.name(lang)}' : s.play,
                    excludeSemantics: true,
                    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: play),
                  ),
                ),
                // the cat waiting at the door
                Positioned(
                  left: math.max(56.0, doorL - 40 * k),
                  top: ground - 118 * k,
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: Offset(0, math.sin(t * 3) * 1.5),
                      child: CourierPortrait(size: 84 * k, stack: const ['c', 'b', 'a'], look: Dir.right),
                    ),
                  ),
                ),
                // chalk stand-board: the menu
                Positioned(
                  right: 10,
                  bottom: pad.bottom + 12,
                  width: math.min(250.0, w * .56),
                  child: _StandBoard(
                    lines: [
                      (started ? '${s.continueFrom}  ${cont.chapter.number}-${cont.number}' : s.play, started ? cont.name(lang) : s.tagline, play, true),
                      (s.stages, null, () => Navigator.of(context).push(StageSelectScreen.route()), false),
                      (s.howToPlay, null, () => Navigator.of(context).push(HowToPlayScreen.route()), false),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}

class _ShopFrontPainter extends CustomPainter {
  _ShopFrontPainter({
    required this.pal,
    required this.eave,
    required this.ground,
    required this.doorL,
    required this.doorR,
    required this.sway,
    required this.crest,
  });
  final Palette pal;
  final double eave, ground, doorL, doorR, sway;
  final String crest;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final night = pal.night;
    // sky
    final skyR = Rect.fromLTWH(0, 0, w, eave);
    canvas.drawRect(
      skyR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night ? const [Color(0xFF141A33), Color(0xFF2E3354)] : const [Color(0xFFB9D8E8), Color(0xFFF1E8D2)],
        ).createShader(skyR),
    );
    if (night) {
      final rnd = math.Random(2);
      for (var i = 0; i < 30; i++) {
        canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * eave * .8), rnd.nextDouble() + .4, Art.fill(Colors.white70));
      }
      canvas.drawCircle(Offset(w * .82, eave * .35), 14, Art.fill(const Color(0xFFFFF1C4)));
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset(w * .78, eave * .4), width: 90, height: 24), Art.fill(Colors.white.withValues(alpha: .7)));
    }
    // facade boards
    final facade = Rect.fromLTWH(0, eave, w, ground - eave);
    final board = night ? const Color(0xFF6E5038) : const Color(0xFFB88A5C);
    canvas.drawRect(facade, Art.fill(board));
    for (var x = 0.0; x < w; x += 22) {
      canvas.drawLine(Offset(x, eave), Offset(x, ground), Art.stroke(const Color(0x30000000), 1.2));
    }
    PaperGrain.paint(canvas, facade);
    // posts
    for (final x in [8.0, w - 8, doorL - 6, doorR + 6]) {
      final r = Rect.fromCenter(center: Offset(x, (eave + ground) / 2), width: 14, height: ground - eave);
      Art.inked(canvas, Path()..addRect(r), pal.woodDark, 1.6);
    }
    // lattice window, lit from inside
    final win = Rect.fromLTRB(26, eave + (ground - eave) * .16, doorL - 22, eave + (ground - eave) * .5);
    Art.inked(canvas, Path()..addRect(win.inflate(6)), pal.woodDark, 1.8);
    canvas.drawRect(win, Art.fill(night ? const Color(0xFFFFD27A) : const Color(0xFFF6E7C4)));
    for (var x = win.left + 9; x < win.right; x += 9) {
      canvas.drawLine(Offset(x, win.top), Offset(x, win.bottom), Art.stroke(pal.woodDark, 3));
    }
    canvas.drawLine(Offset(win.left, win.center.dy), Offset(win.right, win.center.dy), Art.stroke(pal.woodDark, 3));
    if (night) _glow(canvas, win.center, win.width);
    // doorway: warm interior
    final door = Rect.fromLTRB(doorL, eave + 36, doorR, ground);
    canvas.drawRect(door, Art.fill(night ? const Color(0xFF6B4226) : const Color(0xFF7A5234)));
    canvas.drawRect(
      door,
      Paint()
        ..shader = RadialGradient(center: const Alignment(0, .6), colors: [const Color(0xFFFFC56B).withValues(alpha: night ? .55 : .3), Colors.transparent])
            .createShader(door),
    );
    // a glimpse inside: menu tags on the back wall, the counter and stools
    final inside = door.deflate(8);
    for (var i = 0; i < 6; i++) {
      final tr = Rect.fromLTWH(inside.left + 6 + i * (inside.width - 12) / 6, inside.top + inside.height * .42, (inside.width - 12) / 6 - 4, inside.height * .16);
      canvas.drawRect(tr, Art.fill(const Color(0xFFF3E6CC).withValues(alpha: .85)));
      canvas.drawLine(tr.topCenter + const Offset(0, 5), tr.bottomCenter - const Offset(0, 5), Art.stroke(kInk.withValues(alpha: .5), 1.4));
    }
    final counterTop = inside.top + inside.height * .7;
    canvas.drawRect(Rect.fromLTRB(door.left, counterTop, door.right, counterTop + 10), Art.fill(const Color(0xFFD2A676)));
    canvas.drawRect(Rect.fromLTRB(door.left, counterTop + 10, door.right, door.bottom), Art.fill(const Color(0xFF5E3C24)));
    canvas.drawLine(Offset(door.left, counterTop), Offset(door.right, counterTop), Art.stroke(kInk, 1.6));
    for (var i = 0; i < 3; i++) {
      final cx = door.left + door.width * (.22 + i * .28);
      final seat = Rect.fromCenter(center: Offset(cx, door.bottom - 26), width: 26, height: 9);
      canvas.drawLine(Offset(cx, seat.bottom), Offset(cx, door.bottom), Art.stroke(const Color(0xFF3A2618), 4));
      Art.inked(canvas, Path()..addOval(seat), const Color(0xFFB8452F), 1.4);
    }
    canvas.drawRect(door, Art.stroke(kInk, 2));
    // lintel
    final lintel = Rect.fromLTRB(doorL - 14, eave + 26, doorR + 14, eave + 40);
    Art.inked(canvas, Path()..addRect(lintel), pal.woodDark, 1.8);
    // noren in the doorway
    canvas.save();
    canvas.translate(doorL - 4, eave + 38);
    NorenPainter(color: pal.noren, text: pal.onNoren, panels: 3, crest: crest, sway: sway, rod: false)
        .paint(canvas, Size(doorR - doorL + 8, (ground - eave) * .36));
    canvas.restore();
    // hanging lantern by the door
    final lc = Offset(doorR + 30, eave + 70);
    canvas.drawLine(Offset(lc.dx, eave + 40), lc - const Offset(0, 22), Art.stroke(kInk, 1.6));
    if (night) _glow(canvas, lc, 80);
    Art.inked(canvas, Path()..addOval(Rect.fromCenter(center: lc, width: 30, height: 40)), const Color(0xFFE0493A), 1.6);
    for (final dy in [-8.0, 0.0, 8.0]) {
      canvas.drawLine(lc + Offset(-13, dy), lc + Offset(13, dy), Art.stroke(const Color(0x55000000), 1));
    }
    canvas.drawRect(Rect.fromCenter(center: lc - const Offset(0, 20), width: 16, height: 5), Art.fill(kInk));
    canvas.drawRect(Rect.fromCenter(center: lc + const Offset(0, 20), width: 16, height: 5), Art.fill(kInk));
    // eaves: a row of roof tiles
    final roof = Rect.fromLTWH(-6, eave - 40, w + 12, 44);
    canvas.drawRect(roof.shift(const Offset(0, 6)), Art.fill(const Color(0x44000000)));
    Art.inked(canvas, Path()..addRect(roof), night ? const Color(0xFF3A4252) : const Color(0xFF5C6676), 2);
    for (var x = -6.0; x < w + 6; x += 24) {
      canvas.drawLine(Offset(x, roof.top), Offset(x, roof.bottom - 10), Art.stroke(const Color(0x40000000), 1.4));
      Art.inked(canvas, Path()..addOval(Rect.fromCircle(center: Offset(x + 12, roof.bottom - 4), radius: 9)),
          night ? const Color(0xFF4A5366) : const Color(0xFF707A8A), 1.6);
    }
    // ground: stone paving
    final g = Rect.fromLTWH(0, ground, w, h - ground);
    canvas.drawRect(g, Art.fill(night ? const Color(0xFF6A6660) : const Color(0xFFC9C1B2)));
    for (var y = ground + 4, row = 0; y < h; y += 26, row++) {
      for (var x = (row.isOdd ? -20.0 : 0.0); x < w; x += 44) {
        canvas.drawPath(Wob.rrect(Rect.fromLTWH(x + 2, y, 40, 22), 6, seed: row * 31 + x.toInt(), amp: .8),
            Art.fill(night ? const Color(0xFF7A766E) : const Color(0xFFD8D0C0)));
      }
    }
    canvas.drawLine(Offset(0, ground), Offset(w, ground), Art.stroke(kInk, 2));
    // a potted pine by the window
    final pot = Offset(28, ground - 2);
    Art.inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pot - const Offset(0, 12), width: 36, height: 24), const Radius.circular(4))),
        const Color(0xFF8A5A3A), 1.6);
    for (var i = -1; i <= 1; i++) {
      Art.inked(canvas, Path()..addOval(Rect.fromCenter(center: pot + Offset(i * 12.0, -36 - (1 - i.abs()) * 10), width: 30, height: 22)), pal.leaf, 1.4);
    }
    PaperGrain.paint(canvas, Offset.zero & size, opacity: .6);
  }

  void _glow(Canvas c, Offset at, double r) {
    final rect = Rect.fromCircle(center: at, radius: r);
    c.drawCircle(at, r, Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(colors: [pal.glow.withValues(alpha: .5), pal.glow.withValues(alpha: 0)]).createShader(rect));
  }

  @override
  bool shouldRepaint(_ShopFrontPainter o) => o.sway != sway || o.pal != pal || o.eave != eave || o.ground != ground;
}

/// An A-frame blackboard standing on the pavement. Each chalk line is a
/// menu item; the first one is underlined twice.
class _StandBoard extends StatelessWidget {
  const _StandBoard({required this.lines});
  final List<(String, String?, VoidCallback, bool)> lines;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      painter: _StandPainter(pal),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, sub, onTap, main) in lines)
              Semantics(
                button: true,
                label: sub == null ? label : '$label $sub',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppScope.read(context).sound.play(Sfx.tap);
                    onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: CustomPaint(
                      painter: _ChalkUnderline(pal.chalk, main),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (main) ...[const InkIcon(InkGlyph.play, size: 16, color: Color(0xFFF2A08E)), const SizedBox(width: 4)],
                                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(main ? 21 : 18, pal.chalk))),
                              ],
                            ),
                            if (sub != null)
                              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(13, pal.chalk.withValues(alpha: .75))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StandPainter extends CustomPainter {
  _StandPainter(this.pal);
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // legs
    for (final x in [14.0, w - 14]) {
      canvas.drawLine(Offset(x, h - 30), Offset(x + (x < w / 2 ? -6 : 6), h), Art.stroke(kInk, 7));
      canvas.drawLine(Offset(x, h - 30), Offset(x + (x < w / 2 ? -6 : 6), h), Art.stroke(pal.woodDark, 4.5));
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * .9, height: 8), Art.fill(const Color(0x33000000)));
    final r = Rect.fromLTWH(0, 0, w, h - 24);
    final frame = Wob.rrect(r.deflate(1), 6, seed: 90, amp: .8);
    canvas.drawPath(frame.shift(const Offset(3, 4)), Art.fill(const Color(0x40000000)));
    canvas.drawPath(frame, Art.fill(pal.wood));
    final inner = Wob.rrect(r.deflate(9), 3, seed: 91, amp: .6);
    canvas.drawPath(inner, Art.fill(pal.board));
    canvas.save();
    canvas.clipPath(inner);
    final rnd = math.Random(8);
    for (var i = 0; i < 8; i++) {
      canvas.drawOval(Rect.fromCenter(center: Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), width: 60, height: 14),
          Art.fill(Colors.white.withValues(alpha: .04)));
    }
    canvas.restore();
    canvas.drawPath(frame, Art.stroke(kInk, 2));
    canvas.drawPath(inner, Art.stroke(kInk.withValues(alpha: .6), 1.2));
  }

  @override
  bool shouldRepaint(_StandPainter o) => o.pal != pal;
}

class _ChalkUnderline extends CustomPainter {
  _ChalkUnderline(this.color, this.twice);
  final Color color;
  final bool twice;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 2;
    canvas.drawPath(Wob.line(Offset(0, y), Offset(size.width * (twice ? .95 : .6), y), seed: size.width.toInt(), amp: 1),
        Art.stroke(color.withValues(alpha: .55), 1.6));
    if (twice) {
      canvas.drawPath(Wob.line(Offset(4, y + 3), Offset(size.width * .7, y + 3), seed: 3, amp: 1), Art.stroke(color.withValues(alpha: .35), 1.2));
    }
  }

  @override
  bool shouldRepaint(_ChalkUnderline o) => o.color != color;
}
