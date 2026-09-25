// Stage list.
//
// Stages marked (試作) come from the prototype; the rest were found with
// tool/gen_levels.dart and picked by hand for the difficulty curve.
// test/levels_test.dart checks that every stage is solvable, that `par` is
// the true shortest solution, and that every gimmick on the map matters.
//
// Stage ids are saved in players' progress: never change or reuse them.
import 'level_model.dart';

export 'level_model.dart';

final List<Chapter> chapters = [
  Chapter(
    number: 1,
    id: 'basic',
    icon: 'dish',
    titleJa: 'まちの食堂',
    titleEn: 'The Corner Diner',
    subJa: 'はじめての出前。通れば必ず拾う、あとから拾った料理ほど上に来る。',
    subEn: 'First deliveries. You pick up whatever you walk over; the last dish is on top.',
    levels: [
      Level(id: 'b01', ja: 'はじめての出前', en: 'First Order', par: 4, map: [
        '#######',
        '#P.a.A#',
        '#######',
      ]), // (試作)
      Level(id: 'b02', ja: '上から順に', en: 'Top Comes First', par: 7, map: [
        '########',
        '#Pba..A#',
        '#.##B###',
        '########',
      ]),
      Level(id: 'b03', ja: '寄り道', en: 'A Little Detour', par: 10, map: [
        '######',
        '#abbA#',
        '#PaB##',
        '#aA#.#',
        '#....#',
        '######',
      ]),
      Level(id: 'b04', ja: '奥の卵焼き', en: 'Omelette at the Back', par: 11, map: [
        '#######',
        '#c.bPC#',
        '#B#..##',
        '##....#',
        '#c.a#.#',
        '#######',
      ]),
      Level(id: 'b05', ja: '並んだトマト', en: 'Row of Tomatoes', par: 13, map: [
        '#######',
        '#A#..##',
        '#bb..##',
        '#P.aaA#',
        '#######',
      ]),
      Level(id: 'b06', ja: '余計なお皿', en: 'One Dish Too Many', par: 15, map: [
        '######',
        '##Ba.#',
        '#.Aa.#',
        '#b..##',
        '#P...#',
        '######',
      ]), // (試作)
      Level(id: 'b07', ja: 'トマトの海', en: 'Sea of Tomatoes', par: 15, map: [
        '#######',
        '#..Pb##',
        '#.aa..#',
        '##Aa..#',
        '#Ac.A.#',
        '#######',
      ]),
      Level(id: 'b08', ja: '三つの小部屋', en: 'Three Little Rooms', par: 22, map: [
        '#######',
        '#b#.#A#',
        '#..b#b#',
        '#.BP.c#',
        '#C#..a#',
        '#######',
      ]),
      Level(id: 'b09', ja: '大忙し', en: 'Rush Hour', par: 24, map: [
        '#######',
        '#a#.P.#',
        '#...cA#',
        '##b#.##',
        '##aCB##',
        '#######',
      ]), // (試作)
      Level(id: 'b10', ja: '抹茶の行列', en: 'Matcha Queue', par: 24, map: [
        '#######',
        '##bb..#',
        '#BBcP.#',
        '#.a.bB#',
        '#######',
      ]),
    ],
  ),
  Chapter(
    number: 2,
    id: 'counter',
    icon: 'counter',
    titleJa: '駅前の定食屋',
    titleEn: 'Station Set-Meal Shop',
    subJa: '返却口：ぶつかると一番上の1皿を引き取ってくれる。1回だけ。',
    subEn: 'Return counter: bump it to hand back your top dish. Works once.',
    levels: [
      Level(id: 'c01', ja: 'はじめての返却', en: 'First Return', par: 5, map: [
        '#######',
        '#Pab.A#',
        '####T##',
        '#######',
      ]),
      Level(id: 'c02', ja: '返却口', en: 'The Counter', par: 9, map: [
        '######',
        '#Aa.##',
        '#.P###',
        '#TbaB#',
        '######',
      ]), // (試作)
      Level(id: 'c03', ja: '二人のトマト好き', en: 'Two Tomato Fans', par: 10, map: [
        '#######',
        '#..aAA#',
        '#..bTc#',
        '###.Pa#',
        '#######',
      ]),
      Level(id: 'c04', ja: '回り込み', en: 'Around the Back', par: 16, map: [
        '#######',
        '##.cab#',
        '#..ATC#',
        '#..b.##',
        '##...P#',
        '#######',
      ]),
      Level(id: 'c05', ja: '一皿だけ', en: 'Just One Dish', par: 18, map: [
        '#######',
        '##A.P.#',
        '##B...#',
        '#C.Ta.#',
        '#.bca.#',
        '#######',
      ]), // (試作)
      Level(id: 'c06', ja: '卵焼き日和', en: 'Omelette Weather', par: 18, map: [
        '########',
        '#.c..A##',
        '##.BTcc#',
        '#C.abP.#',
        '########',
      ]),
      Level(id: 'c07', ja: 'いらない一皿', en: 'The Unwanted Dish', par: 22, map: [
        '#######',
        '#b.T#B#',
        '#.aCA.#',
        '#..#Pa#',
        '#..c..#',
        '#######',
      ]), // (試作)
      Level(id: 'c08', ja: '三つの抹茶', en: 'Three Matcha', par: 26, map: [
        '######',
        '#..TC#',
        '#bc.a#',
        '#bbB.#',
        '#Pc.##',
        '#B..B#',
        '######',
      ]),
    ],
  ),
  Chapter(
    number: 3,
    id: 'tray',
    icon: 'tray',
    titleJa: '坂の上の喫茶店',
    titleEn: 'Hilltop Café',
    subJa: 'くるりのお盆：乗ると頭の上の料理が上下さかさまになる。',
    subEn: 'Flip tray: step on it and your whole stack turns upside down.',
    levels: [
      Level(id: 't02', ja: '下からくるり', en: 'Flip from Below', par: 9, map: [
        '######',
        '#...b#',
        '##caP#',
        '##a#A#',
        '#.s.C#',
        '######',
      ]),
      Level(id: 't01', ja: 'くるりトレイ', en: 'Flip Tray', par: 7, map: [
        '######',
        '#bPa.#',
        '#..sB#',
        '##A..#',
        '######',
      ]), // (試作)
      Level(id: 't03', ja: 'さかさま注文', en: 'Upside-Down Order', par: 11, map: [
        '######',
        '#b.sB#',
        '##.PA#',
        '#.a..#',
        '######',
      ]), // (試作)
      Level(id: 't04', ja: '角のトレイ', en: 'Tray in the Corner', par: 11, map: [
        '#######',
        '##cC.s#',
        '#b.a..#',
        '#Pc.#C#',
        '#######',
      ]),
      Level(id: 't05', ja: '二枚のトレイ', en: 'Two Trays', par: 13, map: [
        '######',
        '#saa.#',
        '#bAAs#',
        '#C#.c#',
        '##.Pb#',
        '######',
      ]),
      Level(id: 't06', ja: '遠いトレイ', en: 'The Far Tray', par: 16, map: [
        '######',
        '#s...#',
        '#..c.#',
        '#b#.P#',
        '#aBCb#',
        '######',
      ]),
      Level(id: 't07', ja: '三段重ね', en: 'Three High', par: 16, cap: 3, map: [
        '#######',
        '#Bs#..#',
        '#..bbA#',
        '###Aa##',
        '#P.a.b#',
        '#######',
      ]),
      Level(id: 't08', ja: 'ひっくり返して', en: 'Turn It Over', par: 22, cap: 3, map: [
        '#######',
        '#a..CA#',
        '#B#...#',
        '#....s#',
        '#.P.bc#',
        '#######',
      ]), // (試作)
    ],
  ),
  Chapter(
    number: 4,
    id: 'oneway',
    icon: 'oneWay',
    titleJa: '路地裏',
    titleEn: 'Back Alleys',
    subJa: '一方通行：矢印の向きに進むときだけ入れる道。戻り道に気をつけて。',
    subEn: 'One-way lanes: enter only the way the arrows point.',
    levels: [
      Level(id: 'o01', ja: '一方通行', en: 'One Way', par: 7, map: [
        '######',
        '#P.a.#',
        '#..<b#',
        '#<.AB#',
        '######',
      ]), // (試作)
      Level(id: 'o02', ja: '右へ右へ', en: 'Keep Right', par: 12, map: [
        '#######',
        '#A.C.a#',
        '#a.P>c#',
        '#.#av>#',
        '#######',
      ]),
      Level(id: 'o03', ja: '下り坂', en: 'Downhill', par: 15, map: [
        '#######',
        '#Ca.b^#',
        '#.Pvvc#',
        '#Aa..>#',
        '##.v..#',
        '#######',
      ]),
      Level(id: 'o04', ja: '回り道の出前', en: 'The Long Way Round', par: 15, map: [
        '#######',
        '#B...P#',
        '#.<c..#',
        '#b<.a.#',
        '#C.<.A#',
        '#######',
      ]), // (試作)
      Level(id: 'o05', ja: '行き止まり', en: 'Dead End', par: 16, map: [
        '######',
        '#B.^b#',
        '###P.#',
        '#Cc<.#',
        '#..ba#',
        '######',
      ]),
      Level(id: 'o06', ja: '左側通行', en: 'Keep Left', par: 17, map: [
        '#######',
        '#C<.a##',
        '#A.vcC#',
        '#<Pc..#',
        '##<ac##',
        '#######',
      ]),
      Level(id: 'o07', ja: '抜け道なし', en: 'No Shortcuts', par: 21, map: [
        '#######',
        '#bBc..#',
        '#.aC<P#',
        '##...##',
        '#.<.A##',
        '#######',
      ]), // (試作)
      Level(id: 'o08', ja: '迷路の食堂', en: 'Maze Diner', par: 23, map: [
        '#######',
        '##.>B##',
        '#.>.#C#',
        '#ab##^#',
        '#c...P#',
        '#<..c.#',
        '#######',
      ]),
    ],
  ),
  Chapter(
    number: 5,
    id: 'mix',
    icon: 'mix',
    titleJa: '夏祭りの夜',
    titleEn: 'Summer Festival Night',
    subJa: '屋台が並ぶお祭りの夜。これまでのしかけが総出演。',
    subEn: 'A night of festival stalls, with every trick you have learned.',
    levels: [
      Level(id: 'm01', ja: '返却と矢印', en: 'Counters and Arrows', par: 14, map: [
        '########',
        '#P^##..#',
        '#ab.A.C#',
        '#T^...^#',
        '#..c..>#',
        '########',
      ]),
      Level(id: 'm02', ja: '返してくるり 前菜', en: 'Return and Flip: Starter', par: 17, map: [
        '######',
        '#bAB.#',
        '#aTsa#',
        '#Pb#.#',
        '#Aa..#',
        '######',
      ]),
      Level(id: 'm03', ja: 'くるりの小道', en: 'Flip Lane', par: 17, map: [
        '#######',
        '#b#.<P#',
        '#<.c.##',
        '#<a<.##',
        '#sBbAC#',
        '#.>b.s#',
        '#######',
      ]),
      Level(id: 'm04', ja: '裏口', en: 'Back Door', par: 18, map: [
        '########',
        '#B..#.P#',
        '#c>C.#.#',
        '#^.c.Aa#',
        '#.T...b#',
        '#a.....#',
        '########',
      ]),
      Level(id: 'm05', ja: '坂の上のトレイ', en: 'Tray on the Hill', par: 18, map: [
        '#######',
        '#Pc>..#',
        '#A.>^.#',
        '#cb#.C#',
        '#.....#',
        '#.<.sa#',
        '#######',
      ]),
      Level(id: 'm06', ja: '卵焼き三昧', en: 'Omelette Feast', par: 21, map: [
        '########',
        '#AaCCPa#',
        '##...T.#',
        '#...s#c#',
        '##..b.c#',
        '########',
      ]),
      Level(id: 'm07', ja: '満員御礼', en: 'Full House', par: 21, cap: 3, map: [
        '#######',
        '#B..ca#',
        '#..#Ab#',
        '#c<..s#',
        '#.PTC.#',
        '#######',
      ]), // (試作)
      Level(id: 'm08', ja: '逆走禁止', en: 'No Wrong Way', par: 22, map: [
        '########',
        '#<.#.T##',
        '#^<aPbc#',
        '#<b#<a.#',
        '#A...CB#',
        '########',
      ]),
      Level(id: 'm09', ja: '返してくるり', en: 'Return and Flip', par: 24, map: [
        '#######',
        '##Pa.b#',
        '#Ac.#.#',
        '#B#cTs#',
        '#...#C#',
        '#######',
      ]), // (試作)
      Level(id: 'm10', ja: '二つの窓口', en: 'Two Windows', par: 24, map: [
        '########',
        '#C#A#A##',
        '#c.<..##',
        '#.#vaT##',
        '#.<.^.P#',
        '#.bBcac#',
        '########',
      ]),
      Level(id: 'm11', ja: 'せまい厨房', en: 'Tight Kitchen', par: 28, map: [
        '#######',
        '#.ac###',
        '#b#asP#',
        '#.CTsA#',
        '#######',
      ]),
      Level(id: 'm12', ja: '閉店前の大仕事', en: 'Last Orders', par: 29, map: [
        '########',
        '#.cb<Pa#',
        '#...B.v#',
        '#A.T.a##',
        '##..#..#',
        '#..Ac..#',
        '########',
      ]),
    ],
  ),
];

final List<Level> allLevels = linkLevels(chapters);

Level? levelById(String id) {
  for (final l in allLevels) {
    if (l.id == id) return l;
  }
  return null;
}
