import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../app/progress.dart';
import '../app/scope.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../audio/sound.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import '../game/levels.dart';
import 'art.dart';
import 'backdrop.dart';
import 'board_view.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'scene.dart';
import 'settings_screen.dart';
import 'widgets.dart';
import 'world_controls.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});
  final Level level;

  static Route<void> route(Level level) =>
      NorenRoute(settings: RouteSettings(name: '/play/${level.id}'), builder: (_) => GameScreen(level: level));

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const double _maxCell = 76;
  static const double _frame = 4;

  late GameController _c;
  final _focus = FocusNode(debugLabel: 'game');
  bool _resultShown = false;
  bool _newBest = false;
  int _stars = 0;

  Level get level => widget.level;

  @override
  void initState() {
    super.initState();
    _c = GameController(level)..addListener(_onGame);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      AppScope.read(context).progress.markPlayed(level);
      await _maybeShowIntro();
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onGame);
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onGame() {
    if (_c.isWon && !_resultShown) {
      final scope = AppScope.read(context);
      _resultShown = true;
      _newBest = scope.progress.recordClear(level, _c.moves);
      _stars = starsFor(level, _c.moves);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        scope.sound.play(Sfx.clear);
        if (scope.settings.haptics) HapticFeedback.mediumImpact();
      });
    } else if (!_c.isWon) {
      _resultShown = false;
    }
    setState(() {});
  }

  Future<void> _maybeShowIntro() async {
    final g = level.introduces;
    final progress = AppScope.read(context).progress;
    if (g == null || progress.introSeen(g)) return;
    await showGimmickIntro(context, g);
    progress.markIntroSeen(g);
  }

  /// Nothing is written on screen during play: the board shows what went
  /// wrong. Screen readers still hear it.
  void _announce(String text) {
    if (text.isEmpty) return;
    SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context));
  }

  void _move(Dir d) {
    if (_c.isWon) return;
    final scope = AppScope.read(context);
    final r = _c.move(d);
    final haptic = scope.settings.haptics;
    if (!r.isOk) {
      scope.sound.play(Sfx.bump);
      if (haptic) HapticFeedback.lightImpact();
      final b = _c.bump;
      if (b != null) _announce(Strings.of(context).blocked(b.reason));
      if (_c.beckonUndo) _announce('${Strings.of(context).stuckTitle} ${Strings.of(context).stuckBody}');
      return;
    }
    final ev = r.events;
    if (ev.any((e) => e is Served)) {
      scope.sound.play(Sfx.serve);
      if (haptic) HapticFeedback.lightImpact();
    } else if (ev.any((e) => e is Swung)) {
      scope.sound.play(Sfx.swing);
      if (haptic) HapticFeedback.lightImpact();
    } else if (ev.any((e) => e is Slid)) {
      scope.sound.play(Sfx.slide);
      if (haptic) HapticFeedback.selectionClick();
    } else {
      scope.sound.play(ev.any((e) => e is KeyTaken) ? Sfx.key : Sfx.step);
      if (haptic) HapticFeedback.selectionClick();
    }
  }

  void _undo() {
    if (_c.undo()) AppScope.read(context).sound.play(Sfx.undo);
  }

  void _redo() {
    if (_c.redo()) AppScope.read(context).sound.play(Sfx.step);
  }

  void _restart() {
    _c.restart();
    AppScope.read(context).sound.play(Sfx.undo);
  }

  void _hint() {
    final d = _c.showHint();
    final s = Strings.of(context);
    _announce(d != null ? s.hintArrow(d) : '${s.stuckTitle} ${s.stuckBody}');
  }

  void _next() {
    final next = level.next;
    if (next == null) {
      _showAllClear();
      return;
    }
    Navigator.of(context).pushReplacement(GameScreen.route(next));
  }

  Future<void> _showAllClear() async {
    final s = Strings.of(context);
    await showNotice<void>(
      context,
      title: s.allClearTitle,
      art: const CourierPortrait(size: 70, stack: ['a', 'b', 'c']),
      body: Text(s.allClearBody),
      actions: [Builder(builder: (context) => WoodButton(kind: WoodKind.shu, label: s.toStages, onPressed: () => Navigator.pop(context)))],
    );
    if (mounted) Navigator.of(context).pop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    Dir? d;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) d = Dir.up;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) d = Dir.down;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) d = Dir.left;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) d = Dir.right;
    if (d != null) {
      _move(d);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyZ || k == LogicalKeyboardKey.backspace) {
      _undo();
    } else if (k == LogicalKeyboardKey.keyY) {
      _redo();
    } else if (k == LogicalKeyboardKey.keyR) {
      _restart();
    } else if (k == LogicalKeyboardKey.keyH) {
      _hint();
    } else if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) && _c.isWon) {
      _next();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = Strings.of(context);
    final reduce = scope.settings.reduceMotion(context);
    final st = _c.state;
    final lang = Localizations.localeOf(context).languageCode;
    final scene = sceneFor(level.chapter.id);

    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: SceneBackdrop(
        scene: scene,
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            children: [
              _TopBand(level: level, lang: lang, state: st, moves: _c.moves, safeTop: pad.top, night: scene.alwaysNight),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _boardArea(context, s, scene, reduce, st),
                    ),
                  ),
                ),
              ),
              _CounterBand(
                controller: _c,
                safeBottom: pad.bottom,
                onMove: _move,
                onUndo: _undo,
                onRedo: _redo,
                onRestart: _restart,
                onHint: _hint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boardArea(BuildContext context, Strings s, Scene scene, bool reduce, GameState st) {
    return LayoutBuilder(builder: (context, box) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_frame),
              child: BoardView(
                controller: _c,
                scene: scene,
                reduceMotion: reduce,
                maxCell: _maxCell,
                onMove: _c.isWon ? null : _move,
                semanticLabel: s.boardSummary(st),
              ),
            ),
          ),
          if (_c.isWon)
            Positioned(
              left: 4,
              right: 4,
              bottom: 0,
              child: _Receipt(
                moves: _c.moves,
                par: level.par,
                stars: _stars,
                newBest: _newBest,
                isLast: level.next == null,
                reduceMotion: reduce,
                onNext: _next,
                onRetry: _restart,
                onStages: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      );
    });
  }
}

/// The result: a receipt slides up with the stamps.
class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.moves,
    required this.par,
    required this.stars,
    required this.newBest,
    required this.isLast,
    required this.reduceMotion,
    required this.onNext,
    required this.onRetry,
    required this.onStages,
  });
  final int moves, par, stars;
  final bool newBest, isLast, reduceMotion;
  final VoidCallback onNext, onRetry, onStages;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    final card = PaperSlip(
      seed: 23,
      tilt: -.8,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CourierPortrait(size: 44, look: Dir.down),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.clearTitle, style: display(27, pal.shu, height: 1.1)),
                    Text(s.clearBody(moves, par), style: TextStyle(color: pal.inkSoft, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              HankoStars(stars: stars, size: 30, animate: !reduceMotion),
            ],
          ),
          if (newBest || stars == 3) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                children: [
                  if (stars == 3) Text('〔${s.perfect}〕', style: display(14, pal.shu)),
                  if (newBest) Text('〔${s.newBest}〕', style: display(14, pal.leaf)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          CustomPaint(size: const Size(double.infinity, 10), painter: _DashPainter(pal)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: WoodButton(kind: WoodKind.shu, label: isLast ? s.toStages : s.next, glyph: InkGlyph.play, onPressed: onNext),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: WoodButton(small: true, label: s.retry, glyph: InkGlyph.restart, onPressed: onRetry)),
              const SizedBox(width: 8),
              Expanded(child: WoodButton(small: true, label: s.toStages, glyph: InkGlyph.menu, onPressed: onStages)),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      child: reduceMotion
          ? card
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.translate(offset: Offset(0, (1 - v) * 120), child: Opacity(opacity: v.clamp(0, 1), child: child)),
              child: card,
            ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.pal);
  final Palette pal;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = pal.inkSoft.withValues(alpha: .5)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 4, size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => false;
}

Future<void> showGimmickIntro(BuildContext context, String gimmick) {
  final s = Strings.of(context);
  return showNotice<void>(
    context,
    title: s.gimmickName(gimmick),
    art: Column(
      children: [
        Text(s.newGimmick, style: display(15, context.palette.shu)),
        const SizedBox(height: 6),
        GimmickIcon(gimmick, size: 72),
      ],
    ),
    body: Text(s.gimmickDesc(gimmick)),
    actions: [Builder(builder: (context) => WoodButton(kind: WoodKind.shu, label: s.gotIt, onPressed: () => Navigator.pop(context)))],
  );
}

Future<void> showRulesSheet(BuildContext context, Level level) {
  final s = Strings.of(context);
  final pal = context.palette;
  return showNotice<void>(
    context,
    title: s.rules,
    body: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .5),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.ruleShort, textAlign: TextAlign.start),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final c in level.board.guests.map((g) => g.wants).toSet())
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    DishIcon(c, size: 26),
                    const SizedBox(width: 4),
                    Text(s.dishName(c), style: TextStyle(color: pal.inkSoft, fontSize: 13)),
                  ]),
              ],
            ),
            for (final g in level.gimmicks) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GimmickIcon(g, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.gimmickName(g), style: display(16, pal.ink)),
                        Text(s.gimmickDesc(g), textAlign: TextAlign.start, style: TextStyle(color: pal.inkSoft, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(s.keyboardHelp, textAlign: TextAlign.start, style: TextStyle(color: pal.inkSoft, fontSize: 11.5)),
          ],
        ),
      ),
    ),
    actions: [Builder(builder: (context) => WoodButton(kind: WoodKind.shu, label: s.gotIt, onPressed: () => Navigator.pop(context)))],
  );
}

/// The top of the screen: the kitchen pass. A beam with the shop's noren
/// (shop and dish name on it), tags for back / rules / settings, the order
/// slips clipped to a rail and the little blackboard.
class _TopBand extends StatelessWidget {
  const _TopBand({required this.level, required this.lang, required this.state, required this.moves, required this.safeTop, required this.night});
  final Level level;
  final String lang;
  final GameState state;
  final int moves;
  final double safeTop;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    final g = state.board.guests;
    final noren = night ? const Color(0xFF7A2E24) : pal.noren;
    return SizedBox(
      height: safeTop + 150,
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, height: safeTop + 18, child: CustomPaint(painter: BeamPainter(pal, height: safeTop + 18))),
          Positioned(
            top: safeTop + 14,
            left: 60,
            right: 108,
            height: 74,
            child: CustomPaint(
              painter: NorenPainter(color: noren, text: pal.onNoren, panels: 3, crest: '', rod: false),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${level.chapter.title(lang)}  ${level.chapter.number}-${level.number}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: display(11.5, pal.onNoren.withValues(alpha: .8))),
                    Text(level.name(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(21, pal.onNoren, height: 1.15)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: safeTop + 12,
            left: 10,
            child: HangingTag(
              glyph: InkGlyph.back,
              label: s.back,
              showLabel: false,
              width: 42,
              height: 44,
              onPressed: () => Navigator.of(context).maybePop(),
              seed: 1,
            ),
          ),
          Positioned(
            top: safeTop + 12,
            right: 56,
            child: HangingTag(
              glyph: InkGlyph.help,
              label: s.rules,
              showLabel: false,
              width: 42,
              height: 44,
              onPressed: () => showRulesSheet(context, level),
              seed: 2,
            ),
          ),
          Positioned(
            top: safeTop + 12,
            right: 8,
            child: HangingTag(
              glyph: InkGlyph.settings,
              label: s.settings,
              showLabel: false,
              width: 42,
              height: 44,
              onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
              seed: 3,
            ),
          ),
          // order slips clipped to the rail
          Positioned(
            top: safeTop + 92,
            left: 6,
            right: 118,
            height: 58,
            child: Semantics(
              label: '${s.orders} ${state.servedCount}/${g.length}',
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _RailPainter(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 4, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < g.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: OrderSlip(kind: g[i].wants, served: state.isServed(i), stamp: s.servedStamp, index: i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: safeTop + 84,
            right: 10,
            child: Semantics(
              label: '${s.movesWord} $moves. ${s.parWord} ${level.par}.',
              child: ExcludeSemantics(
                child: WallChalkboard(moves: moves, par: level.par, movesWord: s.movesWord, parWord: s.parWord),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin brass rail with clips, for the order slips.
class _RailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const y = 4.0;
    canvas.drawLine(const Offset(0, y + 2), Offset(size.width, y + 2), Art.stroke(const Color(0x33000000), 3));
    canvas.drawLine(const Offset(0, y), Offset(size.width, y), Art.stroke(const Color(0xFFB08A45), 4));
    canvas.drawLine(const Offset(0, y - 1), Offset(size.width, y - 1), Art.stroke(const Color(0x66FFFFFF), 1));
    for (final x in [3.0, size.width - 3]) {
      canvas.drawCircle(Offset(x, y), 4, Art.fill(const Color(0xFF8A6A30)));
    }
  }

  @override
  bool shouldRepaint(_RailPainter o) => false;
}

/// The bottom of the screen: the counter with the tray pad, and the tags
/// and lantern hanging from a short rail.
class _CounterBand extends StatelessWidget {
  const _CounterBand({
    required this.controller,
    required this.safeBottom,
    required this.onMove,
    required this.onUndo,
    required this.onRedo,
    required this.onRestart,
    required this.onHint,
  });
  final GameController controller;
  final double safeBottom;
  final void Function(Dir) onMove;
  final VoidCallback onUndo, onRedo, onRestart, onHint;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    final c = controller;
    final screen = MediaQuery.sizeOf(context);
    final short = screen.height < 700;
    final narrow = screen.width < 360;
    final tray = short || narrow ? 122.0 : 146.0;
    final tagW = narrow ? 38.0 : 44.0;
    final tagH = short ? 76.0 : 90.0;
    final bandH = (short ? 148.0 : 172.0) + safeBottom;
    return SizedBox(
      height: bandH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, right: 0, bottom: 0, height: 58 + safeBottom, child: CustomPaint(painter: CounterPainter(pal))),
          Positioned(
            left: 12,
            bottom: 26 + safeBottom,
            child: TrayPad(size: tray, onMove: onMove, highlight: c.hint, enabled: !c.isWon),
          ),
          Positioned(
            right: 8,
            top: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CustomPaint(size: Size(tagW * 4 + 42, 10), painter: _PegRailPainter(pal)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 6),
                    HangingTag(
                      label: s.undo,
                      glyph: InkGlyph.undo,
                      width: tagW,
                      height: tagH,
                      onPressed: c.canUndo ? onUndo : null,
                      beckon: c.beckonUndo,
                      seed: 4,
                    ),
                    const SizedBox(width: 6),
                    HangingTag(label: s.redo, glyph: InkGlyph.redo, width: tagW, height: tagH, onPressed: c.canRedo ? onRedo : null, seed: 5),
                    const SizedBox(width: 6),
                    HangingTag(
                      label: s.restart,
                      glyph: InkGlyph.restart,
                      width: tagW,
                      height: tagH,
                      wood: TagWood.dark,
                      onPressed: c.canUndo || c.canRedo ? onRestart : null,
                      seed: 6,
                    ),
                    const SizedBox(width: 8),
                    LanternButton(
                      label: s.hint,
                      lit: c.hint != null,
                      width: tagW + 10,
                      height: tagH + 10,
                      onPressed: c.isWon ? null : onHint,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The short wooden rail the tags hang from.
class _PegRailPainter extends CustomPainter {
  _PegRailPainter(this.pal);
  final Palette pal;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, 10);
    canvas.drawRect(r.shift(const Offset(0, 3)), Art.fill(const Color(0x33000000)));
    Art.inked(canvas, Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(3))), pal.woodDark, 1.6);
  }

  @override
  bool shouldRepaint(_PegRailPainter o) => o.pal != pal;
}
