import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/settings.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import 'art.dart';
import 'how_to_play_screen.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'widgets.dart';

const appVersion = '1.1.0';

/// Settings, written in the shop's notebook.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Route<void> route() => NorenRoute(settings: const RouteSettings(name: '/settings'), builder: (_) => const SettingsScreen());

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.settings;
    final s = Strings.of(context);
    final pal = context.palette;

    Widget row(InkGlyph glyph, String label, Widget trailing, {String? sub}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              InkIcon(glyph, size: 24, color: pal.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: display(17, pal.ink)),
                    if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: pal.inkSoft)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        );

    Widget rule() => CustomPaint(size: const Size(double.infinity, 6), painter: _RulePainter(pal));

    Widget page(int seed, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PaperSlip(
            seed: seed,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(children: children),
          ),
        );

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RoundWoodButton(glyph: InkGlyph.back, tooltip: s.back, onPressed: () => Navigator.of(context).maybePop()),
                        Expanded(
                          child: Center(
                            child: Signboard(
                              hanging: true,
                              padding: const EdgeInsets.fromLTRB(26, 4, 26, 8),
                              child: Text(s.settings, style: display(24, kInk)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        page(51, [
                          row(InkGlyph.sound, s.sound, InkSwitch(value: st.sound, label: s.sound, onChanged: (v) => st.sound = v)),
                          rule(),
                          row(InkGlyph.music, s.music, InkSwitch(value: st.music, label: s.music, onChanged: (v) => st.music = v)),
                          rule(),
                          row(InkGlyph.vibrate, s.haptics, InkSwitch(value: st.haptics, label: s.haptics, onChanged: (v) => st.haptics = v)),
                        ]),
                        page(52, [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                            child: Align(alignment: Alignment.centerLeft, child: Text(s.language, style: display(17, pal.ink))),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TagChoice<AppLanguage>(
                              value: st.language,
                              options: [(AppLanguage.system, s.languageSystem), (AppLanguage.ja, '日本語'), (AppLanguage.en, 'English')],
                              onChanged: (v) => st.language = v,
                            ),
                          ),
                          const SizedBox(height: 8),
                          rule(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                            child: Align(alignment: Alignment.centerLeft, child: Text(s.theme, style: display(17, pal.ink))),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TagChoice<ThemeMode>(
                              value: st.themeMode,
                              options: [(ThemeMode.system, s.themeSystem), (ThemeMode.light, s.themeLight), (ThemeMode.dark, s.themeDark)],
                              onChanged: (v) => st.themeMode = v,
                            ),
                          ),
                          const SizedBox(height: 8),
                          rule(),
                          row(InkGlyph.info, s.reduceMotion, InkSwitch(value: st.reduceMotionSetting, label: s.reduceMotion, onChanged: (v) => st.reduceMotionSetting = v),
                              sub: s.reduceMotionSub),
                        ]),
                        page(53, [
                          _LinkRow(glyph: InkGlyph.book, label: s.howToPlay, onTap: () => Navigator.of(context).push(HowToPlayScreen.route())),
                          rule(),
                          _LinkRow(
                            glyph: InkGlyph.menu,
                            label: s.licenses,
                            onTap: () => showLicensePage(context: context, applicationName: s.appTitle, applicationVersion: appVersion),
                          ),
                          rule(),
                          row(InkGlyph.info, s.version, Text(appVersion, style: display(15, pal.inkSoft))),
                        ]),
                        Center(
                          child: WoodButton(
                            small: true,
                            kind: WoodKind.paper,
                            glyph: InkGlyph.trash,
                            label: s.resetProgress,
                            onPressed: () async {
                              final ok = await showNotice<bool>(
                                context,
                                title: s.resetProgress,
                                body: Text(s.resetConfirm),
                                actions: [
                                  Builder(builder: (c) => WoodButton(small: true, label: s.cancel, onPressed: () => Navigator.pop(c, false))),
                                  Builder(builder: (c) => WoodButton(small: true, kind: WoodKind.shu, label: s.reset, onPressed: () => Navigator.pop(c, true))),
                                ],
                              );
                              if (ok == true && context.mounted) {
                                scope.progress.resetAll();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.resetDone)));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.glyph, required this.label, required this.onTap});
  final InkGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              InkIcon(glyph, size: 24, color: pal.ink),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: display(17, pal.ink))),
              Transform.rotate(angle: 3.14159, child: InkIcon(InkGlyph.back, size: 20, color: pal.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A faint pencil rule between notebook lines.
class _RulePainter extends CustomPainter {
  _RulePainter(this.pal);
  final Palette pal;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(Wob.line(Offset(0, size.height / 2), Offset(size.width, size.height / 2), seed: size.width.toInt(), amp: .6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (pal.night ? pal.inkSoft : kInk).withValues(alpha: .2));
  }

  @override
  bool shouldRepaint(_RulePainter o) => o.pal != pal;
}
