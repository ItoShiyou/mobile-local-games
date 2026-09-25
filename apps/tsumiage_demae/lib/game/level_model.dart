import 'engine.dart';

class Chapter {
  Chapter({
    required this.number,
    required this.id,
    required this.titleJa,
    required this.titleEn,
    required this.subJa,
    required this.subEn,
    required this.icon,
    required List<Level> levels,
  }) : levels = List.unmodifiable(levels) {
    for (var i = 0; i < levels.length; i++) {
      levels[i]
        .._chapter = this
        .._number = i + 1;
    }
  }

  final int number;
  final String id;
  final String titleJa, titleEn;
  final String subJa, subEn;

  /// Gimmick id for the chapter icon ('dish' for the basics).
  final String icon;
  final List<Level> levels;

  String title(String lang) => lang == 'ja' ? titleJa : titleEn;
  String sub(String lang) => lang == 'ja' ? subJa : subEn;
}

class Level {
  Level({
    required this.id,
    required this.ja,
    required this.en,
    required this.par,
    required this.map,
    this.cap = 2,
  });

  /// Stable id used for saved progress. Never change it after release.
  final String id;
  final String ja, en;
  final int par;
  final List<String> map;
  final int cap;

  late final Chapter _chapter;
  late final int _number;
  Level? _next;
  String? _introduces;

  Chapter get chapter => _chapter;
  int get number => _number;
  Level? get next => _next;

  /// Gimmick id first seen in this stage, if any.
  String? get introduces => _introduces;

  String name(String lang) => lang == 'ja' ? ja : en;

  late final Board board = Board.parse(map, capacity: cap);

  late final List<String> gimmicks = [
    if (map.any((r) => r.contains('T'))) 'counter',
    if (map.any((r) => r.contains('s'))) 'tray',
    if (map.any((r) => r.contains(RegExp(r'[<>^v]')))) 'oneWay',
  ];
}

/// Links stages in play order and records where each gimmick first appears.
List<Level> linkLevels(List<Chapter> chapters) {
  final all = [for (final c in chapters) ...c.levels];
  final seen = <String>{};
  for (var i = 0; i < all.length; i++) {
    all[i]._next = i + 1 < all.length ? all[i + 1] : null;
    for (final g in all[i].gimmicks) {
      if (seen.add(g)) all[i]._introduces = g;
    }
  }
  return List.unmodifiable(all);
}
