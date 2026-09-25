import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../game/levels.dart';
import 'art.dart';
import 'auto_play.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'settings_screen.dart';
import 'stage_select_screen.dart';
import 'widgets.dart';

const _demoMap = ['########', '#Pba..A#', '#.##B###', '########'];

/// The shop front: a noren over the door, the sign, and a window onto the
/// dining room where the cat is already at work.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AppScope.of(context).settings.reduceMotion(context);
    if (reduce) {
      _sway.stop();
    } else if (!_sway.isAnimating) {
      _sway.repeat();
    }
  }

  @override
  void dispose() {
    _sway.dispose();
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
    final short = MediaQuery.sizeOf(context).height < 720;

    Future<void> play() async {
      if (!started && !progress.introSeen('howto')) {
        progress.markIntroSeen('howto');
        await Navigator.of(context).push(HowToPlayScreen.route());
        if (!context.mounted) return;
      }
      Navigator.of(context).push(GameScreen.route(cont));
    }

    return Scaffold(
      body: PaperBackground(
        child: Stack(
          children: [
            // noren over the entrance
            Positioned(
              left: -6,
              right: -6,
              top: 0,
              height: MediaQuery.paddingOf(context).top + (short ? 64 : 92),
              child: AnimatedBuilder(
                animation: _sway,
                builder: (_, _) => CustomPaint(
                  painter: NorenPainter(
                    color: pal.noren,
                    text: pal.onNoren,
                    sway: math.sin(_sway.value * 2 * math.pi) * .25,
                    panels: 5,
                    crest: lang == 'ja' ? '出' : 'D',
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.only(top: short ? 68 : 96),
                            child: RoundWoodButton(
                              glyph: InkGlyph.settings,
                              tooltip: s.settings,
                              onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Signboard(
                              padding: const EdgeInsets.fromLTRB(26, 10, 26, 14),
                              child: Column(
                                children: [
                                  Text(s.appTitle, textAlign: TextAlign.center, style: display((lang == 'ja' ? 46 : 38) * (short ? .82 : 1), kInk, height: 1.1)),
                                  Text(s.appTitleKana, style: display(13, kInk.withValues(alpha: .6))),
                                ],
                              ),
                            ),
                            Positioned(right: -10, top: -18, child: _OpenTag(text: s.openSign)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(s.tagline, textAlign: TextAlign.center, style: display(15, pal.inkSoft)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: short ? 112 : 176,
                          child: const WoodFrame(child: AutoPlayBoard(map: _demoMap, maxCell: 54)),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: WoodButton(
                            kind: WoodKind.shu,
                            glyph: InkGlyph.play,
                            label: started ? '${s.continueFrom}  ${cont.chapter.number}-${cont.number} ${cont.name(lang)}' : s.play,
                            onPressed: play,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: WoodButton(
                                glyph: InkGlyph.menu,
                                label: s.stages,
                                seed: 8,
                                onPressed: () => Navigator.of(context).push(StageSelectScreen.route()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: WoodButton(
                                glyph: InkGlyph.book,
                                label: s.howToPlay,
                                seed: 9,
                                onPressed: () => Navigator.of(context).push(HowToPlayScreen.route()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            const HankoStars(stars: 1, total: 1, size: 20),
                            Text('× ${progress.totalStars} / ${allLevels.length * 3}', style: display(15, pal.inkSoft)),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
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

/// The little "open" tag hanging off the corner of the sign.
class _OpenTag extends StatelessWidget {
  const _OpenTag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Transform.rotate(
      angle: .18,
      child: PaperSlip(
        seed: 44,
        color: pal.shu,
        padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
        child: Text(text, style: display(14, pal.onShu)),
      ),
    );
  }
}
