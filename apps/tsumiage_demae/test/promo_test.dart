import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiage_demae/promo/promo.dart';

void main() {
  const json = '''
{"enabled": true, "line_url": "https://lin.ee/abc",
 "apps": [{"id": "tsumiage_demae", "name": "self", "url": "https://apps.apple.com/jp/app/id1"},
          {"id": "other", "name": "Other", "copy": "c", "url": "https://example.com/"}],
 "launch_notice": {"every": 3, "skip_first": 1, "seconds": 5}}''';

  test('promo config parses and never promotes this app', () {
    final c = PromoConfig.tryParse(json)!;
    expect(c.lineUrl, 'https://lin.ee/abc');
    expect(c.latestFor('tsumiage_demae')!.id, 'other');
    expect(PromoConfig.tryParse('{oops'), isNull);
  });

  test('takes turns through the other apps', () {
    const c = PromoConfig(apps: [
      PromoApp(id: 'tsumiage_demae', name: 's', copy: '', url: 'https://a/'),
      PromoApp(id: 'b', name: 'b', copy: '', url: 'https://b/'),
      PromoApp(id: 'c', name: 'c', copy: '', url: 'https://c/'),
    ]);
    expect([for (var r = 0; r < 4; r++) c.pickFor('tsumiage_demae', r)!.id], ['b', 'c', 'b', 'c']);
    expect(const PromoConfig().pickFor('tsumiage_demae', 3), isNull);
  });

  test('launch notice: every 3rd launch, never the first', () {
    const c = PromoConfig(launchEvery: 3, skipFirstLaunches: 1);
    final shown = [
      for (var i = 1; i <= 9; i++)
        if (Promo.isNoticeLaunch(i, c)) i,
    ];
    expect(shown, [3, 6, 9]);
    expect(Promo.isNoticeLaunch(3, const PromoConfig(launchEvery: 0)), isFalse);
  });

  test('tracking params', () {
    Promo.selfId = 'tsumiage_demae';
    expect(
      Promo.tracked('https://apps.apple.com/jp/app/id1').queryParameters['ct'],
      'tsumiage_demae',
    );
    expect(
      Promo.tracked('https://example.com/').queryParameters['utm_source'],
      'tsumiage_demae',
    );
  });
}
