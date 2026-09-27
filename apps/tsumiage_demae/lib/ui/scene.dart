import 'package:flutter/material.dart';

enum FloorKind { planks, tiles, parquet, stones, earth }

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

const _diner = Scene(
  id: 'diner',
  floor: FloorKind.planks,
  wall: WallKind.plaster,
  // pale hinoki boards and warm plaster: a bright lunchtime room
  floorA: Color(0xFFF0D6A8),
  floorB: Color(0xFFE8CA98),
  floorLine: Color(0xFFC39A68),
  wallTop: Color(0xFFD2AE82),
  wallFront: Color(0xFFFAF1DD),
  wallTrim: Color(0xFFB07C4C),
  outside: Color(0xFFC49C72),
  decor: [Decor.tanzaku, Decor.window, Decor.shelf, Decor.plant, Decor.clock, Decor.tanzaku],
  sunny: true,
);

const _teishoku = Scene(
  id: 'teishoku',
  floor: FloorKind.tiles,
  wall: WallKind.tiles,
  floorA: Color(0xFFE9E1CF),
  floorB: Color(0xFFD4C8B0),
  floorLine: Color(0xFFB9AC92),
  wallTop: Color(0xFF7A6552),
  wallFront: Color(0xFF7FA58F),
  wallTrim: Color(0xFF6E4A30),
  outside: Color(0xFF5B574B),
  decor: [Decor.poster, Decor.tanzaku, Decor.maneki, Decor.teapot, Decor.plant, Decor.shelf],
);

const _kissa = Scene(
  id: 'kissa',
  floor: FloorKind.parquet,
  wall: WallKind.brick,
  floorA: Color(0xFFB98A5E),
  floorB: Color(0xFFA7774D),
  floorLine: Color(0xFF7D5433),
  wallTop: Color(0xFF6B4A36),
  wallFront: Color(0xFFB06A4E),
  wallTrim: Color(0xFF4F3324),
  outside: Color(0xFF45302A),
  decor: [Decor.lamp, Decor.window, Decor.cup, Decor.plant, Decor.poster, Decor.lamp],
);

const _alley = Scene(
  id: 'alley',
  floor: FloorKind.stones,
  wall: WallKind.fence,
  floorA: Color(0xFFCFC8BA),
  floorB: Color(0xFFBDB5A5),
  floorLine: Color(0xFF928A7B),
  wallTop: Color(0xFF6E9656),
  wallFront: Color(0xFFA27A52),
  wallTrim: Color(0xFF6A4B30),
  outside: Color(0xFF557A45),
  decor: [Decor.flowerpot, Decor.lantern, Decor.plant, Decor.flowerpot, Decor.poster],
);

const _matsuri = Scene(
  id: 'matsuri',
  floor: FloorKind.earth,
  wall: WallKind.stalls,
  floorA: Color(0xFFB48D66),
  floorB: Color(0xFFA67F59),
  floorLine: Color(0xFF86623F),
  wallTop: Color(0xFFB8463A),
  wallFront: Color(0xFFEFE3CF),
  wallTrim: Color(0xFF7A2E24),
  outside: Color(0xFF3B4636),
  decor: [Decor.chochin, Decor.chochin, Decor.lantern, Decor.chochin],
  alwaysNight: true,
);

/// Scene for each chapter id (see levels.dart).
const scenes = <String, Scene>{
  'basic': _diner,
  'counter': _teishoku,
  'tray': _kissa,
  'oneway': _alley,
  'mix': _matsuri,
};

Scene sceneFor(String chapterId) => scenes[chapterId] ?? _diner;
