import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../game/levels.dart';
import 'auto_play.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';
import 'stage_select_screen.dart';
import 'widgets.dart';

const _demoMap = ['########', '#Pba..A#', '#.##B###', '########'];

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final pal = context.palette;
    final progress = scope.progress;
    final lang = Localizations.localeOf(context).languageCode;
    final started = progress.clearedCount > 0 || progress.lastLevelId != null;
    final cont = progress.continueLevel;

    Future<void> play() async {
      if (!started && !progress.introSeen('howto')) {
        progress.markIntroSeen('howto');
        await Navigator.of(context).push(HowToPlayScreen.route());
        if (!context.mounted) return;
      }
      Navigator.of(context).push(GameScreen.route(cont));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: s.settings,
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Text(
                    s.appTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: pal.ink, height: 1.1, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(s.tagline, textAlign: TextAlign.center, style: TextStyle(color: pal.muted, fontSize: 14)),
                  const SizedBox(height: 24),
                  Container(
                    height: 170,
                    decoration: BoxDecoration(color: pal.tint(.22), borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.all(10),
                    child: const AutoPlayBoard(map: _demoMap, maxCell: 50),
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    width: double.infinity,
                    child: SoftButton(
                      primary: true,
                      icon: Icons.play_arrow_rounded,
                      label: started ? '${s.continueFrom}  ${cont.chapter.number}-${cont.number} ${cont.name(lang)}' : s.play,
                      onPressed: play,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SoftButton(
                          icon: Icons.grid_view_rounded,
                          label: s.stages,
                          onPressed: () => Navigator.of(context).push(StageSelectScreen.route()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SoftButton(
                          icon: Icons.menu_book_rounded,
                          label: s.howToPlay,
                          onPressed: () => Navigator.of(context).push(HowToPlayScreen.route()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const StarRow(stars: 1, max: 1, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${progress.totalStars} / ${allLevels.length * 3}',
                        style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.flag_rounded, size: 18, color: pal.muted),
                      const SizedBox(width: 4),
                      Text(
                        s.clearedCount(progress.clearedCount, allLevels.length),
                        style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
