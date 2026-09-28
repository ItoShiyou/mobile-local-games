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

// Every wing of the inn is floored with tatami; the walls and the light
// change from chapter to chapter.
const _ground = Scene(
  id: 'basic',
  floor: FloorKind.tatami,
  wall: WallKind.plaster,
  floorA: Color(0xFFDDD8A6),
  floorB: Color(0xFFD3CD98),
  floorLine: Color(0xFF8F8A55),
  wallTop: Color(0xFFCDA97E),
  wallFront: Color(0xFFF8EEDA),
  wallTrim: Color(0xFF55603E),
  outside: Color(0xFFBF976C),
  decor: [Decor.window, Decor.plant, Decor.clock, Decor.window, Decor.teapot],
  sunny: true,
);

const _annex = Scene(
  id: 'pair',
  floor: FloorKind.tatami,
  wall: WallKind.plaster,
  floorA: Color(0xFFD9D7AA),
  floorB: Color(0xFFCFCC9C),
  floorLine: Color(0xFF878757),
  wallTop: Color(0xFFA9A493),
  wallFront: Color(0xFFEEF0E8),
  wallTrim: Color(0xFF2F4B6B),
  outside: Color(0xFF9A9580),
  decor: [Decor.window, Decor.lantern, Decor.plant, Decor.window],
  sunny: true,
);

const _office = Scene(
  id: 'lock',
  floor: FloorKind.tatami,
  wall: WallKind.plaster,
  floorA: Color(0xFFD6CF9B),
  floorB: Color(0xFFCBC38D),
  floorLine: Color(0xFF857D4B),
  wallTop: Color(0xFFA27A58),
  wallFront: Color(0xFFF3E6CC),
  wallTrim: Color(0xFF6B3F2A),
  outside: Color(0xFF8E6A4C),
  decor: [Decor.shelf, Decor.maneki, Decor.lamp, Decor.clock],
);

const _teaRoom = Scene(
  id: 'revolve',
  floor: FloorKind.tatami,
  wall: WallKind.plaster,
  floorA: Color(0xFFE0DBAC),
  floorB: Color(0xFFD6D09E),
  floorLine: Color(0xFF928D58),
  wallTop: Color(0xFFBFA27A),
  wallFront: Color(0xFFF4E9D2),
  wallTrim: Color(0xFF3F4A2E),
  outside: Color(0xFFB09067),
  decor: [Decor.window, Decor.teapot, Decor.cup, Decor.plant, Decor.flowerpot],
  sunny: true,
);

const _banquet = Scene(
  id: 'mix',
  floor: FloorKind.tatami,
  wall: WallKind.plaster,
  floorA: Color(0xFFD8D09E),
  floorB: Color(0xFFCDC490),
  floorLine: Color(0xFF857C4A),
  wallTop: Color(0xFF9E4A3A),
  wallFront: Color(0xFFF1E4CC),
  wallTrim: Color(0xFF7A2E24),
  outside: Color(0xFF6E4336),
  decor: [Decor.chochin, Decor.lantern, Decor.lamp, Decor.chochin],
  alwaysNight: true,
);

/// Scene for each chapter id (see levels.dart).
const scenes = <String, Scene>{
  'basic': _ground,
  'pair': _annex,
  'lock': _office,
  'revolve': _teaRoom,
  'mix': _banquet,
};

Scene sceneFor(String chapterId) => scenes[chapterId] ?? _ground;
