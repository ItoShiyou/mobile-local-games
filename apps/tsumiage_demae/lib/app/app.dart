import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../audio/sound.dart';
import '../ui/title_screen.dart';
import 'progress.dart';
import 'scope.dart';
import 'settings.dart';
import 'theme.dart';

class TsumiageApp extends StatefulWidget {
  const TsumiageApp({super.key, required this.settings, required this.progress, required this.sound});
  final Settings settings;
  final Progress progress;
  final Sound sound;

  @override
  State<TsumiageApp> createState() => _TsumiageAppState();
}

class _TsumiageAppState extends State<TsumiageApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_applyAudio);
    _applyAudio();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_applyAudio);
    widget.sound.dispose();
    super.dispose();
  }

  void _applyAudio() => widget.sound.setEnabled(sfx: widget.settings.sound, music: widget.settings.music);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.sound.resumeMusic();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        widget.sound.pauseMusic();
      case AppLifecycleState.inactive:
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: widget.settings,
      progress: widget.progress,
      sound: widget.sound,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          title: 'つみあげ出前',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          supportedLocales: const [Locale('ja'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Text is part of painted signs, tags and tickets that have a fixed
          // size, so larger system text is honoured only up to a point.
          builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
          home: const TitleScreen(),
        ),
      ),
    );
  }
}
