import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

enum AppLanguage { system, ja, en }

class Settings extends ChangeNotifier {
  Settings(this._prefs)
      : _sound = _prefs.getBool(_kSound) ?? true,
        _music = _prefs.getBool(_kMusic) ?? true,
        _haptics = _prefs.getBool(_kHaptics) ?? true,
        _reduceMotion = _prefs.getBool(_kMotion) ?? false,
        _language = AppLanguage.values.asNameMap()[_prefs.getString(_kLang)] ?? AppLanguage.system,
        _themeMode = ThemeMode.values.asNameMap()[_prefs.getString(_kTheme)] ?? ThemeMode.system;

  static const _kSound = 'settings.sound';
  static const _kMusic = 'settings.music';
  static const _kHaptics = 'settings.haptics';
  static const _kMotion = 'settings.reduceMotion';
  static const _kLang = 'settings.language';
  static const _kTheme = 'settings.theme';

  final SharedPreferences _prefs;
  bool _sound;
  bool _music;
  bool _haptics;
  bool _reduceMotion;
  AppLanguage _language;
  ThemeMode _themeMode;

  bool get sound => _sound;
  bool get music => _music;
  bool get haptics => _haptics;
  bool get reduceMotionSetting => _reduceMotion;
  AppLanguage get language => _language;
  ThemeMode get themeMode => _themeMode;

  set sound(bool v) => _set(() => _sound = v, () => _prefs.setBool(_kSound, v));
  set music(bool v) => _set(() => _music = v, () => _prefs.setBool(_kMusic, v));
  set haptics(bool v) => _set(() => _haptics = v, () => _prefs.setBool(_kHaptics, v));
  set reduceMotionSetting(bool v) => _set(() => _reduceMotion = v, () => _prefs.setBool(_kMotion, v));
  set language(AppLanguage v) => _set(() => _language = v, () => _prefs.setString(_kLang, v.name));
  set themeMode(ThemeMode v) => _set(() => _themeMode = v, () => _prefs.setString(_kTheme, v.name));

  void _set(void Function() apply, Future<bool> Function() save) {
    apply();
    notifyListeners();
    // A failed write must never stop the game (spec §4-3).
    save().catchError((_) => false);
  }

  /// The user's toggle, or the OS "reduce motion" accessibility setting.
  bool reduceMotion(BuildContext context) =>
      _reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  Locale? get locale => switch (_language) {
        AppLanguage.system => null,
        AppLanguage.ja => const Locale('ja'),
        AppLanguage.en => const Locale('en'),
      };

  Strings strings(BuildContext context) {
    final code = switch (_language) {
      AppLanguage.ja => 'ja',
      AppLanguage.en => 'en',
      AppLanguage.system => Localizations.maybeLocaleOf(context)?.languageCode ?? 'ja',
    };
    return code == 'ja' ? const StringsJa() : const StringsEn();
  }
}
