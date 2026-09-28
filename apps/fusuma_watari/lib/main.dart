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
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Storage can be unavailable (e.g. a browser with site data blocked):
    // play on with progress kept in memory for this session only.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }
  runApp(FusumaApp(
    settings: Settings(prefs),
    progress: Progress(prefs),
    sound: PluginSound(),
  ));
}
