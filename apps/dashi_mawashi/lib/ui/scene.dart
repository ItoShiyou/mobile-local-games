import 'package:flutter/material.dart';

enum FloorKind { tatami, planks, tiles, parquet, stones, earth }

enum WallKind { plaster, tiles, brick, fence, stalls }

/// Things that can decorate a wall. `front` ones hang on the visible face of
/// a wall, the others sit on its top.
enum Decor {
  tanzaku(front: true),
  window(front: true),
  shelf(front: true),
  clock(front: true),
  poster(front: true),
  lamp(front: true, light: true),
  lantern(front: true, light: true),
  plant(),
  maneki(),
  teapot(),
  cup(),
  flowerpot(),
  chochin(light: true);

  const Decor({this.front = false, this.light = false});
  final bool front;
  final bool light;
}

/// Where a chapter takes place.
class Scene {
  const Scene({
    required this.id,
    required this.floor,
    required this.wall,
    required this.floorA,
    required this.floorB,
    required this.floorLine,
    required this.wallTop,
    required this.wallFront,
    required this.wallTrim,
    required this.outside,
    required this.decor,
    this.alwaysNight = false,
    this.sunny = false,
  });

  final String id;
  final FloorKind floor;
  final WallKind wall;
  final Color floorA, floorB, floorLine;
  final Color wallTop, wallFront, wallTrim;

  /// Walls deep inside the block (the roof, seen from above).
  final Color outside;
  final List<Decor> decor;
  final bool alwaysNight;

  /// Daylight falls through the windows onto the floor.
  final bool sunny;
}

// The pipes sit on a wooden counter; the kitchen around it changes from
// chapter to chapter.
const _kitchen = Scene(
  id: 'basic',
  floor: FloorKind.planks,
  wall: WallKind.tiles,
  floorA: Color(0xFFE6C99A),
  floorB: Color(0xFFDDBE8C),
  floorLine: Color(0xFFB08A5C),
  wallTop: Color(0xFFA38B6E),
  wallFront: Color(0xFF8DB09B),
  wallTrim: Color(0xFF6E4A30),
  outside: Color(0xFF94876F),
  decor: [Decor.poster, Decor.teapot, Decor.plant, Decor.shelf],
  sunny: true,
);

const _pantry = Scene(
  id: 'mix',
  floor: FloorKind.planks,
  wall: WallKind.plaster,
  floorA: Color(0xFFE2C293),
  floorB: Color(0xFFD8B684),
  floorLine: Color(0xFFAA8455),
  wallTop: Color(0xFFCDA97E),
  wallFront: Color(0xFFF8EEDA),
  wallTrim: Color(0xFF55603E),
  outside: Color(0xFFBF976C),
  decor: [Decor.window, Decor.shelf, Decor.plant, Decor.window],
  sunny: true,
);

const _boiler = Scene(
  id: 'iron',
  floor: FloorKind.planks,
  wall: WallKind.brick,
  floorA: Color(0xFFD4B184),
  floorB: Color(0xFFC9A677),
  floorLine: Color(0xFF9A764C),
  wallTop: Color(0xFF9A7152),
  wallFront: Color(0xFFC47D5E),
  wallTrim: Color(0xFF6E4A33),
  outside: Color(0xFF7E5A45),
  decor: [Decor.lamp, Decor.shelf, Decor.lamp],
);

const _garden = Scene(
  id: 'cross',
  floor: FloorKind.planks,
  wall: WallKind.fence,
  floorA: Color(0xFFE0C696),
  floorB: Color(0xFFD5BA88),
  floorLine: Color(0xFFA88A5C),
  wallTop: Color(0xFF6E9656),
  wallFront: Color(0xFFA27A52),
  wallTrim: Color(0xFF6A4B30),
  outside: Color(0xFF557A45),
  decor: [Decor.flowerpot, Decor.plant, Decor.flowerpot],
  sunny: true,
);

const _lateNight = Scene(
  id: 'night',
  floor: FloorKind.planks,
  wall: WallKind.plaster,
  floorA: Color(0xFFD9B98A),
  floorB: Color(0xFFCEAC7C),
  floorLine: Color(0xFFA07C50),
  wallTop: Color(0xFF9E4A3A),
  wallFront: Color(0xFFF1E4CC),
  wallTrim: Color(0xFF7A2E24),
  outside: Color(0xFF6E4336),
  decor: [Decor.chochin, Decor.lantern, Decor.lamp, Decor.chochin],
  alwaysNight: true,
);

/// Scene for each chapter id (see levels.dart).
const scenes = <String, Scene>{
  'basic': _kitchen,
  'mix': _pantry,
  'iron': _boiler,
  'cross': _garden,
  'night': _lateNight,
};

Scene sceneFor(String chapterId) => scenes[chapterId] ?? _kitchen;
