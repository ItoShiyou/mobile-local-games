// Plays the app end to end on a real simulator/device and saves screenshots.
//
//   flutter test integration_test/walkthrough_test.dart -d <device> \
//     --dart-define=LANG=ja|en --dart-define=THEME=light|dark --dart-define=SHOT=name
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiage_demae/app/app.dart';
import 'package:tsumiage_demae/app/progress.dart';
import 'package:tsumiage_demae/app/settings.dart';
import 'package:tsumiage_demae/app/strings.dart';
import 'package:tsumiage_demae/audio/sound.dart';
import 'package:tsumiage_demae/game/controller.dart';
import 'package:tsumiage_demae/game/engine.dart';
import 'package:tsumiage_demae/game/levels.dart';
import 'package:tsumiage_demae/game/solver.dart';
import 'package:tsumiage_demae/ui/game_screen.dart';
import 'package:tsumiage_demae/ui/how_to_play_screen.dart';
import 'package:tsumiage_demae/ui/sprites.dart';

const _lang = String.fromEnvironment('LANG', defaultValue: 'ja');
const _theme = String.fromEnvironment('THEME', defaultValue: 'light');
const _shot = String.fromEnvironment('SHOT', defaultValue: 'dev');

const _keys = {
  Dir.up: LogicalKeyboardKey.arrowUp,
  Dir.down: LogicalKeyboardKey.arrowDown,
  Dir.left: LogicalKeyboardKey.arrowLeft,
  Dir.right: LogicalKeyboardKey.arrowRight,
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walkthrough', (tester) async {
    await CatSprites.load();
    SharedPreferences.setMockInitialValues({'settings.language': _lang, 'settings.theme': _theme});
    final sp = await SharedPreferences.getInstance();
    await tester.pumpWidget(TsumiageApp(settings: Settings(sp), progress: Progress(sp), sound: PluginSound()));
    await tester.pump(const Duration(seconds: 1));

    Future<void> settle([int ms = 900]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
    }

    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 300));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot('${_shot}_${_lang}_${_theme}_$name');
      expect(tester.takeException(), isNull, reason: name);
    }

    Future<void> pop() async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle();
    }

    Strings s() => Strings.of(tester.element(find.byType(Scaffold).first));

    Future<void> solveAndPlay(Level level) async {
      final path = Solver().solve(GameController(level).state)!;
      for (final d in path) {
        await tester.sendKeyEvent(_keys[d]!);
        await tester.pump(const Duration(milliseconds: 380));
      }
      await tester.pump(const Duration(milliseconds: 900));
    }

    Future<void> dismissIntro() async {
      final got = find.text(s().gotIt);
      if (got.evaluate().isNotEmpty) {
        await shot('intro');
        await tester.tap(got);
        await settle();
      }
    }

    await shot('01_title');

    await tester.tap(find.text(s().howToPlay));
    await settle();
    await shot('02_howto_p1');
    final nextPage = find.text(s().nextPage);
    if (nextPage.evaluate().isNotEmpty) {
      await tester.tap(nextPage.first);
      await settle();
      await shot('03_howto_p2');
    }
    await pop();
    await settle();

    await tester.tap(find.text(s().play));
    await settle(1400);
    // The first start shows the how-to once; page through it to the stage.
    var page = 4;
    while (find.byType(HowToPlayScreen).evaluate().isNotEmpty) {
      await shot('03b_howto_first_${page++}');
      final more = find.text(s().nextPage);
      if (more.evaluate().isNotEmpty) {
        await tester.tap(more.first);
        await settle();
      } else {
        await pop();
      }
      await settle(1200);
    }
    await dismissIntro();
    await shot('04_stage1');
    await solveAndPlay(allLevels.first);
    await shot('05_clear');
    await tester.tap(find.text(s().next));
    await settle(1200);
    await shot('06_stage2');
    await pop();
    await settle();
    // back out to title if a result/stage route is still open
    while (find.byType(GameScreen).evaluate().isNotEmpty) {
      await pop();
      await settle();
    }

    await tester.tap(find.text(s().stages));
    await settle(1200);
    await shot('07_menu');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await settle(1000);
    await shot('08_menu_bottom');
    await pop();
    await settle();

    // Chapters 6-8 (cat tongue / shared table / cart): play each one's first stage.
    for (final id in const ['catTongue', 'shared', 'cart']) {
      final ch = chapters.firstWhere((c) => c.id == id);
      final level = ch.levels.first;
      tester.state<NavigatorState>(find.byType(Navigator)).push(GameScreen.route(level));
      await settle(1400);
      await dismissIntro();
      await shot('09_${id}_start');
      await solveAndPlay(level);
      await shot('10_${id}_clear');
      await pop();
      await settle();
      while (find.byType(GameScreen).evaluate().isNotEmpty) {
        await pop();
        await settle();
      }
    }
  });
}
