import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves walkthrough screenshots under $SHOT_DIR (default: build/shots).
Future<void> main() async {
  final dir = Directory(Platform.environment['SHOT_DIR'] ?? 'build/shots')..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
