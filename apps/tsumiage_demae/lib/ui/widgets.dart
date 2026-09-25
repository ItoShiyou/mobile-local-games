import 'dart:async';

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../app/theme.dart';
import '../audio/sound.dart';
import '../game/engine.dart';
import 'art.dart';

/// Rounded button used across the app (spec §3-7: 12px radius, bg colour).
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.primary = false,
    this.highlight = false,
    this.compact = false,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool primary;
  final bool highlight;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final enabled = onPressed != null;
    final bg = primary ? pal.accent : (highlight ? pal.tint(.3) : pal.bg);
    final fg = primary ? pal.onAccent : pal.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed == null
                ? null
                : () {
                    AppScope.read(context).sound.play(Sfx.tap);
                    onPressed!();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 8 : 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) Icon(icon, size: 20, color: fg),
                    if (icon != null && label.isNotEmpty) const SizedBox(width: 6),
                    if (label.isNotEmpty)
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 13 : 15, color: fg),
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

/// Square tool button with the icon above a short label.
class ToolButton extends StatelessWidget {
  const ToolButton({super.key, required this.icon, required this.label, required this.onPressed, this.highlight = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: Material(
          color: highlight ? pal.tint(.3) : pal.bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed == null
                ? null
                : () {
                    AppScope.read(context).sound.play(Sfx.tap);
                    onPressed!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 22, color: pal.ink),
                      const SizedBox(height: 2),
                      Text(label, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pal.ink)),
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
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 14, this.max = 3});
  final int stars;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size, color: i < stars ? const Color(0xFFE7A33E) : pal.line),
      ],
    );
  }
}

/// The dishes on the courier's head, bottom to top, with empty slots for
/// the remaining capacity. The top dish is outlined.
class StackTower extends StatelessWidget {
  const StackTower({super.key, required this.stack, required this.capacity, this.cell = 30});
  final List<String> stack;
  final int capacity;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return CustomPaint(
      size: Size(cell * 1.3, cell * .5 * capacity + cell * .5),
      painter: _TowerPainter(stack, capacity, cell, pal),
    );
  }
}

class _TowerPainter extends CustomPainter {
  _TowerPainter(this.stack, this.capacity, this.cell, this.pal);
  final List<String> stack;
  final int capacity;
  final double cell;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final step = cell * .5;
    for (var k = 0; k < capacity; k++) {
      final c = Offset(cx, size.height - cell * .3 - k * step);
      if (k < stack.length) {
        Art.stackDish(canvas, c, cell * 1.6, stack[k], highlight: k == stack.length - 1);
      } else {
        final r = Rect.fromCenter(center: c, width: cell * .9, height: cell * .22);
        canvas.drawOval(r, Art.stroke(pal.line, 1.5));
      }
    }
  }

  @override
  bool shouldRepaint(_TowerPainter old) =>
      old.stack.join() != stack.join() || old.capacity != capacity || old.pal != pal;
}

class GimmickIcon extends StatelessWidget {
  const GimmickIcon(this.id, {super.key, this.size = 32});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .18),
      child: CustomPaint(
        size: Size.square(size),
        painter: _GimmickPainter(id, pal),
      ),
    );
  }
}

class _GimmickPainter extends CustomPainter {
  _GimmickPainter(this.id, this.pal);
  final String id;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width;
    switch (id) {
      case 'counter':
        Art.counter(canvas, Offset.zero, u, pal, used: false);
      case 'tray':
        Art.tray(canvas, Offset.zero, u, pal);
      case 'oneWay':
        Art.oneWay(canvas, Offset.zero, u, pal, Dir.right);
      case 'mix':
        Art.woodTile(canvas, Offset.zero, u, pal);
        canvas.save();
        canvas.scale(.5);
        Art.counter(canvas, Offset.zero, u, pal, used: false);
        Art.tray(canvas, Offset(u, 0), u, pal);
        Art.oneWay(canvas, Offset(0, u), u, pal, Dir.right);
        Art.woodTile(canvas, Offset(u, u), u, pal);
        Art.floorDish(canvas, Offset(u * 1.5, u * 1.5), u, 'a');
        canvas.restore();
      default:
        Art.woodTile(canvas, Offset.zero, u, pal);
        Art.floorDish(canvas, Offset(u / 2, u / 2), u, 'a');
    }
  }

  @override
  bool shouldRepaint(_GimmickPainter old) => old.id != id || old.pal != pal;
}

class DishIcon extends StatelessWidget {
  const DishIcon(this.kind, {super.key, this.size = 28});
  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _DishPainter(kind));
}

class _DishPainter extends CustomPainter {
  _DishPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas, Size size) => Art.food(canvas, size.center(Offset.zero), size.width, kind);
  @override
  bool shouldRepaint(_DishPainter old) => old.kind != kind;
}

/// Inverted-T direction pad (spec §3-6). Holding a button repeats the move.
class DPad extends StatelessWidget {
  const DPad({super.key, required this.onMove, this.highlight, this.enabled = true, this.buttonSize = const Size(56, 50)});
  final void Function(Dir) onMove;
  final Dir? highlight;
  final bool enabled;
  final Size buttonSize;

  @override
  Widget build(BuildContext context) {
    Widget b(Dir d, IconData icon, String label) => _PadButton(
          dir: d,
          icon: icon,
          label: label,
          size: buttonSize,
          onMove: enabled ? onMove : null,
          highlight: highlight == d,
        );
    const gap = 6.0;
    final names = Localizations.localeOf(context).languageCode == 'ja'
        ? const ['上', '左', '下', '右']
        : const ['Up', 'Left', 'Down', 'Right'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        b(Dir.up, Icons.keyboard_arrow_up_rounded, names[0]),
        const SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            b(Dir.left, Icons.keyboard_arrow_left_rounded, names[1]),
            const SizedBox(width: gap),
            b(Dir.down, Icons.keyboard_arrow_down_rounded, names[2]),
            const SizedBox(width: gap),
            b(Dir.right, Icons.keyboard_arrow_right_rounded, names[3]),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatefulWidget {
  const _PadButton({
    required this.dir,
    required this.icon,
    required this.label,
    required this.size,
    required this.onMove,
    required this.highlight,
  });
  final Dir dir;
  final IconData icon;
  final String label;
  final Size size;
  final void Function(Dir)? onMove;
  final bool highlight;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  Timer? _repeat;
  bool _down = false;

  void _start() {
    if (widget.onMove == null) return;
    setState(() => _down = true);
    widget.onMove!(widget.dir);
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 380), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 150), (_) => widget.onMove?.call(widget.dir));
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    if (mounted && _down) setState(() => _down = false);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bg = _down ? pal.tint(.35) : (widget.highlight ? pal.tint(.28) : pal.bg);
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onMove == null ? null : () => widget.onMove!(widget.dir),
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size.width,
          height: widget.size.height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: widget.highlight ? Border.all(color: pal.accent, width: 2) : null,
          ),
          child: Icon(widget.icon, size: 30, color: widget.onMove == null ? pal.muted : pal.ink),
        ),
      ),
    );
  }
}
