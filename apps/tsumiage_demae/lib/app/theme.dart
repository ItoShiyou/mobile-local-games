import 'package:flutter/material.dart';

/// Design tokens, following the チルパズル工房 UI/UX spec (§2):
/// a calm blue-grey ground plus exactly one accent colour per game.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.tile,
    required this.wall,
    required this.ink,
    required this.muted,
    required this.line,
    required this.wood,
    required this.woodLine,
    required this.accent,
    required this.onAccent,
    required this.warn,
    required this.ok,
  });

  final Color bg;
  final Color surface;
  final Color tile;
  final Color wall;
  final Color ink;
  final Color muted;
  final Color line;

  /// Restaurant floor boards.
  final Color wood;
  final Color woodLine;

  /// つみあげ出前's accent (warm tray brown).
  final Color accent;
  final Color onAccent;
  final Color warn;
  final Color ok;

  static const light = Palette(
    bg: Color(0xFFE4E8EE),
    surface: Color(0xFFF4F6F9),
    tile: Color(0xFFD3DAE4),
    wall: Color(0xFF5A667D),
    ink: Color(0xFF26303F),
    muted: Color(0xFF667085),
    line: Color(0xFFC5CDD9),
    wood: Color(0xFFE7D5BD),
    woodLine: Color(0x0F000000),
    accent: Color(0xFFB7794A),
    onAccent: Colors.white,
    warn: Color(0xFFC43B3B),
    ok: Color(0xFF4FA86A),
  );

  static const dark = Palette(
    bg: Color(0xFF161B23),
    surface: Color(0xFF1F2631),
    tile: Color(0xFF2C3443),
    wall: Color(0xFF0E1218),
    ink: Color(0xFFE6EAF0),
    muted: Color(0xFF98A2B3),
    line: Color(0xFF333D4D),
    wood: Color(0xFF4A3D30),
    woodLine: Color(0x14FFFFFF),
    accent: Color(0xFFC98A5A),
    onAccent: Colors.white,
    warn: Color(0xFFE06A6A),
    ok: Color(0xFF5DBA78),
  );

  /// `color-mix(in srgb, accent p%, base)` from the prototype.
  Color tint(double p, [Color? base]) => Color.lerp(base ?? bg, accent, p)!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      tile: l(tile, other.tile),
      wall: l(wall, other.wall),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      wood: l(wood, other.wood),
      woodLine: l(woodLine, other.woodLine),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      warn: l(warn, other.warn),
      ok: l(ok, other.ok),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// Food colours. Each dish also has its own silhouette (see dish_art.dart)
/// so that colour is never the only cue (UI/UX spec KI-08).
const dishColors = <String, Color>{
  'a': Color(0xFFE0646A), // tomato
  'b': Color(0xFF4FA86A), // matcha
  'c': Color(0xFFE9B93A), // egg
  'd': Color(0xFF8E5CC6), // grape
};

const fontFamily = 'ZenMaruGothic';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: b,
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.surface,
    onSurface: p.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink, fontFamily: fontFamily);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w900, fontSize: 18, color: p.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(48, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(48, 48),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.bg, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
