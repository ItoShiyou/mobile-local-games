// Cross promotion widgets. They take colors and fonts from the app's own
// Theme, so they look native to each app (Guideline 4.3).
// Source of truth: itoshiyou.github.io/hub/flutter/promo_widgets.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'promo.dart';

const _lineGreen = Color(0xFF06C755);

Widget _appIcon(BuildContext context, PromoApp app, double size) {
  final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
  final box = Container(width: size, height: size, color: bg);
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: app.iconUrl == null
        ? box
        : Image.network(
            app.iconUrl!,
            width: size,
            height: size,
            errorBuilder: (_, _, _) => box,
          ),
  );
}

/// Settings: always-on rows for official LINE + latest app.
class PromoPanel extends StatelessWidget {
  const PromoPanel({super.key, this.showHeader = true, this.textColor});
  final bool showHeader;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final line = Promo.lineUri;
    final app = Promo.latest;
    if (!Promo.current.enabled || (line == null && app == null)) {
      return const SizedBox.shrink();
    }
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '${Promo.current.brand} のアプリ・お知らせ',
              style: tt.labelLarge?.copyWith(color: textColor),
            ),
          ),
        if (line != null)
          ListTile(
            leading: const Icon(Icons.chat_bubble_rounded, color: _lineGreen),
            title: Text(
              '${Promo.current.brand} 公式LINE',
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              Promo.current.lineCopy,
              style: TextStyle(color: textColor?.withValues(alpha: 0.7)),
            ),
            trailing: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: textColor,
            ),
            onTap: Promo.openLine,
          ),
        if (app != null)
          ListTile(
            leading: _appIcon(context, app, 36),
            title: Text(
              'おすすめ「${app.name}」',
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              app.copy,
              style: TextStyle(color: textColor?.withValues(alpha: 0.7)),
            ),
            trailing: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: textColor,
            ),
            onTap: () => Promo.openApp(app),
          ),
        if (Promo.allAppsUri != null)
          ListTile(
            leading: Icon(Icons.apps_rounded, color: textColor),
            title: Text(
              '${Promo.current.brand} のアプリ一覧',
              style: TextStyle(color: textColor),
            ),
            trailing: Icon(Icons.open_in_new_rounded, size: 18, color: textColor),
            onTap: Promo.openAllApps,
          ),
      ],
    );
  }
}

/// Result screen: one quiet line under the buttons.
class PromoStrip extends StatelessWidget {
  const PromoStrip({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!Promo.current.enabled) return const SizedBox.shrink();
    final line = Promo.lineUri;
    final app = Promo.latest;
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (line != null)
          const TextButton(
            onPressed: Promo.openLine,
            child: Text(
              'LINEでお知らせを受け取る',
              style: TextStyle(fontSize: 12, color: _lineGreen),
            ),
          ),
        if (app != null)
          TextButton(
            onPressed: () => Promo.openApp(app),
            child: Text(
              '「${app.name}」も遊ぶ',
              style: TextStyle(fontSize: 12, color: c.withValues(alpha: 0.75)),
            ),
          ),
      ],
    );
  }
}

/// Wrap the whole app via MaterialApp.builder. On a notice launch a small
/// card slides down from the top and hides by itself. Never a modal.
class LaunchNotice extends StatefulWidget {
  const LaunchNotice({super.key, required this.child, this.suppressed});
  final Widget child;

  /// Return true to skip the notice (e.g. record / screenshot mode).
  final bool Function()? suppressed;

  @override
  State<LaunchNotice> createState() => _LaunchNoticeState();
}

class _LaunchNoticeState extends State<LaunchNotice> {
  /// The card is only in the tree while it is (or is animating) on screen.
  bool _mounted = false;
  bool _shown = false;
  bool _line = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _maybeShow();
  }

  Future<void> _maybeShow() async {
    if (!await Promo.takeLaunchNotice() || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || (widget.suppressed?.call() ?? false)) return;
    final hasLine = Promo.lineUri != null;
    final hasApp = Promo.latest != null;
    setState(() {
      _line = hasLine && (!hasApp || Promo.noticeIndex.isEven);
      _mounted = true;
    });
    // Start off-screen for one frame, then slide in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _hide = Timer(Duration(seconds: Promo.current.noticeSeconds), _close);
  }

  void _close() {
    if (mounted) setState(() => _shown = false);
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack so the app (child) keeps its state when the card comes and goes.
    if (!_mounted) return Stack(children: [widget.child]);
    final app = Promo.latest;
    final cs = Theme.of(context).colorScheme;
    final isLine = _line || app == null;
    final top = MediaQueryData.fromView(View.of(context)).padding.top + 8;
    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          left: 12,
          right: 12,
          top: _shown ? top : -160,
          onEnd: () {
            if (!_shown && mounted) setState(() => _mounted = false);
          },
          child: Material(
            color: cs.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                _close();
                if (isLine) {
                  Promo.openLine();
                } else {
                  Promo.openApp(app);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    if (isLine)
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: _lineGreen,
                        size: 30,
                      )
                    else
                      _appIcon(context, app, 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLine
                                ? '${Promo.current.brand} 公式LINE'
                                : 'おすすめ「${app.name}」',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            isLine ? Promo.current.lineCopy : app.copy,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: cs.onSurface),
                      onPressed: _close,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
