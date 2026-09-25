import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/progress.dart';
import 'app/settings.dart';
import 'audio/sound.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Zen Maru Gothic'], ofl);
    final yusei = await rootBundle.loadString('assets/fonts/OFL-YuseiMagic.txt');
    yield LicenseEntryWithLineBreaks(['Yusei Magic'], yusei);
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(TsumiageApp(
    settings: Settings(prefs),
    progress: Progress(prefs),
    sound: PluginSound(),
  ));
}
