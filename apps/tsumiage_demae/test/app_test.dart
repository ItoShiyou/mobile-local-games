import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiage_demae/app/app.dart';
import 'package:tsumiage_demae/app/progress.dart';
import 'package:tsumiage_demae/app/settings.dart';
import 'package:tsumiage_demae/audio/sound.dart';
import 'package:tsumiage_demae/game/controller.dart';
import 'package:tsumiage_demae/game/engine.dart';
import 'package:tsumiage_demae/game/levels.dart';
import 'package:tsumiage_demae/game/solver.dart';
import 'package:tsumiage_demae/ui/board_view.dart';
import 'package:tsumiage_demae/ui/game_screen.dart';
import 'package:tsumiage_demae/ui/how_to_play_screen.dart';
import 'package:tsumiage_demae/ui/ink_icons.dart';
import 'package:tsumiage_demae/ui/paper.dart';
import 'package:tsumiage_demae/ui/settings_screen.dart';
import 'package:tsumiage_demae/ui/title_screen.dart';
import 'package:tsumiage_demae/ui/widgets.dart';
import 'package:tsumiage_demae/ui/world_controls.dart';
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
          'progress.intro.v1': <String>['howto', 'counter', 'tray', 'oneWay', 'catTongue', 'shared', 'cart'],
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
            'progress.intro.v1': <String>['howto', 'counter', 'tray', 'oneWay', 'catTongue', 'shared', 'cart'],
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

  const seen = <String>['howto', 'counter', 'tray', 'oneWay', 'catTongue', 'shared', 'cart'];

  Future<void> open(WidgetTester tester, Level level) async {
    tester.state<NavigatorState>(find.byType(Navigator)).push(GameScreen.route(level));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  int moves(WidgetTester tester) => tester.widget<WallChalkboard>(find.byType(WallChalkboard)).moves;
  Finder tag(String label) => find.byWidgetPredicate((w) => w is HangingTag && w.label == label);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the result menu returns from a title game to stages with title beneath', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen});
    await tester.tap(find.text('はじめる'));
    await settle(tester);
    expect(tester.widget<GameScreen>(find.byType(GameScreen)).level, allLevels.first);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    expect(find.text('毎度あり！'), findsOneWidget);
    await tester.tap(find.text('お品書き'));
    await settle(tester);
    await settle(tester);
    await settle(tester);
    expect(find.byType(StageSelectScreen), findsOneWidget);
    expect(find.byType(GameScreen, skipOffstage: false), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await settle(tester);
    await settle(tester);
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.byType(StageSelectScreen, skipOffstage: false), findsNothing);
  });

  for (final lang in const ['ja', 'en']) {
    for (final size in const [Size(320, 568), Size(375, 667), Size(402, 874)]) {
      testWidgets('title settings is labelled, clear of decorations and opens at ${size.width.toInt()}x${size.height.toInt()} ($lang)', (tester) async {
        await boot(tester, prefs: {'settings.language': lang});
        await tester.binding.setSurfaceSize(size);
        await tester.pump();
        final label = lang == 'ja' ? '設定' : 'Settings';
        final settingsTag = tag(label);
        final widget = tester.widget<HangingTag>(settingsTag);
        expect(widget.showLabel, isTrue);
        expect(widget.wood, TagWood.dark);
        expect(widget.width, 58);
        expect(widget.height, 66);
        expect(find.descendant(of: settingsTag, matching: find.text(label)), findsOneWidget);
        expect(find.descendant(of: settingsTag, matching: find.byWidgetPredicate((w) => w is InkIcon && w.glyph == InkGlyph.settings)), findsOneWidget);
        final rect = tester.getRect(settingsTag);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect((Offset.zero & size).contains(rect.topLeft), isTrue);
        expect((Offset.zero & size).contains(rect.bottomRight), isTrue);
        expect(rect.overlaps(tester.getRect(find.byType(Signboard))), isFalse);
        expect(rect.overlaps(tester.getRect(find.byType(PaperSlip))), isFalse);
        final eave = 96 * (size.height / 844).clamp(.68, 1.2);
        final lantern = Rect.fromCenter(center: Offset(size.width * .73 + 30, eave + 70), width: 34, height: 46);
        expect(rect.overlaps(lantern), isFalse);
        expect(tester.takeException(), isNull);
        await tester.tap(settingsTag);
        await settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    }
  }

  testWidgets('the tray pad moves the cat, and holding it keeps walking', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen});
    await open(tester, allLevels.firstWhere((l) => l.id == 'b08'));
    final pad = tester.getRect(find.byType(TrayPad));
    final first = Solver().solve(GameController(allLevels.firstWhere((l) => l.id == 'b08')).state)!.first;
    final at = pad.center + Offset(first.dx * pad.width * .33, first.dy * pad.height * .33);
    await tester.tapAt(at);
    await settle(tester);
    expect(moves(tester), 1);
    final b01 = allLevels.first;
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await open(tester, b01);
    final g = await tester.startGesture(tester.getRect(find.byType(TrayPad)).centerRight - const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 380));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 160));
    await g.up();
    await settle(tester);
    expect(moves(tester), greaterThanOrEqualTo(3));
  });

  testWidgets('a swipe and a tap on the next cell both walk', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen});
    final level = allLevels.first;
    await open(tester, level);
    final r = tester.getRect(find.byType(BoardView));
    final u = cellSizeFor(level.board, r.size, 76);
    await tester.dragFrom(r.center, Offset(u, 0));
    await settle(tester);
    expect(moves(tester), 1);
    final c = GameController(level);
    final x = r.center.dx + (c.state.pos.x + 1 + 1.5 - level.board.width / 2) * u;
    await tester.tapAt(Offset(x, r.center.dy));
    await settle(tester);
    expect(moves(tester), 2);
  });

  testWidgets('undo, redo, restart and hint', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen});
    await open(tester, allLevels.firstWhere((l) => l.id == 'b08'));
    Dir? hintDir() => tester.widget<TrayPad>(find.byType(TrayPad)).highlight;
    expect(hintDir(), isNull);
    await tester.tap(find.byType(LanternButton));
    await settle(tester);
    final d = hintDir();
    expect(d, isNotNull);
    final key = {Dir.up: LogicalKeyboardKey.arrowUp, Dir.down: LogicalKeyboardKey.arrowDown, Dir.left: LogicalKeyboardKey.arrowLeft, Dir.right: LogicalKeyboardKey.arrowRight}[d!]!;
    await tester.sendKeyEvent(key);
    await settle(tester);
    expect(moves(tester), 1);
    await tester.tap(tag('戻す'));
    await settle(tester);
    expect(moves(tester), 0);
    await tester.tap(tag('進む'));
    await settle(tester);
    expect(moves(tester), 1);
    await tester.tap(tag('やり直す'));
    await settle(tester);
    expect(moves(tester), 0);
  });

  testWidgets('clearing the last stage ends the game and returns to the menu', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen});
    final level = allLevels.last;
    await open(tester, level);
    final path = Solver().solve(GameController(level).state)!;
    const keys = {Dir.up: LogicalKeyboardKey.arrowUp, Dir.down: LogicalKeyboardKey.arrowDown, Dir.left: LogicalKeyboardKey.arrowLeft, Dir.right: LogicalKeyboardKey.arrowRight};
    for (final d in path) {
      await tester.sendKeyEvent(keys[d]!);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    expect(find.text('毎度あり！'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('本日の出前、ぜんぶ完了！'), findsOneWidget);
    await tester.tap(find.text('お品書き').last);
    await settle(tester);
    await settle(tester);
    await settle(tester);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(StageSelectScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    expect(find.byType(TitleScreen), findsOneWidget);
  });

  testWidgets('progress survives a restart and "continue" goes to the next stage', (tester) async {
    final (_, progress) = await boot(tester, prefs: {'progress.intro.v1': seen});
    final first = allLevels.first;
    progress.recordClear(first, first.par);
    final again = Progress(await SharedPreferences.getInstance());
    expect(again.isCleared(first.id), isTrue);
    expect(again.continueLevel, first.next);
    expect(again.isUnlocked(allLevels.last), isFalse);
    again.resetAll();
    expect(Progress(await SharedPreferences.getInstance()).isCleared(first.id), isFalse);
  });

  testWidgets('a locked stage does not open from the menu', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen});
    tester.state<NavigatorState>(find.byType(Navigator)).push(StageSelectScreen.route());
    await settle(tester);
    final tags = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MenuTag');
    final locked = tags.evaluate().last.widget;
    final at = find.byWidget(locked);
    await tester.ensureVisible(at);
    await settle(tester);
    await tester.tap(at, warnIfMissed: false);
    await settle(tester);
    expect(find.byType(GameScreen), findsNothing);
  });

  testWidgets('settings: language and theme apply at once and are kept', (tester) async {
    final (settings, _) = await boot(tester, prefs: {'progress.intro.v1': seen});
    tester.state<NavigatorState>(find.byType(Navigator)).push(SettingsScreen.route());
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(settings.language, AppLanguage.en);
    expect(find.text('Settings'), findsOneWidget);
    final kept = Settings(await SharedPreferences.getInstance());
    expect(kept.language, AppLanguage.en);
  });

  testWidgets('the title menu never cuts its text off', (tester) async {
    await boot(tester);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.overflow, isNot(TextOverflow.ellipsis), reason: t.data);
    }
  });

  testWidgets('every stage lays out on the smallest phone in English', (tester) async {
    await boot(tester, prefs: {'progress.intro.v1': seen, 'settings.language': 'en'});
    await tester.binding.setSurfaceSize(const Size(320, 568));
    for (final l in allLevels) {
      await open(tester, l);
      expect(tester.takeException(), isNull, reason: l.id);
      final texts = find.descendant(of: find.byType(GameScreen), matching: find.byType(Text));
      for (final t in tester.widgetList<Text>(texts)) {
        expect(t.overflow, isNot(TextOverflow.ellipsis), reason: '${l.id}: ${t.data}');
      }
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 400));
    }
  });

  test('stage names are all different', () {
    for (final name in [(Level l) => l.ja, (Level l) => l.en]) {
      final names = allLevels.map(name).toList();
      expect(names.toSet().length, names.length);
    }
  });
}
