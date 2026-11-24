// Cross promotion kit (official LINE + latest app).
// Source of truth: itoshiyou.github.io/hub/flutter/promo.dart
// Copy into an app as lib/promo/promo.dart and set [Promo.selfId] in init().
// Rules: itoshiyou.github.io/hub/README.md
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Promo {
  Promo._();

  static const configUrl = 'https://itoshiyou.github.io/hub/promo.json';
  static const _cacheKey = 'promo_json';
  static const _launchKey = 'promo_launches';

  /// This app's id in promo.json (self-exclusion + tracking).
  static String selfId = '';
  static PromoConfig current = PromoConfig.fallback;

  /// Notice launches so far; even = LINE, odd = latest app.
  static int noticeIndex = 0;

  static bool _noticeDue = false;
  static Future<void>? _refreshing;
  static final _initDone = Completer<void>();
  static final _ready = Completer<void>();
  static bool _holdForReady = false;

  /// Call once at startup (no need to await). Set [waitForReady] when the app
  /// shows ads consent / ATT at launch, then call [markReady] after them so
  /// the launch notice never stacks on those dialogs.
  static Future<void> init(String appId, {bool waitForReady = false}) async {
    if (_initDone.isCompleted) return;
    selfId = appId;
    _holdForReady = waitForReady;
    try {
      final sp = await SharedPreferences.getInstance();
      final cached = sp.getString(_cacheKey);
      if (cached != null) {
        current = PromoConfig.tryParse(cached) ?? current;
      }
      final launches = (sp.getInt(_launchKey) ?? 0) + 1;
      await sp.setInt(_launchKey, launches);
      _noticeDue = isNoticeLaunch(launches, current);
      if (current.launchEvery > 0) {
        noticeIndex = launches ~/ current.launchEvery;
      }
      _refreshing = _refresh(sp);
    } catch (_) {
      // Storage unavailable: promo simply stays quiet.
    } finally {
      _initDone.complete();
    }
  }

  static void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Pure rule for the launch notice.
  static bool isNoticeLaunch(int launches, PromoConfig c) =>
      c.enabled &&
      c.launchEvery > 0 &&
      launches > c.skipFirstLaunches &&
      launches % c.launchEvery == 0;

  static Future<bool> takeLaunchNotice() async {
    await _initDone.future;
    if (!_noticeDue) return false;
    _noticeDue = false;
    if (_holdForReady) {
      await _ready.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    }
    await _refreshing?.timeout(const Duration(seconds: 3), onTimeout: () {});
    return current.enabled && current.hasAnything(selfId);
  }

  static Future<void> _refresh(SharedPreferences sp) async {
    try {
      // NetworkAssetBundle works on iOS, Android and web (no extra package).
      final body = await NetworkAssetBundle(
        Uri.parse(configUrl),
      ).loadString('', cache: false).timeout(const Duration(seconds: 8));
      final parsed = PromoConfig.tryParse(body);
      if (parsed == null) return;
      current = parsed;
      await sp.setString(_cacheKey, body);
    } catch (_) {
      // Offline / non-200: keep cached / fallback config.
    }
  }

  static Uri? get lineUri {
    final u = current.lineUrlByApp[selfId] ?? current.lineUrl;
    return u.isEmpty ? null : Uri.tryParse(u);
  }

  static PromoApp? get latest => current.latestFor(selfId);

  /// App Store links get `ct` (App Analytics campaign), others get UTM.
  static Uri tracked(String url) {
    final u = Uri.parse(url);
    final q = Map<String, String>.from(u.queryParameters);
    if (u.host == 'apps.apple.com') {
      q.putIfAbsent('ct', () => selfId);
    } else {
      q.putIfAbsent('utm_source', () => selfId);
      q.putIfAbsent('utm_medium', () => 'app');
      q.putIfAbsent('utm_campaign', () => 'cross_promo');
    }
    return u.replace(queryParameters: q);
  }

  static Future<void> openLine() async {
    final u = lineUri;
    if (u != null) await _open(u);
  }

  static Future<void> openApp(PromoApp app) => _open(tracked(app.url));

  static Future<void> _open(Uri u) async {
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class PromoApp {
  const PromoApp({
    required this.id,
    required this.name,
    required this.copy,
    required this.url,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String copy;
  final String url;
  final String? iconUrl;

  static PromoApp? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'], url = j['url'];
    if (id is! String || name is! String || url is! String || url.isEmpty) {
      return null;
    }
    final icon = j['icon'];
    return PromoApp(
      id: id,
      name: name,
      copy: j['copy'] is String ? j['copy'] as String : '',
      url: url,
      iconUrl: icon is String && icon.isNotEmpty ? icon : null,
    );
  }
}

class PromoConfig {
  const PromoConfig({
    this.enabled = true,
    this.lineUrl = '',
    this.lineUrlByApp = const {},
    this.lineCopy = '新作やお知らせを LINE でおとどけします',
    this.apps = const [],
    this.launchEvery = 3,
    this.skipFirstLaunches = 1,
    this.noticeSeconds = 6,
  });

  final bool enabled;
  final String lineUrl;
  final Map<String, String> lineUrlByApp;
  final String lineCopy;
  final List<PromoApp> apps;
  final int launchEvery;
  final int skipFirstLaunches;
  final int noticeSeconds;

  /// Bundled default, used until promo.json has been fetched once.
  static const fallback = PromoConfig(
    lineUrl: 'https://line.me/R/ti/p/@400kkcxl',
    apps: [
      PromoApp(
        id: 'english_lesson',
        name: 'Mimi English',
        copy: 'AI英会話・医学英語をオフラインで',
        url: 'https://englishlesson-eight.vercel.app/',
        iconUrl: 'https://itoshiyou.github.io/hub/icons/english_lesson.png',
      ),
    ],
  );

  PromoApp? latestFor(String selfId) {
    for (final a in apps) {
      if (a.id != selfId) return a;
    }
    return null;
  }

  bool hasAnything(String selfId) =>
      lineUrl.isNotEmpty ||
      lineUrlByApp[selfId] != null ||
      latestFor(selfId) != null;

  static PromoConfig? tryParse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final notice = j['launch_notice'] is Map
          ? j['launch_notice'] as Map
          : const {};
      final byApp = <String, String>{};
      if (j['line_url_by_app'] is Map) {
        (j['line_url_by_app'] as Map).forEach((k, v) {
          if (k is String && v is String && v.isNotEmpty) byApp[k] = v;
        });
      }
      return PromoConfig(
        enabled: j['enabled'] != false,
        lineUrl: j['line_url'] is String ? j['line_url'] as String : '',
        lineUrlByApp: byApp,
        lineCopy: j['line_copy'] is String
            ? j['line_copy'] as String
            : fallback.lineCopy,
        apps: [
          if (j['apps'] is List)
            for (final a in j['apps'] as List) ?PromoApp.fromJson(a),
        ],
        launchEvery: _int(notice['every'], 3),
        skipFirstLaunches: _int(notice['skip_first'], 1),
        noticeSeconds: _int(notice['seconds'], 6),
      );
    } catch (_) {
      return null;
    }
  }

  static int _int(Object? v, int d) => v is int ? v : d;
}
