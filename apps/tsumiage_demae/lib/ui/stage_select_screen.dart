import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../game/levels.dart';
import 'game_screen.dart';
import 'widgets.dart';

class StageSelectScreen extends StatefulWidget {
  const StageSelectScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: '/stages'),
        builder: (_) => const StageSelectScreen(),
      );

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
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .1);
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
      appBar: AppBar(
        title: Text(s.stages),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(s.starsTotal(progress.totalStars, allLevels.length * 3),
                  style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                for (final ch in chapters)
                  Padding(
                    key: ch.levels.contains(focus) ? _focusKey : null,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ChapterCard(chapter: ch, lang: lang),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.lang});
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
    return Container(
      decoration: BoxDecoration(color: pal.surface, borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GimmickIcon(chapter.icon, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.chapterLabel(chapter.number), style: TextStyle(fontSize: 12, color: pal.muted)),
                    Text(chapter.title(lang), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(s.clearedCount(cleared, chapter.levels.length),
                      style: TextStyle(fontSize: 12, color: pal.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                  Text('★ $stars / ${chapter.levels.length * 3}',
                      style: TextStyle(fontSize: 12, color: pal.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(chapter.sub(lang), style: TextStyle(fontSize: 13, color: pal.muted, height: 1.5)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            const gap = 8.0;
            final cols = box.maxWidth > 420 ? 6 : 5;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final l in chapter.levels) _StageTile(level: l, size: w, lang: lang)],
            );
          }),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.level, required this.size, required this.lang});
  final Level level;
  final double size;
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
    final label = '${level.chapter.number}-${level.number} ${level.name(lang)}'
        '${unlocked ? (cleared ? ' ★$stars' : '') : ' ${s.locked}'}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: cleared ? pal.tint(.16, pal.bg) : pal.bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!unlocked) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(s.lockedHint)));
              return;
            }
            Navigator.of(context).push(GameScreen.route(level));
          },
          child: Container(
            width: size,
            height: size * 1.05,
            decoration: isNext
                ? BoxDecoration(border: Border.all(color: pal.accent, width: 2.5), borderRadius: BorderRadius.circular(14))
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (unlocked)
                  Text('${level.number}',
                      style: TextStyle(fontSize: size * .34, fontWeight: FontWeight.w900, color: pal.ink, height: 1.1))
                else
                  Icon(Icons.lock_rounded, color: pal.muted, size: size * .32),
                const SizedBox(height: 2),
                if (unlocked) StarRow(stars: stars, size: size * .2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
