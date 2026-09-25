import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import 'board_view.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'scene.dart';
import 'settings_screen.dart';
import 'widgets.dart';

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
  static const double _frame = 12;

  late GameController _c;
  final _focus = FocusNode(debugLabel: 'game');
  String? _say;
  Timer? _sayTimer;
  Timer? _greetTimer;
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
      if (!mounted) return;
      _greetTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && _c.moves == 0) _speak(Strings.of(context).greeting, ms: 1800);
      });
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onGame);
    _c.dispose();
    _focus.dispose();
    _sayTimer?.cancel();
    _greetTimer?.cancel();
    super.dispose();
  }

  void _onGame() {
    if (_c.isWon && !_resultShown) {
      final scope = AppScope.read(context);
      _resultShown = true;
      _say = null;
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

  void _speak(String text, {int ms = 1600}) {
    _sayTimer?.cancel();
    setState(() => _say = text);
    _sayTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _say = null);
    });
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
      if (b != null) {
        final msg = Strings.of(context).blocked(b.reason, wanted: b.wanted);
        if (msg.isNotEmpty) _speak(msg);
      }
      return;
    }
    if (_say != null && _c.hint == null) setState(() => _say = null);
    final ev = r.events;
    if (ev.any((e) => e is Served)) {
      scope.sound.play(Sfx.serve);
      if (haptic) HapticFeedback.lightImpact();
    } else if (ev.any((e) => e is Returned)) {
      scope.sound.play(Sfx.drop);
      if (haptic) HapticFeedback.lightImpact();
    } else {
      scope.sound.play(ev.any((e) => e is PickedUp) ? Sfx.pickup : Sfx.step);
      if (ev.any((e) => e is Flipped)) {
        Future.delayed(const Duration(milliseconds: 160), () => scope.sound.play(Sfx.flip));
      }
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
    if (d != null) _speak(Strings.of(context).hintArrow(d), ms: 2200);
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
    final best = scope.progress.best(level.id);
    final lang = Localizations.localeOf(context).languageCode;
    final scene = sceneFor(level.chapter.id);

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    children: [
                      _TopBar(level: level, lang: lang),
                      const SizedBox(height: 6),
                      _Hud(state: st, level: level, moves: _c.moves, best: best),
                      const SizedBox(height: 8),
                      Expanded(child: _boardArea(context, s, scene, reduce, st)),
                      const SizedBox(height: 10),
                      _Controls(controller: _c, onMove: _move, onUndo: _undo, onRedo: _redo, onRestart: _restart, onHint: _hint),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _boardArea(BuildContext context, Strings s, Scene scene, bool reduce, GameState st) {
    return LayoutBuilder(builder: (context, box) {
      final b = level.board;
      final inner = Size(box.maxWidth - _frame * 2, box.maxHeight - _frame * 2);
      final u = cellSizeFor(b, inner, _maxCell);
      final bw = u * b.width, bh = u * b.height;
      final ox = (box.maxWidth - bw) / 2, oy = (box.maxHeight - bh) / 2;
      // where the courier's head is, for the speech bubble
      final catX = ox + (st.pos.x + .5) * u;
      final catTop = oy + st.pos.y * u - u * (.1 + st.stack.length * .16);
      final bubbleW = math.min(240.0, box.maxWidth);
      final bubbleLeft = (catX - 44).clamp(0.0, math.max(0.0, box.maxWidth - bubbleW)).toDouble();
      final bubbleBottom = (box.maxHeight - catTop).clamp(0.0, math.max(0.0, box.maxHeight - 70)).toDouble();
      final tailX = ((catX - bubbleLeft) / bubbleW).clamp(.1, .9);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: ox - _frame,
            top: oy - _frame,
            width: bw + _frame * 2,
            height: bh + _frame * 2,
            child: CustomPaint(painter: _FramePainter(context.palette)),
          ),
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
          if (_c.stuck && !_c.isWon)
            Positioned(
              left: bubbleLeft,
              bottom: bubbleBottom,
              width: bubbleW,
              child: SpeechBubble(
                warn: true,
                tailX: tailX,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.stuckTitle),
                    const SizedBox(height: 2),
                    Text(s.stuckBody, style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: .7), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: WoodButton(small: true, kind: WoodKind.shu, glyph: InkGlyph.undo, label: s.undo, onPressed: _undo)),
                      const SizedBox(width: 8),
                      Expanded(child: WoodButton(small: true, glyph: InkGlyph.restart, label: s.restart, onPressed: _restart)),
                    ]),
                  ],
                ),
              ),
            )
          else if (_say != null && !_c.isWon)
            // anchor the bubble on the side of the courier with more room
            Positioned(
              left: catX <= box.maxWidth / 2 ? math.max(0.0, catX - 34) : null,
              right: catX > box.maxWidth / 2 ? math.max(0.0, box.maxWidth - catX - 34) : null,
              bottom: bubbleBottom,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bubbleW),
                  child: Semantics(
                    liveRegion: true,
                    child: SpeechBubble(
                      tailFromLeft: catX <= box.maxWidth / 2 ? catX - math.max(0.0, catX - 34) : null,
                      tailFromRight: catX > box.maxWidth / 2 ? (box.maxWidth - catX) - math.max(0.0, box.maxWidth - catX - 34) : null,
                      child: Text(_say!),
                    ),
                  ),
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

/// Wooden frame around the diorama.
class _FramePainter extends CustomPainter {
  _FramePainter(this.pal);
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = Wob.rrect(r.deflate(1), 14, seed: 40, amp: 1.2);
    canvas.drawPath(outer.shift(const Offset(0, 5)), Paint()..color = const Color(0x44000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(outer, Paint()..color = pal.woodDark);
    canvas.save();
    canvas.clipPath(outer);
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x22FFFFFF);
    for (var i = 0; i < 6; i++) {
      canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(2.0 + i * 1.7), const Radius.circular(12)), g);
    }
    PaperGrain.paint(canvas, r);
    canvas.restore();
    canvas.drawPath(outer, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kInk);
  }

  @override
  bool shouldRepaint(_FramePainter o) => o.pal != pal;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.level, required this.lang});
  final Level level;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoundWoodButton(glyph: InkGlyph.back, tooltip: s.back, onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: Signboard(
              hanging: true,
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${level.chapter.title(lang)}  ${level.chapter.number}-${level.number}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: display(11.5, kInk.withValues(alpha: .7))),
                  Text(level.name(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(19, kInk)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RoundWoodButton(glyph: InkGlyph.help, tooltip: s.rules, onPressed: () => showRulesSheet(context, level)),
        const SizedBox(width: 6),
        RoundWoodButton(
          glyph: InkGlyph.settings,
          tooltip: s.settings,
          onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
        ),
      ],
    );
  }
}

/// Order slips on a cord, and the chalkboard with the move count.
class _Hud extends StatelessWidget {
  const _Hud({required this.state, required this.level, required this.moves, required this.best});
  final GameState state;
  final Level level;
  final int moves;
  final int? best;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    final g = state.board.guests;
    return Semantics(
      liveRegion: true,
      label: '${s.orders} ${state.servedCount}/${g.length}. ${s.movesWord} $moves. ${s.parWord} ${level.par}.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _CordPainter(pal),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, right: 6),
                          child: Text(s.orders, style: display(13, pal.inkSoft)),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < g.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: OrderSlip(kind: g[i].wants, served: state.isServed(i), stamp: s.servedStamp, index: i),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Chalkboard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '${s.movesWord} '),
                      TextSpan(text: '$moves', style: display(20, pal.chalk, height: 1)),
                      TextSpan(text: '  ${s.parWord} ${level.par}', style: display(12.5, pal.chalk.withValues(alpha: .75))),
                    ])),
                    Text('${s.bestWord} ${best ?? '—'} ・ ${s.capacity(state.board.capacity)}', style: display(11.5, pal.chalk.withValues(alpha: .7))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CordPainter extends CustomPainter {
  _CordPainter(this.pal);
  final Palette pal;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 8)
      ..quadraticBezierTo(size.width / 2, 16, size.width, 8);
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = pal.inkSoft);
  }

  @override
  bool shouldRepaint(_CordPainter o) => o.pal != pal;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.onMove,
    required this.onUndo,
    required this.onRedo,
    required this.onRestart,
    required this.onHint,
  });
  final GameController controller;
  final void Function(Dir) onMove;
  final VoidCallback onUndo, onRedo, onRestart, onHint;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final c = controller;
    return LayoutBuilder(builder: (context, box) {
      final h = MediaQuery.sizeOf(context).height;
      final arm = h < 640 ? 34.0 : (box.maxWidth < 360 || h < 740 ? 42.0 : 48.0);
      final tools = [
        WoodButton(vertical: true, glyph: InkGlyph.undo, label: s.undo, onPressed: c.canUndo ? onUndo : null, seed: 1),
        WoodButton(vertical: true, glyph: InkGlyph.redo, label: s.redo, onPressed: c.canRedo ? onRedo : null, seed: 2),
        WoodButton(vertical: true, glyph: InkGlyph.restart, label: s.restart, onPressed: c.canUndo || c.canRedo ? onRestart : null, seed: 3),
        WoodButton(
          vertical: true,
          kind: WoodKind.noren,
          glyph: InkGlyph.hint,
          label: s.hint,
          glow: c.hint != null,
          onPressed: c.isWon || c.stuck ? null : onHint,
          seed: 4,
        ),
      ];
      return SizedBox(
        height: arm * 3 + 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            WoodDPad(onMove: onMove, highlight: c.hint, enabled: !c.isWon, arm: arm),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: tools[0]), const SizedBox(width: 8), Expanded(child: tools[1])])),
                  const SizedBox(height: 8),
                  Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: tools[2]), const SizedBox(width: 8), Expanded(child: tools[3])])),
                ],
              ),
            ),
          ],
        ),
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
                for (final c in level.board.dishes.map((d) => d.color).toSet())
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
