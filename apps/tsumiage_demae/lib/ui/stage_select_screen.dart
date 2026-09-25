import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../audio/sound.dart';
import '../game/levels.dart';
import 'art.dart';
import 'backdrop.dart';
import 'game_screen.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'scene.dart';
import 'widgets.dart';
import 'world_controls.dart';

/// "O-shinagaki": the menu on the wall. Each shop hangs its noren, and each
/// stage is a narrow wooden tag written top to bottom, like the menu tags
/// in a neighbourhood diner. Stamps are pressed on the tags you have done.
class StageSelectScreen extends StatefulWidget {
  const StageSelectScreen({super.key});

  static Route<void> route() => NorenRoute(settings: const RouteSettings(name: '/stages'), builder: (_) => const StageSelectScreen());

  @override
  State<StageSelectScreen> createState() => _StageSelectScreenState();
}

class _StageSelectScreenState extends State<StageSelectScreen> {
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .05);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final pal = context.palette;
    final progress = scope.progress;
    final lang = Localizations.localeOf(context).languageCode;
    final focus = progress.continueLevel;
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      body: SceneBackdrop(
        scene: sceneFor('basic'),
        child: Column(
          children: [
            SizedBox(
              height: pad.top + 84,
              child: Stack(
                children: [
                  Positioned(top: 0, left: 0, right: 0, height: pad.top + 18, child: CustomPaint(painter: BeamPainter(pal, height: pad.top + 18))),
                  Positioned(
                    top: pad.top + 12,
                    left: 10,
                    child: HangingTag(
                      glyph: InkGlyph.back,
                      label: s.back,
                      showLabel: false,
                      width: 42,
                      height: 44,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned(
                    top: pad.top + 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Signboard(
                        hanging: true,
                        padding: const EdgeInsets.fromLTRB(26, 2, 26, 8),
                        child: Text(s.stages, style: display(26, kInk)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: pad.top + 24,
                    right: 12,
                    child: PaperSlip(
                      seed: 7,
                      tilt: 3,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const HankoStars(stars: 1, total: 1, size: 16),
                        const SizedBox(width: 3),
                        Text('${progress.totalStars}', style: display(14, pal.ink)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(8, 4, 8, 28 + pad.bottom),
                    children: [
                      for (final ch in chapters)
                        Padding(
                          key: ch.levels.contains(focus) ? _focusKey : null,
                          padding: const EdgeInsets.only(bottom: 26),
                          child: _ShopWall(chapter: ch, lang: lang),
                        ),
                    ],
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

class _ShopWall extends StatelessWidget {
  const _ShopWall({required this.chapter, required this.lang});
  final Chapter chapter;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final pal = context.palette;
    final progress = scope.progress;
    final cleared = chapter.levels.where((l) => progress.isCleared(l.id)).length;
    final sc = sceneFor(chapter.id);
    final noren = sc.alwaysNight ? const Color(0xFF7A2E24) : pal.noren;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 74,
          child: CustomPaint(
            painter: NorenPainter(color: noren, text: pal.onNoren, panels: 3, crest: ''),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Text(s.chapterLabel(chapter.number), style: display(14, pal.onNoren.withValues(alpha: .8))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(chapter.title(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(24, pal.onNoren))),
                  Text(s.clearedCount(cleared, chapter.levels.length), style: display(13, pal.onNoren.withValues(alpha: .8))),
                ],
              ),
            ),
          ),
        ),
        // a little board under the noren saying what this shop is about
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
          child: PaperSlip(
            seed: chapter.number * 5,
            tilt: chapter.number.isEven ? .6 : -.6,
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
            child: Text(chapter.sub(lang), style: TextStyle(fontSize: 12.5, color: pal.ink, height: 1.5, fontWeight: FontWeight.w500)),
          ),
        ),
        LayoutBuilder(builder: (context, box) {
          final perRow = box.maxWidth > 460 ? 8 : 6;
          const gap = 6.0;
          final tagW = (box.maxWidth - 20 - gap * (perRow - 1)) / perRow;
          final rows = <List<Level>>[];
          for (var i = 0; i < chapter.levels.length; i += perRow) {
            rows.add(chapter.levels.sublist(i, (i + perRow).clamp(0, chapter.levels.length)));
          }
          return Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Stack(
                    children: [
                      Positioned(left: 4, right: 4, top: 0, height: 9, child: CustomPaint(painter: _MenuRailPainter(pal))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (i, l) in row.indexed) ...[
                              if (i > 0) const SizedBox(width: gap),
                              _MenuTag(level: l, width: tagW, lang: lang),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _MenuRailPainter extends CustomPainter {
  _MenuRailPainter(this.pal);
  final Palette pal;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r.shift(const Offset(0, 3)), Art.fill(const Color(0x33000000)));
    Art.inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(3))), pal.woodDark, 1.5);
  }

  @override
  bool shouldRepaint(_MenuRailPainter o) => o.pal != pal;
}

/// One menu tag: number, the stage name written top to bottom, and the
/// stamps. A stage not open yet hangs a "準備中" (closed) tag instead.
class _MenuTag extends StatelessWidget {
  const _MenuTag({required this.level, required this.width, required this.lang});
  final Level level;
  final double width;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final pal = context.palette;
    final progress = scope.progress;
    final unlocked = progress.isUnlocked(level);
    final cleared = progress.isCleared(level.id);
    final isNext = progress.continueLevel == level && unlocked;
    final stars = progress.stars(level);
    final ja = lang == 'ja';
    final name = level.name(lang);
    final text = unlocked ? name : s.locked;
    final ink = unlocked ? kInk : kInk.withValues(alpha: .45);
    final height = ja ? 176.0 : 132.0;

    Widget body() {
      if (ja) {
        // up to 8 characters top to bottom; longer names are shrunk to fit
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final ch in text.characters) Text(ch == 'ー' ? '｜' : ch, style: display(15, ink, height: 1.04))],
          ),
        );
      }
      // one word per line, each shrunk to the tag's width if needed
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final word in text.split(' ').take(4))
            FittedBox(fit: BoxFit.scaleDown, child: Text(word, maxLines: 1, style: display(12, ink, height: 1.15))),
        ],
      );
    }

    final tag = CustomPaint(
      painter: _MenuTagPainter(pal, unlocked: unlocked, cleared: cleared, seed: level.number + level.chapter.number * 17, glow: isNext),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 16, 3, 6),
          child: Column(
            children: [
              if (unlocked)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: cleared ? pal.shu : kInk.withValues(alpha: .75), shape: BoxShape.circle),
                  child: Text('${level.number}', style: display(12.5, const Color(0xFFFFF7EA), height: 1)),
                ),
              const SizedBox(height: 4),
              Expanded(child: Center(child: body())),
              if (unlocked) ...[
                const SizedBox(height: 3),
                FittedBox(child: HankoStars(stars: stars, size: 10)),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${level.chapter.number}-${level.number} $name${unlocked ? '' : ' ${s.locked}'}',
      value: cleared ? '$stars/3' : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (!unlocked) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.lockedHint)));
            return;
          }
          AppScope.read(context).sound.play(Sfx.tap);
          Navigator.of(context).push(GameScreen.route(level));
        },
        child: isNext
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  tag,
                  Positioned(left: width / 2 - 16, bottom: -20, child: const IgnorePointer(child: CourierPortrait(size: 32))),
                ],
              )
            : tag,
      ),
    );
  }
}

class _MenuTagPainter extends CustomPainter {
  _MenuTagPainter(this.pal, {required this.unlocked, required this.cleared, required this.seed, required this.glow});
  final Palette pal;
  final bool unlocked, cleared, glow;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, 12), Art.stroke(kInk, 1.4));
    final r = Rect.fromLTWH(1, 8, w - 2, size.height - 9);
    const c = 6.0;
    final shape = Wob.around(
      Path()
        ..moveTo(r.left + c, r.top)
        ..lineTo(r.right - c, r.top)
        ..lineTo(r.right, r.top + c)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..lineTo(r.left, r.top + c)
        ..close(),
      seed: seed,
      amp: .6,
    );
    if (glow) {
      canvas.drawPath(shape, Paint()
        ..color = pal.glow.withValues(alpha: .8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    }
    final face = !unlocked ? const Color(0xFF9C8466) : (cleared ? const Color(0xFFF1E2C3) : const Color(0xFFE6CDA2));
    canvas.drawPath(shape.shift(const Offset(2, 3)), Art.fill(const Color(0x33000000)));
    canvas.drawPath(shape, Art.fill(face));
    canvas.save();
    canvas.clipPath(shape);
    for (var i = 0; i < 2; i++) {
      final x = r.left + r.width * (.3 + i * .4);
      canvas.drawPath(Path()..moveTo(x, r.top)..cubicTo(x - 2, r.top + r.height * .3, x + 2, r.top + r.height * .7, x, r.bottom),
          Art.stroke(const Color(0x18000000), 1));
    }
    PaperGrain.paint(canvas, r, opacity: .8);
    canvas.restore();
    canvas.drawPath(shape, Art.stroke(kInk.withValues(alpha: unlocked ? .9 : .5), 1.4));
    canvas.drawCircle(Offset(w / 2, r.top + 5), 2, Art.fill(kInk.withValues(alpha: .7)));
  }

  @override
  bool shouldRepaint(_MenuTagPainter o) => o.unlocked != unlocked || o.cleared != cleared || o.glow != glow || o.pal != pal;
}
