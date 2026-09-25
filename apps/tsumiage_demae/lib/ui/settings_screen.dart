import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/settings.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import 'how_to_play_screen.dart';

const appVersion = '1.0.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: '/settings'),
        builder: (_) => const SettingsScreen(),
      );

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.settings;
    final s = Strings.of(context);
    final pal = context.palette;

    Widget section(List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: pal.surface, borderRadius: BorderRadius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        );

    Widget choice<T>(String title, T value, List<(T, String)> options, void Function(T) onChanged) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<T>(
                  showSelectedIcon: false,
                  segments: [for (final (v, l) in options) ButtonSegment(value: v, label: Text(l))],
                  selected: {value},
                  onSelectionChanged: (v) => onChanged(v.first),
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                section([
                  SwitchListTile(
                    title: Text(s.sound),
                    secondary: const Icon(Icons.volume_up_rounded),
                    value: st.sound,
                    onChanged: (v) => st.sound = v,
                  ),
                  SwitchListTile(
                    title: Text(s.music),
                    secondary: const Icon(Icons.music_note_rounded),
                    value: st.music,
                    onChanged: (v) => st.music = v,
                  ),
                  SwitchListTile(
                    title: Text(s.haptics),
                    secondary: const Icon(Icons.vibration_rounded),
                    value: st.haptics,
                    onChanged: (v) => st.haptics = v,
                  ),
                ]),
                section([
                  choice<AppLanguage>(s.language, st.language, [
                    (AppLanguage.system, s.languageSystem),
                    (AppLanguage.ja, '日本語'),
                    (AppLanguage.en, 'English'),
                  ], (v) => st.language = v),
                  choice<ThemeMode>(s.theme, st.themeMode, [
                    (ThemeMode.system, s.themeSystem),
                    (ThemeMode.light, s.themeLight),
                    (ThemeMode.dark, s.themeDark),
                  ], (v) => st.themeMode = v),
                  SwitchListTile(
                    title: Text(s.reduceMotion),
                    subtitle: Text(s.reduceMotionSub),
                    secondary: const Icon(Icons.motion_photos_off_rounded),
                    value: st.reduceMotionSetting,
                    onChanged: (v) => st.reduceMotionSetting = v,
                  ),
                ]),
                section([
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(s.howToPlay),
                    onTap: () => Navigator.of(context).push(HowToPlayScreen.route()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(s.licenses),
                    onTap: () => showLicensePage(context: context, applicationName: s.appTitle, applicationVersion: appVersion),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(s.version),
                    trailing: Text(appVersion, style: TextStyle(color: pal.muted)),
                  ),
                ]),
                section([
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: pal.warn),
                    title: Text(s.resetProgress, style: TextStyle(color: pal.warn, fontWeight: FontWeight.w700)),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(s.resetProgress),
                          content: Text(s.resetConfirm),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: pal.warn),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(s.reset),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        scope.progress.resetAll();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.resetDone)));
                      }
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
