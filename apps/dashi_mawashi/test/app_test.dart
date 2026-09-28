import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dashi_mawashi/app/app.dart';
import 'package:dashi_mawashi/app/progress.dart';
import 'package:dashi_mawashi/app/settings.dart';
import 'package:dashi_mawashi/audio/sound.dart';
import 'package:dashi_mawashi/game/engine.dart';
import 'package:dashi_mawashi/game/levels.dart';
import 'package:dashi_mawashi/game/solver.dart';
import 'package:dashi_mawashi/ui/game_screen.dart';
import 'package:dashi_mawashi/ui/how_to_play_screen.dart';
import 'package:dashi_mawashi/ui/settings_screen.dart';
import 'package:dashi_mawashi/ui/stage_select_screen.dart';

Future<(Settings, Progress)> boot(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'settings.language': 'ja', ...prefs});
  final sp = await SharedPreferences.getInstance();
  final settings = Settings(sp)..reduceMotionSetting = true;
  final progress = Progress(sp);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(DashiApp(settings: settings, progress: progress, sound: SilentSound()));
  await tester.pump();
  return (settings, progress);
}

void main() {
  testWidgets('title shows and opens the stage list', (tester) async {
    await boot(tester);
    expect(find.text('だし回し'), findsOneWidget);
    await tester.tap(find.text('献立帳'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('だしの通り道'), findsWidgets);
    expect(find.text('合わせだし'), findsWidgets);
  });

  testWidgets('clearing a stage with the keyboard shows the result and saves it', (tester) async {
    final (_, progress) = await boot(
      tester,
      prefs: {
        'progress.intro.v1': <String>['howto'],
      },
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(GameScreen.route(allLevels.first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('一番だし'), findsOneWidget);

    final keys = {
      Dir.up: LogicalKeyboardKey.arrowUp,
      Dir.down: LogicalKeyboardKey.arrowDown,
      Dir.left: LogicalKeyboardKey.arrowLeft,
      Dir.right: LogicalKeyboardKey.arrowRight,
    };
    final board = allLevels.first.board;
    var state = board.initialState();
    var cursor = const Pos(0, 0);
    outer:
    for (var y = 0; y < board.height; y++) {
      for (var x = 0; x < board.width; x++) {
        if (board.turnable(x, y)) {
          cursor = Pos(x, y);
          break outer;
        }
      }
    }
    while (!state.isWon) {
      final to = Solver().hint(state)!;
      while (cursor != to) {
        final d = to.x > cursor.x
            ? Dir.right
            : to.x < cursor.x
                ? Dir.left
                : to.y > cursor.y
                    ? Dir.down
                    : Dir.up;
        await tester.sendKeyEvent(keys[d]!);
        await tester.pump(const Duration(milliseconds: 50));
        cursor = cursor.step(d);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 50));
      state = state.tap(to.x, to.y).state!;
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('毎度あり！'), findsOneWidget);
    expect(progress.best(allLevels.first.id), allLevels.first.par);
    expect(progress.stars(allLevels.first), 3);

    await tester.tap(find.text('次のだしへ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('曲がり角'), findsOneWidget);
  });

  testWidgets('a new gimmick is introduced once', (tester) async {
    final (_, progress) = await boot(tester);
    final pairStage = allLevels.firstWhere((l) => l.introduces == 'mix');
    tester.state<NavigatorState>(find.byType(Navigator)).push(GameScreen.route(pairStage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('おしらせ'), findsOneWidget);
    await tester.tap(find.text('わかった'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(progress.introSeen('mix'), isTrue);
  });

  testWidgets('English UI', (tester) async {
    final (settings, _) = await boot(tester);
    settings.language = AppLanguage.en;
    await tester.pump();
    expect(find.text('Stock Pipes'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(430, 932), Size(820, 1180)]) {
    testWidgets('every chapter\'s hardest stage lays out at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await boot(
        tester,
        prefs: {
          'progress.intro.v1': <String>['howto', 'mix', 'iron', 'cross', 'shiitake'],
        },
      );
      await tester.binding.setSurfaceSize(size);
      for (final ch in chapters) {
        tester.state<NavigatorState>(find.byType(Navigator)).push(GameScreen.route(ch.levels.last));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  }

  for (final lang in const ['ja', 'en']) {
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      testWidgets('every screen fits with the largest system text at ${size.width.toInt()}x${size.height.toInt()} ($lang)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await boot(
          tester,
          prefs: {
            'progress.intro.v1': <String>['howto', 'mix', 'iron', 'cross', 'shiitake'],
            'settings.language': lang,
          },
        );
        await tester.binding.setSurfaceSize(size);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'title');
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        final routes = <String, Route<void>>{
          'stages': StageSelectScreen.route(),
          'settings': SettingsScreen.route(),
          'how to play': HowToPlayScreen.route(),
          'game': GameScreen.route(chapters.last.levels.last),
        };
        for (final MapEntry(:key, :value) in routes.entries) {
          nav.push(value);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull, reason: key);
          nav.pop();
          await tester.pump(const Duration(milliseconds: 600));
        }
      });
    }
  }
}
