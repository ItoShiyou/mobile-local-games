import 'package:flutter/material.dart';

/// The look of the whole app: a picture-book neighbourhood diner.
///
/// Washi paper, sumi-brown ink lines, wood, an indigo noren and vermilion
/// hanko stamps. Dark mode is "evening service": indigo night paper and
/// lantern light.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.night,
    required this.paper,
    required this.paperDeep,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.wood,
    required this.woodLight,
    required this.woodDark,
    required this.noren,
    required this.onNoren,
    required this.shu,
    required this.onShu,
    required this.leaf,
    required this.glow,
    required this.chalk,
    required this.board,
  });

  final bool night;

  /// Page background (washi) and its deeper shade.
  final Color paper;
  final Color paperDeep;

  /// Paper slips laid on top of the page.
  final Color card;

  /// Sumi ink for lines and text.
  final Color ink;
  final Color inkSoft;
  final Color line;

  final Color wood;
  final Color woodLight;
  final Color woodDark;

  /// Indigo shop curtain.
  final Color noren;
  final Color onNoren;

  /// Vermilion: hanko stamps and the main button.
  final Color shu;
  final Color onShu;
  final Color leaf;

  /// Lantern light.
  final Color glow;

  /// Chalk on the small blackboard.
  final Color chalk;
  final Color board;

  static const day = Palette(
    night: false,
    paper: Color(0xFFF3EAD8),
    paperDeep: Color(0xFFE6D6BA),
    card: Color(0xFFFBF5EA),
    ink: Color(0xFF3A2B22),
    inkSoft: Color(0xFF7D6754),
    line: Color(0xFFD5C2A2),
    wood: Color(0xFFC6955F),
    woodLight: Color(0xFFE0B985),
    woodDark: Color(0xFF7E5535),
    noren: Color(0xFF2F4B6B),
    onNoren: Color(0xFFF6EEDF),
    shu: Color(0xFFC8452F),
    onShu: Color(0xFFFFF7EA),
    leaf: Color(0xFF5E8C4A),
    glow: Color(0xFFFFC56B),
    chalk: Color(0xFFF2EEDF),
    board: Color(0xFF3E4A3F),
  );

  static const evening = Palette(
    night: true,
    paper: Color(0xFF1F2331),
    paperDeep: Color(0xFF171A26),
    card: Color(0xFF2B2F3F),
    ink: Color(0xFFF1E6D2),
    inkSoft: Color(0xFFB9AB94),
    line: Color(0xFF444A5E),
    wood: Color(0xFFA27650),
    woodLight: Color(0xFFC49A6C),
    woodDark: Color(0xFF5A3C26),
    noren: Color(0xFF3F5F86),
    onNoren: Color(0xFFF6EEDF),
    shu: Color(0xFFD9573F),
    onShu: Color(0xFFFFF7EA),
    leaf: Color(0xFF6E9C58),
    glow: Color(0xFFFFC56B),
    chalk: Color(0xFFF2EEDF),
    board: Color(0xFF2F3A31),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < .5 ? this : (other ?? this);
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// Food colours. Each dish also has its own silhouette (see art.dart), so
/// colour is never the only cue.
const dishColors = <String, Color>{
  'a': Color(0xFFE0564A), // tomato
  'b': Color(0xFF6FA64E), // matcha dango
  'c': Color(0xFFF0C13F), // tamagoyaki
  'd': Color(0xFF8A56B8), // grapes
};

/// Body text: a soft rounded gothic that stays readable at small sizes.
const fontFamily = 'ZenMaruGothic';

/// Signs, titles and numbers: a hand-lettered marker face.
const displayFont = 'YuseiMagic';

TextStyle display(double size, Color color, {double height = 1.2}) =>
    TextStyle(fontFamily: displayFont, fontSize: size, color: color, height: height, fontWeight: FontWeight.w400);

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.day : Palette.evening;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.shu,
    brightness: b,
    primary: p.shu,
    onPrimary: p.onShu,
    surface: p.card,
    onSurface: p.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: p.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [p],
  );
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink, fontFamily: fontFamily);
  return base.copyWith(
    textTheme: text,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.paper, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
