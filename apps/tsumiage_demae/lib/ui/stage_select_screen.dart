import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../game/levels.dart';
import 'art.dart';
import 'game_screen.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'widgets.dart';

/// "O-shinagaki": the menu. Each chapter is a shop, hung with its noren,
/// and each stage a wooden tag on its menu board.
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

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RoundWoodButton(glyph: InkGlyph.back, tooltip: s.back, onPressed: () => Navigator.of(context).maybePop()),
                        Expanded(
                          child: Center(
                            child: Signboard(
                              hanging: true,
                              padding: const EdgeInsets.fromLTRB(26, 4, 26, 8),
                              child: Text(s.stages, style: display(24, kInk)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Column(
                            children: [
                              const HankoStars(stars: 1, total: 1, size: 22),
                              Text('${progress.totalStars}', style: display(14, pal.inkSoft)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                      children: [
                        for (final ch in chapters)
                          Padding(
                            key: ch.levels.contains(focus) ? _focusKey : null,
                            padding: const EdgeInsets.only(bottom: 22),
                            child: _ShopCard(chapter: ch, lang: lang),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.chapter, required this.lang});
  final Chapter chapter;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final pal = context.palette;
    final progress = scope.progress;
    final cleared = chapter.levels.where((l) => progress.isCleared(l.id)).length;
    final stars = chapter.levels.fold(0, (a, l) => a + progress.stars(l));
    final night = chapter.id == 'mix';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // the shop's noren with its name
        SizedBox(
          height: 70,
          child: CustomPaint(
            painter: NorenPainter(color: night ? const Color(0xFF7A2E24) : pal.noren, text: pal.onNoren, panels: 3, crest: ''),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(
                children: [
                  Text(s.chapterLabel(chapter.number), style: display(14, pal.onNoren.withValues(alpha: .8))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(chapter.title(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(23, pal.onNoren))),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: PaperSlip(
            seed: chapter.number * 3,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(chapter.sub(lang), style: TextStyle(fontSize: 13, color: pal.inkSoft, height: 1.5, fontWeight: FontWeight.w500))),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(s.clearedCount(cleared, chapter.levels.length), style: display(14, pal.ink)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const HankoStars(stars: 1, total: 1, size: 14),
                          Text(' $stars/${chapter.levels.length * 3}', style: display(12.5, pal.inkSoft)),
                        ]),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, box) {
                  const gap = 10.0;
                  final cols = box.maxWidth > 420 ? 6 : 4;
                  final w = (box.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap + 4,
                    children: [for (final l in chapter.levels) _StageTag(level: l, width: w, lang: lang)],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A wooden menu tag hanging from a nail: the stage number, its name and
/// the stamps earned. Closed stages show "準備中".
class _StageTag extends StatelessWidget {
  const _StageTag({required this.level, required this.width, required this.lang});
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
    final isNext = progress.continueLevel == level;
    final stars = progress.stars(level);
    final label = '${level.chapter.number}-${level.number} ${level.name(lang)}${unlocked ? '' : ' ${s.locked}'}';
    return Semantics(
      button: true,
      label: label,
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
          Navigator.of(context).push(GameScreen.route(level));
        },
        child: SizedBox(
          width: width,
          child: CustomPaint(
            painter: _TagPainter(pal, unlocked: unlocked, cleared: cleared, seed: level.number + level.chapter.number * 13),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unlocked) ...[
                    Text('${level.number}', style: display(26, kInk, height: 1)),
                    const SizedBox(height: 2),
                    Text(level.name(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(10.5, kInk.withValues(alpha: .75))),
                    const SizedBox(height: 4),
                    HankoStars(stars: stars, size: width * .17),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(s.locked, style: display(15, kInk.withValues(alpha: .55))),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).withNextMarker(isNext && unlocked, pal);
  }
}

extension on Widget {
  /// A tiny cat peeking over the tag the player should try next.
  Widget withNextMarker(bool show, Palette pal) => !show
      ? this
      : Stack(
          clipBehavior: Clip.none,
          children: [
            this,
            const Positioned(right: -8, top: -16, child: IgnorePointer(child: CourierPortrait(size: 30))),
          ],
        );
}

class _TagPainter extends CustomPainter {
  _TagPainter(this.pal, {required this.unlocked, required this.cleared, required this.seed});
  final Palette pal;
  final bool unlocked, cleared;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1, 6, size.width - 2, size.height - 7);
    final path = Wob.around(
      Path()
        ..moveTo(r.left + 10, r.top)
        ..lineTo(r.right - 10, r.top)
        ..lineTo(r.right, r.top + 10)
        ..lineTo(r.right, r.bottom - 4)
        ..quadraticBezierTo(r.right, r.bottom, r.right - 4, r.bottom)
        ..lineTo(r.left + 4, r.bottom)
        ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 4)
        ..lineTo(r.left, r.top + 10)
        ..close(),
      seed: seed,
      amp: .7,
    );
    final face = !unlocked ? pal.paperDeep : (cleared ? const Color(0xFFF7EBD2) : pal.woodLight);
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = const Color(0x2A000000));
    canvas.drawPath(path, Paint()..color = face);
    canvas.save();
    canvas.clipPath(path);
    PaperGrain.paint(canvas, r, opacity: .8);
    canvas.restore();
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = kInk.withValues(alpha: unlocked ? .9 : .4));
    // nail hole and cord
    final hole = Offset(size.width / 2, r.top + 7);
    canvas.drawLine(hole, Offset(size.width / 2, 0), Paint()
      ..strokeWidth = 1.4
      ..color = kInk.withValues(alpha: .6));
    canvas.drawCircle(hole, 2.6, Paint()..color = kInk.withValues(alpha: .7));
  }

  @override
  bool shouldRepaint(_TagPainter o) => o.unlocked != unlocked || o.cleared != cleared || o.pal != pal;
}
