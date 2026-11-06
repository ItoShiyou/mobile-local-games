// The App Review crash path: Continue and How to play from the title,
// again and again, after some progress. Run on an iPad simulator.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiage_demae/app/app.dart';
import 'package:tsumiage_demae/app/progress.dart';
import 'package:tsumiage_demae/app/settings.dart';
import 'package:tsumiage_demae/audio/sound.dart';
import 'package:tsumiage_demae/ui/how_to_play_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('continue and how to play, repeatedly', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    SharedPreferences.setMockInitialValues({'settings.language': 'en', 'settings.theme': 'light'});
    final sp = await SharedPreferences.getInstance();
    await tester.pumpWidget(TsumiageApp(settings: Settings(sp), progress: Progress(sp), sound: PluginSound()));
    await tester.pump(const Duration(seconds: 1));

    Future<void> settle([int ms = 1200]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> back() async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle();
    }

    // first start: how-to, then stage 1, cleared
    await tester.tap(find.text('Start'));
    await settle();
    while (find.byType(HowToPlayScreen).evaluate().isNotEmpty) {
      final next = find.text('Next');
      if (next.evaluate().isNotEmpty) {
        await tester.tap(next.first);
      } else {
        await back();
      }
      await settle();
    }
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await settle(1500);
    await back();

    for (var round = 0; round < 6; round++) {
      final cont = find.textContaining('Continue');
      expect(cont, findsWidgets, reason: 'round $round');
      await tester.tap(cont.first);
      await settle(800);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(600);
      await back();
      await tester.tap(find.text('How to play'));
      await settle(700);
      for (var p = 0; p < 3; p++) {
        final next = find.text('Next');
        if (next.evaluate().isEmpty) break;
        await tester.tap(next.first);
        await settle(500);
      }
      await back();
    }
    FlutterError.onError = old;
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });
}
