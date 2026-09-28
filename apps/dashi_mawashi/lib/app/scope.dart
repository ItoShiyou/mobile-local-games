import 'package:flutter/widgets.dart';

import '../audio/sound.dart';
import 'progress.dart';
import 'settings.dart';

/// Makes the app-wide services available to every screen and rebuilds
/// dependants when settings or progress change.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({
    super.key,
    required this.settings,
    required this.progress,
    required this.sound,
    required super.child,
  }) : super(notifier: Listenable.merge([settings, progress]));

  final Settings settings;
  final Progress progress;
  final Sound sound;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// Access without registering a rebuild dependency (for callbacks).
  static AppScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;
}
