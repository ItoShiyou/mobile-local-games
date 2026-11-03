import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// The delivery cat, hand-drawn and printed: four raster poses that replace
/// the code-drawn cat once loaded. Until then (or if a file fails to load,
/// or in widget tests) [Art.courier] falls back to the vector cat.
class CatSprites {
  CatSprites._();

  static const _poses = ['down', 'up', 'right', 'happy'];
  static final Map<String, ui.Image> _images = {};

  static ui.Image? pose(String name) => _images[name];

  /// Width over height of every pose (they share one canvas).
  static double get aspect {
    final i = _images['down'];
    return i == null ? .82 : i.width / i.height;
  }

  static Future<void> load() async {
    try {
      for (final p in _poses) {
        final data = await rootBundle.load('assets/art/cat_$p.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _images[p] = (await codec.getNextFrame()).image;
      }
    } catch (_) {
      _images.clear(); // all or nothing: never mix a sprite cat with a vector one
    }
  }
}
