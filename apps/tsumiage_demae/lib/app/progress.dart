import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels.dart';

/// Saved progress: best move count per stage id, last stage played and
/// which gimmick introductions have been shown.
class Progress extends ChangeNotifier {
  Progress(this._prefs) {
    try {
      final raw = _prefs.getString(_kBest);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, v) => _best[k] = v as int);
      }
    } catch (_) {
      // Corrupt save: start fresh rather than crash.
    }
    _last = _prefs.getString(_kLast);
    _seenIntros.addAll(_prefs.getStringList(_kIntro) ?? const []);
  }

  static const _kBest = 'progress.best.v1';
  static const _kLast = 'progress.last.v1';
  static const _kIntro = 'progress.intro.v1';

  final SharedPreferences _prefs;
  final Map<String, int> _best = {};
  final Set<String> _seenIntros = {};
  String? _last;

  int? best(String levelId) => _best[levelId];
  bool isCleared(String levelId) => _best.containsKey(levelId);
  String? get lastLevelId => _last;

  int get clearedCount => allLevels.where((l) => isCleared(l.id)).length;

  int stars(Level level) => starsFor(level, _best[level.id]);

  int get totalStars => allLevels.fold(0, (s, l) => s + stars(l));

  /// A stage is playable when at most two earlier stages are still uncleared,
  /// so one hard stage never blocks the whole game.
  bool isUnlocked(Level level) {
    var skipped = 0;
    for (final l in allLevels) {
      if (l.id == level.id) return true;
      if (!isCleared(l.id)) skipped++;
      if (skipped > 2) return false;
    }
    return false;
  }

  /// Where "Continue" should go: the first uncleared unlocked stage after
  /// the last one played, else the first uncleared stage, else the last.
  Level get continueLevel {
    final lastIndex = _last == null ? -1 : allLevels.indexWhere((l) => l.id == _last);
    for (var i = lastIndex + 1; i < allLevels.length; i++) {
      if (!isCleared(allLevels[i].id) && isUnlocked(allLevels[i])) return allLevels[i];
    }
    for (final l in allLevels) {
      if (!isCleared(l.id) && isUnlocked(l)) return l;
    }
    return lastIndex >= 0 ? allLevels[lastIndex] : allLevels.first;
  }

  /// Records a clear. Returns true when it is a new best.
  bool recordClear(Level level, int moves) {
    final prev = _best[level.id];
    final improved = prev == null || moves < prev;
    if (improved) {
      _best[level.id] = moves;
      _save(() => _prefs.setString(_kBest, jsonEncode(_best)));
    }
    notifyListeners();
    return improved;
  }

  void markPlayed(Level level) {
    if (_last == level.id) return;
    _last = level.id;
    _save(() => _prefs.setString(_kLast, level.id));
  }

  bool introSeen(String gimmick) => _seenIntros.contains(gimmick);

  void markIntroSeen(String gimmick) {
    if (_seenIntros.add(gimmick)) {
      _save(() => _prefs.setStringList(_kIntro, _seenIntros.toList()));
    }
  }

  void resetAll() {
    _best.clear();
    _seenIntros.clear();
    _last = null;
    _save(() async {
      await _prefs.remove(_kBest);
      await _prefs.remove(_kIntro);
      return _prefs.remove(_kLast);
    });
    notifyListeners();
  }

  void _save(Future<bool> Function() write) {
    write().catchError((_) => false);
  }
}

/// ★3 at par, ★2 within a small margin, ★1 for any clear.
int starsFor(Level level, int? moves) {
  if (moves == null) return 0;
  if (moves <= level.par) return 3;
  if (moves <= level.par + twoStarMargin(level.par)) return 2;
  return 1;
}

int twoStarMargin(int par) => (par * 0.25).ceil().clamp(2, 8);
