import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fusuma_watari/app/progress.dart';
import 'package:fusuma_watari/game/levels.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stars', () {
    final l = allLevels[5]; // par 15
    expect(starsFor(l, null), 0);
    expect(starsFor(l, l.par), 3);
    expect(starsFor(l, l.par + twoStarMargin(l.par)), 2);
    expect(starsFor(l, l.par + twoStarMargin(l.par) + 1), 1);
  });

  test('records bests, unlocks ahead and survives a reload', () async {
    final prefs = await SharedPreferences.getInstance();
    final p = Progress(prefs);
    expect(p.isUnlocked(allLevels[0]), isTrue);
    expect(p.isUnlocked(allLevels[2]), isTrue);
    expect(p.isUnlocked(allLevels[3]), isFalse);
    expect(p.recordClear(allLevels[0], 6), isTrue);
    expect(p.recordClear(allLevels[0], 8), isFalse);
    expect(p.recordClear(allLevels[0], 4), isTrue);
    expect(p.isUnlocked(allLevels[3]), isTrue);
    p.markPlayed(allLevels[0]);
    expect(p.continueLevel, allLevels[1]);
    await Future<void>.delayed(Duration.zero);

    final again = Progress(prefs);
    expect(again.best(allLevels[0].id), 4);
    expect(again.stars(allLevels[0]), 3);
    expect(again.lastLevelId, allLevels[0].id);

    again.resetAll();
    expect(again.clearedCount, 0);
  });

  test('a corrupt save does not crash', () async {
    SharedPreferences.setMockInitialValues({'progress.best.v1': '{not json'});
    final p = Progress(await SharedPreferences.getInstance());
    expect(p.clearedCount, 0);
  });
}
