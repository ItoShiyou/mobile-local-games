import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiage_demae/app/app.dart';
import 'package:tsumiage_demae/app/progress.dart';
import 'package:tsumiage_demae/app/settings.dart';
import 'package:tsumiage_demae/audio/sound.dart';
import 'package:tsumiage_demae/game/levels.dart';
import 'package:tsumiage_demae/ui/game_screen.dart';
import 'package:tsumiage_demae/ui/how_to_play_screen.dart';
import 'package:tsumiage_demae/ui/settings_screen.dart';
import 'package:tsumiage_demae/ui/stage_select_screen.dart';

Future<(Settings, Progress)> boot(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'settings.language': 'ja', ...prefs});
  final sp = await SharedPreferences.getInstance();
  final settings = Settings(sp)..reduceMotionSetting = true;
  final progress = Progress(sp);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(TsumiageApp(settings: settings, progress: progress, sound: SilentSound()));
  await tester.pump();
  return (settings, progress);
}

void main() {
  testWidgets('title shows and opens the stage list', (tester) async {
    await boot(tester);
    expect(find.text('つみあげ出前'), findsOneWidget);
    await tester.tap(find.text('お品書き'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('まちの食堂'), findsWidgets);
    expect(find.text('駅前の定食屋'), findsWidgets);
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
    expect(find.text('はじめての出前'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('毎度あり！'), findsOneWidget);
    expect(progress.best(allLevels.first.id), 4);
    expect(progress.stars(allLevels.first), 3);

    await tester.tap(find.text('次の出前へ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('上から順に'), findsOneWidget);
  });

  testWidgets('a new gimmick is introduced once', (tester) async {
    final (_, progress) = await boot(tester);
    final c01 = allLevels.firstWhere((l) => l.id == 'c01');
    tester.state<NavigatorState>(find.byType(Navigator)).push(GameScreen.route(c01));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('おしらせ'), findsOneWidget);
    await tester.tap(find.text('わかった'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(progress.introSeen('counter'), isTrue);
  });

  testWidgets('English UI', (tester) async {
    final (settings, _) = await boot(tester);
    settings.language = AppLanguage.en;
    await tester.pump();
    expect(find.text('Stack & Deliver'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(430, 932), Size(820, 1180)]) {
    testWidgets('every chapter\'s hardest stage lays out at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await boot(
        tester,
        prefs: {
          'progress.intro.v1': <String>['howto', 'counter', 'tray', 'oneWay'],
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
            'progress.intro.v1': <String>['howto', 'counter', 'tray', 'oneWay'],
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
