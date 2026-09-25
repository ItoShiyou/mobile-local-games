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
import 'board_view.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});
  final Level level;

  static Route<void> route(Level level) => PageRouteBuilder(
        settings: RouteSettings(name: '/play/${level.id}'),
        pageBuilder: (_, _, _) => GameScreen(level: level),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      );

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const double _maxCell = 76;
  late GameController _c;
  final _focus = FocusNode(debugLabel: 'game');
  String? _toast;
  Timer? _toastTimer;
  bool _resultShown = false;
  bool _newBest = false;
  int _stars = 0;

  Level get level => widget.level;

  @override
  void initState() {
    super.initState();
    _c = GameController(level)..addListener(_onGame);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.read(context).progress.markPlayed(level);
      _maybeShowIntro();
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onGame);
    _c.dispose();
    _focus.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _onGame() {
    if (_c.isWon && !_resultShown) {
      final scope = AppScope.read(context);
      _resultShown = true;
      _newBest = scope.progress.recordClear(level, _c.moves);
      _stars = starsFor(level, _c.moves);
      Future.delayed(const Duration(milliseconds: 280), () {
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
        if (msg.isNotEmpty) _showToast(msg);
      }
      return;
    }
    final ev = r.events;
    if (ev.any((e) => e is Served)) {
      scope.sound.play(Sfx.serve);
      if (haptic) HapticFeedback.lightImpact();
    } else if (ev.any((e) => e is Returned)) {
      scope.sound.play(Sfx.drop);
      if (haptic) HapticFeedback.lightImpact();
    } else {
      if (ev.any((e) => e is PickedUp)) {
        scope.sound.play(Sfx.pickup);
      } else {
        scope.sound.play(Sfx.step);
      }
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
    if (d != null) _showToast(Strings.of(context).hintArrow(d));
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _toast = null);
    });
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.allClearTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(s.allClearBody),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.toStages))],
      ),
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
    final pal = context.palette;
    final reduce = scope.settings.reduceMotion(context);
    final st = _c.state;
    final best = scope.progress.best(level.id);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    _TopBar(level: level, lang: lang),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: pal.surface, borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          children: [
                            _Hud(state: st, level: level, moves: _c.moves, best: best),
                            const SizedBox(height: 10),
                            Expanded(
                              child: LayoutBuilder(builder: (context, box) {
                                // The tray hugs the board; the whole area still takes swipes.
                                final b = level.board;
                                final u = math.min(
                                  math.min((box.maxWidth - 16) / b.width, (box.maxHeight - 16) / b.height),
                                  _maxCell,
                                ).floorToDouble();
                                return Stack(
                                  children: [
                                    Center(
                                      child: Container(
                                        width: u * b.width + 16,
                                        height: u * b.height + 16,
                                        decoration: BoxDecoration(color: pal.tint(.22), borderRadius: BorderRadius.circular(18)),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: BoardView(
                                          controller: _c,
                                          reduceMotion: reduce,
                                          maxCell: _maxCell,
                                          onMove: _c.isWon ? null : _move,
                                          semanticLabel: s.boardSummary(st),
                                        ),
                                      ),
                                    ),
                                    if (_c.stuck && !_c.isWon)
                                      Positioned(
                                        left: 8,
                                        right: 8,
                                        top: 8,
                                        child: _StuckBanner(onUndo: _undo, onRestart: _restart),
                                      ),
                                    if (_toast != null && !_c.isWon)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 10,
                                        child: IgnorePointer(child: Center(child: _Toast(_toast!))),
                                      ),
                                    if (_c.isWon)
                                      Positioned(
                                        left: 8,
                                        right: 8,
                                        bottom: 8,
                                        child: _ResultCard(
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
                              }),
                            ),
                            const SizedBox(height: 12),
                            _Controls(
                              controller: _c,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.level, required this.lang});
  final Level level;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    return Row(
      children: [
        IconButton(
          tooltip: s.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            children: [
              Text('${level.chapter.number}-${level.number}',
                  style: TextStyle(fontSize: 12, color: pal.muted, fontFeatures: const [FontFeature.tabularFigures()])),
              Text(level.name(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        IconButton(
          tooltip: s.rules,
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => showRulesSheet(context, level),
        ),
        IconButton(
          tooltip: s.settings,
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
        ),
      ],
    );
  }
}

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
    final g = state.board.guests.length;
    const tab = [FontFeature.tabularFigures()];
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StackTower(stack: state.stack, capacity: state.board.capacity, cell: 26),
              const SizedBox(height: 2),
              Text(s.capacity(state.board.capacity), style: TextStyle(fontSize: 11, color: pal.muted)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < g; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Opacity(
                          opacity: state.isServed(i) ? .35 : 1,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: dishColors[state.board.guests[i].wants]!, width: 2),
                            ),
                            child: state.isServed(i)
                                ? Icon(Icons.check_rounded, size: 18, color: pal.ok)
                                : Padding(padding: const EdgeInsets.all(3), child: DishIcon(state.board.guests[i].wants)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(s.delivered(state.servedCount, g),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFeatures: tab)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 10,
                  children: [
                    Text(s.movesLabel(moves),
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: pal.ink, fontFeatures: tab)),
                    Text(s.parLabel(level.par), style: TextStyle(fontSize: 13.5, color: pal.muted, fontFeatures: tab)),
                    Text(s.bestLabel(best), style: TextStyle(fontSize: 13.5, color: pal.muted, fontFeatures: tab)),
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
      final narrow = box.maxWidth < 360;
      final pad = narrow ? const Size(50, 46) : const Size(56, 50);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DPad(onMove: onMove, highlight: c.hint, enabled: !c.isWon, buttonSize: pad),
          const SizedBox(width: 10),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: (box.maxWidth - pad.width * 3 - 12 - 10 - 6) / 2 / (pad.height),
              children: [
                ToolButton(icon: Icons.undo_rounded, label: s.undo, onPressed: c.canUndo ? onUndo : null),
                ToolButton(icon: Icons.redo_rounded, label: s.redo, onPressed: c.canRedo ? onRedo : null),
                ToolButton(icon: Icons.replay_rounded, label: s.restart, onPressed: c.canUndo || c.canRedo ? onRestart : null),
                ToolButton(
                  icon: Icons.lightbulb_outline_rounded,
                  label: s.hint,
                  highlight: c.stuck,
                  onPressed: c.isWon || c.stuck ? null : onHint,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _Toast extends StatelessWidget {
  const _Toast(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: pal.ink.withValues(alpha: .88), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: pal.bg, fontWeight: FontWeight.w700, fontSize: 13.5)),
    );
  }
}

class _StuckBanner extends StatelessWidget {
  const _StuckBanner({required this.onUndo, required this.onRestart});
  final VoidCallback onUndo, onRestart;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: Color.lerp(pal.surface, pal.warn, .12),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: pal.warn),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.stuckTitle, style: TextStyle(fontWeight: FontWeight.w900, color: pal.warn)),
                  Text(s.stuckBody, style: TextStyle(fontSize: 12.5, color: pal.muted)),
                ],
              ),
            ),
            SoftButton(compact: true, primary: true, icon: Icons.undo_rounded, label: '', semanticLabel: s.undo, onPressed: onUndo),
            const SizedBox(width: 6),
            SoftButton(compact: true, icon: Icons.replay_rounded, label: '', semanticLabel: s.restart, onPressed: onRestart),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
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
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.clearTitle, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: pal.accent)),
                    Text(s.clearBody(moves, par), style: TextStyle(color: pal.muted, fontSize: 13.5)),
                  ],
                ),
              ),
              _PopStars(stars: stars, animate: !reduceMotion),
            ],
          ),
          if (newBest || stars == 3) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                if (stars == 3) _Badge(s.perfect, pal.accent),
                if (newBest) _Badge(s.newBest, pal.ok),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SoftButton(primary: true, label: isLast ? s.toStages : s.next, icon: Icons.arrow_forward_rounded, onPressed: onNext),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: SoftButton(compact: true, label: s.retry, icon: Icons.replay_rounded, onPressed: onRetry)),
              const SizedBox(width: 6),
              Expanded(child: SoftButton(compact: true, label: s.toStages, icon: Icons.grid_view_rounded, onPressed: onStages)),
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
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.translate(
                offset: Offset(0, (1 - v) * 40),
                child: Opacity(opacity: v.clamp(0, 1), child: child),
              ),
              child: card,
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _PopStars extends StatelessWidget {
  const _PopStars({required this.stars, required this.animate});
  final int stars;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          animate
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 420 + i * 160),
                  curve: Interval(i * .25, 1, curve: Curves.elasticOut),
                  builder: (_, v, _) => Transform.scale(scale: .4 + .6 * v, child: _star(context, i < stars)),
                )
              : _star(context, i < stars),
      ],
    );
  }

  Widget _star(BuildContext context, bool on) => Icon(
        on ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 34,
        color: on ? const Color(0xFFE7A33E) : context.palette.line,
      );
}

Future<void> showGimmickIntro(BuildContext context, String gimmick) {
  final s = Strings.of(context);
  final pal = context.palette;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: GimmickIcon(gimmick, size: 64),
      title: Column(
        children: [
          Text(s.newGimmick, style: TextStyle(fontSize: 13, color: pal.accent, fontWeight: FontWeight.w700)),
          Text(s.gimmickName(gimmick), style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
      content: Text(s.gimmickDesc(gimmick), textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.gotIt))],
    ),
  );
}

Future<void> showRulesSheet(BuildContext context, Level level) {
  final s = Strings.of(context);
  final pal = context.palette;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.rules, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(s.ruleShort, style: TextStyle(color: pal.ink, height: 1.6)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final c in level.board.dishes.map((d) => d.color).toSet())
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    DishIcon(c, size: 24),
                    const SizedBox(width: 4),
                    Text(s.dishName(c), style: TextStyle(color: pal.muted, fontSize: 13)),
                  ]),
              ],
            ),
            for (final g in level.gimmicks) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GimmickIcon(g, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.gimmickName(g), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(s.gimmickDesc(g), style: TextStyle(color: pal.muted, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(s.keyboardHelp, style: TextStyle(color: pal.muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
